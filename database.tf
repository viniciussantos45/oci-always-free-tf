# Always Free Autonomous Databases. is_free_tier fixes 1 ECPU / 20 GB and cannot
# scale; do not add cpu/storage scaling arguments or it leaves the free envelope.
resource "oci_database_autonomous_database" "free" {
  count          = var.adb_count
  compartment_id = var.compartment_id
  db_name        = "${var.adb_db_name_prefix}${count.index + 1}"
  display_name   = "${var.name_prefix}-adb-${count.index + 1}"
  admin_password = var.adb_admin_password
  db_workload    = var.adb_db_workload
  is_free_tier   = true

  freeform_tags = local.common_tags

  lifecycle {
    # Avoid noisy diffs from server-managed maintenance/patch attributes.
    ignore_changes = [db_version]
  }
}
