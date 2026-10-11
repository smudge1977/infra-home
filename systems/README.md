# System deployment layout

This repository is split by system ownership and by host, not by one shared Compose project.

- `systems/iot-home/home-automation/` — Home Assistant, ESPHome, Mosquitto and Zigbee2MQTT for the `iot-home` host.
- `systems/forgejo/` — Forgejo, runners and registry deployment inventory.
- `systems/zabbix/` — monitoring stack deployment inventory.
- `systems/meshcentral/` — remote management stack deployment inventory.
- `systems/maillist/` — mail-hosted services deployment inventory.
- `systems/massage-brighton/` — application hosting deployment inventory.

The network boundary, firewall rules and split-horizon DNS remain the responsibility of Sprint 2. The service folders describe what runs, while VyOS defines what is allowed to reach it.
