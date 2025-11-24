#!/usr/bin/env bash
set -euo pipefail

# Install helper for the `gcc` paranpackage.
# Behavior:
#  - Looks for a tarball named `gcc-build-v0.0.1.tar.gz` in the current package dir
#    or falls back to the workspace path `/workspaces/paran-base/temp/gcc-build-v0.0.1.tar.gz`.
#  - Extracts the tarball to a temporary dir and calls the repo's
#    `scripts/install-gcc-from-dir.sh` with a user-local prefix to avoid system changes.

TARBALL_NAME="gcc-build-v0.0.1.tar.gz"
FALLBACK_PATH="/workspaces/paran-base/temp/gcc-build-v0.0.1.tar.gz"
TARGET_PREFIX="$HOME/pp/opt/gcc-14.1.0"

# Prefer an included files/ tree (e.g. files/usr/). If present, use that
# directory as the staged build. Otherwise fall back to a packaged tarball,
# or a repository fallback path.
PKG_BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# The package should include a prebuilt tree under files/ (typically a
# top-level `usr/` directory containing the GCC install). Use that as the
# staged build directory. Do not attempt to auto-download or fall back to
# other locations; fail early if files/ is absent so the package author can
# fix the package contents.
if [ -d "$PKG_BASE_DIR/files" ]; then
  echo "Using included files/ tree from package: $PKG_BASE_DIR/files"
  STAGED_DIR="$PKG_BASE_DIR/files"
else
  echo "Error: package does not contain a 'files/' build tree. Put the built 'usr/' tree under pkg/gcc/files/ and repack." >&2
  exit 1
fi

# Use the repo installer script to copy the staged usr/ tree into the target prefix.
INSTALLER_SCRIPT="$(dirname "$0")/install-gcc-from-dir.sh"
if [ ! -x "${INSTALLER_SCRIPT}" ]; then
  echo "Warning: packaged installer not executable or missing at ${INSTALLER_SCRIPT}. Falling back to repo script if available."
  if [ -x "/workspaces/paran-base/scripts/install-gcc-from-dir.sh" ]; then
    INSTALLER_SCRIPT="/workspaces/paran-base/scripts/install-gcc-from-dir.sh"
  else
    echo "Error: installer script not found or not executable: packaged or repo fallback." >&2
    exit 2
  fi
fi

# Pass --lfs to avoid system ldconfig/profile modifications. Use --prefix for user-local install.
echo "Running installer script to copy files from ${STAGED_DIR} to ${TARGET_PREFIX} (LFS mode)..."
# Ensure the parent directory and the target prefix exist so installer realpath/mkdir logic succeeds
mkdir -p "$(dirname "${TARGET_PREFIX}")"
mkdir -p "${TARGET_PREFIX}"

"${INSTALLER_SCRIPT}" "${STAGED_DIR}" --prefix "${TARGET_PREFIX}" --lfs

echo "GCC installed to ${TARGET_PREFIX}"

exit 0
