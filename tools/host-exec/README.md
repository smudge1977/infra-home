# Design: Guarded Agent Access to Production Servers

Status: Revised design / existing remote-end lab POC only
Updated: 2026-11-14
Scope: Linux hosts, primarily Ubuntu including Ubuntu 18.04, accessed from an agent workspace on a machine that also acts as an Ansible controller.
Primary use case: Allow a coding agent to inspect production without a general-purpose shell or administrative credentials, and develop proposed automation locally.

**First coding pass: only the read-only `agent-gateway` and its tests. Ansible privilege delegation is stage two, not part of this POC.** This document specifies the target design; section 26 distinguishes the existing `host-exec-gateway` lab implementation from capabilities and isolation still to be built and verified.

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

./tools/host-exec inventory prod-sc01
./tools/host-exec service-status prod-sc01 zabbix-agent
./tools/host-exec journal prod-sc01 zabbix-agent
./tools/host-exec check prod-sc01 network


The agent can therefore gather enough evidence to understand the target environment without receiving unrestricted SSH access.

3. Design Principles
3.1 Safety must be enforced, not prompted

Instructions such as:

Do not modify production.

are useful agent guidance but are not considered a security control.

Assume the agent may make mistakes, ignore instructions, construct unexpected commands, or attempt to use any credentials it can reach. Controls must exist independently of agent behaviour.

The remote host enforces the restricted inspection capability; the controller host enforces separation from unrestricted administrative credentials. Both are security boundaries. A forced command on one key does not help if the agent can use a second unrestricted key.

Keeping an admin key alongside a restricted key and instructing the agent to choose the latter is not isolation. The same applies if the admin key is unreadable but usable through `SSH_AUTH_SOCK`, another credential broker, or a privileged service.

**A credential unavailable to the agent is a security control. A credential available to the agent with instructions not to use it is not.**

3.2 No arbitrary remote shell

The execution interface must not expose a generic facility equivalent to:

host-exec prod01 exec "arbitrary shell command"


This would simply recreate unrestricted SSH through another interface.

Instead, operations are exposed as defined capabilities:

inventory
service-status
journal
read-file
check


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

Controller Unix identity / credential isolation
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


Agent instructions are guidance, not a layer of enforcement. Failure or bypass of the local CLI must not provide unrestricted production access.

4. POC Scope

The first POC should remain deliberately small.

Included
one non-production Linux host initially;
one production host once the controls are demonstrated;
local CLI;
SSH transport;
dedicated SSH key;
separate local agent and Ansible runner identities and credentials;
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
arbitrary inventory, Ansible modules or playbooks;
arbitrary file writes or agent-created script execution;
SSH tunnelling, SSH agent forwarding, PTYs and SCP/SFTP;
repository checkout on the host;
long-running remote agents;
centrally hosted API;
MCP.

MCP is discussed as a potential future interface in the appendix.

5. Architecture

There are two distinct paths into production, not two keys available to one agent process:

```text
Controller workstation/server (part of the security boundary)
================================================================
Keith / administrator                    agent Unix account
        | unrestricted administration           | coding agent + editable checkout
        v                                       | restricted key B only
ansible-runner                            | NO admin key / admin SSH agent
        | privileged administrative identity    | NO sudo / container socket
        | admin credential                      |
        | approved inventory/playbooks          | optional host-exec CLI
        | audit logging                         |
        |                                       | restricted SSH key B
        v                                       v
Production Linux servers
================================================================
Normal administrative access          sshd -> agent-inspect
                                                                                                                                                                                 | forced command
                                                                                                                                                                                 v
                                                                                                                                                        agent-gateway (unprivileged)
                                                                                                                                                                                 | fixed capabilities
                                                                                                                                                                                 + inventory
                                                                                                                                                                                 + service-status / journal
                                                                                                                                                                                 + read-file / check
```

The agent inspection path is agent → restricted SSH → sshd forced command → gateway → allow-listed operation. The administrative path is approved automation → isolated ansible-runner → admin credential → production. The agent has no direct access to the latter.

`tools/host-exec` remains the optional local client abstraction. The target remote command name is `/usr/local/sbin/agent-gateway`; the existing lab implementation is installed as `/usr/local/sbin/host-exec-gateway` (section 26). Names or aliases must never introduce a bypass.

5.1 Controller Unix identities and credential isolation

Initially use separate local identities: `keith`, `agent`, and `ansible-runner`. The actual coding process, terminal, extensions and subprocesses must run within the agent boundary, not as the administrator with an instruction to switch accounts.

