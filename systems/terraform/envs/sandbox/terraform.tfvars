# Copy to terraform.tfvars (ignored by Git), then replace both placeholders.
# Required: actual Ubuntu 26.04 template ID on prox01, NOT trial VM ID 4001.
template_vm_id = 9026
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUq8KR9IvnCCSrqkH/pdpCvFfE8HfbqBweHM2it7kpR keith@iot-home"

# User-supplied HTTPS origin. If direct PVE rather than a proxy, add :8006.
# TEMPORARY: live trial VM 4001 is still on prox01. Tear it down, then replace
# these with prox04 values (see terraform.tfvars.example).
proxmox_endpoint = "https://prox01.keithmarston.me.uk/"
node_name        = "prox01"
datastore_id     = "ZFS01"
bridge           = "vmbr0"
protect_vm       = false
vms = {
  trial = {
    name         = "tf-ubuntu2604-trial"
    description  = "Disposable Ubuntu 26.04 Terraform trial. No production data."
    system       = "ubuntu-trial"
    vm_id        = 4001
    extra_tags   = ["trial", "ubuntu-2604"]
    disk_size_gb = 100
    linked_clone = true

  }
}