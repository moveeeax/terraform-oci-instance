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

output "instance_id" {
  value = module.instance.id
}
