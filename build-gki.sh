#!/bin/bash
set -e

# --- Configurable variables ---
NETHUNTER_TAR="nethunter-pro.tar"
DEBIAN_HALIUM_TAR="debian-halium.tar"
ANDROID_ROOTFS_IMG_ORIG="android-rootfs.img"
MERGED_ROOTFS="rootfs-out"
WORK_DEBIAN="debian-halium-unpack"
WORK_NH="nethunter-pro-unpack"
ROOTFS_IMG="rootfs.img"
ROOTFS_SIZE_MB=4096
HOSTNAME="droidian-kali"

# --- Cleanup ---
rm -rf "$MERGED_ROOTFS" "$WORK_DEBIAN" "$WORK_NH" mnt-rootfs-img
mkdir "$MERGED_ROOTFS" "$WORK_DEBIAN" "$WORK_NH"

echo "[*] Extracting debian-halium..."
tar -xf "$DEBIAN_HALIUM_TAR" -C "$WORK_DEBIAN"
echo "[*] Extracting nethunter-pro..."
tar -xf "$NETHUNTER_TAR" -C "$WORK_NH"
echo "[*] Merging rootfs..."
cp -a "$WORK_DEBIAN"/. "$MERGED_ROOTFS"/
cp -a "$WORK_NH"/. "$MERGED_ROOTFS"/

# --- Essentials ---
echo "[*] Ensuring essential files..."
mkdir -p "$MERGED_ROOTFS/etc"
touch "$MERGED_ROOTFS/etc/fstab" "$MERGED_ROOTFS/etc/passwd" "$MERGED_ROOTFS/etc/shadow" "$MERGED_ROOTFS/etc/group"

# Hostname & Hosts
echo "$HOSTNAME" > "$MERGED_ROOTFS/etc/hostname"
cat > "$MERGED_ROOTFS/etc/hosts" <<EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

# API32 in build.prop
BUILD_PROP="$MERGED_ROOTFS/system/build.prop"
if [ -d "$MERGED_ROOTFS/system" ]; then
  mkdir -p "$MERGED_ROOTFS/system"
  touch "$BUILD_PROP"
  grep -q "ro.build.version.sdk" "$BUILD_PROP" && \
    sed -i 's/^ro\.build\.version\.sdk=.*/ro.build.version.sdk=32/' "$BUILD_PROP" || \
    echo "ro.build.version.sdk=32" >> "$BUILD_PROP"
fi

# /init and /sbin/init
if [[ ! -f "$MERGED_ROOTFS/init" ]]; then
  if [[ -x "$MERGED_ROOTFS/sbin/init" ]]; then
    ln -sf /sbin/init "$MERGED_ROOTFS/init"
  elif [[ -x "$MERGED_ROOTFS/bin/init" ]]; then
    ln -sf /bin/init "$MERGED_ROOTFS/init"
  else
    echo "ERROR: No /sbin/init or /bin/init found!"
    exit 1
  fi
fi
chmod +x "$MERGED_ROOTFS/init"
if [[ ! -x "$MERGED_ROOTFS/sbin/init" ]] && [[ -x "$MERGED_ROOTFS/bin/init" ]]; then
  ln -sf /bin/init "$MERGED_ROOTFS/sbin/init"
  chmod +x "$MERGED_ROOTFS/sbin/init"
fi

# FSTAB (read-write rootfs)
cat > "$MERGED_ROOTFS/etc/fstab" <<EOF
/dev/root    /    ext4    rw,relatime,errors=remount-ro    0    1
tmpfs        /tmp tmpfs   defaults    0 0
proc         /proc proc   defaults    0 0
sysfs        /sys  sysfs  defaults    0 0
devpts       /dev/pts devpts gid=5,mode=620 0 0
EOF

# Ensure / is not set RO elsewhere (e.g., /init)
if [ -f "$MERGED_ROOTFS/init" ]; then
  sed -i 's/mount -o ro/mount -o rw/g' "$MERGED_ROOTFS/init" || true
fi

# kali-mobile-themes: Nethunter Pro as default
THEME_PATH="$MERGED_ROOTFS/usr/share/kali-mobile-themes/themes/nethunter-pro"
if [ -d "$THEME_PATH" ]; then
  mkdir -p "$MERGED_ROOTFS/usr/share/kali-mobile-themes/themes"
  ln -sf "$THEME_PATH" "$MERGED_ROOTFS/usr/share/kali-mobile-themes/themes/default"
  echo "[*] Set Nethunter Pro as default Kali Mobile theme."
fi

# Kali Plymouth splash
if [ -d "$MERGED_ROOTFS/usr/share/plymouth/themes/kali" ]; then
  mkdir -p "$MERGED_ROOTFS/etc/plymouth"
  echo "Theme=kali" > "$MERGED_ROOTFS/etc/plymouth/plymouthd.conf"
  echo "[*] Set Kali Plymouth splash."
fi

# --- Place android-rootfs.img in /var/lib/lxc and symlink from /data ---
# Ensure android-rootfs.img exists
if [ ! -f "$ANDROID_ROOTFS_IMG_ORIG" ]; then
  echo "ERROR: $ANDROID_ROOTFS_IMG_ORIG not found!"
  exit 1
fi

mkdir -p "$MERGED_ROOTFS/var/lib/lxc"
mkdir -p "$MERGED_ROOTFS/data"
cp "$ANDROID_ROOTFS_IMG_ORIG" "$MERGED_ROOTFS/var/lib/lxc/android-rootfs.img"
ln -sf /var/lib/lxc/android-rootfs.img "$MERGED_ROOTFS/data/android-rootfs.img"

# --- Permissions ---
echo "[*] Setting permissions..."
chown -R root:root "$MERGED_ROOTFS"

# --- Create rootfs.img file ---
echo "[*] Creating $ROOTFS_IMG ($ROOTFS_SIZE_MB MB ext4)..."
dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count=$ROOTFS_SIZE_MB
mkfs.ext4 -F "$ROOTFS_IMG"
mkdir mnt-rootfs-img
sudo mount -o loop "$ROOTFS_IMG" mnt-rootfs-img
sudo cp -a "$MERGED_ROOTFS"/. mnt-rootfs-img/
sync
sudo umount mnt-rootfs-img
rmdir mnt-rootfs-img

echo "[*] Bootable rootfs.img is ready!"
echo "You will find /var/lib/lxc/android-rootfs.img (and a symlink at /data/android-rootfs.img) inside the image."
echo "[*] Testing rootfs.img by mounting..."

MOUNT_DIR="test-mnt-rootfs"
rm -rf "$MOUNT_DIR"
mkdir "$MOUNT_DIR"

sudo mount -o loop rootfs.img "$MOUNT_DIR"

echo "[*] Contents of $MOUNT_DIR/var/lib/lxc:"
ls -l "$MOUNT_DIR/var/lib/lxc"

echo "[*] Symlink in $MOUNT_DIR/data:"
ls -l "$MOUNT_DIR/data"

# Optionally, check existence
if [ -f "$MOUNT_DIR/var/lib/lxc/android-rootfs.img" ] && [ -L "$MOUNT_DIR/data/android-rootfs.img" ]; then
    echo "[+] android-rootfs.img and symlink exist as expected."
else
    echo "[!] android-rootfs.img or symlink missing."
fi

sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
echo "[*] rootfs.img mount test complete."
