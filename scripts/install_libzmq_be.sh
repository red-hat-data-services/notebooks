#!/bin/bash
# Install libzmq.so.5 on BE arches where the zeromq RPM is unavailable in UBI9.
# RH pyzmq wheels link dynamically against libzmq.so.5.

set -Eeuxo pipefail

arch="${1:-$(uname -m)}"
if [ "$arch" != "s390x" ] && [ "$arch" != "ppc64le" ]; then
    echo "Skipping libzmq install on ${arch}"
    exit 0
fi

LIBZMQ_VERSION=4.3.5
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fL "https://github.com/zeromq/libzmq/releases/download/v${LIBZMQ_VERSION}/zeromq-${LIBZMQ_VERSION}.tar.gz" \
    -o "${workdir}/libzmq.tar.gz"
tar -xzf "${workdir}/libzmq.tar.gz" -C "${workdir}"
cd "${workdir}/zeromq-${LIBZMQ_VERSION}"

./configure --prefix=/usr --with-libsodium=no --with-norm=no --with-gssapi=no
make -j"$(nproc)"
make install
ldconfig

if ! test -f /usr/lib64/libzmq.so.5 && ! test -f /usr/lib/libzmq.so.5; then
    echo "Error: libzmq.so.5 was not found after installation" >&2
    exit 1
fi
