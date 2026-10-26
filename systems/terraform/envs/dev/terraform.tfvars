# Copy to terraform.tfvars (ignored by Git), then replace every placeholder.
# Required: actual Ubuntu 26.04 cloud-init template ID ON prox01, NOT a VM ID in vms.
template_vm_id = 9026
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUq8KR9IvnCCSrqkH/pdpCvFfE8HfbqBweHM2it7kpR keith@iot-home"
proxmox_endpoint = "https://prox04.keithmarston.me.uk/"
node_name        = "prox04"
datastore_id     = "ZFS04"
bridge           = "vmbr0"

# Defaults already target prox01 (https://prox01.keithmarston.me.uk/, ZFS01, vmbr0).
# Override only if they differ. Add VMs via `vms`; see variables.tf for the shape.
vms = {}

# Set false and apply the protection-only update before an approved destroy.
protect_vm = true
