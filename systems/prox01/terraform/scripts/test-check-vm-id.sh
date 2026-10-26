#!/usr/bin/env bash
# Exercise the actual preflight script with a fake curl transport. No network.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
export PROXMOX_VE_API_TOKEN='offline@pve!test=not-a-real-secret'

curl() {
  local header
  IFS= read -r header
  [[ $header == "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" ]] || return 90
  [[ ${!#} == 'https://example.invalid/api2/json/cluster/nextid?vmid=4001' ]] || return 91
  case "$CURL_CASE" in
    free) printf '{"data":"4001"}' ;;
    occupied_or_api_failure) return 22 ;;
    wrong_id) printf '{"data":"4002"}' ;;
    null) printf '{"data":null}' ;;
    malformed) printf 'not json' ;;
  esac
}
export -f curl

export CURL_CASE=free
bash check-vm-id.sh https://example.invalid 4001 >/dev/null
passed=1
for CURL_CASE in occupied_or_api_failure wrong_id null malformed; do
  export CURL_CASE
  if bash check-vm-id.sh https://example.invalid 4001 >/dev/null 2>&1; then
    printf 'FAIL: preflight accepted %s\n' "$CURL_CASE" >&2
    exit 1
  fi
  passed=$((passed + 1))
done
export CURL_CASE=free
if PROXMOX_VE_API_TOKEN='' bash check-vm-id.sh https://example.invalid 4001 >/dev/null 2>&1; then
  printf 'FAIL: preflight accepted missing token\n' >&2
  exit 1
fi
if bash check-vm-id.sh https://example.invalid invalid-id >/dev/null 2>&1; then
  printf 'FAIL: preflight accepted invalid ID\n' >&2
  exit 1
fi
if bash check-vm-id.sh http://example.invalid 4001 >/dev/null 2>&1; then
  printf 'FAIL: preflight accepted insecure endpoint\n' >&2
  exit 1
fi
printf 'Preflight tests: %s passed (fake transport, no API requests).\n' "$((passed + 3))"