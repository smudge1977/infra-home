# Offline plans only: no API requests, real VMs, credentials or state.
mock_provider "proxmox" {}

variables {
  template_vm_id = 9026
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess trial-test"
}

run "isolated_trial_defaults" {
  command = plan

  assert {
    condition = (
      proxmox_virtual_environment_vm.ubuntu_trial.node_name == "prox01" &&
      proxmox_virtual_environment_vm.ubuntu_trial.vm_id == 4001 &&
      proxmox_virtual_environment_vm.ubuntu_trial.clone[0].full &&
      proxmox_virtual_environment_vm.ubuntu_trial.clone[0].vm_id == 9000 &&
      !proxmox_virtual_environment_vm.ubuntu_trial.on_boot
    )
    error_message = "Trial must be a separate, full clone on prox01 without host-boot autostart."
  }

  assert {
    condition = (
      proxmox_virtual_environment_vm.ubuntu_trial.disk[0].datastore_id == "ZFS01" &&
      proxmox_virtual_environment_vm.ubuntu_trial.disk[0].size == 20 &&
      proxmox_virtual_environment_vm.ubuntu_trial.network_device[0].bridge == "vmbr0" &&
      proxmox_virtual_environment_vm.ubuntu_trial.initialization[0].ip_config[0].ipv4[0].address == "dhcp"
    )
    error_message = "Trial must use the agreed storage/bridge with a 20 GiB disk and DHCP."
  }
}

run "reject_template_id_as_trial_id" {
  command = plan

  variables {
    vm_id = 9000
  }

  expect_failures = [proxmox_virtual_environment_vm.ubuntu_trial]
}

run "reject_missing_template_placeholder" {
  command = plan

  variables {
    template_vm_id = 0
  }

  expect_failures = [var.template_vm_id]
}