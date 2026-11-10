# Infrastructure backlog

Unscheduled work owned by infra-home. Forgejo issues carry the **backlog** label;
these items are not added to a sprint until explicitly planned.

## Planned energy monitoring work

Octopus daily electricity consumption, per-plug daily kWh, unaccounted usage and
additional monitoring plugs are planned in
[Sprint 3 — Electricity dashboard and smart-plug coverage](sprint-3.md), rather
than left as unscheduled backlog work. Heating/controller-specific use of energy
data remains separate from this infrastructure dashboard.

## Excalidraw collaboration service

- [ ] Commission the [Excalidraw project](../systems/excalidraw/README.md): choose
  its host, review/pin supported images, provision private HTTPS/DNS ingress,
  verify cross-browser scene/image persistence and complete isolated backup recovery.
  Follow the [design gate and acceptance checklist](design/excalidraw.md); local
  configuration is not a deployed service. No sprint or Forgejo issue assigned yet.
- [ ] Decide whether saved scene links and editable exports meet the drawing workflow,
  or design a thin named-document layer backed by private Forgejo `.excalidraw` files.
  Login, file listing, explicit Save/Open and version conflict handling are not
  provided by the collaboration stack and are not implemented here.

## Monitoring appliance

- [ ] Commission the proposed [monitoring architecture](design/monitoring-architecture.md):
  one unprivileged Ubuntu 24.04 Proxmox LXC, separate Zabbix/Alerta/Wazuh Compose
  projects and one shared PostgreSQL infrastructure project. Select host/storage,
  inventory existing Zabbix, pin compatible versions and pass the
  [deployment and recovery gates](design/monitoring-deployment.md), including a
  VM fallback if LXC compatibility requires unacceptable privilege/kernel changes.
- [ ] Implement [alert aggregation](design/monitoring-alerting.md): normalize
  actionable Zabbix/Wazuh events into Alerta, verify Teams or the chosen destination,
  test problem/recovery/deduplication and provide an independent outage alert path.
- [ ] Define retention, resource budgets and RPO/RTO; demonstrate isolated recovery
  of both SQL databases, Wazuh state/indices and protected identities. Template
  exports in issue #22 remain supplementary, not a full Zabbix recovery plan.

Design only: no sprint or Forgejo issue assigned, no guest or integration deployed.

## Backup and recovery

- [ ] **Evaluate layered backup/restore strategy: Borg, restic, PBS and portable
  dumps** — Forgejo issue creation pending; intended label **backlog**, no sprint.
  Use the [design and issue-ready acceptance criteria](design/backup-recovery.md)
  to compare **Borg Backup** with restic and the existing PBS installation.
  Cover infrastructure rebuild, VM/LXC recovery, consistent application/database
  dumps, general file/volume recovery and portable exports; define RPO/RTO,
  independent encrypted copies, retention, key recovery and isolated restore tests.
  Feed the decision into issues #21–#24 and Excalidraw commissioning rather than
  assuming one tool or a simple on-host file dump covers every layer.
- [ ] **Forgejo backups** — [Issue #21](https://git.keithmarston.me.uk/Home/infra-home/issues/21).
  Inventory the live database and storage; protect repositories, consistent
  database snapshots, configuration, LFS, attachments and package/registry data
  where enabled. Schedule encrypted off-host backups and test isolated recovery.
  Git mirrors alone do not cover the full service.
- [ ] **Zabbix template backups** — [Issue #22](https://git.keithmarston.me.uk/Home/infra-home/issues/22).
  Automate supported template exports with version metadata and dependencies.
  Keep only sanitized, non-secret exports in Git and test importing them into a
  compatible isolated instance. Template exports are not full database backups.
- [ ] **Pull massage-brighton backups** — [Issue #23](https://git.keithmarston.me.uk/Home/infra-home/issues/23).
  Confirm the host and existing backup source; securely pull completed backup
  sets off-host. Verify application/database/uploads coverage, integrity and
  freshness, then test restoring a pulled set in isolation.
- [ ] **MeshCentral backups** — [Issue #24](https://git.keithmarston.me.uk/Home/infra-home/issues/24).
  Inventory the database, configuration, files and certificate/identity keys
  needed to retain agent trust. Back them up consistently and test recovery with
  a dedicated test agent without contacting production agents.

## Shared completion requirements

- Record the owning host, backup destination, schedule, retention and recovery
  objectives before implementation; do not assume all systems share a host.
- Identify recovery layers and supported data-consistency methods using the
  [backup/recovery evaluation](design/backup-recovery.md); distinguish portable
  exports and completed file/database dumps from whole-service and guest backups.
- Keep runtime credentials, private keys, databases and sensitive backup payloads
  out of Git. Encrypt off-host copies and use least-privilege backup access.
- Monitor failed or stale backups and preserve the last known-good backup.
- Record successful isolated restore evidence and a recovery runbook before
  closing an issue. Evaluate the existing Proxmox Backup Server on
  [prox01](../systems/prox01/README.md) as an option, not an assumed destination.