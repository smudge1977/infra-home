# infra-home

Deployment, networking and operational recovery for the home infrastructure estate.

## Systems owned by the infra team

| System | Scope |
|---|---|
| Forgejo, runners and registry | Git hosting, CI execution and package/container publishing |
| Home Assistant and associated services | Home Assistant, ESPHome, Mosquitto and Zigbee2MQTT deployment and recovery |
| VyOS | Firewall, routing and network entry point |
| massage-brighton | Application/service hosting and operations; deployment details to inventory |
| Zabbix | Infrastructure monitoring and alerting |
| MeshCentral | Remote management infrastructure |
| maillist.cloud | Application/service hosting and operations; deployment details to inventory |

This is the team's ownership inventory, not a claim that every system is already deployed or included in the first two sprints.

## Current implementation

The repo is structured by ownership and host, not by one monolithic stack:

- `systems/iot-home/home-automation/` contains the live Home Assistant stack for `iot-home`.
- `systems/.../` folders are reserved for other infra-owned systems such as Forgejo, Zabbix, MeshCentral and service hosts.
- Each deployment folder owns its own Compose file, local config and secret handling.

Within the HA stack:

- `systems/iot-home/home-automation/docker-compose.yml` defines Home Assistant, ESPHome, Mosquitto and Zigbee2MQTT in one project.
- `systems/iot-home/home-automation/.env.example` lists the non-secret variables required for local runtime settings.
- `systems/iot-home/home-automation/config/` contains the broker and Zigbee templates, with generated state and secrets kept outside Git.

The existing live runtime paths under `/opt/homeassistant` and `/opt/esphome` are preserved in the initial migration layout while the project remains local-only until cutover. Network exposure and DNS forwarding are intentionally left to the VyOS/Sprint 2 layer.

## Sprint plan

1. [Sprint 1 — Home automation service stack](docs/sprint-1.md): consolidate the existing manual HA and ESPHome Compose deployments into one project, adding Mosquitto and Zigbee2MQTT. This is the infrastructure dependency for the first part of **HeatMesh Sprint 3**.
2. [Sprint 2 — VyOS and split-horizon DNS](docs/sprint-2.md): establish the firewall/network entry point and internal DNS horizon for `keithmarston.me.uk`.

Sprint numbering is local to this repository. HeatMesh owns heating behavior and device firmware; infra-home owns how the supporting services run, are secured and recover.

## Design notes

- [Home automation stack and migration](docs/design/home-automation-stack.md)
- [Home Assistant configuration ownership and backups](docs/design/homeassistant.md)
- [Forgejo deployment](docs/design/forgejo.md)
