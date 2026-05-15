# rTorrent Deployment
> How-To Guide

## Wat doet dit script?

Het installeert rTorrent met automatisch starten, een watch map en ingebouwde foutcontrole.

## Benodigdheden

- Een Debian of Ubuntu systeem
- Sudo rechten
- Ansible geïnstalleerd

## Installatie in 3 stappen

1) Sla het playbook op als rtorrent.yml

2) Draai het playbook
```bash
ansible-playbook -K rtorrent.yml
```

3) Check of het werkt
```bash
systemctl --user status rtorrent
```

## Waar vind ik alles?

Je persoonlijke map bevat een nieuwe map 'rtorrent'. Daarin vind je:

- downloading/ - voltooide downloads
- watch/ - plaats hier .torrent bestanden
- .session/ - tijdelijke bestanden
- rtorrent.log - het logboek

## Hoe gebruik ik het?

- Een torrent toevoegen:
Kopieer het .torrent bestand naar ~/rtorrent/watch/

- De service bedienen:
```bash
systemctl --user start rtorrent
systemctl --user stop rtorrent
systemctl --user restart rtorrent
```

- Logboek bekijken:
```bash
tail -f ~/rtorrent/rtorrent.log
```

## Problemen oplossen

- Service start niet:
```bash
tmux kill-session -t rtorrent
systemctl --user restart rtorrent
```

- Geen downloads na herstart:
```bash
loginctl show-user $USER -p Linger
```
(moet 'yes' zijn)

## Alles verwijderen
```bash
systemctl --user stop rtorrent
rm -rf ~/rtorrent ~/.rtorrent.rc
rm -rf ~/.config/systemd/user/rtorrent.service
```

## Belangrijk om te weten

De software draait als gewone gebruiker, niet als root. Bij netwerkverlies stoppen actieve downloads automatisch. Logbestanden worden wekelijks opgeruimd.

Versie 1.0.0