variable "port" {
  type    = number
  default = 2222
}

# From forgejo.sh: the throwaway Forgejo's API and its token.
variable "endpoint" {
  type = string
}

variable "token" {
  type      = string
  ephemeral = true
  sensitive = true
}

# CI sets these to apply an older release first, then upgrade.
variable "renovate_version" {
  type    = string
  default = null
}

variable "image_digest" {
  type    = string
  default = null
}

module "renovate" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  renovate_version = var.renovate_version
  image_digest     = var.image_digest

  platform     = "forgejo"
  endpoint     = var.endpoint
  token        = var.token
  repositories = ["renovate/demo"]
  git_author   = "Renovate <renovate@example.com>"

  # The demo repository has no renovate.json, so skip the onboarding pull
  # request and go straight to updates. The throwaway Forgejo doesn't know
  # its own address, so Renovate clones from the endpoint's.
  config = {
    gitUrl              = "endpoint"
    onboarding          = false
    requireConfig       = "optional"
    dependencyDashboard = false
  }
}
