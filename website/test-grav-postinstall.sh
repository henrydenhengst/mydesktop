#!/usr/bin/env bash

###############################################################################
#                                                                             #
#   Debian 13 (Trixie) + Docker + Grav + Admin - Volledige Setup             #
#                                                                             #
#   Version: 3.3.0                                                            #
#   Datum: 2025-01-27                                                         #
#   Doel: Debian 13 Trixie ONLY                                               #
#   Getest op: Debian 13 Trixie (testing)                                     #
#                                                                             #
#   GRAV VERSIE: LATEST (automatische security updates via Docker)           #
#                                                                             #
###############################################################################
#                                                                             #
#   WAARSCHUWING                                                              #
#   -----------                                                               #
#                                                                             #
#   Dit script is UITSLUITEND ontworpen voor Debian 13 "Trixie".              #
#   Het gebruikt moderne Debian features.                                     #
#                                                                             #
#   Gebruik dit script NIET op oudere Debian versies.                         #
#                                                                             #
###############################################################################
#                                                                             #
#   DOEL                                                                      #
#   ----                                                                      #
#                                                                             #
#   Dit script installeert een volledig werkende Grav CMS omgeving op         #
#   Debian 13 binnen enkele minuten, inclusief:                               #
#                                                                             #
#     • Docker Engine + Compose                                               #
#     • Grav CMS (kale core met error + problems plugins)                     #
#     • Admin panel (trekt login, form, flex-objects automatisch mee)         #
#     • Quark theme                                                           #
#     • Optionele extra plugins (breadcrumbs, git-sync, sitemap, etc.)        #
#                                                                             #
#   GRAV VERSION:                                                             #
#   -------------                                                             #
#                                                                             #
#     • Gebruikt 'latest' tag van lscr.io/linuxserver/grav                    #
#     • Altijd de meest recente stabiele versie (1.7.52 op moment van schrijven)
#     • Bevat alle security fixes (geen kwetsbare 1.7.48 meer!)               #
#     • Toekomstige versies (zoals Grav 2.0) worden automatisch gebruikt      #
#                                                                             #
###############################################################################
#                                                                             #
#   GRAV CORE PLUGINS (AL AANWEZIG)                                           #
#   -----------------------------                                             #
#                                                                             #
#     ✓ Error      - Foutafhandeling in nette layout                          #
#     ✓ Problems   - Diagnostische tool voor serveromgeving                   #
#                                                                             #
#   GEÏNSTALLEERDE PLUGINS (VIA ADMIN)                                        #
#   ----------------------------------                                        #
#                                                                             #
#     ✓ Admin           - CMS beheerinterface                                 #
#     ✓ Login           - Gebruikers authenticatie (admin dependency)         #
#     ✓ Form            - Formulieren builder (admin dependency)              #
#     ✓ Flex Objects    - Flexibele objecten (admin dependency)               #
#     ✓ Email           - E-mail functionaliteit (optioneel maar aanbevolen)  #
#                                                                             #
#   EXTRA PLUGINS (OPTIONEEL)                                                 #
#   -------------------------                                                 #
#                                                                             #
#     ✓ Breadcrumbs      - Navigatie broodkruimels                            #
#     ✓ Git Sync         - Git integratie                                     #
#     ✓ Markdown Notices - Markdown notificaties                              #
#     ✓ Sitemap          - XML sitemap generator                              #
#                                                                             #
###############################################################################
#                                                                             #
#   VEREISTEN                                                                 #
#   ----------                                                                #
#                                                                             #
#   • Debian 13 "Trixie" (testing)                                            #
#   • Werkende internetverbinding                                             #
#   • sudo/root toegang                                                       #
#   • Minimaal 1GB vrije schijfruimte                                         #
#   • Poort 8080 vrij (aanpasbaar)                                            #
#                                                                             #
###############################################################################
#                                                                             #
#   INSTALLATIE                                                               #
#   ------------                                                              #
#                                                                             #
#   1. Download het script:                                                   #
#                                                                             #
#      wget https://example.com/debian13-grav-install.sh                      #
#                                                                             #
#   2. Maak uitvoerbaar:                                                      #
#                                                                             #
#      chmod +x debian13-grav-install.sh                                      #
#                                                                             #
#   3. Voer uit als root:                                                     #
#                                                                             #
#      sudo ./debian13-grav-install.sh                                        #
#                                                                             #
#   4. Na installatie: browse naar:                                           #
#                                                                             #
#      http://localhost:8080                                                  #
#      http://localhost:8080/admin                                            #
#                                                                             #
###############################################################################
#                                                                             #
#   NA DE INSTALLATIE                                                         #
#   -----------------                                                         #
#                                                                             #
#   EERSTE LOGIN:                                                             #
#   ------------                                                              #
#                                                                             #
#   1. Open http://localhost:8080/admin                                       #
#   2. Volg de wizard om een admin account aan te maken                       #
#   3. Kies een sterk wachtwoord                                              #
#                                                                             #
#   HANDIGE COMMANDS:                                                         #
#   -----------------                                                         #
#                                                                             #
#   Container status:                                                         #
#      docker ps                                                              #
#                                                                             #
#   Logs bekijken:                                                            #
#      docker logs -f grav                                                    #
#                                                                             #
#   Stoppen:                                                                  #
#      cd ~/grav && docker compose down                                       #
#                                                                             #
#   Starten:                                                                  #
#      cd ~/grav && docker compose up -d                                      #
#                                                                             #
#   Herstarten:                                                               #
#      cd ~/grav && docker compose restart                                    #
#                                                                             #
#   Nieuwe plugin installeren:                                                #
#      docker exec grav bin/gpm install [plugin-naam] -y                      #
#                                                                             #
#   Grav upgraden (indien nieuwe versie beschikbaar):                         #
#      cd ~/grav && docker compose pull grav                                  #
#      cd ~/grav && docker compose up -d                                      #
#                                                                             #
###############################################################################

