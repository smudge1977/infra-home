# Offline plans of the sandbox root: no API requests, credentials or state.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint = "https://prox04.example.invalid/"
  datastore_id     = "test-ds"
  bridge           = "vmbr0"
  template_vm_id   = 9026
  ssh_public_key   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeOfflineTestKeyOnlyNotForRealAccess trial-test"
}

run "sandbox_declares_trial_vm" {
  command = plan

  assert {
    condition     = output.vms["trial"].vm_id == 4001 && output.vms["trial"].vm_name == "tf-ubuntu2604-trial"
    error_message = "Sandbox must default to the 4001 trial VM."
  }

}

run "reject_duplicate_vm_ids" {
  command = plan

  variables {
    vms = {
      a = { name = "a", system = "x", vm_id = 4010 }
      b = { name = "b", system = "x", vm_id = 4010 }
    }
  }

  expect_failures = [var.vms]
}