Example credential locations:

```text
/home/agent/.ssh/id_agent_restricted
/var/lib/ansible-runner/.ssh/id_ansible_admin
```

The runner's home, credentials and any SSH-agent socket must be protected by ownership and permissions inaccessible to `agent`. Private keys stay outside Git. Separate Unix users are the initial boundary, not a claim of isolation from host root or a kernel compromise.

The agent must not be able to:

- Read or use the admin credential, including inherited file descriptors, forwarded agents or accessible credential brokers.
- Access an administrative `SSH_AUTH_SOCK`; normally unset it. If needed, use an agent holding **only** the restricted identity, with no route to load an admin identity.
- Sudo to root or `ansible-runner`, or ptrace/debug the runner or administrator processes.
- Modify the runner, its dependencies, service units, privileged wrappers, approved automation or any parent directories controlling them.
- Control the runner service or submit arbitrary jobs to another administrative interface.

Do not grant the local agent or remote inspection account membership in `sudo`, `docker`, `lxd` or equivalent privileged groups. Access to `/var/run/docker.sock`, a rootful container API or an equivalent host-control socket is effectively host root and defeats private-key filesystem protection. Review ACLs, inherited groups, service sockets and existing privilege escalation policy, not just account creation defaults.

The approved automation tree and controller credential boundary are administrator-owned. Editing the development repository must not change anything the privileged runner subsequently trusts.

6. Local Execution Interface

The local CLI provides a consistent abstraction over SSH.

Example:

./tools/host-exec --help


Example operations:

./tools/host-exec inventory prod-sc01

./tools/host-exec service-status prod-sc01 zabbix-agent

./tools/host-exec journal prod-sc01 zabbix-agent

./tools/host-exec check prod-sc01 network


The local tool is responsible for:

resolving the host from repository inventory;
determining its environment;
selecting the restricted SSH identity (not choosing between restricted and agent-accessible admin keys);
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

This assertion is conditional on controller isolation in section 5.1: the engineer's key and agent socket are unavailable to the coding agent. On the target, authorized keys and their parent directories must be root-controlled so `agent-inspect` cannot add a second, unrestricted key. Disable other login mechanisms for this account and audit existing keys, groups, sudo rules and sshd policy.

8. SSH Restriction

The SSH public key on the target will be bound to the remote gateway using a forced command.

Conceptually:

restrict,command="/usr/local/sbin/agent-gateway" ssh-ed25519 ...


The gateway receives the requested operation but the SSH client cannot choose the executable that runs.

Interactive sessions, SSH agent forwarding, port forwarding, X11 forwarding, PTYs, user RC execution and SCP/SFTP must be unavailable. A request such as `ssh server bash` or `ssh server "sudo something"` still invokes the gateway and must be rejected.

Use explicit supported restrictions for each installed OpenSSH version, especially Ubuntu 18.04 hosts; do not assume one version's `restrict` behaviour proves another's effective policy. Include `no-agent-forwarding`, `no-port-forwarding`, `no-X11-forwarding`, `no-pty` and `no-user-rc` where supported, and account-level sshd restrictions as appropriate. Verify effective configuration and attempts against the actual daemon, including forwarding-only connections without a remote command. If the required restrictions cannot be enforced, do not enable access. The forced command runs as `agent-inspect`, not root; root ownership does not imply privileged execution.

The gateway itself must be:

owned by root (`root:root`, mode `0755`, no setuid or privileged file capabilities);
not writable by agent-inspect;
installed through normal configuration management;
version controlled in the systems repository.

Configuration and allow-lists, executable dependencies and parent directories must also be protected from the inspection account. The installed production artifact must not be a symlink into an agent-writable checkout.
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


Never build a shell parser or accept shell syntax. `SSH_ORIGINAL_COMMAND` is untrusted input to a small, bounded request grammar, not a command to execute. Reject unknown options, extra tokens, command chaining, substitutions and malformed/oversized input. A tokenizer is not an authorization policy.

Instead, requests map to known absolute executable paths and predefined argument arrays. Invoke them with `shell=False` (or equivalent), a fixed environment and working directory, closed unrelated file descriptors, no pager and no caller-controlled executable search path. Do not pass input to `bash -c`, `sh -c`, `eval` or equivalent. Validate each service, file and check independently; never allow argument/option injection or use a command-prefix test as authorization.

Conceptually:

service-status
       │
       ├── validate service
       │
       ▼
/usr/bin/systemctl status <validated-service>


