#!/usr/bin/env bash
# Fail on unset vars and errors; enable pipefail when supported
set -eu
{ set -o pipefail; } 2>/dev/null || true

usage() {
  cat <<EOF
Usage: $0 /path/to/gcc-install [--prefix /opt/gcc-VERSION] [--no-register] [--lfs] [--system]

Installs a GCC build directory (the folder that contains `bin include lib lib64 libexec share`).
Defaults: copies to /opt/gcc-<version>. By default it will attempt to register
libraries with ldconfig and (optionally) create simple symlinks for `gcc`, `g++`, `cpp`.

Flags:
  --prefix PATH     Install into PATH instead of /opt/gcc-<version>
  --no-register     Do not register binaries or create system profile/ld config
  --lfs             LFS-friendly minimal mode: only copy files (no system changes)
  --system          Force system registration (ldconfig/profile and create symlinks)

LFS note: For Linux From Scratch, prefer `--lfs` which will only copy files into
the target prefix. Do not run system registration steps while in a temporary
toolchain or chroot unless you know what you're doing.

Example:
  sudo $0 /workspaces/gcc-install --lfs

EOF
  exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

SRC_DIR=$(realpath "$1")
shift || true
PREFIX=""
REGISTER=1
LFS_MODE=0
FORCE_SYSTEM=0
FORCE_LINKS=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      shift
      PREFIX=$(realpath "$1")
      ;;
    --no-register)
      REGISTER=0
      ;;
    --lfs)
      LFS_MODE=1
      # In LFS mode we avoid system-wide registration by default
      REGISTER=0
      ;;
    --system)
      FORCE_SYSTEM=1
      ;;
    --force-links)
      FORCE_LINKS=1
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

if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory not found: $SRC_DIR"
  exit 2
fi

if [ ! -d "$SRC_DIR/bin" ]; then
  echo "Directory doesn't look like a gcc install (missing bin): $SRC_DIR"
  exit 3
fi

# Try to detect version from the built gcc if executable
VERSION="local"
if [ -x "$SRC_DIR/bin/gcc" ]; then
  # prefer -dumpfullversion when available, fallback to -dumpversion or --version
  if ver=$("$SRC_DIR/bin/gcc" -dumpfullversion 2>/dev/null || true); then
    if [ -n "$ver" ]; then
      VERSION=$ver
    fi
  fi
  if [ "$VERSION" = "local" ]; then
    if ver=$("$SRC_DIR/bin/gcc" -dumpversion 2>/dev/null || true); then
      if [ -n "$ver" ]; then
        VERSION=$ver
      fi
    fi
  fi
  if [ "$VERSION" = "local" ]; then
    if ver=$("$SRC_DIR/bin/gcc" --version 2>/dev/null | head -n1 | awk '{print $3}' || true); then
      if [ -n "$ver" ]; then
        VERSION=$ver
      fi
    fi
  fi
fi

if [ -z "$PREFIX" ]; then
  DEST_DIR="/opt/gcc-$VERSION"
else
  DEST_DIR="$PREFIX"
fi

echo "Source: $SRC_DIR"
echo "Destination: $DEST_DIR"

if [ "$SRC_DIR" = "$DEST_DIR" ]; then
  echo "Source and destination are the same. Nothing to copy."
else
  echo "Copying files to $DEST_DIR (needs sudo if not root)..."
  if [ "$(id -u)" -ne 0 ]; then
    sudo mkdir -p "$(dirname "$DEST_DIR")"
    sudo rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
  else
    mkdir -p "$(dirname "$DEST_DIR")"
    rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
  fi
fi

# Register libs with ldconfig
LD_CONF_FILE="/etc/ld.so.conf.d/gcc-$VERSION.conf"

# Handle ldconfig / ld.so.conf only when not in LFS mode unless forced
if [ "$LFS_MODE" -eq 1 ] && [ "$FORCE_SYSTEM" -eq 0 ]; then
  echo "LFS mode: skipping ldconfig/ld.so.conf and system registration."
else
  echo "Adding $DEST_DIR/lib and $DEST_DIR/lib64 to $LD_CONF_FILE"
  if [ "$(id -u)" -ne 0 ]; then
    sudo bash -c "cat > $LD_CONF_FILE <<EOF
$DEST_DIR/lib
$DEST_DIR/lib64
EOF"
    sudo ldconfig || true
  else
    cat > "$LD_CONF_FILE" <<EOF
$DEST_DIR/lib
$DEST_DIR/lib64
EOF
    ldconfig || true
  fi
