#!/bin/bash
set -e

echo "Setting up build environment for Nethunter-Halium..."

# Install dependencies
if [ -f /etc/debian_version ]; then
  sudo apt update
  sudo apt install -y git make curl wget gdisk parted \
    adb fastboot android-sdk-libsparse-utils \
    docker.io docker-compose python3 python3-pip \
    qemu-user-static debootstrap schroot lxc lxd \
    build-essential devscripts crossbuild-essential-arm64 \
    android-sdk-platform-tools-common  \
    repo python3-pycryptodome gzip lz4
elif [ -f /etc/arch-release ]; then
  sudo pacman -Syu --needed git make curl wget gdisk parted \
    android-tools docker docker-compose python python-pip \
    qemu-user-static arch-install-scripts lxc \
    android-sdk-platform-tools repo python-pycryptodome lz4
else
  echo "Unsupported distribution. Please install the required dependencies manually."
  exit 1
fi

# Setup Docker for non-root user
# Check if systemd is running before using systemctl
if command -v systemctl >/dev/null && systemctl is-system-running >/dev/null 2>&1; then
  sudo systemctl enable docker
  # Only start if systemd is actively running
  if [ "$(systemctl is-system-running)" != "offline" ]; then
    sudo systemctl start docker
  fi
else
  echo "Systemd is not available or not running."
  echo "You'll need to start docker manually with 'sudo service docker start' or equivalent."
fi

sudo usermod -aG docker "$USER"
echo "You may need to log out and log back in for docker group changes to take effect."

# Clone required repositories
mkdir -p sources
cd sources

# Clone Halium (using the correct repository URL)
if [ ! -d "halium" ]; then
  git clone https://github.com/Halium/halium-boot.git halium
else
  (cd halium && git pull)
fi

# Add GSI building tools to Halium
if [ ! -d "halium/gsi-tools" ]; then
  mkdir -p halium/gsi-tools
  git clone https://github.com/phhusson/treble_experimentations.git halium/gsi-tools/treble_exp
  cp halium/gsi-tools/treble_exp/build-gsi.sh halium/build-gsi.sh
  chmod +x halium/build-gsi.sh
fi

# Clone Droidian
if [ ! -d "droidian" ]; then
  git clone https://github.com/droidian/droidian
else
  (cd droidian && git pull)
fi

# Clone Kali Nethunter
if [ ! -d "nethunter" ]; then
  git clone https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-project.git nethunter
else
  (cd nethunter && git pull)
fi

# Create necessary directories
cd ..
mkdir -p build/{rootfs,config,out,logs}
mkdir -p overlays/{phosh-theme,kali-tools,devices}

# Create device-specific overlay directories for commonly used devices
mkdir -p overlays/devices/generic-30
mkdir -p overlays/devices/generic-32
mkdir -p overlays/gki-5.10

# Create a script to help with adding device overlays
cat > add-device-overlay.sh << 'EOF'
#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <device>"
  exit 1
fi

DEVICE="$1"
OVERLAY_DIR="overlays/devices/$DEVICE"

mkdir -p "$OVERLAY_DIR"
echo "Created device overlay directory: $OVERLAY_DIR"
echo "You can now add device-specific customizations to this directory."
echo "These customizations will be applied when building for this device."
EOF

chmod +x add-device-overlay.sh

# Fix for locales warning
if [ -f /etc/debian_version ]; then
  if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    echo "Setting up locales to avoid warnings..."
    sudo apt install -y locales
    sudo locale-gen en_US.UTF-8
  fi
fi

echo "Setup complete! You can now build specific device images or generic API images:"
echo ""
echo "For device-specific builds:"
echo "  ./build.sh <device>"
echo ""
echo "For generic API builds:"
echo "  ./build.sh generic-30  # For Android 11 (API 30)"
echo "  ./build.sh generic-32  # For Android 12 (API 32)"
echo ""
echo "For GKI builds:"
echo "  ./build.sh gki-5.10    # For Android 12 with GKI kernel 5.10"
