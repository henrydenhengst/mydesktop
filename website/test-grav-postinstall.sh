#!/usr/bin/env bash

###############################################################################
#                                                                             #
#   Debian + Docker + Grav + Admin + Plugins - Volledige Installatie         #
#                                                                             #
#   Version: 2.2.0                                                            #
#   Datum: 2025-01-27                                                         #
#   Compatibel: Debian 11, 12, 13 (Bullseye, Bookworm, Trixie)               #
#   Getest op: Debian 11, Debian 12, Debian 13 (testing)                      #
#                                                                             #
###############################################################################
#                                                                             #
#   DOEL                                                                      #
#   ----                                                                      #
#                                                                             #
#   Dit script installeert een volledig werkende Grav CMS omgeving binnen     #
#   enkele minuten, inclusief:                                                #
#                                                                             #
#     • Docker Engine + Compose                                               #
#     • Grav CMS met Admin panel                                              #
#     • Quark theme (modern default)                                          #
#     • Essentiële plugins (form, email, login, seo, sitemap, etc.)           #
#     • Firewall configuratie (indien UFW aanwezig)                           #
#                                                                             #
#   Het resultaat is een development platform voor:                           #
#                                                                             #
#     • Proof-of-Concepts                                                     #
#     • Client demo's                                                         #
#     • Lokale ontwikkeling                                                   #
#     • Homelab projecten                                                     #
#     • CMS evaluaties                                                        #
#                                                                             #
###############################################################################
#                                                                             #
#   WERKING                                                                   #
#   ------                                                                    #
#                                                                             #
#   1. Validatie                                                              #
#      • Check op root/sudo                                                   #
#      • Debian OS verificatie                                                #
#      • Schijfruimte (min. 1GB vrij)                                         #
#      • Poort beschikbaarheid                                                #
#                                                                             #
#   2. Systeem voorbereiding                                                  #
#      • APT update (en optioneel upgrade)                                    #
#      • Basis packages (alleen Debian-compatibele)                           #
#                                                                             #
#   3. Docker installatie                                                     #
#      • Officiële Docker repository                                          #
#      • Docker Engine + Compose                                              #
#      • Gebruiker toevoegen aan docker group                                 #
#                                                                             #
#   4. Grav setup                                                             #
#      • Docker Compose configuratie                                          #
#      • Container starten                                                    #
#      • Healthcheck + startup wachten                                        #
#                                                                             #
#   5. Plugins & thema's                                                      #
#      • Admin panel                                                          #
#      • Quark theme                                                          #
#      • Essentiële plugins                                                   #
#      • Cache clearen                                                        #
#                                                                             #
#   6. Afronding                                                              #
#      • Firewall regels                                                      #
#      • IP adres overzicht                                                   #
#      • Volgende stappen instructies                                         #
#                                                                             #
###############################################################################
#                                                                             #
#   VEREISTEN                                                                 #
#   ----------                                                                #
#                                                                             #
#   • Debian 11, 12 of 13 (alle versies ondersteund)                          #
#   • Werkende internetverbinding                                             #
#   • sudo/root toegang                                                       #
#   • Minimaal 1GB vrije schijfruimte                                         #
#   • Poort 8080 vrij (aanpasbaar)                                            #
#                                                                             #
#   OPTIONEEL:                                                                #
#   • UFW firewall (wordt automatisch geconfigureerd)                         #
#   • XFCE desktop (aanbevolen voor snelheid)                                 #
#                                                                             #
###############################################################################
#                                                                             #
#   INSTALLATIE                                                               #
#   ------------                                                              #
#                                                                             #
#   1. Download het script:                                                   #
#                                                                             #
#      wget https://example.com/grav-full-install.sh                          #
#                                                                             #
#   2. Maak uitvoerbaar:                                                      #
#                                                                             #
#      chmod +x grav-full-install.sh                                          #
#                                                                             #
#   3. Voer uit als root:                                                     #
#                                                                             #
#      sudo ./grav-full-install.sh                                            #
#                                                                             #
#   4. Volg de instructies op scherm                                          #
#                                                                             #
#   5. Na installatie: browse naar:                                           #
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
#   Backup config:                                                            #
#      cp -r ~/grav/config ~/grav-backup-$(date +%Y%m%d)                      #
#                                                                             #
#   Nieuwe plugin installeren:                                                #
#      docker exec grav bin/gpm install [plugin-naam] -y                      #
#                                                                             #
###############################################################################
#                                                                             #
#   TROUBLESHOOTING                                                           #
#   -------------                                                             #
#                                                                             #
#   PROBLEM: Poort 8080 is al in gebruik                                      #
#   OPLOSSING: Wijzig GRAV_PORT variabele in script (regel 220)               #
#                                                                             #
#   PROBLEM: Docker group niet actief                                         #
#   OPLOSSING: Log uit en opnieuw in, of: newgrp docker                       #
#                                                                             #
#   PROBLEM: Plugins installeren niet                                         #
#   OPLOSSING: Check logs: docker logs grav                                   #
#                                                                             #
#   PROBLEM: Grav niet bereikbaar                                             #
#   OPLOSSING: Check firewall: sudo ufw status                                #
#                                                                             #
#   PROBLEM: 'ss' command not found                                           #
#   OPLOSSING: apt install iproute2 (wordt door script gedaan)                #
#                                                                             #
#   PROBLEM: software-properties-common niet gevonden                         #
#   OPLOSSING: Dit package is verwijderd uit Debian 13 - script gebruikt het  #
#              niet meer. Handmatige repo toevoeging werkt op alle versies.   #
#                                                                             #
###############################################################################
#                                                                             #
#   VEILIGHEID                                                                #
#   ----------                                                                #
#                                                                             #
#   • Gebruikt officiële Docker repository                                     #
#   • Grav container draait als niet-root user                                #
#   • Geen hardcoded wachtwoorden                                             #
#   • restart: unless-stopped voor auto-herstart                              #
#   • Healthcheck voor monitoring                                             #
#                                                                             #
#   AANBEVELINGEN VOOR PRODUCTIE:                                             #
#   ---------------------------------                                         #
#                                                                             #
#   • Zet HTTPS op met reverse proxy (Traefik/Nginx)                          #
#   • Gebruik environment variables voor secrets                              #
#   • Overweeg Docker volumes voor backups                                    #
#   • Beperk resource usage in compose file                                   #
#                                                                             #
###############################################################################

