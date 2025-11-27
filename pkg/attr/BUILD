#!/usr/bin/env bash
set -euo pipefail

# BUILD helper for attr package
# Usage: BUILD WORKDIR SOURCE_OR_URL RELEASE_TAG

WORKDIR="${1:-/tmp/paranbuild}"
SRC_ARG="${2:-2.5.2}"
RELEASE_VERSION="${3:-v0.0.1}"

INSTALL_DIR="$WORKDIR/attr-install"
RELEASE_DIR="$WORKDIR/release"

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_FILES_DIR="$PKG_DIR/files"

echo "BUILD: workdir=$WORKDIR src=$SRC_ARG release=$RELEASE_VERSION"

mkdir -p "$WORKDIR" "$INSTALL_DIR" "$RELEASE_DIR"

cd "$WORKDIR"
if echo "$SRC_ARG" | grep -Eq '^https?://'; then
  SRC_URL="$SRC_ARG"
  SRC_TARBALL="$(basename "$SRC_URL")"
  if [ ! -f "$SRC_TARBALL" ]; then
    echo "Downloading source: $SRC_URL"
    wget "$SRC_URL"
  fi
  echo "Extracting $SRC_TARBALL"
  tar -xf "$SRC_TARBALL"
  SRC_DIR="$(ls -d attr-* 2>/dev/null | head -n1)"
  if [ -z "$SRC_DIR" ]; then
    echo "Could not find extracted attr source dir" >&2
    exit 2
  fi
else
  ATTR_VERSION="$SRC_ARG"
  SRC_TARBALL="attr-${ATTR_VERSION}.tar.gz"
  SRC_DIR="attr-${ATTR_VERSION}"
  # Prefer already-present tarball under /sources (legacy dev layout)
  if [ -f "/sources/${SRC_TARBALL}" ]; then
    echo "Using existing /sources/${SRC_TARBALL}"
    cp "/sources/${SRC_TARBALL}" .
  fi
  if [ ! -d "$SRC_DIR" ]; then
    if [ ! -f "$SRC_TARBALL" ]; then
      echo "Downloading attr source: $SRC_TARBALL"
      wget "https://download.savannah.gnu.org/releases/attr/$SRC_TARBALL"
    fi
    echo "Extracting $SRC_TARBALL"
    tar -xf "$SRC_TARBALL"
  fi
fi

cd "$SRC_DIR"
echo "Configuring..."
# Match configure flags from original temp script: set sysconfdir and docdir with versioned name
./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/${SRC_DIR}
echo "Building..."
make -j"$(nproc)"
echo "Installing into staged DESTDIR=$INSTALL_DIR"
make install DESTDIR="$INSTALL_DIR"

echo "Preparing package files directory: $TARGET_FILES_DIR"
rm -rf "$TARGET_FILES_DIR"
mkdir -p "$TARGET_FILES_DIR"

if [ -d "$INSTALL_DIR/usr" ]; then
  cp -a "$INSTALL_DIR/usr" "$TARGET_FILES_DIR/"
  echo "Copied staged usr/ to $TARGET_FILES_DIR/usr"
else
  echo "Error: staged /usr not found in $INSTALL_DIR" >&2
  exit 3
fi

echo "BUILD complete"
exit 0
