# WordPress protection production candidate — not enabled

This is a proposal only. No configuration is installed or activated on the host. First deploy diagnostics, inspect the resulting slow traces and would-be ban list, then review and approve any enforcement separately.

## PHP-FPM diagnostic-first proposal

The host is under 1 GiB RAM and the current pool allows three children. At the observed snapshot only 114 MiB was available, while the logs repeatedly reported the pool at `pm.max_children`. Increasing children without a measured memory budget risks OOM. First add slow logging to the existing `[www]` pool and observe during a representative load window:

```ini
; Add to the existing [www] pool config after confirming exact path and owner.
request_slowlog_timeout = 5s
slowlog = /var/log/php8.3-fpm/www-slow.log
```

Create the log directory/file with root ownership and permissions that permit PHP-FPM to write but limit read access. Validate with `php-fpm8.3 -t` (or the installed binary's equivalent). Reload only after reviewing the diff and securing a rollback copy. Capture slow traces, per-child RSS over time, and pool status before setting `request_terminate_timeout`; a hard timeout can interrupt legitimate long WordPress work. Don't raise `pm.max_children` until a conservative memory budget is established from observed peak child RSS and non-PHP services.

## Fail2ban design proposal

The workspace contains two narrowly scoped candidate filters:

- `nginx-wordpress-login.conf`: POST to `/wp-login.php` only.
- `nginx-wordpress-xmlrpc.conf`: POST to `/xmlrpc.php`, accepting the observed duplicate-slash form.

Both have passed synthetic positive/negative tests and the candidate regexes match real Nginx records. Do not copy/install these yet. Match counts over the current day's log were 382 login POSTs and 764 XML-RPC POSTs. XML-RPC is reportedly unused; the busiest login source is not recognized. Both are rate signals, not failed-authentication evidence.

Proposed first enforcement settings after reviewing exact candidate IPs and the current `ignoreip` / ban action:

- XML-RPC: `maxretry = 30`, `findtime = 10m`, `bantime = 10m`.
- Login POST: `maxretry = 20`, `findtime = 10m`, `bantime = 10m`.
- Separate jails and files, preserving the existing `sshd` jail. Do not use global Fail2ban defaults as implicit configuration; set and review all needed options, especially `backend`, `logpath`, `banaction`, and `ignoreip`.
- Initially keep both web jails `enabled = false`. Preview matches using `fail2ban-regex`, inspect `fail2ban-client -d` output and the candidate source list, then enable only with a tested SSH-safe rollback path.

These rates are starting test thresholds—not a claim of ideal limits. Re-evaluate against normal login/maintenance activity. The pattern includes any POST response status and can match unsuccessful and successful-looking attempts; Fail2ban here provides temporary request-rate containment, not account compromise detection. Do not automatically escalate ban length or permanently block addresses based only on these request paths.

## Rollback checklist

1. Save exact copies and checksums of the active FPM pool and Fail2ban files before deployment.
2. Validate FPM config; validate filters with `fail2ban-regex`; inspect the parsed Fail2ban config before reload/restart.
3. Keep the current SSH session open and verify a second SSH connection before changing firewall actions.
4. On false positives or service impact, disable only the new web jails, reload/restart Fail2ban, restore the FPM pool backup if needed, validate, and reload PHP-FPM.
5. Check site response, PHP-FPM pool warnings/slow traces, memory, and Fail2ban ban/unban history after each one-at-a-time change.
