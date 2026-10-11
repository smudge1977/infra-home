# iot-home: Home automation stack

This folder contains the Home Assistant deployment for the `iot-home` host.

## Scope

- Home Assistant
- ESPHome dashboard/compiler
- Mosquitto MQTT broker
- Zigbee2MQTT

## Design intent

This is a host-specific deployment under the infra-home ownership model. The stack remains local to `iot-home` and is managed as its own project, separate from Forgejo, Zabbix, MeshCentral and other infra-owned services.

## Network policy

Access to HA, ESPHome, MQTT and Zigbee administration is not treated as a default public exposure. The actual firewall, NAT and split-horizon DNS policy belongs to the Sprint 2 VyOS layer.

## Secret handling

Runtime secrets and generated state are stored outside Git. Use the local `.env` and generated broker files for the live system, while the repo keeps only non-secret templates and examples.
