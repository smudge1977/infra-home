# Sandbox environment — Ubuntu 26.04 build/teardown trial

The `sandbox` root configuration using the `bpg/proxmox` provider. It calls the
shared [`modules/vm`](../../modules/vm) module for the VMs in `vms` (default: one
disposable trial), not the host itself, its backup service, or existing guests.
Hosts are standalone Proxmox servers, so each environment has its own API
origin, token, datastore, bridge and template:

| Env | Host | VM IDs |
| --- | --- | --- |
| [dev](../dev) | prox01 | 5000-5099 |
| sandbox (this) | prox04 | 4000-4099 |
| [prod](../prod) | prox04 | 1000-1999 |

Sandbox and prod share prox04: use separate API tokens scoped to separate pools,
and keep the ID ranges disjoint. Endpoint, datastore, bridge and template ID have
no defaults here and must be supplied in `terraform.tfvars` from prox04. Node,
pool and the VM ID range are variables (defaults in [variables.tf](variables.tf)).
The module adds mandatory `env-*`, `system-*` and `owner-*` tags and rejects an
ID outside `vm_id_range`. The pool must already exist. No infrastructure changes
happen until an explicitly reviewed apply.

**Pending migration:** the live trial VM 4001 is still on prox01, and the local
`terraform.tfvars` is pinned to prox01 until it is torn down (steps below). Do not
repoint the endpoint or node while it is in state: the old VM would be orphaned.
After teardown and an empty `terraform state list`, replace the tfvars with prox04
values from `terraform.tfvars.example`.

The `moved` block in [main.tf](main.tf) adopts the VM previously tracked as
`proxmox_virtual_environment_vm.ubuntu_trial` in the former `ubuntu-trial` root,
so the first plan after the refactor is an in-place update (new tags), not a
replacement. Stop if any plan proposes a destroy or replace.

## Agreed target

| Setting | Trial value |
| --- | --- |
| Host | prox04 target; currently still on prox01 until teardown |
| API origin | prox04: supply in tfvars. prox01 (current): https://prox01.keithmarston.me.uk/ — user-confirmed Nginx proxy on 443 |
| Storage | prox04 datastore from tfvars (current: ZFS01) |
| Network | prox04 bridge from tfvars (current: vmbr0), IPv4 DHCP |
| Trial VM | 4001 / tf-ubuntu2604-trial — must be unused cluster-wide |
| Guest | Ubuntu Server 26.04 LTS, cloned from an existing template |
| Resources | 2 vCPUs, 2048 MiB RAM, 20 GiB root disk |
| Access | ubuntu, SSH public key; no password supplied by Terraform |

The source template ID and SSH public key are still required. The template is
referenced by ID only: it is **not** a Terraform resource and is not deleted by
teardown. A full clone gives the trial independent disks. Set `linked_clone = true`
for a linked clone: its source disk must already be on ZFS01 on prox01, and the
template/base disk must be retained for the entire life of the clone. Linked mode
omits the clone API's target storage argument; it cannot relocate the source disk.
The configured root disk and cloud-init drive still use ZFS01. Changing clone
mode for an existing guest may require replacement: inspect the plan first.

## ID and deletion safeguards

- Proxmox rejects creation using an occupied cluster-wide VM/LXC ID; a clone
   request does not overwrite or automatically adopt an existing guest.
- Before a **first create or rebuild after teardown**, run
   `bash ../../scripts/check-vm-id.sh https://prox01.keithmarston.me.uk 4001` using the same
   endpoint/ID as your Terraform inputs and the same token environment. It calls
   the read-only `/cluster/nextid?vmid=4001` check, fails closed on API/ACL/TLS
   errors, and refuses any occupied ID, including a trial already in state.
   Requires Bash, curl and jq. This is an operator preflight, not automatically
   enforced by `terraform apply`, and not a reservation: PVE remains the final
   collision guard if another operator allocates the ID after the check.
