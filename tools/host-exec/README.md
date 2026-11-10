Design: Guarded Remote Execution Interface — POC

Status: Draft / Proof of Concept
 Scope: Linux hosts accessed from the systems repository development environment
 Primary use case: Allow a local coding agent to inspect and test against a remote host without checking out the systems repository on that host or granting the agent an unrestricted remote shell.

1. Summary

The systems repository contains code and configuration covering multiple systems. Development is performed locally in VS Code, where an agent can use the repository as context.

For some work, particularly host-specific troubleshooting and script development, the agent also needs information from the actual target host. Using VS Code Remote SSH or cloning the repository onto the target host is undesirable, particularly for production systems.

This POC introduces a guarded remote execution interface.

The interface will:

run locally alongside the repository;
connect to remote Linux hosts using SSH;
expose a small set of explicitly permitted operations;
default to read-only inspection;
prevent the agent from obtaining a general-purpose remote shell;
enforce restrictions on the target host as well as locally;
log remote operations for audit and troubleshooting;
provide an architecture that can later support a richer agent interface.

The initial implementation intentionally uses a simple CLI and SSH rather than introducing an agent protocol or service.

2. Desired Outcome

An engineer working locally should be able to ask an agent to investigate a host and develop a script using both:

the wider systems repository as context; and
controlled observations from the real target system.

For example:

Local VS Code
     │
     ├── systems repository
     ├── agent
     │
     └── execution interface
              │
              │ SSH
              ▼
        production host
              │
              └── restricted execution gateway


Typical interaction:

./tools/host-exec status prod-sc01
./tools/host-exec service-status prod-sc01 zabbix-agent
./tools/host-exec logs prod-sc01 zabbix-agent --minutes 30
./tools/host-exec sockets prod-sc01


The agent can therefore gather enough evidence to understand the target environment without receiving unrestricted SSH access.

3. Design Principles
3.1 Safety must be enforced, not prompted

Instructions such as:

Do not modify production.

are useful agent guidance but are not considered a security control.

Controls must exist independently of agent behaviour.

The remote host is therefore the final enforcement point.

3.2 No arbitrary remote shell

The execution interface must not expose a generic facility equivalent to:

host-exec prod01 exec "arbitrary shell command"


This would simply recreate unrestricted SSH through another interface.

Instead, operations are exposed as defined verbs:

status
facts
service-status
logs
processes
sockets
read-config


Each operation has known semantics and independently validated parameters.

3.3 Read-only by default

POC operations are diagnostic.

The normal execution path must not:

modify configuration;
install or remove packages;
restart/reload services;
signal processes;
change firewall/network configuration;
change ownership or permissions;
invoke sudo;
write into application directories.

Where temporary files are eventually required for testing, this will be an explicitly separate operation and constrained to a dedicated staging area.

3.4 Defence in depth

Access is constrained at multiple layers:

Agent instructions
        │
        ▼
Local execution interface
        │
        ▼
Known-host / operation policy
        │
        ▼
Dedicated SSH identity
        │
        ▼
sshd forced command
        │
        ▼
Remote command gateway
        │
        ▼
Linux permissions


Failure or bypass of one control should not immediately provide unrestricted production access.

4. POC Scope

The first POC should remain deliberately small.

Included
one non-production Linux host initially;
one production host once the controls are demonstrated;
local CLI;
SSH transport;
dedicated SSH key;
dedicated remote account;
forced-command SSH restriction;
remote command allowlist;
operation logging;
structured exit status;
basic evidence capture;
explicit separation of production and non-production hosts.
Excluded

For the initial POC:

arbitrary SSH command execution;
interactive remote shell;
sudo;
configuration changes;
service restart/reload;
package management;
automated production deployment;
secret retrieval;
repository checkout on the host;
long-running remote agents;
centrally hosted API;
MCP.

MCP is discussed as a potential future interface in the appendix.

