# OCI Always Free — Maxed Terraform Stack (us-ashburn-1)

Terraform for the **maximum Always Free** footprint Oracle Cloud allows in **US East (Ashburn)**,
centered on one maximally-sized Arm server, at a strict **US$0** (no Pay-As-You-Go upgrade, no trial
credits, nothing outside the verified Always Free envelope).

## What it provisions

| Component | Detail |
|---|---|
| Network | 1 VCN, Internet Gateway, default route table, security list, 1 public subnet |
| **Arm server (maxed)** | 1× `VM.Standard.A1.Flex` — **2 OCPU / 12 GB**, Ubuntu 22.04, 100 GB boot |
| AMD micros | 2× `VM.Standard.E2.1.Micro` — 1/8 OCPU, 1 GB, Ubuntu 22.04 (default ~47 GB boot) |
| Databases | 2× Autonomous Database, `is_free_tier = true` (1 ECPU / 20 GB each, OLTP) |
| Alerts | Notifications topic + email subscription + CPU monitoring alarm |

**Block storage budget:** 100 GB (A1) + ~47 GB + ~47 GB ≈ **194 GB**, under the 200 GB Always Free pool.

> **Heads-up — Arm limit halved on 2026-06-15.** Always Free A1 is now **2 OCPU / 12 GB** total
> (was 4/24). This stack maxes out the current ceiling, enforced by variable validation.

Excluded by design: MySQL HeatWave, Object Storage, Load Balancer, NoSQL (Phoenix-only).

## Prerequisites

1. An OCI account kept on **Always Free** (do **not** upgrade to Pay-As-You-Go).
2. A dedicated compartment (e.g. `always-free-lab`) — record its OCID.
3. An API signing key uploaded to your user; `~/.oci/config` configured (DEFAULT profile).
4. An SSH public key.
5. Terraform >= 1.6 and `jq` installed.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your real values (compartment OCID, keys, email, password)

terraform fmt -check
terraform init
terraform validate
terraform plan -out=tfplan

# Guardrail: confirm the plan only touches Always Free resources
terraform show -json tfplan > tfplan.json
./scripts/check-plan.sh tfplan.json

terraform apply tfplan
```

## After apply — required steps

1. **Confirm the email subscription.** OCI sends a confirmation link; the subscription stays
   `PENDING` until you click it. Re-check:
   ```bash
   terraform refresh && terraform output notification_subscription_state   # want: ACTIVE
   ```
2. **Smoke tests:**
   - `terraform output a1_ssh_command` → SSH in as `ubuntu`.
   - Console/CLI: A1 shows **2 OCPU / 12 GB**; both ADBs are `AVAILABLE` with `is_free_tier = true`.
   - `terraform plan` again → **No changes** (no drift).

## Known caveats

- **A1 capacity:** `Out of host capacity` is common for free A1 in Ashburn. Retry, or set
  `availability_domain_index` to `1` or `2` and re-apply.
- **ADB password:** 12–30 chars, must include upper, lower, and a number; cannot contain the string
  `admin` or a double-quote.
- **Costs:** Everything here maps to a verified Always Free entitlement. Never create resources from
  the Console outside Terraform — manual edits cause drift and can incur charges.
- **Provider/limits drift:** Provider pinned to `oracle/oci ~> 8.18`. Re-verify Oracle's Always Free
  page periodically; the catalogue and limits change (as the 2026-06-15 A1 cut showed).

## Layout

```
versions.tf      providers.tf     variables.tf     locals.tf
data.tf          network.tf       compute.tf       database.tf
observability.tf guardrails.tf    outputs.tf
scripts/check-plan.sh   terraform.tfvars.example
```