- A resource precondition rejects a trial ID equal to the template ID.
- `protect_vm = true` is the default and sets Proxmox's deletion-protection flag.
   Explicitly disable it and apply the reviewed in-place change before teardown.
   An administrator can bypass this flag; it is not a security boundary. It only
   protects a VM once the provider has successfully configured it, not necessarily
   a partial clone left by a failed create.
- Terraform state is the ownership record, **not an independent identity check**.
   Never import arbitrary existing guests, delete state to resolve a collision,
   or reuse an ID externally while it is still in this state. If someone deletes
   the managed trial outside Terraform and reuses its ID, refresh may mistake that
   guest for the managed resource. Stop and reconcile identity/state before apply.
- `prevent_destroy` is deliberately not set: this root is intended for controlled
   teardown. Review every plan, especially replacements; no `-auto-approve` or
   `create_before_destroy` with a fixed ID. Keep state locked and access restricted.

## Preflight — do not skip

- Confirm prox01's PVE version is supported by the selected provider; host version
  and real API compatibility have not yet been checked.
- Confirm the HTTPS origin reaches the Proxmox API. Direct PVE normally uses
  https://prox01.keithmarston.me.uk:8006/; the supplied address without a port
  assumes an HTTPS proxy on 443. TLS verification stays enabled. Install/trust the
  issuing CA on the Terraform runner if required; do not disable certificate checks.
- Confirm ID 4001 is free across the cluster, ZFS01 supports VM images and has
  capacity, and vmbr0 has DHCP available. Confirm no VLAN tag is required.
- Confirm the source is an actual **Ubuntu 26.04** cloud-init template on prox01,
  not a running VM. Terraform cannot infer its OS from its numeric ID.
- Template contract: root disk on **scsi0**, a cloud-init drive compatible with
  **ide2**, virtio NIC, working cloud-init, and `qemu-guest-agent` installed and
  enabled. Preserve the template's working boot/firmware/controller settings.
  Use a clean/generalized template without production data, embedded credentials,
  custom cloud-init snippets, or inherited extra disks/NICs. Inspect any template
  firewall rules, hooks and backup-job membership before cloning.
- The root disk must be no larger than `disk_size_gb`. Increase the trial disk
  input for a larger source; Proxmox cannot shrink it. Check cloud-init/growpart
  expands the guest filesystem after boot.
- Use a dedicated API token, restricted to the required node/template/storage
  and trial VM allocation/configuration/power/deletion operations. A separated
  token and its underlying user both need appropriate ACLs. Consult the pinned
  provider's documented permissions for your PVE version; do not use root's
  password or broad administrator credentials merely to bypass an ACL failure.
  This clone-only configuration needs no node SSH credentials or snippet uploads.
- Install Terraform >= 1.7 and < 2 on the trusted runner. Use only this directory's
  local state; do not share it between concurrent operators or use another root's
  state. Local state and plans need access controls and secure backups.

## Local setup and credentials

Copy [terraform.tfvars.example](terraform.tfvars.example) to a local
terraform.tfvars file and set the real template ID and **public** SSH key. The
example deliberately fails validation until both placeholders are replaced.

Set `PROXMOX_VE_API_TOKEN` in the Terraform process environment through your
local secret manager or a non-echoing terminal prompt. The provider expects
`user@realm!token-id=secret`. Never send the secret through chat, commit it,
put it in a command-line argument, or paste it into shell history. Do not print
the environment during diagnostics.

The local ignore rules exclude state, variable files, saved plans, provider cache
and crash logs. Keep `.terraform.lock.hcl` committed. Ignore rules are not access
controls: state and plans may contain sensitive values. Do not delete state as a
substitute for teardown.

## Build, verify, tear down, repeat

Run Terraform from **this directory**. Each command below is a separate operator
step; no apply or destroy has been run as part of scaffolding.

1. Run `terraform init`, then `terraform fmt -check`, `terraform validate` and
   `terraform test`. Tests use a mocked provider and never contact prox01. Also
   run `terraform test` in [modules/vm](../../modules/vm).
