# Building Nethunter-Halium from Source

This guide covers the detailed steps for building Nethunter-Halium from source code.

## System Requirements

To build Nethunter-Halium, you need:

- A Linux computer (Ubuntu 20.04 or newer recommended)
- At least 16GB RAM
- At least 100GB free disk space
- Fast internet connection
- Quad-core CPU or better

## Setting Up the Build Environment

### 1. Install Dependencies

First, run the setup script to install all necessary dependencies:

```bash
./setup.sh
```

This script will install:
- Android build tools
- Halium build dependencies
- Docker for containerized builds
- LXC/LXD for container management
- Other required utilities

### 2. Configure Your Build

You may want to customize your build by modifying the configuration files:

- Edit `overlays/phosh-theme/` for UI customization
- Edit `overlays/kali-tools/` to add/remove tools
- Create custom scripts in `overlays/custom-scripts/`

### 3. Building for a Specific Device

To build for a specific device, use the `build.sh` script:

```bash
./build.sh <device-codename>
```

For example, to build for a OnePlus 3:

```bash
./build.sh oneplus3
```

### 4. Build Process Explanation

The build process involves several steps:

1. **Halium Base**: Builds the Halium base system for your device, which provides Android hardware compatibility
2. **Droidian Rootfs**: Creates a Debian-based root filesystem with Phosh UI
3. **Nethunter Integration**: Applies Nethunter theme and tools to the rootfs
4. **LXC Setup**: Configures the LXC container for Kali tools
5. **Image Creation**: Packages everything into a flashable image

The build may take 1-4 hours depending on your system specs and internet speed.

### 5. Build Artifacts

After a successful build, you'll find these files in the `build/out/` directory:

- `nethunter-halium-<device>.img`: The main system image
- Build logs in the `build/logs/` directory
- Temporary files in the `build/tmp/` directory

## Advanced Building Options

### Custom Package Selection

You can customize which packages are included by editing the build script:

```bash
# Edit build.sh to modify package selection
nano build.sh
```

Look for the `mkbootstrap` command and modify the `--include` parameter.

### Custom Overlays

To add your own files to the system:

1. Create a directory in `overlays/`
2. Add your files with the same path structure as they should appear in the rootfs
3. Update the build script to copy your overlay

### Building Only Specific Components

You can build only specific components by using these flags:

```bash
# Build only Halium base
./build.sh <device> --halium-only

# Build only rootfs
./build.sh <device> --rootfs-only

# Skip LXC container setup
./build.sh <device> --skip-lxc
```

## Troubleshooting Build Issues

Common build issues and solutions:

1. **Out of disk space**: Clear the `build/tmp/` directory
2. **Network errors**: Check your internet connection and try again
3. **Missing dependencies**: Run `./setup.sh` again
4. **Device-specific errors**: Check the Halium project for device-specific issues

For more detailed troubleshooting, check the build logs in `build/logs/`.