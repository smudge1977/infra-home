# APT maintenance playbook

Shared Ansible role and playbook for explicitly approved Debian/Ubuntu servers. This is separate from application provisioning playbooks; it does not automatically add or discover hosts.

## Safety behavior

- Target only hosts listed in the `apt_managed` inventory group.
- Run one host at a time and stop the play if a host fails.
- Refresh APT metadata, then run the ordinary package upgrade (not `full-upgrade`/`dist-upgrade`) by default.
- Preserve locally modified package configuration using `force-confold`.
- Do not automatically reboot, autoremove packages, or clean package archives.
- Assert that each target is Debian-family and uses APT.

APT upgrades can still restart services or alter application behavior. Review pending changes and maintenance windows first. Proxmox hosts, database servers, and other stateful/critical services should be reviewed individually before adding them to `apt_managed`; do not include every server just because it is in an inventory.

## Inventory

Copy `inventory.example.yml` to a local, ignored inventory file and add only approved hosts under `apt_managed`. Keep production IPs and secrets out of the committed example. Ensure SSH access and privilege escalation work for each target.

## Preview and apply

From this directory, preview first:

```sh
ansible-playbook -i inventory.yml apt-upgrade.yml --check --diff
```

Review the target list and proposed package changes. Then apply in an approved maintenance window:

```sh
ansible-playbook -i inventory.yml apt-upgrade.yml
```

Add `-u USER --private-key PATH --ask-become-pass` when needed. The role defaults to a one-hour APT cache validity window. To always refresh metadata set `-e apt_upgrade_cache_valid_time=0`. Full distribution upgrades, autoremove and autoclean are opt-in variables and are intentionally off by default.

## Housekeeping

`housekeeping.yml` runs the separate `server_housekeeping` role against the same explicitly curated `apt_managed` group, one host at a time. It runs APT autoremove with purge to remove packages no longer required (including obsolete kernels when APT marks them as automatically removable) and cleans obsolete cached package archives. It does not remove packages that APT still considers required, and it does not reboot.

If the Docker daemon is available, the role also prunes unused images older than 30 days and Docker builder cache older than 30 days. It never prunes containers, networks, or volumes. Images that remain referenced by any container are retained. Review the host and Docker retention requirements before running this on production systems.

Preview first:

```sh
ansible-playbook -i inventory.yml housekeeping.yml --check --diff
```

In check mode, APT cleanup is predicted by Ansible and Docker prune commands are skipped; a debug message reports the Docker retention scope. Apply in a maintenance window only after reviewing the targets and expected cleanup:

```sh
ansible-playbook -i inventory.yml housekeeping.yml
```

Tune retention with `-e housekeeping_docker_image_until=1440h` and `-e housekeeping_docker_build_cache_until=1440h` (60 days), or disable Docker cleanup with `-e housekeeping_docker_enabled=false`. Disable APT cleanup independently with `-e housekeeping_apt_autoremove=false` or `-e housekeeping_apt_autoclean=false`.
