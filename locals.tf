locals {
  common_tags = {
    cost_class = "always-free"
    managed_by = "terraform"
    owner      = var.owner_tag
    project    = "oci-always-free-tf"
  }

  # Minimal cloud-init: refresh package metadata on first boot. Extend as needed.
  cloud_init = <<-EOT
    #cloud-config
    package_update: true
  EOT
}
