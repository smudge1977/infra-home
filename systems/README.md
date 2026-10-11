# System deployment layout

This repository is split by system ownership and by host, not by one shared Compose project.

- [prox04](prox04/README.md) — Proxmox host on an HPE DL380 with 256 GB RAM.
- [prox01](prox01/README.md) — Proxmox host on a consumer NUC-type machine with 32 GB RAM; Proxmox Backup Server is installed, with exploration planned.
- `systems/iot-home/home-automation/` — Home Assistant, ESPHome, Mosquitto and Zigbee2MQTT for the `iot-home` host.
- `systems/forgejo/` — Forgejo, runners and registry deployment inventory.
- `systems/zabbix/` — monitoring stack deployment inventory.
- `systems/meshcentral/` — remote management stack deployment inventory.
- `systems/maillist/` — mail-hosted services deployment inventory.
- `systems/massage-brighton/` — application hosting deployment inventory.

The network boundary, firewall rules and split-horizon DNS remain the responsibility of Sprint 2. The service folders describe what runs, while VyOS defines what is allowed to reach it.
