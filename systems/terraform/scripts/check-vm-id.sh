#!/usr/bin/env bash
# Read-only first-create preflight. Intentionally refuses ANY occupied VM/LXC ID,
# including an existing trial. Never imports, deletes, or changes infrastructure.
set -euo pipefail

if [[ $# != 2 ]]; then
  printf 'Usage: bash scripts/check-vm-id.sh HTTPS_ORIGIN VM_ID\n' >&2
  exit 2
fi

endpoint=${1%/}
vm_id=$2
if [[ ! $endpoint =~ ^https://[^/?#[:space:]]+$ || $endpoint == *'@'* ]]; then
  printf 'Use an HTTPS origin without a path, query or embedded credentials.\n' >&2
  exit 2
fi
if [[ ! $vm_id =~ ^[1-9][0-9]{2,8}$ ]] || (( vm_id > 999999999 )); then
  printf 'VM ID must be an integer between 100 and 999999999.\n' >&2
  exit 2
fi
if [[ -z ${PROXMOX_VE_API_TOKEN:-} ]]; then
  printf 'Set PROXMOX_VE_API_TOKEN securely in this terminal first.\n' >&2
  exit 2
fi
if [[ $PROXMOX_VE_API_TOKEN == *$'\n'* || $PROXMOX_VE_API_TOKEN == *$'\r'* ]]; then
  printf 'API token must not contain newlines.\n' >&2
  exit 2
fi
command -v curl >/dev/null
command -v jq >/dev/null

# /cluster/nextid with vmid checks that exact cluster-wide ID, rather than
# listing only guests visible to this token. A used ID is rejected by PVE.
# Header via stdin keeps the secret out of curl's command-line arguments.
if ! response=$(
  printf 'Authorization: PVEAPIToken=%s\n' "$PROXMOX_VE_API_TOKEN" |
    curl --silent --show-error --fail-with-body --connect-timeout 10 --max-time 30 \
      --header @- "$endpoint/api2/json/cluster/nextid?vmid=$vm_id"
); then
  printf 'STOP: unable to confirm ID %s is free (occupied ID, ACL, API or TLS error). No changes made.\n' "$vm_id" >&2
  exit 1
fi
if ! jq -e --arg id "$vm_id" '.data != null and ((.data | tostring) == $id)' \
  <<< "$response" >/dev/null; then
  printf 'STOP: API did not confirm the requested ID. No changes made.\n' >&2
  exit 1
fi
printf 'ID %s is currently free cluster-wide. This is a check, NOT a reservation.\n' "$vm_id"