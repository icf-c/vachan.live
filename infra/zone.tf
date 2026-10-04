# Zone-wide switches on the free plan: TLS, protocols, cache, security,
# DNSSEC. One resource per setting, as the provider models them. Rule for
# every switch: nothing that puts a script, a cookie or a report into the
# visitor's browser; scripts/privacy-check.sh is the proof. Anything
# Pro-only (Polish, Mirage, image resizing, the OWASP ruleset, Super Bot
# Fight Mode) is absent on purpose.
#
# The API token needs, beyond what pages.tf already uses: Zone Settings
# Edit, Zone WAF Edit, Bot Management Edit, Cache Rules Edit, Argo Tiered
# Caching Edit. Without them the plan fails on these resources with 9109.

locals {
  zone_settings = {
    # SSL/TLS. Pages is the origin, so strict costs nothing.
    ssl                      = "strict"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    opportunistic_encryption = "off"
    # Protocols. 0-RTT is fine: the only POST is /subscribe, which the
    # Turnstile token makes single-use, so a replayed early request fails.
    http2             = "on"
    http3             = "on"
    "0rtt"            = "on"
    h2_prioritization = "on"
    # Cache. browser_cache_ttl 0 is "respect existing headers"; the long
    # TTLs for static files come from the cache rule below and public/_headers.
    cache_level       = "aggressive"
    browser_cache_ttl = 0
    # Off: Pages does not go down, and on, the Internet Archive crawls the site.
    always_online = "off"
    early_hints   = "on"
    rocket_loader = "off"
    brotli        = "on"
    # Security.
    # "low" challenges only the worst reputations: a challenge sets a
    # cf_clearance cookie, and the page promises no cookies.
    security_level = "low"
    browser_check  = "on"
    challenge_ttl  = 1800
    # Off: on, Cloudflare injects email-decode.min.js into the page.
    email_obfuscation   = "off"
    hotlink_protection  = "off" # the poster and video are meant to be embedded
    server_side_exclude = "off"
  }
}

resource "cloudflare_zone_setting" "each" {
  for_each   = local.zone_settings
  zone_id    = local.zone_id
  setting_id = each.key
  value      = each.value
}

# HSTS: six months, subdomains (media. is proxied too), no preload until
# the site has lived on HTTPS a while; preload is close to irreversible.
resource "cloudflare_zone_setting" "hsts" {
  zone_id    = local.zone_id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      max_age            = 15552000
      include_subdomains = true
      preload            = false
      nosniff            = true
    }
  }
}

# Tiered cache: misses stay inside Cloudflare instead of all reaching Pages.
resource "cloudflare_tiered_cache" "site" {
  zone_id = local.zone_id
  value   = "on"
}

resource "cloudflare_argo_tiered_caching" "site" {
  zone_id = local.zone_id
  value   = "on"
}

# Bot Fight Mode stays off: on the free plan it injects a JavaScript
# detection script into every HTML page and sets __cf_bm, and neither can
# be switched off (developers.cloudflare.com/bots/get-started/bot-fight-mode).
# The probe paths are blocked by the WAF rule below instead. The AI
# crawler block is a managed rule, nothing in the page.
resource "cloudflare_bot_management" "site" {
  zone_id            = local.zone_id
  fight_mode         = false
  ai_bots_protection = "block"
}

# Network Error Logging off: with it, browsers report failed requests to
# a.nel.cloudflare.com, a report leaving the visitor's machine.
resource "cloudflare_zone_setting" "nel" {
  zone_id    = local.zone_id
  setting_id = "nel"
  value = {
    enabled = false
  }
}

# One custom WAF rule for the probe paths. /.well-known/acme-challenge/ and
# /cdn-cgi/ are not in it: certificate issuance and Cloudflare's own scripts.
resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = local.zone_id
  name        = "Probe paths"
  description = "Block the paths only scanners ask for"
  kind        = "zone"
  phase       = "http_request_firewall_custom"
  rules = [{
    action      = "block"
    description = "Scanner probes: .env, .git, config.json, wp-config, phpunit"
    enabled     = true
    expression  = "(http.request.uri.path contains \"/.env\") or (http.request.uri.path contains \"/.git\") or (http.request.uri.path eq \"/config.json\") or (http.request.uri.path contains \"wp-config\") or (http.request.uri.path contains \"/vendor/phpunit\")"
  }]
}

# Cache rules: never cache the form's endpoint; static files for a month at
# the edge and in the browser. HTML stays on Pages' own caching.
resource "cloudflare_ruleset" "cache" {
  zone_id     = local.zone_id
  name        = "Cache"
  description = "Static files a month, the Function never"
  kind        = "zone"
  phase       = "http_request_cache_settings"
  rules = [
    {
      action      = "set_cache_settings"
      description = "Never cache /subscribe"
      enabled     = true
      expression  = "(http.request.uri.path eq \"/subscribe\")"
      action_parameters = {
        cache = false
      }
    },
    {
      action      = "set_cache_settings"
      description = "Static files: a month at the edge and in the browser"
      enabled     = true
      expression  = "(http.request.uri.path.extension in {\"jpg\" \"jpeg\" \"png\" \"webp\" \"avif\" \"gif\" \"css\" \"js\" \"woff2\" \"svg\" \"ico\" \"mp4\"})"
      action_parameters = {
        cache = true
        edge_ttl = {
          mode    = "override_origin"
          default = 2592000
        }
        browser_ttl = {
          mode    = "override_origin"
          default = 2592000
        }
      }
    },
  ]
}

# The one free rate-limiting rule, spent on the form: more than 10 posts
# in 10 s from one address is blocked. Free counts by IP over 10 s and
# mitigates for 10 s; longer windows are paid.
resource "cloudflare_ruleset" "ratelimit" {
  zone_id     = local.zone_id
  name        = "Rate limit"
  description = "The form, by address"
  kind        = "zone"
  phase       = "http_ratelimit"
  rules = [{
    action      = "block"
    description = "/subscribe: 10 requests per 10 s per address"
    enabled     = true
    expression  = "(http.request.uri.path eq \"/subscribe\")"
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 10
      mitigation_timeout  = 10
    }
  }]
}

# DNSSEC. Live only once the DS record below is at the registrar.
resource "cloudflare_zone_dnssec" "site" {
  zone_id = local.zone_id
  status  = "active"
}
