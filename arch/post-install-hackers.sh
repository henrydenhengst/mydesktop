#!/bin/bash
set -euo pipefail

echo "--- HACKERS / PENTEST POST-INSTALL START ---"

USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Update system ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- Core tools ---
echo "--- Installing core hacking / security tools ---"
pacman -S --noconfirm --needed \
  git vim neovim tmux htop wget curl unzip zip p7zip \
  nmap netcat tcpdump wireshark-qt \
  john hashcat hydra \
  aircrack-ng crunch \
  sqlmap nikto \
  metasploit \
  gdb strace ltrace binutils

# --- Python pentesting ecosystem ---
echo "--- Installing Python pentesting libraries ---"
pacman -S --noconfirm --needed python python-pip
sudo -u $USERNAME pip install --upgrade pip
sudo -u $USERNAME pip install \
  requests beautifulsoup4 selenium pwntools scapy paramiko

# --- Containers / VM for lab environments ---
echo "--- Installing virtualization tools ---"
pacman -S --noconfirm --needed \
  docker podman qemu virt-manager libvirt edk2-ovmf ebtables dnsmasq bridge-utils

systemctl enable --now docker libvirtd

# --- Proxy & sniffing tools ---
pacman -S --noconfirm --needed \
  burpsuite \
  wireshark-qt \
  mitmproxy \
  tor torsocks proxychains-ng

# --- Exploit & forensic tools ---
pacman -S --noconfirm --needed \
  volatility foremost binwalk hydra john hashcat radare2 ghex

# --- GPU acceleration (hashing / cracking) ---
if lspci | grep -qi nvidia; then
  pacman -S --noconfirm --needed nvidia-dkms nvidia-utils
elif lspci | grep -qi amd; then
  pacman -S --noconfirm --needed mesa vulkan-radeon opencl-mesa
fi

# --- Networking utilities ---
pacman -S --noconfirm --needed \
  net-tools iproute2 mtr traceroute ethtool nmap

# --- Directories for labs / exploits / scripts ---
mkdir -p /home/$USERNAME/{Labs,Exploits,Scripts,Reports,Recon}
chown -R $USERNAME:$USERNAME /home/$USERNAME

# --- Environment tuning ---
cat >> /home/$USERNAME/.bashrc <<'EOF'

# === HACKERS / SECURITY ENVIRONMENT ===
alias ls='ls --color=auto'
alias ll='ls -lh'
alias grep='grep --color=auto'
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000
EOF

# --- Recommendations / optional tools ---
cat <<EOT

💡 Aanbevelingen voor Ethical Hackers / Pentesters:

1. **Network pentesting**
   - Wireshark filters, nmap scripts, tcpdump analysis
   - Metasploit modules, exploit-db scripts

2. **Web security**
   - Burp Suite extensions, sqlmap automation
   - OWASP ZAP as alternative

3. **Wireless / RF**
   - Aircrack-ng suite
   - WiFi adapters met monitor mode + injection support

4. **Reverse engineering**
   - Radare2, Ghidra, GDB, IDA Free
   - Binary patching / debugging skills

5. **Forensics / OSINT**
   - Volatility (memory analysis), Foremost, Binwalk
   - Recon-ng, theHarvester, Maltego

6. **Containers / isolated labs**
   - QEMU/KVM VMs voor veilige exploit testing
   - Docker / Podman voor reproducible environments

7. **Password cracking / GPU acceleration**
   - Hashcat met NVIDIA/AMD GPU drivers
   - John the Ripper + wordlists

8. **Workflow / documentation**
   - Store scripts in /home/$USERNAME/Scripts
   - Reports in /home/$USERNAME/Reports
   - Use Git for versioning lab environments

EOT

echo "--- HACKERS INSTALL COMPLETE ---"
echo "Reboot recommended if new kernel or GPU drivers installed."