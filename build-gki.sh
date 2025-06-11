#!/bin/bash
set -e

# Nethunter-Halium GKI Builder
# This script builds GKI-based system images for Halium-based systems

# Configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BUILD_DIR="$SCRIPT_DIR/build"
TOOLS_DIR="$SCRIPT_DIR/gki-tools"
OUT_DIR="$BUILD_DIR/out"
LOGS_DIR="$BUILD_DIR/logs"
TEMP_DIR="$BUILD_DIR/tmp"
KERNEL_SRC_DIR="$BUILD_DIR/kernel"

# Default values
GKI_VERSION="5.10"    # Default kernel version
ANDROID_API="32"      # Default to Android 12
GSI_VARIANT="halium"  # Default to Halium variant
ARCH="arm64"          # Default to arm64 architecture
WITH_NETHUNTER=true   # Include Nethunter by default
CLEAN_BUILD=false     # Don't clean by default
VERBOSE=false         # Don't use verbose output by default
JOBS=$(nproc)         # Allow overriding with --jobs

# Create necessary directories
mkdir -p "$BUILD_DIR" "$OUT_DIR" "$LOGS_DIR" "$TEMP_DIR"

# Log file
LOG_FILE="$LOGS_DIR/build-gki-$(date +%Y%m%d-%H%M%S).log"

# Function to print usage
print_usage() {
  echo "Usage: build-gki.sh [options]"
  echo ""
  echo "Options:"
  echo "  --gki-version <version>  GKI kernel version (5.10 supported)"
  echo "  --android-api <level>    Android API level (32 for Android 12)"
  echo "  --arch <architecture>    Target architecture (arm64 or arm)"
  echo "  --gsi-variant <variant>  GSI variant (halium, vanilla)"
  echo "  --no-nethunter           Build without Nethunter customizations"
  echo "  --clean                  Clean build directory before starting"
  echo "  --verbose                Enable verbose output"
  echo "  --jobs <num>             Number of threads to use for kernel build"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./build-gki.sh --gki-version 5.10 --android-api 32           # Build Android 12 GKI 5.10 Halium image"
  echo "  ./build-gki.sh --gki-version 5.10 --gsi-variant vanilla      # Build vanilla GKI 5.10 image"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gki-version)
      GKI_VERSION="$2"
      if [[ "$GKI_VERSION" != "5.10" ]]; then
        echo "Error: Unsupported GKI version: $GKI_VERSION"
        echo "Supported GKI versions: 5.10"
        exit 1
      fi
      shift 2
      ;;
    --android-api)
      ANDROID_API="$2"
      if [[ "$ANDROID_API" != "32" ]]; then
        echo "Error: Unsupported API level for GKI: $ANDROID_API"
        echo "Supported API levels for GKI: 32 (Android 12)"
        exit 1
      fi
      shift 2
      ;;
    --arch)
      ARCH="$2"
      if [[ "$ARCH" != "arm64" && "$ARCH" != "arm" ]]; then
        echo "Error: Unsupported architecture: $ARCH"
        echo "Supported architectures: arm64, arm"
        exit 1
      fi
      shift 2
      ;;
    --gsi-variant)
      GSI_VARIANT="$2"
      if [[ "$GSI_VARIANT" != "halium" && "$GSI_VARIANT" != "vanilla" ]]; then
        echo "Error: Unsupported GSI variant for GKI: $GSI_VARIANT"
        echo "Supported variants for GKI: halium, vanilla"
        exit 1
      fi
      shift 2
      ;;
    --no-nethunter)
      WITH_NETHUNTER=false
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    --help)
      print_usage
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

