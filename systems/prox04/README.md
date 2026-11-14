# prox04 — Proxmox host

## Hardware and role

- Hardware: HPE DL380 server.
- Memory: 256 GB installed as eight 32 GB DDR4-2400 (2400 MHz), 1.2 V, dual-rank RDIMMs. iLO reports four DIMMs per processor, in sockets 1, 4, 9 and 12; all are healthy and in use. The reported DIMM manufacturer and part number are unavailable (`HPE Memory: No`, part number `N/A`).
- Advanced Memory Protection (AMP): Advanced ECC is both the configured and active mode. iLO lists Online Spare (rank sparing) and Intrasocket Mirroring as supported modes, but neither is configured. Memory mirroring is therefore not currently enabled.
- Platform: Proxmox virtualization server.

## Outstanding inventory

- Record the Proxmox version, storage layout, network configuration and hosted VMs/containers.
- Document administration access, update procedures and recovery requirements.
- Assess backup coverage using the Proxmox Backup Server installed on [prox01](../prox01/README.md).