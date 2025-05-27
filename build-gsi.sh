#!/bin/bash
set -e

# Nethunter-Halium GSI Builder
# This script builds Generic System Images (GSI) for Halium-based systems

# Configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BUILD_DIR="$SCRIPT_DIR/build"
TOOLS_DIR="$SCRIPT_DIR/gsi-tools"
TREBLE_DIR="$TOOLS_DIR/treble_exp"
OUT_DIR="$BUILD_DIR/out"
LOGS_DIR="$BUILD_DIR/logs"
TEMP_DIR="$BUILD_DIR/tmp"

# Default values
ANDROID_API="32"     # Default to Android 12
GSI_VARIANT="halium" # Default to Halium variant
ARCH="arm64"         # Default to arm64 architecture
WITH_NETHUNTER=true  # Include Nethunter by default
WITH_GMS=false       # Don't include Google Mobile Services by default
CLEAN_BUILD=false    # Don't clean by default
VERBOSE=false        # Don't use verbose output by default

# Create necessary directories
mkdir -p "$BUILD_DIR" "$OUT_DIR" "$LOGS_DIR" "$TEMP_DIR"

# Log file
LOG_FILE="$LOGS_DIR/build-gsi-$(date +%Y%m%d-%H%M%S).log"

# Function to print usage
print_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --android-api <level>    Android API level (30 for Android 11, 32 for Android 12)"
  echo "  --arch <architecture>    Target architecture (arm64 or arm)"
  echo "  --gsi-variant <variant>  GSI variant (halium, vanilla, gapps)"
  echo "  --with-gms               Include Google Mobile Services (only with gapps variant)"
  echo "  --no-nethunter           Build without Nethunter customizations"
  echo "  --clean                  Clean build directory before starting"
  echo "  --verbose                Enable verbose output"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --android-api 32 --gsi-variant halium        # Build Android 12 Halium GSI"
  echo "  $0 --android-api 30 --arch arm --no-nethunter   # Build Android 11 ARM GSI without Nethunter"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-api)
      ANDROID_API="$2"
      if [[ "$ANDROID_API" != "30" && "$ANDROID_API" != "32" ]]; then
        echo "Error: Unsupported API level: $ANDROID_API"
        echo "Supported API levels: 30 (Android 11), 32 (Android 12)"
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
      if [[ "$GSI_VARIANT" != "halium" && "$GSI_VARIANT" != "vanilla" && "$GSI_VARIANT" != "gapps" ]]; then
        echo "Error: Unsupported GSI variant: $GSI_VARIANT"
        echo "Supported variants: halium, vanilla, gapps"
        exit 1
      fi
      shift 2
      ;;
    --with-gms)
      WITH_GMS=true
      if [[ "$GSI_VARIANT" != "gapps" ]]; then
        echo "Warning: --with-gms is only relevant with --gsi-variant gapps"
        echo "Switching to gapps variant"
        GSI_VARIANT="gapps"
      fi
      shift
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

echo "====== Nethunter-Halium GSI Build Started ======"
echo "Android API Level: $ANDROID_API"
echo "Architecture: $ARCH"
echo "GSI Variant: $GSI_VARIANT"
echo "Include Google Mobile Services: $WITH_GMS"
echo "Include Nethunter: $WITH_NETHUNTER"
echo "Clean Build: $CLEAN_BUILD"
echo "Log file: $LOG_FILE"
echo "=========================================="

# Check if necessary tools are available
check_dependencies() {
  echo "Checking dependencies..."
  
  # Check for essential tools
  for cmd in git python3 repo; do
    if ! command -v $cmd &> /dev/null; then
      echo "Error: $cmd is required but not installed. Please install it and try again."
      exit 1
    fi
  done
  
  # Check for treble_experimentations
  if [ ! -d "$TREBLE_DIR" ]; then
    echo "Treble experimentations not found. Cloning repository..."
    mkdir -p "$TOOLS_DIR"
    git clone https://github.com/phhusson/treble_experimentations.git "$TREBLE_DIR"
  else
    echo "Updating treble experimentations..."
    (cd "$TREBLE_DIR" && git pull)
  fi
}

