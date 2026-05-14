#!/usr/bin/env bash

###############################################################################
# Debian + Docker + Grav CMS Full Installer
###############################################################################
#
# WHY
# ----
#
# Dit script automatiseert een complete Grav CMS test/development omgeving.
#
# Inclusief:
#
# - Debian validatie
# - Docker Engine
# - Docker Compose
# - Grav CMS
# - Grav Admin Panel
# - Veelgebruikte standaard plugins
# - Quark theme
#
# Doel:
#
# Binnen enkele minuten een volledig werkende browser-based Grav omgeving
# beschikbaar hebben zonder handmatige configuratie.
#
#
# WAT WORDT GEÏNSTALLEERD
# -----------------------
#
# Core:
# - Grav CMS
# - Grav Admin
#
# Plugins:
# - form
# - email
# - login
# - admin-addon-user-manager
# - archives
# - breadcrumbs
# - feed
# - pagination
# - relatedpages
# - seo
# - sitemap
# - taxonomylist
# - random
# - highlight
# - markdown-notices
# - shortcode-core
# - twigfeeds
# - external-links
# - image-captions
# - lightbox-gallery
# - readingtime
#
# Theme:
# - Quark
#
#
# PREREQUISITES
# -------------
#
# Ondersteund:
# - Debian 12
# - Debian 11
#
# Vereist:
# - sudo/root rechten
# - internetverbinding
# - minimaal 1GB vrije ruimte
#
#
# INSTALLATIE
# -----------
#
# chmod +x test-grav-postinstall.sh
# sudo ./test-grav-postinstall.sh
#
###############################################################################

set -euo pipefail

trap 'echo ""; echo "FOUT: installatie afgebroken."; exit 1' ERR

###############################################################################
# CONFIG
###############################################################################

DO_FULL_UPGRADE=false
REQUIRED_SPACE_KB=1048576
GRAV_PORT=8080
GRAV_IMAGE="lscr.io/linuxserver/grav:1.7.48"

###############################################################################
# START
###############################################################################

echo "========================================="
echo " Debian + Docker + Grav Full Installer"
echo "========================================="
echo ""

###############################################################################
# ROOT CHECK
###############################################################################

if [[ $EUID -ne 0 ]]; then
  echo "Gebruik sudo:"
  echo ""
  echo "  sudo ./test-grav-postinstall.sh"
  echo ""
  exit 1
fi

###############################################################################
# DEBIAN CHECK
###############################################################################

if [[ ! -f /etc/debian_version ]]; then
  echo "Alleen Debian wordt ondersteund."
  exit 1
fi

###############################################################################
# USER DETECTION
###############################################################################

USERNAME="${SUDO_USER:-$USER}"

if ! id "$USERNAME" &>/dev/null; then
  echo "Gebruiker bestaat niet: $USERNAME"
  exit 1
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

if [[ -z "$USER_HOME" ]]; then
  echo "Kan home directory niet bepalen."
  exit 1
fi

GRAV_DIR="$USER_HOME/grav"

echo "Gebruiker : $USERNAME"
echo "Home       : $USER_HOME"
echo "Grav dir   : $GRAV_DIR"
echo ""

###############################################################################
# DISK SPACE CHECK
###############################################################################

AVAILABLE_SPACE=$(df --output=avail "$USER_HOME" | tail -1)

