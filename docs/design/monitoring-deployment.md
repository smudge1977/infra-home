# Monitoring appliance deployment and recovery

Status: proposed deployment contract, 2026-11-08; no Compose files, guest or live
configuration are created by this design. See the
[architecture decision](monitoring-architecture.md) for scope and trade-offs.

## Guest compatibility gate

1. Inventory the selected Proxmox version, kernel, storage backend and available
   capacity. Prepare an unprivileged Ubuntu 24.04 test LXC.
2. Validate Docker/Compose installation, required nesting and user-namespace
   behavior, cgroup/resource limits, volume permissions and the selected storage
   driver. Enable only the Proxmox guest features actually required.
3. Check the selected Wazuh release's Indexer kernel settings, including
   `vm.max_map_count`, memory/locking requirements, certificates and filesystem
   permissions. LXC shares the Proxmox kernel: some requirements may need a
   host-level change and cannot be satisfied inside the guest.
4. Review host-wide effects before approving kernel changes. Do not disable
   AppArmor/seccomp or make the LXC/containers privileged as a blanket workaround.
5. Start the supported stack in a lab; test indexing/search, resource limits,
   guest reboot and a controlled load/retention cycle. Record results.
6. If this fails without unacceptable host changes or reduced isolation, use a
   VM. Re-test the same stack and document the changed deployment boundary.

## Files, state and secrets

Proposed runtime root: `/opt/monitoring`, with `postgres`, `zabbix`, `alerta` and
`wazuh` subdirectories, each owning its Compose definition and non-secret config.
This is a proposal, not an existing runtime path. Record the final paths and
repository ownership before provisioning; retain the existing Zabbix template
area as the source of sanitized template exports.

- Commit Compose definitions, image pins, config templates and example variable
  files with placeholders. Do not commit real environment files or rendered secrets.
- Keep credentials, API tokens, agent enrollment secrets and private keys in
  protected runtime files or the selected secret store, outside Git. Container
  secret support is image-dependent; verify it rather than assuming `_FILE` support.
- Inventory explicit persistent volume/bind-mount paths. Guest rebuild must not
  silently create empty replacement volumes under a different Compose project name.
- Use stable project/network names, documented image versions/digests and
  persistent identities. Avoid unreviewed moving tags.
- Mount dedicated Indexer storage separately; cap log growth and monitor free
  space/inodes for both the root filesystem and index storage.

## Shared PostgreSQL contract

One engine manages **two separate databases**, each with its own application role,
credentials and schema objects. PostgreSQL data lives in one engine data volume:
do not attempt separate database data-directory mounts within the same cluster.

| Database | Application role | Access contract |
|---|---|---|
| `zabbix` | `zabbix` | Zabbix database only; schema/migration permissions required by the chosen release |
| `alerta` | `alerta` | Alerta database only; schema/migration permissions required by the chosen release |

- No application superuser, role creation or cross-database access. Restrict
  default/public connection and schema privileges where appropriate; test that
  each application role is denied access to the other database.
- Use separate restricted administrative/backup identities and protected recovery
  material. Check both clients' compatibility with the chosen PostgreSQL major
  version, extensions, encoding and connection/security settings.
- Initialization scripts typically run only for an empty engine volume. Manage
  subsequent database/role changes deliberately; restarting a container does not
  rerun initialization or rotate existing credentials.
- Define resource budgets and connection limits so one application cannot consume
  all engine capacity. Shared engine maintenance requires a joint outage plan.

## Cross-project connectivity and readiness

Create two explicitly named external Docker networks: one for PostgreSQL/Zabbix
clients and one for PostgreSQL/Alerta clients. Attach the database service to both
with a stable `postgres` alias. Attach only services needing SQL to their
respective database network. These networks reduce accidental reachability;
database roles and authentication remain essential access controls.

