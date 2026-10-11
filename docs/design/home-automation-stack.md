# Home automation stack

Status: planned for [infra-home Sprint 1](../sprint-1.md); not yet migrated or deployed from this repository.

## Current installation

Inspected on 2026-10-11 on `iot-home`:

| Service | Manual Compose location | Persistent configuration | Current networking |
|---|---|---|---|
| Home Assistant | `/opt/homeassistant` | `/opt/homeassistant/config` → `/config` | Host network |
| ESPHome dashboard/compiler | `/opt/esphome` | `/opt/esphome/config` → `/config` | Host network |

Both containers use the upstream `stable` image tag and `unless-stopped` restart policy. Home Assistant currently runs privileged; review the actual device requirements before retaining or removing that setting. ESPHome currently has inline dashboard credentials; replace these with protected local configuration and rotate them during migration. Do not copy their values into Git.

## Target topology

One Compose project, **four separate services**:

| Service | Purpose | Networking and persistence |
|---|---|---|
| Home Assistant | Integrations, household UI and automation runtime | Initially retain host networking for existing discovery; reuse existing configuration |
| ESPHome | Dashboard, firmware builds and installation | Initially retain host networking for device discovery; reuse existing configuration |
| Mosquitto | Authenticated MQTT broker | Compose bridge network; persist broker configuration, password/ACL files and message data |
| Zigbee2MQTT | Zigbee coordinator/device transport and HA discovery | Compose bridge network; persist configuration, device database and coordinator backups |

Firmware remains on the ESP32-C6. The SONOFF Dongle-M is a network/PoE coordinator, not a USB device attached to the Docker host.

Zigbee2MQTT can reach Mosquitto by its Compose service name. Host-network Home Assistant cannot use Compose bridge service DNS: give it a deliberately published broker endpoint on the host. Choose its bind address based on required clients; use loopback if only host-local clients need it, or an explicit trusted LAN address with firewall restrictions if remote clients need access. Do not expose MQTT to the WAN.

Restrict the Zigbee2MQTT frontend and ESPHome dashboard to trusted administration clients. Document selected ports and addresses during implementation rather than assuming an entry-point or DNS design that belongs to Sprint 2.

## Deployment contract

- Store the unified Compose definition and non-secret configuration in infra-home. Select and document its runtime deployment directory before cutover.
- Preserve the existing HA and ESPHome data paths initially using explicit bind mounts, avoiding a combined stack accidentally starting with empty relative configuration directories.
- Keep credentials and local environment values outside Git, with restricted permissions. Commit examples with placeholders only.
- Require authenticated MQTT; define separate service accounts and suitable topic permissions. Configure Home Assistant discovery deliberately.
- Verify the Dongle-M address, firmware, coordinator adapter type and TCP port against the device and Zigbee2MQTT documentation; do not guess these values.
- Define restart policies, readiness checks and startup dependencies. Clients must reconnect after broker restarts; Compose startup order alone is not a recovery mechanism.
- Record tested image versions and a rollback/update procedure rather than relying solely on moving tags.
- Review privileges, mounts and published ports against actual requirements; no blanket privilege requirement for the new services.

## Migration and rollback

1. Inventory the existing integrations, secrets, volumes, network/discovery behavior and Compose projects without publishing sensitive values.
2. Take consistent backups of HA and ESPHome configuration and save the current deployment definitions securely. Confirm a usable restore path.
3. Prepare and validate the unified definition, broker authentication and Zigbee2MQTT configuration before stopping existing services.
4. Schedule a short cutover. Stop the old HA/ESPHome Compose services before starting replacements; never run two containers against the same writable configuration directories.
5. Start the unified project against the preserved data, then verify existing HA integrations, dashboard and ESPHome connectivity before adding Zigbee devices.
6. Validate MQTT, coordinator connectivity and a non-heating test device. Verify reconnects after container and host restarts.
7. On failure, stop the new project, restore any data changed incompatibly, and restart the saved original projects. Retain rollback material until acceptance; do not remove persistent volumes as part of cleanup.

## Backup and safety

Cover HA configuration/internal storage, ESPHome configuration/secrets, Mosquitto configuration and persistent data, and Zigbee2MQTT configuration/database/coordinator backup. Use consistent database backup methods, encrypted off-host copies and a tested restore procedure. A Home Assistant backup alone does not cover its sibling services.

HeatMesh owns heating packages, controller firmware and entity mappings. Infra-home owns deployment and recovery. Keep all heating outputs virtual: no boiler or zone-valve relay mapping is part of this migration.