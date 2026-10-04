# Read by the workflow after plan or apply, and baked into the HTML.
output "turnstile_site_key" {
  value = cloudflare_turnstile_widget.join.sitekey
}

output "pages_subdomain" {
  value = cloudflare_pages_project.site.subdomain
}
