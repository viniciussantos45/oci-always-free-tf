#!/usr/bin/env bash
# Fail if a Terraform plan would create/update any resource type outside the
# approved Always Free allow-list. Run after `terraform plan -out=tfplan`.
#
# Usage:
#   terraform show -json tfplan > tfplan.json
#   ./scripts/check-plan.sh tfplan.json
set -euo pipefail

PLAN_JSON="${1:-tfplan.json}"

if [[ ! -f "$PLAN_JSON" ]]; then
  echo "ERROR: $PLAN_JSON not found. Run: terraform show -json tfplan > $PLAN_JSON" >&2
  exit 2
fi

ALLOWED='[
  "oci_core_vcn",
  "oci_core_internet_gateway",
  "oci_core_default_route_table",
  "oci_core_security_list",
  "oci_core_subnet",
  "oci_core_instance",
  "oci_database_autonomous_database",
  "oci_ons_notification_topic",
  "oci_ons_subscription",
  "oci_monitoring_alarm",
  "terraform_data"
]'

# Resource types being created or updated.
OFFENDERS=$(jq -r --argjson allowed "$ALLOWED" '
  [ .resource_changes[]
    | select(.change.actions | (index("create") or index("update")) != null)
    | .type ]
  | unique
  | map(select(. as $t | $allowed | index($t) | not))
  | .[]
' "$PLAN_JSON")

if [[ -n "$OFFENDERS" ]]; then
  echo "FAIL: plan contains resource types outside the Always Free allow-list:" >&2
  echo "$OFFENDERS" | sed 's/^/  - /' >&2
  exit 1
fi

echo "OK: plan only creates/updates allow-listed Always Free resources."
