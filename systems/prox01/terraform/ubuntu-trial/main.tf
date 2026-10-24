provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = false
  # Authentication is read from PROXMOX_VE_API_TOKEN, never from committed files.
}

resource "proxmox_virtual_environment_vm" "ubuntu_trial" {
  node_name   = "prox01"
  vm_id       = var.vm_id
  name        = "tf-ubuntu2604-trial"
  description = "Disposable Ubuntu 26.04 Terraform trial. No production data."
  tags        = ["terraform", "trial", "ubuntu-2604"]
  on_boot     = false
  started     = true

  clone {
    vm_id        = var.template_vm_id
    full         = true
    datastore_id = "ZFS01"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "ZFS01"
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  agent {
    enabled = true
    timeout = "5m"
  }

  initialization {
    datastore_id = "ZFS01"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "ubuntu"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    precondition {
      condition     = var.vm_id != var.template_vm_id
      error_message = "The disposable VM ID must not equal the source template ID."
    }
  }
}