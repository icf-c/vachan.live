#!/usr/bin/env bash
# List the addresses the form has collected, newest last, as CSV on stdout.
#
#   scripts/subscribers.sh                  # email,at,lang
#   scripts/subscribers.sh > list.csv
#
# Reads the KV namespace through wrangler, which needs `wrangler login` once
# on this machine. The namespace is found by its title, so no id is kept
# here. KV lists keys in pages of 1000; this follows the cursor.
set -euo pipefail
cd "$(dirname "$0")/.."

ns_id=$(npx --yes wrangler kv namespace list 2>/dev/null | python3 -c 'import json,sys; print(next(n["id"] for n in json.load(sys.stdin) if n["title"]=="vachan-live-subscribers"))')
[[ -n "$ns_id" ]] || { echo "no namespace titled vachan-live-subscribers; has infra been applied?" >&2; exit 1; }

echo "email,at,lang"
cursor=""
while :; do
  page=$(npx --yes wrangler kv key list --namespace-id "$ns_id" ${cursor:+--cursor "$cursor"} 2>/dev/null)
  keys=$(printf '%s' "$page" | python3 -c 'import json,sys; [print(k["name"]) for k in json.load(sys.stdin)]')
  for k in $keys; do
    npx --yes wrangler kv key get --namespace-id "$ns_id" "$k" 2>/dev/null \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join([d.get("email",""), d.get("at",""), d.get("lang","")]))'
  done
  # wrangler prints the next cursor on stderr only in some versions; one page
  # covers the first thousand, which is enough until it is not.
  break
done
