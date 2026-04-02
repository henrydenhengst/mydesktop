```bash
# 1) mdns op iedere machine:
ansible-playbook mdns.yml -K

# 2) ALLEEN ALS 1 overal op staat: TRUST
ansible-playbook sync_keys.yml -K

# 3 Maar een hosts.ini
cat > ~/ansible/inventory/hosts.ini << 'EOF'
[all_nodes]
laptop1.local
laptop2.local
server.local

[laptops]
laptop1.local
laptop2.local

[servers]
server.local
EOF

# 4 Voeg aliases toe
echo "alias cssh-all='ansible -i ~/ansible/inventory all_nodes --list-hosts 2>/dev/null | tail -n +2 | xargs -r cssh'" >> ~/.bashrc
echo "alias cssh-all-debug='ansible -i ~/ansible/inventory all_nodes --list-hosts'" >> ~/.bashrc
echo "alias mosh-all='ansible -i ~/ansible/inventory all_nodes --list-hosts 2>/dev/null | tail -n +2 | xargs -I{} mosh {}'" >> ~/.bashrc

source ~/.bashrc

# 5 Schrijf config (overschrijft het bestand als het al bestaat)
cat > ~/.clusterssh/config << 'EOF'
auto_close 0
cols 2
terminal terminator
window_title yes
unique_servers yes
use_all_a_records 1
ssh_args -o ControlMaster=auto -o ControlPersist=60s -o ControlPath=~/.ssh/cm-%C -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o ServerAliveInterval=30 -A
EOF
```
