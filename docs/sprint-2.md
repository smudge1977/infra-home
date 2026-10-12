# Sprint 2 — VyOS and split-horizon DNS

Status: planned; addressing, deployment topology and entry-point exposure decisions are not yet confirmed.

## Goal

Establish **VyOS as the firewall and network entry point**, with an internal DNS horizon for **`keithmarston.me.uk`**, so infra-owned services have deliberate routing, access controls and internal names.

This is infra-home Sprint 2, independent of HeatMesh sprint numbering. Build on the working home automation stack from [infra-home Sprint 1](sprint-1.md).

## Work items

Work is tracked in Forgejo with the **sprint 2** label. Each issue links back to this plan; close it only when its completion evidence is accepted.

- [ ] Inventory current router/firewall, WAN/LAN addressing, routes, DHCP/DNS providers and service ingress; identify recovery access before making changes. [Issue #7](https://git.keithmarston.me.uk/keith/infra-home/issues/7)
- [ ] Choose the VyOS placement, interfaces, management network and any VLAN/subnet segmentation; document a topology and address plan. [Issue #8](https://git.keithmarston.me.uk/keith/infra-home/issues/8)
- [ ] Confirm each infra-owned system's host and ownership boundary: which services run on `iot-home`, which are on their own machines, and which are not yet assigned. [Issue #9](https://git.keithmarston.me.uk/keith/infra-home/issues/9)
- [ ] Map internal and external names for each service; record actual hostnames, internal addresses and any deliberately public names under `keithmarston.me.uk` without overcommitting to a whole-zone split-horizon design. [Issue #10](https://git.keithmarston.me.uk/keith/infra-home/issues/10)
- [ ] Decide which service ports are LAN-only, host-local, or intentionally exposed through the network boundary; default to private-only access unless a service has an explicit reason to be reachable beyond the local network. [Issue #11](https://git.keithmarston.me.uk/keith/infra-home/issues/11)
- [ ] Define firewall zones/rules and required routes/NAT. Default-deny unsolicited inbound access; permit only documented service and management flows. [Issue #12](https://git.keithmarston.me.uk/keith/infra-home/issues/12)
- [ ] Define what “entry point” means for this estate: private/VPN access versus deliberately public services, and any reverse proxy/TLS termination needed. VyOS is the network boundary, not automatically an HTTP reverse proxy. [Issue #13](https://git.keithmarston.me.uk/keith/infra-home/issues/13)
- [ ] Design split-horizon resolution for `keithmarston.me.uk`: selected service names resolve to internal destinations for internal clients, with deliberate public answers for external clients. [Issue #14](https://git.keithmarston.me.uk/keith/infra-home/issues/14)
- [ ] Select the internal DNS service, authoritative/override mechanism, upstream resolvers and client delivery through DHCP or explicit settings. Preserve resolution of names not hosted internally. [Issue #15](https://git.keithmarston.me.uk/keith/infra-home/issues/15)
- [ ] Inventory existing public DNS records before changes; preserve required mail-related records and avoid accidentally shadowing the whole public zone with incomplete internal records. [Issue #16](https://git.keithmarston.me.uk/keith/infra-home/issues/16)
- [ ] Agree names, destinations and access policy for each infra-owned system; do not publish sensitive administration endpoints just to provide a hostname. [Issue #17](https://git.keithmarston.me.uk/keith/infra-home/issues/17)
- [ ] Ensure runtime configuration, credentials and generated state remain with the owning system and are not mixed into a single repo root; each host stack remains in its own deployment folder. [Issue #18](https://git.keithmarston.me.uk/keith/infra-home/issues/18)
- [ ] Implement and test the firewall/DNS setup with configuration backups, a controlled cutover and a working rollback procedure. [Issue #19](https://git.keithmarston.me.uk/keith/infra-home/issues/19)
- [ ] Verify routing, internal/external DNS answers, permitted/blocked access and continued operation of the Sprint 1 stack. [Issue #20](https://git.keithmarston.me.uk/keith/infra-home/issues/20)

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

| System | Host | Internal DNS / address | Public DNS name | Ports | Exposure | Owner | Status |
|---|---|---|---|---|---|---|---|
| Home Assistant | `iot-home` | `homeassistant` on private LAN; MQTT broker on local/private endpoint | None by default | `8123` UI, `1883` MQTT, `6052` ESPHome, `8080` Zigbee2MQTT | LAN-only or host-local by default | infra-home | Confirmed host, pending exact names |
| ESPHome dashboard | `iot-home` | `esphome` on LAN/private endpoint | None by default | `6052` | LAN-only | infra-home | Confirmed host, pending exact names |
| Mosquitto broker | `iot-home` | `mqtt` or `mosquitto` on private network; host-local loopback if possible | None | `1883` internal only | LAN-only / host-local | infra-home | Confirmed host, pending exact endpoint |
| Zigbee2MQTT | `iot-home` | `zigbee2mqtt` on private network | None | `8080` UI + coordinator TCP port | LAN-only | infra-home | Confirmed host, pending exact port and endpoint |
| Forgejo, runners and registry | To be assigned | `forgejo`, `runner-*`, registry service names on internal network | Optional public hostname only if approved | `22`, `443`, `80`, registry ports | Internal-first; public only with explicit approval | infra-home | Pending host and ingress decision |
| Zabbix | To be assigned | `zabbix`, `zabbix-web`, agent endpoints on internal network | Optional public hostname only if approved | Web UI, agent ports, monitoring ports | Internal-first, admin UI restricted | infra-home | Pending host and access review |
| MeshCentral | To be assigned | `meshcentral` on internal management network | Optional public hostname only if approved | Web UI, managed-device ports | Internal-first, management only | infra-home | Pending host and access review |
| massage-brighton | To be assigned | Service hostname or ingress target, to be confirmed | Optional public hostname only if approved | Service-specific | Confirm hosting and audience | infra-home | Pending ownership details |
| maillist.cloud | To be assigned | Internal mail/application host, to be confirmed | Existing public mail names preserved | Mail/service ports | Preserve existing public DNS and mail flow | infra-home | Pending public record review |
| VyOS | Firewall/router host | Management network interface and recovery address only | None for admin endpoints by default | SSH/management and firewall ports | Restricted management only | infra-home | Pending topology and recovery path |

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