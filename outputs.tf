output "service" {
  description = "The systemd service that runs Renovate once, started by renovate.timer. Run it now with systemctl start renovate.service."
  value       = "renovate.service"
}

output "timer" {
  description = "The systemd timer that starts each run."
  value       = "renovate.timer"
}

output "image" {
  description = "The Renovate image each run uses."
  value       = local.image
}

output "config_file" {
  description = "Renovate's config on each host."
  value       = local.config
}
