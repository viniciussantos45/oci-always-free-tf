resource "oci_ons_notification_topic" "alerts" {
  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-alerts"
  description    = "Always Free guardrail and resource alerts"
  freeform_tags  = local.common_tags
}

# Email subscription stays PENDING until you click the confirmation link.
resource "oci_ons_subscription" "email" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.alerts.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
  freeform_tags  = local.common_tags
}

# Warn when sustained CPU is high (helps catch runaway/unexpected workloads).
resource "oci_monitoring_alarm" "instance_cpu" {
  compartment_id        = var.compartment_id
  display_name          = "${var.name_prefix}-cpu-high"
  metric_compartment_id = var.compartment_id
  namespace             = "oci_computeagent"
  query                 = "CpuUtilization[5m].mean() > 85"
  severity              = "WARNING"
  destinations          = [oci_ons_notification_topic.alerts.id]
  is_enabled            = true
  pending_duration      = "PT5M"
  body                  = "Always Free instance CPU above 85% for 5 minutes. Review usage."
  freeform_tags         = local.common_tags
}
