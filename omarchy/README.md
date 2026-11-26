# Functioneel Ontwerp — Omarchy Plus (v3.2.1)

## 1. Doel en scope

Omarchy Plus is een bash-installatie- en beheerscript voor Omarchy (Arch Linux) dat in één gestructureerde run twee componenten aanbiedt:

- **CLI Toolkit**: ~50 systeempakketten via `omarchy pkg add` in één transactie, inclusief inventarisatie, conflictcontrole en overslaan van reeds aanwezige pakketten.
- **Docker Toolbox**: de `dtool` CLI voor kortstondige webtools, shells, ontwikkel-/analyse-gereedschap en tijdelijke databases, aangevuld met aliassen, `~/.bashrc`-integratie en een systemd drop-in voor automatische cleanup van getagde containers (`docker-toolbox.temporary=true`).

**Uit scope:**

- Geen losse `pacman -Syu` (gebruikt `omarchy update`).
- Geen AUR-installaties vanuit het script.
- Geen verwijderen van systeempakketten of Docker-data (images, volumes, containers) bij `--uninstall`.
- Geen automatische activatie van nieuwe achtergrondservices.

## 2. Gebruikers & CLI-interface

**Doelgroep:** systeembeheerders en ontwikkelaars op Omarchy / Arch Linux die herhaalbaar en gecontroleerd CLI-tools en tijdelijke Docker-werkplekken willen inrichten.

**Aanroep:**

```bash
./omarchy-plus.sh [opties]
```

| Optie | Werking |
| --- | --- |
| `--dry-run` | Read-only simulatie; voert geen `omarchy update`, pakketinstallatie, bestandsmutatie of logging uit. |
| `--skip-update` | Slaat de voorafgaande `omarchy update` bewust over. |
| `--yes` | Slaat bevestigingsprompts van Omarchy Plus over (`omarchy update` kan nog eigen interactie vragen). |
| `--skip-cli` | Installeert alleen de Docker Toolbox. |
| `--skip-docker` | Installeert alleen de CLI Toolkit. |
| `--uninstall` | Verwijdert de Docker Toolbox-integratie (niet combineerbaar met `--skip-cli` of `--skip-docker`). |
| `-h`, `--help` | Toont gebruik, stappenplan, onderdelen en logpad. |

## 3. Functionele werking & uitvoeringsflow

De hoofdflow verloopt in vaste fasen met `set -Eeuo pipefail` en `umask 077`.

### Fase 1 — Argumentvalidatie & read-only voorcontroles

- Controleert optiecombinaties.
- Controleert vereiste commando's (`pacman`, `omarchy`/`sudo`, en bij Docker-acties o.a. `systemctl`, `grep`, `awk`, `cmp`, `install`, `readlink`, `mktemp`).
- Valideert `~/.bashrc` op symlinks en op exact één evenwichtig paar begin-/eindmarkers (`# >>> DOCKER_TOOLBOX >>>` / `# <<< DOCKER_TOOLBOX <<<` en legacy `# DOCKER_TOOLBOX` / `# Einde Docker Toolbox`).

### Fase 2 — Dry-run pad (indien `--dry-run`)

- Inventariseert CLI-pakketten (indien actief) en toont het overzicht.
- Meldt verwachte acties en de status van `docker` / `docker.service`.
- Stopt zonder wijzigingen of logbestand.

### Fase 3 — Systeemupdate (`run_omarchy_update`)

- Voert tenzij `--skip-update` of `--uninstall` eerst `omarchy update` uit na bevestiging.
- Bij mislukken: stopt zonder installatie.
- Bij herstartindicatie (`/run/reboot-required`, `/var/run/reboot-required` of ontbrekende actieve kernelmodule-map): meldt dat een herstart nodig is.

### Fase 4 — Controles na update, inventarisatie & bevestiging

- Controleert aanwezigheid van `omarchy` (bij CLI) en `docker` + geladen `docker.service` (bij Docker-installatie).
- Bouwt `INSTALL_LIST` en `SKIP_LIST` op basis van `pacman -Qq`, beschikbaarheid in repositories (`pacman -Si`) en `Conflicts With`.
- Toont overzicht en samenvatting en vraagt bevestiging (tenzij `--yes`).

