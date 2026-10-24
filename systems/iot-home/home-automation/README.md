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

For a fresh deployment, copy `config/zigbee2mqtt/configuration.yaml.example` to
`config/zigbee2mqtt/configuration.yaml` and set the MQTT password to match the
broker's `zigbee2mqtt` account. Do not overwrite an existing live configuration.
The live configuration, broker credentials, Zigbee coordinator backup (which
contains network keys), database, state and logs are ignored by Git. Back these
up securely outside the repository.

The example uses the temporary USB coordinator at `/dev/ttyACM0`; update both
the serial configuration and Compose device mapping when replacing it with the
PoE coordinator. The broker ACL should allow Home Assistant to read/write
`homeassistant/#` and `zigbee2mqtt/#`, and Zigbee2MQTT to read/write
`zigbee2mqtt/#` and publish discovery messages under `homeassistant/#`.

## Home Assistant ESPHome dashboard

- An admin-only **ESPHome** sidebar dashboard at `/esphome-admin/web` embeds
	`http://192.168.0.114:6052/`. ESPHome remains a separate Docker service, not
	a Home Assistant add-on.
- Install [esphome-dashboard.yaml](esphome-dashboard.yaml) as
	`/opt/homeassistant/config/esphome-dashboard.yaml` and
	[esphome-dashboard-package.yaml](esphome-dashboard-package.yaml) as
	`/opt/homeassistant/config/packages/esphome_dashboard.yaml`. The existing
	`homeassistant.packages` directory include loads the registration and keeps
	existing storage dashboards intact. Validate HA configuration and restart HA
	after installing the package.
- ESPHome's own login still applies inside the iframe. The HA admin restriction
	protects the sidebar dashboard, not direct access to port 6052. Keep the service
	on the trusted LAN and do not expose it to the WAN.
- The embedded HTTP URL matches the current LAN HA URL; HTTPS access to HA
	requires an HTTPS ESPHome proxy URL to avoid mixed-content blocking.

## Home Assistant MQTT and Zigbee administration

- MQTT is configured through **Settings → Devices & services → MQTT**, using
	broker `127.0.0.1`, port `1883`, protocol MQTT 5 and account `homeassistant`.
	Set its password to the corresponding local broker credential; do not store
	credentials in this documentation. HA uses host networking, so the loopback
	broker endpoint is accessible without publishing MQTT to the LAN.
- Zigbee2MQTT publishes Home Assistant discovery messages. The bridge connection
	entity is `binary_sensor.zigbee2mqtt_bridge_connection_state`.

- An admin-only **Zigbee2MQTT** sidebar dashboard at `/zigbee-admin/web` embeds
	`https://z2m.keithmarston.me.uk/`. Its non-secret reference configuration is in
	[zigbee2mqtt-dashboard.yaml](zigbee2mqtt-dashboard.yaml).
- The web UI binds only to `192.168.0.114`, not every host interface. It currently
	has no separate frontend authentication: the HA dashboard's admin restriction
	does not protect direct access to port 8080 or its separate HTTPS proxy host.
	The Nginx Proxy Manager host `z2m.keithmarston.me.uk` forwards to
	`http://192.168.0.114:8080/`; TLS makes the iframe compatible with HTTPS HA,
	but does not provide authentication. Apply an NPM Access List or enable
	Zigbee2MQTT frontend authentication before allowing public access.

## HTTPS through Nginx Proxy Manager

The public HA endpoint is `https://ha.keithmarston.me.uk`, with TLS terminated
by Nginx Proxy Manager and HA still served internally on port `8123`. On
2026-10-17, HA logged the proxy's backend source as `10.100.100.7`; the live
`/opt/homeassistant/config/configuration.yaml` therefore has this root-level
HTTP configuration:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.100.100.7
```

Trust only the address HA actually sees for NPM. Do not replace it with the
whole LAN or Docker subnet; re-check HA's logs if NPM networking changes. The
config was checked and HA restarted; the HTTPS endpoint then reached HA's login
flow rather than returning `400 Bad Request`.

## Home Assistant update assessment

As of 2026-10-17, the running container is Home Assistant `2026.7.4`; the
current October release is `2026.10.2`. An update is advisable, but was kept
separate from this proxy fix. Before the maintenance window, back up the full
HA configuration and UI-managed state, review the intervening release notes,
and check HACS and the custom Octopus Energy integration for compatibility.
Then update the HA image and verify HA, MQTT/Zigbee2MQTT, ESPHome, dashboards,
and the heating automations. Keep a rollback image available. In particular,
2026.10 includes some integration-specific breaking changes; check whether
they apply to integrations actually in use.

See the official [2026.8](https://www.home-assistant.io/blog/2026/08/05/release-20268/),
[2026.9](https://www.home-assistant.io/blog/2026/09/02/release-20269/), and
[2026.10 release notes](https://www.home-assistant.io/blog/2026/10/07/release-202610/).