The caller controls values, not command construction.

10. Target Gateway Interface and Initial Operations

The desired interface is a capability contract, not a claim that the existing lab implementation already supports it:

```text
agent-gateway [OPTIONS] <command> [arguments]

Guarded interface for agent access to production systems.
No interactive shell is provided. Default behaviour: READ ONLY.

Commands:
        inventory                  Basic host inventory.
        service-status <service>   Status of an allow-listed systemd service.
        journal <service>          Bounded journal for an allow-listed service.
        read-file <path>           Read an explicitly allow-listed file.
        check <name>               Run a fixed, allow-listed diagnostic.
        validate-script            Reserved: validate/stage content; never execute it.

Options:
        -h, --help                 Show help.
        --list                     List permitted operations/resources, not secrets.
        --audit-id <id>            Associate with an incident/change/work item.
```

`validate-script` is a future non-executing capability and must be rejected as unavailable in the first coding pass; listing/help must clearly mark it as reserved. The first implementation scope is `inventory`, `service-status`, `journal`, `read-file` and `check`, plus discovery/help and audit correlation. Deny any operation that cannot safely be provided by the unprivileged account; do not add sudo to make a diagnostic work.

- `inventory`: bounded hostname, OS/version, kernel, uptime, time and approved package/version information. No general secret or environment dump.
- `service-status <service>`: exact server-side service allow-list, initially candidates `zabbix-agent` and `zabbix-agent2`. No arbitrary units, patterns, paths, flags or mutations. Disable pagers.
- `journal <service>`: exact service allow-list plus maximum lookback, lines/bytes and timeout. Privileged/global journal access can expose secrets: if narrow safe access cannot be provided, deny the operation rather than granting broad journal groups. Review output sensitivity, not only command semantics.
- `read-file <path>`: exact reviewed file entries, ideally mapped to named/sanitised configuration views. Directory candidates such as `/etc/zabbix/` and `/etc/netplan/` are **not recursive grants**; individual files require review because they can contain credentials. `/etc/hosts` is another candidate. Deny `/etc/shadow`, `/root/.ssh/`, `/var/lib/ansible-runner/`, process environments and all other non-allow-listed paths.
- `check <name>`: fixed executable/argument mappings for `disk-space`, `memory`, `load`, `failed-units`, `network` and `zabbix-agent`. Enable only those proved bounded and non-sensitive on the host. A check name never selects a caller-provided script or executable.

For `read-file`, reject traversal (`..`), option-like paths, symlink escapes, special files, devices and pseudo-files. Canonicalisation alone is insufficient: use race-resistant resolution/opening, verify the opened regular file and enforce size limits. Policy must account for bind mounts and mount changes; a permitted pathname must not silently expose a different filesystem object. Keep allowed parents and mount control outside agent authority; deny uncertain cases. Test the actual supported Ubuntu/kernel behaviour before choosing a file-opening mechanism.

Do not expose arbitrary process command lines/environments through a diagnostic check. Bound network/socket output and avoid packet capture. Exact policy remains root-controlled on each target.

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

agent-gateway:
op=20261101T124500Z-6f27
user=agent-inspect
source=<trusted-SSH-connection>
operation=service-status
site=<configured-site>
host=prod-sc01
target=zabbix-agent
audit_id=CHG-12345
mode=read-only
gateway_version=<installed-version>
automation_commit=not-applicable
result=success
exit_status=0


The audit record should capture:

timestamp;
operation ID;
requesting OS/authenticated identity and source (for SSH, trusted connection metadata);
target site and resolved host(s);
requested operation;
non-sensitive parameters;
audit/change/incident ID;
check/apply mode (read-only for the inspection gateway);
approved automation Git commit (not applicable for inspection; record gateway/policy version instead);
result;
exit status;
execution duration.

Log accepted, denied, failed and timed-out requests using structured, escaped records. Treat `--audit-id` as a bounded caller-supplied correlation label, not evidence of approval or authenticated identity. Resolve authorization and target identity independently of caller labels. Future runner jobs must record the immutable approved commit actually executed, not a commit claimed by the requester.

Use syslog/journald with administrator-controlled retention and, where appropriate, remote forwarding. The agent must not be able to modify or delete the authoritative log. Local workspace evidence is not an authoritative audit trail. Secrets and complete command output should not automatically be sent to syslog; avoid logging raw hostile input or secret-bearing parameters.

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

15. Script Validation — Deferred, Non-Executing Capability

