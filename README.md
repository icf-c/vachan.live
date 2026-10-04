# vachan.live

The site for Vachan, the Chrome extension that reads a web page aloud: the
demo video, the email field for launch news, the three ways to get a voice
(browser, local server, cloud) and the privacy line. One static page, one
Pages Function, Terraform for the Cloudflare zone and the Pages project.

This is the site's repository, not the extension's. It takes no pull
requests; issues about the site are fine. AGPL-3.0, the same licence as
Vachan (`LICENSE`).

Running it and how it deploys: `infra/README.md`.

## What the form stores

The address, lower-cased, the time, whether the beta box was ticked, and the
first `Accept-Language` value,
in the KV namespace `vachan-live-subscribers`. No IP, no user agent, no
cookie. The page says "One email when it ships. Nothing else, and nothing
shared." and the code holds it to that.