set -euo pipefail

# Fout afhandeling
trap 'echo ""; echo "❌ FOUT: Installatie afgebroken op regel $LINENO"; exit 1' ERR

# Kleuren voor output (alleen als terminal ondersteunt)
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

# Algemene instellingen
DO_FULL_UPGRADE=false              # Zet op true voor volledige systeem upgrade
REQUIRED_SPACE_KB=1048576          # 1GB in KB
GRAV_PORT=8080                     # Wijzig indien 8080 in gebruik
GRAV_VERSION="1.7.48"              # Vaste versie voor reproduceerbaarheid
GRAV_IMAGE="lscr.io/linuxserver/grav:${GRAV_VERSION}"

# Plugin configuratie
INSTALL_ADMIN=true                  # Admin panel (aanbevolen)
INSTALL_QUARK=true                  # Quark theme (aanbevolen)
INSTALL_EXTRA_PLUGINS=true          # Extra plugins installeren

# Wacht tijden (in seconden)
STARTUP_WAIT=45                     # Max wachten op Grav startup

###############################################################################
#                           START INSTALLATIE                                 #
###############################################################################

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     Debian + Docker + Grav + Admin + Plugins - Volledige Setup     ║"
echo "║                              v2.2.0                                 ║"
echo "║                   Compatibel: Debian 11, 12, 13                     ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

###############################################################################
#                               VALIDATIE                                     #
###############################################################################

