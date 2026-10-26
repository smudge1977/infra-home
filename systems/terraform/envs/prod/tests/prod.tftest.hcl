# Offline plans of the prod root: no API requests, credentials or state.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint = "https://prox04.example.invalid/"
  datastore_id     = "test-ds"
  bridge           = "vmbr0"
  template_vm_id   = 9026
  ssh_public_key   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess prod-test"
}

run "empty_by_default" {
  command = plan

  assert {
    condition     = length(output.vms) == 0
    error_message = "Prod must not create VMs until some are declared."
  }
}

run "vm_in_prod_range" {
  command = plan

  variables {
    vms = {
      web = { name = "prod-web", system = "web", vm_id = 1001 }
    }
  }

  assert {
    condition     = output.vms["web"].vm_id == 1001
    error_message = "A VM inside 1000-1999 must plan."
  }
}
