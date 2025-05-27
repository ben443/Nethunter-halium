#!/bin/bash
#
# Fix graphics on GKI 5.10 devices
# This script addresses common graphics issues on Android 12 GKI devices

set -e

echo "Fixing graphics for GKI 5.10 devices..."

# Check if graphics HAL service is running in Android container
if lxc-attach -n android -- getprop init.svc.vendor.hwcomposer-2-4 | grep -q running; then
  echo "Vendor HWComposer service is running in Android container"
else
  echo "Attempting to start HWComposer service..."
  lxc-attach -n android -- start vendor.hwcomposer-2-4 || true
fi

# Fix permissions for graphics devices
for gfx_dev in /dev/graphics/* /dev/ion /dev/dri/* /dev/kgsl*; do
  if [ -e "$gfx_dev" ]; then
    echo "Setting permissions for $gfx_dev"
    chmod 666 "$gfx_dev"
  fi
done

# Set up Wayland socket directory with proper permissions
mkdir -p /run/user/100000
chmod 700 /run/user/100000
chown 100000:100000 /run/user/100000

# Configure environment variables for graphics
cat > /etc/environment.d/90-gki-graphics.conf << EOF
# GKI 5.10 Graphics Environment Variables
XDG_RUNTIME_DIR=/run/user/100000
WAYLAND_DISPLAY=wayland-0
EGL_PLATFORM=wayland
QT_QPA_PLATFORM=wayland
GBM_BACKEND=android
CLUTTER_BACKEND=wayland
COGL_RENDERER=gles2
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
MOZ_ENABLE_WAYLAND=1
NO_AT_BRIDGE=1
EOF

# Configure Phosh to use the Android GPU
mkdir -p /etc/phosh
cat > /etc/phosh/phoc.ini << EOF
[core]
xwayland=true

[output:DSI-1]
scale = 2

[output:Virtual-1]
mode = 1080x2340
scale = 2

[xwayland]
cursor-theme=Adwaita
cursor-size=24

[android]
enable-hwc = true
use-gles2 = true
EOF

# Configure video acceleration
if [ -e /dev/video-dec ] || [ -e /dev/video-enc ]; then
  echo "Setting up video acceleration..."
  chmod 666 /dev/video-*
  
  # Link Android media libraries if needed
  mkdir -p /usr/lib/droid-vendor-overlay
  for lib in libmedia.so libstagefright.so libcodec2.so; do
    ANDROID_LIB=$(find /android/system -name "$lib" | head -n 1)
    if [ -n "$ANDROID_LIB" ]; then
      ln -sf "$ANDROID_LIB" "/usr/lib/droid-vendor-overlay/$lib"
    fi
  done
fi

# Fix potential vsync issues by creating dummy node
if [ ! -e /dev/sw_sync ]; then
  echo "Creating dummy sw_sync device node..."
  mknod -m 666 /dev/sw_sync c 10 31
fi

echo "Graphics fixes applied for GKI 5.10 devices"