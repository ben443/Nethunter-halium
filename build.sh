#!/bin/bash
set -e

##############################################################################
# Nethunter-Halium Build Script
# Builds device/generic/GKI Halium-based images with Nethunter and Droidian.
# Usage: ./build.sh <device|generic-<api>|gki-<version>> [options]
##############################################################################

# --- Configuration ---
BUILD_DIR="$(pwd)/build"
SOURCES_DIR="$(pwd)/sources"
OVERLAYS_DIR="$(pwd)/overlays"
OUT_DIR="$BUILD_DIR/out"
CONFIG_DIR="$BUILD_DIR/config"
ROOTFS_DIR="$BUILD_DIR/build/rootfs"
LOGS_DIR="$BUILD_DIR/logs"

# --- Create logs directory if it doesn't exist ---
mkdir -p "$LOGS_DIR"

# --- Default Variables ---
DEVICE="gts8"
BUILD_TYPE="device"
API_LEVEL="32"
GKI_VERSION="4"
SKIP_LXC=false
HALIUM_ONLY=false
ROOTFS_ONLY=false
ARCH_OVERRIDE=""

##############################################################################
# Print usage and available devices
##############################################################################
print_usage() {
  echo "Usage: $0 <device|generic-<api>|gki-<version>> [options]"
  echo ""
  echo "Build target:"
  echo "  <device>          Build for a specific device from Halium compatibility list"
  echo "  generic-30        Build a generic image for Android API level 30"
  echo "  generic-32        Build a generic image for Android API level 32"
  echo "  gki-5.10          Build for GKI Android 12 with kernel 5.10"
  echo ""
  echo "Options:"
  echo "  --skip-lxc        Skip LXC container setup"
  echo "  --halium-only     Build only Halium base"
  echo "  --rootfs-only     Build only rootfs"
  echo "  --arch <arch>     Override architecture (e.g., arm64, armhf, amd64)"
  echo ""
  echo "Available devices: (from Halium compatibility list)"
  if [ -d "$SOURCES_DIR/halium/devices" ]; then
    ls -1 "$SOURCES_DIR/halium/devices" | grep -v README
  else
    echo "  [Device list unavailable: $SOURCES_DIR/halium/devices not found]"
  fi
  exit 1
}

##############################################################################
# Parse arguments and options
##############################################################################
if [ $# -lt 1 ]; then
  print_usage
fi

TARGET="$1"
shift

# Parse main target
if [[ "$TARGET" == gki-* ]]; then
  BUILD_TYPE="gki"
  GKI_VERSION="${TARGET#gki-}"
  if [[ "$GKI_VERSION" != "5.10" ]]; then
    echo "Error: Unsupported GKI version: $GKI_VERSION"
    echo "Supported GKI versions: 5.10"
    exit 1
  fi
  API_LEVEL="32"
  DEVICE="gki-$GKI_VERSION"
elif [[ "$TARGET" == generic-* ]]; then
  BUILD_TYPE="generic"
  API_LEVEL="${TARGET#generic-}"
  if [[ "$API_LEVEL" != "30" && "$API_LEVEL" != "32" ]]; then
    echo "Error: Unsupported API level: $API_LEVEL"
    echo "Supported API levels for generic builds: 30, 32"
    exit 1
  fi
  DEVICE="generic-$API_LEVEL"
else
  DEVICE="$TARGET"
fi

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-lxc)
      SKIP_LXC=true
      shift
      ;;
    --halium-only)
      HALIUM_ONLY=true
      shift
      ;;
    --rootfs-only)
      ROOTFS_ONLY=true
      shift
      ;;
    --arch)
      ARCH_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

##############################################################################
# Setup logging
##############################################################################
BUILD_LOG="$LOGS_DIR/build-$DEVICE-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$BUILD_LOG") 2>&1

##############################################################################
# Utility Functions
##############################################################################
fail_if_missing_dir() {
  if [ ! -d "$1" ]; then
    echo "ERROR: Required directory '$1' not found."
    exit 1
  fi
}
fail_if_missing_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: Required file '$1' not found."
    exit 1
  fi
}

