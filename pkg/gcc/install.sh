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

# determine tarball path
if [ -f "${TARBALL_NAME}" ]; then
  TAR_PATH="$(realpath "${TARBALL_NAME}")"
elif [ -f "${FALLBACK_PATH}" ]; then
  TAR_PATH="${FALLBACK_PATH}"
else
  echo "Error: gcc build tarball not found. Expecting ${TARBALL_NAME} in package or ${FALLBACK_PATH}." >&2
  exit 1
fi

echo "Using tarball: ${TAR_PATH}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Extracting tarball to ${TMPDIR}..."
tar -xzf "${TAR_PATH}" -C "${TMPDIR}"

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
echo "Running installer script to copy files to ${TARGET_PREFIX} (LFS mode)..."
# Ensure the parent directory and the target prefix exist so installer realpath/mkdir logic succeeds
mkdir -p "$(dirname "${TARGET_PREFIX}")"
mkdir -p "${TARGET_PREFIX}"

"${INSTALLER_SCRIPT}" "${TMPDIR}" --prefix "${TARGET_PREFIX}" --lfs

echo "GCC installed to ${TARGET_PREFIX}"

exit 0
