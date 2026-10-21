#!/bin/bash

# Pin packages.redhat.com to a public address for this build step.
# s390x and ppc64le Konflux builders resolve that name to the internal ROSA
# ELB (10.29.80.0/24), and the TCP handshake times out. uv uses the system
# resolver, so /etc/hosts has to be updated here: buildah replaces it at the
# start of every RUN, and pod hostAliases never reach the build container.
# Must run as root in the same RUN as the client that connects.

set -Eeuo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: $(basename "$0") must run as root" >&2
    exit 1
fi

_doh_json=""
for _doh_url in \
    "https://cloudflare-dns.com/dns-query?name=packages.redhat.com&type=A" \
    "https://dns.google/resolve?name=packages.redhat.com&type=A"
do
    if _doh_json="$(curl --fail --silent --show-error --location \
        --connect-timeout 20 --max-time 30 \
        --retry 2 --retry-delay 1 --retry-connrefused \
        -H 'accept: application/dns-json' \
        "${_doh_url}")"; then
        break
    fi
    _doh_json=""
done

if [[ -z "${_doh_json}" ]]; then
    echo "WARNING: public DoH lookup for packages.redhat.com failed; using cluster DNS" >&2
    exit 0
fi

_ip="$(printf '%s' "${_doh_json}" | python3 -c '
import ipaddress
import json
import sys

raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    raise SystemExit(0)
for answer in data.get("Answer") or []:
    if answer.get("type") != 1:
        continue
    try:
        address = ipaddress.ip_address(answer.get("data") or "")
    except ValueError:
        continue
    if isinstance(address, ipaddress.IPv4Address) and address.is_global:
        print(address)
        break
')"

if [[ -z "${_ip}" ]]; then
    echo "WARNING: public DoH returned no routable address for packages.redhat.com; using cluster DNS" >&2
    exit 0
fi

_hosts_tmp="$(mktemp)"
grep -v -E '[[:space:]]packages\.redhat\.com([[:space:]]|$)' /etc/hosts > "${_hosts_tmp}" || true
printf '%s packages.redhat.com\n' "${_ip}" >> "${_hosts_tmp}"
cat "${_hosts_tmp}" > /etc/hosts
rm -f "${_hosts_tmp}"
echo "Pinned packages.redhat.com to ${_ip}"
