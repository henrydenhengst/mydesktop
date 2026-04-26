# Website LCH

## 1. Bekijk de site lokaal
Start de engine om live wijzigingen te zien op http://localhost:1313.

```
cd ~/mijn_hugo_site
hugo server -D
```

## 2. Homepage aanpassen (data/)

Het Universal thema bouwt de homepage uit YAML-bestanden. Pas hier de teksten aan:
Diensten: data/features.yml
Recensies: data/testimonials.yml
Klanten: data/clients.yml

## 3. Media toevoegen (static/)

Plaats alle statische bestanden in de juiste map. Gebruik WebP voor snelheid.
Logo: Zet in static/img/logo.webp (Pas de naam aan in hugo.toml).
Banners: Zet slider-afbeeldingen in static/img/.

## 4. Pagina's en Blogs (content/)

Hier komen de Markdown-bestanden van de klant.
Nieuwe pagina: hugo new over-ons.md
Berichten: Bestanden toevoegen of importeren in content/posts/.

## 5. Formulier activeren

Zorg dat de contactpagina jouw spam-vrije script gebruikt.
Action: Koppel het formulier aan /mail.php.
Honeypot: Voeg het verborgen veld <input type="text" name="website" style="display:none"> toe aan de HTML-template van het thema.

## 6. Publiceren

Genereer de definitieve website wanneer je klaar bent:
```
hugo
```

De inhoud van de map public/ is nu klaar voor upload naar de webserver van de klant.