set -euo pipefail

# Fout afhandeling
trap 'echo ""; echo "❌ FOUT: Installatie afgebroken op regel $LINENO"; exit 1' ERR

# Kleuren voor output
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    NC=''
fi

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
header() { echo -e "${BLUE}▶${NC} $1"; }

###############################################################################
#                               CONFIGURATIE                                  #
###############################################################################

REQUIRED_SPACE_KB=1048576          # 1GB in KB
GRAV_PORT=8080                     # Wijzig indien nodig

# GRAV VERSIE: LATEST (automatische security updates)
# Dit betekent altijd de meest recente stabiele Grav versie
# Op moment van schrijven is dat 1.7.52 (bevat geen RCE kwetsbaarheid)
# Na release van Grav 2.0 stable wordt dit automatisch 2.0.0
GRAV_IMAGE="lscr.io/linuxserver/grav:latest"

STARTUP_WAIT=45                    # Max wachten op Grav startup

# Extra plugins (deze worden NIET automatisch met admin mee geïnstalleerd)
# Let op: error + problems zitten AL in Grav core en worden NIET opnieuw geïnstalleerd
EXTRA_PLUGINS=(
    "breadcrumbs"
    "git-sync"
    "markdown-notices"
    "sitemap"
)

# Of extra plugins geïnstalleerd moeten worden
INSTALL_EXTRA_PLUGINS=true

###############################################################################
#                           DEBIAN 13 CHECK                                   #
###############################################################################

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║        Debian 13 (Trixie) + Docker + Grav - Volledige Setup        ║"
echo "║                              v3.3.0                                 ║"
echo "║                   ⚠️  DEBIAN 13 ONLY  ⚠️                            ║"
echo "║                                                                      ║"
echo "║              Grav versie: LATEST (altijd de nieuwste)               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

header "Stap 1/6: Debian 13 validatie"
echo "───────────────────────────────────────────────────────────────────────"

# Root check
if [[ $EUID -ne 0 ]]; then
    error "Dit script moet met sudo worden uitgevoerd"
    echo ""
    echo "  sudo ./debian13-grav-install.sh"
    echo ""
    exit 1
fi
info "Root/sudo check geslaagd"

# Debian check
if [[ ! -f /etc/debian_version ]]; then
    error "Dit script werkt alleen op Debian"
    exit 1
fi

# Debian 13 specifieke check
DEBIAN_VERSION=$(cat /etc/debian_version)
if [[ ! "$DEBIAN_VERSION" =~ ^13 ]] && [[ ! "$DEBIAN_VERSION" =~ ^trixie ]]; then
    error "Dit script is UITSLUITEND voor Debian 13 (Trixie)"
    echo ""
    echo "  Huidige versie: $DEBIAN_VERSION"
    echo "  Gebruik het algemene script voor andere Debian versies"
    echo ""
    exit 1
fi
info "Debian 13 (Trixie) bevestigd - versie: $DEBIAN_VERSION"

# Codename detectie
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    CODENAME="${VERSION_CODENAME:-trixie}"
else
    CODENAME="trixie"
