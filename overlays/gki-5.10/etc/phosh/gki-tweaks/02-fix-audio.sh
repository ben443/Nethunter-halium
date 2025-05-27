#!/bin/bash
#
# Fix audio on GKI 5.10 devices
# This script addresses common audio issues on Android 12 GKI devices

set -e

echo "Fixing audio for GKI 5.10 devices..."

# Check if audio HAL service is running in Android container
if lxc-attach -n android -- getprop init.svc.vendor.audio-hal | grep -q running; then
  echo "Vendor audio HAL service is running in Android container"
else
  echo "WARNING: Vendor audio HAL service is not running in Android container"
  echo "Attempting to start audio HAL service..."
  lxc-attach -n android -- start vendor.audio-hal
fi

# Fix permissions for audio devices
for audio_dev in /dev/snd/* /dev/audio*; do
  if [ -e "$audio_dev" ]; then
    echo "Setting permissions for $audio_dev"
    chmod 666 "$audio_dev"
  fi
done

# Set up PulseAudio configuration for Android audio HAL
mkdir -p /etc/pulse/
cat > /etc/pulse/android-hal.pa << EOF
#!/usr/bin/pulseaudio -nF

### Android HAL module for PulseAudio GKI 5.10 edition

# Ensure we have access to audio devices
.include /etc/pulse/default.pa

# Load the Android HAL module
load-module module-droid-card rate=48000

# Set default sink/source
set-default-sink droid-card
set-default-source droid-source

# Load droid-glue to bridge the gap between Pulseaudio and Android audio HAL
load-module module-droid-glue

# Ensure UCM configs are properly loaded
.ifexists module-alsa-card.so
  load-module module-alsa-card device_id="0" name="android-alsa" card_name="androidalsacard" tsched=yes
.endif
EOF

# Add this configuration to system-wide PulseAudio config
if ! grep -q "android-hal.pa" /etc/pulse/system.pa; then
  echo ".include /etc/pulse/android-hal.pa" >> /etc/pulse/system.pa
fi

# Restart PulseAudio to apply changes
if systemctl is-active --quiet pulseaudio; then
  echo "Restarting PulseAudio service..."
  systemctl restart pulseaudio
fi

# Fix ALSA UCM configurations if needed
if [ -d /android/vendor/etc/audio ] && [ ! -d /usr/share/alsa/ucm2/conf.d/android ]; then
  echo "Linking Android UCM configurations..."
  mkdir -p /usr/share/alsa/ucm2/conf.d/android
  ln -sf /android/vendor/etc/audio/* /usr/share/alsa/ucm2/conf.d/android/
fi

# Fix media codecs by linking the Android ones
if [ ! -d /etc/media_codecs ] && [ -d /android/vendor/etc/media_codecs ]; then
  echo "Linking Android media codecs..."
  ln -sf /android/vendor/etc/media_codecs /etc/media_codecs
fi

echo "Audio fixes applied for GKI 5.10 devices"