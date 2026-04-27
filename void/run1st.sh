#!/bin/bash
set -e

echo "--- Start post-installatiescript ---"

# 1. Installeer de benodigde Ansible collecties
echo "Bezig met installeren van Ansible collecties..."
ansible-galaxy collection install community.general

# 2. Start het Playbook
echo "Start Ansible Playbook op localhost..."
ansible-playbook -K post-install.yml -c local

echo "--- Klaar! Vergeet niet te rebooten voor de nieuwe kernel en services. ---"
