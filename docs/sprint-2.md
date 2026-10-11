# Sprint 2 — VyOS and split-horizon DNS

Status: planned; addressing, deployment topology and entry-point exposure decisions are not yet confirmed.

## Goal

Establish **VyOS as the firewall and network entry point**, with an internal DNS horizon for **`keithmarston.me.uk`**, so infra-owned services have deliberate routing, access controls and internal names.

This is infra-home Sprint 2, independent of HeatMesh sprint numbering. Build on the working home automation stack from [infra-home Sprint 1](sprint-1.md).

## Work items

- [ ] Inventory current router/firewall, WAN/LAN addressing, routes, DHCP/DNS providers and service ingress; identify recovery access before making changes.
- [ ] Choose the VyOS placement, interfaces, management network and any VLAN/subnet segmentation; document a topology and address plan.
- [ ] Confirm each infra-owned system's host and ownership boundary: which services run on `iot-home`, which are on their own machines, and which are not yet assigned.
- [ ] Map internal and external names for each service; record actual hostnames, internal addresses and any deliberately public names under `keithmarston.me.uk` without overcommitting to a whole-zone split-horizon design.
- [ ] Decide which service ports are LAN-only, host-local, or intentionally exposed through the network boundary; default to private-only access unless a service has an explicit reason to be reachable beyond the local network.
- [ ] Define firewall zones/rules and required routes/NAT. Default-deny unsolicited inbound access; permit only documented service and management flows.
- [ ] Define what “entry point” means for this estate: private/VPN access versus deliberately public services, and any reverse proxy/TLS termination needed. VyOS is the network boundary, not automatically an HTTP reverse proxy.
- [ ] Design split-horizon resolution for `keithmarston.me.uk`: selected service names resolve to internal destinations for internal clients, with deliberate public answers for external clients.
- [ ] Select the internal DNS service, authoritative/override mechanism, upstream resolvers and client delivery through DHCP or explicit settings. Preserve resolution of names not hosted internally.
- [ ] Inventory existing public DNS records before changes; preserve required mail-related records and avoid accidentally shadowing the whole public zone with incomplete internal records.
- [ ] Agree names, destinations and access policy for each infra-owned system; do not publish sensitive administration endpoints just to provide a hostname.
- [ ] Ensure runtime configuration, credentials and generated state remain with the owning system and are not mixed into a single repo root; each host stack remains in its own deployment folder.
- [ ] Implement and test the firewall/DNS setup with configuration backups, a controlled cutover and a working rollback procedure.
- [ ] Verify routing, internal/external DNS answers, permitted/blocked access and continued operation of the Sprint 1 stack.

## Systems to include in the access/DNS inventory

| System | Decisions to record |
|---|---|
| Forgejo, runners and registry | User ingress, runner-to-Forgejo traffic and registry push/pull paths |
| Home Assistant and associated services | HA user access, restricted ESPHome/Zigbee2MQTT administration, MQTT clients and discovery/coordinator traffic |
| VyOS | Restricted management access and recovery path |
| massage-brighton | Confirm current hosting, intended audience and ingress requirements |
| Zabbix | Monitoring server/agent flows and restricted UI access |
| MeshCentral | Management endpoint and managed-device connection requirements |
| maillist.cloud | Confirm hosting, existing domain/mail dependencies and ingress requirements |

## First-pass host and access inventory

This is a provisional inventory to be confirmed in the live estate. Values are intentionally explicit about network posture while leaving final hostnames and public records to the design review.

| System | Host | Internal name / address | Public name under `keithmarston.me.uk` | Service ports | Access class |
|---|---|---|---|---|---|
| Home Assistant | `iot-home` | `homeassistant` on private LAN; MQTT broker on `iot-home` local/private endpoint | None by default | `8123` HA UI, `1883` MQTT broker, `6052` ESPHome admin, `8080` Zigbee2MQTT admin | LAN-only or host-local by default |
| ESPHome dashboard | `iot-home` | `esphome` on LAN/private endpoint | None by default | `6052` | LAN-only |
| Mosquitto broker | `iot-home` | `mqtt` or `mosquitto` on private network; host-local loopback if possible | None | `1883` internal only | LAN-only / host-local |
| Zigbee2MQTT | `iot-home` | `zigbee2mqtt` on private network, coordinator via LAN TCP endpoint | None | `8080` frontend, coordinator TCP port to Dongle-M | LAN-only |
| Forgejo, runners and registry | TBD | `forgejo`, `runner-*`, registry service names on internal network | Optional public hostname only if approved | `22`, `443`, `80`, registry ports | Internal-first, public only with explicit approval |
| Zabbix | TBD | `zabbix`, `zabbix-web`, agents on internal network | Optional public hostname only if approved | Web UI, agent ports, monitoring ports | Internal-first, admin UI restricted |
| MeshCentral | TBD | `meshcentral` on internal management network | Optional public hostname only if approved | Web UI, remote-agent ports | Internal-first, management only |
| massage-brighton | TBD | Internal service hostname or ingress target, to be confirmed | Optional public hostname only if approved | Service-specific | Confirm hosting and audience |
| maillist.cloud | TBD | Internal mail/application host, to be confirmed | Existing public mail names preserved | Mail/service ports | Preserve existing public DNS and mail flow |
| VyOS | Firewall / router host | Management network interface and recovery address only | None for admin endpoints by default | SSH/management, firewall ports | Restricted management only |

The exact names and any public records should be confirmed against the live network, but the governing rule remains the same: internal systems are internal by default, public exposure is deliberate, and no admin UI or broker should be made WAN-facing without an explicit security decision.

## Acceptance criteria

- VyOS performs the agreed firewall/routing and entry-point role, with documented rules and no loss of recovery access.
- Internal clients consistently use the chosen resolver and obtain the agreed internal answers under `keithmarston.me.uk`.
- External clients retain the intended public DNS answers; unrelated public records, including mail dependencies, continue to resolve correctly.
- Only explicitly approved services are reachable across each network boundary; management UIs and MQTT are not inadvertently exposed to the WAN.
- The home automation stack still works, including required local discovery, ESPHome connectivity, MQTT and the network Zigbee coordinator.
- Reboot/recovery and firewall/DNS rollback have been tested, and configuration backups are protected.

## Out of scope

Rebuilding every application in the systems inventory, replacing heating logic, or enabling physical heating outputs. Public publication of any service requires an explicit access/security decision; DNS alone does not grant permission to expose it.