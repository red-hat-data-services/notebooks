#!/bin/bash

# Install OS dependencies required for JupyterLab PDF export.
# Uses RHEL/UBI AppStream texlive RPMs plus rhelai texlive-tcolorbox.
# Pandoc comes from the RHOAI public-rhai pandoc-rhai wheel (x86_64, aarch64, ppc64le, s390x).
# Requires AppStream (subscription or c9s); plain unsubscribed UBI lacks these packages
# (see https://github.com/red-hat-data-services/notebooks/issues/2310).
# Backport of main's RPM approach (RHAIENG-2186 / RHAIENG-2345); replaces Utah/CTAN curl.

set -Eeuxo pipefail

_arch="$(uname -m)"

# https://github.com/rh-aiservices-bu/workbench-images/blob/main/snippets/ides/1-jupyter/os/os-packages.txt
# texlive-tcolorbox is not in AppStream; do not use EPEL. Install the rhelai 3.5 noarch RPM.
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
# texlive-tcolorbox rebuild of EPEL package
https://cdn.redhat.com/content/dist/layered/rhel9/x86_64/rhelai/3.5/os/Packages/t/texlive-tcolorbox-20200406-1.el9ai.noarch.rpm
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

if ! dnf install -y "${PACKAGES[@]}"; then
    echo "ERROR: Failed to install texlive/pandoc runtime RPMs." >&2
    echo "AppStream texlive packages require a subscribed RHEL/UBI build or c9s AppStream." >&2
    echo "Unsubscribed UBI-only template builds are tracked in" >&2
    echo "https://github.com/red-hat-data-services/notebooks/issues/2310" >&2
    exit 1
fi

dnf clean all

# Unpack pandoc from the RHOAI wheel onto PATH.
# Index: https://console.redhat.com/api/pypi/public-rhai/rhoai/3.5/cpu-ubi9/simple/pandoc-rhai/
case "${_arch}" in
    x86_64|aarch64|ppc64le|s390x) _pandoc_arch="${_arch}" ;;
    *) echo "ERROR: unsupported arch for pandoc-rhai wheel: ${_arch}" >&2; exit 1 ;;
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
pdflatex --version

texhash

kpsewhich tcolorbox.sty
command -v pandoc
command -v pdflatex