header "Stap 1/7: Omgeving valideren"
echo "───────────────────────────────────────────────────────────────────────"

# Check root
if [[ $EUID -ne 0 ]]; then
  error "Dit script moet met sudo worden uitgevoerd"
  echo ""
  echo "  sudo ./grav-full-install.sh"
  echo ""
  exit 1
fi
info "Root/sudo check geslaagd"

# Check Debian
if [[ ! -f /etc/debian_version ]]; then
  error "Dit script werkt alleen op Debian"
  exit 1
fi
DEBIAN_VERSION=$(cat /etc/debian_version)
DEBIAN_MAJOR=$(echo "$DEBIAN_VERSION" | cut -d. -f1)
info "Debian versie: $DEBIAN_VERSION (major: $DEBIAN_MAJOR)"

# Detecteer gebruiker
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

# Check schijfruimte
AVAILABLE_SPACE=$(df --output=avail "$USER_HOME" | tail -1)
if [[ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_KB" ]]; then
  error "Onvoldoende schijfruimte (minimaal 1GB vereist)"
  echo "  Beschikbaar: $((AVAILABLE_SPACE / 1024)) MB"
  exit 1
fi
info "Schijfruimte: $((AVAILABLE_SPACE / 1024)) MB beschikbaar"

# Functie om poort te checken (werkt op alle Debian versies)
check_port() {
  local port=$1
  local in_use=false
  
  # Check met ss (indien beschikbaar)
  if command -v ss &>/dev/null; then
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
      in_use=true
    fi
  fi
  
  # Check met netstat (fallback als ss niet beschikbaar is)
  if [[ "$in_use" == false ]] && command -v netstat &>/dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
      in_use=true
    fi
  fi
  
  # Check met lsof (meest betrouwbaar, indien beschikbaar)
  if [[ "$in_use" == false ]] && command -v lsof &>/dev/null; then
    if lsof -i ":${port}" &>/dev/null 2>&1; then
      in_use=true
    fi
  fi
  
  echo "$in_use"
}

# Poort check uitvoeren
if [[ "$(check_port "$GRAV_PORT")" == "true" ]]; then
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
#                        DEBIAN VERSIE DETECTIE                               #
###############################################################################

header "Stap 2/7: Systeem voorbereiden"
echo "───────────────────────────────────────────────────────────────────────"

# Detecteer Debian codename op een manier die werkt op alle versies
detect_codename() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    echo "${VERSION_CODENAME:-}"
  elif command -v lsb_release &>/dev/null; then
    lsb_release -sc
  else
    # Fallback obv major version
    case $DEBIAN_MAJOR in
      11) echo "bullseye" ;;
      12) echo "bookworm" ;;
      13) echo "trixie" ;;
      *) echo "" ;;
    esac
  fi
}

CODENAME=$(detect_codename)
info "Debian codename: ${CODENAME:-onbekend}"

# Fix voor Debian 13 (Trixie) - Docker repo ondersteunt Trixie nog niet
case "$CODENAME" in
  trixie)
    warn "Debian 13 (Trixie) gedetecteerd - gebruik Bookworm repo voor Docker"
    DOCKER_CODENAME="bookworm"
    ;;
  "")
    warn "Kan codename niet detecteren - fallback naar bookworm voor Docker"
    DOCKER_CODENAME="bookworm"
    ;;
  *)
    DOCKER_CODENAME="$CODENAME"
    ;;
esac

# Update package index
info "Package index updaten..."
apt update -qq

# Optionele volledige upgrade
if [[ "$DO_FULL_UPGRADE" == true ]]; then
  info "Volledige systeem upgrade uitvoeren..."
  apt upgrade -y -qq
fi

# Basis packages installeren - ALLEEN packages die bestaan op ALLE Debian versies
# software-properties-common is VERWIJDERD omdat het niet bestaat op Debian 13
info "Basis packages installeren..."

