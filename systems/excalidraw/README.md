# Excalidraw collaboration infrastructure

**Status: prepared locally; not deployed or commissioned.** Host placement, DNS,
TLS, access control and off-host backup destination are still decisions to make.
The proposed hostname is `draw.keithmarston.me.uk`; it is not an existing service
claim. This is a separate Compose project, not part of the `iot-home` HA stack.

## Scope and decision

Use the [alswl collaboration stack](https://github.com/alswl/excalidraw-collaboration)
for a self-hosted drawing canvas, live collaboration and persistent scenes/files.
MongoDB supplies durable storage; nginx on the **same Docker host** supplies one
HTTPS origin. See the [design and acceptance criteria](../../docs/design/excalidraw.md).

This is **not a document-management application**. There is no implemented login,
named drawing list, folders, search, ownership or Forgejo integration. The browser's
ordinary working canvas is not a guarantee of server-side saving. Use a saved
scene link or collaboration room link to reopen server-stored content; commission
both workflows separately. Export `.excalidraw` files for portable editable copies.

Keep the **complete link, including its fragment/key**: encrypted content in MongoDB
alone cannot reconstruct a lost decryption key. Treat links as sensitive. Exported
scene links may be snapshots rather than an ongoing editable document; verify
the chosen workflow rather than promising Google Drive-style Save semantics.

## Files and boundaries

- [docker-compose.yml](docker-compose.yml): frontend, storage, room service and MongoDB.
- [.env.example](.env.example): proposed public host, release tags, local ports and
  password placeholders. Copy to a local `.env`, outside version control.
- [config/mongo-init.js](config/mongo-init.js): dedicated database-scoped storage user.
- [config/nginx.conf.example](config/nginx.conf.example): host nginx/TLS template.
- [.gitignore](.gitignore): excludes local secrets, backups and drawing exports.

Only frontend `9013`, storage `9014` and room `9015` are published, on
`127.0.0.1` only. MongoDB has no published port and uses an internal Docker
network. If nginx lives on another host or in a container, this template is not
directly usable: explicitly design private routing/Compose network membership
instead of changing listeners to `0.0.0.0` by default.

## Preparation and startup runbook

Run commands from this project directory on the **chosen deployment host**.
Nothing in this repository installs nginx, obtains certificates or provisions DNS.

1. Confirm the owning host, architecture/image compatibility, Docker Compose,
   capacity, available ports, backup ownership and access policy. Review all four
   image tags for security/support; the upstream Mongo/storage baselines are old.
   Record tested image digests before production, and keep the previous digests.
2. Copy the environment example to local `.env` with permissions `0600`. Replace
   both password placeholders with independent random hex values of at least 32
   characters. Do not commit secrets or paste rendered Compose config into an issue.
   Compose's non-empty checks do not reject a placeholder root password.
3. Set `APP_HOST` to the agreed hostname (no scheme, path or trailing slash), and
   arrange trusted TLS plus split-horizon DNS. Remote browsers need HTTPS for the
   crypto APIs; plain LAN-IP HTTP is not a supported commissioning path.
4. Restrict ingress to trusted LAN/VPN clients. This stack has **no application
   authentication**. A guessed/unshared link is not an ingress policy. If an
   authentication proxy is chosen later, protect frontend, storage and Socket.IO
   together and test browser HTTP/WebSocket access through it.
5. Validate with `docker compose --env-file .env config --quiet`, pull the reviewed
   images with `docker compose --env-file .env pull`, then start with
   `docker compose --env-file .env up -d`. Check `docker compose ps` and private
   service logs. MongoDB initialization must finish and storage must connect
   without falling back to memory or reporting authentication errors.
6. Adapt the nginx template's hostname, certificate paths and ports; install it
   using the host's normal change-control process. Run `nginx -t` before reloading.
   Do not reload an invalid vhost or overwrite unrelated nginx configuration.
7. Complete the acceptance checklist in the design note before declaring live.

Named volumes `excalidraw_mongo-data` and `excalidraw_mongo-config` retain database
state across ordinary `docker compose down`/`up`. **Never use `down -v` on live
data.** The fixed Compose project name must stay stable during migration/recovery.
Passwords/user initialization apply only to an **empty** Mongo data volume:
editing `.env` does not rotate an existing database user's password. Rotate via
authenticated Mongo administration and coordinate the storage credential update.

## Backup and recovery

Before production, record destination, encryption, schedule, retention, recovery
objectives and stale-backup monitoring. No scheduled backup is supplied yet.

- Quiesce frontend/room/storage writes, then take an authenticated full MongoDB
  logical dump (including users/roles) using `mongodump --archive --gzip`. Supply
  credentials from protected host configuration, not a logged command line.
- Back up `.env`, tested image digests and nginx/certificate configuration securely,
  plus a private index of complete scene/room links and portable drawing exports.
  Backups can contain secrets and personal diagrams: encrypt off-host copies.
- Do not copy a running Mongo volume as a supposedly consistent database backup.
  A filesystem archive requires MongoDB stopped and a consistent volume snapshot.
- Test restore on an isolated Docker host/project and hostname, with **no live
  clients**. Initialize appropriate admin access, restore the logical archive and
  users/roles, then verify storage credentials. Do not run first-start initialization
  against recovered data expecting it to replace credentials.
- Verify old scene/room links and embedded images from a second browser, then
  restart the restored services and verify again. If testing under a different
  hostname, retain the original link's fragment/key when changing its origin.

## Updates and rollback

Quiesce writers and take a verified database backup before an update. Record the
old image digests, environment and nginx config. Review upstream compatibility,
especially MongoDB version/feature-compatibility constraints; test migrations in
isolation first. Change the image references, validate Compose and recreate the
affected services. Repeat the cross-browser/restart/image acceptance checks.

Roll back application images/config only if database compatibility permits it.
For incompatible migrations, restore the pre-change database backup in isolation
and follow a controlled cutover; **do not blindly downgrade MongoDB binaries**.
An image rollback alone is not a database rollback.

## Validation status

On 2026-11-07, Compose validation with the non-secret environment example passed.
Structural assertions checked all four services, same-origin frontend URLs,
loopback listeners, private Mongo networking, named volumes and the Mongo readiness
dependency. All seven required variables rejected empty values, 27 local links
resolved, secret/backup ignore rules matched and `git diff --check` passed.
Editor diagnostics reported no errors. No host Node.js or nginx executable was
available, so Mongo initialization and `nginx -t` were not executed.

Local structural validation does not prove image availability, service startup,
TLS, WebSocket collaboration, storage writes or recovery. Those checks require
the chosen host and commissioned ingress. No live service has been changed.