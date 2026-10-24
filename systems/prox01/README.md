# prox01 — Proxmox host and backup service

## Hardware and role

- Hardware: consumer NUC-type machine.
- Memory: 32 GB RAM.
- Platform: Proxmox virtualization server.
- Proxmox Backup Server is installed on this host; installation details and operational readiness remain to be inventoried.

## Terraform trial — Ubuntu 26.04

- Isolated [build/teardown trial](terraform/ubuntu-trial/README.md) for one disposable full clone.
- Target: VM 4001, ZFS01 storage, vmbr0, DHCP; source template ID still to be supplied.
- Review build and destruction plans separately. No existing VMs or host services are managed by this configuration.

## Planned exploration — Proxmox Backup Server

- [ ] Explore the existing installation and record its version, deployment method and datastore configuration.
- [ ] Assess storage capacity, retention, pruning, garbage collection and backup verification.
- [ ] Evaluate VM/container backups from prox01 and [prox04](../prox04/README.md), including access permissions and scheduling.
- [ ] Test backup and restoration with a non-critical workload and record recovery evidence.
- [ ] Review encryption, credential handling and an off-host copy so backups do not rely solely on prox01.

## Outstanding inventory

- Record the Proxmox version, storage layout, network configuration and hosted VMs/containers.
- Document administration access, update procedures and recovery requirements.