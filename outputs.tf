output "a1_public_ip" {
  description = "Public IP of the maxed Always Free Arm server."
  value       = oci_core_instance.a1.public_ip
}

output "a1_shape_summary" {
  description = "Configured A1 capacity."
  value       = "${var.a1_ocpus} OCPU / ${var.a1_memory_gbs} GB (boot ${var.a1_boot_volume_gbs} GB)"
}

output "a1_ssh_command" {
  description = "Convenience SSH command for the A1 server."
  value       = "ssh ubuntu@${oci_core_instance.a1.public_ip}"
}

output "micro_public_ips" {
  description = "Public IPs of the AMD micro instances."
  value       = oci_core_instance.micro[*].public_ip
}

output "autonomous_database_ids" {
  description = "OCIDs of the Always Free Autonomous Databases."
  value       = oci_database_autonomous_database.free[*].id
}

output "notification_topic_id" {
  description = "OCID of the notifications topic."
  value       = oci_ons_notification_topic.alerts.id
}

output "notification_subscription_state" {
  description = "Email subscription state. Must reach ACTIVE after you confirm the email."
  value       = oci_ons_subscription.email.state
}
