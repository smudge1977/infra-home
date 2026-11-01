output "wordpress_lab_host" {
  description = "The lab VM's Proxmox identity and guest-agent IPs; the output does not certify network isolation."
  value = {
    vm_id          = module.vm.vm_id
    vm_name        = module.vm.vm_name
    ipv4_addresses = module.vm.ipv4_addresses
  }
}
