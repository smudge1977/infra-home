# PHP-FPM slow-log diagnostic deployment

This standalone play applies the PHP-FPM slow-request diagnostic change to the verified production WordPress host. It is separate from `wordpress.yml`, which only provisions the isolated Ubuntu 26.04 lab VM. It does not tune worker limits, terminate requests, change Nginx, or configure Fail2ban.

## What the role changes

- Adds `request_slowlog_timeout = 5s` and a private pool slow-log path to the existing PHP 8.3 `www` pool file. `lineinfile` keeps the change idempotent and creates a root-owned timestamped backup before editing.
- Creates a root-only slow-log file under `/var/log/php8.3-fpm/`.
- Adds daily rotation, retaining seven compressed rotations, and uses Ubuntu's PHP-FPM log-reopen helper.
- Runs `php-fpm8.3 -t` and a logrotate config check before gracefully reloading PHP-FPM. The standalone play asserts the exact hostname, Ubuntu 22.04, PHP-FPM 8.3, and systemd graceful-reload support.

## Deploy

From this directory, set `SSH_TARGET` to the verified SSH destination. Keep the existing SSH session available while deploying. Then run the focused playbook with Ansible installed on the controller:

```sh
export SSH_TARGET='your-verified-ssh-destination'
ansible-playbook -i "$SSH_TARGET," -u keith --private-key "$HOME/.ssh/id_ed25519" --ask-become-pass deploy-slowlog.yml
```

Enter the sudo/become password only at Ansible's terminal prompt. The inline inventory avoids recording the host IP in Git. Review the play output; do not add `--diff` if you do not want to display the changed pool-file lines. To preview, use `--check` first; check mode does not apply or reload configuration.

## Verify after deployment

1. `systemctl is-active php8.3-fpm` should report `active`.
2. Confirm the pool file has exactly one each of `request_slowlog_timeout` and `slowlog`, and that the slow-log file is root-owned mode `0600`.
3. Review only recent root-readable slow-log output after a request has exceeded five seconds. No slow traces immediately after deployment is normal.
4. Check `grep` of the PHP-FPM service journal for errors and review memory/load. Do not raise `pm.max_children` based solely on the warning.

The Ansible controller in the current VS Code environment did not have `ansible-playbook` installed, and the configured Python environment lacks pip. Install Ansible on the controller before running these commands. No remote configuration has yet been changed by this play.

## Rollback

Restore the timestamped backup created next to `/etc/php/8.3/fpm/pool.d/www.conf`, remove `/etc/logrotate.d/php8.3-fpm-slow`, and optionally archive or remove the slow-log file after review. Validate with `php-fpm8.3 -t`, then gracefully reload `php8.3-fpm`. Keep the backup path printed in Ansible output.
