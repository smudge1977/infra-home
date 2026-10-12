# Infrastructure backlog

Unscheduled work owned by infra-home. Forgejo issues carry the **backlog** label;
these items are not added to a sprint until explicitly planned.

## Planned energy monitoring work

Octopus daily electricity consumption, per-plug daily kWh, unaccounted usage and
additional monitoring plugs are planned in
[Sprint 3 — Electricity dashboard and smart-plug coverage](sprint-3.md), rather
than left as unscheduled backlog work. Heating/controller-specific use of energy
data remains separate from this infrastructure dashboard.

## Backup and recovery

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
- Keep runtime credentials, private keys, databases and sensitive backup payloads
  out of Git. Encrypt off-host copies and use least-privilege backup access.
- Monitor failed or stale backups and preserve the last known-good backup.
- Record successful isolated restore evidence and a recovery runbook before
  closing an issue. Evaluate the existing Proxmox Backup Server on
  [prox01](../systems/prox01/README.md) as an option, not an assumed destination.