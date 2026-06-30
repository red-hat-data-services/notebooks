#!/usr/bin/env bash
set -Eeuxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

uv --version || pip install "uv==0.8.12"

"${REPO_ROOT}/uv" run scripts/dockerfile_fragments.py
"${REPO_ROOT}/uv" run manifests/tools/generate_kustomization.py
# pylocks_generator fails for trustyai/rocm-tensorflow on rhoai-2.25 (dependency
# resolution vs onnx CVE constraints) and would rewrite unrelated pylock.toml files.