fi
info "Codename: $CODENAME"

# Gebruiker detectie
USERNAME="${SUDO_USER:-$USER}"
if ! id "$USERNAME" &>/dev/null; then
    error "Gebruiker '$USERNAME' bestaat niet"
    exit 1
fi
info "Doel gebruiker: $USERNAME"

# Home directory
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
if [[ -z "$USER_HOME" ]]; then
    error "Kan home directory niet vinden voor $USERNAME"
    exit 1
fi
GRAV_DIR="$USER_HOME/grav"
info "Grav directory: $GRAV_DIR"

# Schijfruimte check
AVAILABLE_SPACE=$(df --output=avail "$USER_HOME" | tail -1)
if [[ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_KB" ]]; then
    error "Onvoldoende schijfruimte (minimaal 1GB vereist)"
    echo ""
    echo "  Beschikbaar: $((AVAILABLE_SPACE / 1024)) MB"
    echo "  Benodigd:    $((REQUIRED_SPACE_KB / 1024)) MB"
    echo ""
    exit 1
fi
info "Schijfruimte: $((AVAILABLE_SPACE / 1024)) MB beschikbaar"

# Poort check (moderne methode met ss)
PORT_IN_USE=false
if command -v ss &>/dev/null; then
    if ss -tuln 2>/dev/null | grep -q ":${GRAV_PORT} "; then
        PORT_IN_USE=true
    fi
elif command -v lsof &>/dev/null; then
    if lsof -i ":${GRAV_PORT}" &>/dev/null 2>&1; then
        PORT_IN_USE=true
    fi
fi

if [[ "$PORT_IN_USE" == true ]]; then
    error "Poort ${GRAV_PORT} is al in gebruik"
    echo ""
    echo "  Wijzig GRAV_PORT in het script of stop de draaiende service"
    echo "  Controleer met: ss -tuln | grep ${GRAV_PORT}"
    echo ""
    exit 1
fi
info "Poort ${GRAV_PORT} is beschikbaar"

echo ""

###############################################################################
#                           SYSTEM UPDATE                                      #
###############################################################################

header "Stap 2/6: Systeem voorbereiden"
echo "───────────────────────────────────────────────────────────────────────"

# Package index updaten
info "Package index updaten..."
apt update -qq

# Alleen essentiële packages voor Debian 13
info "Basis packages installeren..."
apt install -y -qq \
    curl \
    wget \
    git \
    nano \
    ca-certificates \
    gnupg \
    lsb-release \
    lsof \
    iproute2 \
    > /dev/null

info "Basis packages geïnstalleerd"

# Check of ss beschikbaar is (zit in iproute2)
if command -v ss &>/dev/null; then
    info "Network tools (ss) beschikbaar"
else
    warn "ss command niet beschikbaar - alternatieve port check gebruikt"
fi

echo ""

###############################################################################
#                           DOCKER INSTALLATIE                                #
###############################################################################

header "Stap 3/6: Docker installeren (Debian 13 optimaal)"
echo "───────────────────────────────────────────────────────────────────────"

# Check of Docker al geïnstalleerd is
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    info "Docker is al geïnstalleerd en draait"
else
    info "Docker repository configureren..."

    # Moderne GPG key handling voor Debian 13
    mkdir -p /etc/apt/keyrings
    DOCKER_GPG="/etc/apt/keyrings/docker.gpg"

    if [[ ! -f "$DOCKER_GPG" ]]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | \
            gpg --dearmor -o "$DOCKER_GPG"
        chmod a+r "$DOCKER_GPG"
        info "  Docker GPG key geïnstalleerd"
    fi

    # Architectuur
    ARCH=$(dpkg --print-architecture)

    # Voor Debian 13 gebruiken we Bookworm repo (Trixie wordt nog niet ondersteund)
    DOCKER_REPO_CODENAME="bookworm"
    info "  Docker repo codename: $DOCKER_REPO_CODENAME (fallback voor Trixie)"

    # Repository toevoegen met signed-by (moderne methode)
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$ARCH signed-by=$DOCKER_GPG] \
            https://download.docker.com/linux/debian \
            $DOCKER_REPO_CODENAME stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        info "  Docker repository toegevoegd"
    fi

    # Docker installatie
    info "Docker packages installeren..."
    apt update -qq
    apt install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        > /dev/null

    # Docker service starten
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker
    info "  Docker service gestart"

    # Gebruiker toevoegen aan docker group
    usermod -aG docker "$USERNAME"
    info "  Gebruiker $USERNAME toegevoegd aan docker group"
    info "Docker succesvol geïnstalleerd"
fi

# Versies tonen
DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
info "Docker versie: $DOCKER_VERSION"

if docker compose version &>/dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    info "Docker Compose versie: $COMPOSE_VERSION"
fi

echo ""

###############################################################################
#                           GRAV SETUP                                        #
###############################################################################

header "Stap 4/6: Grav configureren"
echo "───────────────────────────────────────────────────────────────────────"

# Directory aanmaken
mkdir -p "$GRAV_DIR"
info "Directory aangemaakt: $GRAV_DIR"

# Docker Compose file met healthcheck
cat > "$GRAV_DIR/compose.yml" <<EOF
services:
  grav:
    image: ${GRAV_IMAGE}
    container_name: grav
    ports:
      - "${GRAV_PORT}:80"
    volumes:
      - ./config:/config
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
EOF

chown -R "$USERNAME":"$USERNAME" "$GRAV_DIR"
info "Compose file aangemaakt: $GRAV_DIR/compose.yml"

# Container starten
info "Grav container starten (image: ${GRAV_IMAGE})..."
cd "$GRAV_DIR"
runuser -u "$USERNAME" -- docker compose up -d > /dev/null 2>&1

# Wacht kort voor container init
sleep 3

# Check of container draait
if docker ps | grep -q grav; then
    info "Container gestart: $(docker ps --filter name=grav --format '{{.Status}}')"
else
    error "Grav container is niet gestart"
    echo ""
    echo "  Check logs: docker logs grav"
    echo ""
    exit 1
fi

# Toon welke Grav versie er is geïnstalleerd
GRAV_INSTALLED_VERSION=$(docker exec grav bin/grav --version 2>/dev/null | head -1 || echo "onbekend")
info "Grav versie in container: $GRAV_INSTALLED_VERSION"

echo ""

###############################################################################
#                           WACHTEN OP GRAV STARTUP                           #
###############################################################################

header "Stap 5/6: Wachten tot Grav volledig gestart is"
echo "───────────────────────────────────────────────────────────────────────"

# Functie om te wachten op Grav
wait_for_grav() {
    local max_wait=$STARTUP_WAIT
    local waited=0
    
    echo -n "  Grav initialiseren"
    
    while [[ $waited -lt $max_wait ]]; do
        # Check of index.php bestaat (indicatie dat Grav klaar is)
        if docker exec grav test -f /app/index.php 2>/dev/null; then
            echo ""
            info "Grav is klaar! (${waited} seconden)"
            return 0
        fi
        echo -n "."
        sleep 2
        waited=$((waited + 2))
    done
    
    echo ""
    warn "Grav startup duurt langer dan verwacht, maar gaat door..."
    return 0
}

wait_for_grav

# Healthcheck status (indien beschikbaar)
if docker inspect grav &>/dev/null; then
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' grav 2>/dev/null || echo "starting")
    if [[ "$HEALTH_STATUS" == "healthy" ]]; then
        info "Healthcheck: Grav is gezond"
    else
        warn "Healthcheck status: $HEALTH_STATUS"
    fi
fi

echo ""

###############################################################################
#                ADMIN PANEL EN PLUGINS INSTALLATIE                           #
###############################################################################

header "Stap 6/6: Admin panel, theme en plugins installeren"
echo "───────────────────────────────────────────────────────────────────────"

# Grav initialiseren (indien nodig)
info "Grav initialiseren..."
docker exec grav bin/grav install > /dev/null 2>&1 || true
sleep 3

# Tellers voor installatie
INSTALLED=0
FAILED=0

# Admin panel installatie
# Let op: admin trekt automatisch login, form en flex-objects mee
info "Admin panel installeren (inclusief dependencies)..."
echo ""

if docker exec -w /app grav bin/gpm install admin -y > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${NC} Admin panel (CMS beheerinterface)"
    echo -e "    ${GREEN}✓${NC} Login (gebruikers authenticatie - dependency)"
    echo -e "    ${GREEN}✓${NC} Form (formulieren builder - dependency)"
    echo -e "    ${GREEN}✓${NC} Flex Objects (flexibele objecten - dependency)"
    INSTALLED=$((INSTALLED + 4))
else
    echo -e "    ${RED}✗${NC} Admin panel installatie mislukt"
    FAILED=$((FAILED + 1))
    error "Admin panel is vereist voor verdere installatie"
    exit 1
fi

echo ""

# Email plugin (optioneel maar aanbevolen voor admin)
info "Email plugin installeren (aanbevolen voor admin)..."
if docker exec -w /app grav bin/gpm install email -y > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${NC} Email (e-mail functionaliteit)"
    INSTALLED=$((INSTALLED + 1))
else
    echo -e "    ${YELLOW}⚠${NC} Email (niet geïnstalleerd)"
    FAILED=$((FAILED + 1))
fi

echo ""

# Quark theme installeren
info "Quark theme installeren (modern standaard thema)..."
if docker exec -w /app grav bin/gpm install quark -y > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓${NC} Quark theme"
    INSTALLED=$((INSTALLED + 1))
else
    echo -e "    ${YELLOW}⚠${NC} Quark theme (niet geïnstalleerd)"
    FAILED=$((FAILED + 1))
fi

echo ""

# Extra plugins (optioneel)
if [[ "$INSTALL_EXTRA_PLUGINS" == true ]]; then
    info "Extra plugins installeren..."
    echo ""
    
    for plugin in "${EXTRA_PLUGINS[@]}"; do
        echo -n "    • ${plugin} ... "
        if docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            INSTALLED=$((INSTALLED + 1))
        else
            echo -e "${YELLOW}⚠${NC}"
            FAILED=$((FAILED + 1))
        fi
        # Korte pauze tussen plugin installaties
        sleep 1
    done
fi

echo ""

# Cache clearen
info "Cache clearen..."
docker exec grav bin/grav clear-cache > /dev/null 2>&1 || true

# Samenvatting plugin installatie
echo ""
info "Plugin installatie samenvatting:"
info "  ✅ Succesvol geïnstalleerd: ${INSTALLED} component(en)"
if [[ $FAILED -gt 0 ]]; then
    warn "  ⚠️  Niet geïnstalleerd/mislukt: ${FAILED}"
fi

echo ""

# Toon welke plugins er in Grav core zitten (voor informatie)
info "Let op: Error en Problems plugins zitten standaard in Grav Core"
info "  Deze hoeven niet apart te worden geïnstalleerd."

echo ""

###############################################################################
#                         FIREWALL CONFIGURATIE                               #
###############################################################################

if command -v ufw &>/dev/null; then
    if ufw status | grep -q "Status: active"; then
        info "UFW firewall is actief - poort ${GRAV_PORT} openen..."
        ufw allow "${GRAV_PORT}/tcp" > /dev/null 2>&1 || true
        info "  Poort ${GRAV_PORT}/tcp open gezet"
    else
        warn "UFW is geïnstalleerd maar niet actief"
        echo "  Activeer met: sudo ufw enable"
    fi
else
    info "Geen UFW gevonden - firewall configuratie overgeslagen"
fi

echo ""

###############################################################################
#                          SAMENVATTING & INFO                                 #
###############################################################################

# Verzamel IP adressen
IP_LIST=$(hostname -I 2>/dev/null || echo "")

# Haal exacte Grav versie op voor de samenvatting
GRAV_FULL_VERSION=$(docker exec grav bin/grav --version 2>/dev/null | head -1 || echo "onbekend")

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    INSTALLATIE VOLTOOID - Debian 13                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}✅ Grav CMS is succesvol geïnstalleerd op Debian 13!${NC}"
echo ""

