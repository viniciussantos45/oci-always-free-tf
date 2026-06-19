# ---------------------------------------------------------------------------
# Authentication (reads user/fingerprint/key/passphrase from ~/.oci/config)
# ---------------------------------------------------------------------------
variable "config_file_profile" {
  type        = string
  description = "Profile name in ~/.oci/config to authenticate with."
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  type        = string
  description = "OCID of your tenancy (used for availability-domain lookups)."
}

variable "region" {
  type        = string
  description = "Home region. This stack is pinned to Ashburn."
  default     = "us-ashburn-1"

  validation {
    condition     = var.region == "us-ashburn-1"
    error_message = "This stack is designed for the us-ashburn-1 home region only."
  }
}

variable "compartment_id" {
  type        = string
  description = "OCID of the dedicated compartment that will hold all Always Free resources."
}

# ---------------------------------------------------------------------------
# Placement / naming
# ---------------------------------------------------------------------------
variable "availability_domain_index" {
  type        = number
  description = "Which AD to place instances in (0,1,2). Switch if A1 capacity is unavailable."
  default     = 0

  validation {
    condition     = var.availability_domain_index >= 0 && var.availability_domain_index <= 2
    error_message = "Ashburn has 3 availability domains: use 0, 1, or 2."
  }
}

variable "a1_availability_domain_index" {
  type        = number
  description = "AD for the A1 server (0,1,2). Set independently so you can hunt A1 capacity without recreating the micros. null = follow availability_domain_index."
  default     = null

  validation {
    condition     = var.a1_availability_domain_index == null || (var.a1_availability_domain_index >= 0 && var.a1_availability_domain_index <= 2)
    error_message = "Ashburn has 3 availability domains: use 0, 1, or 2 (or null to follow availability_domain_index)."
  }
}

variable "name_prefix" {
  type        = string
  description = "Prefix applied to all resource display names."
  default     = "af"
}

variable "owner_tag" {
  type        = string
  description = "Value for the owner freeform tag."
  default     = "home-lab"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN."
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.10.0.0/24"
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "Source CIDR allowed to SSH (port 22). Narrow this to your IP for better security."
  default     = "0.0.0.0/0"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into every instance (login user: ubuntu)."
}

# ---------------------------------------------------------------------------
# Compute - maxed Always Free Arm A1 server
# ---------------------------------------------------------------------------
variable "a1_shape" {
  type        = string
  description = "Shape for the primary Arm server."
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = contains(["VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"], var.a1_shape)
    error_message = "Only Always Free shapes are allowed."
  }
}

variable "a1_ocpus" {
  type        = number
  description = "OCPUs for the A1 server. Always Free ceiling is 2 (as of 2026-06-15)."
  default     = 2

  validation {
    condition     = var.a1_ocpus >= 1 && var.a1_ocpus <= 2
    error_message = "Always Free Arm A1 is capped at 2 OCPUs total (as of 2026-06-15)."
  }
}

variable "a1_memory_gbs" {
  type        = number
  description = "Memory (GB) for the A1 server. Always Free ceiling is 12 (as of 2026-06-15)."
  default     = 12

  validation {
    condition     = var.a1_memory_gbs >= 1 && var.a1_memory_gbs <= 12
    error_message = "Always Free Arm A1 is capped at 12 GB memory total (as of 2026-06-15)."
  }
}

variable "a1_boot_volume_gbs" {
  type        = number
  description = "Boot volume size (GB) for the A1 server. Shares the 200 GB Always Free pool."
  default     = 100

  validation {
    condition     = var.a1_boot_volume_gbs >= 50 && var.a1_boot_volume_gbs <= 200
    error_message = "Boot volume must be between 50 and 200 GB (the Always Free block pool)."
  }
}

# ---------------------------------------------------------------------------
# Compute - AMD E2.1.Micro instances
# ---------------------------------------------------------------------------
variable "micro_shape" {
  type        = string
  description = "Shape for the AMD micro instances."
  default     = "VM.Standard.E2.1.Micro"

  validation {
    condition     = var.micro_shape == "VM.Standard.E2.1.Micro"
    error_message = "Micro instances must use the Always Free VM.Standard.E2.1.Micro shape."
  }
}

variable "enable_micros" {
  type        = bool
  description = "Whether to create the AMD micro instances."
  default     = true
}

variable "micro_count" {
  type        = number
  description = "Number of AMD micro instances (max 2 on Always Free)."
  default     = 2

  validation {
    condition     = var.micro_count >= 0 && var.micro_count <= 2
    error_message = "Always Free allows at most 2 E2.1.Micro instances."
  }
}

variable "micro_skip_source_dest_check" {
  type        = bool
  description = "Disable the VNIC source/destination check on the micro instances. Required for routing/NAT roles such as a Tailscale exit node or subnet router. Leave false unless the instance forwards traffic; enabling it shifts anti-spoofing to the host firewall."
  default     = false
}

# ---------------------------------------------------------------------------
# Autonomous Database
# ---------------------------------------------------------------------------
variable "adb_count" {
  type        = number
  description = "Number of Always Free Autonomous Databases (max 2)."
  default     = 2

  validation {
    condition     = var.adb_count >= 0 && var.adb_count <= 2
    error_message = "Always Free allows at most 2 Autonomous Databases."
  }
}

variable "adb_db_name_prefix" {
  type        = string
  description = "Prefix for ADB db_name (a numeric suffix is appended). Letters/numbers only."
  default     = "AFADB"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,12}$", var.adb_db_name_prefix))
    error_message = "db_name prefix must start with a letter and be alphanumeric (<=13 chars)."
  }
}

variable "adb_db_workload" {
  type        = string
  description = "Autonomous DB workload type."
  default     = "OLTP"

  validation {
    condition     = contains(["OLTP", "DW", "AJD", "APEX"], var.adb_db_workload)
    error_message = "Use an Always Free-compatible ADB workload (OLTP, DW, AJD, APEX)."
  }
}

variable "adb_admin_password" {
  type        = string
  description = "ADB ADMIN password. 12-30 chars, upper+lower+number, no double-quote, not 'admin'."
  sensitive   = true

  validation {
    condition     = length(var.adb_admin_password) >= 12 && length(var.adb_admin_password) <= 30
    error_message = "ADB admin password must be 12-30 characters."
  }
}

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------
variable "notification_email" {
  type        = string
  description = "Email address that receives alerts (must be confirmed after apply)."
}
