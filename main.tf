locals {
  metadata = merge(
    var.ssh_authorized_keys != null ? { ssh_authorized_keys = var.ssh_authorized_keys } : {},
    var.user_data != null ? { user_data = var.user_data } : {},
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
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = var.hostname_label
  }

  metadata = local.metadata

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