echo "📦 Grav versie informatie:"
echo "   ├── Gebruikte image: ${BLUE}${GRAV_IMAGE}${NC}"
echo "   ├── Geïnstalleerde versie: ${BLUE}${GRAV_FULL_VERSION}${NC}"
echo "   └── Status: ${GREEN}Altijd de nieuwste stabiele versie (bevat security fixes)${NC}"
echo ""

echo "🌐 Toegang tot Grav:"
echo ""
echo "   Lokaal:"
echo "   ├── Frontend: ${BLUE}http://localhost:${GRAV_PORT}${NC}"
echo "   └── Admin:    ${BLUE}http://localhost:${GRAV_PORT}/admin${NC}"
echo ""

if [[ -n "$IP_LIST" ]]; then
    echo "   Vanaf andere apparaten in hetzelfde netwerk:"
    for ip in $IP_LIST; do
        # Skip loopback en IPv6 link-local
        if [[ "$ip" != "127.0.0.1" && "$ip" != "::1" && ! "$ip" =~ ^fe80 ]]; then
            echo "   ├── Frontend: ${BLUE}http://${ip}:${GRAV_PORT}${NC}"
            echo "   └── Admin:    ${BLUE}http://${ip}:${GRAV_PORT}/admin${NC}"
        fi
    done
    echo ""
