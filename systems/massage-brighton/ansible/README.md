# Lab WordPress deployment

This Ansible playbook configures the separately managed Ubuntu 26.04 guest as a lab WordPress host. It installs Nginx, PHP-FPM/extensions, MariaDB, WP-CLI and UFW; downloads a pinned WordPress release with a required SHA-256; checks core files against WordPress's official checksum API; configures a local-only database; and enables a PHP-FPM-backed Nginx site.

## Network and security boundaries

- Use a separate deployment SSH identity/account. Do **not** use the forced-command `agent-inspect` key from the read-only host-exec POC.
- Set the inventory to the private IPv4 address reported by Terraform's guest agent. Use only a verified private bridge and internal client/admin CIDRs. The deployment play fails closed unless the host identity is exactly `lab-massage-brighton` and the address is RFC1918.
- UFW denies unsolicited inbound traffic; port 80 is allowed only from `wordpress_internal_cidr`, and the configured SSH port only from `wordpress_admin_cidr`. Outbound traffic is allowed for updates. Use a clean guest firewall configuration: UFW rules are additive and this play does not remove any pre-existing broad allow rules. UFW rules do not replace Proxmox/edge network isolation; verify both.
- HTTP is not encrypted. Use only a trusted, isolated internal network for the initial setup wizard. Before real user data or credentials are entered, add internal TLS (or an approved internal reverse proxy) and backups. This lab must not hold production/patient data.
- The playbook does not configure DNS, public NAT, TLS, backups, SMTP, or a Proxmox firewall policy.

## Inputs required before running

1. Copy `inventory/lab.example.yml` to the ignored `inventory/lab.yml`; set the actual Terraform guest IP, operator private-key path, trusted internal client CIDR, and admin CIDR. Keep the private key outside this repository.
2. Select a WordPress release version and its official archive SHA-256; set both in inventory. The playbook refuses to download an unpinned archive.
3. Use `ansible-vault create group_vars/vault.yml` and add the keys shown in `group_vars/vault.yml.example`, with unique long random values. Do not create a plaintext secret file first. Never commit plaintext secrets or put the vault password in source control.
4. Install the collections from `requirements.yml` and use an Ansible controller with network access to the private guest, Ubuntu package mirrors, and WordPress checksum API.

From this directory, review the inventory and run `ansible-playbook --syntax-check`, then a `--check --diff` run. Check mode cannot fully emulate package installation, database configuration or firewall changes. Verify SSH access and the exact CIDRs before the real play; an incorrect admin CIDR can cut off SSH when UFW is enabled. Run the deployment without `--limit` only if inventory contains no other target hosts.

The initial WordPress setup wizard remains for an operator to complete. Core files are root-owned/read-only to PHP; only `wp-content/uploads` is writable by the web worker. MariaDB is local and is not opened in UFW. Validate the finished site from an allowed internal client and validate denied access from an untrusted network.
