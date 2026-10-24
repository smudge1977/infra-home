output "vm_id" {
  description = "The disposable VM tracked by this state."
  value       = proxmox_virtual_environment_vm.ubuntu_trial.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.ubuntu_trial.name
}

output "ipv4_addresses" {
  description = "Guest-agent-reported interface addresses; identify the LAN address, excluding loopback."
  value       = proxmox_virtual_environment_vm.ubuntu_trial.ipv4_addresses
}