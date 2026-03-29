```bash
# keys op iedere machine:
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# mdns op iedere machine:
ansible-playbook mdns.yml -K

# als dat overal op staat: TRUST
ansible-playbook sync_keys.yml -K
```