### Fase 5 — Logging & sudo-keepalive

- Maakt `~/.local/state/omarchy-plus` aan en opent een logbestand (`install-YYYYMMDD-HHMMSS-PID.log`, mode `0600`).
- Start een achtergrond-keepalive voor `sudo` en ruimt deze bij EXIT op.

### Fase 6 — Uitvoering (uninstall of installatie)

**Bij `--uninstall`:**

- Maakt back-up van `~/.bashrc`, verwijdert beide Bash-blokken.
- Ruimt de verouderde `docker-toolbox-cleanup.service` en `cleanup.sh` op.
- Maakt back-up en verwijdert de systemd drop-in.
- Verwijdert `aliases.sh` en `dtool`.

**Bij installatie:**

- *CLI Toolkit*: installeert alle geselecteerde pakketten in één `omarchy pkg add`-aanroep en controleert elk pakket via `pacman -Qq`.
- *Docker Toolbox*: verwijdert eerst de oude 1.x cleanup-service, schrijft `~/.local/bin/dtool` (met `bash -n` syntaxcheck), schrijft `~/.config/docker-toolbox/aliases.sh`, werkt het gemarkeerde blok in `~/.bashrc` bij en installeert `/etc/systemd/system/docker.service.d/docker-toolbox.conf` met `daemon-reload`.

### Fase 7 — Eindrapport & exitcodes

- Rapporteert status per onderdeel, logpad en `source ~/.bashrc` (indien Docker Toolbox is geïnstalleerd).
- Exitcode `0` bij succes/annulering; `1` bij fouten; `2` bij vereiste herstart na `omarchy update`.

## 4. `dtool` CLI & automatische cleanup

`dtool` start containers standaard met `--rm` en `--label docker-toolbox.temporary=true`.

### Webtools (gebonden aan `127.0.0.1`, poort overschrijfbaar via `DTOOL_PORT`)

| Commando | Poort |
| --- | --- |
| `pdf` | 8080 |
| `ittools` | 8081 |
| `metube` (downloads naar `~/Downloads`) | 8082 |
| `draw` | 8083 |
| `cyberchef` | 8084 |
| `convert` | 8085 |
| `translate` | 8086 |

### Shells / netwerk

- `debian` (trixie-slim)
- `alpine`
- `ubuntu`
- `python`
- `node`
- `network` (`nicolaka/netshoot` met `--network host`)

### Ontwikkeling & analyse

- `trivy`
- `hadolint`
- `pandoc` (via `pandoc/typst` naar PDF)
- `postgres` (standaard `127.0.0.1:5432`)
- `redis` (standaard `127.0.0.1:6379`)

### Beheer

- `images`
- `containers`
- `cleanup` (prunet gestopte containers met het toolbox-label)
- `help`

### Veiligheid & werkmappen in `dtool`

- Bij `docker info` met permission denied valt `dtool` terug op `sudo docker`.
- Koppelt nooit automatisch `/` of de volledige `$HOME`-map; blokkeert scripts/scans vanuit `/` of `$HOME` en controleert dat opgegeven bestanden binnen de huidige werkmap vallen.
- `python` en `node` draaien met host-UID/GID en `HOME=/tmp`.
- Bij start van `docker.service` voert de systemd drop-in een `ExecStartPost` cleanup uit voor achtergebleven containers met label `docker-toolbox.temporary=true`.

## 5. Beveiliging, bestandsbeheer & foutafhandeling

- **Symlink-bescherming**: weigert te back-uppen, overschrijven of verwijderen wanneer doelbestanden, configuratie-/state-/backup-mappen of de systemd drop-in symbolische links zijn.
- **Back-ups & atomaire updates**: maakt tijdgestempelde back-ups (`0600`) in `~/.config/docker-toolbox/backups` en vervangt `~/.bashrc`, `dtool` en `aliases.sh` via tijdelijke bestanden en `mv`.
- **Foutafhandeling**: `trap` logt het regelnummer bij fouten; falende pakket- of toolbox-stappen worden geregistreerd en resulteren in exitcode 1.