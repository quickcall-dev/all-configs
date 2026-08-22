#!/usr/bin/env bash

input=$(cat)

eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.workspace.current_dir // .cwd)",
  @sh "model=\(.model.display_name // "Claude")",
  @sh "used_pct=\(.context_window.used_percentage // 0)",
  @sh "total_input=\(.context_window.total_input_tokens // 0)",
  @sh "total_output=\(.context_window.total_output_tokens // 0)",
  @sh "ctx_window_size=\(.context_window.context_window_size // 0)",
  @sh "session_id=\(.session_id // "")",
  @sh "session_name=\(.session_name // "")",
  @sh "five_h_pct=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "five_h_reset=\(.rate_limits.five_hour.resets_at // "")",
  @sh "seven_d_pct=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "seven_d_reset=\(.rate_limits.seven_day.resets_at // "")"
')"

R='\033[0m'; B='\033[1m'; D='\033[2m'
BLUE='\033[38;5;33m'
GREEN='\033[38;5;34m'
YELLOW='\033[38;5;172m'
RED='\033[38;5;160m'
CYAN='\033[38;5;31m'
MAGENTA='\033[38;5;92m'
GRAY='\033[38;5;244m'
DIM='\033[38;5;240m'

# ── Git ───────────────────────────────────────────────────────────────────────
git_root="" git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_root=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)")
    git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    [[ -z "$git_branch" ]] && git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if ! git -C "$cwd" --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; then
        git_branch="${git_branch}*"
    fi
fi
dir="${git_root:-$(basename "$cwd")}"

# ── Model short ──────────────────────────────────────────────────────────────
short_model=$(echo "$model" | sed -E 's/Claude //; s/ \(.*//')
short_model="${short_model,}"
if [[ $ctx_window_size -ge 1000000 ]]; then
    short_model+="[$(( ctx_window_size / 1000000 ))M]"
elif [[ $ctx_window_size -ge 1000 ]]; then
    short_model+="[$(( ctx_window_size / 1000 ))K]"
fi

# ── Context % ────────────────────────────────────────────────────────────────
used_int=${used_pct%.*}; used_int=${used_int:-0}
if   [[ $used_int -lt 50 ]]; then cc="$GREEN"
elif [[ $used_int -lt 75 ]]; then cc="$YELLOW"
else cc="$RED"; fi

# ── Turn ─────────────────────────────────────────────────────────────────────
turn="0"
if [[ -n "$session_id" ]]; then
    tf="/tmp/claude-turns-${session_id}.txt"
    [[ -f "$tf" ]] && turn=$(cat "$tf" 2>/dev/null)
fi
[[ -z "$turn" ]] && turn="0"

# ── Countdown ────────────────────────────────────────────────────────────────
fmt_cd() {
    local diff=$(( $1 - $(date +%s) ))
    if [[ $diff -le 0 ]]; then echo "now"
    elif [[ $diff -ge 86400 ]]; then printf "%dd %dh" $(( diff/86400 )) $(( (diff%86400)/3600 ))
    elif [[ $diff -ge 3600 ]]; then printf "%dh %dm" $(( diff/3600 )) $(( (diff%3600)/60 ))
    else printf "%dm" $(( diff/60 )); fi
}

lc() {
    if   [[ $1 -lt 50 ]]; then echo "$GREEN"
    elif [[ $1 -lt 80 ]]; then echo "$YELLOW"
    else echo "$RED"; fi
}

# ── Rate limits (aligned sub-fields) ─────────────────────────────────────────
s_label="session"; s_pct=""; s_time=""; sc=""
if [[ -n "$five_h_pct" ]]; then
    sv=$(printf "%.0f" "$five_h_pct"); sc=$(lc "$sv")
    s_pct="${sv}%"
    [[ -n "$five_h_reset" ]] && s_time=$(fmt_cd "$five_h_reset")
fi

w_label="weekly"; w_pct=""; w_time=""; wc=""
if [[ -n "$seven_d_pct" ]]; then
    wv=$(printf "%.0f" "$seven_d_pct"); wc=$(lc "$wv")
    w_pct="${wv}%"
    [[ -n "$seven_d_reset" ]] && w_time=$(fmt_cd "$seven_d_reset")
fi

lw=$(( ${#s_label} > ${#w_label} ? ${#s_label} : ${#w_label} ))
pw=$(( ${#s_pct}   > ${#w_pct}   ? ${#s_pct}   : ${#w_pct}   ))
tw=$(( ${#s_time}  > ${#w_time}  ? ${#s_time}  : ${#w_time}  ))

session_bit=""
if [[ -n "$s_pct" ]]; then
    session_bit=$(printf "%b%-*s%b %b%b%*s%b %b%*s%b" \
        "$GRAY" "$lw" "$s_label" "$R" \
        "$sc" "$B" "$pw" "$s_pct" "$R" \
        "$DIM" "$tw" "$s_time" "$R")
fi

weekly_bit=""
if [[ -n "$w_pct" ]]; then
    weekly_bit=$(printf "%b%-*s%b %b%b%*s%b %b%*s%b" \
        "$GRAY" "$lw" "$w_label" "$R" \
        "$wc" "$B" "$pw" "$w_pct" "$R" \
        "$DIM" "$tw" "$w_time" "$R")
fi

# ── Right side ───────────────────────────────────────────────────────────────
right=""
[[ -n "$session_name" ]] && right="${GRAY}[s] ${session_name}${R}"

# ── Effort level (read from settings) ────────────────────────────────────────
effort=$(jq -r '.effortLevel // "medium"' ~/.claude/settings.json 2>/dev/null)
case "$effort" in
    low)  effort_display="${GREEN}o low${R}" ;;
    high) effort_display="${RED}* high${R}" ;;
    *)    effort_display="${YELLOW}~ med${R}" ;;
esac

# ── Line 1: identity + turn + effort ────────────────────────────────────────
# ── Column helpers (visible length, strip ANSI) ─────────────────────────────
vlen() {
    local s=$1
    s=$(printf '%b' "$s" | sed 's/\x1b\[[0-9;]*m//g')
    echo -n "${#s}"
}
pad() {
    local s=$1 w=$2
    local l; l=$(vlen "$s")
    local n=$(( w - l ))
    [[ $n -lt 0 ]] && n=0
    printf '%b%*s' "$s" "$n" ''
}
mx() { [[ $1 -gt $2 ]] && echo "$1" || echo "$2"; }

# ── Build columns ────────────────────────────────────────────────────────────
c1a="${BLUE}${B}${dir}${R}${GRAY}/${R}${GREEN}${git_branch}${R}"
c1b="${MAGENTA}${short_model}${R}"

c2a="$session_bit"
c2b="$weekly_bit"

c3a="${GRAY}ctx${R} ${cc}${B}${used_int}%${R}"
c3b="$effort_display"

c4a="${GRAY}T#${R}${CYAN}${B}${turn}${R}"
c4b=""

c5a="$right"
c5b=""

w1=$(mx "$(vlen "$c1a")" "$(vlen "$c1b")")
w2=$(mx "$(vlen "$c2a")" "$(vlen "$c2b")")
w3=$(mx "$(vlen "$c3a")" "$(vlen "$c3b")")
w4=$(mx "$(vlen "$c4a")" "$(vlen "$c4b")")

SEP="  "
line1="$(pad "$c1a" "$w1")${SEP}$(pad "$c2a" "$w2")${SEP}$(pad "$c3a" "$w3")${SEP}$(pad "$c4a" "$w4")${SEP}${c5a}"
line2="$(pad "$c1b" "$w1")${SEP}$(pad "$c2b" "$w2")${SEP}$(pad "$c3b" "$w3")${SEP}$(pad "$c4b" "$w4")${SEP}${c5b}"

printf '%b\n%b' "$line1" "$line2"
