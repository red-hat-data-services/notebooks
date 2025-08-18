#!/bin/bash

# Install dependencies required for Notebooks PDF exports

set -euxo pipefail

dnf install -y \
  pandoc \
  texlive-adjustbox \
  texlive-bibtex \
  texlive-charter \
  texlive-ec \
  texlive-euro \
  texlive-eurosym \
  texlive-fpl \
  texlive-jknapltx \
  texlive-knuth-local \
  texlive-lm-math \
  texlive-marvosym \
  texlive-mathpazo \
  texlive-mflogo-font \
  texlive-parskip \
  texlive-plain \
  texlive-pxfonts \
  texlive-rsfs \
  texlive-tcolorbox \
  texlive-times \
  texlive-titling \
  texlive-txfonts \
  texlive-ulem \
  texlive-upquote \
  texlive-utopia \
  texlive-wasy \
  texlive-wasy-type1 \
  texlive-wasysym \
  texlive-xetex

dnf clean all
