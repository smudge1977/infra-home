# Sprint 1 — Home automation service stack

Status: planned. The two existing manual services have been inspected; unified deployment and acceptance checks remain outstanding.

## Goal

Bring Home Assistant and its associated services under one reproducible, Git-managed Docker Compose project in infra-home:

- Home Assistant.
- ESPHome dashboard/compiler.
- Mosquitto MQTT broker.
- Zigbee2MQTT.

The existing manual Compose installations are in `/opt/homeassistant` and `/opt/esphome`. Preserve their configuration and working integrations during migration.

This is **infra-home Sprint 1**, providing the infrastructure portion of **HeatMesh Sprint 3**. Heating behavior, controller firmware and heating entity mappings remain HeatMesh responsibilities.

## Work items

- [x] Inspect the existing Compose definitions, persistent configuration paths and running services.
- [x] Record the [target stack and migration design](design/home-automation-stack.md).
- [ ] Inventory integrations, discovery requirements, device access and backup coverage; record outstanding coordinator settings without exposing secrets.
- [ ] Add the unified Compose definition and non-secret service configuration to infra-home, with protected local secrets and documented runtime paths.
- [ ] Retain existing HA/ESPHome data paths for the initial cutover; review HA privilege requirements and replace/rotate inline ESPHome dashboard credentials.
- [ ] Configure authenticated Mosquitto, service accounts/topic permissions, persistence and a broker endpoint usable by host-network HA.
- [ ] Configure Zigbee2MQTT, HA discovery and the verified SONOFF Dongle-M network coordinator connection.
- [ ] Define readiness checks, restart/reconnection behavior, version/update policy and administration access restrictions.
- [ ] Back up, perform a controlled cutover, and validate rollback without duplicate writers against configuration directories.
- [ ] Test consistent encrypted off-host backups and restoration for all four services.
- [ ] Record acceptance evidence and hand the working transport/integration layer to HeatMesh.

## Acceptance criteria

- A single Compose project manages all four services; the old manual projects are no longer managing the same containers.
- Existing HA configuration, integrations, heating-lab dashboard and ESPHome device connectivity are preserved.
- HA and Zigbee2MQTT authenticate to the intended Mosquitto broker; anonymous access is disabled and MQTT is not WAN-exposed.
- Zigbee2MQTT reaches the network coordinator; one suitable test device reports expected data into HA, without commanding heating hardware.
- Container and host restarts preserve state and recover connectivity without manual repair.
- Runtime paths, credentials handling, tested versions, update/rollback steps and off-host restore evidence are documented.
- Secrets, generated state and databases are excluded from Git.
- No physical boiler or zone-valve relay is connected to the virtual heating model.

## Out of scope

VyOS cutover, split-horizon DNS and network entry-point design belong to [Sprint 2](sprint-2.md). Forgejo/runners/registry, massage-brighton, Zabbix, MeshCentral and maillist.cloud remain infra-owned systems, but their deployments are not added to this sprint by listing them in the inventory.

## References

- [Home automation stack](design/home-automation-stack.md)
- [Home Assistant ownership and backup guidance](design/homeassistant.md)