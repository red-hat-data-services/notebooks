#!/bin/bash

# Install OS dependencies required for JupyterLab PDF export.
# Uses RHEL/UBI AppStream texlive RPMs plus tcolorbox 4.42 (TeX Live 2020 vintage).
# Pandoc is installed later via uv pip from pylock.toml (pandoc-rhai, RH public-rhai index).
# Requires AppStream (subscription or c9s); plain unsubscribed UBI lacks these packages
# (see https://github.com/red-hat-data-services/notebooks/issues/2310).
# AppStream texlive RPMs (RHAIENG-2186 / RHAIENG-2345); tcolorbox 4.42, not current CTAN/EPEL/CDN.

set -Eeuxo pipefail

# https://github.com/rh-aiservices-bu/workbench-images/blob/main/snippets/ides/1-jupyter/os/os-packages.txt
# texlive-tcolorbox is not in AppStream; do not use EPEL or the rhelai CDN RPM.
# Current CTAN tcolorbox 6.x needs tikz 2023 / \NewStructureName; pin 4.42 for TeX Live 2020.
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

if ! dnf install -y "${PACKAGES[@]}"; then
    echo "ERROR: Failed to install texlive/pandoc runtime RPMs." >&2
    echo "AppStream texlive packages require a subscribed RHEL/UBI build or c9s AppStream." >&2
    echo "Unsubscribed UBI-only template builds are tracked in" >&2
    echo "https://github.com/red-hat-data-services/notebooks/issues/2310" >&2
    exit 1
fi

dnf clean all

# tcolorbox is not in AppStream. Unpack tcolorbox 4.42 (TeX Live 2020 vintage) into TEXMFLOCAL.
# Current CTAN 6.x fails on RHEL 9 XeTeX (\NewStructureName / tikz 2023).
# https://github.com/T-F-S/tcolorbox/releases/tag/v4.42
_tcolorbox_tgz=/tmp/tcolorbox-4.42.tar.gz
curl --fail --location --show-error \
    -o "${_tcolorbox_tgz}" \
    "https://github.com/T-F-S/tcolorbox/archive/refs/tags/v4.42.tar.gz"
_texmf_local="$(kpsewhich -var-value TEXMFLOCAL)"
mkdir -p "${_texmf_local}"
python - "${_texmf_local}" <<'PY'
import pathlib
import sys
import tarfile

dest = pathlib.Path(sys.argv[1]) / "tex" / "latex" / "tcolorbox"
dest.mkdir(parents=True, exist_ok=True)
with tarfile.open("/tmp/tcolorbox-4.42.tar.gz", "r:gz") as tf:
    for member in tf.getmembers():
        name = pathlib.PurePosixPath(member.name)
        if not member.isfile() or name.suffix not in {".sty", ".tex", ".def", ".code"}:
            continue
        if name.suffix == ".tex" and not str(name).endswith(".code.tex"):
            continue
        target = dest / name.name
        src = tf.extractfile(member)
        if src is None:
            continue
        target.write_bytes(src.read())
PY
rm -f "${_tcolorbox_tgz}"

pdflatex --version

texhash

kpsewhich tcolorbox.sty
command -v pdflatex
