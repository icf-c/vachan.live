#!/usr/bin/env bash
# Copy the workflow's secrets from an env file to GitHub Actions.
#
#   usage: scripts/set-secrets.sh [env-file] [--dry-run]
#
# The env file defaults to infra/.env.local, which is gitignored. Values are
# never printed, only their length. The four keys are the only secrets the
# workflow reads (README.md).
#
# Why the pipe has no --body: `gh secret set NAME --body -` stores the one
# character "-"; gh reads stdin only when --body is absent. That once shipped
# a site with data-sitekey="-". A value that is empty or a lone hyphen is
# refused here.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file="$root/infra/.env.local"
dry=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) file="$arg" ;;
  esac
done
[[ -f "$file" ]] || { echo "no env file at $file" >&2; exit 1; }

keys=(CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY)

read_value() {
  local key="$1" line value
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$file" | head -1 || true)"
  value="${line#*=}"; value="${value%$'\r'}"
  if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi
  printf '%s' "$value"
}

failed=0
for key in "${keys[@]}"; do
  value="$(read_value "$key")"
  if [[ -z "$value" || "$value" == "-" ]]; then printf '  %-24s missing or a lone hyphen, skipped\n' "$key"; failed=1; continue; fi
  if [[ "$dry" -eq 1 ]]; then printf '  %-24s would set, %d chars\n' "$key" "${#value}"; continue; fi
  if printf '%s' "$value" | gh secret set "$key" >/dev/null; then printf '  %-24s set, %d chars\n' "$key" "${#value}"; else printf '  %-24s FAILED\n' "$key"; failed=1; fi
done
exit "$failed"
