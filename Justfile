# vachan.live, the coming-soon page. `just` lists recipes.
#
# One static page in public/, one Pages Function in functions/, Terraform in
# infra/. The workflow deploys; nothing else does.

set shell := ["bash", "-euo", "pipefail", "-c"]

scripts := justfile_directory() / "scripts"

default:
    @just --list

# dist/ from public/, with the Turnstile site key written in (or the test key)
build:
    "{{scripts}}/build.sh"

# The built site with its Function, on a local KV and the Turnstile test
# secret, so a submit works end to end: just serve [port]
serve port="8788": build
    npx --yes wrangler pages dev dist --port {{port}} --kv SUBSCRIBERS

# What has to pass before a push lands: the build, no marker in dist/, the
# video and poster present, and the prose checker when it is installed
check: build
    #!/usr/bin/env bash
    set -euo pipefail
    if rg --hidden -q '@(Yogesh|claude)\(' dist; then echo "a marker reached dist/"; rg --hidden -n '@(Yogesh|claude)\(' dist; exit 1; fi
    for f in dist/demo.mp4 dist/poster.jpg dist/logo.svg dist/favicon.png; do [[ -s "$f" ]] || { echo "missing $f"; exit 1; }; done
    node --check functions/subscribe.js
    just voice
    echo "all checks passed"

# The prose on the page against the professional profile, when the checker is here
voice:
    #!/usr/bin/env bash
    set -euo pipefail
    checker="$HOME/.claude/skills/voice/voice-check.sh"
    if [[ ! -x "$checker" ]]; then echo "  voice checker not installed, skipping"; exit 0; fi
    # The page's prose only: tags stripped, scripts and styles dropped.
    tmp=$(mktemp -t vachan-copy).md
    python3 - "$tmp" <<'EOF'
    import re, sys, html
    s = open('public/index.html').read()
    s = re.sub(r'<(script|style)[^>]*>.*?</\1>', '', s, flags=re.S)
    t = html.unescape(re.sub(r'<[^>]+>', ' ', s))
    open(sys.argv[1], 'w').write(re.sub(r'[ \t]+', ' ', t))
    EOF
    VOICE_DEFAULT_PROFILE=professional "$checker" --profile professional "$tmp"

# Every address the form has taken, as CSV on stdout
subscribers:
    "{{scripts}}/subscribers.sh"

# Terraform plan from this machine, read-only: just plan
plan:
    cd infra && terraform init -input=false -lockfile=readonly -backend-config=backend.config && terraform plan -input=false

# Deploy dist/ by hand to a preview branch, for when the workflow is not an option
deploy branch="manual":
    npx --yes wrangler pages deploy ./dist --project-name=vachan-live --branch={{branch}}
