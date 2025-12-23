#!/usr/bin/env bash
set -euo pipefail

# BUILD helper for autoconf package
# Usage: BUILD WORKDIR SOURCE_OR_URL RELEASE_TAG

WORKDIR="${1:-/tmp/paranbuild}"
SRC_ARG="${2:-2.71}"
RELEASE_VERSION="${3:-v0.0.1}"

INSTALL_DIR="$WORKDIR/autoconf-install"
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
  SRC_DIR="$(ls -d autoconf-* 2>/dev/null | head -n1)"
  if [ -z "$SRC_DIR" ]; then
    echo "Could not find extracted autoconf source dir" >&2
    exit 2
  fi
else
  AC_VERSION="$SRC_ARG"
  SRC_TARBALL="autoconf-${AC_VERSION}.tar.gz"
  SRC_DIR="autoconf-${AC_VERSION}"
  # Prefer already-present tarball under /sources (legacy dev layout)
  if [ -f "/sources/${SRC_TARBALL}" ]; then
    echo "Using existing /sources/${SRC_TARBALL}"
    cp "/sources/${SRC_TARBALL}" .
  fi
  if [ ! -d "$SRC_DIR" ]; then
    if [ ! -f "$SRC_TARBALL" ]; then
      echo "Downloading autoconf source: $SRC_TARBALL"
      wget "https://ftp.gnu.org/gnu/autoconf/$SRC_TARBALL"
    fi
    echo "Extracting $SRC_TARBALL"
    tar -xf "$SRC_TARBALL"
  fi
fi

cd "$SRC_DIR"
echo "Configuring..."
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/${SRC_DIR}
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
