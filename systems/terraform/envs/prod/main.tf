provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = false
  # Authentication is read from PROXMOX_VE_API_TOKEN, never from committed files.
}

module "vm" {
  source   = "../../modules/vm"
  for_each = var.vms

  name        = each.value.name
  description = each.value.description
  env         = "prod"
  system      = each.value.system
  owner       = var.owner
  extra_tags  = each.value.extra_tags

  node_name    = var.node_name
  datastore_id = var.datastore_id
  bridge       = var.bridge
  pool_id      = var.pool_id
  vm_id        = each.value.vm_id
  vm_id_range  = var.vm_id_range

  template_vm_id = var.template_vm_id
  ssh_public_key = var.ssh_public_key
  cores          = each.value.cores
  memory_mb      = each.value.memory_mb
  disk_size_gb   = each.value.disk_size_gb
  linked_clone   = each.value.linked_clone
  on_boot        = each.value.on_boot
  protect_vm     = var.protect_vm
}
