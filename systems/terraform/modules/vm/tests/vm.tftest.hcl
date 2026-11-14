# Offline plans only: no API requests, real VMs, credentials or state.
mock_provider "proxmox" {}

variables {
  name           = "tf-test"
  node_name      = "prox01"
  datastore_id   = "ZFS01"
  bridge         = "vmbr0"
  env            = "sandbox"
  system         = "test"
  owner          = "keith"
  vm_id          = 4001
  vm_id_range    = { min = 4000, max = 4099 }
  template_vm_id = 9026
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess trial-test"
  disk_size_gb   = 20
  linked_clone   = false
  protect_vm     = true
}

run "isolated_defaults" {
  command = plan

  assert {
    condition = (
      proxmox_virtual_environment_vm.this.node_name == "prox01" &&
      proxmox_virtual_environment_vm.this.vm_id == 4001 &&
      proxmox_virtual_environment_vm.this.clone[0].full &&
      proxmox_virtual_environment_vm.this.clone[0].vm_id == var.template_vm_id &&
      !proxmox_virtual_environment_vm.this.on_boot &&
      proxmox_virtual_environment_vm.this.protection
    )
    error_message = "VM must be a separate, protected full clone without host-boot autostart."
  }

  assert {
    condition = (
      proxmox_virtual_environment_vm.this.disk[0].datastore_id == "ZFS01" &&
      proxmox_virtual_environment_vm.this.disk[0].size == 20 &&
      proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr0" &&
      proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].address == "dhcp" &&
      length(proxmox_virtual_environment_pool_membership.this) == 0
    )
    error_message = "VM must use the given storage/bridge with a 20 GiB disk, DHCP and no pool."
  }
}

run "node_datastore_bridge_pool_are_inputs" {
  command = plan

  variables {
    node_name    = "prox04"
    datastore_id = "local-zfs"
    bridge       = "vmbr9"
    pool_id      = "dev"
  }

  assert {
    condition = (
      proxmox_virtual_environment_vm.this.node_name == "prox04" &&
      proxmox_virtual_environment_vm.this.clone[0].datastore_id == "local-zfs" &&
      proxmox_virtual_environment_vm.this.disk[0].datastore_id == "local-zfs" &&
      proxmox_virtual_environment_vm.this.initialization[0].datastore_id == "local-zfs" &&
      proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr9" &&
      proxmox_virtual_environment_pool_membership.this[0].pool_id == "dev"
    )
    error_message = "Node, datastore, bridge and pool must flow through from inputs."
  }
}

run "mandatory_tags_are_always_present" {
  command = plan

  variables {
    extra_tags = ["trial", "terraform"]
  }

  assert {
    condition     = jsonencode(proxmox_virtual_environment_vm.this.tags) == jsonencode(["env-sandbox", "owner-keith", "system-test", "terraform", "trial"])
    error_message = "Tags must be terraform, env-*, system-*, owner-* plus de-duplicated extras."
  }
}

run "vlan_tag_is_applied" {
  command = plan

  variables {
    vlan_tag = 1000
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 1000
    error_message = "The VM NIC must use the requested VLAN tag."
  }
}

run "reject_invalid_vlan_tag" {
  command = plan

  variables {
    vlan_tag = 4095
  }

  expect_failures = [var.vlan_tag]
}

run "reject_invalid_tag_label" {
  command = plan

  variables {
    env = "Sandbox Env"
  }

  expect_failures = [var.env]
}

run "reject_vm_id_outside_env_range" {
  command = plan

  variables {
    vm_id = 5001
  }

  expect_failures = [proxmox_virtual_environment_vm.this]
}

run "reject_template_id_as_vm_id" {
  command = plan

  variables {
    vm_id       = 9026
    vm_id_range = { min = 9000, max = 9099 }
  }

  expect_failures = [proxmox_virtual_environment_vm.this]
}

run "reject_inverted_id_range" {
  command = plan

  variables {
    vm_id_range = { min = 4099, max = 4000 }
  }

  expect_failures = [var.vm_id_range]
}

run "reject_missing_template_placeholder" {
  command = plan

  variables {
    template_vm_id = 0
  }

  expect_failures = [var.template_vm_id]
}

run "linked_clone_omits_target_storage" {
  command = plan

  variables {
    linked_clone = true
  }

  assert {
    condition = (
      !proxmox_virtual_environment_vm.this.clone[0].full &&
      proxmox_virtual_environment_vm.this.clone[0].datastore_id == null &&
      proxmox_virtual_environment_vm.this.protection
    )
    error_message = "Linked clones must omit target storage and retain deletion protection."
  }
}

run "explicit_unprotect_for_teardown" {
  command = plan

  variables {
    protect_vm = false
  }

  assert {
    condition     = !proxmox_virtual_environment_vm.this.protection
    error_message = "An operator must be able to explicitly remove protection before teardown."
  }
}
