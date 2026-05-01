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

## Installeer git en Ansible
```bash
sudo apt install git ansible
```

## Stap 1 → hardware inventarisatie

Run het playbook en de hardware info staat in /home/$USER

```bash
ansible-playbook -K stap1.yml
```
- Stap 2 → identiteit (hostname toekennen)

Edit de variabelen (user en hostname) in stap2.yml

```bash
nano stap2.yml
ansible-playbook -i inventory.ini stap2.yml
```

- Stap 3 → volledige provisioning via declaratieve config

```bash
ansible-playbook -i inventory.ini stap3.yml
```
