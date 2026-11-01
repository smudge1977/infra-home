# massage-brighton

This system is owned by infra-home and is being prototyped as a separate host-specific stack.

## Lab WordPress host

- [Terraform root](../terraform/envs/lab-massage-brighton/README.md) defines a protected Ubuntu 26.04 full clone on prox01. It is intentionally blocked until the template, datastore, private bridge and candidate VM ID are verified.
- [Ansible deployment](ansible/README.md) installs Nginx, PHP-FPM, MariaDB and a checksum-verified WordPress release, with UFW limited to internal HTTP and admin SSH CIDRs.

The host is a lab-only POC, not production-ready. Network isolation must be verified at the Proxmox bridge and edge; host firewall rules are an additional layer, not a substitute. Do not store production or patient data. HTTPS, backup/restore, DNS, external exposure and operational monitoring remain out of scope.
