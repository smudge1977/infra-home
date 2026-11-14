locals {
  tags = sort(distinct(concat(
    ["terraform", "env-${var.env}", "system-${var.system}", "owner-${var.owner}"],
    var.extra_tags,
  )))
}

# The VM resource's own pool_id argument is deprecated in favour of membership.
resource "proxmox_virtual_environment_pool_membership" "this" {
  count = var.pool_id == null ? 0 : 1

  pool_id = var.pool_id
  vm_id   = proxmox_virtual_environment_vm.this.vm_id
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  name        = var.name
  description = var.description
  tags        = local.tags
  on_boot     = var.on_boot
  started     = true
  protection  = var.protect_vm

  clone {
    vm_id = var.template_vm_id
    full  = !var.linked_clone
    # PVE rejects the storage parameter for linked clones; null omits it.
    datastore_id = var.linked_clone ? null : var.datastore_id
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
  }

  network_device {
    bridge  = var.bridge
    model   = "virtio"
    vlan_id = var.vlan_tag
  }

  agent {
    enabled = true
    timeout = "5m"
  }

  initialization {
    datastore_id = var.datastore_id
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
      error_message = "The VM ID must not equal the source template ID."
    }

    precondition {
      condition     = var.vm_id >= var.vm_id_range.min && var.vm_id <= var.vm_id_range.max
      error_message = "The VM ID must fall inside this environment's vm_id_range."
    }
  }
}
