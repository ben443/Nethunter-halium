# Generic Builds for Nethunter-Halium

This document explains how to build and use the generic API-level and GKI-based builds for Nethunter-Halium, similar to Droidian's approach.

## What are Generic Builds?

Generic builds are device-agnostic images that work on a range of devices that support a specific Android API level. Instead of being built for a specific device model, they use the Generic System Image (GSI) approach to provide a base system that works across compatible devices.

## Available Build Types

Nethunter-Halium currently supports three generic build types:

- **API 30**: For devices running Android 11
- **API 32**: For devices running Android 12/12L
- **GKI 5.10**: For devices running Android 12/12L with a Generic Kernel Image (GKI) 5.10 kernel

## Building Generic Images

To build a generic image for a specific API level or GKI version, use the `build.sh` script with the appropriate parameter:

```bash
# Build for API level 30 (Android 11)
./build.sh generic-30

# Build for API level 32 (Android 12/12L)
./build.sh generic-32

# Build for GKI 5.10 kernel with Android 12
./build.sh gki-5.10
```

The build process for generic images is similar to device-specific builds but uses the GSI or GKI approach instead of device-specific HAL implementations.

## Device Compatibility

### For API-level Generic Builds

A device is generally compatible with a generic API-level build if:

1. It supports Project Treble
2. It runs the same or higher API level as the generic build
3. It has an unlockable bootloader

### For GKI-based Builds

A device is compatible with a GKI-based build if:

1. It runs Android 12 or higher
2. It uses a GKI kernel (typically 5.10 for Android 12)
3. It supports dynamic partitions
4. It has an unlockable bootloader

### Checking Compatibility

To check if your device supports Project Treble:

```bash
adb shell getprop ro.treble.enabled
```

To check your device's API level:

```bash
adb shell getprop ro.build.version.sdk
```

To check if your device has a GKI kernel:

```bash
adb shell uname -r
# Look for a 5.10.x version
```

To check if your device supports dynamic partitions:

```bash
adb shell getprop ro.boot.dynamic_partitions
```

## Installing Generic Builds

To flash a generic build to your device:

```bash
# Flash the generic API 30 build
./flash.sh generic-30

# Flash the generic API 32 build
./flash.sh generic-32

# Flash the GKI 5.10 build
./flash.sh gki-5.10
```

For GKI builds, you may need to specify additional kernel boot parameters:

```bash
./flash.sh gki-5.10 --boot-params="androidboot.selinux=permissive androidboot.init_fatal_reboot_target=recovery"
```

## Why Use GKI Builds?

GKI (Generic Kernel Image) builds offer several advantages:

1. **Better Hardware Support**: GKI kernels have standardized driver interfaces
2. **Improved Security**: GKI kernels receive regular security updates from Google
3. **Future Compatibility**: GKI is the future direction for Android kernels
4. **Simplified Maintenance**: One kernel works across multiple device types

## GKI-specific Considerations

When using GKI-based builds:

1. **Module Loading**: GKI kernels use a different approach to loading hardware-specific modules
2. **Vendor Modules**: Some vendor<CodePalFile path="docs/generic-builds.md" language="markdown" description="Updated documentation for generic builds including GKI Android 12 kernel 5.10 support" tags="documentation, generic-builds, gki, android12, kernel5.10" related-files="docs/building.md, docs/installation.md">
2. **Vendor Modules**: Some vendor-specific modules may need to be loaded differently
3. **SELinux**: Most GKI implementations require SELinux to be set to permissive mode
4. **Boot Parameters**: Additional boot parameters may be required for proper functionality

Nethunter-Halium's GKI implementation handles these considerations automatically through the GKI module loader service that runs during boot.

## Troubleshooting Generic Builds

### Common Issues with API-level Generic Builds

1. **Device Boots to Recovery**: The system partition may be incompatible. Try using a different GSI variant.
2. **No Graphics/Display**: The display HAL may be incompatible. Try adding `androidboot.sf.no-bl-update=1` to the kernel command line.
3. **No Network**: Network interfaces may not be properly detected. Check the network service status with `systemctl status NetworkManager`.

### Common Issues with GKI Builds

1. **Boot Loop**: The kernel may be incompatible. Verify your device is using a true GKI kernel.
2. **Hardware Functionality Issues**: Some hardware-specific modules may not be loading. Check the status of the GKI module loader service with `systemctl status gki-module-loader`.
3. **SELinux Denials**: GKI builds often require SELinux to be set to permissive mode. Add `androidboot.selinux=permissive` to the kernel command line.

### Logs to Check

When troubleshooting, check these logs:

```bash
# Check GKI module loader logs
journalctl -u gki-module-loader

# Check Halium container logs
journalctl -u lxc@android

# Check first-boot setup logs
journalctl -u nethunter-first-boot
```

## Contributing Compatibility Reports

If you successfully run a generic build on your device, please contribute your experience by:

1. Creating a compatibility report in the `docs/compatibility/` directory
2. Including any special parameters or tweaks needed
3. Submitting a pull request with your findings

This helps expand the database of known-compatible devices and improves the project for everyone.