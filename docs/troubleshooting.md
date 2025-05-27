# Troubleshooting Nethunter-Halium

This guide addresses common issues you might encounter when using Nethunter-Halium and provides solutions.

## Installation Issues

### Device Not Booting After Installation

**Symptoms**: Device shows boot logo but doesn't proceed to the UI.

**Solutions**:
1. Try booting into recovery mode by holding Volume Up + Power
2. Check if your device is fully supported by Halium
3. Try reflashing the image
4. Check the installation logs for errors

### Installation Fails with Error

**Symptoms**: The `flash.sh` script fails with an error.

**Solutions**:
1. Ensure your device is in fastboot mode
2. Check that your bootloader is unlocked
3. Try running the script with sudo: `sudo ./flash.sh <device>`
4. Verify you have the latest fastboot tools installed

## System Issues

### LXC Container Not Starting

**Symptoms**: Nethunter tools aren't available, or you get errors about the container.

**Solutions**:
1. Check container status: `lxc-info -n kali-nethunter`
2. Try starting it manually: `lxc-start -n kali-nethunter`
3. Rebuild the container if necessary:
   ```bash
   lxc-destroy -n kali-nethunter
   /usr/local/bin/nethunter-first-boot
   ```

### WiFi Not Working

**Symptoms**: Can't connect to WiFi networks.

**Solutions**:
1. Check if WiFi is enabled in settings
2. Verify WiFi hardware is recognized: `sudo lshw -C network`
3. Try toggling airplane mode on and off
4. Restart the NetworkManager service: `sudo systemctl restart NetworkManager`

### External USB Devices Not Detected

**Symptoms**: USB devices like WiFi adapters aren't recognized.

**Solutions**:
1. Check if the device is detected by the system: `lsusb`
2. Ensure the device is properly connected
3. Try a different USB OTG adapter
4. Verify the device is compatible with ARM64 architecture

## Performance Issues

### System Running Slowly

**Symptoms**: UI is laggy or unresponsive.

**Solutions**:
1. Check running processes: `top`
2. Close unused applications
3. Reduce background services: `sudo systemctl list-units --type=service --state=running`
4. Clear cached memory: `sync && echo 3 | sudo tee /proc/sys/vm/drop_caches`

### High Battery Drain

**Symptoms**: Battery drains much faster than expected.

**Solutions**:
1. Identify power-hungry processes: `top -o %CPU`
2. Check for wake locks: `dumpsys power | grep WAKE`
3. Disable unused services
4. Ensure LXC containers are stopped when not in use: `lxc-stop -n kali-nethunter`

## Tool-Specific Issues

### Penetration Testing Tools Not Working

**Symptoms**: Tools crash or don't start properly.

**Solutions**:
1. Make sure you're running them from the Nethunter Shell
2. Check for missing dependencies
3. Try updating the tools: `lxc-attach -n kali-nethunter -- apt update && apt upgrade`
4. Check the specific tool's documentation for ARM64 compatibility

### GUI Applications Not Displaying

**Symptoms**: Graphical applications don't appear when launched.

**Solutions**:
1. Check if X forwarding is working
2. Try launching with `--display=:0`
3. Install any missing X libraries: `lxc-attach -n kali-nethunter -- apt install xorg`

## Recovery Options

### Resetting to Factory State

If you need to reset Nethunter-Halium to its factory state:

```bash
# Reset LXC container
lxc-stop -n kali-nethunter
lxc-destroy -n kali-nethunter
rm -rf /var/lib/nethunter/.first-boot-done
reboot
```

### Accessing Recovery Mode

To access recovery mode:

1. Power off the device
2. Hold Volume Up + Power until the recovery menu appears
3. Use volume buttons to navigate and power to select

### Emergency Shell

If the system won't boot properly, you can access an emergency shell:

1. At the boot screen, press Volume Down to interrupt boot
2. Select "Boot to emergency shell"
3. Use this shell to fix critical issues