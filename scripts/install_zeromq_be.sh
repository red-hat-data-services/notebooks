#!/bin/bash
# ppc64le/s390x runtime RPMs for RH prebuilt wheels (pyzmq, numpy/scipy, pyarrow, pillow).
# RHEL 9 with subscription only (rhoai GHA/Konflux).
set -Eeuxo pipefail

arch="${1:-$(uname -m)}"
case "${arch}" in
    ppc64le | s390x) ;;
    *) exit 0 ;;
esac

dnf install -y dnf-plugins-core
subscription-manager repos --enable "codeready-builder-for-rhel-9-${arch}-rpms"

dnf install -y \
    zeromq openblas-threads \
    lcms2 openjpeg2 re2 utf8proc snappy

thrift_lib=$(rpm -ql thrift | grep -E '/libthrift[^/]*\.so(\.[0-9]+)*$' | head -n 1)
test -n "${thrift_lib}"
test -f "${thrift_lib}"
if ldd "${thrift_lib}" | tee /dev/stderr | grep 'not found' >/dev/null; then
    exit 1
fi
