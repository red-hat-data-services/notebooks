#!/usr/bin/env bash
#
# Build and run workbench images locally (podman + gmake).
#
# Usage:
#   ./scripts/build-helpers/build-local.sh <workbench> <variant> <command>
#   ./scripts/build-helpers/build-local.sh --list
#   ./scripts/build-helpers/build-local.sh --help
#
# See scripts/build-helpers/README.md for full documentation.

set -Eeuo pipefail

BUILD_LOCAL_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-local.sh"
export BUILD_LOCAL_SCRIPT

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <workbench> <variant> <command>
  $(basename "$0") --list
  $(basename "$0") --help

Commands:
  setup         Prepare build environment (subscription for variants that need it)
  verify        Verify prerequisites
  build         Run gmake for the selected image
  run           Run the built container locally
  run-nbprefix  Run with NB_PREFIX (ingress routing smoke test)
  all           setup + verify + build
  cleanup       Remove local subscription artifacts

Environment:
  RH_ORG, RH_ACTIVATION_KEY   Required for subscription-backed variants (e.g. rstudio rhel9)
  IMAGE_REGISTRY                Default: ${IMAGE_REGISTRY}
  RELEASE                       Default: ${RELEASE}
  HOST_PORT                     Default: workbench container port
  REPO_ROOT                     Default: repo root (auto-detected)

Examples:
  $(basename "$0") rstudio c9s build
  $(basename "$0") rstudio rhel9 all
  $(basename "$0") rstudio c9s run-nbprefix

Registered workbenches:
EOF
  list_workbenches
}

parse_args() {
  local -a positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        list_workbenches
        exit 0
        ;;
      -h|--help|help)
        CMD=help
        return 0
        ;;
      -w|--workbench)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        WORKBENCH="$2"
        shift 2
        ;;
      -v|--variant)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        VARIANT="$2"
        shift 2
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#positional[@]} -ge 1 && -z "${WORKBENCH}" ]]; then
    WORKBENCH="${positional[0]}"
    positional=("${positional[@]:1}")
  fi
  if [[ ${#positional[@]} -ge 1 && -z "${VARIANT}" ]]; then
    VARIANT="${positional[0]}"
    positional=("${positional[@]:1}")
  fi
  if [[ ${#positional[@]} -ge 1 ]]; then
    CMD="${positional[0]}"
  fi

  if [[ -z "${WORKBENCH}" || -z "${VARIANT}" ]]; then
    die "Usage: $(basename "$0") <workbench> <variant> <command>   (try --list)"
  fi

  load_workbench
  configure_variant
}

main() {
  parse_args "$@"

  if [[ "${CMD:-}" == "help" ]]; then
    usage
    return 0
  fi

  [[ -n "${CMD:-}" ]] || { usage; exit 1; }

  ensure_podman

  case "${CMD}" in
    setup)
      setup_variant
      ;;
    verify)
      verify_variant
      ;;
    build)
      if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
        ensure_rh_registry_login
      fi
      build_image
      ;;
    run)
      run_container
      ;;
    run-nbprefix)
      run_container "/user/testuser/notebooks/${NB_PREFIX_NOTEBOOK}"
      ;;
    all)
      if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
        ensure_rh_registry_login
      fi
      setup_variant
      verify_variant
      build_image
      log "Next: ${BUILD_LOCAL_SCRIPT} ${WORKBENCH} ${VARIANT} run"
      log "  or: ${BUILD_LOCAL_SCRIPT} ${WORKBENCH} ${VARIANT} run-nbprefix"
      ;;
    cleanup)
      cleanup_variant
      ;;
    *)
      die "Unknown command: ${CMD}. Run: $(basename "$0") --help"
      ;;
  esac
}

main "$@"
