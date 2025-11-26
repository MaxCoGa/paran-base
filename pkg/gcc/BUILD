#!/usr/bin/env bash
set -euo pipefail

# BUILD: build and stage GCC for the paranpackage
#
# Usage:
#   ./BUILD [workdir] [gcc_version] [release_version]
#
# Defaults:
#   workdir=/tmp/paranbuild
#   gcc_version=14.1.0
#   release_version=v0.0.1
#
# This script downloads GCC sources, runs contrib/download_prerequisites,
# configures and builds GCC, runs `make install DESTDIR=$INSTALL_DIR` to
# produce a staged `/usr` tree, then copies that `usr/` tree into
# `pkg/gcc/files/usr/` so the paranpackage contains the prebuilt layout.

WORKDIR="${1:-/tmp/paranbuild}"
GCC_VERSION="${2:-14.1.0}"
RELEASE_VERSION="${3:-v0.0.1}"

INSTALL_DIR="$WORKDIR/gcc-install"
RELEASE_DIR="$WORKDIR/release"

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_FILES_DIR="$PKG_DIR/files"

echo "BUILD: workdir=$WORKDIR gcc=$GCC_VERSION release=$RELEASE_VERSION"

mkdir -p "$WORKDIR" "$INSTALL_DIR" "$RELEASE_DIR"

cd "$WORKDIR"

SRC_TARBALL="gcc-${GCC_VERSION}.tar.gz"
SRC_DIR="gcc-${GCC_VERSION}"
if [ ! -d "$SRC_DIR" ]; then
  if [ ! -f "$SRC_TARBALL" ]; then
    echo "Downloading GCC source: $SRC_TARBALL"
    wget "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/${SRC_TARBALL}"
  fi
  echo "Extracting ${SRC_TARBALL}..."
  tar -xf "$SRC_TARBALL"
fi

cd "$SRC_DIR"
echo "Running contrib/download_prerequisites (may take a while)..."
./contrib/download_prerequisites

mkdir -p "$WORKDIR/build-gcc"
cd "$WORKDIR/build-gcc"

echo "Configuring GCC (prefix=/usr, languages=c,c++, disable multilib)..."
"$WORKDIR/$SRC_DIR/configure" --prefix=/usr --enable-languages=c,c++ --disable-multilib

echo "Building GCC (this will take a long time)..."
make -j"$(nproc)"

echo "Installing into staged DESTDIR=$INSTALL_DIR..."
make install DESTDIR="$INSTALL_DIR"

echo "Preparing package files directory: $TARGET_FILES_DIR"
rm -rf "$TARGET_FILES_DIR"
mkdir -p "$TARGET_FILES_DIR"

if [ -d "$INSTALL_DIR/usr" ]; then
  echo "Copying staged usr/ tree into package files/"
  cp -a "$INSTALL_DIR/usr" "$TARGET_FILES_DIR/"
else
  echo "Error: expected staged /usr at $INSTALL_DIR/usr but it was not found" >&2
  exit 2
fi



echo "BUILD complete. Staged tree at: $TARGET_FILES_DIR/usr"
echo "Note: packaging the full paranpackage tarball should be performed by CI"
echo "Use: ./scripts/pack-paranpackage.sh $PKG_DIR <output-tarball>"

exit 0
