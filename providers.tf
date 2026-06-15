# Authenticates using a named profile in ~/.oci/config (created by
# `oci setup config`). The provider reads user OCID, fingerprint, key file, and
# key passphrase from that profile, so no secrets live in terraform.tfvars.
provider "oci" {
  auth                = "ApiKey"
  config_file_profile = var.config_file_profile
  region              = var.region
}