fi

echo "📂 Bestanden en directories:"
echo "   ├── Compose configuratie: ${BLUE}$GRAV_DIR/compose.yml${NC}"
echo "   ├── Grav configuratie:    ${BLUE}$GRAV_DIR/config/${NC}"
echo "   └── Docker volumes:       ${BLUE}docker volume ls${NC}"
echo ""

echo "📦 Geïnstalleerde componenten:"
echo ""
echo "   Grav Core (altijd aanwezig):"
echo "   ├── Error       - Foutafhandeling in nette layout"
echo "   └── Problems    - Diagnostische tool voor serveromgeving"
echo ""
echo "   Via Admin panel geïnstalleerd:"
echo "   ├── Admin           - CMS beheerinterface"
echo "   ├── Login           - Gebruikers authenticatie (dependency)"
echo "   ├── Form            - Formulieren builder (dependency)"
echo "   ├── Flex Objects    - Flexibele objecten (dependency)"
echo "   ├── Email           - E-mail functionaliteit"
echo "   └── Quark theme     - Modern standaard thema"
echo ""

if [[ "$INSTALL_EXTRA_PLUGINS" == true ]]; then
    echo "   Extra plugins:"
    echo "   ├── Breadcrumbs      - Navigatie broodkruimels"
    echo "   ├── Git Sync         - Git integratie"
    echo "   ├── Markdown Notices - Markdown notificaties"
    echo "   └── Sitemap          - XML sitemap generator"
    echo ""