##############################################################################
# Banner
##############################################################################
echo "====== Nethunter-Halium Build Started ======"
echo "Target: $DEVICE (Build type: $BUILD_TYPE)"
[ -n "$API_LEVEL" ] && echo "API Level: $API_LEVEL"
[ -n "$GKI_VERSION" ] && echo "GKI Version: $GKI_VERSION"
echo "Options: Skip LXC: $SKIP_LXC, Halium only: $HALIUM_ONLY, Rootfs only: $ROOTFS_ONLY"
[ -n "$ARCH_OVERRIDE" ] && echo "Architecture override: $ARCH_OVERRIDE"
echo "Log file: $BUILD_LOG"
echo "=========================================="

mkdir -p "$BUILD_DIR" "$OUT_DIR" "$CONFIG_DIR" "$ROOTFS_DIR"

##############################################################################
# Step 1: Build Halium base
##############################################################################
build_halium_base() {
  echo "Building Halium base for $DEVICE..."
  fail_if_missing_dir "$SOURCES_DIR/halium"
  cd "$SOURCES_DIR/halium"

  if [ "$BUILD_TYPE" = "generic" ]; then
    echo "Building generic Halium base for API level $API_LEVEL"
    fail_if_missing_file "./build-gsi.sh"
    ./build-gsi.sh --android-api "$API_LEVEL" --gsi-variant halium
  elif [ "$BUILD_TYPE" = "gki" ]; then
    echo "Building GKI-based Halium for kernel $GKI_VERSION (API level $API_LEVEL)"
    fail_if_missing_file "./build-gki.sh"
    ./build-gki.sh --gki-version "$GKI_VERSION" --android-api "$API_LEVEL" --gsi-variant halium
  else
    fail_if_missing_file "./halium-install"
    ./halium-install -p halium -d "$DEVICE"
  fi
}

