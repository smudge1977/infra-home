# High-confidence WordPress probe Fail2ban jail

The standalone `deploy-wp-probes.yml` play targets only `massage-brighton-02` on Ubuntu 22.04. It installs an exact-path filter and a web-only jail, preserving the existing `sshd` jail. The jail bans a source for one hour after one matching high-confidence sensitive-file or exploit-probe request; it does not ban generic 404s or ordinary WordPress endpoints.

The jail explicitly ignores loopback, `35.153.189.217`, `193.9.255.220`, and `home.keithmarston.me.uk`. Fail2ban resolves DNS names for ignore lists when the jail is loaded; it does not continuously track DNS updates. If the home hostname changes address, reload/restart Fail2ban after DNS has updated, then verify the effective jail allowlist with `fail2ban-client get nginx-wp-probes ignoreip`. Keep the current SSH session open during deployment and verify a second SSH connection after any reload.

## Preview and deploy

From this directory, preview without applying changes:

```sh
/home/keith/workspaces/infra-home/.venv/bin/ansible-playbook -i '83.229.69.134,' -u keith --private-key "$HOME/.ssh/id_ed25519" --ask-become-pass --check --diff deploy-wp-probes.yml
```

Review the proposed jail file and exact allowlist. Check mode does not load/reload Fail2ban or apply a ban. When the preview is approved, run the same command without `--check --diff`.

The playbook backs up replaced Fail2ban files, checks the service and current `sshd` jail, validates Fail2ban configuration and runs `fail2ban-regex` against the live Nginx access log before reload. Verify afterward with:

```sh
sudo fail2ban-client status
sudo fail2ban-client status nginx-wp-probes
sudo fail2ban-client get nginx-wp-probes ignoreip
```

Rollback by removing `/etc/fail2ban/jail.d/nginx-wp-probes.local` and `/etc/fail2ban/filter.d/nginx-wp-probes.conf` (or restoring the Ansible-created backups), then run `sudo fail2ban-client -t` and `sudo fail2ban-client reload`. Confirm the existing `sshd` jail remains active.