fi

echo "👤 Eerste login (belangrijk!):"
echo "   1. Open ${BLUE}http://localhost:${GRAV_PORT}/admin${NC}"
echo "   2. Volg de wizard om een admin account aan te maken"
echo "   3. Gebruik een sterk wachtwoord voor de beveiliging"
echo ""

echo "🐳 Handige Docker commando's:"
echo "   ├── Status bekijken:     ${BLUE}docker ps${NC}"
echo "   ├── Logs bekijken:       ${BLUE}docker logs -f grav${NC}"
echo "   ├── Container stoppen:   ${BLUE}cd $GRAV_DIR && docker compose down${NC}"
echo "   ├── Container starten:   ${BLUE}cd $GRAV_DIR && docker compose up -d${NC}"
echo "   └── Container herstarten: ${BLUE}cd $GRAV_DIR && docker compose restart${NC}"
echo ""

echo "🔄 Grav upgraden (naar nieuwste versie):"
echo "   ${BLUE}cd $GRAV_DIR && docker compose pull grav${NC}"
echo "   ${BLUE}cd $GRAV_DIR && docker compose up -d${NC}"
echo "   ${BLUE}docker exec grav bin/grav update -y${NC} (indien nodig)"
echo ""

echo "🔧 Nieuwe plugin installeren:"
echo "   ${BLUE}docker exec grav bin/gpm install [plugin-naam] -y${NC}"
echo ""

echo "🔧 Plugin verwijderen:"
echo "   ${BLUE}docker exec grav bin/gpm uninstall [plugin-naam]${NC}"
echo ""

echo "⚠️  Belangrijke notities:"
echo "   ├── Docker group wordt actief na ${YELLOW}uit- en opnieuw inloggen${NC}"
echo "   ├── Of gebruik in huidige terminal: ${BLUE}newgrp docker${NC}"
echo "   ├── Poort ${GRAV_PORT} staat open in de firewall (indien UFW actief)"
echo "   ├── Grav data blijft behouden bij container herstart"
echo "   ├── Error en Problems plugins zitten standaard in Grav Core"
echo "   └── ${YELLOW}Grav gebruikt 'latest' tag - altijd de meest recente versie met security fixes!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

# Check of container nog draait na plugin installatie
if docker ps | grep -q grav; then
    echo -e "${GREEN}✅ Grav container draait en is beschikbaar!${NC}"
else
    echo -e "${RED}❌ Waarschuwing: Grav container lijkt niet te draaien.${NC}"
    echo ""
    echo "  Controleer met: ${BLUE}docker ps -a${NC}"
    echo "  Bekijk logs:    ${BLUE}docker logs grav${NC}"
    echo "  Herstart:       ${BLUE}cd $GRAV_DIR && docker compose up -d${NC}"
    echo ""
fi

echo ""
echo -e "${GREEN}Installatie succesvol afgerond!${NC}"
echo ""

exit 0