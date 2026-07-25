# Test-only requirement: `mock_provider` needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still supports >= 1.5 — do not bump required_version for this.
#
# Run with: terraform init -backend=false && terraform test

mock_provider "oci" {}

variables {
  compartment_id      = "ocid1.compartment.oc1..aaaaaaaaexample"
  availability_domain = "EXMP:US-ASHBURN-AD-1"
  display_name        = "unit-test-instance"
  source_image_id     = "ocid1.image.oc1..aaaaaaaaexample"
  subnet_id           = "ocid1.subnet.oc1..aaaaaaaaexample"
}

run "defaults_are_hardened" {
  command = plan

  assert {
    # create_vnic_details.assign_public_ip is a string in the provider schema,
    # so the bool is converted before it reaches the API.
    condition     = oci_core_instance.this.create_vnic_details[0].assign_public_ip == "false"
    error_message = "The primary VNIC must not get a public IP unless assign_public_ip is explicitly set."
  }

  assert {
    condition     = oci_core_instance.this.instance_options[0].are_legacy_imds_endpoints_disabled == true
    error_message = "Legacy IMDS v1 endpoints must be disabled by default (OCI's IMDSv2 analogue)."
  }

  assert {
    condition     = oci_core_instance.this.is_pv_encryption_in_transit_enabled == true
    error_message = "In-transit encryption for paravirtualized volume attachments must be on by default."
  }

  # `metadata` itself is Optional+Computed in the provider schema, so an empty
  # map plans as "known after apply" and cannot be asserted on here. The local
  # that builds it is covered by the ssh/user_data runs below.
  assert {
    condition     = length(local.metadata) == 0
    error_message = "No metadata should be built when neither ssh_authorized_keys nor user_data is set."
  }
}

run "public_ip_and_legacy_imds_are_opt_in" {
  command = plan

  variables {
    assign_public_ip                   = true
    are_legacy_imds_endpoints_disabled = false
  }

  assert {
    condition     = oci_core_instance.this.create_vnic_details[0].assign_public_ip == "true"
    error_message = "assign_public_ip = true must reach the VNIC."
  }

  assert {
    condition     = oci_core_instance.this.instance_options[0].are_legacy_imds_endpoints_disabled == false
    error_message = "Operators must be able to re-enable IMDS v1 for legacy images."
  }
}

run "customer_managed_boot_volume_key_is_passed_through" {
  command = plan

  variables {
    boot_volume_kms_key_id = "ocid1.key.oc1..aaaaaaaaexample"
  }

  assert {
    condition     = oci_core_instance.this.source_details[0].kms_key_id == "ocid1.key.oc1..aaaaaaaaexample"
    error_message = "boot_volume_kms_key_id must reach source_details.kms_key_id."
  }
}

run "accepts_a_real_ssh_public_key" {
  command = plan

  variables {
    # Throwaway ed25519 key generated for this fixture; the private half exists
    # nowhere and is authorized on nothing.
    ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuvNCU/Z0UjRPY1l2EoqwDrVQAwgUwg7GeLnph+FX6F terraform-test-fixture"
  }

  assert {
    condition     = oci_core_instance.this.metadata["ssh_authorized_keys"] == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuvNCU/Z0UjRPY1l2EoqwDrVQAwgUwg7GeLnph+FX6F terraform-test-fixture"
    error_message = "A valid SSH public key must be injected into instance metadata verbatim."
  }
}

# Regression guard for the failure mode seen in a sibling module: a placeholder
# SSH key passes `terraform validate` and only blows up at apply time (or worse,
# succeeds and produces an instance nobody can log into).
run "rejects_placeholder_ssh_key" {
  command = plan

  variables {
    ssh_authorized_keys = "ssh-rsa REPLACE_WITH_YOUR_PUBLIC_KEY"
  }

  expect_failures = [var.ssh_authorized_keys]
}

run "rejects_truncated_ssh_key" {
  command = plan

  variables {
    ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@host"
  }

  expect_failures = [var.ssh_authorized_keys]
}

run "rejects_private_key_pasted_into_ssh_authorized_keys" {
  command = plan

  variables {
    ssh_authorized_keys = "-----BEGIN OPENSSH PRIVATE KEY-----"
  }

  expect_failures = [var.ssh_authorized_keys]
}

run "rejects_unencoded_user_data" {
  command = plan

  variables {
    user_data = "#!/bin/bash\necho hello"
  }

  expect_failures = [var.user_data]
}

run "accepts_base64_user_data" {
  command = plan

  variables {
    user_data = "IyEvYmluL2Jhc2gKZWNobyBoZWxsbwo="
  }

  assert {
    condition     = oci_core_instance.this.metadata["user_data"] == "IyEvYmluL2Jhc2gKZWNobyBoZWxsbwo="
    error_message = "Base64 user_data must be passed through unchanged."
  }
}
