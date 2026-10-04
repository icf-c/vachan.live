#!/usr/bin/env bash
# Build dist/ from public/: a copy, with the Turnstile site key written into
# index.html.
#
#   scripts/build.sh                 # TURNSTILE_SITE_KEY from the environment, else Cloudflare's test key
#
# The test key (1x00000000000000000000AA) renders a widget that always passes,
# so `just serve` shows the real form. The Function pairs it with the test
# secret when no TURNSTILE_SECRET binding is set, so a local submit works end
# to end against a local KV. In production the key comes from Terraform's
# output through the workflow; a key that is set but malformed fails the
# build here, because the site once shipped elsewhere with data-sitekey="-".
set -euo pipefail
cd "$(dirname "$0")/.."

key="${TURNSTILE_SITE_KEY:-}"
if [[ -n "$key" && ! "$key" =~ ^[0-9]x[0-9A-Za-z_-]{20,}$ ]]; then
  echo "TURNSTILE_SITE_KEY is set but is not a Turnstile site key (${#key} characters)" >&2
  exit 1
fi
[[ -n "$key" ]] || { key="1x00000000000000000000AA"; echo "build: no TURNSTILE_SITE_KEY, using Cloudflare's test key"; }

# Media URLs carry the commit as a query string, so a deploy after a re-cut
# fetches the new object instead of the edge's copy of the old one (the
# cache served the previous demo.mp4 for an hour after the upload once).
rev=$(git rev-parse --short HEAD 2>/dev/null || date +%s)

rm -rf dist
cp -R public dist
# sed -i differs between BSD and GNU; a temp file is portable.
sed -e "s|__TURNSTILE_SITE_KEY__|$key|g" -e "s|__MEDIA_V__|$rev|g" public/index.html > dist/index.html
grep -q "__TURNSTILE_SITE_KEY__" dist/index.html && { echo "placeholder survived the build" >&2; exit 1; }
echo "build: dist/ ($(du -sh dist | cut -f1)), site key ${key:0:4}…"
