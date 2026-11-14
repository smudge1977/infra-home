# Terraform and IaC

I want to start to learn about terraform

| Layer | Tool | In Git | Not in Git |
|---|---|---|---|
| VMs, pools, DNS records, firewall objects (things with an API) | Terraform | `.tf`, lock file, `*.tfvars.example` | State, real tfvars, plans |
| Host configuration (Docker, agents, users) | cloud-init and Ansible | Roles, inventory generated from Terraform outputs | Vault and secret vars |
| App deployment | Compose, run by Ansible | Compose files, config templates | `.env`, DB volumes |
| App configuration (Zabbix templates, Wazuh rules/decoders, HA packages) | Config-as-code files, or API providers where they are good | Sanitised exports and rule files | Runtime data such as history, alerts, agents' keys |
| App state (Zabbix DB, Wazuh indices, Forgejo DB) | Backups | Nothing | Encrypted off-host backups |

Rule of thumb: Git holds the desired configuration, and backups hold the accumulated data. This matches your existing backlog items (Zabbix template exports, Forgejo backup).

Terraform is not the right tool for Zabbix or Wazuh internals. Use it for the VM and network, then hand off to Ansible. Template exports and rule files are version-controlled artefacts, not Terraform state.

## Production Terraform state convention

Use one dedicated S3 bucket in the personal AWS account for production Terraform
state across both sites. The naming convention is
`infra-tfstate-prod-<AWS_ACCOUNT_ID>`; the account ID is the numeric AWS account
ID, and the name is not site-specific. The reported production bucket is
`infra-tfstate-prod-190837341922` in `eu-west-2` (London). The bucket owner
confirmed in AWS CloudShell on 2026-11-12 that versioning is `Enabled` and default
server-side encryption is `AES256`. Existing production state has not been
migrated as part of this record.

Use a separate state file for each independently managed system or Terraform root
module, rather than combining all production infrastructure into one state file.
Choose a stable key in the form `<site>/<system>/terraform.tfstate`:

| Site | Proxmox hosts | Example state keys |
|---|---|---|
| `osmond` | `pve01`, `pve04` | `osmond/engineering/terraform.tfstate`, `osmond/iot-home/terraform.tfstate` |
| `ethel` | `pve02` | `ethel/proxmox/terraform.tfstate` |

These are naming examples, not evidence that the systems are already managed by
Terraform. A state key identifies a management boundary, not necessarily a single
VM. Keep development and sandbox state separate from this production bucket.

Enable bucket versioning, encryption and public-access blocking, and restrict
access to the appropriate identities. Use state locking for every backend; when
using Terraform's S3 lockfile, ensure the Terraform version supports it and grant
the required lockfile permissions. Treat state and saved plans as sensitive and
keep them and AWS credentials out of Git. Back up and test recovery of state, and
verify the existing state and its ownership before migrating it to a new key.

The [production configuration](../../systems/terraform/envs/prod/versions.tf)
uses the S3 key `osmond/engineering/terraform.tfstate`, with the local AWS CLI
profile `infra-prod-state` and native S3 lockfiles. Terraform 1.10 or later is
required for S3 lockfiles. Backend initialization has succeeded, and production
state now manages the engineering VM at that key. The bucket owner has confirmed
versioning and default encryption as noted above. Use `terraform init -migrate-state`
only after confirming that any local production state is understood and backed up.

## Engineering host network

The production engineering VM runs on `prox04` using `vmbr0`, tagged VLAN `1000`,
on the `dc01` network. The VM uses DHCP on `10.100.100.0/24`; the DHCP server
gateway is `10.100.100.1`. The operator confirmed on 2026-11-14 that a DHCP
reservation is in place for `10.100.100.11`. The address is reserved, rather
than statically configured in the guest. Terraform refreshed the VM's current
lease as `10.100.100.11` on 2026-11-14.



