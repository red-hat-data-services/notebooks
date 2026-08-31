#!/bin/bash
# ppc64le/s390x runtime RPMs for RH prebuilt wheels (pyzmq, numpy/scipy, pyarrow, pillow).
# RHEL 9 with subscription only (rhoai GHA/Konflux).
set -Eeuxo pipefail

arch="${1:-$(uname -m)}"
case "${arch}" in
    ppc64le | s390x) ;;
    *) exit 0 ;;
esac

EPEL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

dnf install -y dnf-plugins-core "${EPEL}"
subscription-manager repos --enable "codeready-builder-for-rhel-9-${arch}-rpms"

dnf install -y \
    zeromq openblas-threads \
    lcms2 openjpeg2 re2 utf8proc snappy

# EPEL thrift is 0.15; pyarrow 25 needs libthrift-0.24.0.so from COPR.
dnf install -y 'dnf-command(copr)'
dnf copr enable -y aaiet-notebooks/rhelai-el9
dnf install -y thrift
dnf copr disable -y aaiet-notebooks/rhelai-el9 || true
dnf clean all

if test -f /usr/lib64/libopenblasp.so.0 && ! test -e /usr/lib64/libopenblas.so.0; then
    ln -sf /usr/lib64/libopenblasp.so.0 /usr/lib64/libopenblas.so.0
    ldconfig
fi

test -f /usr/lib64/libthrift-0.24.0.so
