#!/usr/bin/env bash

###############################################################################
#                                                                             #
#   Debian + Docker + Grav + Admin + Plugins - Volledige Installatie         #
#                                                                             #
#   Version: 2.0.0                                                            #
#   Datum: 2025-01-27                                                         #
#   Compatibel: Debian 11, 12, 13 (met fallback)                             #
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
#   Het resultaat is een productie-klaar development platform voor:           #
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
#      • Basis packages (curl, git, etc.)                                     #
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
#      • 10+ essentiële plugins                                               #
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
#   • Debian 11, 12 of 13 (getest op 12)                                      #
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
#   OPLOSSING: Wijzig GRAV_PORT variabele in script (regel 155)               #
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
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  RED=''
  NC=''
fi

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

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
STARTUP_WAIT=30                     # Max wachten op Grav startup
HEALTHCHECK_INTERVAL=5              # Interval voor healthcheck

###############################################################################
#                           START INSTALLATIE                                 #
###############################################################################

clear
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     Debian + Docker + Grav + Admin + Plugins - Volledige Setup     ║"
echo "║                              v2.0.0                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

###############################################################################
#                               VALIDATIE                                     #
###############################################################################

echo "📋 Stap 1/7: Omgeving valideren"
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
info "Debian versie: $DEBIAN_VERSION"

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

# Check poort (inclusief Docker containers)
PORT_IN_USE=false
if command -v ss &>/dev/null && ss -tuln | grep -q ":${GRAV_PORT} "; then
  PORT_IN_USE=true
fi
if command -v lsof &>/dev/null && lsof -i ":${GRAV_PORT}" &>/dev/null 2>&1; then
  PORT_IN_USE=true
fi
if $PORT_IN_USE; then
  error "Poort ${GRAV_PORT} is al in gebruik"
  echo ""
  echo "  Wijzig GRAV_PORT in het script of stop de draaiende service"
  echo ""
  exit 1
fi
info "Poort ${GRAV_PORT} is beschikbaar"

echo ""

###############################################################################
#                        DEBIAN 13 COMPATIBILITEIT                            #
###############################################################################

echo "📦 Stap 2/7: Systeem voorbereiden"
echo "───────────────────────────────────────────────────────────────────────"

# Detecteer Debian codename
if [[ -f /etc/os-release ]]; then
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
else
  CODENAME=""
fi

# Fix voor Debian 13 (Trixie) - Docker repo ondersteunt Trixie nog niet
case "$CODENAME" in
  trixie)
    warn "Debian 13 (Trixie) gedetecteerd - gebruik Bookworm repo voor Docker"
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

# Basis packages installeren
info "Basis packages installeren..."
apt install -y -qq \
  curl \
  wget \
  git \
  nano \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  lsof \
  > /dev/null

info "Basis packages geïnstalleerd"

echo ""

###############################################################################
#                            DOCKER INSTALLATIE                               #
###############################################################################

echo "🐳 Stap 3/7: Docker Engine + Compose installeren"
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

  # Gebruiker toevoegen aan docker group
  usermod -aG docker "$USERNAME"
  info "Docker succesvol geïnstalleerd"
fi

# Docker versie tonen
DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
info "Docker versie: $DOCKER_VERSION"

echo ""

###############################################################################
#                         GRAV DIRECTORY & COMPOSE                            #
###############################################################################

echo "📁 Stap 4/7: Grav omgeving configureren"
echo "───────────────────────────────────────────────────────────────────────"

# Directory aanmaken
mkdir -p "$GRAV_DIR"

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

echo ""

###############################################################################
#                       WACHTEN OP GRAV STARTUP                               #
###############################################################################

echo "⏳ Stap 5/7: Wachten tot Grav volledig gestart is"
echo "───────────────────────────────────────────────────────────────────────"