5. Architecture
┌──────────────────────────────────────────────────────────┐
│ Engineer workstation                                     │
│                                                          │
│ VS Code                                                  │
│ ├── Agent                                                │
│ └── systems repository                                   │
│       │                                                  │
│       ├── hosts/                                         │
│       ├── scripts/                                       │
│       └── tools/host-exec                                │
│                 │                                        │
└─────────────────┼────────────────────────────────────────┘
                  │
                  │ restricted SSH key
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│ Target Linux host                                        │
│                                                          │
│ sshd                                                     │
│   │                                                      │
│   └── agent-inspect                                      │
│          │                                               │
│          │ forced command                                │
│          ▼                                               │
│   /usr/local/sbin/host-exec-gateway                      │
│          │                                               │
│          ├── validate operation                          │
│          ├── validate parameters                         │
│          ├── enforce limits                              │
│          ├── audit/log                                   │
│          │                                               │
│          └── execute known diagnostic operation           │
│                                                          │
└──────────────────────────────────────────────────────────┘


There are therefore two components:

Local
tools/host-exec


Provides the stable interface used by engineers and agents.

Remote
/usr/local/sbin/host-exec-gateway


Provides the security boundary and converts permitted requests into specific local diagnostic operations.

6. Local Execution Interface

The local CLI provides a consistent abstraction over SSH.

Example:

./tools/host-exec --help


Example operations:

./tools/host-exec facts prod-sc01

./tools/host-exec service-status prod-sc01 zabbix-agent

./tools/host-exec logs prod-sc01 zabbix-agent --minutes 30

./tools/host-exec sockets prod-sc01


The local tool is responsible for:

resolving the host from repository inventory;
determining its environment;
selecting the appropriate SSH identity;
constructing the remote request;
assigning an operation ID;
recording the request and response;
providing predictable output and exit codes.

It must not be considered the security enforcement point.

A user or agent bypassing the local wrapper must still encounter the restrictions enforced remotely.

7. Remote Identity

A dedicated account should be used, for example:

agent-inspect


The account should have:

no sudo access;
no administrative groups;
no application write access;
no normal interactive SSH capability;
only the minimum filesystem permissions necessary for approved diagnostics.

A separate SSH key should be generated specifically for the execution interface.

The key should not be shared with normal engineering SSH access.

Conceptually:

Engineer SSH key
    └── normal engineer access

Agent inspection SSH key
    └── agent-inspect
            └── forced command only


Compromise or misuse of the agent key therefore does not automatically inherit the engineer's normal privileges.

8. SSH Restriction

The SSH public key on the target will be bound to the remote gateway using a forced command.

Conceptually:

restrict,command="/usr/local/sbin/host-exec-gateway" ssh-ed25519 ...


The gateway receives the requested operation but the SSH client cannot choose the executable that runs.

Interactive sessions, forwarding and other unnecessary SSH capabilities should be disabled.

The gateway itself must be:

owned by root;
not writable by agent-inspect;
installed through normal configuration management;
version controlled in the systems repository.
9. Remote Protocol

The interface between the local wrapper and remote gateway should be deliberately simple.

Example conceptual request:

service-status zabbix-agent


The gateway parses:

operation = service-status
service   = zabbix-agent


It then validates both independently.

It must not execute the received input using constructs equivalent to:

eval "$SSH_ORIGINAL_COMMAND"


or:

sh -c "$SSH_ORIGINAL_COMMAND"


Instead, requests map to known executable paths and predefined arguments.

Conceptually:

service-status
       │
       ├── validate service
       │
       ▼
/usr/bin/systemctl status <validated-service>


The caller controls values, not command construction.

10. Initial Operations

The POC should start with the smallest useful command set.

facts

Return basic host information such as:

hostname;
OS/version;
kernel;
uptime;
current time;
relevant application/package versions.
service-status
service-status <service>


Services must be explicitly allowlisted.

Example:

zabbix-agent
zabbix-agent2


A caller cannot request:

service-status ../../something


or an arbitrary system unit unless permitted.

logs
logs <service> --minutes <n>


Controls should include:

allowlisted service;
maximum lookback;
maximum returned lines/bytes;
timeout.

This protects both availability and the agent context from accidentally retrieving enormous log sets.

processes

Returns a bounded process view suitable for diagnosing the target application.

It must not return arbitrary process environment variables because these may contain credentials.

sockets

Returns listening and/or established network socket information.

Potentially:

sockets
sockets --listening


This provides useful host context without exposing general command execution.

read-config

This should be added cautiously.

Rather than:

read-file /anything/the/caller/wants


