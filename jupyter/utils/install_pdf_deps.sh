#!/bin/bash

# Install OS dependencies required for JupyterLab PDF export.
# Uses RHEL/UBI AppStream texlive RPMs plus the RHOAI 3.3 texlive-tcolorbox
# package and the RHOAI public-rhai pandoc-rhai wheel.

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
# runtime deps of the pandoc-rhai binary
gmp
libffi
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

# Unpack pandoc from the RHOAI wheel onto PATH.
# Index: https://console.redhat.com/api/pypi/public-rhai/rhoai/3.5/cpu-ubi9/simple/pandoc-rhai/
case "$(uname -m)" in
    x86_64|aarch64|ppc64le) _pandoc_arch="$(uname -m)" ;;
    *) echo "ERROR: unsupported arch for pandoc-rhai wheel: $(uname -m)" >&2; exit 1 ;;
esac

_pandoc_whl=/tmp/pandoc_rhai.whl
curl --fail --location --show-error \
    -o "${_pandoc_whl}" \
    "https://packages.redhat.com/api/pulp-content/public-rhai/rhoai/3.5/cpu-ubi9/pandoc_rhai-3.9.0.2-4-py3-none-linux_${_pandoc_arch}.whl"

python - <<'PY'
import pathlib
import zipfile

whl = pathlib.Path("/tmp/pandoc_rhai.whl")
dest = pathlib.Path("/usr/local/bin/pandoc")
with zipfile.ZipFile(whl) as zf:
    names = [name for name in zf.namelist() if name.endswith("/data/bin/pandoc")]
    if len(names) != 1:
        raise SystemExit(f"expected one pandoc binary in wheel, found {names!r}")
    dest.write_bytes(zf.read(names[0]))
dest.chmod(0o755)
PY
rm -f "${_pandoc_whl}"

pandoc --version

# clean up /tmp
rm -rf /tmp/* /tmp/.[!.]*
