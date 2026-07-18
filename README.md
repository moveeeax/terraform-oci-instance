# terraform-oci-instance

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
compute instance. It supports flexible shapes, image-based boot volumes, cloud-init user
data and SSH key injection, and a primary VNIC on a chosen subnet.

## Usage

```hcl
module "instance" {
  source = "github.com/cybercapybara/terraform-oci-instance"

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "prod-app-01"
  shape               = "VM.Standard.E4.Flex"

  shape_config = {
    ocpus         = 2
    memory_in_gbs = 32
  }

  source_image_id     = var.source_image_id
  subnet_id           = var.subnet_id
  assign_public_ip    = false
  ssh_authorized_keys = file("~/.ssh/id_rsa.pub")

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

## Inputs

| Name                      | Description                                                       | Type          | Default                | Required |
|---------------------------|-------------------------------------------------------------------|---------------|------------------------|:--------:|
| `compartment_id`          | OCID of the compartment in which to create the instance.          | `string`      | n/a                    |   yes    |
| `availability_domain`     | Availability domain in which to launch the instance.              | `string`      | n/a                    |   yes    |
| `display_name`            | Human-readable name for the instance.                             | `string`      | n/a                    |   yes    |
| `shape`                   | Compute shape for the instance.                                   | `string`      | `"VM.Standard.E4.Flex"`|    no    |
| `shape_config`            | OCPU/memory config for flexible shapes. Null for fixed shapes.    | `object(...)` | `1 ocpu / 16 GB`       |    no    |
| `source_image_id`         | OCID of the image used for the boot volume.                       | `string`      | n/a                    |   yes    |
| `subnet_id`               | OCID of the subnet for the primary VNIC.                          | `string`      | n/a                    |   yes    |
| `assign_public_ip`        | Whether to assign a public IP to the primary VNIC.                | `bool`        | `false`                |    no    |
| `hostname_label`          | Hostname label for the primary VNIC.                              | `string`      | `null`                 |    no    |
| `ssh_authorized_keys`     | SSH public key(s) injected via cloud-init.                        | `string`      | `null`                 |    no    |
| `user_data`               | Base64-encoded cloud-init user data.                              | `string`      | `null`                 |    no    |
| `boot_volume_size_in_gbs` | Size of the boot volume in GB. Null uses the image default.       | `number`      | `null`                 |    no    |
| `freeform_tags`           | Free-form tags applied to the instance.                           | `map(string)` | `{}`                   |    no    |
| `defined_tags`            | Defined tags applied to the instance, keyed `namespace.key`.      | `map(string)` | `{}`                   |    no    |

## Outputs

| Name             | Description                                            |
|------------------|--------------------------------------------------------|
| `id`             | OCID of the instance.                                 |
| `private_ip`     | Private IP of the instance's primary VNIC.            |
| `public_ip`      | Public IP of the instance's primary VNIC, if assigned.|
| `boot_volume_id` | OCID of the instance boot volume.                     |
| `state`          | Lifecycle state of the instance.                      |

## License

[MIT](LICENSE)