fi

if [ "$REGISTER" -eq 1 ] && { [ "$LFS_MODE" -eq 0 ] || [ "$FORCE_SYSTEM" -eq 1 ]; }; then
  echo "Registering compiler binaries by creating symlinks (if target paths are free)..."
  # For LFS/Paran OS we keep this simple: create symlinks in /usr/bin (or /usr/local/bin if desired)
  # Skip any target that already exists to avoid overwriting system tools.
  for prog in gcc g++ cpp cc; do
    if [ -x "$DEST_DIR/bin/$prog" ]; then
      # prefer /usr/bin for final system installs; fall back to /usr/local/bin if /usr/bin is not writable
      TARGET_DIR="/usr/bin"
      if [ ! -w "$TARGET_DIR" ]; then
        TARGET_DIR="/usr/local/bin"
      fi
      TARGET_PATH="$TARGET_DIR/$prog"
      if [ -e "$TARGET_PATH" ] || [ -L "$TARGET_PATH" ]; then
        if [ "$FORCE_LINKS" -eq 1 ]; then
          # Backup existing target
          bak="$TARGET_PATH.backup.$(date +%s)"
          echo "Backing up existing $TARGET_PATH to $bak"
          if [ "$(id -u)" -ne 0 ]; then
            sudo mv "$TARGET_PATH" "$bak"
          else
            mv "$TARGET_PATH" "$bak"
          fi
          echo "Creating symlink: $TARGET_PATH -> $DEST_DIR/bin/$prog"
          if [ "$(id -u)" -ne 0 ]; then
            sudo ln -s "$DEST_DIR/bin/$prog" "$TARGET_PATH"
          else
            ln -s "$DEST_DIR/bin/$prog" "$TARGET_PATH"
          fi
        else
          echo "$TARGET_PATH already exists, skipping"
        fi
      else
        if [ "$(id -u)" -ne 0 ]; then
          sudo ln -s "$DEST_DIR/bin/$prog" "$TARGET_PATH"
        else
          ln -s "$DEST_DIR/bin/$prog" "$TARGET_PATH"
        fi
        echo "Created symlink: $TARGET_PATH -> $DEST_DIR/bin/$prog"
      fi
    fi
  done
else
  if [ "$LFS_MODE" -eq 1 ]; then
    echo "LFS mode: not registering binaries or creating symlinks."
  fi
fi

# Add a profile.d snippet so PATH/LD_LIBRARY_PATH include the new gcc when logging in
PROFILE_FILE="/etc/profile.d/gcc-$VERSION.sh"
if [ "$LFS_MODE" -eq 1 ] && [ "$FORCE_SYSTEM" -eq 0 ]; then
  echo "LFS mode: skipping creation of $PROFILE_FILE. Add $DEST_DIR/bin to PATH manually if needed."
else
  echo "Creating $PROFILE_FILE to add $DEST_DIR/bin to PATH for interactive shells"
  PROFILE_CONTENT=$(cat <<EOF
# GCC installed to $DEST_DIR
export PATH="$DEST_DIR/bin:\$PATH"
export LD_LIBRARY_PATH="$DEST_DIR/lib:$DEST_DIR/lib64:\$LD_LIBRARY_PATH"
export MANPATH="$DEST_DIR/share/man:\$MANPATH"
EOF
)
  # Write to a temp file first so we can move it into place with sudo if needed
  tmpfile=$(mktemp)
  printf '%s
' "$PROFILE_CONTENT" > "$tmpfile"
  if [ "$(id -u)" -ne 0 ]; then
    sudo mv "$tmpfile" "$PROFILE_FILE"
    sudo chmod 644 "$PROFILE_FILE" || true
  else
    mv "$tmpfile" "$PROFILE_FILE"
    chmod 644 "$PROFILE_FILE" || true
  fi
fi

echo
echo "Installation complete. Quick tests and next steps:"
echo "  1) Run: gcc --version"
echo "  2) Compile a tiny test: echo 'int main(){}' > t.c && gcc t.c -o t && ./t && echo OK"
echo
echo "Uninstall / rollback steps (manual):"
echo "  - If you created symlinks: sudo rm -f /usr/bin/gcc /usr/bin/g++ /usr/bin/cpp (or /usr/local/bin/...)"
echo "  - Remove $LD_CONF_FILE and run sudo ldconfig (unless you used --lfs)"
echo "  - Remove $PROFILE_FILE (unless you used --lfs)"
echo "  - Remove the installed tree: sudo rm -rf $DEST_DIR"

exit 0
