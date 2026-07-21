# RStudio workbench — local build configuration.
# Sourced by build-local.sh via load_workbench.

WORKBENCH_ID=rstudio
WORKBENCH_DESCRIPTION="RStudio Server (Python 3.11)"
WORKBENCH_VARIANTS="c9s rhel9"

RHEL9_BASE_IMAGE="${RH_REGISTRY}/rhel9/python-311:latest"
C9S_BASE_IMAGE="quay.io/sclorg/python-311-c9s:c9s"

workbench_configure_variant() {
  local variant="$1"
  case "${variant}" in
    c9s)
      VARIANT_PYTHON_VERSION=3.11
      MAKE_TARGET="rstudio-c9s-python-${VARIANT_PYTHON_VERSION}"
      BASE_IMAGE="${C9S_BASE_IMAGE}"
      VOLUME_NAME="rstudio-c9s-home"
      CONTAINER_PORT=8888
      RUN_PATH="/rstudio/"
      NB_PREFIX_NOTEBOOK="my-rstudio"
      NEEDS_SUBSCRIPTION=0
      ;;
    rhel9)
      VARIANT_PYTHON_VERSION=3.11
      MAKE_TARGET="rstudio-rhel9-python-${VARIANT_PYTHON_VERSION}"
      BASE_IMAGE="${RHEL9_BASE_IMAGE}"
      VOLUME_NAME="rstudio-rhel9-home"
      CONTAINER_PORT=8888
      RUN_PATH="/rstudio/"
      NB_PREFIX_NOTEBOOK="my-rstudio"
      NEEDS_SUBSCRIPTION=1
      ;;
  esac
}
