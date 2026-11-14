# Dynamic container tracking and observability

Status: draft reference architecture; unscheduled and not deployed from this
repository. This design complements the proposed [monitoring appliance](monitoring-architecture.md)
and does not assert that NetBox, Ansible, Zabbix, Wazuh or Alerta are currently
integrated or running.

## Objective

Docker workloads are created, changed and removed more frequently than static
infrastructure. Manually adding every short-lived container to NetBox or Ansible
inventory creates drift and unnecessary work. Keep intended infrastructure
separate from runtime discovery: NetBox describes durable hosts, networks and
services; monitoring and security systems discover and report actual container
workloads.

The target is zero-touch discovery for container lifecycle and health, centrally
managed host configuration, and bounded retention/noise for ephemeral test
workloads.

## Principles

1. **Static and dynamic state have different owners.** NetBox is the source of
   truth for physical hosts, VMs, network interfaces, VLANs, stable addresses,
   roles and permanent services. Monitoring discovers running containers and
   their changing state; it does not turn each container into a NetBox device.
2. **Discover workloads automatically.** Starting a container should not require
   a manual inventory edit before it can be monitored or audited.
3. **Configure hosts consistently.** Ansible consumes NetBox inventory and
   deploys Docker-host configuration, Zabbix Agent 2 and Wazuh agent settings.
4. **Bound ephemeral noise.** Short-lived and explicitly opted-out workloads
   should not leave stale discovery objects or generate avoidable operational
   alerts.
5. **Treat daemon access as privileged.** Access to Docker's control socket can
   confer host-level control. Agent socket access, alternatives and trust
   boundaries must be reviewed before rollout; do not grant broad access merely
   to make a check pass.

## Architecture and responsibilities

```text
NetBox (intended hosts, roles, networks)
       | dynamic inventory
       v
Ansible (groups docker hosts; configures agents and listeners)
       |
       v
Docker hosts: Zabbix Agent 2 <-> Docker Engine/socket
              Wazuh agent docker-listener <-> Docker Engine/API
                    | metrics/discovery       | lifecycle/security events
                    v                         v
              Zabbix Server              Wazuh Manager
                    \                         /
                     \---- actionable events -/
                                v
                         Alerta aggregation
```

| Component | Responsibility | Tracks |
|---|---|---|
| NetBox | Intended infrastructure source of truth | Physical hosts, VMs, interfaces, VLANs, stable IPs, roles and reserved endpoints for durable core services |
| Ansible | Host configuration and provisioning | NetBox-derived host groups; Docker, Zabbix Agent 2 and Wazuh agent configuration |
| Zabbix | Runtime inventory and metrics | Agent 2 Docker discovery, container health and available CPU, memory and network metrics |
| Wazuh | Security and lifecycle audit | Docker listener events such as create, start, stop, die and destroy, subject to the selected Wazuh version and configuration |
| Alerta | Alert aggregation and presentation | Actionable normalized events, deduplication, acknowledgement and environment-aware routing |

NetBox should contain durable infrastructure and stable endpoints, not each
ephemeral container. Reserve addresses and document reverse-proxy routes there
only for persistent, infrastructure-critical services (for example DNS, ingress
or databases) where that matches the existing IPAM and service-record model.

## Implementation standards

### NetBox and Ansible

- Tag or otherwise classify Docker-capable hosts in NetBox (for example with
  `docker-host`) and map that classification to a predictable Ansible group such
  as `docker_host` using `netbox.netbox.nb_inventory`.
- Keep the inventory mapping explicit and test its result against representative
  hosts. Do not infer that a NetBox tag automatically becomes a group without
  validating plugin configuration and group naming.
- Apply monitoring roles only to intended Docker hosts. Keep credentials and
  enrollment secrets in the established secret-management mechanism, not in
  inventory output or Git.

### Zabbix Agent 2 discovery

- Validate the official **Docker by Zabbix agent 2** template against the Zabbix
  server and Agent 2 versions actually selected. Confirm the plugin keys,
  permissions, supported Docker API and discovered macros before linking it to
  production hosts.
- Review the template's **Keep lost resources period** and set it to `1d` (or
  `12h`) if supported and appropriate. This controls when lost LLD entities are
  removed; it is not a substitute for choosing item history/trend retention.
- Filter scratch workloads using a `monitoring=false` Docker label only if the
  selected template exposes that label in discovery and supports a reliable LLD
  filter. Otherwise implement and test an explicit discovery filter; do not
  assume labels are automatically interpreted.
- Docker socket access is highly privileged. Assess the supported Agent 2 access
  model and alternatives (including a constrained, authenticated proxy where
  compatible). If socket access is used, document the risk, ownership, access
  controls and host-specific validation. Membership in the `docker` group is
  effectively root-equivalent on many hosts and must not be treated as a benign
  read-only permission.

### Wazuh Docker listener

- Manage `<wodle name="docker-listener">` and its version-appropriate options in
  `/var/ossec/etc/ossec.conf` through Ansible for the `docker_host` group.
- Verify the selected Wazuh agent's Docker API and dependency requirements before
  installing packages such as `python3-docker`; package name and compatibility
  can vary by distribution and Wazuh release.
- Grant only the Docker daemon access required by the supported listener. Confirm
  the listener reconnects after agent/daemon restarts and that events are
  distinguishable by host and container identity.
- Define event volume, retention and handling of sensitive container metadata
  before enabling collection broadly.

### Alerta noise control

- Route Zabbix and Wazuh events to Alerta using supported integrations or
  webhooks. Preserve source, host, container, environment, severity and lifecycle
  context so operators can investigate in the originating system.
- Define stable deduplication keys and tested mappings for production versus
  lab/development. Use explicit host classification or controlled container
  metadata/prefix conventions; do not rely on an undocumented naming convention.
- Suppress or lower priority only for explicitly non-critical lab/test workloads.
  Verify that actionable production problems and recoveries still arrive and
  that suppression does not hide security events.

## Rollout and acceptance checklist

- [ ] Classify Docker-capable hosts in NetBox and verify the configured dynamic
  inventory produces the intended `docker_host` group.
- [ ] Add and test Ansible roles for Docker-host Zabbix Agent 2 and Wazuh agent
  configuration, including secure daemon access and secret handling.
- [ ] Validate Agent 2 template/version compatibility, discovery fields and
  resource cleanup; configure a tested lost-resource period of `1d` or `12h`.
- [ ] Demonstrate that `monitoring=false` excludes a scratch container if the
  supported LLD template exposes that label; otherwise document the tested
  alternative filter.
- [ ] Verify container create/start/stop/die/destroy events in Wazuh with useful
  host/container context, and confirm agent/daemon reconnection behavior.
- [ ] Verify actionable Zabbix and Wazuh events reach Alerta, deduplicate as
  intended, and preserve production alerts and recovery notifications.
- [ ] Document resource/event retention, Docker socket threat model, rollout
  scope and rollback steps before enabling across all Docker hosts.

## Scope and dependencies

This is a design gate, not a deployment playbook. It depends on inventorying the
existing Zabbix deployment, choosing compatible product versions and resolving
the proposed [monitoring appliance](monitoring-architecture.md) and
[alert aggregation](monitoring-alerting.md) decisions. Keep NetBox as intended
state and do not mirror transient runtime inventory into it.