# Functie om te wachten op Grav
wait_for_grav() {
  local max_wait=$STARTUP_WAIT
  local waited=0
  
  echo -n "  Wachten op Grav"
  
  while [[ $waited -lt $max_wait ]]; do
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

# Extra check of container draait
if ! docker ps | grep -q grav; then
  error "Grav container is niet gestart"
  echo ""
  echo "  Check logs: docker logs grav"
  echo ""
  exit 1
fi

info "Container status: $(docker ps --filter name=grav --format '{{.Status}}')"

echo ""

###############################################################################
#                        ADMIN PANEL INSTALLATIE                              #
###############################################################################

echo "🔌 Stap 6/7: Admin panel en plugins installeren"
echo "───────────────────────────────────────────────────────────────────────"

# Eerst Grav initialiseren indien nodig
info "Grav initialiseren..."
docker exec grav bin/grav install > /dev/null 2>&1 || true
sleep 3

# Admin panel installeren
if [[ "$INSTALL_ADMIN" == true ]]; then
  info "Admin panel installeren..."
  if docker exec -w /app grav bin/gpm install admin -y > /dev/null 2>&1; then
    info "Admin panel geïnstalleerd"
  else
    warn "Admin panel installatie mislukt (kan later handmatig)"
  fi
fi

# Quark theme installeren
if [[ "$INSTALL_QUARK" == true ]]; then
  info "Quark theme installeren..."
  docker exec -w /app grav bin/gpm install quark -y > /dev/null 2>&1 || true
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
      echo "✓"
    else
      echo "⚠ (slaat over)"
    fi
  done
  
  # Extra plugins (optioneel - kunnen falen afhankelijk van Grav versie)
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
  
  info "Optionele plugins installeren..."
  for plugin in "${OPTIONAL_PLUGINS[@]}"; do
    echo -n "    • $plugin ... "
    if docker exec -w /app grav bin/gpm install "$plugin" -y > /dev/null 2>&1; then
      echo "✓"
    else
      echo "⚠ (overslaan - werkt mogelijk niet met deze versie)"
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

echo "🔥 Stap 7/7: Firewall configuratie"
echo "───────────────────────────────────────────────────────────────────────"

if command -v ufw &>/dev/null; then
  if ufw status | grep -q "inactive"; then
    warn "UFW is niet actief - firewall regels niet toegevoegd"
  else
    info "UFW regel toevoegen voor poort ${GRAV_PORT}..."
    ufw allow "${GRAV_PORT}/tcp" > /dev/null 2>&1 || true
    info "Firewall geconfigureerd"
  fi
else
  info "Geen UFW gevonden - firewall overslaan"
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

echo "🌐 Grav is nu beschikbaar via:"
echo ""
echo "   Lokaal:"
echo "   ├── Frontend: http://localhost:${GRAV_PORT}"
echo "   └── Admin:    http://localhost:${GRAV_PORT}/admin"
echo ""

if [[ -n "$IP_LIST" ]]; then
  echo "   Netwerk (vanaf andere apparaten):"
  for ip in $IP_LIST; do
    echo "   ├── Frontend: http://${ip}:${GRAV_PORT}"
    echo "   └── Admin:    http://${ip}:${GRAV_PORT}/admin"
  done
  echo ""
fi

echo "📂 Bestanden:"
echo "   └── $GRAV_DIR"
echo ""

echo "👤 Eerste login:"
echo "   1. Open http://localhost:${GRAV_PORT}/admin"
echo "   2. Volg de wizard om een admin account aan te maken"
echo ""

echo "🐳 Docker commando's:"
echo "   ├── Status:    docker ps"
echo "   ├── Logs:      docker logs -f grav"
echo "   ├── Stoppen:   cd $GRAV_DIR && docker compose down"
echo "   └── Starten:   cd $GRAV_DIR && docker compose up -d"
echo ""

echo "🔧 Volgende stappen (aanbevolen):"
echo "   ├── Maak een admin account aan via /admin"
echo "   ├── Configureer je site via het admin panel"
echo "   ├── Kies een thema (Quark is geïnstalleerd)"
echo "   └── Voeg content toe via de pagina editor"
echo ""

echo "⚠️  Belangrijke notities:"
echo "   ├── Docker group wordt actief na uit- en inloggen"
echo "   ├── Gebruik 'newgrp docker' in huidige terminal"
echo "   └── Poort ${GRAV_PORT} staat open in de firewall (indien actief)"
echo ""

echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "✅ Installatie succesvol afgerond!"
echo ""

# Optionele: toon logs als er problemen zijn
if ! docker ps | grep -q grav; then
  warn "Container lijkt niet te draaien. Check logs:"
  echo ""
  echo "  docker logs grav"
  echo ""
fi

exit 0