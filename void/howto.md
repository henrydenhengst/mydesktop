Manual

```bash
sudo bash wifi.sh
```

```bash
sudo mkdir -p /mnt/scripts
sudo mount /dev/sdb1 /mnt/scripts  # Vervang sdb1 als jouw stick anders heet
```

```
vim install-uefi.sh  # of install-bios.sh
```

```bash
wget -O howto.md https://bit.ly/3QQj2Ml
```

Than run

```bash
sudo xbps-install -Sy xbps ca-certificates
sudo xbps-install -uy xbps
sudo xbps-install -y git ansible
git clone https://github.com/henrydenhengst/mydesktop.git
cd mydesktop/void
chmod +x run1st.sh
chmod +x post-reboot.sh
sudo ./run1st.sh
```

