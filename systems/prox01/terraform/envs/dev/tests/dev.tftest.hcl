# Offline plans of the dev root: no API requests, credentials or state.
mock_provider "proxmox" {}

variables {
  template_vm_id = 9026
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess dev-test"
}

run "empty_by_default" {
  command = plan

  assert {
    condition     = length(output.vms) == 0
    error_message = "Dev must not create VMs until some are declared."
  }
}

run "vm_in_dev_range_on_prox01" {
  command = plan

  variables {
    vms = {
      web = { name = "dev-web", system = "web", vm_id = 5001 }
    }
  }

  assert {
    condition     = output.vms["web"].vm_id == 5001
    error_message = "A VM inside 5000-5099 must plan."
  }
}
