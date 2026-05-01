# Laptop Revival 

## stap 0 Prerequisites

Gebruik een USB stick van 4 Gb+.
Installeer hier Ventoy op.

Kopieer vervolgens de iso files van Shredos en Linux Mint naartoe.

- https://github.com/ventoy/Ventoy
- https://github.com/PartialVolume/shredos.x86_64
- https://linuxmint.com/download.php

Boot van USB stick en kies voor Shredos.
Clean the disk!

Boot van USB stick en kies voor Linux Mint 
Installeer Linux Mint

### Installeer git en ansible
```bash
sudo apt install git ansible
mkdir -p repo
cd repo
git clone https://github.com/henrydenhengst/laptoprevive.git
cd laptoprevive
```
### directories en files 

```
laptop-revive/
├── inventory.ini
├── stap1-inventory.yml
├── stap2-hostname.yml
├── stap3-provisioning.yml
├── files/
│   ├── laptoprevive-config.dconf
│   ├── logo.webp
│   └── transparent-panels.zip
```

## Stap 1 → hardware inventarisatie

Tijdens installatie is de juiste user al aangemaakt:
- user: laptoprevive
- pwd: zie instructie op NextCloud

Run het playbook en de hardware info staat in `/home/laptoprevive`

```bash
ansible-playbook -K stap1.yml
```

Stuur `/home/laptoprevive/     hardware-info-{{ inventory_hostname }}.txt` naar de administratie `info@laptoprevive.nl`

## Stap 2 → identiteit (hostname toekennen)

Wachten op `hostname` van de administratie.

Edit de variabelen (hostname) in stap2.yml

```bash
nano stap2.yml
ansible-playbook -i inventory.ini stap2.yml
```

## Stap 3 → volledige provisioning via declaratieve config

```bash
ansible-playbook -i inventory.ini stap3.yml
```
