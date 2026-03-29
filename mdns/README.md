```bash
# 1) keys op iedere machine:
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# 2) mdns op iedere machine:
ansible-playbook mdns.yml -K

# 3) ALLEEN ALS 1 + 2 overal op staat: TRUST
ansible-playbook sync_keys.yml -K
```
