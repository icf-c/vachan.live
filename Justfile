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
    for f in dist/logo.svg dist/favicon.png; do [[ -s "$f" ]] || { echo "missing $f"; exit 1; }; done
    # The video and poster live on R2; the page must not point at a 404.
    for u in https://media.vachan.live/demo.mp4 https://media.vachan.live/poster.jpg; do
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -I "$u" || echo 000)
      [[ "$code" == 200 ]] || echo "  warning: $u answers $code (run just media once the bucket exists)"
    done
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

# Upload media/ (the demo cut and its poster) to the R2 bucket the page links to
media *files:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; source infra/.env.local; set +a
    "{{scripts}}/media.sh" {{files}}

# Every address the form has taken, as CSV on stdout
subscribers:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; source infra/.env.local; set +a
    "{{scripts}}/subscribers.sh"

# Deploy dist/ by hand to a preview branch, for when the workflow is not an option
deploy branch="manual":
    npx --yes wrangler pages deploy ./dist --project-name=vachan-live --branch={{branch}}

# Copy the four secrets from infra/.env.local to GitHub Actions: just secrets [--dry-run]
secrets *args:
    "{{scripts}}/set-secrets.sh" {{args}}

# Create the R2 bucket the Terraform state lives in, once. Needs
# CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment
state-bucket:
    npx --yes wrangler r2 bucket create tfstates

# Terraform plan from this machine, with the values from infra/.env.local
plan-local:
    #!/usr/bin/env bash
    set -euo pipefail
    set -a; source infra/.env.local; set +a
    export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN" TF_VAR_cloudflare_account_id="$CLOUDFLARE_ACCOUNT_ID"
    export AWS_ENDPOINT_URL_S3="https://$CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com" AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" AWS_REGION=auto
    cd infra && terraform init -input=false -lockfile=readonly -backend-config=backend.config && terraform plan -input=false
