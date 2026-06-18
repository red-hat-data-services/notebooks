# Shared helpers for local workbench image builds.
# Sourced by build-local.sh — do not execute directly.

BUILD_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${BUILD_HELPERS_DIR}/../.." && pwd)}"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-localhost/rhoai-local}"
RELEASE="${RELEASE:-localtest}"
PLATFORM="${PLATFORM:-linux/amd64}"
HOST_PORT="${HOST_PORT:-}"

ENTITLEMENT_DIR="${REPO_ROOT}/entitlement"
CONSUMER_DIR="${REPO_ROOT}/consumer"
RH_REGISTRY="registry.redhat.io"
UBI_IMAGE="registry.access.redhat.com/ubi9/ubi"

WORKBENCH=""
VARIANT=""
CMD=""
MAKE_TARGET=""
BASE_IMAGE=""
VOLUME_NAME=""
CONTAINER_PORT=""
RUN_PATH=""
NB_PREFIX_NOTEBOOK=""
VARIANT_PYTHON_VERSION=""
NEEDS_SUBSCRIPTION=0
IMAGE=""

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_subscription_env() {
  [[ -n "${RH_ORG:-}" ]] || die "Set RH_ORG (Red Hat organization ID)."
  [[ -n "${RH_ACTIVATION_KEY:-}" ]] || die "Set RH_ACTIVATION_KEY."
}

ensure_repo() {
  [[ -f "${REPO_ROOT}/Makefile" ]] || die "REPO_ROOT does not look like the notebooks repo: ${REPO_ROOT}"
  cd "${REPO_ROOT}" || die "Failed to cd to REPO_ROOT: ${REPO_ROOT}"
}

ensure_gmake() {
  if command -v gmake >/dev/null 2>&1; then
    GMAKE=gmake
  elif make --version 2>/dev/null | grep -q GNU; then
    GMAKE=make
  else
    die "GNU make is required (install gmake on macOS)."
  fi
}

ensure_podman() {
  require_cmd podman
  if ! podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
    return 0
  fi
  if podman machine list --format '{{.LastUp}}' 2>/dev/null | grep -q 'Currently running'; then
    return 0
  fi
  log "Starting podman machine..."
  podman machine start
}

list_workbenches() {
  local f id
  for f in "${BUILD_HELPERS_DIR}"/workbenches/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck source=/dev/null
    source "$f"
    id="${WORKBENCH_ID:-unknown}"
    printf '  %-12s %s (variants: %s)\n' "$id" "${WORKBENCH_DESCRIPTION:-}" "${WORKBENCH_VARIANTS:-}"
    unset WORKBENCH_ID WORKBENCH_DESCRIPTION WORKBENCH_VARIANTS
  done
}

load_workbench() {
  local file="${BUILD_HELPERS_DIR}/workbenches/${WORKBENCH}.sh"
  [[ -f "$file" ]] || die "Unknown workbench '${WORKBENCH}'. Run: ${BUILD_LOCAL_SCRIPT:-build-local.sh} --list"
  # shellcheck source=/dev/null
  source "$file"
  [[ -n "${WORKBENCH_ID:-}" ]] || die "Invalid workbench module: ${file}"
}

variant_is_valid() {
  local v="$1" allowed
  for allowed in ${WORKBENCH_VARIANTS}; do
    [[ "$v" == "$allowed" ]] && return 0
  done
  return 1
}

configure_variant() {
  if ! variant_is_valid "${VARIANT}"; then
    die "Unknown variant '${VARIANT}' for workbench '${WORKBENCH}'. Valid: ${WORKBENCH_VARIANTS}"
  fi
  workbench_configure_variant "${VARIANT}"
  [[ -n "${MAKE_TARGET:-}" ]] || die "workbench ${WORKBENCH} did not set MAKE_TARGET for variant ${VARIANT}"
  if [[ -z "${HOST_PORT:-}" ]]; then
    HOST_PORT="${CONTAINER_PORT}"
  fi
}

entitlement_build_args() {
  printf '%s' "-v ${ENTITLEMENT_DIR}:/etc/pki/entitlement:ro -v ${CONSUMER_DIR}:/etc/pki/consumer:ro"
}

