variable "compartment_id" {
  description = "OCID of the compartment in which to create the instance."
  type        = string
}

variable "availability_domain" {
  description = "Name of the availability domain in which to launch the instance."
  type        = string
}

variable "display_name" {
  description = "Human-readable name for the instance."
  type        = string
}

variable "shape" {
  description = "Compute shape for the instance."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "shape_config" {
  description = "OCPU/memory configuration for flexible shapes. Null for fixed shapes."
  type = object({
    ocpus         = number
    memory_in_gbs = optional(number)
  })
  default = {
    ocpus         = 1
    memory_in_gbs = 16
  }
}

variable "source_image_id" {
  description = "OCID of the image used to launch the instance boot volume."
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet to attach the primary VNIC to."
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the primary VNIC."
  type        = bool
  default     = false
}

variable "hostname_label" {
  description = "Hostname label for the primary VNIC. Null uses no DNS hostname."
  type        = string
  default     = null
}

variable "nsg_ids" {
  description = <<-EOT
    OCIDs of network security groups to attach to the primary VNIC, at most five
    (the OCI limit per VNIC). The NSGs must be in the subnet's VCN.

    Null (the default) leaves the VNIC's NSG membership unmanaged, as before this
    input existed, so the instance is protected only by the subnet's security lists
    unless NSGs are attached elsewhere. A list, including [], is enforced: entries
    removed later are detached from the VNIC.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = var.nsg_ids == null || length(coalesce(var.nsg_ids, [])) <= 5
    error_message = "A VNIC can be in at most five network security groups."
  }

  validation {
    condition     = alltrue([for id in coalesce(var.nsg_ids, []) : can(regex("^ocid1\\.networksecuritygroup\\.", id))])
    error_message = "nsg_ids must contain network security group OCIDs (ocid1.networksecuritygroup...)."
  }

  validation {
    condition     = length(distinct(coalesce(var.nsg_ids, []))) == length(coalesce(var.nsg_ids, []))
    error_message = "nsg_ids must not contain duplicates."
  }
}

variable "private_ip" {
  description = "Private IPv4 address for the primary VNIC, from the subnet's CIDR. Null lets OCI pick a free address."
  type        = string
  default     = null

  validation {
    condition     = var.private_ip == null || can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.private_ip)) && can(cidrnetmask("${coalesce(var.private_ip, "0.0.0.0")}/32"))
    error_message = "private_ip must be an IPv4 address such as 10.0.1.10."
  }
}

variable "skip_source_dest_check" {
  description = "Disable the source/destination check on the primary VNIC, needed when the instance routes traffic (NAT instance, firewall, VPN). Null keeps the OCI default (check enabled)."
  type        = bool
  default     = null
}

variable "ssh_authorized_keys" {
  description = <<-EOT
    SSH public key(s) injected into the instance via cloud-init, one per line, in
    OpenSSH `authorized_keys` format. Null skips injection.

    This is validated rather than passed through blindly: a malformed or
    placeholder value is accepted by `terraform validate` and by the OCI API, and
    only shows up later as an instance nobody can log into.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.ssh_authorized_keys == null ? true : alltrue([
      for key in compact([for line in split("\n", var.ssh_authorized_keys) : trimspace(line)]) :
      can(regex("^(?:ssh-(?:rsa|dss|ed25519)|ecdsa-sha2-nistp(?:256|384|521)|sk-ssh-ed25519@openssh\\.com|sk-ecdsa-sha2-nistp256@openssh\\.com) +AAAA[0-9A-Za-z+/]{50,}={0,3}( .+)?$", key))
    ])
    error_message = "Each non-empty line of ssh_authorized_keys must be a parseable OpenSSH public key, e.g. \"ssh-ed25519 AAAAC3Nza... user@host\". Placeholder text and private keys are rejected."
  }

  validation {
    condition     = var.ssh_authorized_keys == null ? true : length(compact([for line in split("\n", var.ssh_authorized_keys) : trimspace(line)])) > 0
    error_message = "ssh_authorized_keys must contain at least one key, or be null to skip injection."
  }
}

variable "user_data" {
  description = <<-EOT
    Base64-encoded cloud-init user data. Null skips it.

    Marked sensitive: cloud-init payloads routinely carry bootstrap tokens,
    passwords and join secrets, and instance metadata is readable by anything
    running on the instance.
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.user_data == null ? true : can(regex("^[A-Za-z0-9+/=[:space:]]+$", var.user_data))
    error_message = "user_data must be base64-encoded (OCI does not encode it for you). Wrap the raw script in base64encode()."
  }
}

variable "boot_volume_size_in_gbs" {
  description = "Size of the boot volume in GB. Null uses the image default."
  type        = number
  default     = null
}

variable "boot_volume_kms_key_id" {
  description = <<-EOT
    OCID of a Vault master encryption key used to encrypt the boot volume.
    Null uses the Oracle-managed service key, which still encrypts at rest but
    leaves key rotation and revocation outside your control.
  EOT
  type        = string
  default     = null
}

variable "is_pv_encryption_in_transit_enabled" {
  description = <<-EOT
    Encrypt traffic between the instance and its paravirtualized volume
    attachments. OCI defaults this to false; this module defaults it to true.

    Set to false for shapes or images that do not support in-transit encryption.
  EOT
  type        = bool
  default     = true
}

variable "are_legacy_imds_endpoints_disabled" {
  description = <<-EOT
    Disable the legacy (v1) instance metadata service endpoints, leaving only
    the v2 endpoints that require an `Authorization: Bearer Oracle` header.
    This is OCI's analogue of requiring AWS IMDSv2. OCI defaults this to false
    (v1 permitted); this module defaults it to true.

    Set to false only for images or agents that still call the v1 endpoint.
  EOT
  type        = bool
  default     = true
}

variable "freeform_tags" {
  description = "Free-form tags applied to the instance."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the instance, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
