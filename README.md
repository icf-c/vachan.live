# vachan.live

The site for Vachan, the Chrome extension that reads a web page aloud: the
demo video, the email field for launch news, the three ways to get a voice
(browser, local server, cloud) and the privacy line. One static page, one
Pages Function, Terraform for the Cloudflare zone and the Pages project.

This is the site's repository, not the extension's. It takes no pull
requests; issues about the site are fine. AGPL-3.0, the same licence as
Vachan (`LICENSE`).

```
public/      the page and its small assets (index.html, logo.svg, favicon.png)
media/       the demo cut and its poster, gitignored, uploaded to R2 with `just media`
functions/   subscribe.js, the email field's handler, a Cloudflare Pages Function
infra/       Pages project, custom domains, DNS, the Turnstile widget, the KV namespace
scripts/     build.sh (public/ -> dist/ with the site key), media.sh (upload to R2), subscribers.sh (the list), privacy-check.sh (the page's privacy line, checked against the live edge)
```

## Run it

```sh
just serve        # builds, then wrangler pages dev on :8788 with a local KV; the form works
just check        # build, markers, assets, the Function parses, the prose checker
just media        # upload media/* to the R2 bucket served at media.vachan.live
just subscribers  # CSV of every address, through the API
just privacy      # curl the live page: no script src, nothing from /cdn-cgi/, no cookie, no NEL
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
| `CLOUDFLARE_API_TOKEN` | on vachan.live: Pages edit, Workers KV edit, Turnstile edit, R2 edit, DNS edit, Zone read, and for `infra/zone.tf` Zone Settings, Zone WAF, Bot Management, Cache Rules and Argo Tiered Caching edit; add Cache Purge if `just media` should purge the edge (without it the per-commit `?v=` on the page covers the next deploy) |
| `CLOUDFLARE_ACCOUNT_ID` | the account |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | an R2 API token (Object Read & Write on the bucket `tfstates`), for the Terraform state |

Put them in `infra/.env.local` (gitignored, one `KEY=value` per line) and
run `just secrets`; it refuses an empty value or a lone hyphen.

The state bucket is created once, by hand or with `just state-bucket`
(wrangler, needs the API token in the environment). The account is the one
that holds vachan.live.

The zone `vachan.live` must already be on the account; `infra/dns.tf` finds
it by name. No zone id secret, no Turnstile secret, no SMTP: the only
person-held values are the four above.

## The video

`public/` carries nothing bigger than an icon. The demo cut and its poster
sit in `media/` (gitignored) and on the R2 bucket `media-vachan-live`,
served at media.vachan.live, which `infra/media.tf` creates. After a re-cut:
copy the new files into `media/`, `just media`. The repository's history
was rewritten on 2026-10-04 to drop the two revisions of the video that had
been committed before this.

## What the form stores

The address, lower-cased, the time, whether the beta box was ticked, and the
first `Accept-Language` value,
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
