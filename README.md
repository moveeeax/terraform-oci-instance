# terraform-oci-instance

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
compute instance. It supports flexible shapes, image-based boot volumes, cloud-init user
data and SSH key injection, and a primary VNIC on a chosen subnet.

## Secure defaults

The module deliberately departs from OCI's own defaults where those defaults are unsafe.
All of them are plain variables you can set back:

| Behaviour                                                   | OCI default | This module |
|-------------------------------------------------------------|-------------|-------------|
| Public IP on the primary VNIC                                | assigned    | **not assigned** (`assign_public_ip = false`) |
| Legacy IMDS v1 endpoints                                     | permitted   | **disabled** (`are_legacy_imds_endpoints_disabled = true`) |
| In-transit encryption for paravirtualized volume attachments | off         | **on** (`is_pv_encryption_in_transit_enabled = true`) |

Disabling IMDS v1 is OCI's analogue of requiring IMDSv2 on AWS: the v1 endpoint has no
request-header requirement, so a server-side request forgery bug on the instance can read
instance metadata — including whatever you put in `user_data`.

`user_data` is marked `sensitive`, since cloud-init payloads routinely carry bootstrap
tokens and join secrets. `ssh_authorized_keys` is *not* marked sensitive — public keys are
not secrets, and redacting them makes plans harder to review — but it **is** validated:
placeholder or truncated keys are rejected at plan time rather than producing an instance
nobody can log into.

Boot volumes are always encrypted at rest. Set `boot_volume_kms_key_id` to use your own
Vault key instead of the Oracle-managed service key, so rotation and revocation stay
under your control.

## Usage

```hcl
module "instance" {
  source = "github.com/moveeeax/terraform-oci-instance?ref=v1.0.0"

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
  ssh_authorized_keys = file("~/.ssh/id_ed25519.pub")

  # Optional: encrypt the boot volume with your own Vault key.
  boot_volume_kms_key_id = var.boot_volume_kms_key_id

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic); copy
`terraform.tfvars.example` to `terraform.tfvars`, fill in OCIDs from your tenancy, and
`terraform plan`.

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
| `ssh_authorized_keys`     | SSH public key(s), one per line, in OpenSSH format. Validated.    | `string`      | `null`                 |    no    |
| `user_data`               | Base64-encoded cloud-init user data. Sensitive.                   | `string`      | `null`                 |    no    |
| `boot_volume_size_in_gbs` | Size of the boot volume in GB. Null uses the image default.       | `number`      | `null`                 |    no    |
| `boot_volume_kms_key_id`  | Vault key OCID for the boot volume. Null uses the Oracle key.     | `string`      | `null`                 |    no    |
| `is_pv_encryption_in_transit_enabled` | Encrypt traffic to paravirtualized volume attachments. | `bool`     | `true`                 |    no    |
| `are_legacy_imds_endpoints_disabled`  | Disable legacy IMDS v1 endpoints.                     | `bool`     | `true`                 |    no    |
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

## Tests

[`tests/defaults.tftest.hcl`](tests/defaults.tftest.hcl) pins the secure defaults and the
input validation. It uses `mock_provider`, so it needs no OCI credentials and no network:

```sh
terraform init -backend=false
terraform test
```

Running the tests requires Terraform/OpenTofu >= 1.7 for `mock_provider`. The module
itself still supports >= 1.5.

## License

[MIT](LICENSE)
