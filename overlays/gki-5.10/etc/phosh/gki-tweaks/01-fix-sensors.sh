#!/bin/bash
#
# Fix sensors on GKI 5.10 devices
# This script addresses common sensor issues on Android 12 GKI devices

set -e

echo "Fixing sensors for GKI 5.10 devices..."

# Check if sensors service is running in Android container
if lxc-attach -n android -- getprop init.svc.vendor.sensors | grep -q running; then
  echo "Vendor sensors service is running in Android container"
else
  echo "WARNING: Vendor sensors service is not running in Android container"
  echo "Attempting to start sensors service..."
  lxc-attach -n android -- start vendor.sensors
fi

# Fix permissions for sensor HAL
if [ -d /dev/input ]; then
  echo "Setting permissions for input devices..."
  chmod -R 755 /dev/input
  for device in /dev/input/event*; do
    chmod 666 "$device"
  done
fi

# Check for common sensor nodes
for sensor_node in /dev/sensors /dev/iio:device0 /sys/devices/virtual/sensors; do
  if [ -e "$sensor_node" ]; then
    echo "Setting permissions for $sensor_node"
    chmod -R 755 "$sensor_node"
  fi
done

# Create sensor symlinks if needed
if [ -d /dev/sensors ] && [ ! -e /dev/sensor_hub ]; then
  echo "Creating sensor_hub symlink..."
  ln -s /dev/sensors /dev/sensor_hub
fi

# Link libsensorndkbridge if not present
if [ ! -e /usr/lib/aarch64-linux-gnu/libsensorndkbridge.so ]; then
  ANDROID_SENSORLIB=$(find /android/system -name "libsensorndkbridge.so" | head -n 1)
  if [ -n "$ANDROID_SENSORLIB" ]; then
    echo "Linking Android sensor NDK bridge library..."
    ln -sf "$ANDROID_SENSORLIB" /usr/lib/aarch64-linux-gnu/libsensorndkbridge.so
  fi
fi

# Configure sensor service in Phosh
mkdir -p /etc/dbus-1/system.d/
cat > /etc/dbus-1/system.d/org.freedesktop.sensord.conf << EOF
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="org.freedesktop.sensord"/>
    <allow send_destination="org.freedesktop.sensord"/>
  </policy>
  <policy context="default">
    <allow send_destination="org.freedesktop.sensord"/>
  </policy>
</busconfig>
EOF

echo "Sensor fixes applied for GKI 5.10 devices"