#!/usr/bin/env bash
set -Eeuxo pipefail

readonly OUTPUT_DIR="${1:?usage: $0 OUTPUT_DIR}"
readonly TORCH_VERSION="2.7.1+rocm6.3"
readonly TORCH_WHEEL_FILE="torch-2.7.1+rocm6.3-cp312-cp312-manylinux_2_28_x86_64.whl"
readonly TORCH_WHEEL_URL="https://download-r2.pytorch.org/whl/rocm6.3/torch-2.7.1%2Brocm6.3-cp312-cp312-manylinux_2_28_x86_64.whl"
readonly TORCH_WHEEL_SHA256="b0c10342f64a34998ae8d5084aa1beae7e11defa46a4e05fe9aa6f09ffb0db37"
readonly TORCHVISION_VERSION="0.22.1+rhaiv.1"
readonly TORCHVISION_WHEEL_FILE="torchvision-0.22.1+rocm6.3-cp312-cp312-manylinux_2_28_x86_64.whl"
readonly TORCHVISION_WHEEL_URL="https://download-r2.pytorch.org/whl/rocm6.3/torchvision-0.22.1%2Brocm6.3-cp312-cp312-manylinux_2_28_x86_64.whl"
readonly TORCHVISION_WHEEL_SHA256="0dce205fb04d9eb2f6feb74faf17cba9180aff70a8c8ac084912ce41b2dc0ab7"
readonly TORCHVISION_SOURCE_COMMIT="0906be0d2304d57504177cb54248ccb59132205c"
readonly TORCHVISION_SOURCE_URL="https://github.com/opendatahub-io/torchvision/archive/${TORCHVISION_SOURCE_COMMIT}.tar.gz"
readonly TORCHVISION_SOURCE_SHA256="572cf1348f37c83738b6ff98964a8e4f0f3594ecc4bb986ea23e1f3a9d52c989"

BUILD_DIR=$(mktemp -d /tmp/torchvision-build.XXXXXX)
readonly BUILD_DIR
trap 'rm -rf "${BUILD_DIR}"' EXIT

mkdir -p "${OUTPUT_DIR}"

download_and_verify() {
    local url=$1
    local sha256=$2
    local destination=$3

    curl --fail --location --show-error --output "${destination}" "${url}"
    printf '%s  %s\n' "${sha256}" "${destination}" | sha256sum --check --strict -
}

# Install the exact Torch ABI and the Python build dependencies in this throwaway
# builder stage. The final image still installs Torch from its generated lockfile.
download_and_verify "${TORCH_WHEEL_URL}" "${TORCH_WHEEL_SHA256}" "${BUILD_DIR}/${TORCH_WHEEL_FILE}"
uv pip install --strict --no-deps --no-cache --no-config --no-progress \
    'filelock==3.32.4' \
    'fsspec==2026.7.0' \
    'jinja2==3.1.6' \
    'markupsafe==3.0.3' \
    'mpmath==1.3.0' \
    'networkx==3.6.1' \
    'numpy==2.3.5' \
    'pillow==12.3.0' \
    'setuptools==80.9.0' \
    'sympy==1.14.0' \
    'typing-extensions==4.16.0' \
    'wheel==0.46.3'
uv pip install --strict --no-deps --no-cache --no-config --no-progress "${BUILD_DIR}/${TORCH_WHEEL_FILE}"

download_and_verify \
    "${TORCHVISION_SOURCE_URL}" \
    "${TORCHVISION_SOURCE_SHA256}" \
    "${BUILD_DIR}/torchvision-source.tar.gz"
download_and_verify \
    "${TORCHVISION_WHEEL_URL}" \
    "${TORCHVISION_WHEEL_SHA256}" \
    "${BUILD_DIR}/${TORCHVISION_WHEEL_FILE}"

tar -xzf "${BUILD_DIR}/torchvision-source.tar.gz" -C "${BUILD_DIR}"
readonly SOURCE_DIR="${BUILD_DIR}/torchvision-${TORCHVISION_SOURCE_COMMIT}"
readonly GIF_DECODER_SOURCE="${SOURCE_DIR}/torchvision/csrc/io/image/cpu/decode_gif.cpp"

