#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s on|off|status [config]\n' "$(basename "$0")" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

mode="$1"
config="${2:-$HOME/.config/karabiner/karabiner.json}"

case "$mode" in
  on|off|status) ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ ! -f "$config" ]]; then
  printf 'missing config: %s\n' "$config" >&2
  exit 1
fi

filter_status='
  .profiles[0].devices[]
  | select(.identifiers.vendor_id == 13364 and .identifiers.product_id == 560)
  | if (.simple_modifications // [] | length) > 0 then "on" else "off" end
'

if [[ "$mode" == "status" ]]; then
  jq -r "$filter_status" "$config"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [[ "$mode" == "on" ]]; then
  jq '
    .profiles |= map(
      .complex_modifications.rules = (.complex_modifications.rules // [] | map(select(.description != "Swap left and right Option/Command on Keychron")))
      | .devices = (.devices // [] | map(
          if (.identifiers.vendor_id == 13364 and .identifiers.product_id == 560) then
            .simple_modifications = [
              {"from":{"key_code":"left_option"},"to":[{"key_code":"left_command"}]},
              {"from":{"key_code":"left_command"},"to":[{"key_code":"left_option"}]},
              {"from":{"key_code":"right_option"},"to":[{"key_code":"right_command"}]},
              {"from":{"key_code":"right_command"},"to":[{"key_code":"right_option"}]}
            ]
          else
            .
          end
        ))
    )
  ' "$config" > "$tmp"
else
  jq '
    .profiles |= map(
      .complex_modifications.rules = (.complex_modifications.rules // [] | map(select(.description != "Swap left and right Option/Command on Keychron")))
      | .devices = (.devices // [] | map(
          if (.identifiers.vendor_id == 13364 and .identifiers.product_id == 560) then
            del(.simple_modifications)
          else
            .
          end
        ))
    )
  ' "$config" > "$tmp"
fi

jq empty "$tmp"
mv "$tmp" "$config"
trap - EXIT

printf 'Keychron modifier swap: %s\n' "$mode"
