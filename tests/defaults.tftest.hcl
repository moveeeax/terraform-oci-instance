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

run "nsg_membership_is_unmanaged_by_default" {
  command = plan

  # Null keeps the pre-nsg_ids behaviour: nothing is sent, so existing instances
  # see no diff and NSGs attached outside this module are left alone.
  assert {
    condition     = var.nsg_ids == null && var.private_ip == null && var.skip_source_dest_check == null
    error_message = "nsg_ids, private_ip and skip_source_dest_check must default to null."
  }
}

run "vnic_passthroughs_reach_the_primary_vnic" {
  command = plan

  variables {
    nsg_ids = [
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaweb",
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaassh",
    ]
    private_ip             = "10.0.1.10"
    skip_source_dest_check = true
  }

  assert {
    condition = oci_core_instance.this.create_vnic_details[0].nsg_ids == toset([
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaweb",
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaassh",
    ])
    error_message = "nsg_ids must reach create_vnic_details.nsg_ids."
  }

  assert {
    condition     = oci_core_instance.this.create_vnic_details[0].private_ip == "10.0.1.10"
    error_message = "private_ip must reach create_vnic_details.private_ip."
  }

  assert {
    condition     = oci_core_instance.this.create_vnic_details[0].skip_source_dest_check == true
    error_message = "skip_source_dest_check must reach create_vnic_details.skip_source_dest_check."
  }
}

run "empty_nsg_list_is_enforced" {
  command = plan

  variables {
    nsg_ids = []
  }

  assert {
    condition     = length(oci_core_instance.this.create_vnic_details[0].nsg_ids) == 0
    error_message = "An explicit empty nsg_ids must be sent so NSGs can be detached."
  }
}

run "rejects_more_than_five_nsgs" {
  command = plan

  variables {
    nsg_ids = [for i in range(6) : "ocid1.networksecuritygroup.oc1.iad.aaaaaaaa${i}"]
  }

  expect_failures = [var.nsg_ids]
}

run "rejects_non_nsg_ocid" {
  command = plan

  variables {
    nsg_ids = ["ocid1.securitylist.oc1.iad.aaaaaaaaexample"]
  }

  expect_failures = [var.nsg_ids]
}

run "rejects_duplicate_nsg_ids" {
  command = plan

  variables {
    nsg_ids = [
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaweb",
      "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaweb",
    ]
  }

  expect_failures = [var.nsg_ids]
}

run "rejects_malformed_private_ip" {
  command = plan

  variables {
    private_ip = "10.0.1.300"
  }

  expect_failures = [var.private_ip]
}
