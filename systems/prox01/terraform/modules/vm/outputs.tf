output "vm_id" {
  description = "The VM tracked by this state."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4_addresses" {
  description = "Guest-agent-reported interface addresses; identify the LAN address, excluding loopback."
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}
