# rTorrent Deployment
> How-To Guide - Versie 1.1.0

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

---

# Voorkomen van dubbele downloads

## Het probleem

Standaard blijft een .torrent bestand in de watch map staan nadat rTorrent hem heeft geladen. Bij een herstart van de service wordt dezelfde torrent opnieuw geladen. Dit leidt tot verwarring en mogelijk dubbele downloads.

## De oplossing

Vanaf versie 1.1.0 verplaatst rTorrent elk .torrent bestand automatisch naar de map 'watch/processed' zodra de download is gestart.

## Hoe het werkt

Eerst kopieer je een .torrent bestand naar de watch map
Daarna laadt rTorrent het bestand binnen 5 seconden
Vervolgens start de download automatisch
Tenslotte verplaatst rTorrent het .torrent bestand naar de processed map

## Wat gebeurt er met verplaatste bestanden

De .torrent bestanden in de processed map blijven bewaard. Je kunt ze handmatig verwijderen als je ze niet meer nodig hebt. Ze worden nooit opnieuw geladen omdat rTorrent alleen naar de watch map kijkt.

## Gevolgen voor jou

Geen dubbele downloads meer
Geen handmatig opruhmen van .torrent bestanden nodig
Een archief van alle ooit geladen torrents in de processed map

## Let op

Als je een torrent wilt hervatten die al in de processed map staat, kopieer hem dan gewoon opnieuw naar de watch map. rTorrent herkent aan de hand van de sessie data dat de download al bestaat en zal niet opnieuw downloaden.

Versie 1.1.0 en hoger