# Set up logging
if [ "$VERBOSE" = true ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
else
  exec > >(tee -a "$LOG_FILE" >/dev/null) 2>&1
fi

echo "====== Nethunter-Halium GKI Build Started ======"
echo "GKI Kernel Version: $GKI_VERSION"
echo "Android API Level: $ANDROID_API"
echo "Architecture: $ARCH"
echo "GSI Variant: $GSI_VARIANT"
echo "Include Nethunter: $WITH_NETHUNTER"
echo "Clean Build: $CLEAN_BUILD"
echo "Log file: $LOG_FILE"
echo "Jobs: $JOBS"
echo "=========================================="

# Function to check and install dependencies
check_dependencies() {
  echo "Checking dependencies..."
  local deps=(git python3 repo make gcc bc bison flex openssl libssl-dev)
  local missing=()
  for cmd in "${deps[@]}"; do
    if ! command -v $cmd &> /dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    echo "Error: Missing dependencies: ${missing[*]}"
    echo "Please install them using your package manager (e.g., sudo apt-get install ${missing[*]})"
    exit 1
  fi

  mkdir -p "$TOOLS_DIR"

  # Check for GKI kernel source
  if [ ! -d "$KERNEL_SRC_DIR" ]; then
    echo "GKI kernel source not found. Cloning repository..."
    mkdir -p "$KERNEL_SRC_DIR"
    if ! git clone https://android.googlesource.com/kernel/common -b android12-5.10 "$KERNEL_SRC_DIR"; then
      echo "Error: Failed to clone the kernel source. Exiting."
      exit 1
    fi
  fi
}

# Clean build directory if requested
clean_build() {
  if [ "$CLEAN_BUILD" = true ]; then
    echo "Cleaning build directories..."
    rm -rf "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API"
    mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API"
  else
    mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API"
  fi
}

# Build the GKI kernel
build_kernel() {
  echo "Building GKI kernel version $GKI_VERSION for Android API $ANDROID_API..."

  cd "$KERNEL_SRC_DIR"

  if [ "$ARCH" = "arm64" ]; then
    KERNEL_CONFIG="gki_defconfig"
    CROSS_COMPILE="aarch64-linux-gnu-"
  else
    KERNEL_CONFIG="gki_defconfig"
    CROSS_COMPILE="arm-linux-gnueabi-"
  fi

  if [ "$GSI_VARIANT" = "halium" ]; then
    echo "Applying Halium-specific kernel configurations..."
    # Placeholder: apply Halium-specific patches here if available
  fi

  echo "Configuring kernel..."
  if ! make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$KERNEL_CONFIG"; then
    echo "Error: Kernel configuration failed."
    exit 1
  fi

  echo "Building kernel with $JOBS jobs..."
  if ! make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS"; then
    echo "Error: Kernel build failed. Check the log for details: $LOG_FILE"
    exit 1
  fi

  # Copy kernel to output directory
  echo "Copying kernel to build directory..."
  mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/kernel"
  cp arch/"$ARCH"/boot/Image "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/kernel/" || {
    echo "Error: Failed to copy kernel image."
    exit 1
  }

  # Copy kernel modules
  echo "Copying kernel modules..."
  mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/modules"
  find . -name "*.ko" -exec cp {} "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/modules/" \;
}

# Build the GKI-based system image (placeholder)
build_system_image() {
  echo "Building GKI-based system image..."

  # Placeholder: in a real implementation, integrate with AOSP build system
  echo "Creating placeholder system image..."

  mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/system/bin"
  mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/system/etc"
  mkdir -p "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/system/lib"

  dd if=/dev/zero of="$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/system.img" bs=1M count=100
}

# Apply Nethunter customizations (placeholder)
apply_nethunter() {
  if [ "$WITH_NETHUNTER" = true ]; then
    echo "Applying Nethunter customizations to GKI system image..."
    # Placeholder for real Nethunter integration steps
    echo "Note: In a real implementation, this would customize the system image with Nethunter components."
  fi
}

# Create the final image
create_final_image() {
  echo "Creating final GKI-based system image..."

  OUTPUT_NAME="nethunter-halium-gki-$GKI_VERSION-$ANDROID_API-$ARCH"
  if [ "$GSI_VARIANT" != "halium" ]; then
    OUTPUT_NAME="$OUTPUT_NAME-$GSI_VARIANT"
  fi

  cp "$TEMP_DIR/gki-$GKI_VERSION-$ANDROID_API/system.img" "$OUT_DIR/$OUTPUT_NAME.img"

  cat > "$OUT_DIR/$OUTPUT_NAME.info" << EOF
Nethunter-Halium GKI Build Information
======================================
Build Date: $(date)
GKI Version: $GKI_VERSION
Android API: $ANDROID_API
Architecture: $ARCH
GSI Variant: $GSI_VARIANT
With Nethunter: $WITH_NETHUNTER
EOF
}

# Execute the build process
check_dependencies
clean_build
build_kernel
build_system_image
apply_nethunter
create_final_image

echo "====== GKI Build Complete ======"
echo "Output: $OUT_DIR/nethunter-halium-gki-$GKI_VERSION-$ANDROID_API-$ARCH.img"
echo "Build log: $LOG_FILE"
echo "====================================="

cd "$SCRIPT_DIR"
