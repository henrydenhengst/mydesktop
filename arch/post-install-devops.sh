#!/bin/bash
set -euo pipefail

echo "--- DEVOPS POST-INSTALL START ---"

# --- Config ---
USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Pacman update ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- DevOps packages ---
echo "--- Installing DevOps tools ---"
pacman -S --noconfirm --needed \
  ripgrep fd jq yq \
  eza bat duf ncdu tree \
  curl wget nmap dnsutils mtr tcpdump netcat \
  btop htop iotop iftop strace lsof \
  git git-delta lazygit tig github-cli \
  ansible ansible-lint yamllint python-pip \
  docker docker-compose podman buildah skopeo kubectl helm \
  rsync unzip zip xz \
  shellcheck shfmt \
  fzf tmux neovim direnv tldr hyperfine entr parallel

# --- Enable services ---
echo "--- Enabling services ---"
systemctl enable --now docker
systemctl enable --now systemd-timesyncd

# --- Docker permissions ---
echo "--- Configuring Docker permissions ---"
usermod -aG docker "$USERNAME"

# --- Python tools ---
echo "--- Installing Python DevOps tools ---"
sudo -u "$USERNAME" bash <<'EOF'
pip install --user --break-system-packages molecule
EOF

# --- Shell config ---
echo "--- Configuring shell ---"
BASHRC="/home/$USERNAME/.bashrc"

cat >> "$BASHRC" <<'EOF'

# === DEVOPS TOOLING ===

# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias cat='bat'
alias df='duf'
alias top='btop'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

# FZF
[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash

# Direnv
eval "$(direnv hook bash)"
EOF

chown "$USERNAME:$USERNAME" "$BASHRC"

echo "--- DEVOPS INSTALL COMPLETE ---"
echo "IMPORTANT: Log out and back in for Docker group to apply."