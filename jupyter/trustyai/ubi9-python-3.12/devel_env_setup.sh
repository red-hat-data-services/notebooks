#!/bin/bash
set -eoux pipefail

#####################################################################################################
# This script installs build-time dependencies for ppc64le and s390x Python wheels.                  #
# OpenBLAS is built from source on ppc64le; s390x uses the distro-provided library.                  #
#####################################################################################################
WHEELS_DIR=/wheelsdir
mkdir -p "${WHEELS_DIR}"
ARCH=$(uname -m)

if [[ "${ARCH}" == "ppc64le" || "${ARCH}" == "s390x" ]]; then
    CURDIR=$(pwd)

    # Install development packages shared by the IBM architectures.
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    if [[ "${ARCH}" == "s390x" ]]; then
        dnf clean all
        dnf install -y dnf-plugins-core
        if command -v subscription-manager &> /dev/null; then
            subscription-manager repos --enable "codeready-builder-for-rhel-9-${ARCH}-rpms"
        else
            dnf config-manager --set-enabled crb
        fi
    fi

    dnf install -y gcc gcc-c++ gcc-gfortran make cmake ninja-build \
        autoconf automake libtool pkg-config \
        python3.12-devel python3-devel pybind11-devel openssl-devel \
        fribidi-devel lcms2-devel libimagequant-devel patchelf libraqm-devel \
        openjpeg2-devel tcl-devel tk-devel unixODBC-devel \
        zlib-devel libjpeg-devel libtiff-devel freetype-devel libwebp-devel \
        git tar wget unzip

    if [[ "${ARCH}" == "ppc64le" ]]; then
        dnf install -y gcc-toolset-13 gcc-toolset-13-libatomic-devel
        source /opt/rh/gcc-toolset-13/enable
    else
        dnf install -y openblas-devel
        export CFLAGS="-O3"
        export CXXFLAGS="-O3"
    fi

    # Isolate rustup from any pre-existing root configuration in the base image.
    RUSTUP_TMP=$(mktemp -d)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "${RUSTUP_TMP}/rustup-init.sh"
    chmod +x "${RUSTUP_TMP}/rustup-init.sh"
    mkdir -p /opt/.cargo /opt/.rustup
    CARGO_HOME=/opt/.cargo RUSTUP_HOME=/opt/.rustup HOME=/root \
        "${RUSTUP_TMP}/rustup-init.sh" -y --no-modify-path --default-toolchain stable --profile minimal
    rm -rf "${RUSTUP_TMP}"
    export CARGO_HOME=/opt/.cargo
    export RUSTUP_HOME=/opt/.rustup
    export PATH="${CARGO_HOME}/bin:${PATH}"
    rustc --version
    cargo --version

    export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
    uv pip install cmake 'cython>=3.1,<3.3' 'libcst>=1.8.6' 'numpy~=1.26.4' scikit-build-core 'setuptools_scm[toml]>=8'
fi

