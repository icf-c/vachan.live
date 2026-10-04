# Zone-wide switches on the free plan. Only what the current API token may
# set is here; the rest (zone settings, WAF custom rule, cache rule, rate
# limit, Bot Fight Mode) sits on feature/zone-hardening until the token
# carries Zone Settings, Zone WAF, Bot Management, Cache Rules and Argo
# Tiered Caching edit.

# Tiered cache: misses stay inside Cloudflare instead of all reaching Pages.
resource "cloudflare_tiered_cache" "site" {
  zone_id = local.zone_id
  value   = "on"
}

# DNSSEC. Live only once the DS record (output dnssec_ds) is at the registrar.
resource "cloudflare_zone_dnssec" "site" {
  zone_id = local.zone_id
  status  = "active"
}
