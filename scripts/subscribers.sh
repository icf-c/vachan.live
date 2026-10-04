#!/usr/bin/env bash
# List the addresses the form has collected, as CSV on stdout.
#
#   scripts/subscribers.sh              # email,at,beta,lang
#   scripts/subscribers.sh > list.csv
#
# Reads the KV namespace through Cloudflare's API with CLOUDFLARE_API_TOKEN
# and CLOUDFLARE_ACCOUNT_ID from the environment (the Justfile recipe
# sources infra/.env.local). The first version went through wrangler, whose
# `kv key list` printed a banner around the JSON and the parse died silently
# behind a 2>/dev/null, so a store with one address listed as empty. The
# API returns JSON and nothing else; pages of 1000 follow the cursor.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is not set}"
api="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/storage/kv/namespaces"
auth="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

ns_id=$(curl -sf "$api" -H "$auth" | python3 -c 'import json,sys; print(next(n["id"] for n in json.load(sys.stdin)["result"] if n["title"]=="vachan-live-subscribers"))')

echo "email,at,beta,lang"
cursor=""
while :; do
  page=$(curl -sf "$api/$ns_id/keys?limit=1000${cursor:+&cursor=$cursor}" -H "$auth")
  for key in $(printf '%s' "$page" | python3 -c 'import json,sys; [print(k["name"]) for k in json.load(sys.stdin)["result"]]'); do
    curl -sf "$api/$ns_id/values/$key" -H "$auth" \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join([d.get("email",""), d.get("at",""), "yes" if d.get("beta") else "no", d.get("lang","")]))'
  done
  cursor=$(printf '%s' "$page" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result_info",{}).get("cursor") or "")')
  [[ -n "$cursor" ]] || break
done