Develop and test scripts locally or in a separate lab sandbox. The read-only production gateway must not stage-and-execute agent-created scripts, even as the inspection account. An unprivileged arbitrary script is still arbitrary code and can read anything that account can read, bypass output policy, or attack local services.

A future `validate-script` may accept bounded content into a dedicated non-executable staging area for non-executing validation only. It needs a separately reviewed transfer protocol (not SCP/SFTP), ownership/retention limits, safe validators, isolation and resource controls. Do not source, import, run or otherwise execute uploaded content, including through validation tools with plugins/hooks or unsafe configuration discovery. This is not part of the first implementation.

Human approval or rejecting `--apply` arguments does not turn arbitrary uploaded code into a safe production diagnostic. Any future execution capability requires a new threat model and explicit approval; it is not an extension implicitly granted by this design.

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

16.1 Stage two: approved Ansible operations

The controller's unrestricted Ansible credential is a separate security problem, not an exception to the inspection restrictions. The future path is:

```text
agent -> narrow authenticated ansible-gateway
                        -> isolated ansible-runner
                        -> fixed approved playbook + approved inventory
                        -> admin credential -> production
```

Do not expose a generic runner trigger in stage one. Stage two requires its own reviewed authentication, authorization, approval and audit boundary. A possible interface is:

```text
ansible-gateway [OPTIONS] <operation>

Approved operation candidates:
        site-health-check
        collect-diagnostics
        deploy-zabbix-agent
        validate-inventory

Options:
        --site SITE
        --limit HOSTS
        --ticket ID
        --check
        --apply
        -h, --help

Default: no production changes; --apply is required for a change.
```

For example, `ansible-gateway --site erlangen --ticket CHG-12345 --check deploy-zabbix-agent` requests a check; the corresponding `--apply` request explicitly asks for a change. These are future interface examples, not executable facilities provided by the POC.

Omitting a mode must be non-mutating; reject conflicting `--check`/`--apply`. An explicit `--apply` is necessary but **not sufficient**: the caller, operation, targets and approval must also be authorized. A ticket string is not approval. Ansible check mode is not a security sandbox: modules, plugins and tasks (including `check_mode: false`) may still execute code or change systems. Reviewed jobs must enforce non-mutating default/check behaviour; deny jobs that cannot meet that guarantee.

The agent requests an operation, never a key or playbook pathname. For example, the administrator-controlled mapping may resolve `deploy-zabbix-agent` to `/srv/approved-automation/deploy-zabbix-agent.yml`. Reject arbitrary modules, ad-hoc `shell`/`command`, caller-supplied playbooks and inventory, extra Ansible arguments/variables, plugin paths and environment overrides. Validate `--site` and `--limit` against approved inventory and authorized host sets; do not treat a free-form Ansible host pattern as authorization. Record the resolved target set.

16.2 Editable versus executable automation

Keep the agent-editable checkout (for example `/home/agent/workspace/automation/`) separate from the runner's trusted content (`/srv/approved-automation/`). An administrator-controlled review/promotion step must select an immutable Git commit and install its approved artifact. The agent cannot approve/promote its own changes or write the trusted tree.

Protect the **complete execution dependency tree**, not just the top-level playbook: inventory and dynamic inventory scripts, roles, collections, modules, plugins, templates, included files, Ansible configuration, Python environment, runner wrappers and service configuration. Use trusted configuration, executable paths, working directory and environment; never discover them in an agent-writable checkout or inherit untrusted `ANSIBLE_*`, Python or SSH settings. Dependencies must be pinned/reviewed so a fixed commit cannot load agent-modified code later.

If the agent can edit an approved playbook or any code it loads and then trigger the runner, it effectively has administrative code execution. Filesystem ownership, explicit promotion and job authorization must enforce this boundary, not a convention that a directory is called “approved”.

16.3 Longer-term runner isolation

Same-host Unix identity separation is acceptable to prove the model only when its acceptance tests pass. For production customer OT environments, prefer AWX or a dedicated hardened runner on a separate security boundary. The agent receives a narrow authenticated API/job interface and permission for specific reviewed job templates, never their credentials or arbitrary template edits. This reduces the concentration of agent, development repository, Ansible and production credentials on one host; it does not remove job/dependency/approval validation requirements.

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

20. Mandatory POC Security Acceptance Tests

**Acceptance statement: compromise or misbehaviour of the coding agent does not automatically provide unrestricted production access.** These are release gates, not optional hardening. Test from the real agent identity/environment and separately from the remote inspection identity. Record expected denial and observed result on the actual supported hosts, including Ubuntu 18.04/OpenSSH versions in scope. Unit tests alone cannot prove OS, socket, mount or sshd policy.

