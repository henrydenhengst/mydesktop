#!/usr/bin/env bash

###############################################################################
# Debian + Docker + Grav Post Install Script
###############################################################################
#
# WHY
# ----
#
# Dit script automatiseert een snelle test/development omgeving voor:
#
# - Debian Linux
# - Docker Engine
# - Docker Compose
# - Grav CMS
#
# Doel:
#
# Binnen enkele minuten een volledig werkende browser-based Grav omgeving
# beschikbaar hebben zonder handmatige configuratie van repositories,
# packages, containers en compose files.
#
# Ideaal voor:
#
# - snelle Proof-of-Concepts
# - development/testing
# - homelab omgevingen
# - tijdelijke demo setups
# - CMS evaluaties
# - lokale container testing
#
#
# HOW
# ----
#
# Het script doet automatisch:
#
# 1. Validatie van omgeving en gebruiker
# 2. Controle op vrije schijfruimte
# 3. Installatie van basis packages
# 4. Installatie van Docker repository
# 5. Installatie van Docker Engine + Compose
# 6. Toevoegen gebruiker aan docker group
# 7. Aanmaken van Grav compose omgeving
# 8. Starten van Grav container
# 9. Validatie van draaiende container
#
#
# PREREQUISITES
# -------------
#
# Ondersteund:
#
# - Debian 12+
#
# Aanbevolen desktop:
#
# - XFCE
#
# Vereist:
#
# - Werkende internetverbinding
# - sudo/root toegang
# - Minimaal 1GB vrije schijfruimte
#
#
# INSTALLATIE
# -----------
#
# 1. Bestand opslaan:
#
#    test-grav-postinstall.sh
#
# 2. Execute permission geven:
#
#    chmod +x test-grav-postinstall.sh
#
# 3. Script uitvoeren:
#
#    sudo ./test-grav-postinstall.sh
#
#
# RESULTAAT
# ----------
#
# Grav wordt bereikbaar via:
#
#    http://localhost:8080
#
# Of via netwerk:
#
#    http://<IP-ADRES>:8080
#
#
# BESTANDEN
# ----------
#
# Compose directory:
#
#    ~/grav
#
# Persistente data:
#
#    ~/grav/config
#
#
# HANDIGE COMMANDS
# ----------------
#
# Containers bekijken:
#
#    docker ps
#
# Logs bekijken:
#
#    docker logs -f grav-grav-1
#
# Stoppen:
#
#    cd ~/grav
#    docker compose down
#
# Starten:
#
#    cd ~/grav
#    docker compose up -d
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
echo " Debian + Docker + Grav Installer"
echo "========================================="
echo ""

###############################################################################
# ROOT CHECK
###############################################################################

if [[ $EUID -ne 0 ]]; then
  echo "Run dit script met sudo:"
  echo ""
  echo "  sudo ./test-grav-post-install.sh"
  echo ""
  exit 1
fi

###############################################################################
# DEBIAN CHECK
###############################################################################

if [[ ! -f /etc/debian_version ]]; then
  echo "Fout: alleen Debian wordt ondersteund."
  exit 1
fi

###############################################################################
# USER DETECTION
###############################################################################

USERNAME="${SUDO_USER:-$USER}"

if ! id "$USERNAME" &>/dev/null; then
  echo "Fout: gebruiker '$USERNAME' bestaat niet."
  exit 1
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

if [[ -z "$USER_HOME" ]]; then
  echo "Fout: home directory van '$USERNAME' niet gevonden."
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
  echo "Fout: onvoldoende vrije schijfruimte."
  echo ""
  echo "Benodigd : minimaal 1GB"
  echo "Beschikbaar: $((AVAILABLE_SPACE / 1024)) MB"
  echo ""
  exit 1
fi

###############################################################################
# PORT CHECK
###############################################################################

if ss -tuln | grep -q ":${GRAV_PORT} "; then
  echo "Fout: poort ${GRAV_PORT} is al in gebruik."
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
  echo "==> Volledige systeem upgrade..."
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

  echo "==> Docker service activeren..."

  systemctl enable docker
  systemctl start docker

  echo "==> Gebruiker toevoegen aan docker group..."

  usermod -aG docker "$USERNAME"

else

  echo "==> Docker draait al, installatie overslaan..."

fi

###############################################################################
# OPTIONAL FIREWALL
###############################################################################

if command -v ufw &>/dev/null; then
  echo "==> Firewall regel toevoegen voor poort ${GRAV_PORT}..."
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

echo "==> Wachten op container startup..."

sleep 8

###############################################################################
# VERIFY CONTAINER
###############################################################################

if runuser -u "$USERNAME" -- docker compose ps --status running | grep -q grav; then
  echo "==> Grav container draait."
else
  echo ""
  echo "WAARSCHUWING:"
  echo "Grav container lijkt niet correct te draaien."
  echo ""
  echo "Controleer logs:"
  echo ""
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

echo "Open Grav lokaal via:"
echo ""
echo "  http://localhost:${GRAV_PORT}"
echo ""

if [[ -n "$IP_LIST" ]]; then
  echo "Of vanaf andere machines:"
  echo ""

  for ip in $IP_LIST; do
    echo "  http://${ip}:${GRAV_PORT}"
  done

  echo ""
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