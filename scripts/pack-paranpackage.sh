#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 /path/to/package_dir [output-tarball]

Creates a gzipped tarball from the package directory and prints the SHA256 checksum.
If `output-tarball` is omitted the script will try to infer a filename from the
package MANIFEST (`name` and `version`) or fall back to the directory name.

Example:
  ./scripts/pack-paranpackage.sh temp/helloworld
  ./scripts/pack-paranpackage.sh temp/helloworld /tmp/helloworld-1.2.3.tar.gz

EOF
  exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

PKG_DIR="$1"
if [ ! -d "$PKG_DIR" ]; then
  echo "Package directory not found: $PKG_DIR" >&2
  exit 2
fi

OUT="$2"

# try to infer name/version from MANIFEST if present
MANIFEST_PATH="$PKG_DIR/MANIFEST"
PKG_NAME=""
PKG_VERSION=""
if [ -f "$MANIFEST_PATH" ]; then
  # read simple key: value lines
  PKG_NAME=$(awk -F": " '/^name:/ {print $2; exit}' "$MANIFEST_PATH" || true)
  PKG_VERSION=$(awk -F": " '/^version:/ {print $2; exit}' "$MANIFEST_PATH" || true)
fi

# fallback to basename
if [ -z "$PKG_NAME" ]; then
  PKG_NAME=$(basename "$PKG_DIR")
fi
if [ -z "$PKG_VERSION" ]; then
  PKG_VERSION="local"
fi

if [ -z "$OUT" ]; then
  OUT="${PKG_NAME}-${PKG_VERSION}.tar.gz"
fi

# create tarball (create parent dir if needed for relative paths)
OUT_DIR=$(dirname "$OUT")
[ -z "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

echo "Packing package directory: $PKG_DIR -> $OUT"
# Use tar -C to avoid including the parent path
tar -C "$PKG_DIR" -czf "$OUT" .

# compute sha256
if command -v sha256sum >/dev/null 2>&1; then
  sha256=$(sha256sum "$OUT" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  sha256=$(shasum -a 256 "$OUT" | awk '{print $1}')
else
  echo "No sha256 utility found (sha256sum or shasum required)" >&2
  exit 3
fi

echo "Created: $OUT"
echo "SHA256: $sha256"

exit 0