prefer:

read-config zabbix-agent


with a server-side mapping:

zabbix-agent
    → /etc/zabbix/zabbix_agentd.conf


This prevents the interface turning into arbitrary filesystem read access.

Files likely to contain credentials should not be exposed through the POC.

11. Host Inventory

The local repository should determine which hosts are available to the interface.

Conceptually:

hosts/
├── lab-sc01/
│   └── host.yaml
└── prod-sc01/
    └── host.yaml


Relevant metadata could include:

name: prod-sc01
environment: production
address: prod-sc01.example
execution_profile: inspect-only


The inventory should not contain SSH private keys or host credentials.

The local tool should clearly identify production:

[op=20261101-001 host=prod-sc01 env=production] requesting service-status


This distinction should also be available to agent instructions.

12. Logging and Audit

Every remote request should receive an operation ID.

For example:

20261101T124500Z-6f27


Local logging:

[op=20261101T124500Z-6f27 host=prod-sc01] requesting service-status zabbix-agent


Remote syslog:

host-exec-gateway:
op=20261101T124500Z-6f27
user=agent-inspect
operation=service-status
target=zabbix-agent
result=0


The audit record should capture:

timestamp;
operation ID;
source identity where available;
host;
requested operation;
non-sensitive parameters;
result;
execution duration.

Secrets and complete command output should not automatically be sent to syslog.

13. Evidence Capture

The local CLI should optionally/defaultly store useful output in the repository working tree:

hosts/
└── prod-sc01/
    └── evidence/
        └── 20261101T124500Z-6f27/
            ├── request.json
            ├── response.txt
            └── metadata.json


This gives the agent stable local evidence to reason over.

Evidence should normally be excluded from Git unless deliberately selected for inclusion:

