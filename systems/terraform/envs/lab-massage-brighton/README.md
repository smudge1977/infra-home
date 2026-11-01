# Lab WordPress VM — massage-brighton

This standalone Terraform root creates one protected full clone on **prox01** from a verified Ubuntu 26.04 cloud-init template. It uses the shared [VM module](../../modules/vm), its own local state, and a candidate VM ID of 5101 in a proposed 5100–5199 range. No VM has been created by this scaffold.

## Internal-network boundary

The VM NIC attaches to `private_bridge`. Terraform deliberately has no default for that bridge and requires `private_network_confirmed = true`. Before setting it, verify on prox01 that the selected bridge has no public/WAN ingress and that its routing/DHCP/DNS behavior is appropriate. A bridge name, tag, VM label, or host firewall alone does not establish isolation. The guest Ansible firewall allows HTTP only from the configured internal client CIDR, SSH only from the admin CIDR, and denies other inbound traffic; outbound access is allowed for updates. Confirm the Proxmox network and host/edge firewall independently.

## Required preflight

Before using real values:

- Verify the source is a clean Ubuntu 26.04 cloud-init template on prox01, with working cloud-init, `qemu-guest-agent`, root disk on `scsi0`, and compatible `ide2` cloud-init disk.
- Confirm prox01 API origin, datastore, private bridge, DHCP, DNS and internal routing; do not assume `vmbr0` is internal.
- Confirm candidate VM ID 5101 is unused cluster-wide with `bash ../../scripts/check-vm-id.sh <prox01-api-origin> 5101` using the same API token as Terraform. This is a preflight, not a reservation.
- Confirm template disk size is no larger than the configured 40 GiB. Keep TLS verification enabled and use a least-privilege Proxmox API token.
- Ensure the Ansible runner can SSH to the DHCP lease over the trusted internal network. Keep the Terraform state and saved plans private.

Copy `terraform.tfvars.example` to the ignored `terraform.tfvars`, replace placeholders, and set `private_network_confirmed = true` only after verifying the bridge. `PROXMOX_VE_API_TOKEN` supplies provider authentication. The SSH public key is not a private key, but it should be for the dedicated operator account.

From this directory, run `terraform init`, `terraform fmt -check`, `terraform validate`, and `terraform test`. Commit `.terraform.lock.hcl` after initialization. Then create and inspect a saved plan; expect one VM create only. Apply only after review/approval. Use the `wordpress_lab_host` output to obtain the guest-agent IPv4 address. The Terraform root does not set DNS, public NAT, TLS, backups, or a Proxmox firewall policy.

The VM is marked deletion-protected. Teardown requires a reviewed plan after deliberately disabling and applying the protection-only update. Never delete or replace another Terraform root's state to resolve an ID conflict.

## Current unresolved inputs

The template ID, datastore, isolated bridge, address ranges, and free VM ID must be confirmed against prox01. The sample values intentionally do not constitute a runnable production plan. This is a lab-only guest; do not store real client/patient data.