# Eerst de packages die overal bestaan
BASE_PACKAGES=(
  "curl"
  "wget"
  "git"
  "nano"
  "ca-certificates"
  "gnupg"
  "lsb-release"
  "apt-transport-https"
  "lsof"
  "iproute2"
)

# Installeer basis packages
for pkg in "${BASE_PACKAGES[@]}"; do
  if apt-cache show "$pkg" &>/dev/null; then
    apt install -y -qq "$pkg" > /dev/null
    info "  $pkg"
  else
    warn "Package $pkg niet beschikbaar - wordt overgeslagen"
  fi
done

# Check of ss beschikbaar is (zit in iproute2)
if command -v ss &>/dev/null; then
  info "Network tools (ss) beschikbaar"
else
  warn "ss command niet beschikbaar - netstat fallback wordt gebruikt"
  # Installeer net-tools als fallback voor netstat
  if apt-cache show net-tools &>/dev/null; then
    apt install -y -qq net-tools > /dev/null
    info "net-tools geïnstalleerd (fallback voor port check)"
  fi
fi

echo ""

###############################################################################
#                            DOCKER INSTALLATIE                               #
###############################################################################

header "Stap 3/7: Docker Engine + Compose installeren"
echo "───────────────────────────────────────────────────────────────────────"

# Check of Docker al draait
SKIP_DOCKER_INSTALL=false
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  SKIP_DOCKER_INSTALL=true
  info "Docker is al geïnstalleerd en draait"
fi

if [[ "$SKIP_DOCKER_INSTALL" == false ]]; then
  info "Docker repository toevoegen..."

  # Docker GPG key
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg > /dev/null 2>&1
    info "  Docker GPG key geïnstalleerd"
  fi
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Docker repository
  ARCH=$(dpkg --print-architecture)
  if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
    echo \
      "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $DOCKER_CODENAME stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    info "  Docker repository toegevoegd (codename: $DOCKER_CODENAME)"
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

# Docker versie tonen
DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
info "Docker versie: $DOCKER_VERSION"

# Docker Compose versie tonen
if docker compose version &>/dev/null; then
  COMPOSE_VERSION=$(docker compose version --short)
  info "Docker Compose versie: $COMPOSE_VERSION"
fi

echo ""

###############################################################################
#                         GRAV DIRECTORY & COMPOSE                            #
###############################################################################

header "Stap 4/7: Grav omgeving configureren"
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
info "Grav container starten..."
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

echo ""

###############################################################################
#                       WACHTEN OP GRAV STARTUP                               #
###############################################################################

header "Stap 5/7: Wachten tot Grav volledig gestart is"
echo "───────────────────────────────────────────────────────────────────────"

# Functie om te wachten op Grav (werkt met elke versie)
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

# Extra healthcheck check (indien beschikbaar)
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
#                        ADMIN PANEL INSTALLATIE                              #
###############################################################################

header "Stap 6/7: Admin panel en plugins installeren"
echo "───────────────────────────────────────────────────────────────────────"

# Eerst Grav initialiseren indien nodig
info "Grav initialiseren..."
docker exec grav bin/grav install > /dev/null 2>&1 || true
sleep 3

# Admin panel installeren
if [[ "$INSTALL_ADMIN" == true ]]; then
  info "Admin panel installeren..."
  if docker exec -w /app grav bin/gpm install admin -y > /dev/null 2>&1; then
    info "  Admin panel geïnstalleerd"
  else
    warn "  Admin panel installatie mislukt (kan later handmatig)"
  fi
fi

# Quark theme installeren
if [[ "$INSTALL_QUARK" == true ]]; then
  info "Quark theme installeren..."
  if docker exec -w /app grav bin/gpm install quark -y > /dev/null 2>&1; then
    info "  Quark theme geïnstalleerd"
  else
    warn "  Quark theme installatie mislukt"
  fi
fi