if [[ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_KB" ]]; then
  echo "Minimaal 1GB vrije ruimte vereist."
  exit 1
fi

###############################################################################
# PORT CHECK
###############################################################################

if ss -tuln | grep -q ":${GRAV_PORT} "; then
  echo "Poort ${GRAV_PORT} is al in gebruik."
  echo ""
  echo "Gebruik:"
  echo "  ss -tulnp | grep ${GRAV_PORT}"
  echo ""
  exit 1
fi

###############################################################################
# DOCKER CHECK
###############################################################################

SKIP_DOCKER_INSTALL=false

if command -v docker &>/dev/null; then
  if docker info &>/dev/null; then
    SKIP_DOCKER_INSTALL=true
  fi
fi

###############################################################################
# SYSTEM UPDATE
###############################################################################

echo "==> Package index updaten..."
apt update

if [[ "$DO_FULL_UPGRADE" == true ]]; then
  echo "==> Volledige upgrade uitvoeren..."
  apt upgrade -y
fi

###############################################################################
# BASE PACKAGES
###############################################################################

echo "==> Basis packages installeren..."

apt install -y \
  curl \
  wget \
  git \
  nano \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

###############################################################################
# DOCKER INSTALL
###############################################################################

if [[ "$SKIP_DOCKER_INSTALL" == false ]]; then

  echo "==> Docker installeren..."

  install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  fi

  chmod a+r /etc/apt/keyrings/docker.gpg

  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

  if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
    echo \
      "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $CODENAME stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi

  apt update

  apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  usermod -aG docker "$USERNAME"

else

  echo "==> Docker draait al."

fi

###############################################################################
# OPTIONAL FIREWALL
###############################################################################

if command -v ufw &>/dev/null; then
  echo "==> Firewall openen voor ${GRAV_PORT}/tcp ..."
  ufw allow "${GRAV_PORT}/tcp" || true
fi

###############################################################################
# CREATE GRAV DIRECTORY
###############################################################################

echo "==> Grav directory aanmaken..."

mkdir -p "$GRAV_DIR"

###############################################################################
# WRITE COMPOSE FILE
###############################################################################

echo "==> Docker Compose configuratie schrijven..."

cat > "$GRAV_DIR/compose.yml" <<EOF
services:
  grav:
    image: ${GRAV_IMAGE}
    ports:
      - "${GRAV_PORT}:80"
    volumes:
      - ./config:/config
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

###############################################################################
# OWNERSHIP
###############################################################################

chown -R "$USERNAME":"$USERNAME" "$GRAV_DIR"

###############################################################################
# START CONTAINER
###############################################################################

echo "==> Grav container starten..."

cd "$GRAV_DIR"

runuser -u "$USERNAME" -- docker compose up -d

###############################################################################
# WAIT FOR STARTUP
###############################################################################

echo "==> Wachten op Grav startup..."

sleep 15

###############################################################################
# INSTALL PLUGINS
###############################################################################

echo "==> Grav plugins installeren..."

CONTAINER_ID=$(docker ps --format '{{.Names}}' | grep grav | head -n1)

if [[ -z "$CONTAINER_ID" ]]; then
  echo "Grav container niet gevonden."
  exit 1
fi

###############################################################################
# ADMIN
###############################################################################

echo "==> Admin plugin installeren..."

docker exec "$CONTAINER_ID" bin/gpm install admin -y || true

###############################################################################
# DEFAULT PLUGINS
###############################################################################

PLUGINS=(
  "form"
  "email"
  "login"
  "admin-addon-user-manager"
  "archives"
  "breadcrumbs"
  "feed"
  "pagination"
  "relatedpages"
  "seo"
  "sitemap"
  "taxonomylist"
  "random"
  "highlight"
  "markdown-notices"
  "shortcode-core"
  "twigfeeds"
  "external-links"
  "image-captions"
  "lightbox-gallery"
  "readingtime"
)

for plugin in "${PLUGINS[@]}"; do
  echo "==> Installing plugin: $plugin"
  docker exec "$CONTAINER_ID" bin/gpm install "$plugin" -y || true
done

###############################################################################
# THEME
###############################################################################

echo "==> Quark theme installeren..."

docker exec "$CONTAINER_ID" bin/gpm install quark -y || true

###############################################################################
# CLEAR CACHE
###############################################################################

echo "==> Cache legen..."

docker exec "$CONTAINER_ID" bin/grav clear-cache || true

###############################################################################
# VERIFY CONTAINER
###############################################################################

echo "==> Container status controleren..."

if runuser -u "$USERNAME" -- docker compose ps --status running | grep -q grav; then
  echo "==> Grav draait correct."
else
  echo ""
  echo "WAARSCHUWING:"
  echo "Container lijkt niet correct te draaien."
  echo ""
  echo "Controleer logs:"
  echo "  docker compose logs"
  echo ""
fi

###############################################################################
# NETWORK INFO
###############################################################################

IP_LIST=$(hostname -I)

###############################################################################
# DONE
###############################################################################

echo ""
echo "========================================="
echo " INSTALLATIE VOLTOOID"
echo "========================================="
echo ""

echo "Grav website:"
echo ""
echo "  http://localhost:${GRAV_PORT}"
echo ""

echo "Grav Admin:"
echo ""
echo "  http://localhost:${GRAV_PORT}/admin"
echo ""

if [[ -n "$IP_LIST" ]]; then
  echo "Beschikbaar via netwerk:"
  echo ""

  for ip in $IP_LIST; do
    echo "  http://${ip}:${GRAV_PORT}"
    echo "  http://${ip}:${GRAV_PORT}/admin"
    echo ""
  done
fi

echo "Docker commando's:"
echo ""
echo "  docker ps"
echo "  docker compose logs -f"
echo ""

echo "Health status:"
echo ""
echo "  docker inspect --format='{{.State.Health.Status}}' grav-grav-1"
echo ""

echo "Compose directory:"
echo ""
echo "  ${GRAV_DIR}"
echo ""

echo "BELANGRIJK:"
echo ""
echo "Docker group membership wordt actief in nieuwe shells."
echo ""

echo "Optie 1:"
echo "  Log uit en opnieuw in"
echo ""

echo "Optie 2:"
echo "  newgrp docker"
echo ""

echo "Daarna kun je docker zonder sudo gebruiken."
echo ""