require_entitlement_files() {
  [[ -d "${ENTITLEMENT_DIR}" ]] && [[ -n "$(ls -A "${ENTITLEMENT_DIR}" 2>/dev/null)" ]] \
    || die "No entitlements in ${ENTITLEMENT_DIR}. Run: ${BUILD_LOCAL_SCRIPT} ${WORKBENCH} ${VARIANT} setup"
  [[ -d "${CONSUMER_DIR}" ]] && [[ -n "$(ls -A "${CONSUMER_DIR}" 2>/dev/null)" ]] \
    || die "No consumer certs in ${CONSUMER_DIR}. Run: ${BUILD_LOCAL_SCRIPT} ${WORKBENCH} ${VARIANT} setup"
}

ensure_rh_registry_login() {
  log "Checking Red Hat registry login (${RH_REGISTRY})..."
  if ! podman login "${RH_REGISTRY}" --get-login >/dev/null 2>&1; then
    log "Log in to ${RH_REGISTRY} (portal username + password or token):"
    podman login "${RH_REGISTRY}"
  fi
}

pull_base_image() {
  log "Pulling base image ${BASE_IMAGE}..."
  podman pull --platform "${PLATFORM}" "${BASE_IMAGE}" >/dev/null
  log "Base image OK: ${BASE_IMAGE}"
}

register_entitlements() {
  require_subscription_env
  mkdir -p "${ENTITLEMENT_DIR}" "${CONSUMER_DIR}"

  log "Registering Red Hat subscription for org ${RH_ORG}..."
  podman run --platform "${PLATFORM}" \
    -v "${ENTITLEMENT_DIR}:/etc/pki/entitlement:Z" \
    -v "${CONSUMER_DIR}:/etc/pki/consumer:Z" \
    --rm "${UBI_IMAGE}" \
    subscription-manager register \
      --org="${RH_ORG}" \
      --activationkey="${RH_ACTIVATION_KEY}"

  [[ -n "$(ls -A "${ENTITLEMENT_DIR}" 2>/dev/null)" ]] \
    || die "entitlement/ is empty after registration."
  [[ -n "$(ls -A "${CONSUMER_DIR}" 2>/dev/null)" ]] \
    || die "consumer/ is empty after registration."
  log "Entitlement certificates written to ${ENTITLEMENT_DIR} and ${CONSUMER_DIR}"
}

configure_podman_mounts() {
  if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
    log "Configuring podman entitlement mounts in VM (/etc/containers/mounts.conf)..."
    podman machine ssh "sudo mkdir -p /etc/containers && sudo tee /etc/containers/mounts.conf > /dev/null" <<EOF
${ENTITLEMENT_DIR}:/etc/pki/entitlement
${CONSUMER_DIR}:/etc/pki/consumer
EOF
    podman machine ssh 'cat /etc/containers/mounts.conf'
  else
    warn "No podman machine detected; skipping VM mounts.conf (explicit -v mounts still used)."
  fi
}

verify_entitlements() {
  require_entitlement_files
  log "Verifying codeready-builder repo access inside ${BASE_IMAGE}..."
  podman run --platform "${PLATFORM}" --user 0 --rm \
    -v "${ENTITLEMENT_DIR}:/etc/pki/entitlement:ro" \
    -v "${CONSUMER_DIR}:/etc/pki/consumer:ro" \
    "${BASE_IMAGE}" \
    bash -c 'subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms && dnf repolist | grep -i codeready'
  log "Entitlement verification passed."
}

run_workbench_hook() {
  local hook="$1"
  if declare -F "workbench_${hook}" >/dev/null 2>&1; then
    "workbench_${hook}"
  fi
}

setup_variant() {
  log "Workbench: ${WORKBENCH} | variant: ${VARIANT} | target: ${MAKE_TARGET}"
  run_workbench_hook pre_setup
  if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
    ensure_rh_registry_login
    register_entitlements
    configure_podman_mounts
    pull_base_image
  else
    pull_base_image
    log "No subscription required for this variant."
  fi
  run_workbench_hook post_setup
}

verify_variant() {
  log "Workbench: ${WORKBENCH} | variant: ${VARIANT} | target: ${MAKE_TARGET}"
  run_workbench_hook pre_verify
  if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
    ensure_rh_registry_login
    configure_podman_mounts
    verify_entitlements
  else
    pull_base_image
    log "Prerequisites OK."
  fi
  run_workbench_hook post_verify
}

