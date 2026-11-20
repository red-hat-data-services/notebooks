#!/usr/bin/env bash
set -eu

system_bundle=/etc/pki/tls/certs/ca-bundle.crt
python_site_packages=/opt/app-root/lib/python3.12/site-packages

if [[ ! -f "$system_bundle" ]]; then
    echo "ERROR: system CA bundle not found: $system_bundle" >&2
    exit 1
fi

bundles=(
    "$python_site_packages/pip/_vendor/certifi/cacert.pem"
    "$python_site_packages/certifi/cacert.pem"
    "$python_site_packages/botocore/cacert.pem"
    "$python_site_packages/grpc/_cython/_credentials/roots.pem"
)

replaced=0
for bundle in "${bundles[@]}"; do
    if [[ -f "$bundle" ]]; then
        cp -- "$system_bundle" "$bundle"
        replaced=$((replaced + 1))
    fi
done

if (( replaced == 0 )); then
    echo "INFO: no vendored CA bundles found under $python_site_packages; nothing to replace" >&2
fi
