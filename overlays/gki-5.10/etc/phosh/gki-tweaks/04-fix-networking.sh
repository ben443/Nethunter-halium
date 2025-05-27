#!/bin/bash
#
# Fix networking on GKI 5.10 devices
# This script addresses common networking issues on Android 12 GKI devices

set -e

echo "Fixing networking for GKI 5.10 devices..."

# Check if network services are running in Android container
if lxc-attach -n android -- getprop init.svc.vendor.wifi | grep -q running; then
  echo "Vendor WiFi service is running in Android container"
else
  echo "WARNING: Vendor WiFi service is not running in Android container"
  echo "Attempting to start WiFi service..."
  lxc-attach -n android -- start vendor.wifi || true
fi

# Fix permissions for network devices
for net_dev in /dev/wlan* /dev/wcnss* /dev/wifi*; do
  if [ -e "$net_dev" ]; then
    echo "Setting permissions for $net_dev"
    chmod 666 "$net_dev"
  fi
done

# Configure wpa_supplicant for Android WiFi HAL
mkdir -p /etc/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant-android.conf << EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1
pmf=1
driver_param=use_p2p_group_interface=1p2p_device=1
EOF

# Configure NetworkManager to use the Android WiFi driver
cat > /etc/NetworkManager/conf.d/android-wifi.conf << EOF
[device]
wifi.backend=wext

[connectivity]
uri=http://nmcheck.gnome.org/check_network_status.txt
interval=300

[main]
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=true
EOF

# Set up USB tethering
cat > /usr/local/bin/usb-tethering << 'EOF'
#!/bin/bash

# Script to enable USB tethering on GKI 5.10 devices

# Load necessary modules
modprobe g_ether || true

# Configure USB gadget function
if [ -d /sys/class/android_usb/android0 ]; then
  echo 0 > /sys/class/android_usb/android0/enable
  echo rndis > /sys/class/android_usb/android0/functions
  echo 1 > /sys/class/android_usb/android0/enable
elif [ -d /config/usb_gadget/g1 ]; then
  cd /config/usb_gadget/g1
  echo "" > UDC
  rm -f configs/c.1/rndis.usb0 || true
  rmdir functions/rndis.usb0 || true
  
  mkdir -p functions/rndis.usb0
  echo 42 > functions/rndis.usb0/ifname
  echo 1 > functions/rndis.usb0/host_addr
  echo 2 > functions/rndis.usb0/self_addr
  
  ln -s functions/rndis.usb0 configs/c.1/
  ls /sys/class/udc > UDC
fi

# Configure network interface
RNDIS_IF=$(ip -o link show | grep usb | awk -F': ' '{print $2}' | head -n 1)
if [ -n "$RNDIS_IF" ]; then
  ip addr add 192.168.42.1/24 dev $RNDIS_IF
  ip link set $RNDIS_IF up
  
  # Start DHCP server
  if command -v dnsmasq >/dev/null; then
    killall dnsmasq || true
    dnsmasq --interface=$RNDIS_IF --dhcp-range=192.168.42.2,192.168.42.254,1h
  fi
  
  # Enable NAT
  iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
  iptables -A FORWARD -i wlan0 -o $RNDIS_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i $RNDIS_IF -o wlan0 -j ACCEPT
  
  echo 1 > /proc/sys/net/ipv4/ip_forward
  
  echo "USB tethering enabled on $RNDIS_IF"
else
  echo "No USB network interface found"
  exit 1
fi
EOF

chmod +x /usr/local/bin/usb-tethering

# Create systemd service for USB tethering
cat > /etc/systemd/system/usb-tethering.service << EOF
[Unit]
Description=USB Tethering Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/usb-tethering
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Fix mobile data if needed
if [ -e /dev/rmnet0 ] || [ -e /dev/qcqmi0 ]; then
  echo "Configuring mobile data support..."
  
  # Set up ModemManager configuration
  mkdir -p /etc/ModemManager/
  cat > /etc/ModemManager/ModemManager.conf << EOF
[General]
LoadPlugins=Android,Generic,Altair,AnySIM,BroadbandModem,Cinterion,Gobi,Huawei,Linktop,Longcheer,Motorola,Nokia,Novatel,Option,Samsung,Sierra,SimTech,Telit,Wavecom,X22X,ZTE
EOF

  # Load necessary kernel modules
  for module in qmi_wwan rmnet_usb; do
    modprobe $module || true
  done
fi

echo "Network fixes applied for GKI 5.10 devices"