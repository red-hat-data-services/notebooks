#!/bin/bash
set -Eeuxo pipefail

ARROW_SOURCE_DIR=$(realpath "$1")
mkdir -p "$2"
WHEELS_DIR=$(realpath "$2")
BUILD_PYTHON=$(command -v python)

# requirements-wheel-build.txt targets NumPy 2 wheels; TrustyAI needs NumPy 1.26.
# These satisfy Arrow's build-system.requires while keeping that runtime ABI.
uv pip install --python "${BUILD_PYTHON}" \
    'cython>=3.1,<3.3' 'libcst>=1.8.6' 'numpy~=1.26.4' scikit-build-core 'setuptools_scm[toml]>=8'
"${BUILD_PYTHON}" -c 'import Cython, libcst, numpy, scikit_build_core, setuptools_scm'

# Keep these as separate commands: failures in an && chain can bypass set -e.
# PyArrow 25 requires Compute and CSV; datasets also needs Dataset/Acero and JSON.
cmake -S "${ARROW_SOURCE_DIR}/cpp" -B "${ARROW_SOURCE_DIR}/cpp/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DARROW_BUILD_TESTS=OFF \
    -DARROW_BUILD_STATIC=OFF \
    -DARROW_JEMALLOC=ON \
    -DARROW_COMPUTE=ON \
    -DARROW_CSV=ON \
    -DARROW_JSON=ON \
    -DARROW_ACERO=ON \
    -DARROW_DATASET=ON \
    -DARROW_PARQUET=ON \
    -DARROW_WITH_SNAPPY=ON \
    -DARROW_WITH_ZLIB=ON \
    -DARROW_WITH_ZSTD=ON \
    -DARROW_WITH_LZ4=ON
cmake --build "${ARROW_SOURCE_DIR}/cpp/build" --parallel "${MAX_JOBS:-$(nproc)}"
cmake --install "${ARROW_SOURCE_DIR}/cpp/build"

cd "${ARROW_SOURCE_DIR}/python"
PYARROW_BUNDLE_ARROW_CPP=ON \
CMAKE_BUILD_PARALLEL_LEVEL="${PYARROW_PARALLEL:-$(nproc)}" \
uv build --python "${BUILD_PYTHON}" --wheel --no-build-isolation --out-dir "${WHEELS_DIR}" \
    --config-setting="cmake.define.Python3_EXECUTABLE=${BUILD_PYTHON}" \
    --config-setting=cmake.define.CMAKE_PREFIX_PATH=/usr/local
