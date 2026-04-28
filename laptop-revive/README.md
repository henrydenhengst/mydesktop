# Laptop Revival 


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

- Stap 1 → hardware inventarisatie
- Stap 2 → identiteit (hostname toekennen)
- Stap 3 → volledige provisioning via declaratieve config

```bash
ansible-playbook -i inventory.ini stap1.yml
ansible-playbook -i inventory.ini stap2.yml
ansible-playbook -i inventory.ini stap3.yml
```
