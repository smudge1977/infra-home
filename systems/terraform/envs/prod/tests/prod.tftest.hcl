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

run "engineering_vlan_is_passed_to_module" {
  command = plan

  variables {
    bridge = "vmbr0"
    vms = {
      engineering = { name = "engineering", system = "engineering", vm_id = 1001, vlan_tag = 1000 }
    }
  }

  assert {
    condition     = module.vm["engineering"].vm_id == 1001
    error_message = "The engineering VM with a VLAN tag must plan in the production range."
  }
}
