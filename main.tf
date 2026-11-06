locals {
  # `var.user_data` is sensitive, so a bare `var.user_data != null` predicate
  # would mark the whole merged map sensitive even when no user data is set,
  # needlessly redacting the SSH key from plan output. nonsensitive() here
  # exposes only whether the value is null, never its contents; when user data
  # *is* supplied its mark still propagates to the metadata map.
  has_user_data = nonsensitive(var.user_data != null)

  metadata = merge(
    var.ssh_authorized_keys != null ? { ssh_authorized_keys = var.ssh_authorized_keys } : {},
    local.has_user_data ? { user_data = var.user_data } : {},
  )
}

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = var.display_name
  shape               = var.shape

  dynamic "shape_config" {
    for_each = var.shape_config != null ? [var.shape_config] : []
    content {
      ocpus         = shape_config.value.ocpus
      memory_in_gbs = shape_config.value.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = var.source_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs

    # Null falls back to the Oracle-managed service key.
    kms_key_id = var.boot_volume_kms_key_id
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = var.hostname_label

    # NSGs are OCI's per-VNIC firewall; without them only the subnet's security
    # lists apply.
    nsg_ids                = var.nsg_ids
    private_ip             = var.private_ip
    skip_source_dest_check = var.skip_source_dest_check
  }

  # Encrypt traffic between the instance and its paravirtualized boot/block
  # volume attachments. OCI leaves this off by default.
  is_pv_encryption_in_transit_enabled = var.is_pv_encryption_in_transit_enabled

  # OCI's analogue of AWS IMDSv2: the v1 endpoint has no request-header
  # requirement, so an SSRF against the instance can read instance metadata
  # (including anything placed in `metadata`/`user_data`). OCI permits v1 by
  # default; this module opts out.
  instance_options {
    are_legacy_imds_endpoints_disabled = var.are_legacy_imds_endpoints_disabled
  }

  metadata = local.metadata

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
