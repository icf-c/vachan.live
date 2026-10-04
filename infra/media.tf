# The demo video and its poster, kept out of git: a 14 MB file in two
# revisions is a repository nobody wants to clone. The bucket is served on
# media.vachan.live rather than the r2.dev subdomain, which is rate limited
# and meant for development. `just media` uploads. Provider 5.x cannot import
# the custom domain, so it is only ever created here.
resource "cloudflare_r2_bucket" "media" {
  account_id = var.cloudflare_account_id
  name       = var.media_bucket_name
  location   = "APAC"
}

resource "cloudflare_r2_custom_domain" "media" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.media.name
  domain      = var.media_domain
  zone_id     = local.zone_id
  enabled     = true
  min_tls     = "1.2"
}
