# Offline mocked plans only: no API, credentials, VM create or network access.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint         = "https://prox01.example.invalid/"
  datastore_id             = "lab-zfs"
  private_bridge           = "vmbr9"
  private_network_confirmed = true
  template_vm_id            = 9026
  ssh_public_key             = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess test"
}

run "creates_protected_lab_clone_on_prox01" {
  command = plan

  assert {
    condition = (
      output.wordpress_lab_host.vm_id == 5101 &&
      output.wordpress_lab_host.vm_name == "lab-massage-brighton"
    )
    error_message = "The lab root must declare exactly the named candidate VM."
  }
}

run "requires_private_network_acknowledgement" {
  command = plan

  variables {
    private_network_confirmed = false
  }

  expect_failures = [var.private_network_confirmed]
}

run "rejects_generic_vmbr0_bridge" {
  command = plan

  variables {
    private_bridge = "vmbr0"
  }

  expect_failures = [var.private_bridge]
}
