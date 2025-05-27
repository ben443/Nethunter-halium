# Nethunter-Halium

This project combines Kali Nethunter-Pro with Halium and LXC containers, similar to how Droidian works, but with the Nethunter Pro theming applied to the Phosh interface.

## Overview

Nethunter-Halium uses:
- Halium as the base (Android HAL compatibility layer)
- LXC containers for running Linux applications
- Phosh for the mobile shell UI
- Nethunter Pro theming and penetration testing tools

## Build Options

Nethunter-Halium supports two build approaches:

1. **Device-specific builds**: Optimized for a particular device model
2. **Generic API builds**: Works on a range of devices that support a specific Android API level

### Generic API Builds

Like Droidian, Nethunter-Halium now supports generic builds for specific Android API levels:

- **API 30 (Android 11)**: Compatible with most Android 11 devices that support Project Treble
- **API 32 (Android 12/12L)**: Compatible with most Android 12/12L devices that support Project Treble

## Requirements

- A device with Halium support (for device-specific builds) or Project Treble support (for generic builds)
- Linux development environment
- 20GB+ free disk space
- Android tools (adb, fastboot)
- Docker (for building in a controlled environment)

## Quick Start

1. Clone this repository
2. Run `./setup.sh` to install dependencies

3. Build for a specific device:
   ```bash
   ./build.sh <device>
   ```

   OR build a generic image:
   ```bash
   ./build.sh generic-30  # For Android 11 devices
   ./build.sh generic-32  # For Android 12/12L devices
   ```

4. Flash the resulting image:
   ```bash
   ./flash.sh <device>
   ```
   
   OR flash a generic image:
   ```bash
   ./flash.sh generic-30  # For Android 11 devices
   ./flash.sh generic-32  # For Android 12/12L devices
   ```

## Detailed Documentation

See the `docs/` directory for detailed guides on:
- [Installation](docs/installation.md)
- [Building from source](docs/building.md)
- [Generic builds](docs/generic-builds.md)
- [Customizing Nethunter theme](docs/customizing.md)
- [Adding penetration testing tools](docs/tools.md)
- [Troubleshooting](docs/troubleshooting.md)