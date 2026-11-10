# Layered backup and recovery — options to evaluate

## Status and recommendation

Proposed, unscheduled infrastructure work; no backup tool, destination or schedule
is selected or deployed by this document. Track delivery in the
[infrastructure backlog](../backlog.md#backup-and-recovery), alongside the
existing service-specific issues #21–#24.

**Consider Borg Backup**, but do not expect one tool to cover every recovery
need. The initial shortlist is **Proxmox Backup Server (PBS) for VM/LXC recovery**
plus **Borg or restic for application-consistent dumps and files**. Start with
simple, documented dumps/exports where useful, then protect completed sets in
an encrypted, versioned off-host repository. A dump left on its source host is
not adequate disaster recovery.

There is no universally better solution: choose against restore requirements,
storage targets, operational effort and verified recovery evidence, not just
backup throughput.

## Recovery at different layers

| Layer | Capture / backup | Restore and limitations |
|---|---|---|
| Rebuildable infrastructure and configuration | Git-managed Terraform/Ansible/Compose, version inventory and sanitized configuration; separately protect state and secrets | Rebuild a host/service; Git alone does not contain application state or all credentials. Test bootstrap without the production Forgejo service. |
| VM / LXC | Evaluate PBS on [prox01](../../systems/prox01/README.md), including guests on prox04 | Restore a whole guest or recover supported files. Assess guest quiescing/database consistency, external mounts and passthrough storage; a live snapshot is not automatically an application-consistent backup. |
| Whole application | Supported service backup/export or coordinated database dump plus matching files/configuration | Restore the service on a compatible isolated instance, including identities and permissions. Record versions, backup window and cross-component consistency. |
| Database | Engine-supported logical dump, online backup API, or coordinated physical backup | Logical dumps aid portability but can be slow to restore; physical backups can have stricter version requirements. Point-in-time recovery requires additional engine-specific logging and retention, if the agreed RPO needs it. Never assume copying an active database file is safe. |
| General files / volumes | Borg/restic over stable files and completed dumps, or a quiesced filesystem capture | Recover a deleted file, directory or historical version; verify ownership, modes, ACLs, xattrs and links where required. Raw live Docker-volume copies may be inconsistent. |
| Portable user exports | Editable drawing exports, Zabbix templates, configuration exports and other supported formats | Recover selected content without restoring the entire service; exports may omit history, identities, attachments or dependencies. They complement full backups. |

For each layer specify **RPO** (acceptable data loss), **RTO** (acceptable recovery
time), owner, scope/exclusions, destination, schedule, retention, consistency
method and restore procedure. Exercise both individual-item recovery and complete
service/guest recovery where applicable.

## Tool comparison / decision criteria

| Option | Good fit | Trade-offs to check |
|---|---|---|
| Borg Backup | Encrypted, deduplicated, compressed file archives to local storage or a controlled remote host over SSH | Strong candidate for owned Linux backup storage. Check supported Borg major version, client/server compatibility, retention, repository maintenance and append-only access. Not a database consistency mechanism; native object-storage destinations are not its primary fit. |
| restic | Encrypted, deduplicated file backups to local/remote storage, including S3-compatible object storage | Potentially simpler than Borg when object storage is the requirement. Check backend costs, bandwidth, retention/pruning, integrity checks and restore metadata/platform support. Also requires consistent input datasets. |
| Proxmox Backup Server | Proxmox VM/LXC backups and integrated guest recovery; also assess its file backup client where useful | Existing installation is not proof of readiness. Assess datastore capacity, verification, access, encrypted recovery and independent copies. Inventory storage omitted from guest backups. A datastore on prox01 alone does not survive loss of that host/site. |
| Plain dumps / exports / tar archives | Transparent first step, portable database recovery and emergency manual recovery | Simple to inspect and restore, but scheduling, versioning, encryption, checksums, retention, monitoring and remote copies still need implementation. Include a manifest; treat these as payloads for a backup system, not an equivalent to a managed repository. |
| rsync / Git mirrors | Transport completed sets or maintain useful secondary copies | A current mirror can propagate deletion/corruption and lacks historical recovery unless separately versioned. Neither a Git mirror nor a file sync is a complete service backup. |

Do a small Borg/restic restore comparison using representative files and a
completed database dump. Measure backup size/time, single-file and full-set
restore time, restore permissions, unattended key recovery and maintenance effort.
Assess PBS separately with a disposable guest. Avoid deploying two overlapping
file-backup tools unless a concrete requirement justifies the extra operations.

## Service-specific scope

- **Forgejo (#21):** consistent database plus repositories, configuration, LFS,
  attachments and package/registry data where enabled. Preserve a runbook and
  backup access outside Forgejo so its own outage does not block recovery.
- **Zabbix (#22):** supported template exports are portable item-level recovery;
  decide separately whether full database/configuration recovery needs an
  additional issue. Template exports alone do not preserve monitoring history.
- **massage-brighton (#23):** pull only completed sets, matching the database,
  application and uploads; validate existing backup production and retention.
- **MeshCentral (#24):** database, configuration, files and certificate/identity
  keys; restore with a test agent and no production-agent contact.
- **Excalidraw:** consistent MongoDB capture plus configuration, protected full
  scene links/keys and editable exports with embedded images. The proposed
  standalone Mongo deployment must use a supported consistency procedure, such
  as stopping writes during a dump; do not assume replica-set oplog features are
  available. Prove old links and images work after isolated recovery. See the
  [deployment gate](excalidraw.md#open-decisions--deployment-gate).
- **Home automation:** protect Home Assistant and each sibling service, including
  Zigbee coordinator recovery data; see the
  [stack backup boundary](home-automation-stack.md#backup-and-safety).

## Acceptance / issue-ready scope

Proposed Forgejo issue title: **Evaluate layered backup/restore strategy: Borg,
restic, PBS and portable dumps**. Label: **backlog**; no sprint assignment.
Issue creation is pending; the local backlog is not evidence of a published issue.

- [ ] Inventory systems, live data engines, sizes, change rates and excluded storage.
- [ ] Define per-service/per-layer RPO, RTO and item-level versus full recovery needs.
- [ ] Compare Borg, restic, PBS and simple dump/export payloads; record the chosen
  combination and rejected alternatives, including destination and recurring costs.
- [ ] Specify supported consistency procedures and backup-set manifests with
  timestamps, source/version inventory and integrity evidence, without secrets.
- [ ] Specify retention and a 3-2-1-style independent-copy plan, including a copy
  outside the source host/site and an offline or immutable copy where practical.
  Encryption does not prevent deletion; check deletion rights, append-only/object
  lock semantics and retention/pruning interactions before relying on them.
- [ ] Protect keys and recovery credentials independently of the source service;
  test recovering when that service and its ordinary credentials are unavailable.
- [ ] Define automation and failed/stale/incomplete-backup alerts, repository
  verification and capacity monitoring. Do not prune last known-good sets after
  failed backups; define a tested repository-maintenance policy.
- [ ] Demonstrate an individual-file restore, portable dump/export restore and a
  disposable VM/LXC restore; record timings against objectives and application
  checks, not merely a successful backup exit status.
- [ ] Record clean-room runbooks, restore dependencies and safe network isolation
  so restored services do not send email, run production jobs or contact agents.
- [ ] Feed decisions into #21–#24, the Excalidraw commissioning gate and PBS
  exploration; create missing full-service recovery issues where scope is absent.

## References for evaluation

- [Borg documentation](https://borgbackup.readthedocs.io/)
- [restic documentation](https://restic.readthedocs.io/)
- [Proxmox Backup Server documentation](https://pbs.proxmox.com/docs/)

Validate supported versions and backend-specific behaviour during the trial;
these links are evaluation starting points, not evidence of completed testing.