# The widget in front of the email field. Terraform owns it so the site key
# and the secret never pass through a person: the key goes into the built
# HTML via the workflow, the secret into the Pages Function as a binding.
resource "cloudflare_turnstile_widget" "join" {
  account_id = var.cloudflare_account_id
  name       = "vachan.live join form"
  domains    = [var.domain, "www.${var.domain}"]
  mode       = "managed"
}