build_image() {
  ensure_repo
  ensure_gmake
  ensure_podman
  run_workbench_hook pre_build

  if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
    verify_entitlements
  fi

  local -a gmake_extra=()
  if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
    gmake_extra=(-e CONTAINER_BUILD_CACHE_ARGS="$(entitlement_build_args)")
  else
    gmake_extra=(-e CONTAINER_BUILD_CACHE_ARGS="")
  fi

  log "Building ${MAKE_TARGET} (platform=${PLATFORM}, this may take 30-60+ min on Apple Silicon)..."
  "${GMAKE}" "${MAKE_TARGET}" \
    -e RELEASE_PYTHON_VERSION="${VARIANT_PYTHON_VERSION}" \
    -e IMAGE_REGISTRY="${IMAGE_REGISTRY}" \
    -e RELEASE="${RELEASE}" \
    -e PUSH_IMAGES=no \
    "${gmake_extra[@]}"

  resolve_image
  log "Build complete: ${IMAGE}"
  run_workbench_hook post_build
}

resolve_image() {
  if [[ -n "${IMAGE:-}" ]]; then
    if podman image exists "${IMAGE}" >/dev/null 2>&1; then
      return 0
    fi
    die "IMAGE is set but not found locally: ${IMAGE}"
  fi

  IMAGE="$(podman images --format '{{.Repository}}:{{.Tag}}' \
    | grep "^${IMAGE_REGISTRY}:${MAKE_TARGET}-${RELEASE}_" \
    | head -1 || true)"

  if [[ -z "${IMAGE:-}" ]]; then
    # Fall back: any local tag for this make target (e.g. different IMAGE_REGISTRY/RELEASE)
    IMAGE="$(podman images --format '{{.Repository}}:{{.Tag}}' \
      | grep ":${MAKE_TARGET}-" \
      | head -1 || true)"
  fi

  if [[ -z "${IMAGE:-}" ]]; then
    die "Could not find built image for ${MAKE_TARGET}.\
 Try: IMAGE_REGISTRY=... RELEASE=... $0 ${WORKBENCH} ${VARIANT} run\
 Or: IMAGE=<repo:tag> $0 ${WORKBENCH} ${VARIANT} run\
 Available images matching '${MAKE_TARGET}':\
$(podman images --format '  {{.Repository}}:{{.Tag}}' | grep "${MAKE_TARGET}" || echo '  (none)')"
  fi

  log "Using image: ${IMAGE}"
}

run_container() {
  local nb_prefix="${1:-}"
  [[ -n "${IMAGE:-}" ]] || resolve_image

  local -a env_args=()
  local url_path="${RUN_PATH}"
  if [[ -n "${nb_prefix}" ]]; then
    env_args+=(-e "NB_PREFIX=${nb_prefix}")
    env_args+=(-e 'NOTEBOOK_ARGS={"hub_host":"https://jupyterhub.example.com/user/testuser"}')
    log "Running ${WORKBENCH}/${VARIANT} with NB_PREFIX=${nb_prefix}"
    log "Try: http://localhost:${HOST_PORT}${nb_prefix}${url_path}"
  else
    log "Running ${WORKBENCH}/${VARIANT} without NB_PREFIX"
    log "Open: http://localhost:${HOST_PORT}${url_path}"
  fi

  podman run -it --rm \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    -v "${VOLUME_NAME}:/opt/app-root/src" \
    "${env_args[@]}" \
    "${IMAGE}"
}

cleanup_variant() {
  if [[ "${NEEDS_SUBSCRIPTION}" == "1" ]]; then
    log "Unregistering subscription and removing local entitlement files..."
    if [[ -d "${ENTITLEMENT_DIR}" ]] && [[ -n "$(ls -A "${ENTITLEMENT_DIR}" 2>/dev/null)" ]]; then
      podman run --platform "${PLATFORM}" \
        -v "${ENTITLEMENT_DIR}:/etc/pki/entitlement:Z" \
        -v "${CONSUMER_DIR}:/etc/pki/consumer:Z" \
        --rm "${UBI_IMAGE}" \
        subscription-manager unregister || true
    fi
    rm -rf "${ENTITLEMENT_DIR}" "${CONSUMER_DIR}"
    if podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
      podman machine ssh 'sudo rm -f /etc/containers/mounts.conf' >/dev/null 2>&1 || true
    fi
  else
    log "This variant does not use local subscription artifacts — nothing to clean up."
  fi
  log "Cleanup done."
}
