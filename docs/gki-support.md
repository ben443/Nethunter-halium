# GKI Support in Nethunter-Halium

This document details the implementation of Generic Kernel Image (GKI) support for Android 12 devices with kernel 5.10 in Nethunter-Halium.

## What is GKI?

The Generic Kernel Image (GKI) is Google's approach to standardize the Android kernel across devices. Starting with Android 12, many devices use a standard GKI kernel (typically version 5.10 for Android 12) with vendor-specific modules loaded separately.

Benefits of GKI include:
- Standard kernel interface across devices
- Regular security updates from Google
- Improved compatibility across different hardware
- Simplified kernel development

## GKI Support in Nethunter-Halium

Nethunter-Halium now supports building images specifically tailored for GKI-based devices running Android 12 with kernel 5.10. This support includes:

1. Specialized build process for GKI kernels
2. Runtime module loading for vendor-specific hardware
3. Fixes for common issues on GKI devices
4. Optimized system configuration for GKI compatibility

## Building for GKI Devices

To build Nethunter-Halium for a GKI device, use:

```bash
./build.sh gki-5.10
```

This will create an image compatible with Android 12 devices using the 5.10 GKI kernel.

## Flashing to GKI Devices

To flash the GKI build to your device:

```bash
./flash.sh gki-5.10
```

You may need additional boot parameters depending on your device:

```bash
./flash.sh gki-5.10 --boot-params="androidboot.selinux=permissive androidboot.init_fatal_reboot_target=recovery"
```

## Technical Implementation

### GKI Module Loader

The GKI implementation includes a specialized module loader service that runs at boot time to handle loading vendor-specific kernel modules. This service:

1. Detects and loads vendor modules from `/vendor/lib/modules`
2. Loads additional GKI-specific modules if present
3. Configures proper permissions for hardware devices

### Hardware Compatibility Fixes

Nethunter-Halium includes specific fixes for common issues on GKI devices:

1. **Sensors**: Fixes for sensor permissions and HAL compatibility
2. **Audio**: Configuration for audio HAL and PulseAudio integration
3. **Graphics**: Proper setup for graphics acceleration and display
4. **Networking**: WiFi, mobile data, and USB tethering support

These fixes are applied automatically during first boot.

### Dynamic Partitions

GKI devices typically use dynamic partitions. The flashing process has been updated to:

1. Detect if the device supports dynamic partitions
2. Use the appropriate flashing method based on partition layout
3. Apply the correct boot parameters for GKI kernels

## Troubleshooting GKI Installations

### Common Issues

1. **Boot Loop**: May indicate incompatible kernel or missing modules
   - Solution: Check if your device truly uses a GKI 5.10 kernel with `adb shell uname -r`

2. **No Hardware Functionality**: Likely a module loading issue
   - Solution: Check the GKI module loader logs with `journalctl -u gki-module-loader`

3. **SELinux Denials**: Common with GKI kernels
   - Solution: Add `androidboot.selinux=permissive` to boot parameters

### Checking Compatibility

To verify if your device is compatible with the GKI build:

1. Check kernel version:
   ```bash
   adb shell uname -r
   # Should show 5.10.x
   ```

2. Verify it's a true GKI kernel:
   ```bash
   adb shell cat /proc/cmdline
   # Should contain "androidboot.hardware.platform"
   ```

3. Check for dynamic partition support:
   ```bash
   adb shell getprop ro.boot.dynamic_partitions
   # Should return "true"
   ```

## Development Notes

When adding support for new GKI versions:

1. Create a new overlay directory in `overlays/gki-<version>/`
2. Add necessary fixes and tweaks in `etc/phosh/gki-tweaks/`
3. Update the build and flash scripts to recognize the new GKI version
4. Test thoroughly on compatible devices

## Future Plans

Future GKI support will include:

1. Support for newer GKI kernel versions (5.15, 5.16, etc.)
2. Improved hardware compatibility across more devices
3. Better integration with Android 13+ GKI implementations
4. Automated detection of device-specific requirements

## Contributing

If you have a GKI-based device and want to contribute:

1. Test the GKI build on your device
2. Document any additional fixes or parameters needed
3. Submit your findings as a pull request with any necessary scripts or configurations