Controller isolation:

- [ ] Agent cannot read/use the Ansible admin key or administrator credentials, including via alternate ACLs, inherited descriptors or credential services. Test access without copying secrets into evidence.
- [ ] `SSH_AUTH_SOCK` is absent or exposes only the restricted identity; admin/forwarded sockets and their credentials are unreachable.
- [ ] Agent cannot sudo to root, become `ansible-runner`, ptrace/debug privileged identities or control the runner service.
- [ ] Agent cannot access Docker/LXD/rootful container sockets or equivalent privileged groups/APIs.
- [ ] Agent cannot modify the gateway installer, privileged wrappers, runner code/configuration or trusted dependencies used by privileged execution.
- [ ] Agent can edit development automation but cannot edit/promote approved playbooks, inventory or their dependency tree.
- [ ] Arbitrary playbook paths, agent-created playbooks, arbitrary inventory, Ansible ad-hoc commands, modules and environment/extra-argument overrides cannot be executed with the admin identity. In stage one there is no agent-accessible privileged runner interface at all; ordinary local Ansible development without admin credentials is not prohibited.

Authentication and remote enforcement:

- [ ] Dedicated restricted key authenticates only to the intended restricted accounts; unrelated keys and alternative authentication do not open them.
- [ ] Bypassing the local wrapper still reaches the remote forced command and identical policy.
- [ ] Interactive login, `bash`, `sudo`, arbitrary commands, SCP and SFTP fail; no unrestricted key can be added by `agent-inspect`.
- [ ] PTYs, local/remote/dynamic port forwarding (including no-command forwarding), SSH agent forwarding, X11 forwarding and user RC execution are denied by actual sshd policy.
- [ ] Remote account cannot sudo, join privileged groups, modify applications/gateway/allow-lists/dependencies or access protected secrets. Gateway and policy are root-owned and non-writable through their parent paths.

Capability validation and file containment:

- [ ] Allowed inventory, exact services, journal queries, files and checks succeed with bounded output and least privilege; unavailable capabilities fail closed.
- [ ] Unknown operations/services/files/checks, extra tokens, options, malformed requests and oversized input are rejected.
- [ ] Command separators, pipes, redirection, shell expansion, command substitution, newlines and option injection cannot cause unintended execution; subprocess calls use fixed argument arrays with no shell.
- [ ] `read-file` cannot escape via `../`, symlinks, symlink-swap races, bind mounts or unexpected canonical paths; reject special/pseudo-files and files exceeding limits.
- [ ] Sensitive Zabbix/Netplan settings, journals and diagnostic output are not accidentally exposed by broad directory/group permissions or process environment/command-line dumps.
- [ ] `validate-script` is unavailable in stage one; uploaded scripts cannot execute or be passed to a privileged runner.

Availability and audit:

- [ ] Timeouts, child cleanup, output/line/byte limits and journal lookback bounds behave predictably; repeated/concurrent requests are bounded or rate-limited to protect availability.
- [ ] Accepted/denied/failed requests are attributable by trusted identity/source, operation, targets, correlation ID, mode, version/commit, result and exit status; hostile labels cannot forge records.
- [ ] Agent cannot modify/delete authoritative audit records; retention is verified independently of workspace evidence.

Stage two adds approval/promotion tampering, target-scope escape and check-mode non-mutation tests **before** enabling any Ansible job delegation. Until then, these tests must confirm the delegated write path is absent, not imply it has been built or approved.
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
The controller credential-isolation and all applicable acceptance tests in section 20 must also pass; a working forced command alone is not success.
22. Implementation Stages

Stage one — read-only `agent-gateway` and tests only:

1. Establish and verify the controller identity/credential boundary; do not make admin credentials available while developing the POC.
2. Build the small gateway contract (`inventory`, `service-status`, `journal`, exact `read-file`, named `check`) and unit tests. Deny features not safely available. Keep any local wrapper optional and non-authoritative; do not expand the first coding pass into a runner service.
3. Use a non-production lab host to exercise the complete controller, SSH, filesystem, hostile-input, audit and availability acceptance tests. Verify Ubuntu 18.04 compatibility rather than assuming modern runtime/sshd/kernel features.
4. Only after independent review and all applicable acceptance gates pass, use the normal approved change process to consider one production read-only pilot. The current lab deployment playbook remains lab-only; this design update does not authorize or enable a production deployment.

