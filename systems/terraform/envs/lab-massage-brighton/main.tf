provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = false
  # Authentication comes from PROXMOX_VE_API_TOKEN in the Terraform process.
}

module "vm" {
  source = "../../modules/vm"

  name        = "lab-massage-brighton"
  description = "Internal-only lab WordPress host; no production data."
  env         = "lab"
  system      = "massage-brighton"
  owner       = var.owner
  extra_tags  = ["wordpress", "internal-only"]

  node_name    = "prox01"
  datastore_id = var.datastore_id
  bridge       = var.private_bridge
  pool_id      = var.pool_id
  vm_id        = var.vm_id
  vm_id_range  = var.vm_id_range

  template_vm_id = var.template_vm_id
  ssh_public_key = var.ssh_public_key
  cores          = 2
  memory_mb      = 4096
  disk_size_gb   = 40
  linked_clone   = false
  on_boot        = true
  protect_vm     = true
}
