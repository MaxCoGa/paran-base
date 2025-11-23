#!/usr/bin/env bash
# Uninstall helper for GCC installed by install-gcc-from-dir.sh
set -eu
{ set -o pipefail; } 2>/dev/null || true

usage() {
  cat <<EOF
Usage: $0 [--prefix /opt/gcc-VERSION] [--version VERSION] [--remove-tree] [--yes] [--dry-run]

Removes symlinks, ld.so.conf entry and profile snippet created by
`install-gcc-from-dir.sh`. If `--remove-tree` is provided, it will also
remove the installed tree (requires root).

Examples:
  sudo $0 --prefix /opt/gcc-14.1.0 --remove-tree
  $0 --version 14.1.0 --dry-run

Flags:
  --prefix PATH     Exact install prefix to uninstall (preferred)
  --version VER     Use /opt/gcc-VER as the installed prefix
  --remove-tree     Also remove the installed directory
  --yes             Do not prompt for confirmation
  --dry-run         Print actions without performing them
  -h, --help        Show this help

EOF
  exit 1
}

PREFIX=""
VERSION=""
REMOVE_TREE=0
ASSUME_YES=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      shift
      PREFIX=$(realpath "$1")
      ;;
    --version)
      shift
      VERSION="$1"
      ;;
    --remove-tree)
      REMOVE_TREE=1
      ;;
    --yes)
      ASSUME_YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      ;;
  esac
  shift || true
done

fail() { echo "Error: $*" >&2; exit 2; }

# Resolve DEST_DIR and VERSION
if [ -n "$PREFIX" ]; then
  DEST_DIR="$PREFIX"
  VERSION=""
  # try to extract version if prefix matches /opt/gcc-*
  base=$(basename "$DEST_DIR")
  case "$base" in
    gcc-*) VERSION=${base#gcc-} ;;
  esac
elif [ -n "$VERSION" ]; then
  DEST_DIR="/opt/gcc-$VERSION"
else
  # Try to detect from ld.so.conf.d
  matches=(/etc/ld.so.conf.d/gcc-*.conf)
  found=""
  for f in "${matches[@]}"; do
    [ -f "$f" ] || continue
    while read -r line; do
      [ -z "$line" ] && continue
      if [ -d "$line" ] && [ -x "$line/bin/gcc" ]; then
        found="$line"
        conf="$f"
        break 2
      fi
    done <"$f"
  done
  if [ -n "$found" ]; then
    DEST_DIR="$found"
    base=$(basename "$f")
    case "$base" in
      gcc-*.conf) VERSION=${base#gcc-}; VERSION=${VERSION%.conf} ;;
    esac
  else
    fail "Could not detect installed GCC prefix. Provide --prefix or --version."
  fi
fi

echo "Target uninstall prefix: $DEST_DIR"
[ -n "$VERSION" ] && echo "Detected version: $VERSION"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: no changes will be made."
fi

confirm() {
  if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    y|Y) return 0 ;; *) return 1 ;;
  esac
}

ACTION_rm() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY: rm -rf $1"
  else
    if [ "$(id -u)" -ne 0 ]; then
      sudo rm -rf "$1"
    else
      rm -rf "$1"
    fi
  fi
}

# Remove symlinks only if they point into DEST_DIR/bin
for prog in gcc g++ cpp cc gfortran gcov; do
  for dir in /usr/bin /usr/local/bin; do
    target="$dir/$prog"
    if [ -L "$target" ]; then
      link=$(readlink -f "$target" || true)
      if [ -n "$link" ] && [ "${link%%/}" = "${DEST_DIR%%/}/bin/$prog" ] || [ "${link%%/}" = "${DEST_DIR%%/}/bin/$prog" ]; then
        if confirm "Remove symlink $target -> $link?"; then
          if [ "$DRY_RUN" -eq 1 ]; then
            echo "DRY: rm $target"
          else
            if [ "$(id -u)" -ne 0 ]; then
              sudo rm -f "$target"
            else
              rm -f "$target"
            fi
            echo "Removed $target"
          fi
        fi
      fi
    fi
  done
done

# Remove ld config file if it matches DEST_DIR
if [ -n "$VERSION" ]; then
  LD_CONF_FILE="/etc/ld.so.conf.d/gcc-$VERSION.conf"
  if [ -f "$LD_CONF_FILE" ]; then
    # verify file contains DEST_DIR
    if grep -qF "$DEST_DIR" "$LD_CONF_FILE" 2>/dev/null; then
      if confirm "Remove ld config $LD_CONF_FILE and run ldconfig?"; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "DRY: rm $LD_CONF_FILE && ldconfig"
        else
          if [ "$(id -u)" -ne 0 ]; then
            sudo rm -f "$LD_CONF_FILE"
            sudo ldconfig || true
          else
            rm -f "$LD_CONF_FILE"
            ldconfig || true
          fi
          echo "Removed $LD_CONF_FILE and ran ldconfig"
        fi
      fi
    fi
  fi
fi

# Remove profile.d snippet if it matches DEST_DIR
if [ -n "$VERSION" ]; then
  PROFILE_FILE="/etc/profile.d/gcc-$VERSION.sh"
  if [ -f "$PROFILE_FILE" ]; then
    if grep -qF "$DEST_DIR" "$PROFILE_FILE" 2>/dev/null; then
      if confirm "Remove profile fragment $PROFILE_FILE?"; then
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "DRY: rm $PROFILE_FILE"
        else
          if [ "$(id -u)" -ne 0 ]; then
            sudo rm -f "$PROFILE_FILE"
          else
            rm -f "$PROFILE_FILE"
          fi
          echo "Removed $PROFILE_FILE"
        fi
      fi
    fi
  fi
fi

# Optionally remove the tree
if [ "$REMOVE_TREE" -eq 1 ]; then
  if [ -d "$DEST_DIR" ]; then
    if confirm "Remove installed tree $DEST_DIR? This cannot be undone."; then
      ACTION_rm "$DEST_DIR"
      echo "Removed $DEST_DIR"
    fi
  else
    echo "$DEST_DIR not found, skipping tree removal."
  fi
fi

echo "Uninstall complete."

exit 0
