#!/usr/bin/env bash
# Multi-GitHub account setup — never push as the wrong account again.
#
# What it does:
#   1. Generates one ed25519 key per GitHub account (reuses existing keys).
#   2. Adds SSH host aliases:  github.com -> personal, github-<work> -> work.
#   3. Adds a directory-scoped git identity (includeIf) for the work dir, so
#      commits there are authored as the work account automatically.
#   4. Rewrites all github.com remote URLs inside the work dir to the work
#      SSH alias — https remotes work too, authenticated as the work account.
#
# After running: add each printed public key to its GitHub account at
# https://github.com/settings/ssh/new (while logged in as that account).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options: (all required — this script stores no account names or emails)
  -p, --personal <name>    Personal GitHub account/login; also the SSH key suffix
  -w, --work <name>        Work GitHub account/login; also the SSH key suffix
  -d, --work-dir <path>    Directory whose repos use the work account
  -W, --work-email <email> Work commit email (e.g. <id>+<login>@users.noreply.github.com)
  -h, --help               Show this help

Environment variables: GH_PERSONAL, GH_WORK, GH_WORK_DIR, GH_WORK_EMAIL

Examples:
  ${0##*/} -p alice -w alice-corp -d "\$HOME/work" -W "12345+alice-corp@users.noreply.github.com"
  GH_PERSONAL=alice GH_WORK=alice-corp GH_WORK_DIR="\$HOME/work" GH_WORK_EMAIL="12345+alice-corp@users.noreply.github.com" ${0##*/}
USAGE
  exit 0
}

PERSONAL="${GH_PERSONAL:-}"
WORK="${GH_WORK:-}"
WORK_DIR="${GH_WORK_DIR:-}"
WORK_EMAIL="${GH_WORK_EMAIL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--personal)  PERSONAL="$2"; shift 2 ;;
    -w|--work)      WORK="$2"; shift 2 ;;
    -d|--work-dir)  WORK_DIR="$2"; shift 2 ;;
    -W|--work-email) WORK_EMAIL="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

# Interactive fallback (terminal or the TUI's pty): prompt for anything not given
if [[ -t 0 ]]; then
  [[ -n "$PERSONAL" ]]   || read -rp "  Personal GitHub login: " PERSONAL
  [[ -n "$WORK" ]]       || read -rp "  Work GitHub login: " WORK
  [[ -n "$WORK_DIR" ]]   || read -rp "  Directory for work repos (e.g. \$HOME/work): " WORK_DIR
  [[ -n "$WORK_EMAIL" ]] || read -rp "  Work commit email: " WORK_EMAIL
  WORK_DIR="${WORK_DIR/#\~/$HOME}"
fi

