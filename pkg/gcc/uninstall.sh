#!/usr/bin/env bash
set -euo pipefail

# Uninstall helper for the `gcc` paranpackage installed by the install.sh above.
# Uses the repo uninstall helper to remove the prefix created during install.

TARGET_PREFIX="$HOME/pp/opt/gcc-14.1.0"
UNINSTALLER_SCRIPT="$(dirname "$0")/uninstall-gcc-from-dir.sh"

if [ ! -x "${UNINSTALLER_SCRIPT}" ]; then
  echo "Warning: packaged uninstaller not executable or missing at ${UNINSTALLER_SCRIPT}. Falling back to repo script if available."
  if [ -x "/workspaces/paran-base/scripts/uninstall-gcc-from-dir.sh" ]; then
    UNINSTALLER_SCRIPT="/workspaces/paran-base/scripts/uninstall-gcc-from-dir.sh"
  fi
fi

if [ -x "${UNINSTALLER_SCRIPT}" ]; then
  echo "Calling uninstaller script for prefix ${TARGET_PREFIX}"
  "${UNINSTALLER_SCRIPT}" --prefix "${TARGET_PREFIX}" --remove-tree --yes
else
  echo "Uninstaller helper not found; removing ${TARGET_PREFIX} directly"
  rm -rf "${TARGET_PREFIX}"
  echo "Removed ${TARGET_PREFIX}"
fi

exit 0
