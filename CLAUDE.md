# CLAUDE.md - vachan.live

One page: the product's name, a hero line, the demo video, the email
field, the three ways to get a voice (browser, local server, cloud) and the
privacy line. Nothing on it may claim a shipped feature that has not
shipped; the cloud path is described as what is coming (Yogesh's decision,
2026-10-04). Every zone switch in `infra/zone.tf` follows one rule: nothing
that puts a script, a cookie or a report into the visitor's browser, and
`just privacy` is the proof.

Load the `voice` skill (professional) and `stop-slop` before touching any
prose here, the page copy included. `just voice` runs the checker on the
page's text.

`just check` is the gate before a push. The workflow deploys; see README.md
for the secrets it needs and the two-job shape (infra, then deploy).

The video is the long demo cut from `vachan/extension/demo/out/demo.mp4`.
It is never committed: copy it and `poster.jpg` into `media/` and run
`just media`, which puts them on the R2 bucket behind media.vachan.live.

Open questions carry `@Yogesh(subject): …` markers in HTML comments; `just
check` fails if one reaches `dist/`.