Compose must reference the pre-created networks rather than creating unrelated
project-scoped networks. Do not publish PostgreSQL to the LAN/WAN. Keep Wazuh's
internal network separate. Provide a deliberately scoped API path from alert
senders/adapters to Alerta; do not join every service to one unrestricted network.

Cross-project `depends_on` is not available. Deploy the database project first,
wait for authenticated database readiness, then start clients. Applications must
retry/reconnect after later database restarts. Health checks, restart policies and
deployment orchestration must handle failure, not merely a happy-path startup order.

## Network and access policy

- Internal-first: no public exposure of PostgreSQL, Indexer or manager APIs.
- Put web UIs/APIs behind selected private HTTPS ingress with authentication and
  restricted administration access; bind host ports to loopback or a deliberate
  trusted interface, not indiscriminately to all interfaces.
- Permit only needed Zabbix agent/proxy flows and Wazuh enrollment/event flows
  from approved networks. Record actual ports/protocols for the selected versions.
- Use supported authenticated/encrypted agent communication; protect Wazuh
  certificates and enrollment identities. Do not enable anonymous enrollment.
- Scope API tokens and outbound notification access. Document secret rotation and
  revocation without exposing their values in logs or evidence.

## Backup layers and restore sequence

Follow the [backup/recovery evaluation](backup-recovery.md). A guest backup,
template export or live copy of database files alone is not the full recovery plan.

| State | Protection requirement |
|---|---|
| Guest/configuration | Rebuild definitions plus a tested guest backup where selected |
| PostgreSQL | Consistent logical dumps of both databases and protected role/global definitions; record engine version and restore order |
| Zabbix | Database, configuration and relevant external scripts/files; sanitized template exports are supplementary |
| Alerta | Database, routing/plugins/configuration and protected integration secrets |
| Wazuh manager | Supported backup of configuration, rules, agent identities/keys and required operational state |
| Wazuh Indexer | Version-supported consistent snapshot/restore, including security configuration as required; verify snapshot destination support |
| Dashboards/certificates | Required saved configuration, trust material and securely backed-up private keys |

LXC bind mounts or additional storage are not automatically included in all PBS/
guest backup configurations. Verify inclusion/exclusion and restore evidence for
every mount; snapshots on the same host are not independent backups.

Set RPO/RTO, backup frequency, retention and encrypted off-host destinations before
commissioning. Decide whether historical indices are recoverable data or may be
discarded/re-ingested; do not assume upstream logs remain available. Monitor
backup freshness and preserve the last known-good copies.

Restore in an isolated network: rebuild guest/networks → restore PostgreSQL roles
and databases → restore Wazuh state/certificates/index snapshots using its supported
sequence → start application services → verify queries and agent trust → verify
alert delivery. Disable notifications and prevent restored services contacting
production agents during tests. Record elapsed time and data-loss bounds.

## Upgrades, migration and rollback

Inventory any existing Zabbix server first. Back up its compatible database and
supporting state, preserve its current deployment, and rehearse the target version's
supported migration in isolation. Do not change production agents as part of design.

Upgrade one application project at a time within supported compatibility ranges.
Treat PostgreSQL major upgrades as a shared change and Wazuh manager/indexer/dashboard
version changes as a coordinated vendor-supported change. Take verified backups
before schema/index migrations. Rolling an image tag back does not reverse a data
migration: restore compatible data as well when required.

## Commissioning acceptance

- [ ] Record host, guest identity, storage/network inventory and supported version pins.
- [ ] Pass the unprivileged LXC compatibility/load/reboot gate, or record VM fallback.
- [ ] Verify database role isolation, authenticated readiness and reconnects.
- [ ] Verify private ingress, agent communication and absence of unintended public ports.
- [ ] Measure resource use; approve retention, index capacity and disk-growth limits.
- [ ] Pass the [alert lifecycle tests](monitoring-alerting.md#acceptance-tests).
- [ ] Define RPO/RTO and demonstrate isolated recovery of every required state layer.
- [ ] Record cutover, secret rotation, upgrade and data-compatible rollback procedures.