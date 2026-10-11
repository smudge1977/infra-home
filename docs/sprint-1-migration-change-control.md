# Sprint 1 migration change control

Status: planned for cutover. This document captures the change record for the Home Assistant / ESPHome migration and should be treated as the working change ticket until the Forgejo instance is reachable from this environment.

## Scope

Migrate the existing Home Assistant and ESPHome stack into the unified infra-home Compose project while preserving the live config and avoiding duplicate writers.

Temporary operating note: the live stack is currently using a USB Zigbee coordinator in pass-through while the PoE Sonoff Dongle-M is awaited; this is a short-term workaround only and not the final target topology.

## Change record

1. Pre-change validation
   - Confirm the existing live stack is still running from /opt/homeassistant and /opt/esphome.
   - Record the current HA version, ESPHome version and current config directory state.
   - Validate the unified Compose project in infra-home with `docker compose config`.
   - Confirm there is no duplicated writer on the same config tree.

2. Backup and safety
   - Create a backup snapshot of /opt/homeassistant/config and /opt/esphome/config.
   - Keep the original docker-compose files and a restore copy of the config in a dated backup directory.
   - Record the current image tags and version markers before any cutover.

3. Stop legacy services
   - Stop the legacy Home Assistant Compose stack from /opt/homeassistant.
   - Stop the legacy ESPHome Compose stack from /opt/esphome.
   - Confirm both are no longer running before proceeding.

4. Start the unified stack against the existing data
   - Launch the infra-home Compose stack from systems/iot-home/home-automation.
   - Reuse the existing /opt/homeassistant/config and /opt/esphome/config bind mounts.
   - Confirm MQTT, HA and ESPHome come up without duplicate config initialization.

5. Validate and sign off
   - Check HA loads successfully and the existing dashboards remain intact.
   - Validate ESPHome connectivity and device configuration remains available.
   - Validate MQTT/Zigbee2MQTT route and coordinator connectivity.
   - If any service fails, stop the new stack and restore the last-good backup before retrying.

## Rollback trigger

If either HA or ESPHome fails to load or there is evidence of duplicate writers or config corruption, revert to the prior legacy compose definitions and restore the backup set before reattempting the change.

## Owner

Infrastructure owner: Keith Marston
