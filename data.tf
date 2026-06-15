# Availability domains in the home region. A1 capacity varies by AD; switch
# availability_domain_index if you hit "Out of host capacity".
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
}

# Latest Ubuntu 22.04 image compatible with the Arm A1 shape (aarch64).
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.a1_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Latest Ubuntu 22.04 image compatible with the AMD micro shape (x86_64).
data "oci_core_images" "ubuntu_x86" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.micro_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
