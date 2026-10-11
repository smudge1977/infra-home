# Home Assistant and associated services

## Delivery plan

[infra-home Sprint 1](../sprint-1.md) owns consolidation of the existing manual Home Assistant and ESPHome deployments into **one Docker Compose project**, adding Mosquitto and Zigbee2MQTT. This supplies the infrastructure portion of HeatMesh Sprint 3; the two repositories have independent sprint numbering.

The stack design and migration boundary are recorded in [Home automation stack](home-automation-stack.md). [infra-home Sprint 2](../sprint-2.md) covers VyOS as firewall/network entry point and split-horizon DNS for `keithmarston.me.uk`.

Separate **configuration you maintain in Git** from **the running Home Assistant installation you back up**. You need both: Git is not a full HA backup.

## 1. What the HA tabs mean

| Component | Responsibility | Heating example |
|---|---|---|
| **Automation** | **When** to do something: triggers, conditions, actions | Start boost when a button is pressed |
| **Script** | **How** to perform a reusable sequence of actions | Enable boost and start its timer |
| **Scene** | A predefined set of entity states—not ongoing control logic | Set several room targets for “Evening” |
| **Blueprint** | A reusable template for creating automations or scripts | Apply the same button behaviour to several rooms |
| **Helper** | Stores a value or represents a control | Target temperature, boost flag, timer |

A scene setting a thermostat target is fine; a scene directly forcing heating relays on should not replace thermostat control.

## 2. Separation between your repositories

### HeatMesh: heating behaviour

Keep the heating-specific source here:

- ESPHome device configuration.
- HA packages: helpers, template sensors, thermostats, scripts and automations.
- Heating dashboards and test scenarios.
- Entity mappings and hardware documentation.

Your homeassistant/packages/heating_lab.yaml currently defines only a lounge setpoint and boost helper. It is a starting point, **not a copy or backup of your live HA automations**.

### infra-home: running the services

Keep deployment and operational configuration here:

- Home Assistant container definition, volumes and networking.
- MQTT and Zigbee2MQTT deployment.
- Backup schedules, storage and retention.
- Configuration deployment and restore procedures.
- Secret-management arrangements—not secret values in a public repository.

**HeatMesh defines what heating does; infra-home defines how the services run and recover.**

## 3. UI-managed versus Git-managed HA configuration

Both are valid, but choose **one authoritative editing location for each item**.

| Approach | Best use | Important detail |
|---|---|---|
| **HA UI-managed** | Experiments and general household automations | UI automations normally live in the HA configuration’s automations YAML; other UI configuration can live in internal storage |
| **Git-managed YAML packages** | Tested, repeatable heating logic | Edit in the repository, deploy into HA, validate and reload |

Recommended here:

- Use the UI to explore and prototype.
- Move established heating behaviour into HeatMesh packages.
- Keep unrelated household automations UI-managed if that is more convenient.
- Remove or disable the prototype when replacing it with a package automation—otherwise both may run.

Package-defined automations can appear in HA, but are generally not editable through the automation UI. Packages also need to be enabled in HA configuration; merely having the file in this repository does not load it.

## 4. Backup: two complementary layers

### Git: source history

Version your intended YAML, deployment configuration and documentation. This gives you review, diffs and rollback.

Exclude credentials, tokens, databases, generated files and HA’s internal storage. **Do not publish the whole HA configuration directory**, particularly with your planned public mirror.

### Recoverable backups: installation state

Use **Settings → System → Backups** for scheduled HA backups, where supported by your installation. Check what the backup actually includes.

Also protect the surrounding infrastructure:

- HA configuration, including internal storage containing integrations and UI-managed settings.
- Zigbee2MQTT data and coordinator backup, where supported.
- Deployment configuration and required secrets.
- Any external databases or other service data you need.

For your Docker installation, do not assume a Home Assistant backup also includes sibling MQTT/Zigbee2MQTT containers or their volumes.

Keep an encrypted copy **off the HA host**, preserve the backup recovery key separately, and test restoration. For filesystem/database backups, use a consistent backup method rather than blindly copying live database files.

## 5. Heating-specific boundary

A useful division is:

**Wall controller → user intent → HA heating logic → zone demand → hardware**

- **ESPHome:** display, touch/buttons, local sensing and device health.
- **HA:** schedules, setpoints, boost expiry and combining room demands into zone demands.
- **Zigbee2MQTT:** device communication—not the heating policy.
- **Hardware:** physical interlocks and safe failure behaviour; software must not be their substitute.

For HeatMesh Sprint 1 and Sprint 3, keep the heating output boundary virtual. Infrastructure delivery must not connect those virtual outputs to physical heating relays.

**Practical recommendation:** Git-managed packages for heating, UI-managed configuration for experimentation, and scheduled off-host backups for the complete installation.