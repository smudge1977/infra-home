# Infrastructure backlog

Unscheduled work owned by infra-home. Forgejo issues carry the **backlog** label;
these items are not added to a sprint until explicitly planned.

## Planned energy monitoring work

Octopus daily electricity consumption, per-plug daily kWh, unaccounted usage and
additional monitoring plugs are planned in
[Sprint 3 — Electricity dashboard and smart-plug coverage](sprint-3.md), rather
than left as unscheduled backlog work. Heating/controller-specific use of energy
data remains separate from this infrastructure dashboard.

## Local voice assistant and ESP room displays

- [ ] Explore a [local voice assistant](design/local-voice-assistant.md) with the
  Mac providing whisper.cpp speech recognition, Ollama/Llama and local TTS, and
  Home Assistant providing authoritative house state and controlled actions.
  Reuse one or more existing ESP room displays with microphone/speaker hardware
  where supported; first verify the actual boards, audio interfaces, memory and
  local wake-word compatibility without disrupting room controls.
- [ ] Prove the first milestone: **“Okay Nabu” detected locally → speech sent to
  Mac Whisper → transcription shown on the ESP display**. Add language responses,
  read-only house queries, TTS, house-aware reasoning, policy-gated actions and a
  custom wake word only in the staged order described in the design.

Idea only: no sprint or Forgejo issue assigned, no firmware or service deployed.
HeatMesh retains ownership of display firmware and heating behaviour; infra-home
owns supporting services, networking, security and recovery.

## Samba setup note

The repository does not yet document the Samba setup. Record the actual host and
share path, intended clients, account/group permissions, network exposure, and
backup/recovery approach once those details are confirmed. Do not infer a live
deployment or configuration from this note.

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

## Dynamic container tracking and observability

- [ ] Implement the [dynamic container tracking and observability design](design/dynamic-container-observability.md) — [Forgejo issue #29](https://git.keithmarston.me.uk/Home/infra-home/issues/29): classify Docker hosts in NetBox, verify the `docker_host` Ansible dynamic-inventory group, and deploy version-compatible Zabbix Agent 2 discovery and Wazuh Docker lifecycle auditing. Set bounded lost-resource retention, validate the `monitoring=false` opt-out where supported, and route/deduplicate actionable events in Alerta without suppressing production/security signals. Review Docker socket privilege, event/resource retention and rollback before rollout.

Design only: no host integration or agent/listener deployment is claimed. Track as
unscheduled backlog work; coordinate implementation with monitoring appliance
commissioning and alert aggregation.

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