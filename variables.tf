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

variable "ssh_authorized_keys" {
  description = "SSH public key(s) injected into the instance via cloud-init. Null skips injection."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Base64-encoded cloud-init user data. Null skips it."
  type        = string
  default     = null
}

variable "boot_volume_size_in_gbs" {
  description = "Size of the boot volume in GB. Null uses the image default."
  type        = number
  default     = null
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
