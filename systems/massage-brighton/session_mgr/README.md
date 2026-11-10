# WordPress resource protection

## Goal

Reduce the impact of abusive or runaway requests on the remote WordPress server using backend controls only. There should be no end-user banner.

The site is believed to receive low legitimate traffic (roughly 100 visits per month); verify this from access logs before setting limits. Fail2ban is already enabled for SSH.

## Approach

Work in stages, starting with read-only evidence gathering:

1. Identify the OS, web server, PHP version and PHP-FPM service/pool, log locations, and current Fail2ban jails.
2. Review a time-bounded sample of web access/error logs and PHP-FPM logs around CPU or memory alerts. Correlate requests and source addresses; do not infer an offending IP from whole-server CPU or memory alone.
3. Tune PHP-FPM as the **terminator**: assess worker capacity against available memory, then consider request timeouts, slow logging, and worker recycling. Validate configuration and preserve a rollback copy before reloading.
4. Add a Fail2ban **blocker** only after logs establish a repeatable abusive request pattern. Test the filter against real log samples, account for trusted/shared addresses, begin with a conservative temporary ban, and verify the firewall action and unban path.
5. Recheck service health, logs, and false positives after deployment; document the exact rollback steps.

## Safety and evidence

- Collect only the time window around an alert and the relevant services; avoid copying full logs unnecessarily.
- Redact credentials, cookies, authorization headers, and sensitive query parameters before sharing logs. If source IPs need privacy, replace each with a consistent pseudonym so repeated traffic remains correlatable.
- Do not deploy guessed limits or a generic “high CPU per IP” ban. CPU and memory are server-wide measures, not per-request attribution.
- Make one change at a time, validate before reload, and keep a known-good configuration available for rollback.

## Read-only prototype

`log_audit.py` reads standard Nginx combined access logs from standard input and groups requests by client and fixed five-minute buckets. It strips query strings, reports method/path/status aggregates, anonymizes addresses by default, and never bans or changes the host. A bucket is only a review lead, not a blocking rule.

`nginx-wordpress-login.conf` and `nginx-wordpress-xmlrpc.conf` are candidate Fail2ban filters, not installed configuration. They match only POST requests to the WordPress login or XML-RPC endpoint so they can be given separate retry thresholds. `test_wordpress_filter.py` checks positive and negative synthetic examples.

Run the synthetic tests with `python3 -m unittest -v test_log_audit.py test_wordpress_filter.py` from this directory. Set `SSH_TARGET` in your shell to the working SSH destination for this server; don't commit its address. To review a bounded recent sample, stream it into the analyzer rather than saving a second copy of the log:

```sh
ssh "$SSH_TARGET" 'tail -n 10000 /var/log/nginx/access.log' | python3 log_audit.py
```

Use `--show-ips` only for private review when actual addresses are necessary. Never enable automatic bans from this prototype.

## Current status

- Connected read-only to the WordPress host; it reports `massage-brighton-02`, Ubuntu 22.04.5, Nginx, PHP-FPM 8.3, and Fail2ban. Current pool settings include `pm.max_children = 3` and `pm.max_requests = 500`; no slow-log or request-termination settings were found in the pool file. No settings have been changed.
- At the inspection time, the host had 957 MiB RAM, 114 MiB available, no swap pressure, and low load; MySQL and two PHP workers were among the largest processes. No OOM-killer events were found in the recent kernel journal.
- The active Nginx log covered midnight through about 14:10 and had about 13,700 records. Around 11:25–11:35, one external source made 132 requests, including 115 HTTP 499s and probes for sensitive files; another source made 26 requests to the home/treatment pages. A separate Nginx error showed a PHP upstream timeout on `/news_sitemap.xml`. The 499 status means the client closed the request; it does not alone prove server-side failure. The current Nginx access format has no request-duration field.
- The supplied PHP-FPM log tail showed `pm.max_children` (3) reached 29 times between 10:39 and 14:06. That confirms worker-pool saturation, but not which requests caused it. Memory was only 114 MiB available on a 957 MiB host at the inventory snapshot, so do not simply raise the worker count before measuring worker memory and identifying slow requests. Enable slow logging as the next diagnostic step; no FPM settings have yet changed.
- Candidate filters were tested with the server's `fail2ban-regex`: 764 XML-RPC POSTs and 382 login POSTs matched in the active log. The owner says XML-RPC is not used and does not recognize the busiest login source. These counts include responses regardless of success; they are signals for a rate-based jail, not proof of failed authentication. The exact candidate filters and synthetic tests are in this directory.
- The `basic_status` location is IP-allowlisted. No Nginx real-IP/proxy trust directives were found, so `$remote_addr` appears to be the direct client address.
- PHP-FPM's file log is root-only. The user supplied a bounded tail showing repeated pool-saturation warnings; it contained no slow-stack traces because slow logging is not configured.
- Fail2ban currently has only the distribution-enabled `sshd` jail; no custom web jail or override was found. Existing SSH bans/unbans are being logged.
- `log_audit.py`, the two candidate filters, and their tests are local-only. Nine synthetic tests pass; the candidate Fail2ban regexes also match against the live log using `fail2ban-regex`. No jail/filter, PHP-FPM, or Nginx configuration has been changed.
- Next production-prep steps: configure a short temporary ban for repeated XML-RPC POSTs and a more conservative threshold for login POSTs; keep each jail disabled until reviewing a dry-run candidate list. For PHP-FPM, enable a 5-second slow log first, estimate a safe worker memory budget, then consider a conservative request-termination timeout. Validate syntax and rollback before any reload.

