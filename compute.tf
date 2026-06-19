# Maxed Always Free Arm server: 2 OCPU / 12 GB (the current ceiling as of 2026-06-15).
resource "oci_core_instance" "a1" {
  availability_domain = local.a1_availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-a1"
  shape               = var.a1_shape

  shape_config {
    ocpus         = var.a1_ocpus
    memory_in_gbs = var.a1_memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.a1_boot_volume_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "${var.name_prefix}-a1-vnic"
    hostname_label   = "afa1"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  freeform_tags = local.common_tags

  # The newest matching image OCID can change over time; don't recreate the VM for it.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

# AMD Always Free micro instances (1/8 OCPU, 1 GB each, fixed shape).
resource "oci_core_instance" "micro" {
  count               = var.enable_micros ? var.micro_count : 0
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-micro-${count.index + 1}"
  shape               = var.micro_shape

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_x86.images[0].id
    # No boot_volume_size_in_gbs: keep the image default (~47 GB) to stay
    # under the 200 GB pool alongside the 100 GB A1 boot volume.
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "${var.name_prefix}-micro-${count.index + 1}-vnic"
    hostname_label   = "afmicro${count.index + 1}"
    # Required for the Tailscale exit node: OCI's default source/dest check
    # drops packets whose source IP isn't the VNIC's own, which kills traffic
    # forwarded from tailscale0 out through ens3.
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  freeform_tags = local.common_tags

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
