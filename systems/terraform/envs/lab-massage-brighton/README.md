# Lab WordPress VM — massage-brighton

This standalone Terraform root manages one disposable dev clone on **prox04** from a verified Ubuntu 26.04 cloud-init template. It uses the shared [VM module](../../modules/vm), its own local state, and VM ID 5101 in the proposed 5100–5199 range. Deletion protection defaults off for this dev VM.

Full clone is the reusable default; the current local `terraform.tfvars` opts into `linked_clone = true`. The template's source disk must already reside on the configured datastore, and the template must be retained for the clone's lifetime. Changing clone mode on the managed VM requires replacement. The root volume is 100 GiB to match the source template; set `disk_size_gb` explicitly if the verified template's disk size differs. Proxmox cannot shrink a cloned disk.

## Internal-network boundary

The VM NIC attaches to `private_bridge`. Terraform deliberately has no default for that bridge and requires `private_network_confirmed = true`. Verify on prox04 that the selected bridge has no public/WAN ingress and that its routing/DHCP/DNS behavior is appropriate. The operator has identified `vmbr0` as internal; confirm prox04's `vmbr0` attachment and routing. A bridge name, tag, VM label, or host firewall alone does not establish isolation. The guest Ansible firewall allows HTTP only from the configured internal client CIDR, SSH only from the admin CIDR, and denies other inbound traffic; outbound access is allowed for updates. Confirm the Proxmox network and host/edge firewall independently.

## Required preflight

Before using real values:

- Verify the source is a clean Ubuntu 26.04 cloud-init template on prox04, with working cloud-init, `qemu-guest-agent`, root disk on `scsi0`, and compatible `ide2` cloud-init disk.
- Confirm prox04 API origin, datastore, DHCP, DNS and internal routing; confirm `vmbr0`'s prox04 attachment before applying.
- Confirm candidate VM ID 5101 is unused on the target Proxmox cluster with `bash ../../scripts/check-vm-id.sh <prox04-api-origin> 5101` using the same API token as Terraform. This is a preflight, not a reservation.
- Confirm the template's root disk is no larger than the configured 100 GiB. Keep TLS verification enabled and use a least-privilege Proxmox API token.
- Ensure the Ansible runner can SSH to the DHCP lease over the trusted internal network. Keep the Terraform state and saved plans private.

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars`, replace placeholders, and set `private_network_confirmed = true` only after verifying the bridge. `PROXMOX_VE_API_TOKEN` supplies provider authentication. The SSH public key is not a private key, but it should be for the dedicated operator account.

From this directory, run `terraform init`, `terraform fmt -check`, `terraform validate`, and `terraform test`. Commit `.terraform.lock.hcl` after initialization. Then create and inspect a saved plan; expect one VM create only. Apply only after review/approval. Use the `wordpress_lab_host` output to obtain the guest-agent IPv4 address. The Terraform root does not set DNS, public NAT, TLS, backups, or a Proxmox firewall policy.

`protect_vm` defaults to `false` because this VM is disposable development infrastructure; the sample local tfvars also sets it false. Destroying the guest is intentionally possible after reviewing the Terraform destroy plan. Never delete or replace another Terraform root's state to resolve an ID conflict.

## Current unresolved inputs

The template ID, datastore, isolated bridge, address ranges, and free VM ID must be confirmed against prox04. The sample values intentionally do not constitute a runnable production plan. This is a lab-only guest; do not store real client/patient data.
