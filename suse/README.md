Let op: Vervang $6$yoursalt$hashedpasswordhere door de output van 
```bash
openssl passwd -6
```

**Typ je gewenste wachtwoord** wanneer daarom gevraagd wordt en druk op Enter. (Je zult tijdens het typen niets op het scherm zien, dat is normaal).

**Kopieer de output.** Je krijgt een lange string terug die begint met `$6$`.

### Wat krijg je precies?
De output ziet er ongeveer zo uit:
`$6$a1b2c3d4e5f6g7h8$tW3xY...[een heleboel tekens]`

**`$6$`**: Geeft aan dat het een SHA-512 hash is (de huidige standaard voor Linux).

**`a1b2c3d4e5f6g7h8`**: Dit is de *salt*. Dit zorgt ervoor dat hetzelfde wachtwoord bij iedereen een unieke hash oplevert.

**De rest**: De eigenlijke gehashte versie van je wachtwoord.

---

### Hoe verwerk je dit in je XML?

In je `autoinst.xml` vervang je de regel met de placeholder door deze string.

**Verkeerd (voorbeeld):**
`<user_password>$6$yoursalt$hashedpasswordhere</user_password>`

**Goed (voorbeeld):**
`<user_password>$6$RkX9.3Fh.m...[jouw gekopieerde hash]...</user_password>`

### Belangrijke tips:

**Niet vergeten:** Vergeet niet de tag `<encrypted config:type="boolean">true</encrypted>` direct onder de password-regel te laten staan! Zonder deze regel zal AutoYaST proberen de *hash zelf* als wachtwoord in te stellen (waardoor je niet kunt inloggen).

**Kopiëren:** Zorg dat je de gehele string kopieert, inclusief de `$` tekens.

**Opslaan:** Omdat dit XML-bestand straks op een webserver staat voor je Netboot, is het verstandig om het bestand zelf ook met de juiste rechten (`chmod 600`) op te slaan, zodat niet iedereen op je server zomaar het bestand kan inzien.

---

```
https://raw.githubusercontent.com/henrydenhengst/mydesktop/main/suse/autoinst.xml
```

---



