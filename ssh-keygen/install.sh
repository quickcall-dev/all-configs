#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -e, --email <email>        Key email/comment (required)
  -u, --username <username>  SSH username (default: current user)
  -H, --hostname <hostname>  Target host (default: github.com)
  -k, --keyname <name>       Output key filename (default: id_ed25519_<hostname>)
  -c, --comment <comment>    Key comment (default: <email>)
  -h, --help                 Show this help

Examples:
  ${0##*/} -e sagar@example.com -u sagar -H github.com
USAGE
  exit 0
}

EMAIL="${EMAIL:-}"
USERNAME="${USERNAME:-$(whoami)}"
HOSTNAME="${HOSTNAME:-github.com}"
KEYNAME="${KEYNAME:-}"
COMMENT="${COMMENT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--email) EMAIL="$2"; shift 2 ;;
    -u|--username) USERNAME="$2"; shift 2 ;;
    -H|--hostname) HOSTNAME="$2"; shift 2 ;;
    -k|--keyname) KEYNAME="$2"; shift 2 ;;
    -c|--comment) COMMENT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -n "$EMAIL" ]] || { fail "--email is required"; usage; }

if [[ -z "$KEYNAME" ]]; then
  # strip domain suffix, e.g. github.com -> github
  KEYNAME="id_ed25519_${HOSTNAME%%.*}"
fi
[[ -n "$COMMENT" ]] || COMMENT="$EMAIL"

KEY_PATH="$HOME/.ssh/$KEYNAME"
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"

step "Generating SSH key"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$KEY_PATH" ]]; then
  warn "key already exists: $KEY_PATH"
else
  ssh-keygen -t ed25519 -C "$COMMENT" -f "$KEY_PATH" -N ""
  ok "key generated: $KEY_PATH"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

step "Adding key to ssh-agent"

if command -v ssh-agent &>/dev/null && [[ -n "${SSH_AGENT_PID:-}" ]]; then
  ssh-add "$KEY_PATH" 2>/dev/null && ok "key added to ssh-agent" || warn "ssh-add failed"
else
  warn "ssh-agent not running — skipping ssh-add"
fi

step "Updating SSH config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  touch "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
fi

HOST_ALIAS="$HOSTNAME"

# Remove existing block for this host if present
if grep -q "# ssh-keygen: $HOST_ALIAS" "$CONFIG_FILE" 2>/dev/null; then
  sed -i "/# ssh-keygen: $HOST_ALIAS/,/# end ssh-keygen: $HOST_ALIAS/d" "$CONFIG_FILE"
fi

cat >> "$CONFIG_FILE" << EOF
# ssh-keygen: $HOST_ALIAS
Host $HOST_ALIAS
    HostName $HOSTNAME
    User $USERNAME
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
# end ssh-keygen: $HOST_ALIAS
EOF

ok "SSH config updated: $CONFIG_FILE"

step "Testing GitHub SSH authentication"

if [[ "$HOSTNAME" == "github.com" ]]; then
  if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i "$KEY_PATH" -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    ok "GitHub SSH authentication works"
  else
    warn "GitHub SSH authentication failed — add the public key to GitHub first"
  fi
else
  warn "hostname is not github.com — skipping GitHub auth test"
fi

echo ""
echo -e "  ${GRN}Done!${R} Public key: ${CYN}$KEY_PATH.pub${R}"
echo ""
echo -e "  ${D}Add this to $HOSTNAME:${R}"
echo ""
cat "$KEY_PATH.pub"
echo ""
