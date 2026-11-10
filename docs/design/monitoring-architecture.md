# Monitoring appliance architecture

Status: proposed design, 2026-11-08; unscheduled and not deployed from this
repository. Existing Zabbix deployment details remain to be inventoried. This
document does not authorize migration or claim that Alerta or Wazuh are running.

## Decision

Use one **Ubuntu 24.04 monitoring LXC on Proxmox**, running Docker, as the initial
management boundary. Prefer an **unprivileged LXC**. Treat the appliance as
rebuildable compute/configuration with explicitly protected persistent data.

Give each application its own Compose project. Use **one PostgreSQL engine for
Zabbix and Alerta**, with separate databases, application roles and credentials.
Wazuh uses its own Indexer storage, not PostgreSQL.

The shared database adds a fourth infrastructure project: three application
projects plus one database project, not three independent database lifecycles.

```text
Proxmox host (to be selected)
└── monitoring: unprivileged Ubuntu 24.04 LXC
    └── Docker
        ├── postgres/     shared PostgreSQL engine
        │   ├── database: zabbix, role: zabbix
        │   └── database: alerta, role: alerta
        ├── zabbix/       server + web frontend
        ├── alerta/       API + web UI, packaging to be selected
        └── wazuh/        manager + indexer + dashboard
            └── dedicated persistent index storage
```

## Clear product responsibilities

| Product | Responsibility | Not its primary job |
|---|---|---|
| Zabbix | Infrastructure/service availability, capacity, performance and backup freshness | Security-event investigation or long-term log search |
| Wazuh | Security events, file integrity monitoring, agent/security posture and vulnerability monitoring | General infrastructure availability |
| Alerta | Consolidation, deduplication, acknowledgement and presentation of actionable alerts | Replacing source history, metrics or security evidence |

Route actionable Zabbix and Wazuh alerts into Alerta, then deliver notifications
to Teams or another chosen destination. Retain source dashboards for diagnosis;
do not make all three systems send duplicate routine notifications independently.
See [alert aggregation](monitoring-alerting.md) for lifecycle and failure handling.

## Initial resource envelope

These are planning allocations, not measured capacity or vendor guarantees.

| Resource | Starting position |
|---|---|
| CPU | 4 vCPU initially; measure ingestion, query and contention before increasing |
| RAM | 8 GB minimum planning floor; prefer **12–16 GB** when running Wazuh meaningfully |
| OS/application disk | 64–128 GB; budget for images, PostgreSQL, configuration and operating headroom |
| Wazuh index disk | Separate, larger persistent storage where ingestion warrants it; size from measured daily indexed volume and retention |

Wazuh's OpenSearch-based Indexer is the likely dominant consumer of memory and
disk I/O. The combined stack may exceed these allocations. Choose supported
versions first, check their requirements, then prove the resource envelope under
representative load. Do not deploy on 8 GB merely because it is listed here.

Document Indexer heap/container limits without starving the manager, PostgreSQL,
Zabbix, Alerta or the guest OS. Define retention and disk-watermark responses
before production ingestion; a full index disk must not fill the guest root disk.

## Isolation and trade-offs

- **One LXC:** simple appliance ownership, backup inventory and rebuild workflow;
  guest maintenance or a Proxmox host failure affects all monitoring services.
- **Separate Compose projects:** independent application updates and restart
  control, but shared host resources and database availability remain coupled.
- **Shared PostgreSQL:** less operational overhead than two engines; database
  maintenance, engine upgrades and resource exhaustion affect both clients.
  Separate databases/roles are access boundaries, not independent failure domains.
- **Separate Indexer storage:** allows independent retention/capacity management,
  but is not automatically backed up by an LXC backup.
- **Docker inside LXC:** Proxmox → LXC → Docker → application adds kernel,
  cgroup, storage and permissions constraints. Prefer a small VM over weakening
  guest security if the supported Wazuh configuration cannot run reliably.

Do not escalate to privileged LXC as the default fix. Complete the compatibility
gate in [deployment and recovery](monitoring-deployment.md) before committing to
the LXC. A VM for the whole appliance is the straightforward fallback; splitting
Wazuh out is a later option if independent capacity or failure isolation is needed.

## Ownership and unresolved choices

Infra-home owns guest provisioning, Compose/configuration, private networking,
secrets, upgrades and recovery. Terraform/Ansible should rebuild the selected
infrastructure and configuration once the design passes commissioning.

Decide before implementation:

- Proxmox host, guest ID, IP/subnet, DNS names and storage placement. Review
  [prox04](../../systems/prox04/README.md) and
  [prox01](../../systems/prox01/README.md); neither is assigned by this design.
- Supported, pinned Zabbix/Alerta/Wazuh/PostgreSQL versions and upgrade paths.
  The existing [Zabbix template](../../systems/zabbix/README.md) targets 6.0;
  test import compatibility rather than assuming it selects the new server version.
- Private ingress, authentication, agent enrollment and notification ownership;
  coordinate DNS/firewall decisions with [Sprint 2](../sprint-2.md).
- Retention, ingestion scope, off-host backup destination and explicit RPO/RTO.
- Whether to migrate an existing Zabbix server or commission a new one. Inventory
  current state and preserve rollback material before changing anything live.

## Related design and implementation gates

- [Deployment, shared PostgreSQL and recovery](monitoring-deployment.md)
- [Alert aggregation and notification lifecycle](monitoring-alerting.md)
- [Layered backup/recovery evaluation](backup-recovery.md)
- [Unscheduled commissioning work](../backlog.md#monitoring-appliance)

Upstream implementation references: [Wazuh Docker deployment](https://documentation.wazuh.com/current/deployment-options/docker/index.html),
[Wazuh OpenSearch integration](https://documentation.wazuh.com/current/integrations-guide/opensearch/index.html),
[Zabbix documentation](https://www.zabbix.com/documentation/current/en/manual),
and [Alerta documentation](https://docs.alerta.io/).
Verify requirements against the chosen versions during implementation; these
links are not evidence of a tested local deployment.