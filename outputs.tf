output "id" {
  description = "OCID of the instance."
  value       = oci_core_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance's primary VNIC."
  value       = oci_core_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance's primary VNIC, if assigned."
  value       = oci_core_instance.this.public_ip
}

output "boot_volume_id" {
  description = "OCID of the instance boot volume."
  value       = oci_core_instance.this.boot_volume_id
}

output "state" {
  description = "Lifecycle state of the instance."
  value       = oci_core_instance.this.state
}
