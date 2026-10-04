variable "cloudflare_account_id" {
  description = "The Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "A Cloudflare API token: Pages, Workers KV, Turnstile, DNS and zone read on vachan.live"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "The zone, which must already be on this Cloudflare account"
  type        = string
  default     = "vachan.live"
}