hosts/*/evidence/*


This reduces the chance of inadvertently committing host data or sensitive log material.

14. Script Development

A primary use case is developing a script for behaviour observed on a real system.

The intended loop is:

             ┌────────────────┐
             │ inspect host   │
             └───────┬────────┘
                     │
                     ▼
             understand issue
                     │
                     ▼
              modify script
               locally
                     │
                     ▼
              review change
                     │
                     ▼
             validate safely
                     │
                     └────► repeat


The complete repository remains local throughout.

Scripts of significance should follow the repository convention:

script --help


and:

script


must not change the system.

Changes require an explicit switch such as:

script --apply


The presence of --apply does not mean that the POC execution interface will permit the agent to invoke it on a production host.

15. Script Testing — POC Extension

Once read-only inspection is working reliably, the next POC capability may allow testing a locally developed script against the real host.

This should remain separate from general command execution.

Conceptually:

./tools/host-exec stage prod-sc01 scripts/check-foo.sh


The file would be transferred to a controlled location such as:

/var/tmp/host-exec/<operation-id>/


It would:

run as the unprivileged inspection user;
have an execution timeout;
have resource limits;
receive a controlled environment;
not have sudo;
not gain additional filesystem permissions;
be removed after the operation.

For production, an uploaded script should initially require explicit engineer approval before execution.

An execution request should also reject known change modes such as:

--apply


However, argument filtering alone must not be treated as sufficient containment: the script itself is untrusted executable code.

The actual protection remains the restricted Linux account, filesystem permissions and execution sandbox.

16. Production Change Boundary

The POC is specifically not a production change mechanism.

The boundary should be:

                AGENT
                  │
          inspect / diagnose
                  │
          develop proposed fix
                  │
                  ▼
           local Git diff
                  │
            HUMAN REVIEW
                  │
                  ▼
        approved change process
                  │
                  ▼
             PRODUCTION


Production application should use a separate identity/process.

The inspection key should never become the deployment key merely for convenience.

17. Failure Behaviour

The interface should fail closed.

Examples:

Unknown operation:

ERROR: operation not permitted: exec


Unknown service:

ERROR: service not permitted: ssh


Invalid parameter:

ERROR: --minutes must be between 1 and 60


Attempted interactive login:

ERROR: interactive access is not permitted


Failures should have deterministic non-zero exit codes so both humans and agents can understand them.

18. Availability Protections

Read-only does not necessarily mean harmless.

A diagnostic operation can still adversely affect a production system by consuming CPU, memory, disk IO or producing excessive log reads.

The gateway should therefore enforce:

execution timeout;
output limit;
log lookback limit;
restricted filesystem traversal;
no arbitrary recursion;
no unrestricted packet capture;
no dumping process environments;
no core dumps;
no unrestricted hashing of large directory trees.

The POC should favour predictable, bounded operations.

19. Secrets Handling

The execution interface must assume that production hosts contain material that must not enter agent context.

The following should not be generically accessible:

private keys;
password stores;
application secrets;
tokens;
complete process environments;
SSH configuration containing credentials;
secret-containing configuration;
/proc/<pid>/environ.

Where configuration inspection is useful, provide a named and preferably sanitised operation rather than arbitrary file reading.

Example:

config zabbix-agent


is preferable to:

cat /etc/zabbix/zabbix_agentd.conf


from the perspective of agent capability design.

20. POC Validation

Before allowing the interface to access production, validate that:

Authentication
the dedicated key authenticates;
unrelated keys cannot use the restricted account unexpectedly;
the agent key does not provide normal engineering SSH.
Shell escape

Attempt:

ssh agent-inspect@host


and confirm no shell is provided.

Attempt arbitrary commands and confirm they are rejected.

SSH features

Confirm that unnecessary:

port forwarding;
agent forwarding;
X11 forwarding;
PTY allocation

are unavailable.

Command validation

Attempt:

unsupported operations;
unsupported services;
malformed arguments;
command separators;
shell expansion;
path traversal;
oversized values.

All must fail closed.

Linux permissions

Confirm agent-inspect cannot:

modify application configuration;
modify the gateway;
obtain sudo;
interfere with application processes;
access protected secrets.
Resource limits

Confirm:

long operations time out;
excessive log requests are bounded;
excessive output is truncated/rejected predictably.
21. POC Success Criteria

The POC is successful if an agent working in the local systems repository can investigate a real host sufficiently to support development of a diagnostic script while:

no repository checkout exists on the target host;
no VS Code remote development session is required;
the agent does not have an interactive remote shell;
arbitrary remote commands cannot be executed;
the remote host independently enforces the permitted operations;
production-changing operations are not available;
each operation is attributable through an operation ID;
useful host evidence can be captured locally;
failure of the local guard does not grant unrestricted production access.
22. Implementation Phases
Phase 1 — Lab

Implement:

host-exec
host-exec-gateway
facts
service-status
logs
processes
sockets


Test extensively against a lab host.

Phase 2 — Production read-only POC

Deploy the gateway through normal configuration management to one production host.

Enable only:

facts
service-status
logs
processes
sockets

Validate audit logging and operational impact.

Phase 3 — Configuration evidence

Introduce carefully scoped:

read-config


with named configuration objects rather than arbitrary filesystem access.

Phase 4 — Script validation

Explore:

stage
validate
test


using an isolated temporary execution area and resource controls.

Production modification remains outside the execution interface.

23. Risks / Dependencies
Restricted account gains excessive read permissions

Risk: Agent retrieves secrets or unrelated customer/system information.

Control: Named resources, filesystem permissions and explicit allowlists.

Gateway becomes an indirect shell

Risk: Weak argument handling permits shell injection.

Control: No eval, no sh -c using caller input, fixed executable mappings, strict parsing and hostile-input testing.

Diagnostic load impacts production

Risk: Apparently read-only operation consumes significant resources.

Control: Timeouts, output limits, bounded log queries and operation-specific resource constraints.

Inspection interface gradually becomes deployment interface

Risk: Convenience results in progressively adding restart/write/sudo capabilities.

Control: Explicit architectural boundary between inspection/testing and production application.

Retrieved evidence enters Git

Risk: Logs or configuration are accidentally committed.

Control: Default .gitignore, explicit evidence directory and review before adding evidence to source control.

24. Future Considerations — MCP Appendix
A.1 Rationale

The initial POC deliberately uses a CLI because:

SSH is already understood operationally;
the trust model is easy to inspect;
it has few dependencies;
troubleshooting remains straightforward;
the remote security boundary can be proven before introducing an agent-specific interface.

A future enhancement could expose the same logical operations through Model Context Protocol (MCP).

The underlying execution and security model should remain unchanged.

Today

Agent
  │
  ▼
host-exec CLI
  │
  ▼
SSH
  │
  ▼
host-exec-gateway


Potential future

Agent
  │
  ▼
Fleet MCP
  │
  ▼
same execution policy
  │
  ▼
SSH
  │
  ▼
same host-exec-gateway

A.2 Potential MCP tools

The existing execution verbs map naturally onto typed tools:

host_facts(host)

service_status(host, service)

service_logs(host, service, minutes)

processes(host)

sockets(host)

read_config(host, config)


This would give the agent structured operations without exposing arbitrary command execution.

A.3 Security position

MCP would be an interface, not an elevation of trust.

The architecture should continue to enforce:

MCP
 ↓
local policy
 ↓
restricted SSH
 ↓
remote gateway
 ↓
Linux permissions


No future MCP tool equivalent to:

exec(host, arbitrary_command)


should be introduced.

If MCP is adopted, its principal advantage is therefore better agent/tool integration and structured inputs/outputs — not replacing the server-side security controls designed and validated by this POC.

25. Decision

Proceed with a CLI + restricted SSH + remote forced-command gateway as the first POC.

The POC should prove the important part first:

An agent with the full systems repository locally can obtain useful, real-world production context without either placing the repository on production or receiving a general-purpose production shell.

MCP remains a future interface option once the underlying execution contract and production security boundary have been demonstrated.

26. Remote-end deployment POC

The first implementation is an Ansible deployment for a systemd Linux host using Python 3, `journalctl`, `ps`, and `ss`. It installs only the remote boundary; the local `host-exec` client, evidence capture, and operation-ID correlation are not implemented yet.

Files:

- `ansible/deploy-remote.yml` — guarded lab-only playbook.
- `ansible/files/host_exec_gateway.py` — root-owned allowlisted gateway.
- `ansible/inventory/lab.example.yml` — placeholder inventory; replace the example address, admin account, and inspection public key.
- `ansible/tests/test_gateway.py` — parser and rejection tests.

The playbook creates a locked, unprivileged `agent-inspect` account with no supplementary groups or sudo configuration. Its sole authorized key is installed with a forced command and SSH forwarding/PTY/RC restrictions. The gateway independently accepts only `facts`, `service-status` and bounded `logs`, `processes`, and `sockets` requests. It uses fixed argument-vector subprocess calls (never a shell), caps request and response sizes, applies timeouts, and writes operation metadata to syslog. The service allowlist is intentionally small (`zabbix-agent` and `zabbix-agent2`) and is maintained in the gateway source.

This is a lab POC, not production-ready hardening. It does not configure sshd globally, establish host-key trust, deploy the local client, or prove that the target's syslog is retained. Before production use, complete the validation checklist in section 20, review the target's existing SSH/account policy, and separately implement the local client and operation-ID protocol. Never point this POC at production.

This requires Ansible on the controller. Install the required collection with `ansible-galaxy collection install -r requirements.yml`. To prepare the example inventory, set the lab host's real address and existing Ansible administrator account, then set `host_exec_authorized_key` to the dedicated inspection key's **public** key. Keep the matching private key outside the repository. From the `ansible` directory, check the plan and syntax before applying:

```sh
ansible-playbook -i inventory/lab.example.yml deploy-remote.yml --syntax-check
ansible-playbook -i inventory/lab.example.yml deploy-remote.yml --check --diff
ansible-playbook -i inventory/lab.example.yml deploy-remote.yml
```

The playbook refuses to run unless the target is explicitly marked `host_exec_environment: lab`. Use normal host-key verification; do not disable SSH host-key checking. The final command changes the remote host and requires an administrator account with Ansible privilege escalation.

Run the local parser tests with `python3 -m unittest discover -s tests -v` from `tools/host-exec/ansible`. The example inventory is deliberately non-routable and is not a real host configuration.

27. Existing Systems to Document

These are existing systems/services, listed here as placeholders for documenting how they fit into host-exec. Their details and any host-exec integration are not yet recorded in this section.

- Cloud UniFi — document its current management and access arrangement.
- TP-Link Omada management — document the existing controller and access arrangement.
- Brian's LXC — document the existing container, its Proxmox host, and the intended inspection target.