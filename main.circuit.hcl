locals {
  image    = "${var.image_repository}:${var.renovate_version}@${var.image_digest}"
  etc      = "/etc/renovate"
  config   = "/etc/renovate/config.json"
  env_file = "/etc/renovate/token.env"
  cache    = "/var/cache/renovate"
  script   = "/usr/local/sbin/conn3x-renovate"
  unit     = "renovate"

  # The token stays out of this file, which is in the plan and state.
  # Renovate reads it from RENOVATE_TOKEN in the root-only env file.
  settings = merge(concat(
    [{ platform = var.platform, repositories = var.repositories }],
    [for e in [var.endpoint] : { endpoint = e } if e != null],
    [for a in [var.git_author] : { gitAuthor = a } if a != null],
    [var.config],
  )...)

  run_script = <<-EOT
    #!/bin/sh
    # Written by Conn3x. Changes here are overwritten on the next apply.
    # One Renovate run over the repositories in ${local.config}, from the
    # pinned image. The container shares the host's network, so it reaches a
    # forge on the host's loopback, and listens on nothing.
    exec podman run --rm --replace --name ${local.unit} --network host \
      --env-file ${local.env_file} \
      -e RENOVATE_CONFIG_FILE=/usr/src/app/config.json \
      -e LOG_LEVEL=${var.log_level} \
      -v ${local.config}:/usr/src/app/config.json:ro,z \
      -v ${local.cache}:/tmp/renovate:Z,U \
      ${local.image}
  EOT
}

circuit "renovate" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "podman" {
    package {
      name = "podman"
    }
  }

  # Pulled during the apply, so the config check below can use it and the
  # first run doesn't spend its time downloading.
  step "pull" {
    command {
      command = "podman pull -q ${local.image} >/dev/null"
      unless  = "podman image exists ${local.image}"
    }
  }

  step "etc" {
    directory {
      path  = local.etc
      owner = "root"
      group = "root"
      mode  = "0755"
    }
  }

  # Renovate's own validator reads the config as global config before it
  # replaces the old one, so a typo fails the apply rather than a run at
  # night. The config holds no secrets, so Renovate's user in the container
  # can read it.
  step "config" {
    file {
      path     = local.config
      content  = "${jsonencode(local.settings)}\n"
      owner    = "root"
      group    = "root"
      mode     = "0644"
      validate = "podman run --rm --network none -v %s:/config.json:ro,z --entrypoint renovate-config-validator ${local.image} --strict /config.json"
    }
  }

  # Write-only: the plan and state record only an HMAC of the content.
  step "token" {
    file {
      path       = local.env_file
      content_wo = join("", [for k, v in merge({ RENOVATE_TOKEN = var.token }, var.github_com_token == null ? {} : { GITHUB_COM_TOKEN = var.github_com_token }) : "${k}=${v}\n"])
      owner      = "root"
      group      = "root"
      mode       = "0600"
    }
  }

  # Clones, package caches and the tools Renovate installs as it needs them.
  # Podman hands it to the container's user, UID 12021, as each run starts.
  step "cache" {
    directory {
      path = local.cache
      mode = "0700"
    }
  }

  step "script" {
    file {
      path    = local.script
      content = local.run_script
      owner   = "root"
      group   = "root"
      mode    = "0755"
    }
  }

  step "schedule_valid" {
    command {
      command = "echo 'schedule is not a calendar expression systemd understands: ${var.schedule}' >&2; exit 1"
      unless  = "systemd-analyze calendar '${var.schedule}' >/dev/null"
    }
  }

  step "timer" {
    timer {
      name        = local.unit
      description = "Renovate dependency updates"
      on_calendar = var.schedule
      command     = local.script
      persistent  = true
    }
  }
}
