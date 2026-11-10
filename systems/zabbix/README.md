# Zabbix

This system is owned by infra-home. Deployment configuration is not yet recorded here.

## Proposed monitoring appliance

The [monitoring architecture](../../docs/design/monitoring-architecture.md) proposes
hosting Zabbix alongside Alerta and Wazuh in one Proxmox LXC, using separate
application Compose projects and a shared PostgreSQL engine with isolated databases
and roles. Alerta would aggregate actionable alerts and own routine notification.

This is unscheduled design work, not an existing deployment or a server upgrade.
Inventory the current server before migration; the template below targets Zabbix
6.0 and must be checked against any selected replacement version. See the
[deployment/recovery contract](../../docs/design/monitoring-deployment.md) and
[alert lifecycle design](../../docs/design/monitoring-alerting.md).

## Linux fail2ban monitoring (Zabbix 6.0)

Import [templates/linux-fail2ban-agent2.yaml](templates/linux-fail2ban-agent2.yaml)
to create **Linux fail2ban by Zabbix agent 2**. The template checks the actual
systemd `fail2ban.service` substate, not just whether a matching process exists.
It does not install, start, or restart fail2ban.

### Requirements

- Zabbix server 6.0 and Zabbix **agent 2** on every target Linux host.
  The original `zabbix_agentd` does not provide the required `systemd.unit.info` key.
- systemd and a unit named `fail2ban.service`.
- A working host agent interface and passive agent access from the server/proxy
  (normally TCP 10050, with the appropriate `Server` allowlist and TLS settings).
- The agent user must be able to query systemd over D-Bus. No root agent,
  `sudo`, `system.run`, or custom `UserParameter` is required.

### Checks and alerts

| Check | Behaviour |
| --- | --- |
| Service substate | Read `systemd.unit.info[fail2ban.service,SubState]` every minute; retain seven days of text history. |
| Service not running | High severity after three consecutive returned values other than `running` (approximately two to three minutes); recovers when a `running` value arrives. |
| Monitoring unavailable | Warning after ten minutes without a value. Covers a missing unit, unsupported key, permissions failure, or agent connectivity failure; inspect the item's error to distinguish them. Recovers when values resume. |

The service-not-running trigger cannot detect a missing unit if systemd returns
an item error instead of a substate; the monitoring-unavailable trigger covers
that case. The checks do not prove that individual jails are enabled or banning.
Existing notification actions must match these trigger severities/tags for alerts
to be delivered. Tags are `component=security`, `service=fail2ban`, and
`scope=availability` (on triggers).

### Import and apply to all Linux hosts

1. In Zabbix 6.0, open **Configuration → Templates → Import**, select the YAML,
	review the import preview, and import the new template. Do not select any
	**Delete missing** options.
2. Link it to one representative Linux host first. In **Monitoring → Latest data**,
	confirm **fail2ban: Service substate** returns `running` and the item has no
	unsupported-key/permission error. On that host, the agent's test mode can also
	query `systemd.unit.info[fail2ban.service,SubState]`; this does not verify
	server-to-agent connectivity.
3. If an interruption is acceptable, stop fail2ban on that test host, confirm the
	High problem after three non-running samples, restart it, and confirm recovery.
	Do not stop a production security service merely to test monitoring without an
	approved maintenance window. Otherwise validate the expression in a lab.
4. Open **Configuration → Hosts**, filter to the Linux host group(s), select the
	intended hosts, and choose **Mass update → Templates**. Use **Link templates**
	to **add** this template; do not replace or unlink existing templates. Review
	the host selection before updating. Include only hosts meeting the requirements.
5. To cover future Linux hosts automatically, also add this template to the
	existing Linux auto-registration/discovery action's **Link to templates**
	operation, if such an action is used. Alternatively, link it as a child of a
	shared Linux template already inherited by all intended hosts, rather than
	linking it both directly and through that shared template. Review the impact
	of changing a shared template before doing so.

For rollback, unlink this template using **Unlink and clear** only if you intend
to remove its inherited items/triggers and their history; ordinary **Unlink**
retains the entities and therefore does not stop monitoring.

### Access and deployment status

No live Zabbix API/MCP configuration or server endpoint is recorded here. Creating
this import file does not deploy it or change any host. Use an authenticated
Zabbix UI or a separately configured, least-privilege Zabbix API/MCP connection
to import/link it. Keep API tokens and passwords out of this repository.