2. Run `terraform plan -out=build.tfplan`. Inspect the entire plan using
   `terraform show build.tfplan`: expect **one VM create, zero changes and zero
   destroys**. The template must not appear as a managed resource. Stop on any
   unexpected diff, occupied ID, template mismatch or permission failure.
3. After owner approval, run `terraform apply build.tfplan`. Applying a saved plan
   does not prompt again: the explicit approval is the gate before this step.
4. Run `terraform output`. Identify the LAN IPv4 address reported by the guest
   agent. Connect with the corresponding private SSH key as `ubuntu`. Check
   `/etc/os-release` reports 26.04, `cloud-init status --wait` succeeds, CPU/RAM,
   root filesystem size, DHCP/DNS and guest-agent service health. No live acceptance
   has been performed yet. Verify in Proxmox that only VM 4001 was created.
5. Keep no useful data in the guest. Before teardown, set `protect_vm = false`
   in the local variable values, plan and apply **only the reviewed in-place
   protection change**. If that plan proposes replacement or unrelated changes,
   stop and investigate. Then run
   `terraform plan -destroy -out=destroy.tfplan`, then
   `terraform show destroy.tfplan`. Expect **one VM destroy only** and verify its
   ID/name is the trial. Stop if anything else is listed.
6. After explicit approval, run `terraform apply destroy.tfplan`. This irreversibly
   deletes the trial VM and its managed disks; the source template is retained.
7. Run `terraform state list` and confirm it is empty. Confirm VM 4001 and its trial
   disks/cloud-init volume are gone in Proxmox, while the template and pre-existing
   guests are unchanged. `terraform plan -destroy` should report no changes.
8. Remove the two saved plan artifacts. A normal `terraform plan` now proposes a
   fresh build — that is expected. Restore `protect_vm = true`, run the free-ID
   preflight again and repeat the build/teardown once to prove the cycle.

Rebuilt guests have new SSH host keys. Verify the new fingerprint via the Proxmox
console before replacing a stale known-hosts entry; do not disable host-key checks.

If apply fails part-way through (for example guest-agent timeout), inspect both
the Proxmox guest list and `terraform state list` before retrying or deleting
anything. A VM may exist even after an error. Reconcile an orphan deliberately;
never blindly import or delete an occupied ID. Destroying this trial is its
rollback, not a backup strategy for unrelated workloads. Cluster-level backup
jobs may retain backups separately; Terraform teardown does not remove those.

## Reference documentation

- [Proxmox provider](https://registry.terraform.io/providers/bpg/proxmox/0.87.0/docs)
- [VM resource](https://registry.terraform.io/providers/bpg/proxmox/0.87.0/docs/resources/virtual_environment_vm)
- [Ubuntu cloud images](https://cloud-images.ubuntu.com/)

Provider schema validation and offline tests do not prove that the template,
network, permissions or endpoint work. Record live build and teardown results
here after commissioning; none are claimed in advance.

## Validation evidence

- Scaffolding validation: Terraform 1.13.4 (temporary, checksum-verified runner)
   and bpg/proxmox 0.87.0; provider selections/checksums recorded in
   [.terraform.lock.hcl](.terraform.lock.hcl).
- `terraform fmt -check` and `terraform validate` passed.
- Latest regression validation: `terraform validate` and formatting checks for
   the configuration/test HCL passed; 6 mocked Terraform tests passed, including
   linked-clone storage omission, full-clone storage and explicit unprotection.
- Module/env refactor: `terraform test` passed (10 module runs, 1 sandbox run);
   a live read-only plan showed one in-place update (new tags, `started`
   drift) with the `moved` block adopting VM 4001.
- `bash ../../scripts/test-check-vm-id.sh`: 8 passed against the actual preflight script
   with a fake curl transport (no API calls). Covers free/occupied or API failure,
   incorrect/null/malformed responses, missing token, bad ID and insecure URL.
- Local user variable values were not modified; their existing formatting-only
   difference is outside the configuration HCL formatting check.
- User-run live attempts subsequently reached PVE through Nginx: first a clone
   permission failure on template 9026, then rejection of the storage parameter
   for linked clones. No successful live build/teardown is recorded here.