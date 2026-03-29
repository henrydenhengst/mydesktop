```bash
ansible-playbook hardware.yml -K
```

# Functionele Beschrijving: Hardware-Master Provisioning

Dit Ansible-playbook transformeert "afgeschreven" Windows-hardware naar een 
volwaardig Linux-cluster node. Het lost de meest voorkomende driver- en 
performance-problemen op die optreden bij het hergebruiken van oude laptops en PC's.

## 1. Repository Beheer (The Foundation)
* **Non-Free Firmware:** Activeert `contrib`, `non-free` en `non-free-firmware` 
  repositories. Dit is essentieel voor Debian 12+ om propriëtaire drivers 
  (zoals Wi-Fi en GPU-microcode) te mogen installeren.

## 2. Processor & Stabiliteit
* **Microcode Updates:** Installeert zowel `intel-microcode` als `amd64-microcode`. 
  Dit patcht beveiligingslekken en stabiliteitsfouten direct op de CPU.
* **Thermisch Beheer:** Activeert `thermald` om te voorkomen dat oude laptops 
  oververhit raken of gaan "throttelen" door stof of verouderde koelpasta.

## 3. Netwerk & Connectiviteit (De Wi-Fi Redders)
* **Multi-Vendor Support:** Bevat drivers voor de "Grote Drie" in laptopland:
    - Intel (iwlwifi)
    - Broadcom (brcm80211 & sta-dkms)
    - Realtek & Atheros
* **Bluetooth:** Volledige stack inclusief firmware voor randapparatuur.

## 4. Grafische & Input Optimalisatie
* **GPU Acceleratie:** Installeert firmware voor AMD/Radeon en Intel HD Graphics. 
  Dit ontlast de CPU bij het renderen van de interface of video.
* **Input Legacy:** Gebruikt `libinput` voor moderne touchpads en voegt 
  ondersteuning toe voor oudere 'synaptics' klikplaten.

## 5. Opslag & Randapparatuur
* **Cross-Platform Storage:** Volledige lees/schrijf ondersteuning voor 
  NTFS (Windows) en exFAT (USB-sticks/SD-kaarten).
* **Smartcard Support:** Activeert `pcscd` en `opensc` voor hardware-tokens, 
  eID-lezers of authenticatie-kaarten.
* **Multimedia:** Configureert webcams via `v4l-utils` en bereidt het systeem 
  voor op moderne audio via `firmware-sof-signed`.

## 6. Energiebeheer (Laptop Specifiek)
* **TLP:** Activeert geavanceerd energiebeheer. Dit verlaagt het stroomverbruik 
  en verlengt de levensduur van oude accu's door agressief beheer van 
  ongebruikte hardware-onderdelen.

## 7. Gebruikersrechten (Permissions)
* Voegt de actieve gebruiker toe aan kritieke groepen (`video`, `audio`, 
  `bluetooth`, `plugdev`) zodat hardware direct toegankelijk is zonder 
  constante `sudo` vragen.

