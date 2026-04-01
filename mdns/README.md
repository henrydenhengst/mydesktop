```bash
# 1) mdns op iedere machine:
ansible-playbook mdns.yml -K

# 2) ALLEEN ALS 1 overal op staat: TRUST
ansible-playbook sync_keys.yml -K
```
