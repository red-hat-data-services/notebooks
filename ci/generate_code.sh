#!/usr/bin/env bash
set -Eeuxo pipefail

uv --version || pip install "uv>=0.9,<0.12"

uv run scripts/dockerfile_fragments.py
PYLOCKS_CI_CHECK=1 uv run scripts/pylocks_generator.py public-index