grep -Fq 'memcpy(out.data() + img.pos, source, num_bytes_to_read);' "${GIF_DECODER_SOURCE}"
if grep -Fq 'memcpy(out.data() + img.pos, source, len);' "${GIF_DECODER_SOURCE}"; then
    echo "vulnerable GIF decoder memcpy is still present" >&2
    exit 1
fi

# Only torchvision.image contains the vulnerable GIF decoder. Rebuild that
# extension from the patched source, while retaining the official ROCm wheel's
# GPU-enabled _C extension and the rest of its tested binary payload.
python3 - "${SOURCE_DIR}/setup.py" <<'PY'
from pathlib import Path
import sys

setup = Path(sys.argv[1])
text = setup.read_text()
old = """    extensions = [
        make_C_extension(),
        make_image_extension(),
        *make_video_decoders_extensions(),
    ]"""
new = "    extensions = [make_image_extension()]"
if text.count(old) != 1:
    raise SystemExit("expected torchvision extension list was not found exactly once")
setup.write_text(text.replace(old, new))
PY

(
    cd "${SOURCE_DIR}"
    BUILD_VERSION="${TORCHVISION_VERSION}" \
        FORCE_CUDA=0 \
        TORCHVISION_USE_FFMPEG=0 \
        TORCHVISION_USE_JPEG=1 \
        TORCHVISION_USE_NVJPEG=0 \
        TORCHVISION_USE_PNG=1 \
        TORCHVISION_USE_VIDEO_CODEC=0 \
        TORCHVISION_USE_WEBP=1 \
        python3 setup.py build_ext --inplace
)

python3 -m wheel unpack "${BUILD_DIR}/${TORCHVISION_WHEEL_FILE}" --dest "${BUILD_DIR}/unpacked"
readonly WHEEL_ROOT="${BUILD_DIR}/unpacked/torchvision-0.22.1+rocm6.3"
readonly OLD_DIST_INFO="${WHEEL_ROOT}/torchvision-0.22.1+rocm6.3.dist-info"
readonly NEW_DIST_INFO="${WHEEL_ROOT}/torchvision-${TORCHVISION_VERSION}.dist-info"

test -f "${SOURCE_DIR}/torchvision/image.so"
test -d "${OLD_DIST_INFO}"
install -m 0755 "${SOURCE_DIR}/torchvision/image.so" "${WHEEL_ROOT}/torchvision/image.so"
mv "${OLD_DIST_INFO}" "${NEW_DIST_INFO}"

python3 - \
    "${NEW_DIST_INFO}/METADATA" \
    "${WHEEL_ROOT}/torchvision/version.py" \
    "${TORCHVISION_VERSION}" \
    "${TORCHVISION_SOURCE_COMMIT}" <<'PY'
from pathlib import Path
import re
import sys

metadata = Path(sys.argv[1])
version_file = Path(sys.argv[2])
version = sys.argv[3]
commit = sys.argv[4]

metadata_text, count = re.subn(r"^Version: .+$", f"Version: {version}", metadata.read_text(), count=1, flags=re.M)
if count != 1:
    raise SystemExit("failed to update wheel METADATA version")
metadata.write_text(metadata_text)

version_text, version_count = re.subn(
    r"^__version__ = .+$", f"__version__ = {version!r}", version_file.read_text(), count=1, flags=re.M
)
version_text, commit_count = re.subn(
    r"^git_version = .+$", f"git_version = {commit!r}", version_text, count=1, flags=re.M
)
if version_count != 1 or commit_count != 1:
    raise SystemExit("failed to update torchvision/version.py provenance")
version_file.write_text(version_text)
PY

cat >"${NEW_DIST_INFO}/CVE-2026-65918-PROVENANCE" <<EOF
Source: ${TORCHVISION_SOURCE_URL}
Commit: ${TORCHVISION_SOURCE_COMMIT}
Source-SHA256: ${TORCHVISION_SOURCE_SHA256}
Base-Wheel: ${TORCHVISION_WHEEL_URL}
Base-Wheel-SHA256: ${TORCHVISION_WHEEL_SHA256}
Torch-Version: ${TORCH_VERSION}
EOF

python3 -m wheel pack "${WHEEL_ROOT}" --dest-dir "${OUTPUT_DIR}"
test "$(find "${OUTPUT_DIR}" -maxdepth 1 -name 'torchvision-*.whl' | wc -l)" -eq 1
