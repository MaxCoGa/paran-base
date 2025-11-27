#!/usr/bin/env bash
set -euo pipefail

# BUILD helper for acl package
# Usage: BUILD WORKDIR SOURCE_OR_URL RELEASE_TAG

WORKDIR="${1:-/tmp/paranbuild}"
SRC_ARG="${2:-2.3.2}"
RELEASE_VERSION="${3:-v0.0.1}"

INSTALL_DIR="$WORKDIR/acl-install"
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
  SRC_DIR="$(ls -d acl-* 2>/dev/null | head -n1)"
  if [ -z "$SRC_DIR" ]; then
    echo "Could not find extracted acl source dir" >&2
    exit 2
  fi
else
  ACL_VERSION="$SRC_ARG"
  SRC_TARBALL="acl-${ACL_VERSION}.tar.xz"
  SRC_DIR="acl-${ACL_VERSION}"
  if [ ! -d "$SRC_DIR" ]; then
    if [ ! -f "$SRC_TARBALL" ]; then
      echo "Downloading acl source: $SRC_TARBALL"
      wget "https://download.savannah.gnu.org/releases/acl/$SRC_TARBALL"
    fi
    echo "Extracting $SRC_TARBALL"
    tar -xf "$SRC_TARBALL"
  fi
fi

cd "$SRC_DIR"
echo "Configuring..."
# If attr was built earlier in the same workdir, point configure to its staged include/lib
extra_cflags=""
extra_ldflags=""
extra_pkgconfig=""
if [ -d "$WORKDIR/attr-install/usr" ]; then
  echo "Found staged attr at $WORKDIR/attr-install/usr, adding include/lib flags"
  extra_cflags="-I$WORKDIR/attr-install/usr/include"
  extra_ldflags="-L$WORKDIR/attr-install/usr/lib"
  extra_pkgconfig="$WORKDIR/attr-install/usr/lib/pkgconfig"
  export PKG_CONFIG_PATH="$extra_pkgconfig${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH:-}"
fi
CPPFLAGS="$extra_cflags" LDFLAGS="$extra_ldflags" ./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/$SRC_DIR
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
