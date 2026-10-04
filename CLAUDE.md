# CLAUDE.md - vachan.live

One page: the product's name, one sentence, the demo video, an email field.
Nothing on it may claim a feature that has not shipped, and the page never
mentions the cloud service until that exists.

Load the `voice` skill (professional) and `stop-slop` before touching any
prose here, the page copy included. `just voice` runs the checker on the
page's text.

`just check` is the gate before a push. The workflow deploys; see README.md
for the secrets it needs and the two-job shape (infra, then deploy).

The video is the long demo cut from `vachan/extension/demo/out/demo.mp4`
(not tracked there; this copy is the published one). Replace it by copying
the new file over `public/demo.mp4` and `public/poster.jpg`.

Open questions carry `@Yogesh(subject): …` markers in HTML comments; `just
check` fails if one reaches `dist/`.
