# Backstop against drifting outside the Always Free envelope. Variable-level
# validation already enforces most of this; these preconditions re-check the
# combined picture at plan time and fail fast with clear messages.
resource "terraform_data" "always_free_guard" {
  input = {
    a1_shape  = var.a1_shape
    a1_ocpus  = var.a1_ocpus
    a1_memory = var.a1_memory_gbs
  }

  lifecycle {
    precondition {
      condition     = contains(["VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"], var.a1_shape)
      error_message = "Only Always Free compute shapes are allowed for the primary server."
    }

    precondition {
      condition     = var.a1_ocpus <= 2 && var.a1_memory_gbs <= 12
      error_message = "Always Free Arm A1 ceiling is 2 OCPU / 12 GB (as of 2026-06-15)."
    }

    precondition {
      condition     = var.micro_count <= 2
      error_message = "Always Free allows at most 2 E2.1.Micro instances."
    }

    precondition {
      condition     = var.adb_count <= 2
      error_message = "Always Free allows at most 2 Autonomous Databases."
    }

    precondition {
      condition     = var.region == "us-ashburn-1"
      error_message = "This stack is pinned to the us-ashburn-1 home region."
    }
  }
}
