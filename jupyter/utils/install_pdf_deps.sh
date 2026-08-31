#!/bin/bash

# Install dependencies required for Notebooks PDF exports

set -Eeuxo pipefail

# Mapping of `uname -m` values to equivalent GOARCH values
declare -A UNAME_TO_GOARCH
UNAME_TO_GOARCH["x86_64"]="amd64"
UNAME_TO_GOARCH["aarch64"]="arm64"
UNAME_TO_GOARCH["ppc64le"]="ppc64le"
UNAME_TO_GOARCH["s390x"]="s390x"

ARCH="${UNAME_TO_GOARCH[$(uname -m)]}"
if [[ -z "${ARCH:-}" ]]; then
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
fi

# Skip PDF export installation for s390x (no pandoc/texlive support)
if [[ "$(uname -m)" == "s390x" ]]; then
    echo "PDF export functionality is not supported on s390x architecture. Skipping installation."
    exit 0
fi

enable_rhelai_texlive_repo() {
    local basearch
    basearch="$(uname -m)"
    # Layered-product repo for texlive-tcolorbox (RHAIENG-4114 / AIPCC-7791).
    if command -v subscription-manager &>/dev/null; then
        subscription-manager repos --enable "rhelai-3.3-for-rhel-9-${basearch}-rpms" 2>/dev/null || true
    fi
    dnf config-manager --set-enabled "rhelai-3.3-for-rhel-9-${basearch}-rpms" 2>/dev/null || true
}

# https://github.com/rh-aiservices-bu/workbench-images/blob/main/snippets/ides/1-jupyter/os/os-packages.txt
PACKAGES=(
texlive-adjustbox
texlive-bibtex
texlive-charter
texlive-ec
texlive-euro
texlive-eurosym
texlive-fpl
texlive-jknapltx
texlive-knuth-local
texlive-lm-math
texlive-marvosym
texlive-mathpazo
texlive-mflogo-font
texlive-parskip
texlive-plain
texlive-pxfonts
texlive-rsfs
texlive-times
texlive-titling
texlive-txfonts
texlive-ulem
texlive-upquote
texlive-utopia
texlive-wasy
texlive-wasy-type1
texlive-wasysym
texlive-xetex
# dependencies of texlive-tcolorbox
texlive-environ
texlive-trimspaces
)

dnf install -y "${PACKAGES[@]}"

enable_rhelai_texlive_repo
if ! dnf install -y texlive-tcolorbox; then
    echo "ERROR: Failed to install texlive-tcolorbox from rhelai-3.3-for-rhel-9-$(uname -m)-rpms." >&2
    echo "AppStream texlive packages require a subscribed RHEL/AIPCC build or c9s AppStream." >&2
    echo "Unsubscribed UBI-only template builds are tracked in" >&2
    echo "https://github.com/red-hat-data-services/notebooks/issues/2310" >&2
    exit 1
fi

dnf clean all

pdflatex --version
texhash
kpsewhich tcolorbox.sty

# pandoc installation
# https://github.com/jgm/pandoc/releases/3.7.0.2
# alternative installation method (EPEL, currently pandoc-2.14.0.3-17):
#   dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
#   dnf install -y pandoc
#   mkdir -p /usr/local/pandoc/bin
#   ln -s /usr/bin/pandoc /usr/local/pandoc/bin/pandoc
#   export PATH="/usr/local/pandoc/bin:$PATH"
#   pandoc --version
# github installation method (newer version, but missing ppc64le):
#   curl -fL "https://github.com/jgm/pandoc/releases/download/3.7.0.2/pandoc-3.7.0.2-linux-${ARCH}.tar.gz"  -o /tmp/pandoc.tar.gz
#   mkdir -p /usr/local/pandoc
#   tar xvzf /tmp/pandoc.tar.gz --strip-components 1 -C /usr/local/pandoc/
#   rm -f /tmp/pandoc.tar.gz

if [[ "$ARCH" == "ppc64le" ]]; then
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  dnf install -y pandoc
  mkdir -p /usr/local/pandoc/bin
  ln -s /usr/bin/pandoc /usr/local/pandoc/bin/pandoc
  export PATH="/usr/local/pandoc/bin:$PATH"
  pandoc --version
else
  curl -fL "https://github.com/jgm/pandoc/releases/download/3.7.0.2/pandoc-3.7.0.2-linux-${ARCH}.tar.gz"  -o /tmp/pandoc.tar.gz
  mkdir -p /usr/local/pandoc
  tar xvzf /tmp/pandoc.tar.gz --strip-components 1 -C /usr/local/pandoc/
  rm -f /tmp/pandoc.tar.gz
fi

# clean up /tmp
rm -rf /tmp/* /tmp/.[!.]*
