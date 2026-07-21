# Code Server workbench — local build configuration.
# Sourced by build-local.sh via load_workbench.
#
# Status: scaffold only. Enable by implementing workbench_pre_build if needed.

WORKBENCH_ID=codeserver
WORKBENCH_DESCRIPTION="code-server / VS Code in the browser (Python 3.12)"
WORKBENCH_VARIANTS="ubi9"

workbench_configure_variant() {
  local variant="$1"
  case "${variant}" in
    ubi9)
      VARIANT_PYTHON_VERSION=3.12
      MAKE_TARGET="codeserver-ubi9-python-${VARIANT_PYTHON_VERSION}"
      BASE_IMAGE="registry.access.redhat.com/ubi9/python-312:latest"
      VOLUME_NAME="codeserver-ubi9-home"
      CONTAINER_PORT=8787
      RUN_PATH="/"
      NB_PREFIX_NOTEBOOK="my-codeserver"
      # Public UBI pull; set to 1 if your build needs RH entitlements (codeready-builder, etc.)
      NEEDS_SUBSCRIPTION=0
      ;;
  esac
}

workbench_pre_build() {
  die "codeserver local build is not fully validated yet. Copy workbenches/rstudio.sh as a template or remove this hook once tested."
}
