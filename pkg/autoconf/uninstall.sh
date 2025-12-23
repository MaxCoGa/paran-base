#!/usr/bin/env bash
set -euo pipefail

pkgdir="$(cd "$(dirname "$0")/.." && pwd)"
PKG_NAME="${PKG_NAME:-$(basename "$pkgdir") }"
PKG_VERSION="$(awk -F": " '/^version:/ {print $2; exit}' "$pkgdir/MANIFEST" || echo "local")"

PREFIX="$HOME/pp/opt/$PKG_NAME-$PKG_VERSION"
if [ -d "$PREFIX" ]; then
  rm -rf "$PREFIX"
  echo "Removed $PREFIX"
else
  echo "Nothing to remove at $PREFIX"
fi

exit 0
