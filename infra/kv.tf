# Where the addresses go. One key per address, the value a small JSON record.
# `just subscribers` lists them.
resource "cloudflare_workers_kv_namespace" "subscribers" {
  account_id = var.cloudflare_account_id
  title      = "vachan-live-subscribers"
}
