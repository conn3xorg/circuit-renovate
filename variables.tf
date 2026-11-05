variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}


variable "platform" {
  type        = string
  description = "Where the repositories live: \"github\", \"gitlab\", \"forgejo\", \"gitea\", \"bitbucket\", \"bitbucket-server\" or \"azure\"."

  validation {
    condition     = contains(["github", "gitlab", "forgejo", "gitea", "bitbucket", "bitbucket-server", "azure"], var.platform)
    error_message = "platform must be one of github, gitlab, forgejo, gitea, bitbucket, bitbucket-server or azure."
  }
}

variable "endpoint" {
  type        = string
  default     = null
  description = "The platform's API address, such as \"https://git.example.com/api/v1\" for Forgejo or \"https://gitlab.example.com/api/v4\". When null, the platform's public service, such as GitHub.com."

  validation {
    condition     = var.endpoint == null || can(regex("^https?://[^\\s]+$", coalesce(var.endpoint, "-")))
    error_message = "endpoint must be an http or https address."
  }
}

variable "repositories" {
  type        = list(string)
  description = "Repositories to run on, such as [\"acme/api\", \"acme/web\"]. The token's account needs write access to each."

  validation {
    condition     = length(var.repositories) > 0 && alltrue([for r in var.repositories : can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$", r))])
    error_message = "repositories must list at least one repository, as owner/name or group/subgroup/name."
  }
}

variable "token" {
  type        = string
  ephemeral   = true
  sensitive   = true
  description = "Access token for the platform, for the account Renovate opens pull requests as. It goes to a root-only env file, written from the ephemeral value, and never reaches the plan or state. Pass it at run time with -var or TF_VAR_token."

  validation {
    condition     = length(var.token) > 0 && !strcontains(var.token, "\n")
    error_message = "token must be one line and can't be empty."
  }
}

variable "github_com_token" {
  type        = string
  default     = null
  ephemeral   = true
  sensitive   = true
  description = "A read-only GitHub.com token, for release notes and lookups on GitHub when platform isn't github. Without one, GitHub's rate limit for anonymous calls applies. Kept out of the plan and state like token."

  validation {
    condition     = !strcontains(coalesce(var.github_com_token, "-"), "\n")
    error_message = "github_com_token must be on one line."
  }
}

variable "git_author" {
  type        = string
  default     = null
  description = "Author of Renovate's commits, such as \"Renovate Bot <bot@example.com>\". When null, Renovate's default, or the token account's details on platforms that give them."

  validation {
    condition     = var.git_author == null || can(regex("^[^<>\\n]+ <[^<>@\\s]+@[^<>\\s]+>$", coalesce(var.git_author, "-")))
    error_message = "git_author must look like \"Name <email@example.com>\"."
  }
}

variable "config" {
  type        = any
  default     = {}
  nullable    = false
  description = "More of Renovate's self-hosted and repository options, merged over the ones above, such as { onboarding = false, requireConfig = \"optional\" }. Renovate's validator checks them before they're written. Put no secrets here: the config is in the plan and state."
}

variable "schedule" {
  type        = string
  default     = "hourly"
  description = "When Renovate runs, as a systemd calendar expression, such as \"hourly\" or \"*-*-* 02:00:00\". A run missed while the host was off happens at the next boot. Renovate's own schedule option still decides when it opens pull requests."
}

variable "log_level" {
  type        = string
  default     = "info"
  description = "How much Renovate logs to the journal: \"debug\", \"info\", \"warn\" or \"error\"."

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level must be debug, info, warn or error."
  }
}

variable "renovate_version" {
  type        = string
  default     = "44.220.0"
  nullable    = false
  description = "Tag of the Renovate image, such as \"44.220.0\". Change image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.renovate_version))
    error_message = "renovate_version must be an image tag, such as \"44.220.0\"."
  }
}

variable "image_digest" {
  type        = string
  default     = "sha256:71599a2007228ada2cc6acb5ed836cf2c088537ffe76dafee1ee6a1c5c45d5e5"
  nullable    = false
  description = "Digest of the image for renovate_version, such as \"sha256:7159...\". Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "image_repository" {
  type        = string
  default     = "ghcr.io/renovatebot/renovate"
  description = "Where to pull Renovate's image from. \"docker.io/renovate/renovate\" serves the same image, by the same digest."

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+$", var.image_repository))
    error_message = "image_repository must be a registry and path without a tag, such as \"ghcr.io/renovatebot/renovate\"."
  }
}
