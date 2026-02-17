#!/bin/bash

# Shared install script with retry logic for dnf, texlive (install_pdf_deps), and npm.
# Usage:
#   ./install_with_retry.sh dnf-install <package> [package ...]
#   ./install_with_retry.sh texlive-install
#   ./install_with_retry.sh npm-install

set -Eeuxo pipefail

readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly RETRY_DELAY="${RETRY_DELAY:-30}"

# Runs a command with retry logic.
# Optional: set CLEANUP_CMD to a shell command (e.g. "dnf clean metadata") to run between retries.
# Returns 0 on success, exits 1 after MAX_RETRIES failures.
run_with_retry() {
    local retry_count=0
    while true; do
        if "$@"; then
            return 0
        fi
        retry_count=$((retry_count + 1))
        if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
            echo "ERROR: Command failed after $MAX_RETRIES attempts" >&2
            exit 1
        fi
        echo "Command failed (attempt $retry_count/$MAX_RETRIES), retrying in ${RETRY_DELAY} seconds..."
        if [ -n "${CLEANUP_CMD:-}" ]; then
            $CLEANUP_CMD || true
        fi
        sleep "$RETRY_DELAY"
    done
}

dnf_install() {
    local packages=("$@")
    if [ ${#packages[@]} -eq 0 ]; then
        echo "Usage: $0 dnf-install <package> [package ...]" >&2
        exit 1
    fi
    CLEANUP_CMD="dnf clean metadata" run_with_retry dnf install -y ${DNF_EXTRA_OPTS:-} "${packages[@]}"
    dnf clean all
    rm -rf /var/cache/yum
}

texlive_install() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    CLEANUP_CMD= run_with_retry "$script_dir/install_pdf_deps.sh"
}

npm_install() {
    CLEANUP_CMD="rm -rf node_modules" run_with_retry npm install
}

main() {
    case "${1:-}" in
        dnf-install)
            shift
            dnf_install "$@"
            ;;
        texlive-install)
            texlive_install
            ;;
        npm-install)
            npm_install
            ;;
        *)
            echo "Usage: $0 {dnf-install|texlive-install|npm-install} [args...]" >&2
            echo "  dnf-install <package> [package ...]  Install RPM packages with retry" >&2
            echo "  texlive-install                       Run install_pdf_deps.sh with retry" >&2
            echo "  npm-install                           Run npm install with retry" >&2
            exit 1
            ;;
    esac
}

# Only run main when this script is executed directly (not when sourced by run-code-server.sh)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