Stage two — separately reviewed `ansible-gateway` privilege delegation:

Implement only fixed authorized jobs, approved inventory, immutable reviewed/promoted automation, isolated runner credentials, non-mutating default/check mode, explicit authorized `--apply`, and authoritative audit. Complete new privilege-boundary acceptance tests first. No arbitrary Ansible interface or shared admin key.

Deferred independently: non-executing script validation/staging and MCP integration. Neither implies arbitrary production code execution. Consider AWX or a separate hardened runner before production customer OT use.

23. Risks / Dependencies
Controller credential bypass

Risk: Agent uses the unrestricted admin key, SSH agent, root-equivalent socket or writable runner dependency and avoids the remote gateway entirely.

Control: Separate Unix identities, inaccessible credentials/sockets, no privilege escalation, immutable trusted automation and controller acceptance tests. Move privileged execution to a separate host/service when the shared-host boundary is insufficient.

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

Control: Explicit architectural boundary between production inspection, local/lab testing and separately approved production application.

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

Initial target interface

Agent
  │
  ▼
host-exec CLI
  │
  ▼
SSH
  │
  ▼
agent-gateway


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
same agent-gateway

A.2 Potential MCP tools

The existing execution verbs map naturally onto typed tools:

host_inventory(host)

service_status(host, service)

service_journal(host, service)

read_file(host, approved_path)

diagnostic_check(host, approved_check)


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


Controller credential isolation remains required outside this chain. MCP must not expose an admin credential, runner configuration, arbitrary job or approval bypass.

No future MCP tool equivalent to:

exec(host, arbitrary_command)


should be introduced.

If MCP is adopted, its principal advantage is therefore better agent/tool integration and structured inputs/outputs — not replacing the server-side security controls designed and validated by this POC.

25. Decision

Proceed with a CLI + restricted SSH + remote forced-command gateway as the first POC.

Only the read-only gateway and its tests are in the first coding pass. The local agent cannot access the administrator/Ansible credential or any equivalent privilege. Future approved job delegation is a separate stage; `--apply` is required but never substitutes for authorization and review.

The POC should prove the important part first:

An agent with the full systems repository locally can obtain useful, real-world production context without either placing the repository on production or receiving a general-purpose production shell.

MCP remains a future interface option once the underlying execution contract and production security boundary have been demonstrated.

26. Remote-end deployment POC

**Legacy lab implementation, not the revised gateway contract. It does not satisfy stage-one acceptance. Do not deploy it to production or treat these installation steps as proof of controller credential isolation.**

The existing implementation predates this revised design. It is an Ansible deployment for a systemd Linux host using Python 3, `journalctl`, `ps`, and `ss`. It installs only the remote boundary; the local `host-exec` client, evidence capture, and operation-ID correlation are not implemented yet.

Files:

- `ansible/deploy-remote.yml` — guarded lab-only playbook.
- `ansible/files/host_exec_gateway.py` — root-owned allowlisted gateway.
- `ansible/inventory/lab.example.yml` — placeholder inventory; replace the example address, admin account, and inspection public key.
- `ansible/tests/test_gateway.py` — parser and rejection tests.

The playbook creates a locked, unprivileged `agent-inspect` account with no supplementary groups or sudo configuration. Its sole authorized key is installed with a forced command and SSH forwarding/PTY/RC restrictions. The gateway independently accepts only `facts`, `service-status` and bounded `logs`, `processes`, and `sockets` requests. It uses fixed argument-vector subprocess calls (never a shell), caps request and response sizes, applies timeouts, and writes operation metadata to syslog. The service allowlist is intentionally small (`zabbix-agent` and `zabbix-agent2`) and is maintained in the gateway source.

This is a lab POC, not production-ready hardening. It does not configure sshd globally, establish host-key trust, deploy the local client, or prove that the target's syslog is retained. Before production use, complete the validation checklist in section 20, review the target's existing SSH/account policy, and separately implement the local client and operation-ID protocol. Never point this POC at production.

Revision gap: it does not establish or test the controller's `keith`/`agent`/`ansible-runner` isolation, and its `facts`/`logs`/`processes`/`sockets` vocabulary is legacy, not the target interface in section 10. The revised `inventory`/`journal`/`read-file`/`check`, discovery/help and audit-ID contract, file-containment tests and complete security acceptance suite remain implementation work. Ansible deployment here is administrator-operated installation tooling, **not** an agent-accessible `ansible-gateway`. No Ansible delegation, promotion workflow, script validation or production readiness is claimed by this document update.

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