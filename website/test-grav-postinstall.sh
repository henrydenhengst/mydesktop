#!/usr/bin/env bash

###############################################################################
#                                                                             #
#   Debian 13 (Trixie) + Docker + Grav + Admin + Plugins - Volledige Setup   #
#                                                                             #
#   Version: 3.0.0                                                            #
#   Datum: 2025-01-27                                                         #
#   Doel: Debian 13 Trixie ONLY                                               #
#   Getest op: Debian 13 Trixie (testing)                                     #
#                                                                             #
###############################################################################
#                                                                             #
#   WAARSCHUWING                                                              #
#   -----------                                                               #
#                                                                             #
#   Dit script is UITSLUITEND ontworpen voor Debian 13 "Trixie".              #
#   Het gebruikt moderne Debian features zoals:                               #
#                                                                             #
#     • /etc/apt/keyrings/ voor GPG keys                                      #
#     • signed-by in apt sources                                              #
#     • Docker repository compatibiliteit met Bookworm fallback               #
#     • Alleen packages die bestaan in Debian 13                              #
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
#     • Grav CMS met Admin panel                                              #
#     • Quark theme (modern default)                                          #
#     • Essentiële plugins (form, email, login, seo, sitemap, etc.)           #
#     • Firewall configuratie (indien UFW aanwezig)                           #
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
#   2. Volg de wizard om admin account aan te maken                           #
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
GRAV_VERSION="1.7.48"              # Vaste versie
GRAV_IMAGE="lscr.io/linuxserver/grav:${GRAV_VERSION}"
STARTUP_WAIT=45

###############################################################################
#                           DEBIAN 13 CHECK                                   #
###############################################################################

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║        Debian 13 (Trixie) + Docker + Grav - Volledige Setup        ║"
echo "║                              v3.0.0                                 ║"
echo "║                   ⚠️  DEBIAN 13 ONLY  ⚠️                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

header "Stap 1/6: Debian 13 validatie"
echo "───────────────────────────────────────────────────────────────────────"

# Root check
if [[ $EUID -ne 0 ]]; then
    error "Dit script moet met sudo worden uitgevoerd"
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
    error "Kan home directory niet vinden"
    exit 1
fi
GRAV_DIR="$USER_HOME/grav"
info "Grav directory: $GRAV_DIR"

