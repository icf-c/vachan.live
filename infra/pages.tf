# A direct-upload project: the workflow builds and deploys with wrangler, so
# nothing reaches the site that has not passed `just check`. No git source
# block, so Pages never builds on its own.
#
# The names inside deployment_configs are exact. Terraform drops an unknown
# key in a nested object without a word; check a new one against
# `terraform providers schema -json`.
resource "cloudflare_pages_project" "site" {
  account_id        = var.cloudflare_account_id
  name              = "vachan-live"
  production_branch = "main"

  deployment_configs = {
    production = {
      compatibility_date = "2026-04-01"
      kv_namespaces = {
        SUBSCRIBERS = { namespace_id = cloudflare_workers_kv_namespace.subscribers.id }
      }
      env_vars = {
        TURNSTILE_SECRET = {
          type  = "secret_text"
          value = cloudflare_turnstile_widget.join.secret
        }
      }
    }
    preview = {
      compatibility_date = "2026-04-01"
      kv_namespaces = {
        SUBSCRIBERS = { namespace_id = cloudflare_workers_kv_namespace.subscribers.id }
      }
      env_vars = {
        TURNSTILE_SECRET = {
          type  = "secret_text"
          value = cloudflare_turnstile_widget.join.secret
        }
      }
    }
  }
}

resource "cloudflare_pages_domain" "apex" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.site.name
  name         = var.domain
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.site.name
  name         = "www.${var.domain}"
}
