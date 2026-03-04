#!/usr/bin/env bash
set -euo pipefail

# Install script for the `automake` paranpackage.
pkgdir="$(cd "$(dirname "$0")" && pwd)"
# prefer MANIFEST in the same dir (pp_info/<pkg>), fall back to parent (pkg/<pkg>)
if [ ! -f "$pkgdir/MANIFEST" ]; then
	pkgdir="$(cd "$(dirname "$0")/.." && pwd)"
fi
PKG_NAME="${PKG_NAME:-$(basename "$pkgdir")}"
PKG_VERSION="$(awk -F": " '/^version:/ {print $2; exit}' "$pkgdir/MANIFEST" || echo "local")"

PREFIX="$HOME/pp/opt/$PKG_NAME-$PKG_VERSION"
mkdir -p "$PREFIX"
cp -a files/. "$PREFIX/"
echo "Installed to $PREFIX"

exit 0
