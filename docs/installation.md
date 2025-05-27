# Installation Guide for Nethunter-Halium

This guide covers the detailed steps to install Nethunter-Halium on a supported device.

## Supported Devices

Nethunter-Halium can be installed on:

1. **Specific devices**: Any device that supports Halium. You can check the [Halium device compatibility list](https://github.com/halium/halium/tree/master/devices) for a full list of supported devices.

2. **Generic builds**: Any device that supports Project Treble and meets the API level requirements:
   - Generic API 30 build: For devices running Android 11
   - Generic API 32 build: For devices running Android 12/12L

## Prerequisites

Before starting the installation, ensure you have:

1. A supported device
2. A computer running Linux
3. USB cable to connect your device
4. Unlocked bootloader on your device
5. Basic familiarity with flashing custom ROMs

## Backup Your Data

**IMPORTANT**: Installing Nethunter-Halium will erase all data on your device. Make sure to back up any important data before proceeding.

## Installation Steps

### 1. Prepare Your Computer

First, you need to set up your computer with the necessary tools:

```bash
# Clone the repository
git clone https://github.com/yourusername/nethunter-halium.git
cd nethunter-halium

# Run the setup script
./setup.sh
```

### 2. Build or Download Nethunter-Halium

You can either download a pre-built image (if available) or build it yourself:

#### For device-specific builds:

```bash
# Build for your specific device (e.g., 'oneplus3')
./build.sh oneplus3
```

#### For generic builds:

```bash
# Build for Android 11 devices
./build.sh generic-30

# Build for Android 12/12L devices
./build.sh generic-32
```

The build process may take some time (30 minutes to several hours) depending on your computer's specifications.

### 3. Flash Nethunter-Halium

Once the build is complete, you can flash it to your device:

#### For device-specific builds:

```bash
# Flash to your device
./flash.sh oneplus3
```

#### For generic builds:

```bash
# Flash for Android 11 devices
./flash.sh generic-30

# Flash for Android 12/12L devices
./flash.sh generic-32
```

Follow the on-screen instructions to complete the flashing process.

### 4. First Boot

The first boot may take several minutes as Nethunter-Halium completes its setup. During this time:

- The LXC container for Kali tools will be created
- The Nethunter theme will be applied
- System configurations will be set up

## Post-Installation

After installation, you should:

1. Complete the initial setup wizard
2. Connect to Wi-Fi
3. Update the system packages
4. Install additional penetration testing tools as needed

## Choosing Between Device-Specific and Generic Builds

- **Device-specific builds**: Better hardware support and performance, but only available for officially supported devices.
- **Generic builds**: Work on a wider range of devices, but may have limited hardware support or performance.

If your device is officially supported by Halium, we recommend using a device-specific build. If not, try a generic build that matches your device's Android APIlevel. Generic builds are also useful for testing Nethunter-Halium on new devices before creating a device-specific port.

## Troubleshooting

If you encounter issues during installation:

- **Boot loop**: Try reflashing the image with the `--skip-confirm` option
- **No display**: Some devices may require additional configuration
- **Limited functionality**: Generic builds may require additional drivers or configurations

For detailed troubleshooting, refer to the [troubleshooting guide](troubleshooting.md).

## Upgrading

To upgrade to a newer version of Nethunter-Halium:

1. Backup your data
2. Build or download the new version
3. Flash it using the same procedure as the initial installation

Alternatively, for minor updates, you can use the system's built-in update mechanism once it's available.