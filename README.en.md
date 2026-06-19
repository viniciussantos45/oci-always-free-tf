# OCI Always Free — Maxed Terraform Stack (us-ashburn-1)

🇧🇷 [Ver em Português (original)](README.md)

> **📌 Note:** We're based in Brazil, so the original README is written in Portuguese. This page is the English translation — see [README.md](README.md) for the original. 🇧🇷

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

---

## Setup — do these once

### 1. Install the tools

```bash
brew install terraform jq oci-cli   # macOS
```

### 2. Have an OCI account on Always Free

Keep it on **Always Free** — do **not** upgrade to Pay-As-You-Go.

### 3. Create your API key + config

```bash
oci setup config
```

Answer the prompts (user OCID, tenancy OCID, region `us-ashburn-1`). It generates a key pair under
`~/.oci/` and writes a profile to `~/.oci/config`. **Note the profile name** it creates (in this repo's
history it was `Profile1-macos`) and whether it set a **passphrase** on the key — both are handled
automatically by the profile, so you never put them in Terraform.

### 4. Upload the public key in the Console

`oci setup config` does **not** register the key with Oracle — you must do it once:

1. Sign in at <https://cloud.oracle.com>
2. Top-right **profile icon → My profile → API keys → Add API key**
3. **Paste a public key** → paste the full contents of:
   ```bash
   cat ~/.oci/oci_api_key_public.pem
   ```
4. **Add**.

### 5. Verify auth works

```bash
oci iam region list --profile Profile1-macos
```

You should get a **table of regions**. If you get `401 NotAuthenticated`, the public key isn't
uploaded/registered yet — redo step 4 (see FAQ).

### 6. Choose a compartment

Either use your **root** compartment (your tenancy OCID) or create a dedicated one (recommended):

```bash
oci iam compartment create \
  --compartment-id <tenancy_ocid> \
  --name always-free-lab \
  --description "Always Free Terraform stack" \
  --profile Profile1-macos --query 'data.id' --raw-output
```

The command prints the new compartment OCID — use it as `compartment_id`.

### 7. Have an SSH key

```bash
cat ~/.ssh/id_ed25519.pub   # or create one: ssh-keygen -t ed25519
```

---

## Configure `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Fill in **literal values** (⚠️ `.tfvars` cannot reference other variables — paste real OCID strings):

```hcl
config_file_profile = "Profile1-macos"                 # the profile from step 3
tenancy_ocid        = "ocid1.tenancy.oc1..aaaa..."     # your tenancy OCID
region              = "us-ashburn-1"
compartment_id      = "ocid1.compartment.oc1..aaaa..." # or your tenancy OCID for root

ssh_public_key      = "ssh-ed25519 AAAA... you@host"
ssh_ingress_cidr    = "0.0.0.0/0"                       # tighten to "<your.ip>/32" to cut scan noise

adb_admin_password  = "Str0ngPassw0rd!"                 # 12-30 chars, upper+lower+number
notification_email  = "you@example.com"
```

Secrets (user OCID, fingerprint, key path, key passphrase) are **read from `~/.oci/config`** via the
profile, so they don't go in this file.

---

## Deploy

```bash
terraform init
terraform validate
terraform plan -out=tfplan

# Guardrail: fail if the plan touches anything outside the Always Free allow-list
terraform show -json tfplan > tfplan.json
./scripts/check-plan.sh tfplan.json

terraform apply tfplan
```

Expected: **14 resources to add**. If the A1/micros fail with `Out of host capacity` or
`404-NotAuthorizedOrNotFound`, that's an Oracle capacity shortage, not a config error — see the FAQ.

## After apply

1. **Confirm the alert email** — OCI sends a link; the subscription stays `PENDING` until you click it:
   ```bash
   terraform refresh && terraform output notification_subscription_state   # want: ACTIVE
   ```
2. **Smoke test:**
   - `terraform output a1_ssh_command` → SSH in as `ubuntu`.
   - Console/CLI: A1 shows **2 OCPU / 12 GB**; both ADBs are `AVAILABLE` with `is_free_tier = true`.
   - `terraform plan` again → **No changes** (no drift).

## Tear down

```bash
terraform destroy
```

Removes everything (incl. the 2 ADBs). The notifications topic can take ~5 min to delete — that's normal.