##############################################################################
# Step 2: Create Droidian-based rootfs
##############################################################################
create_rootfs() {
  echo "Creating Droidian-based rootfs..."
  fail_if_missing_dir "$SOURCES_DIR/droidian"
  cd "$SOURCES_DIR/droidian"

  # Architecture detection or override
  if [ -n "$ARCH_OVERRIDE" ]; then
    ARCH="$ARCH_OVERRIDE"
  elif [ "$BUILD_TYPE" = "generic" ] || [ "$BUILD_TYPE" = "gki" ]; then
    ARCH="arm64"
  else
    # TODO: Implement device-specific arch detection
    ARCH="arm64"
  fi

  fail_if_missing_file "./mkbootstrap"
  ./mkbootstrap \
    --arch "$ARCH" \
    --suite bookworm \
    --include droidian-base,phosh,kali-linux-default \
    --output "$ROOTFS_DIR/rootfs.tar.gz"

  # Extract rootfs safely
  mkdir -p "$ROOTFS_DIR/extracted"
  rm -rf "$ROOTFS_DIR/extracted"/*
  tar -xzf "$ROOTFS_DIR/rootfs.tar.gz" -C "$ROOTFS_DIR/extracted"
}

##############################################################################
# Step 3: Apply Nethunter customizations
##############################################################################
apply_nethunter_customizations() {
  echo "Applying Nethunter customizations..."

  # Copy Nethunter tools and scripts
  if [ -d "$SOURCES_DIR/nethunter/nethunter-fs/opt/nethunter" ]; then
    mkdir -p "$ROOTFS_DIR/extracted/opt/nethunter"
    cp -r "$SOURCES_DIR/nethunter/nethunter-fs/opt/nethunter/"* "$ROOTFS_DIR/extracted/opt/nethunter/"
  fi

  # Copy Nethunter Phosh theme
  if [ -d "$OVERLAYS_DIR/phosh-theme" ]; then
    mkdir -p "$ROOTFS_DIR/extracted/usr/share/themes/nethunter"
    cp -r "$OVERLAYS_DIR/phosh-theme/"* "$ROOTFS_DIR/extracted/usr/share/themes/nethunter/"
  fi

  # Copy Kali tools overlay
  if [ -d "$OVERLAYS_DIR/kali-tools" ]; then
    cp -r "$OVERLAYS_DIR/kali-tools/"* "$ROOTFS_DIR/extracted/"
  fi

  # Create Nethunter configuration file
  mkdir -p "$ROOTFS_DIR/extracted/etc"
  cat > "$ROOTFS_DIR/extracted/etc/nethunter.conf" << EOF
# Nethunter-Halium Configuration
NETHUNTER_VERSION="Halium Edition"
NETHUNTER_BRANCH="Pro"
PHOSH_THEME="nethunter"
BUILD_TYPE="$BUILD_TYPE"
EOF

  # Add build-specific configuration
  if [ "$BUILD_TYPE" = "generic" ]; then
    echo "API_LEVEL=\"$API_LEVEL\"" >> "$ROOTFS_DIR/extracted/etc/nethunter.conf"
  elif [ "$BUILD_TYPE" = "gki" ]; then
    echo "GKI_VERSION=\"$GKI_VERSION\"" >> "$ROOTFS_DIR/extracted/etc/nethunter.conf"
    echo "API_LEVEL=\"$API_LEVEL\"" >> "$ROOTFS_DIR/extracted/etc/nethunter.conf"
    # GKI tweaks and service
    mkdir -p "$ROOTFS_DIR/extracted/etc/phosh/gki-tweaks"
    if [ -d "$OVERLAYS_DIR/gki-$GKI_VERSION" ]; then
      cp -r "$OVERLAYS_DIR/gki-$GKI_VERSION/"* "$ROOTFS_DIR/extracted/"
    fi
    mkdir -p "$ROOTFS_DIR/extracted/etc/systemd/system"
    cat > "$ROOTFS_DIR/extracted/etc/systemd/system/gki-module-loader.service" << EOFSERVICE
[Unit]
Description=GKI Kernel Module Loader
After=halium-boot.service
Before=phosh.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gki-load-modules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOFSERVICE

    mkdir -p "$ROOTFS_DIR/extracted/usr/local/bin"
    cat > "$ROOTFS_DIR/extracted/usr/local/bin/gki-load-modules" << 'EOFSCRIPT'
#!/bin/bash
set -e
echo "Loading GKI-specific kernel modules..."
source /etc/nethunter.conf
if [ -d "/vendor/lib/modules" ]; then
    for module in /vendor/lib/modules/*.ko; do
        modname=$(basename "$module")
        echo "Loading vendor module: $modname"
        insmod "$module" || echo "Failed to load $modname"
    done
fi
if [ -d "/lib/modules/$(uname -r)/kernel/drivers/gki" ]; then
    for module in /lib/modules/$(uname -r)/kernel/drivers/gki/*.ko; do
        modname=$(basename "$module")
        echo "Loading GKI module: $modname"
        modprobe "$modname" || echo "Failed to load $modname"
    done
fi
echo "GKI module loading complete"
exit 0
EOFSCRIPT
    chmod +x "$ROOTFS_DIR/extracted/usr/local/bin/gki-load-modules"
    ln -sf "/etc/systemd/system/gki-module-loader.service" \
      "$ROOTFS_DIR/extracted/etc/systemd/system/multi-user.target.wants/gki-module-loader.service"
  else
    echo "DEVICE=\"$DEVICE\"" >> "$ROOTFS_DIR/extracted/etc/nethunter.conf"
  fi

  # LXC container setup
  if [ "$SKIP_LXC" = false ]; then
    setup_lxc_container
  fi
}

##############################################################################
# Step 4: LXC Container Setup
##############################################################################
setup_lxc_container() {
  mkdir -p "$ROOTFS_DIR/extracted/var/lib/lxc/kali-nethunter"
  cat > "$ROOTFS_DIR/extracted/var/lib/lxc/kali-nethunter/config" << EOF
# Kali Nethunter LXC configuration
lxc.uts.name = kali-nethunter
lxc.rootfs.path = dir:/var/lib/lxc/kali-nethunter/rootfs
lxc.include = /usr/share/lxc/config/debian.common.conf
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.name = eth0
lxc.mount.entry = /dev dev none bind,create=dir 0 0
lxc.mount.entry = /sys/kernel/security sys/kernel/security none ro,bind,optional 0 0
EOF

  # First-boot setup script
  cat > "$ROOTFS_DIR/extracted/usr/local/bin/nethunter-first-boot" << 'EOF'
#!/bin/bash
set -e
echo "Performing first-boot setup for Nethunter-Halium..."
source /etc/nethunter.conf
echo "Nethunter-Halium $NETHUNTER_VERSION ($NETHUNTER_BRANCH)"
echo "Build type: $BUILD_TYPE"
if [ "$BUILD_TYPE" = "generic" ]; then
  echo "API level: $API_LEVEL"
elif [ "$BUILD_TYPE" = "gki" ]; then
  echo "GKI version: $GKI_VERSION (API level: $API_LEVEL)"
else
  echo "Device: $DEVICE"
fi
# Initialize LXC container for Kali tools
if [ ! -f /var/lib/lxc/kali-nethunter/rootfs/.initialized ]; then
  echo "Setting up Kali Nethunter LXC container..."
  lxc-create -n kali-nethunter -t download -- -d kali -r current -a arm64
  lxc-attach -n kali-nethunter -- apt-get update
  lxc-attach -n kali-nethunter -- apt-get install -y kali-linux-default
  touch /var/lib/lxc/kali-nethunter/rootfs/.initialized
fi
# Apply Nethunter theme to Phosh
if [ -d /usr/share/themes/nethunter ]; then
  gsettings set org.gnome.desktop.interface gtk-theme 'nethunter'
  gsettings set org.gnome.desktop.wm.preferences theme 'nethunter'
fi
mkdir -p /usr/local/share/applications/
cat > /usr/local/share/applications/nethunter-terminal.desktop << INNEREOF
[Desktop Entry]
Name=Nethunter Terminal
Comment=Kali Nethunter Terminal
Exec=lxc-attach -n kali-nethunter -- /bin/bash
Icon=/opt/nethunter/icons/kali-term.png
Terminal=true
Type=Application
Categories=Kali;Penetration Testing;
INNEREOF
if [ "$BUILD_TYPE" = "device" ]; then
  echo "Applying device-specific optimizations for $DEVICE..."
elif [ "$BUILD_TYPE" = "gki" ]; then
  echo "Applying GKI-specific optimizations for kernel $GKI_VERSION..."
  if [ -d "/etc/phosh/gki-tweaks" ]; then
    for tweakscript in /etc/phosh/gki-tweaks/*.sh; do
      [ -x "$tweakscript" ] && "$tweakscript"
    done
  fi
fi
echo "First boot setup completed!"
EOF
  chmod +x "$ROOTFS_DIR/extracted/usr/local/bin/nethunter-first-boot"

  # Systemd service for first-boot
  mkdir -p "$ROOTFS_DIR/extracted/etc/systemd/system"
  cat > "$ROOTFS_DIR/extracted/etc/systemd/system/nethunter-first-boot.service" << EOF
[Unit]
Description=Nethunter First Boot Setup
After=network.target
ConditionPathExists=!/var/lib/nethunter/.first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nethunter-first-boot
ExecStartPost=/bin/touch /var/lib/nethunter/.first-boot-done

[Install]
WantedBy=multi-user.target
EOF
  mkdir -p "$ROOTFS_DIR/extracted/var/lib/nethunter"
  ln -sf "/etc/systemd/system/nethunter-first-boot.service" \
    "$ROOTFS_DIR/extracted/etc/systemd/system/multi-user.target.wants/nethunter-first-boot.service"
}

##############################################################################
# Step 5: Repackage rootfs safely
##############################################################################
repackage_rootfs() {
  echo "Repackaging rootfs..."
  cd "$ROOTFS_DIR/extracted"
  # Output file outside the directory being packed
  find . | cpio -o -H newc | gzip > "$ROOTFS_DIR/rootfs.img"
}

##############################################################################
# Step 6: Combine with Halium system image
##############################################################################
combine_with_halium() {
  echo "Combining with Halium system image..."
  mkdir -p "$OUT_DIR"
  fail_if_missing_file "$SOURCES_DIR/halium/scripts/halium-install"
  if [ "$BUILD_TYPE" = "generic" ]; then
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      --generic-android-api "$API_LEVEL" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  elif [ "$BUILD_TYPE" = "gki" ]; then
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      --gki-version "$GKI_VERSION" \
      --android-api "$API_LEVEL" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  else
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      "$DEVICE" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  fi
}

##############################################################################
# Main build flow
##############################################################################
if [ "$ROOTFS_ONLY" = false ]; then
  build_halium_base
fi

if [ "$HALIUM_ONLY" = false ]; then
  create_rootfs
  apply_nethunter_customizations
  repackage_rootfs
  combine_with_halium
fi

echo "Build complete! Output image: $OUT_DIR/nethunter-halium-$DEVICE.img"
echo "You can flash this image using ./flash.sh $DEVICE"
