# Offline mocked plans only: no API, credentials, VM create or network access.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint          = "https://prox04.example.invalid/"
  datastore_id              = "lab-zfs"
  private_bridge            = "vmbr9"
  private_network_confirmed = true
  linked_clone              = false
  template_vm_id            = 9026
  ssh_public_key            = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess test"
}

run "creates_unprotected_lab_clone_on_prox04" {
  command = plan

  assert {
    condition = (
      output.wordpress_lab_host.vm_id == 5101 &&
      output.wordpress_lab_host.vm_name == "lab-massage-brighton" &&
      output.wordpress_lab_host.clone_mode == "full" &&
      output.wordpress_lab_host.root_disk_gb == 100 &&
      output.wordpress_lab_host.deletion_protection == false
    )
    error_message = "The dev lab root must default to an unprotected VM with a 100 GiB root volume."
  }
}

run "selects_linked_clone_when_enabled" {
  command = plan

  variables {
    linked_clone = true
  }

  assert {
    condition     = output.wordpress_lab_host.clone_mode == "linked"
    error_message = "Setting linked_clone=true must report linked clone mode."
  }
}

run "allows_explicit_larger_root_volume" {
  command = plan

  variables {
    disk_size_gb = 120
  }

  assert {
    condition     = output.wordpress_lab_host.root_disk_gb == 120
    error_message = "The root volume size must be configurable for a larger source template."
  }
}

run "rejects_root_volume_smaller_than_minimum" {
  command = plan

  variables {
    disk_size_gb = 19
  }

  expect_failures = [var.disk_size_gb]
}

run "requires_private_network_acknowledgement" {
  command = plan

  variables {
    private_network_confirmed = false
  }

  expect_failures = [var.private_network_confirmed]
}

run "accepts_vmbr0_when_private_network_is_confirmed" {
  command = plan

  variables {
    private_bridge            = "vmbr0"
    private_network_confirmed = true
  }

  assert {
    condition     = output.wordpress_lab_host.vm_name == "lab-massage-brighton"
    error_message = "A verified internal vmbr0 bridge must be accepted when explicitly confirmed."
  }
}
