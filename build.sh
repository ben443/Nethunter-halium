#!/bin/bash
set -e

# Configuration
BUILD_DIR="$(pwd)/build"
SOURCES_DIR="$(pwd)/sources"
OVERLAYS_DIR="$(pwd)/overlays"
OUT_DIR="$(pwd)/build/out"
CONFIG_DIR="$(pwd)/build/config"
ROOTFS_DIR="$(pwd)/build/build/rootfs"
LOGS_DIR="$(pwd)/build/logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Parse arguments
DEVICE=""
BUILD_TYPE="device" # Default to device-specific build
API_LEVEL=""
GKI_VERSION=""
SKIP_LXC=false
HALIUM_ONLY=false
ROOTFS_ONLY=false

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
  echo ""
  echo "Available devices: (from Halium compatibility list)"
  ls -1 "$SOURCES_DIR/halium/devices" | grep -v README
  exit 1
}

# Process arguments
if [ $# -lt 1 ]; then
  print_usage
fi

TARGET="$1"
shift

# Check if the target is a GKI build
if [[ "$TARGET" == gki-* ]]; then
  BUILD_TYPE="gki"
  GKI_VERSION="${TARGET#gki-}"
  
  # Validate GKI version
  if [[ "$GKI_VERSION" != "5.10" ]]; then
    echo "Error: Unsupported GKI version: $GKI_VERSION"
    echo "Supported GKI versions: 5.10"
    exit 1
  fi
  
  # For GKI builds, we assume Android 12 (API 32)
  API_LEVEL="32"
  DEVICE="gki-$GKI_VERSION"
# Check if the target is a generic build
elif [[ "$TARGET" == generic-* ]]; then
  BUILD_TYPE="generic"
  API_LEVEL="${TARGET#generic-}"
  
  # Validate API level
  if [[ "$API_LEVEL" != "30" && "$API_LEVEL" != "32" ]]; then
    echo "Error: Unsupported API level: $API_LEVEL"
    echo "Supported API levels for generic builds: 30, 32"
    exit 1
  fi
  
  DEVICE="generic-$API_LEVEL"
else
  DEVICE="$TARGET"
fi

# Process additional options
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
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

# Log file for this build
BUILD_LOG="$LOGS_DIR/build-$DEVICE-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "====== Nethunter-Halium Build Started ======"
echo "Target: $DEVICE (Build type: $BUILD_TYPE)"
if [ "$BUILD_TYPE" = "generic" ]; then
  echo "API Level: $API_LEVEL"
elif [ "$BUILD_TYPE" = "gki" ]; then
  echo "GKI Version: $GKI_VERSION (API Level: $API_LEVEL)"
fi
echo "Options: Skip LXC: $SKIP_LXC, Halium only: $HALIUM_ONLY, Rootfs only: $ROOTFS_ONLY"
echo "Log file: $BUILD_LOG"
echo "=========================================="

# Create necessary directories
mkdir -p "$BUILD_DIR" "$OUT_DIR" "$CONFIG_DIR" "$ROOTFS_DIR"

# Step 1: Build Halium base
if [ "$ROOTFS_ONLY" = false ]; then
  echo "Building Halium base for $DEVICE..."
  cd "$SOURCES_DIR/halium"
  
  if [ "$BUILD_TYPE" = "generic" ]; then
    echo "Building generic Halium base for API level $API_LEVEL"
    # For generic builds, use the generic GSI builder with specific API level
    ./build-gsi.sh --android-api "$API_LEVEL" --gsi-variant halium
  elif [ "$BUILD_TYPE" = "gki" ]; then
    echo "Building GKI-based Halium for kernel $GKI_VERSION (API level $API_LEVEL)"
    # For GKI builds, use the GKI builder with specific kernel version
    ./build-gki.sh --gki-version "$GKI_VERSION" --android-api "$API_LEVEL" --gsi-variant halium
  else
    # For device-specific builds, use the regular halium-install script
    ./halium-install -p halium -d "$DEVICE"
  fi
fi

# Step 2: Create Droidian-based rootfs
if [ "$HALIUM_ONLY" = false ]; then
  echo "Creating Droidian-based rootfs..."
  cd "$SOURCES_DIR/droidian"
  
  # Choose architecture based on device or use arm64 for generic/GKI builds
  if [ "$BUILD_TYPE" = "generic" ] || [ "$BUILD_TYPE" = "gki" ]; then
    ARCH="arm64"
  else
    # For device-specific builds, determine architecture from device specs
    # This is simplified - in a real implementation, you'd need to query the device architecture
    ARCH="arm64"
  fi
  
  ./mkbootstrap \
    --arch "$ARCH" \
    --suite bookworm \
    --include droidian-base,phosh,kali-linux-default \
    --output "$ROOTFS_DIR/rootfs.tar.gz"
  
  # Extract rootfs
  mkdir -p "$ROOTFS_DIR/extracted"
  tar -xzf "$ROOTFS_DIR/rootfs.tar.gz" -C "$ROOTFS_DIR/extracted"
  
  # Step 3: Apply Nethunter customizations
  echo "Applying Nethunter customizations..."
  
  # Copy Nethunter tools and scripts
  mkdir -p "$ROOTFS_DIR/extracted/opt/nethunter"
  cp -r "$SOURCES_DIR/nethunter/nethunter-fs/opt/nethunter/"* "$ROOTFS_DIR/extracted/opt/nethunter/"
  
  # Copy Nethunter Phosh theme
  mkdir -p "$ROOTFS_DIR/extracted/usr/share/themes/nethunter"
  cp -r "$OVERLAYS_DIR/phosh-theme/"* "$ROOTFS_DIR/extracted/usr/share/themes/nethunter/"
  
  # Copy Kali tools overlay
  cp -r "$OVERLAYS_DIR/kali-tools/"* "$ROOTFS_DIR/extracted/"
  
  # Create Nethunter configuration file
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
    
    # Apply GKI-specific tweaks
    mkdir -p "$ROOTFS_DIR/extracted/etc/phosh/gki-tweaks"
    
    # Copy GKI overlay files if they exist
    if [ -d "$OVERLAYS_DIR/gki-$GKI_VERSION" ]; then
      cp -r "$OVERLAYS_DIR/gki-$GKI_VERSION/"* "$ROOTFS_DIR/extracted/"
    fi
    
    # Create GKI kernel module loader service
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

    # Create GKI module loader script
    mkdir -p "$ROOTFS_DIR/extracted/usr/local/bin"
    cat > "$ROOTFS_DIR/extracted/usr/local/bin/gki-load-modules" << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "Loading GKI-specific kernel modules..."

# Source the configuration
source /etc/nethunter.conf

# Check for presence of vendor modules
if [ -d "/vendor/lib/modules" ]; then
    for module in /vendor/lib/modules/*.ko; do
        modname=$(basename "$module")
        echo "Loading vendor module: $modname"
        insmod "$module" || echo "Failed to load $modname"
    done
fi

# Load additional GKI modules if present
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
    
    # Enable the service
    ln -sf "/etc/systemd/system/gki-module-loader.service" \
      "$ROOTFS_DIR/extracted/etc/systemd/system/multi-user.target.wants/gki-module-loader.service"
  else
    echo "DEVICE=\"$DEVICE\"" >> "$ROOTFS_DIR/extracted/etc/nethunter.conf"
  fi
  
  # Configure LXC containers if not skipped
  if [ "$SKIP_LXC" = false ]; then
    mkdir -p "$ROOTFS_DIR/extracted/var/lib/lxc/kali-nethunter"
    cat > "$ROOTFS_DIR/extracted/var/lib/lxc/kali-nethunter/config" << EOF
# Kali Nethunter LXC configuration
lxc.uts.name = kali-nethunter
lxc.rootfs.path = dir:/var/lib/lxc/kali-nethunter/rootfs
lxc.include = /usr/share/lxc/config/debian.common.conf

# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.name = eth0

# Mount points
lxc.mount.entry = /dev dev none bind,create=dir 0 0
lxc.mount.entry = /sys/kernel/security sys/kernel/security none ro,bind,optional 0 0
EOF
  
    # Create first-boot setup script
    cat > "$ROOTFS_DIR/extracted/usr/local/bin/nethunter-first-boot" << 'EOF'
#!/bin/bash
set -e

echo "Performing first-boot setup for Nethunter-Halium..."

# Read configuration
source /etc/nethunter.conf

# Display build information
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
  
  # Configure container for Nethunter tools
  chroot /var/lib/lxc/kali-nethunter/rootfs apt-get update
  chroot /var/lib/lxc/kali-nethunter/rootfs apt-get install -y kali-linux-default
  
  # Mark as initialized
  touch /var/lib/lxc/kali-nethunter/rootfs/.initialized
fi

# Apply Nethunter theme to Phosh
if [ -d /usr/share/themes/nethunter ]; then
  gsettings set org.gnome.desktop.interface gtk-theme 'nethunter'
  gsettings set org.gnome.desktop.wm.preferences theme 'nethunter'
fi

# Create desktop shortcuts for Nethunter tools
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

# Apply build-specific optimizations
if [ "$BUILD_TYPE" = "device" ]; then
  echo "Applying device-specific optimizations for $DEVICE..."
  # Device-specific optimizations would go here
elif [ "$BUILD_TYPE" = "gki" ]; then
  echo "Applying GKI-specific optimizations for kernel $GKI_VERSION..."
  
  # Check for and apply any GKI-specific tweaks
  if [ -d "/etc/phosh/gki-tweaks" ]; then
    for tweakscript in /etc/phosh/gki-tweaks/*.sh; do
      if [ -x "$tweakscript" ]; then
        echo "Running GKI tweak: $(basename $tweakscript)"
        "$tweakscript"
      fi
    done
  fi
fi

echo "First boot setup completed!"
EOF
  
    chmod +x "$ROOTFS_DIR/extracted/usr/local/bin/nethunter-first-boot"
  
    # Add to systemd to run on first boot
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
  
    # Enable the service
    ln -sf "/etc/systemd/system/nethunter-first-boot.service" \
      "$ROOTFS_DIR/extracted/etc/systemd/system/multi-user.target.wants/nethunter-first-boot.service"
  fi
  
  # Step 4: Repackage rootfs
  echo "Repackaging rootfs..."
  cd "$ROOTFS_DIR/extracted"
  find . | cpio -o -H newc | gzip > "$ROOTFS_DIR/rootfs.img"
  
  # Step 5: Combine with Halium system image
  echo "Combining with Halium system image..."
  mkdir -p "$OUT_DIR"
  
  if [ "$BUILD_TYPE" = "generic" ]; then
    # For generic builds, use a different approach to create the final image
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      --generic-android-api "$API_LEVEL" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  elif [ "$BUILD_TYPE" = "gki" ]; then
    # For GKI builds, use the GKI-specific installation method
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      --gki-version "$GKI_VERSION" \
      --android-api "$API_LEVEL" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  else
    # For device-specific builds
    "$SOURCES_DIR/halium/scripts/halium-install" \
      -p halium \
      -r "$ROOTFS_DIR/rootfs.img" \
      "$DEVICE" \
      "$OUT_DIR/nethunter-halium-$DEVICE.img"
  fi
fi

echo "Build complete! Output image: $OUT_DIR/nethunter-halium-$DEVICE.img"
echo "You can flash this image using ./flash.sh $DEVICE"