# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `nsg_ids` input: network security groups for the primary VNIC
  (`create_vnic_details.nsg_ids`), at most five, validated as NSG OCIDs without
  duplicates. Defaults to `null`, which leaves NSG membership unmanaged as before;
  any list, `[]` included, is enforced.
- `private_ip` and `skip_source_dest_check` inputs passed through to the primary
  VNIC, both `null` by default.

[Unreleased]: https://github.com/moveeeax/terraform-oci-instance/compare/v1.1.0...HEAD
