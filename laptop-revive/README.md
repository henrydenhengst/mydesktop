# Laptop Revival 

## directories en files 

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

## Installeer git en ansible
```bash
sudo apt install git ansible
mkdir -p repo
cd repo
git clone https://github.com/henrydenhengst/laptoprevive.git
cd laptoprevive
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
