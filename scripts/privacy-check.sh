#!/usr/bin/env bash
# Prove the page's privacy line against what the edge actually serves.
#
#   scripts/privacy-check.sh                  # https://vachan.live/
#   scripts/privacy-check.sh https://vachan-live.pages.dev/
#
# The line on the page: no cookies, no analytics and no script from anyone,
# only the bot check on the form. So the served HTML may carry no external
# script (Turnstile loads itself on form focus), nothing under /cdn-cgi/
# (Rocket Loader, email obfuscation, Bot Fight Mode's JS detection all
# live there), and the response may set no cookie and ask the browser for
# no reports (NEL). Anyone can run the same curl; this is the version that
# fails loudly. Written 2026-10-04 when the live page turned out to carry
# rocket-loader.min.js and email-decode.min.js from zone defaults.
set -euo pipefail
url="${1:-https://vachan.live/}"
bust="v=$(date +%s)"
sep='?'; [[ "$url" == *\?* ]] && sep='&'
headers=$(curl -sS -D - -o /dev/null -A "privacy-check" "$url$sep$bust")
body=$(curl -sS -A "privacy-check" "$url$sep$bust")
fail=0
bad() { echo "FAIL: $1"; fail=1; }

# Scripts: only inline ones, which view-source shows in full.
srcs=$(printf '%s' "$body" | grep -oiE '<script[^>]+src="[^"]+"' | grep -oE 'src="[^"]+"' || true)
[[ -z "$srcs" ]] || bad "script tags with a src: $(echo "$srcs" | tr '\n' ' ')"
# Nothing of Cloudflare's injected into the page.
cdn=$(printf '%s' "$body" | grep -oE '/cdn-cgi/[^"'"'"' >]+' | sort -u || true)
[[ -z "$cdn" ]] || bad "Cloudflare injected: $(echo "$cdn" | tr '\n' ' ')"
# No beacon, no analytics host anywhere in the HTML.
printf '%s' "$body" | grep -qiE 'cloudflareinsights|googletagmanager|google-analytics|plausible|matomo|hotjar|segment\.io' && bad "an analytics host is in the HTML"
# Headers: no cookie, no reporting, a policy that names only the page, Turnstile and media.
printf '%s' "$headers" | grep -qi '^set-cookie:' && bad "a cookie is set: $(printf '%s' "$headers" | grep -i '^set-cookie:' | cut -c1-60)"
printf '%s' "$headers" | grep -qiE '^(nel|report-to):' && bad "NEL/report-to headers ask the browser to report to Cloudflare"
csp=$(printf '%s' "$headers" | grep -i '^content-security-policy:' || true)
[[ -n "$csp" ]] || bad "no Content-Security-Policy header"
[[ -n "$csp" ]] && printf '%s' "$csp" | grep -oE 'https?://[a-z0-9.-]+' | sort -u | grep -vE '^https://(challenges\.cloudflare\.com|media\.vachan\.live)$' | while read -r h; do echo "FAIL: policy allows $h"; done | grep -q . && fail=1
printf '%s' "$headers" | grep -qi '^referrer-policy: no-referrer' || bad "Referrer-Policy is not no-referrer"

if (( fail )); then echo "privacy-check: $url does not match the page's line"; exit 1; fi
echo "privacy-check: $url serves no external script, nothing from /cdn-cgi/, no cookie, no reporting"