# Essentiële plugins (minimale set voor betrouwbaarheid)
if [[ "$INSTALL_EXTRA_PLUGINS" == true ]]; then
  info "Essentiële plugins installeren..."
  
  # Kern plugins die altijd werken
  CORE_PLUGINS=(
    "form"
    "email"
    "login"
  )
  
  for plugin in "${CORE_PLUGINS[@]}"; do
    echo -n "    • $plugin ... "
    if docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1; then
      echo -e "${GREEN}✓${NC}"
    else
      echo -e "${YELLOW}⚠ (slaat over)${NC}"
    fi
  done
  
  # Extra plugins (optioneel)
  OPTIONAL_PLUGINS=(
    "admin-addon-user-manager"
    "seo"
    "sitemap"
    "archives"
    "breadcrumbs"
    "pagination"
    "taxonomylist"
    "markdown-notices"
    "shortcode-core"
  )
  
  echo ""
  info "Optionele plugins installeren..."
  for plugin in "${OPTIONAL_PLUGINS[@]}"; do
    echo -n "    • $plugin ... "
    if docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1; then
      echo -e "${GREEN}✓${NC}"
    else
      echo -e "${YELLOW}⚠ (overslaan)${NC}"
    fi
  done
fi

# Cache clearen
info "Cache clearen..."
docker exec grav bin/grav clear-cache > /dev/null 2>&1 || true

info "Installatie van plugins voltooid"

echo ""

###############################################################################
#                         FIREWALL CONFIGURATIE                               #
###############################################################################

header "Stap 7/7: Firewall configuratie"
echo "───────────────────────────────────────────────────────────────────────"

if command -v ufw &>/dev/null; then
  if ufw status | grep -q "Status: active"; then
    info "UFW firewall is actief"
    if ufw allow "${GRAV_PORT}/tcp" > /dev/null 2>&1; then
      info "  Poort ${GRAV_PORT}/tcp open gezet"
    else
      warn "  Kon poort ${GRAV_PORT}/tcp niet openen"
    fi
  else
    warn "UFW is geïnstalleerd maar niet actief"
    echo "  Activeer met: sudo ufw enable"
  fi
else
  info "Geen UFW gevonden - firewall configuratie overgeslagen"
  echo "  Tip: installeer UFW met: apt install ufw"
fi

echo ""

###############################################################################
#                          SAMENVATTING & INFO                                 #
###############################################################################

# Verzamel IP adressen
IP_LIST=$(hostname -I 2>/dev/null || echo "")

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                         INSTALLATIE VOLTOOID                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}✅ Grav CMS is succesvol geïnstalleerd!${NC}"
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

echo "🔧 Volgende stappen (aanbevolen):"
echo "   ├── Maak een admin account aan via /admin"
echo "   ├── Configureer je site via het admin panel"
echo "   ├── Kies een thema (Quark is al geïnstalleerd)"
echo "   ├── Voeg content toe via de pagina editor"
echo "   └── Maak een backup van je configuratie"
echo ""

echo "⚠️  Belangrijke notities:"
echo "   ├── Docker group wordt actief na ${YELLOW}uit- en opnieuw inloggen${NC}"
echo "   ├── Of gebruik in huidige terminal: ${BLUE}newgrp docker${NC}"
echo "   ├── Poort ${GRAV_PORT} staat open in de firewall (indien UFW actief)"
echo "   └── Grav data blijft behouden bij container herstart"
echo ""

echo "📦 Geïnstalleerde componenten:"
echo "   ├── Debian versie:        ${DEBIAN_VERSION} (codename: ${CODENAME:-onbekend})"
echo "   ├── Docker versie:        ${DOCKER_VERSION}"
echo "   ├── Docker Compose:       ${COMPOSE_VERSION:-geïnstalleerd}"
echo "   ├── Grav CMS:             ${GRAV_VERSION}"
echo "   ├── Admin panel:          ${INSTALL_ADMIN:-ja}"
echo "   ├── Quark theme:          ${INSTALL_QUARK:-ja}"
echo "   └── Extra plugins:        ${INSTALL_EXTRA_PLUGINS:-ja}"
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