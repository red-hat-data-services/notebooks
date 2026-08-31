#!/bin/bash
set -Eeuxo pipefail

# texlive-tcolorbox is in the RHOAI 3.3 layered-product repo (not AppStream/EPEL).
# See RHAIENG-4114 and scripts/lockfile-generators/Dockerfile.rpm-lockfile.
_basearch="$(uname -m)"
dnf config-manager --set-enabled "rhelai-3.3-for-rhel-9-${_basearch}-rpms" 2>/dev/null || true

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
texlive-tcolorbox
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
dnf clean all

pdflatex --version
texhash
kpsewhich tcolorbox.sty
