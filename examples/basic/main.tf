provider "oci" {}

module "instance" {
  source = "../.."

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "example-instance"
  shape               = "VM.Standard.E4.Flex"

  shape_config = {
    ocpus         = 1
    memory_in_gbs = 16
  }

  source_image_id  = var.source_image_id
  subnet_id        = var.subnet_id
  assign_public_ip = false
  nsg_ids          = var.nsg_ids

  # Supplied by the operator rather than hardcoded: a placeholder key here would
  # pass `terraform validate` and only fail once the instance is unreachable.
  ssh_authorized_keys = var.ssh_public_key

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example instance into."
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name for the example instance."
  type        = string
}

variable "source_image_id" {
  description = "OCID of the image used for the example instance."
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet for the example instance VNIC."
  type        = string
}

variable "nsg_ids" {
  description = "Network security group OCIDs for the example instance VNIC. Null leaves NSG membership unmanaged."
  type        = list(string)
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key to authorize on the example instance, e.g. file(\"~/.ssh/id_ed25519.pub\"). Null skips key injection."
  type        = string
  default     = null
}

output "instance_id" {
  value = module.instance.id
}
