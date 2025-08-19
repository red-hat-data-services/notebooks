#!/bin/bash
set -euxo pipefail

# Mapping of `uname -m` values to equivalent GOARCH values
declare -A UNAME_TO_GOARCH
UNAME_TO_GOARCH["x86_64"]="amd64"
UNAME_TO_GOARCH["aarch64"]="arm64"
UNAME_TO_GOARCH["ppc64le"]="ppc64le"
UNAME_TO_GOARCH["s390x"]="s390x"

ARCH="${UNAME_TO_GOARCH[$(uname -m)]}"

if [[ "$ARCH" == "ppc64le" ]]; then
  # Install Pandoc from source
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  dnf install -y cabal-install ghc gmp-devel gcc-toolset-13 git jq
  
  source /opt/rh/gcc-toolset-13/enable
  
  # ghc-8.10 has specific path for gcc in settings
  sed -i.bak 's|/usr/bin/gcc|gcc|g' /usr/lib64/ghc-8.10.7/settings
  
  cabal user-config init

  sed -i -e 's/http/https/g' -e 's/-- secure: True/secure: True/g' $HOME/.cabal/config
  
  cabal update
  cabal install cabal-install --verbose
  
  # use latest cabal
  export PATH=/root/.cabal/bin:$PATH

  PANDOC_VERSION=$(curl -s "https://api.github.com/repos/jgm/pandoc/releases/latest" | jq -r '.tag_name')

  cd /tmp
  git clone --recurse-submodules https://github.com/jgm/pandoc.git
  cd pandoc
  git checkout ${PANDOC_VERSION}
  git submodule update --init --recursive

  # Modify config
  sed -i -e 's/http/https/g' -e 's/-- secure: True/secure: True/g' $HOME/.cabal/config

  cabal update -v
  cd pandoc-cli
  cabal build -j"$(nproc)" --verbose
  mkdir -p /usr/local/pandoc/bin
  cabal install \
    --installdir=/usr/local/pandoc/bin \
    --overwrite-policy=always \
    --install-method=copy

  # Clean up Haskell build system
  rm -rf ~/.cabal ~/.ghc /tmp/pandoc
  dnf remove -y cabal-install ghc gmp-devel
  dnf clean all && rm -rf /var/cache/dnf

  /usr/local/pandoc/bin/pandoc --version

elif [[ "$ARCH" == "amd64" ]]; then
  # pandoc installation
  curl -fL "https://github.com/jgm/pandoc/releases/download/3.7.0.2/pandoc-3.7.0.2-linux-${ARCH}.tar.gz"  -o /tmp/pandoc.tar.gz
  mkdir -p /usr/local/pandoc
  tar xvzf /tmp/pandoc.tar.gz --strip-components 1 -C /usr/local/pandoc/
  rm -f /tmp/pandoc.tar.gz

else
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
fi
