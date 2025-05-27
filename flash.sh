#!/bin/bash
set -e

# Configuration
OUT_DIR="$(pwd)/build/out"

# Parse arguments
print_usage() {
  echo "Usage: $0 <device|generic-api|gki-version> [options]"
  echo ""
  echo "Flash target:"
  echo "  <device>          Flash a device-specific image"
  echo "  generic-30        Flash a generic image for Android API level 30"
  echo "  generic-32        Flash a generic image for Android API level 32"
  echo "  gki-5.10          Flash a GKI image for Android 12 with kernel 5.10"
  echo ""
  echo "Options:"
  echo "  --skip-confirm    Skip confirmation prompt"
  echo "  --boot-params=<params>  Additional kernel boot parameters"
  echo ""
  echo "Available images:"
  ls -1 "$OUT_DIR" | grep "nethunter-halium-" | sed 's/nethunter-halium-\(.*\)\.img/\1/'
  exit 1
}

# Check if device is specified
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
  
  DEVICE="gki-$GKI_VERSION"
  # For GKI builds, we assume Android 12 (API 32)
  API_LEVEL="32"
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
  BUILD_TYPE="device"
fi

# Process additional options
SKIP_CONFIRM=false
BOOT_PARAMS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-confirm)
      SKIP_CONFIRM=true
      shift
      ;;
    --boot-params=*)
      BOOT_PARAMS="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

IMAGE_FILE="$OUT_DIR/nethunter-halium-$DEVICE.img"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "Error: Image file not found: $IMAGE_FILE"
  echo "Did you build the image with ./build.sh $DEVICE first?"
  exit 1
fi

if [ "$BUILD_TYPE" = "gki" ]; then
  echo "This will flash a GKI-based Nethunter-Halium build for kernel $GKI_VERSION (API level $API_LEVEL)"
elif [ "$BUILD_TYPE" = "generic" ]; then
  echo "This will flash a generic Nethunter-Halium build for API level $API_LEVEL"
else
  echo "This will flash Nethunter-Halium to your device: $DEVICE"
fi

echo "WARNING: This will erase all data on your device!"

if [ "$SKIP_CONFIRM" = false ]; then
  read -p "Are you sure you want to continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Check if device is connected
adb devices | grep -q "device$" || {
  echo "No device connected in ADB mode. Please connect your device and enable USB debugging."
  exit 1
}

# Reboot to bootloader
echo "Rebooting device to bootloader mode..."
adb reboot bootloader
sleep 5

# Wait for device to be detected in fastboot
fastboot devices | grep -q . || {
  echo "No device connected in fastboot mode. Please check your connection."
  exit 1
}

# For GKI builds, we need additional checks
if [ "$BUILD_TYPE" = "gki" ]; then
  # Check if the device has a GKI kernel
  KERNEL_VERSION=$(fastboot getvar kernel.version 2>&1 | grep "kernel.version" | awk '{print $2}')
  
  if [[ "$KERNEL_VERSION" != *"$GKI_VERSION"* ]]; then
    echo "WARNING: Device kernel version ($KERNEL_VERSION) doesn't match GKI version ($GKI_VERSION)."
    echo "This may cause compatibility issues."
    
    if [ "$SKIP_CONFIRM" = false ]; then
      read -p "Continue anyway? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
      fi
    fi
  fi
  
  # Check if the device supports dynamic partitions (required for GKI)
  DYNAMIC_PARTITIONS=$(fastboot getvar is-dynamic-partitions 2>&1 | grep "is-dynamic-partitions" | awk '{print $2}')
  
  if [[ "$DYNAMIC_PARTITIONS" != "true" ]]; then
    echo "ERROR: Device does not support dynamic partitions, which is required for GKI builds."
    exit 1
  fi
  
  # Set default boot parameters for GKI if none provided
  if [ -z "$BOOT_PARAMS" ]; then
    BOOT_PARAMS="androidboot.selinux=permissive androidboot.init_fatal_reboot_target=recovery"
  fi
# For generic builds, we need to check if the device supports the API level
elif [ "$BUILD_TYPE" = "generic" ]; then
  # Get device info to check API compatibility
  DEVICE_API=$(fastboot getvar ro.build.version.sdk 2>&1 | grep "ro.build.version.sdk" | awk '{print $2}')
  
  if [ -n "$DEVICE_API" ] && [ "$DEVICE_API" -lt "$API_LEVEL" ]; then
    echo "WARNING: Device API level ($DEVICE_API) is lower than the image API level ($API_LEVEL)."
    echo "This may cause compatibility issues."
    
    if [ "$SKIP_CONFIRM" = false ]; then
      read -p "Continue anyway? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
      fi
    fi
  fi
fi

# Flash the image
echo "Flashing Nethunter-Halium to $DEVICE..."

if [ "$BUILD_TYPE" = "gki" ]; then
  # For GKI builds, we need to use a different flashing method
  echo "Using GKI-specific flashing method..."
  
  # Flash system image
  fastboot flash system "$IMAGE_FILE"
  
  # Flash or update boot parameters if needed
  if [ -n "$BOOT_PARAMS" ]; then
    echo "Setting boot parameters: $BOOT_PARAMS"
    CURRENT_CMDLINE=$(fastboot getvar androidboot.boot_devices 2>&1 | grep "androidboot.boot_devices" | cut -d: -f2 | tr -d ' ')
    NEW_CMDLINE="$CURRENT_CMDLINE $BOOT_PARAMS"
    fastboot --cmdline "$NEW_CMDLINE" boot
  fi
else
  # Standard flashing for device-specific and generic builds
  fastboot flash system "$IMAGE_FILE"
fi

# Reboot the device
echo "Flashing complete. Rebooting device..."
fastboot reboot

echo "Nethunter-Halium has been flashed to your device!"
echo "The first boot may take several minutes as it completes setup."