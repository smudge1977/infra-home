# Sprint 1 — Home automation service stack

Status: planned. The two existing manual services have been inspected; unified deployment and acceptance checks remain outstanding.

## Change control

- [Sprint 1 migration change control](sprint-1-migration-change-control.md)

1. Back up the current host config before cutover:
   ```bash
   sudo mkdir -p /root/backup/homeassistant /root/backup/esphome
   sudo rsync -a --delete /opt/homeassistant/config/ /root/backup/homeassistant/config/
   sudo rsync -a --delete /opt/esphome/config/ /root/backup/esphome/config/
   sudo cp /opt/homeassistant/docker-compose.yml /root/backup/homeassistant/docker-compose.yml
   sudo cp /opt/esphome/docker-compose.yml /root/backup/esphome/docker-compose.yml
   ```

2. Stop the legacy homeassistant and esphome Compose stacks:
   ```bash
   cd /opt/homeassistant && docker compose down
   cd /opt/esphome && docker compose down
   ```

3. Verify both legacy stacks are no longer active before bringing up the unified stack:
   ```bash
   docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -E 'homeassistant|esphome'
   ```

4. Start the unified stack against the existing live data directories:
   ```bash
   cd /home/keith/workspaces/infra-home/systems/iot-home/home-automation
   docker compose up -d
   ```

5. Validate the service load and rollback trigger before closing the change:
   ```bash
   docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
   docker logs homeassistant --tail 80
   docker logs esphome --tail 80
   ```

If either service fails to start cleanly or shows duplicate writer/config corruption, stop the new stack and restore the backup set before retrying the change.

## Goal

Bring Home Assistant and its associated services under one reproducible, Git-managed Docker Compose project in infra-home:

- Home Assistant.
- ESPHome dashboard/compiler.
- Mosquitto MQTT broker.
- Zigbee2MQTT.

The existing manual Compose installations are in `/opt/homeassistant` and `/opt/esphome`. Preserve their configuration and working integrations during migration.

This is **infra-home Sprint 1**, providing the infrastructure portion of **HeatMesh Sprint 3**. Heating behavior, controller firmware and heating entity mappings remain HeatMesh responsibilities.

Progress snapshot (2026-10-11): the unified Compose project, non-secret service templates and authenticated MQTT/Zigbee configuration are now represented in the repo, and the project validates cleanly with `docker compose config`.

Current temporary operating note: a USB Zigbee coordinator is being used in pass-through for the live stack while the PoE Sonoff Dongle-M is awaited; the config should be treated as a short-term replacement and not as the final target topology.

## Work items

- [x] Inspect the existing Compose definitions, persistent configuration paths and running services.
- [x] Record the [target stack and migration design](design/home-automation-stack.md).
- [ ] Inventory integrations, discovery requirements, device access and backup coverage; record outstanding coordinator settings without exposing secrets.
- [x] Add the unified Compose definition and non-secret service configuration to infra-home, with protected local secrets and documented runtime paths.
- [ ] Retain existing HA/ESPHome data paths for the initial cutover; review HA privilege requirements and replace/rotate inline ESPHome dashboard credentials.
- [x] Configure authenticated Mosquitto, service accounts/topic permissions, persistence and a broker endpoint usable by host-network HA.
- [x] Configure Zigbee2MQTT, HA discovery and the verified SONOFF Dongle-M network coordinator connection.
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