if [[ "${ARCH}" == "ppc64le" ]]; then
    export MAX_JOBS=${MAX_JOBS:-$(nproc)}
    export OPENBLAS_VERSION=${OPENBLAS_VERSION:-0.3.30}

    # Install OpenBlas
    # IMPORTANT: Ensure Openblas is installed in the final image
    cd /root
    curl -L "https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}.tar.gz" | tar xz
    # rename directory for mounting (without knowing version numbers) in multistage builds
    openblas_src="OpenBLAS-${OPENBLAS_VERSION}"
    mv "${openblas_src}/" OpenBLAS/
    cd OpenBLAS/
    make -j"${MAX_JOBS}" TARGET=POWER9 BINARY=64 USE_OPENMP=1 USE_THREAD=1 NUM_THREADS=120 DYNAMIC_ARCH=1 INTERFACE64=0
    make install
    cd ..

    # set path for openblas
    export LD_LIBRARY_PATH="/opt/OpenBLAS/lib/:/usr/local/lib64:/usr/local/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    PKG_CONFIG_PATH=$(find / -type d -name "pkgconfig" 2>/dev/null | tr '\n' ':' || true)
    export PKG_CONFIG_PATH
    CMAKE_ARGS="-DPython3_EXECUTABLE=$(command -v python)"
    export CMAKE_ARGS
    export CMAKE_POLICY_VERSION_MINIMUM=3.5

    TMP=$(mktemp -d)
    # Fail before the expensive builds if the selected toolchain cannot link libatomic.
    printf 'int main(void) { return 0; }\n' | gcc -x c - -latomic -o "${TMP}/libatomic-check"
    "${TMP}/libatomic-check"

    # Torch
    cd "${CURDIR}"
    # torch is pinned under x86_64 markers; we build the same version from source on ppc64le
    TORCH_VERSION=$(python3 ./pylock_version.py torch --platform x86_64)
    # Drop PEP 440 local segment (+cu128) for git tag; pre-releases (1.0a1) are unchanged.
    TORCH_VERSION=${TORCH_VERSION%%+*}
    TORCH_TAG="v${TORCH_VERSION}"
    cd "${TMP}"
    git clone --recursive https://github.com/pytorch/pytorch.git -b "${TORCH_TAG}"
    cd pytorch
    # lintrunner's sdist pyproject.toml is non-compliant with PEP 621; skip it (dev-only dep).
    # Keep the filtered requirements file in this directory so uv resolves nested
    # requirements includes (for example requirements-build.txt) relative to PyTorch.
    grep -v '^lintrunner' requirements.txt > requirements-pytorch-build.txt
    uv pip install -r requirements-pytorch-build.txt
    rm -f requirements-pytorch-build.txt
    python setup.py develop
    rm -f dist/torch*+git*whl
    MAX_JOBS=${MAX_JOBS:-$(nproc)} \
        PYTORCH_BUILD_VERSION="${TORCH_VERSION}" PYTORCH_BUILD_NUMBER=1 uv build --wheel --out-dir "${WHEELS_DIR}"

    cd "${CURDIR}"
    # Pyarrow
    PYARROW_VERSION=$(python3 ./pylock_version.py pyarrow --platform ppc64le)
    cd "${TMP}"
    git clone --recursive https://github.com/apache/arrow.git -b "apache-arrow-${PYARROW_VERSION}"
    bash "${CURDIR}/build_pyarrow.sh" "${TMP}/arrow" "${WHEELS_DIR}"
    compgen -G "${WHEELS_DIR}/pyarrow-${PYARROW_VERSION}-*.whl" > /dev/null

    # Pillow (use auditwheel repaired wheel to avoid pulling runtime libs from EPEL)
    cd "${CURDIR}"
    PILLOW_VERSION=$(python3 ./pylock_version.py pillow --platform ppc64le)
    cd "${TMP}"
    git clone --recursive https://github.com/python-pillow/Pillow.git -b "${PILLOW_VERSION}"
    cd Pillow
    uv build --wheel --out-dir /pillowwheel
    : ================= Fix Pillow Wheel ====================
    cd /pillowwheel
    uv pip install auditwheel
    auditwheel repair pillow*.whl
    mv wheelhouse/pillow*.whl "${WHEELS_DIR}"

    ls -ltr "${WHEELS_DIR}"

    cd "${CURDIR}"
    # accelerate is pinned under x86_64 markers; install the same version on ppc64le
    ACCELERATE_VERSION=$(python3 ./pylock_version.py accelerate --platform x86_64)
    uv pip install --refresh "${WHEELS_DIR}"/*.whl "accelerate==${ACCELERATE_VERSION}"

    uv pip list
    cd "${CURDIR}"
else
    # s390x and other architectures do not build the ppc64le OpenBLAS wheel;
    # keep this directory for the Dockerfile cache mount.
    mkdir -p /root/OpenBLAS/
fi
