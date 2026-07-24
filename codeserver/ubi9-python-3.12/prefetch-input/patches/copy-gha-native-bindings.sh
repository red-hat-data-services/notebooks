#!/bin/bash
# GHA-only: copy native .node files built in lib/vscode during postinstall into
# release-standalone. vscode-reh-web output (rsync'd by release:standalone) does not
# include those bindings; npm rebuild there is a no-op on trimmed packages.
set -Eeuxo pipefail

. "${CODESERVER_SOURCE_CODE}/patches/codeserver-offline-env.sh"

src_root="${CODESERVER_SOURCE_PREFETCH}"
dst_root="${src_root}/release-standalone"

copy_native_artifacts() {
    local src_pkg="$1"
    local dst_pkg="$2"
    local label="$3"
    local required="${4:-true}"

    if [[ ! -d "${src_pkg}" ]]; then
        if [[ "${required}" == "true" ]]; then
            echo "ERROR: ${label} source not found at ${src_pkg}" >&2
            return 1
        fi
        echo "WARNING: ${label} source not found at ${src_pkg}, skipping"
        return 0
    fi
    if [[ ! -d "${dst_pkg}" ]]; then
        if [[ "${required}" == "true" ]]; then
            echo "ERROR: ${label} destination not found at ${dst_pkg}" >&2
            return 1
        fi
        echo "WARNING: ${label} destination not found at ${dst_pkg}, skipping"
        return 0
    fi

    local copied=false
    for subdir in build prebuilds compiled; do
        if [[ -d "${src_pkg}/${subdir}" ]]; then
            mkdir -p "${dst_pkg}/${subdir}"
            rsync -a "${src_pkg}/${subdir}/" "${dst_pkg}/${subdir}/"
            copied=true
        fi
    done

    if [[ "${copied}" != "true" ]]; then
        if [[ "${required}" == "true" ]]; then
            echo "ERROR: no native artifacts found under ${src_pkg} for ${label}" >&2
            return 1
        fi
        echo "WARNING: no native artifacts found under ${src_pkg} for ${label}, skipping"
        return 0
    fi
    echo "Copied native artifacts for ${label} into ${dst_pkg}"
}

echo "Copying GHA native bindings from lib/vscode build tree into release-standalone"

copy_native_artifacts \
    "${src_root}/lib/vscode/node_modules/@vscode/spdlog" \
    "${dst_root}/lib/vscode/node_modules/@vscode/spdlog" \
    "@vscode/spdlog"

copy_native_artifacts \
    "${src_root}/lib/vscode/node_modules/@vscode/native-watchdog" \
    "${dst_root}/lib/vscode/node_modules/@vscode/native-watchdog" \
    "@vscode/native-watchdog"

# node-pty is built under lib/vscode/remote during postinstall; runtime loads it from
# release-standalone/lib/vscode/node_modules/node-pty after npm install merges remote deps.
copy_native_artifacts \
    "${src_root}/lib/vscode/remote/node_modules/node-pty" \
    "${dst_root}/lib/vscode/node_modules/node-pty" \
    "node-pty" \
    "false"

# @vscode/ripgrep postinstall writes bin/rg under lib/vscode; release:standalone drops it.
ripgrep_src="${src_root}/lib/vscode/node_modules/@vscode/ripgrep"
ripgrep_dst="${dst_root}/lib/vscode/node_modules/@vscode/ripgrep"
if [[ -d "${ripgrep_src}/bin" && -d "${ripgrep_dst}" ]]; then
    mkdir -p "${ripgrep_dst}/bin"
    rsync -a "${ripgrep_src}/bin/" "${ripgrep_dst}/bin/"
    echo "Copied @vscode/ripgrep bin/ into ${ripgrep_dst}"
elif [[ -x "${RIPGREP_BINARY_PATH:-}" && -d "${ripgrep_dst}" ]]; then
    mkdir -p "${ripgrep_dst}/bin"
    cp -f "${RIPGREP_BINARY_PATH}" "${ripgrep_dst}/bin/rg"
    chmod 755 "${ripgrep_dst}/bin/rg"
    echo "Copied RIPGREP_BINARY_PATH into ${ripgrep_dst}/bin/rg"
else
    echo "ERROR: @vscode/ripgrep bin/rg missing (src=${ripgrep_src}/bin RIPGREP_BINARY_PATH=${RIPGREP_BINARY_PATH:-})" >&2
    exit 1
fi

spdlog_dst="${dst_root}/lib/vscode/node_modules/@vscode/spdlog"
if [[ -f "${spdlog_dst}/build/Release/spdlog.node" && ! -e "${spdlog_dst}/build/spdlog.node" ]]; then
    ln -sf Release/spdlog.node "${spdlog_dst}/build/spdlog.node"
fi

if ! find "${spdlog_dst}" -name 'spdlog.node' -print -quit | grep -q .; then
    echo "ERROR: spdlog.node not found under ${spdlog_dst} after copy" >&2
    exit 1
fi

watchdog_dst="${dst_root}/lib/vscode/node_modules/@vscode/native-watchdog"
if [[ ! -e "${watchdog_dst}/build/Release/watchdog" && ! -e "${watchdog_dst}/build/Release/watchdog.node" ]]; then
    echo "ERROR: native-watchdog binary not found under ${watchdog_dst} after copy" >&2
    exit 1
fi

if [[ ! -x "${ripgrep_dst}/bin/rg" ]]; then
    echo "ERROR: ${ripgrep_dst}/bin/rg missing or not executable after copy" >&2
    exit 1
fi

echo "Verified spdlog.node, native-watchdog, and ripgrep bin/rg under release-standalone"
