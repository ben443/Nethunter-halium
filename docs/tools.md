# Penetration Testing Tools in Nethunter-Halium

This guide covers the penetration testing tools included in Nethunter-Halium and how to use them effectively.

## Tool Architecture

Nethunter-Halium uses a dual-system approach:
1. **Host System**: Phosh UI with basic tools and utilities
2. **LXC Container**: Full Kali Linux environment with penetration testing tools

This architecture provides isolation while allowing full access to hardware when needed.

## Accessing Tools

### Nethunter Shell

The easiest way to access all penetration testing tools is through the Nethunter Shell:

1. Click the "Nethunter Shell" icon on your home screen
2. This launches a terminal connected to the Kali LXC container
3. All Kali tools are available from this shell

### Tool Categories

The included tools are organized into these categories:

- Information Gathering
- Vulnerability Analysis
- Web Application Analysis
- Database Assessment
- Password Attacks
- Wireless Attacks
- Reverse Engineering
- Exploitation Tools
- Sniffing & Spoofing
- Post Exploitation
- Forensics
- Reporting Tools

## Key Tools Included

### Information Gathering

- **Nmap**: Network discovery and security auditing
  ```bash
  nmap -sV -p 1-1000 192.168.1.1
  ```

- **Maltego**: Open source intelligence and forensics
  ```bash
  maltego
  ```

### Vulnerability Analysis

- **OpenVAS**: Vulnerability scanner
  ```bash
  openvas-setup
  openvas-start
  ```

### Web Application Analysis

- **Burp Suite**: Web vulnerability scanner
  ```bash
  burpsuite
  ```

- **OWASP ZAP**: Web app vulnerability scanner
  ```bash
  zaproxy
  ```

### Wireless Attacks

- **Aircrack-ng**: Wireless network security auditing
  ```bash
  airmon-ng start wlan0
  airodump-ng wlan0mon
  ```

### Exploitation Tools

- **Metasploit Framework**: Penetration testing framework
  ```bash
  msfconsole
  ```

## Hardware Integration

### USB Devices

USB devices connected to your phone are automatically made available to the LXC container. This includes:

- WiFi adapters
- Rubber Ducky
- USB Ethernet adapters
- Bluetooth adapters

### Using External WiFi Adapters

To use an external WiFi adapter:

1. Connect the adapter to your phone (may require OTG adapter)
2. Open Nethunter Shell
3. Run `iwconfig` to verify the adapter is detected
4. Use Aircrack-ng or other tools with the adapter

## Creating Tool Shortcuts

You can create shortcuts for commonly used tools:

1. Create a script in `/usr/local/bin/` that launches the tool
2. Create a desktop file in `/usr/share/applications/`
3. Add an icon for the tool

## Updating Tools

To update all tools in the Kali container:

```bash
lxc-attach -n kali-nethunter -- apt update
lxc-attach -n kali-nethunter -- apt upgrade
```

Or use the provided update script:

```bash
nethunter-update
```

## Adding Custom Tools

If a tool isn't included, you can install it:

```bash
lxc-attach -n kali-nethunter -- apt install <tool-name>
```

For tools not in the Kali repositories, you can install them manually:

```bash
lxc-attach -n kali-nethunter -- bash
cd /opt
git clone https://github.com/tool/repository.git
cd repository
./install.sh
```