#!/bin/bash
# ppc64le/s390x runtime libs for RH prebuilt wheels (pyzmq, numpy/scipy, pyarrow, pillow).
# RHEL 9 signed RPMs and source builds only — no EPEL/COPR (Conforma rpm_signature policy).
set -Eeuxo pipefail

arch="${1:-$(uname -m)}"
case "${arch}" in
    ppc64le | s390x) ;;
    *) exit 0 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

THRIFT_VERSION=0.24.0
RE2_VERSION=2023-03-01

DNF_OPTS=(
    --disablerepo='*-debug-*'
    --disablerepo='*-source-*'
    --disablerepo='*-eus-*'
)

subscription-manager refresh || true
# Konflux builders use full RHEL subs; local UBI activation keys expose ubi-9-* repos only.
if ! subscription-manager repos --enable "codeready-builder-for-rhel-9-${arch}-rpms" 2>/dev/null; then
    subscription-manager repos --enable ubi-9-codeready-builder-rpms 2>/dev/null || true
fi

dnf install -y "${DNF_OPTS[@]}" \
    openblas openblas-threads \
    lcms2 openjpeg2 snappy utf8proc

# Build thrift/re2 from source; libzmq via install_libzmq_be.sh (same pattern as minimal).
dnf install -y "${DNF_OPTS[@]}" cmake boost-devel libevent-devel openssl-devel zlib-devel

curl -fL "https://github.com/apache/thrift/archive/refs/tags/v${THRIFT_VERSION}.tar.gz" \
    -o "${workdir}/thrift.tar.gz"
tar -xzf "${workdir}/thrift.tar.gz" -C "${workdir}"
cmake -S "${workdir}/thrift-${THRIFT_VERSION}" -B "${workdir}/thrift-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_COMPILER=OFF \
    -DBUILD_TESTING=OFF \
    -DBUILD_TUTORIALS=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_JAVASCRIPT=OFF \
    -DBUILD_NODEJS=OFF \
    -DBUILD_PYTHON=OFF \
    -DBUILD_C_GLIB=OFF \
    -DBUILD_CPP=ON \
    -DWITH_CPP=ON \
    -DWITH_LIBEVENT=ON \
    -DWITH_ZLIB=ON \
    -DWITH_OPENSSL=ON
cmake --build "${workdir}/thrift-build" -j"$(nproc)"
cmake --install "${workdir}/thrift-build"
thrift_soname="$(find /usr/lib64 /usr/lib -maxdepth 1 -name 'libthrift.so.*' -type f 2>/dev/null | sort -V | tail -1)"
test -n "${thrift_soname}"
ln -sf "${thrift_soname}" /usr/lib64/libthrift-0.24.0.so

curl -fL "https://github.com/google/re2/archive/refs/tags/${RE2_VERSION}.tar.gz" \
    -o "${workdir}/re2.tar.gz"
tar -xzf "${workdir}/re2.tar.gz" -C "${workdir}"
cmake -S "${workdir}/re2-${RE2_VERSION}" -B "${workdir}/re2-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DBUILD_SHARED_LIBS=ON \
    -DRE2_BUILD_TESTING=OFF
cmake --build "${workdir}/re2-build" -j"$(nproc)"
cmake --install "${workdir}/re2-build"

"${script_dir}/install_libzmq_be.sh" "$arch"

ldconfig

dnf remove -y "${DNF_OPTS[@]}" boost-devel libevent-devel || true
dnf clean all

if test -f /usr/lib64/libopenblasp.so.0 && ! test -e /usr/lib64/libopenblas.so.0; then
    ln -sf /usr/lib64/libopenblasp.so.0 /usr/lib64/libopenblas.so.0
    ldconfig
fi

cat > /etc/profile.d/rhoai-be-scientific-stack.sh <<'EOF'
# Headless matplotlib and bounded BLAS threading for ppc64le/s390x CI and runtime.
export MPLBACKEND=Agg
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
EOF

test -f /usr/lib64/libthrift-0.24.0.so
test -f /usr/lib64/libre2.so || test -f /usr/lib64/libre2.so.10
