# The zone is looked up by name rather than carried as a secret: vachan.live
# is public, and one fewer GitHub secret is one fewer thing to set to "-".
data "cloudflare_zones" "site" {
  name = var.domain
}

locals {
  zone_id = data.cloudflare_zones.site.result[0].id
}

# Provider 5.26.0 reports "inconsistent result after apply" on an in-place
# update of a DNS record (modified_on); the change lands, the job reports red,
# a re-run passes. https://github.com/cloudflare/terraform-provider-cloudflare/issues/7387

resource "cloudflare_dns_record" "apex" {
  zone_id = local.zone_id
  name    = "@"
  content = cloudflare_pages_project.site.subdomain
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "www" {
  zone_id = local.zone_id
  name    = "www"
  content = cloudflare_pages_project.site.subdomain
  type    = "CNAME"
  proxied = true
  ttl     = 1
}
