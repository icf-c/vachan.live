#!/usr/bin/env bash
# Upload the page's media to the R2 bucket it is served from.
#
#   scripts/media.sh                 # every file under media/ -> media-vachan-live, served at https://media.vachan.live/<name>
#   scripts/media.sh media/demo.mp4  # one file
#
# media/ is gitignored: the demo cut is 14 MB and changes with every re-cut,
# and git keeps every revision forever. Copy the current cut in from
# vachan/extension/demo/out/ (demo.mp4, poster.jpg), then run this. Needs
# CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment
# (`set -a; source infra/.env.local; set +a`); the Justfile recipe does that.
#
# wrangler guesses the content type from the extension; it is passed
# explicitly because a video served as application/octet-stream will not
# play inline in Safari.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is not set}"
bucket="media-vachan-live"
files=("$@")
[[ ${#files[@]} -gt 0 ]] || files=(media/*)
for f in "${files[@]}"; do
  [[ -f "$f" ]] || { echo "no file $f" >&2; exit 1; }
  name=$(basename "$f")
  case "$name" in
    *.mp4) type="video/mp4" ;; *.jpg|*.jpeg) type="image/jpeg" ;; *.png) type="image/png" ;; *.webm) type="video/webm" ;; *.gif) type="image/gif" ;; *) type="application/octet-stream" ;;
  esac
  npx --yes wrangler r2 object put "$bucket/$name" --file "$f" --content-type "$type" --remote >/dev/null
  printf '  %-14s %7s  https://media.vachan.live/%s\n' "$name" "$(du -h "$f" | cut -f1)" "$name"
done
