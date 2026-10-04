# vachan.live

The coming-soon page for Vachan: the name, one sentence, the demo video, and
an email field. One static page, one Pages Function, Terraform for the rest.

```
public/      the page and its assets (index.html, demo.mp4, poster.jpg, logo.svg)
functions/   subscribe.js, the email field's handler, a Cloudflare Pages Function
infra/       Pages project, custom domains, DNS, the Turnstile widget, the KV namespace
scripts/     build.sh (public/ -> dist/ with the site key), subscribers.sh (the list)
```

## Run it

```sh
just serve        # builds, then wrangler pages dev on :8788 with a local KV; the form works
just check        # build, markers, assets, the Function parses, the prose checker
just subscribers  # CSV of every address, through wrangler (needs `wrangler login`)
```

## How it deploys

The workflow in `.github/workflows/on-push.yml` is the only thing that
deploys. Every push runs two jobs:

1. `infra`: Terraform plan, and apply on `main`. It outputs the Turnstile
   site key, which the widget's secret half never leaves Cloudflare: Terraform
   writes it straight into the Pages project as the `TURNSTILE_SECRET` binding.
2. `deploy`: `just check` with that site key, then `wrangler pages deploy`.
   `main` is production, any other branch its own preview URL.

The Pages project is direct-upload. It has no git source, so Pages never
builds on its own and nothing reaches the site without `just check`.

GitHub secrets the workflow needs, and nothing else:

| secret | what |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Pages edit, Workers KV edit, Turnstile edit, DNS edit and Zone read on vachan.live |
| `CLOUDFLARE_ACCOUNT_ID` | the account |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | the Terraform state bucket `tfstate-yogeshlonkar`, key `vachan.live/infra.tfstate` |

Put them in `infra/.env.local` (gitignored, one `KEY=value` per line) and
run `just secrets`; it refuses an empty value or a lone hyphen.

The zone `vachan.live` must already be on the account; `infra/dns.tf` finds
it by name. No zone id secret, no Turnstile secret, no SMTP: the only
person-held values are the four above.

## What the form stores

The address, lower-cased, the time, and the first `Accept-Language` value,
in the KV namespace `vachan-live-subscribers`. No IP, no user agent, no
cookie. The page says "One email when it ships. Nothing else, and nothing
shared." and the code holds it to that.

## Things that bit once

- A Turnstile site key stored as a literal `-` once shipped on another site
  with `data-sitekey="-"`. `scripts/build.sh` refuses a key that is set but
  malformed, and the test key is used only when none is set at all.
- Terraform drops an unknown key inside a nested object silently. The
  attribute names in `infra/pages.tf` came from `terraform providers schema
  -json` for provider 5.26.0; check a new one the same way.
- Provider 5.26.0 reports an in-place DNS update as failed after it has
  applied; a re-run passes.
