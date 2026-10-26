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



