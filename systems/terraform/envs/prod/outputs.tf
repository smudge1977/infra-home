output "vms" {
  description = "VMs tracked by this state; identify each LAN IPv4 address, excluding loopback."
  value = {
    for key, vm in module.vm : key => {
      vm_id          = vm.vm_id
      vm_name        = vm.vm_name
      ipv4_addresses = vm.ipv4_addresses
    }
  }
}
