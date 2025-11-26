#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 PACKAGE_NAME [VERSION] [BUILD_TARBALL]

Create a basic paranpackage skeleton directory with:
  - MANIFEST
  - install.sh (example)
  - uninstall.sh (example)
  - files/ (payload placeholder)

If `BUILD_TARBALL` is provided the script will extract that tarball into
`<PACKAGE>/files/` so the resulting package includes the build tree (for
example a `usr/` directory produced by a local build).

Example:
  ./scripts/new-paranpackage.sh helloworld 1.0.0 /path/to/build.tar.gz

EOF
  exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

PKG_NAME="$1"
PKG_VERSION="${2:-0.1.0}"
BUILD_TARBALL="${3:-}"
PKG_DIR="$PKG_NAME"

if [ -e "$PKG_DIR" ]; then
  echo "Destination already exists: $PKG_DIR" >&2
  exit 2
fi

mkdir -p "$PKG_DIR/files"

# If a build tarball path was provided, extract its contents into files/
if [ -n "${BUILD_TARBALL}" ]; then
  if [ ! -f "${BUILD_TARBALL}" ]; then
    echo "Build tarball not found: ${BUILD_TARBALL}" >&2
    exit 3
  fi
  echo "Extracting build tarball into: $PKG_DIR/files/"
  tar -xzf "${BUILD_TARBALL}" -C "$PKG_DIR/files"
fi

cat > "$PKG_DIR/MANIFEST" <<EOF
name: $PKG_NAME
version: $PKG_VERSION
description: $PKG_NAME package
# dependencies: bash
install: install.sh
uninstall: uninstall.sh
# helper: <space-separated helper scripts to keep in pp_info/>
# Example: helper: uninstall-from-dir.sh uninstall.sh
EOF

cat > "$PKG_DIR/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Determine package name from the package directory when not supplied
pkgdir="$(cd "$(dirname "$0")/.." && pwd)"
PKG_NAME="${PKG_NAME:-$(basename "$pkgdir") }"

# Example install: copy files to a local per-user prefix
PREFIX="$HOME/pp/opt/$PKG_NAME"
mkdir -p "$PREFIX"
cp -r files/. "$PREFIX/"
echo "Installed to $PREFIX"
SH

# No runtime placeholder replacement necessary; scripts detect package name automatically

cat > "$PKG_DIR/uninstall.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
pkgdir="$(cd "$(dirname "$0")/.." && pwd)"
PKG_NAME="${PKG_NAME:-$(basename "$pkgdir") }"

# Example uninstall: remove the installed files from the per-user prefix
PREFIX="$HOME/pp/opt/$PKG_NAME"
if [ -d "$PREFIX" ]; then
  rm -rf "$PREFIX"
  echo "Removed $PREFIX"
else
  echo "Nothing to remove at $PREFIX"
fi
SH

# ensure scripts are executable
chmod +x "$PKG_DIR/install.sh" "$PKG_DIR/uninstall.sh"

# Example helper script that can be listed under the MANIFEST's "helper:" key.
# Helpers listed in MANIFEST will be copied into pp_info/<pkg>/ and kept
# around so the uninstaller can run from there.
cat > "$PKG_DIR/uninstall-from-dir.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
pkgdir="$(cd "$(dirname "$0")/.." && pwd)"
PKG_NAME="${PKG_NAME:-$(basename "$pkgdir") }"
PREFIX="$HOME/pp/opt/$PKG_NAME"
if [ -d "$PREFIX" ]; then
  rm -rf "$PREFIX"
  echo "Removed $PREFIX"
else
  echo "Nothing to remove at $PREFIX"
fi
SH

chmod +x "$PKG_DIR/uninstall-from-dir.sh"

cat > "$PKG_DIR/.README" <<EOF
Package skeleton for $PKG_NAME
- Edit MANIFEST to add description and dependencies
- Put payload files under files/
- Build the package:
    tar -czf ${PKG_NAME}-${PKG_VERSION}.tar.gz -C $PKG_DIR .
- Then add the package to the repo list or install locally with pp
Notes:
- To keep helper scripts available for uninstall, add a `helper:` line
  to the MANIFEST. Example:

    helper: uninstall-from-dir.sh uninstall.sh

  `pp` will copy those files into `pp_info/<pkg>/` and make them executable.
EOF

echo "Created package skeleton: $PKG_DIR (version $PKG_VERSION)"
echo "Next: run ./scripts/pack-paranpackage.sh $PKG_DIR to create a tarball"

exit 0