---

## Beating A1 capacity (the #1 gotcha)

Always Free **Arm A1 in Ashburn is heavily oversubscribed**. Apply can fail purely because Oracle has
no free Arm host at that moment. There is **no code fix** — you retry until capacity appears:

- **Cycle the A1's availability domain** with `a1_availability_domain_index` (0, 1, 2). It's separate
  from `availability_domain_index` so you can hunt A1 capacity **without recreating the micros**:
  ```hcl
  a1_availability_domain_index = 1   # try 0, then 1, then 2; re-apply each time
  ```
- **Retry off-peak** (late night / early morning local time) — capacity frees up.
- Re-running `terraform apply` only re-attempts the failed instances; already-created resources stay.

---

## FAQ

**Q: `terraform apply` fails with `500-InternalError, Out of host capacity` on the A1.**
Oracle has no free Arm host right now. Not a bug. Cycle `a1_availability_domain_index` across 0/1/2 and
retry, ideally off-peak. Keep retrying — this is the normal Always Free Ashburn experience.

**Q: Instances fail with `404-NotAuthorizedOrNotFound` on `LaunchInstance`, but everything else created.**
For Always Free shapes this is almost always the **same capacity shortage** surfaced as Oracle's
ambiguous error — not a permissions problem. Confirm by checking whether the A1 reports
`Out of host capacity` on a retry: if it does, your compute auth is fine and it's purely capacity. (It
would only be a real policy issue if **every** service — including the ADBs — failed with 404.)

**Q: `oci iam region list` returns `401 NotAuthenticated`.**
The API public key isn't registered. Re-do Setup step 4 (Console → My profile → API keys → Add API
key → paste `~/.oci/oci_api_key_public.pem`). Make sure the fingerprint shown in the Console matches the
`fingerprint` in your `~/.oci/config` profile.

**Q: `Error: Variables not allowed` / `Variables may not be used here` pointing at `terraform.tfvars`.**
`.tfvars` files only accept literal values. Replace any `compartment_id = tenancy_ocid` with the actual
OCID string in quotes, e.g. `compartment_id = "ocid1.tenancy.oc1..aaaa..."`.

**Q: My private key has a passphrase. Where do I put it?**
Nowhere in Terraform. The provider authenticates via `config_file_profile`, which reads the key path
**and** its passphrase straight from `~/.oci/config`. Keep using profile auth and you never handle the
passphrase in this repo.

**Q: Can I authorize more than one SSH key?**
The `ssh_authorized_keys` metadata accepts multiple newline-separated keys, so you can pass several in
one string: `ssh_public_key = "ssh-ed25519 AAAA... me\nssh-ed25519 BBBB... teammate"`. Want a cleaner
`list(string)` variable instead? Ask and it's a small change.

**Q: The alert email never arrives / subscription stays `PENDING`.**
Open the confirmation email OCI sent to `notification_email` and click the link. Until then,
`notification_subscription_state` stays `PENDING` and alerts won't fire.

**Q: Will this cost anything?**
No — every resource maps to a verified Always Free entitlement, and the guardrails
(`check-plan.sh` + variable validation + `guardrails.tf`) block anything outside it. The one rule:
**never create resources from the Console outside Terraform** — manual changes cause drift and can
incur charges.

**Q: Can I run this in another region?**
No. It's pinned to `us-ashburn-1` (validation enforces it). Free tenancies are limited to one home
region, and some choices here (e.g. excluding Phoenix-only NoSQL) assume Ashburn.

**Q: Apply succeeded partially and then I changed my mind — how do I clean up?**
`terraform destroy`. It removes whatever is in state, even from a partial apply.

---

## Layout

```
versions.tf      providers.tf     variables.tf     locals.tf
data.tf          network.tf       compute.tf       database.tf
observability.tf guardrails.tf    outputs.tf
scripts/check-plan.sh   terraform.tfvars.example
```

## Notes

- Provider pinned to `oracle/oci ~> 8.18`. Re-verify Oracle's
  [Always Free page](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
  periodically — the catalogue and limits change (as the 2026-06-15 A1 cut showed).
- `terraform.tfvars`, `*.pem`, and state files are git-ignored. Never commit real secrets.