missing=()
[[ -z "$PERSONAL" ]] && missing+=("--personal")
[[ -z "$WORK" ]] && missing+=("--work")
[[ -z "$WORK_DIR" ]] && missing+=("--work-dir")
[[ -z "$WORK_EMAIL" ]] && missing+=("--work-email")
if [[ ${#missing[@]} -gt 0 ]]; then
  fail "Missing required options: ${missing[*]}"
  echo "  Run ${0##*/} --help for details. No account names or emails are stored in this script."
  exit 1
fi
if [[ "$PERSONAL" == "$WORK" ]]; then
  fail "--personal and --work must be different accounts"
  exit 1
fi

WORK_ALIAS="github-${WORK}"
SSH_CONFIG="$HOME/.ssh/config"
WORK_GITCONFIG="$HOME/.gitconfig-${WORK}"
MARK_BEGIN="# BEGIN multi-github (${PERSONAL} / ${WORK})"
MARK_END="# END multi-github"

# ---------------------------------------------------------------------------
step "Generating SSH keys (reuses existing)"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
for acct in "$PERSONAL" "$WORK"; do
  key="$HOME/.ssh/id_ed25519_${acct}"
  if [[ -f "$key" ]]; then
    ok "key exists: $key"
  else
    ssh-keygen -t ed25519 -C "${acct}@$(hostname -s 2>/dev/null || echo mac)" -f "$key" -N "" -q
    ok "generated: $key"
  fi
done

# ---------------------------------------------------------------------------
step "Writing SSH host aliases"
touch "$SSH_CONFIG"
backup_file "$SSH_CONFIG"
sed -i.bak "/$(echo "$MARK_BEGIN" | sed 's/[][\.*^$/]/\\&/g')/,/$(echo "$MARK_END" | sed 's/[][\.*^$/]/\\&/g')/d" "$SSH_CONFIG" 2>/dev/null || true
rm -f "$SSH_CONFIG.bak"
cat >> "$SSH_CONFIG" << EOF

$MARK_BEGIN
# github.com      -> $PERSONAL (personal, default everywhere)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_${PERSONAL}
  IdentitiesOnly yes

# ${WORK_ALIAS} -> $WORK (work account — use for work remotes)
Host ${WORK_ALIAS}
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_${WORK}
  IdentitiesOnly yes
$MARK_END
EOF
ok "ssh config → $SSH_CONFIG"
ok "aliases: github.com=${PERSONAL}, ${WORK_ALIAS}=${WORK}"

# ---------------------------------------------------------------------------
step "Configuring git identities"
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  git config --global user.name "$PERSONAL"
  ok "global git user.name → $PERSONAL"
else
  ok "global git user.name already set ($(git config --global user.name)) — leaving it"
fi

cat > "$WORK_GITCONFIG" << EOF
# Work identity — applies automatically to every repo under ${WORK_DIR}/
[user]
	name = ${WORK}
	email = ${WORK_EMAIL}

# Any GitHub remote in work dirs authenticates as ${WORK} via SSH,
# whether the remote URL is https or ssh.
[url "git@${WORK_ALIAS}:"]
	insteadOf = "git@github.com:"
	insteadOf = "https://github.com/"
EOF
ok "work gitconfig → $WORK_GITCONFIG"

# Idempotently register the includeIf in ~/.gitconfig
ABS_WORK_DIR="$(cd "$WORK_DIR" 2>/dev/null && pwd || echo "$WORK_DIR")"
if git config --global --get-all includeif.gitdir:"${ABS_WORK_DIR}/".path 2>/dev/null | grep -qF "$WORK_GITCONFIG"; then
  ok "includeIf already registered for ${ABS_WORK_DIR}/"
else
  git config --global includeIf.gitdir:"${ABS_WORK_DIR}/".path "$WORK_GITCONFIG"
  ok "includeIf registered: ${ABS_WORK_DIR}/ → $WORK_GITCONFIG"
fi

# ---------------------------------------------------------------------------
step "Your public keys — add each while logged in as that account"
echo ""
echo -e "  ${B}${WORK}${R} → paste at ${CYN}https://github.com/settings/ssh/new${R}:"
echo "  $(cat "$HOME/.ssh/id_ed25519_${WORK}.pub")"
echo ""
echo -e "  ${B}${PERSONAL}${R} → paste at ${CYN}https://github.com/settings/ssh/new${R}:"
echo "  $(cat "$HOME/.ssh/id_ed25519_${PERSONAL}.pub")"
echo ""

step "Verify (after adding keys to GitHub)"
echo -e "  ssh -T git@github.com        ${D}# expect: Hi ${PERSONAL}!${R}"
echo -e "  ssh -T git@${WORK_ALIAS}     ${D}# expect: Hi ${WORK}!${R}"
echo -e "  In a work repo: ${CYN}git var GIT_AUTHOR_IDENT${R} ${D}# expect ${WORK} identity${R}"
echo ""

step "Testing authentication (expected to fail until keys are added)"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -T "git@github.com" 2>&1 | sed 's/^/  /' || true
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -T "git@${WORK_ALIAS}" 2>&1 | sed 's/^/  /' || true
echo ""
ok "Done. Work repos under ${ABS_WORK_DIR}/ authenticate + commit as ${WORK}; everything else as ${PERSONAL}."
echo -e "  ${D}gh CLI note: gh commands still use the active account — check with 'gh auth status'.${R}"
