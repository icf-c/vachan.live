# vachan.live

[![The demo: a Wikipedia page read aloud with the spoken word lit](https://media.vachan.live/poster.jpg)](https://vachan.live/)

The site at [vachan.live](https://vachan.live/) for Vachan, the Chrome
extension that reads a web page aloud: the demo video, the email field for
launch news, the three ways to get a voice (browser, local server, cloud)
and the privacy line. One static page, one Pages Function, Terraform for
the Cloudflare zone and the Pages project.

This is the site's repository, not the extension's. It takes no pull
requests; issues about the site are fine. AGPL-3.0, the same licence as
Vachan (`LICENSE`).

Running it and how it deploys: `infra/README.md`.

## The privacy line, checked

The page says it sets no cookie, runs no analytics and loads no script from
anyone but the bot check on the form. `scripts/privacy-check.sh` (`just
privacy`) fetches the live page the way any visitor would and fails if:

- the HTML carries a script `src`, anything under `/cdn-cgi/`, or an
  analytics host;
- the response sets a cookie;
- the response asks the browser to report errors to Cloudflare (NEL);
- the Content-Security-Policy names a host other than Turnstile and the
  media bucket;
- the referrer policy is anything but `no-referrer`.

These are checks on what the edge serves, not proof of what Cloudflare does
inside. The zone's switches are in `infra/zone.tf` and follow one rule:
nothing that puts a script, a cookie or a report into the visitor's
browser.

## What the form does and stores

`functions/subscribe.js` answers the submit:

- a filled honeypot field (`website`) gets a quiet OK and nothing is written;
- the address is trimmed and lower-cased and must look like one;
- the Turnstile token is verified with Cloudflare;
- then one KV write, keyed by the address, in the namespace
  `vachan-live-subscribers`.

What that write holds:

- the address;
- the time of the first submit;
- whether the beta box was ticked;
- the first `Accept-Language` value.

A second submit of the same address can only add the beta flag; it never
clears it and never moves the time. No IP, no user agent, no cookie. The
page says "One email when it ships. Nothing else, and nothing shared." and
the code holds it to that.

To come off the list, write to vachan@icf-c.com from the address you
submitted, or name it; the key is deleted by hand and nothing else is kept.
