# The Keith Marston Inc company

This fictitious company dose something but has many of the standard problems...

Dev / Prod environment 

Wazuh for detection
Zabbix for monitoring 
Authentik for IdP


I need to store state - where?
tf will build an Ubuntu 26 machine ../../systems/prox01/terraform/envs/sandbox
we then provision this machine with docker 

Maybe we then add that it is behind a VyOS firewall
We then put Wazuh on the docker 
and then a couple more hosts in the system, which need agents
and then zabbix on the main host in our infra and the agents to all our hosts

but a lot of this then becomes ansible?
but what is stored here in this git and and is zabbix state for example and wazuh state

I want an internal dns zone for this infra  and deploy an internal ca we issue all our internal systems from
externally they will all be <system>.keithmarston.me.uk
and to get certs for external systems generally all via a common Nginx providing the https://<system>.keithmarston.me.uk we use mTLS to login to the statically mapped `10.100.100.143 broker.keithmarston.me.uk`

Forgejo at git.keithmarston.me.uk is the place to store

This will then move to keithmarston.me.uk been a PaaS provider spinning a customer environment on demand 



Copy:

- A per-environment least-privilege token.
- Mandatory tags: owner, env and system.
- Pinned provider and module versions.
- tflint and a security scanner such as Trivy in CI.
- Plan review before apply.
- Scheduled drift detection.
- A tested "rebuild from zero" runbook with stated RPO and RTO.
- Golden images built with Packer, because the current template is an untracked manual dependency.
- Static or DNS-registered IPs for prod instead of DHCP.


Suggested next steps
- Refactor ubuntu-trial into modules/vm and envs/sandbox, with node, datastore, bridge, tags, pool and ID range as variables.
- Stand up a remote state backend on a separate host, and migrate the sandbox state to it.
- Add envs/dev with its own pool, token, bridge and DNS subzone.
- Add a Forgejo Actions pipeline running fmt, validate, test and plan on PRs.
- Choose Ansible for the Docker and agent layer, and feed it an inventory from Terraform outputs.
- Add the internal DNS zone and CA, once there is something to issue certificates to.
- I can draft the module and environment layout, or rewrite terraform.md into a decision record along these lines. Which would you prefer?