# Schijfruimte check
AVAILABLE_SPACE=$(df --output=avail "$USER_HOME" | tail -1)
if [[ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_KB" ]]; then
    error "Onvoldoende schijfruimte (minimaal 1GB vereist)"
    exit 1
fi
info "Schijfruimte: $((AVAILABLE_SPACE / 1024)) MB beschikbaar"

# Poort check (moderne methode met ss)
if command -v ss &>/dev/null; then
    if ss -tuln 2>/dev/null | grep -q ":${GRAV_PORT} "; then
        error "Poort ${GRAV_PORT} is al in gebruik"
        exit 1
    fi
else
    # Fallback naar lsof
    if command -v lsof &>/dev/null && lsof -i ":${GRAV_PORT}" &>/dev/null 2>&1; then
        error "Poort ${GRAV_PORT} is al in gebruik"
        exit 1
    fi
fi
info "Poort ${GRAV_PORT} is beschikbaar"

echo ""

###############################################################################
#                           SYSTEM UPDATE                                      #
###############################################################################

header "Stap 2/6: Systeem updaten"
echo "───────────────────────────────────────────────────────────────────────"

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

echo ""

###############################################################################
#                           DOCKER INSTALLATIE                                #
###############################################################################

header "Stap 3/6: Docker installeren (Debian 13 optimaal)"
echo "───────────────────────────────────────────────────────────────────────"

# Check of Docker al geïnstalleerd is
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    info "Docker is al geïnstalleerd"
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

    # Repository toevoegen met signed-by
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$ARCH signed-by=$DOCKER_GPG] \
            https://download.docker.com/linux/debian \
            $DOCKER_REPO_CODENAME stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        info "  Docker repository toegevoegd"
    fi

    # Docker installeren
    info "Docker packages installeren..."
    apt update -qq
    apt install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        > /dev/null

    # Docker service
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker
    info "  Docker service gestart"

    # Gebruiker toevoegen aan docker group
    usermod -aG docker "$USERNAME"
    info "  Gebruiker toegevoegd aan docker group"
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
info "Directory: $GRAV_DIR"

# Docker Compose file (met healthcheck)
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
info "Compose file: $GRAV_DIR/compose.yml"

# Container starten
info "Grav container starten..."
cd "$GRAV_DIR"
runuser -u "$USERNAME" -- docker compose up -d > /dev/null 2>&1

sleep 3

if docker ps | grep -q grav; then
    info "Container gestart"
else
    error "Container start mislukt"
    docker logs grav
    exit 1
fi

echo ""

###############################################################################
#                           WACHTEN OP GRAV                                    #
###############################################################################

header "Stap 5/6: Wachten op Grav startup"
echo "───────────────────────────────────────────────────────────────────────"

echo -n "  Grav initialiseren"
WAITED=0
while [[ $WAITED -lt $STARTUP_WAIT ]]; do
    if docker exec grav test -f /app/index.php 2>/dev/null; then
        echo ""
        info "Grav is klaar! (${WAITED} seconden)"
        break
    fi
    echo -n "."
    sleep 2
    WAITED=$((WAITED + 2))
done

if [[ $WAITED -ge $STARTUP_WAIT ]]; then
    echo ""
    warn "Startup duurt langer - doorgaan..."
fi

# Healthcheck status
if docker inspect grav &>/dev/null; then
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' grav 2>/dev/null || echo "starting")
    info "Healthcheck: $HEALTH"
fi

echo ""

###############################################################################
#                           PLUGINS INSTALLATIE                               #
###############################################################################

header "Stap 6/6: Admin panel en plugins"
echo "───────────────────────────────────────────────────────────────────────"

# Grav initialiseren
info "Grav initialiseren..."
docker exec grav bin/grav install > /dev/null 2>&1 || true
sleep 3

# Admin panel
info "Admin panel installeren..."
if docker exec -w /app grav bin/gpm install admin -y > /dev/null 2>&1; then
    info "  Admin panel geïnstalleerd"
else
    warn "  Admin panel installatie mislukt"
fi

# Quark theme
info "Quark theme installeren..."
docker exec -w /app grav bin/gpm install quark -y > /dev/null 2>&1 || true

# Kern plugins
info "Kern plugins installeren..."
for plugin in form email login; do
    echo -n "    • $plugin ... "
    if docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
    fi
done

# Optionele plugins
info "Optionele plugins..."
for plugin in admin-addon-user-manager seo sitemap archives breadcrumbs; do
    echo -n "    • $plugin ... "
    docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1 && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠${NC}"
done

# Cache clearen
info "Cache clearen..."
docker exec grav bin/grav clear-cache > /dev/null 2>&1 || true

echo ""

###############################################################################
#                           FIREWALL                                          #
###############################################################################

if command -v ufw &>/dev/null; then
    if ufw status | grep -q "Status: active"; then
        info "UFW: poort ${GRAV_PORT} openen..."
        ufw allow "${GRAV_PORT}/tcp" > /dev/null 2>&1 || true
    fi
fi

###############################################################################
#                           SAMENVATTING                                      #
###############################################################################

IP_LIST=$(hostname -I 2>/dev/null || echo "")

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    INSTALLATIE VOLTOOID - Debian 13                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}✅ Grav CMS is succesvol geïnstalleerd op Debian 13!${NC}"
echo ""

echo "🌐 Toegang:"
echo "   ├── Frontend: ${BLUE}http://localhost:${GRAV_PORT}${NC}"
echo "   └── Admin:    ${BLUE}http://localhost:${GRAV_PORT}/admin${NC}"
echo ""

if [[ -n "$IP_LIST" ]]; then
    echo "   Netwerk toegang:"
    for ip in $IP_LIST; do
        if [[ "$ip" != "127.0.0.1" && "$ip" != "::1" ]]; then
            echo "   ├── http://${ip}:${GRAV_PORT}"
        fi
    done
    echo ""
fi

echo "👤 Eerste login:"
echo "   1. Open ${BLUE}http://localhost:${GRAV_PORT}/admin${NC}"
echo "   2. Volg de wizard om een admin account aan te maken"
echo ""

echo "🐳 Commando's:"
echo "   ├── Status:    ${BLUE}docker ps${NC}"
echo "   ├── Logs:      ${BLUE}docker logs -f grav${NC}"
echo "   ├── Stoppen:   ${BLUE}cd $GRAV_DIR && docker compose down${NC}"
echo "   └── Starten:   ${BLUE}cd $GRAV_DIR && docker compose up -d${NC}"
echo ""

echo "⚠️  Notities:"
echo "   ├── Docker group actief na ${YELLOW}uit- en inloggen${NC}"
echo "   └── Of: ${BLUE}newgrp docker${NC} in huidige terminal"
echo ""

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

if docker ps | grep -q grav; then
    echo -e "${GREEN}✅ Grav draait!${NC}"
else
    echo -e "${RED}❌ Container draait niet - check: docker logs grav${NC}"
fi

echo ""
echo -e "${GREEN}Klaar!${NC}"
echo ""

exit 0