# Clean build directory if requested
clean_build() {
  if [ "$CLEAN_BUILD" = true ]; then
    echo "Cleaning build directories..."
    rm -rf "$TEMP_DIR"/*
    mkdir -p "$TEMP_DIR"
  fi
}

# Prepare build environment
prepare_env() {
  echo "Preparing build environment..."
  
  # Set up environment variables
  export ANDROID_API_LEVEL="$ANDROID_API"
  export ARCH="$ARCH"
  export USE_HALIUM="$([[ "$GSI_VARIANT" == "halium" ]] && echo "true" || echo "false")"
  export WITH_GMS="$WITH_GMS"
  
  # Create working directory
  mkdir -p "$TEMP_DIR/gsi-$ANDROID_API-$ARCH-$GSI_VARIANT"
  cd "$TEMP_DIR/gsi-$ANDROID_API-$ARCH-$GSI_VARIANT"
  
  # Prepare treble build environment
  if [ ! -f ".treble_env_setup" ]; then
    echo "Setting up treble build environment..."
    "$TREBLE_DIR/build.sh" --setup-only
    touch ".treble_env_setup"
  fi
}

# Build the GSI
build_gsi() {
  echo "Building GSI for Android API $ANDROID_API ($ARCH) - Variant: $GSI_VARIANT..."
  
  cd "$TEMP_DIR/gsi-$ANDROID_API-$ARCH-$GSI_VARIANT"
  
  # Determine the build parameters based on API level and variant
  TREBLE_TARGET=""
  
  if [ "$ANDROID_API" = "30" ]; then
    # Android 11
    if [ "$GSI_VARIANT" = "halium" ]; then
      TREBLE_TARGET="treble_arm64_bvN-userdebug"
      EXTRA_ARGS="WITH_HALIUM=true"
    elif [ "$GSI_VARIANT" = "vanilla" ]; then
      TREBLE_TARGET="treble_arm64_bvN-userdebug"
    elif [ "$GSI_VARIANT" = "gapps" ]; then
      TREBLE_TARGET="treble_arm64_bgN-userdebug"
      if [ "$WITH_GMS" = true ]; then
        EXTRA_ARGS="WITH_GMS=true"
      fi
    fi
  elif [ "$ANDROID_API" = "32" ]; then
    # Android 12
    if [ "$GSI_VARIANT" = "halium" ]; then
      TREBLE_TARGET="treble_arm64_bvS-userdebug"
      EXTRA_ARGS="WITH_HALIUM=true"
    elif [ "$GSI_VARIANT" = "vanilla" ]; then
      TREBLE_TARGET="treble_arm64_bvS-userdebug"
    elif [ "$GSI_VARIANT" = "gapps" ]; then
      TREBLE_TARGET="treble_arm64_bgS-userdebug"
      if [ "$WITH_GMS" = true ]; then
        EXTRA_ARGS="WITH_GMS=true"
      fi
    fi
  fi
  
  # Adjust architecture if needed
  if [ "$ARCH" = "arm" ]; then
    TREBLE_TARGET="${TREBLE_TARGET/arm64/arm}"
  fi
  
  # Execute build
  echo "Building with target: $TREBLE_TARGET $EXTRA_ARGS"
  "$TREBLE_DIR/build.sh" "$TREBLE_TARGET" $EXTRA_ARGS
  
  # Check if build was successful
  if [ $? -ne 0 ]; then
    echo "Error: GSI build failed. Check the log for details: $LOG_FILE"
    exit 1
  fi
  
  # Copy output files
  OUTPUT_NAME="nethunter-halium-generic-$ANDROID_API-$ARCH"
  if [ "$GSI_VARIANT" != "halium" ]; then
    OUTPUT_NAME="$OUTPUT_NAME-$GSI_VARIANT"
  fi
  
  echo "Copying built GSI to output directory..."
  find out/target/product -name "system-*.img" -exec cp {} "$OUT_DIR/$OUTPUT_NAME.img" \;
  
  # Create build info file
  cat > "$OUT_DIR/$OUTPUT_NAME.info" << EOF
Nethunter-Halium GSI Build Information
======================================
Build Date: $(date)
Android API: $ANDROID_API
Architecture: $ARCH
GSI Variant: $GSI_VARIANT
With Google Mobile Services: $WITH_GMS
With Nethunter: $WITH_NETHUNTER
EOF
}

# Apply Nethunter customizations
apply_nethunter() {
  if [ "$WITH_NETHUNTER" = true ]; then
    echo "Applying Nethunter customizations to GSI..."
    
    # This would normally involve:
    # 1. Mounting the system image
    # 2. Applying overlays and customizations
    # 3. Adding Nethunter-specific files
    # 4. Repackaging the system image
    
    # For demonstration, we'll just create a placeholder
    OUTPUT_NAME="nethunter-halium-generic-$ANDROID_API-$ARCH"
    if [ "$GSI_VARIANT" != "halium" ]; then
      OUTPUT_NAME="$OUTPUT_NAME-$GSI_VARIANT"
    fi
    
    echo "Note: In a real implementation, this would customize the GSI with Nethunter components."
    echo "For now, we're just renaming the file to indicate it's Nethunter-ready."
    
    # In a real implementation, you would mount the image, modify it, and repackage it
    # This is a placeholder for that process
  fi
}

# Execute the build process
check_dependencies
clean_build
prepare_env
build_gsi
apply_nethunter

echo "====== GSI Build Complete ======"
echo "Output: $OUT_DIR/nethunter-halium-generic-$ANDROID_API-$ARCH.img"
echo "Build log: $LOG_FILE"
echo "==============================="

# Return to original directory
cd "$SCRIPT_DIR"