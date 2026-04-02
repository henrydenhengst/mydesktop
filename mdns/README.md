# 🖥️ Dev Fleet Setup

![Status](https://img.shields.io/badge/status-ready-brightgreen)
![Technologies](https://img.shields.io/badge/ansible-blue)
![SSH/Mosh](https://img.shields.io/badge/ssh%2Fmosh-purple)
![CSSH](https://img.shields.io/badge/cssh-orange)

---

## 📌 Functionaliteit

Dit setup-script configureert en beheert een **multi-node homelab / dev fleet** met de volgende functionaliteiten:

### 1️⃣ Netwerk & mDNS
- Installeert en configureert `avahi-daemon` voor `.local` hostnames.
- Machines zijn automatisch vindbaar binnen het lokale netwerk.
- Maakt CSSH en Mosh gebruiksvriendelijk en dynamisch.

### 2️⃣ SSH & Trust
- Genereert een **ED25519 SSH key** voor de gebruiker.
- Verspreidt deze key naar alle nodes via Ansible.
- Zorgt voor **passwordless login** naar alle machines.

### 3️⃣ Ansible Inventory (`hosts.ini`)
- Bevat alle nodes in het homelab en kan worden uitgebreid met subgroepen zoals `laptops` en `servers`.
- Subgroepen maken gerichte taken mogelijk en zorgen voor overzicht.

### 4️⃣ CSSH & Mosh Aliases
- `cssh-all` opent meerdere terminals tegelijk (parallel commands).
- `cssh-all-debug` controleert de huidige hosts in de inventory.
- `mosh-all` opent stabiele reconnecting SSH sessies op alle nodes.

### 5️⃣ CSSH Config (`~/.clusterssh/config`)
- Layout: 2 kolommen, terminal = `terminator`.
- Connection reuse via `ControlMaster`.
- Agent forwarding voor CSSH.
- Timeouts en keepalives voor stabiele sessies.
- Nette window titles en unieke servers per terminal.

### 6️⃣ Firewall / Poorten
- SSH: TCP 22 open.
- Mosh: UDP 60000–61000 open.
- Geconfigureerd via de Ansible playbooks `mdns.yml` en `sync_keys.yml`.

---

## ⚡ Workflow
- Configureer mDNS op alle nodes.
- Vertrouw de nodes via SSH.
- Maak of update de `hosts.ini` met alle machines.
- Voeg CSSH en Mosh aliases toe aan `.bashrc`.
- Configureer de CSSH instellingen voor layout, connection reuse en agent forwarding.

---

## ✅ Testen
- Controleer hosts via de debug alias.
- Open alle terminals tegelijk met `cssh-all`.
- Start reconnecting Mosh-sessies met `mosh-all`.
- Individuele verbindingen testen met SSH of Mosh naar een specifieke node.

---

## 📌 Notities
- Zorg dat `.local` hostnames via mDNS werken.
- Backup CSSH config indien al aanwezig.
- Voeg nieuwe machines toe in `hosts.ini` → aliases werken direct.
- SSH keys zijn verspreid via Ansible, geen wachtwoorden nodig.
- Controleer dat de firewall de juiste poorten open heeft.

---

## 🧠 Conclusie
Met dit setup-script kan je **met één workflow**:

- Multi-node CSSH sessies openen.
- Stabiele Mosh sessies starten.
- Ansible inventory dynamisch beheren.
- Veilig en snel passwordless toegang tot al je nodes.

Dit is een **pro-level homelab workflow** voor DevOps, testing en beheer.


```bash
# 1) mdns op iedere machine:
ansible-playbook mdns.yml -K

# 2) ALLEEN ALS 1 overal op staat: TRUST
ansible-playbook sync_keys.yml -K

# 3) Setup inventory, aliases, and ClusterSSH config
ansible-playbook final-finish.yml -K

```