# Functionele Instructie: Universeel Android Flashing Station (Debian)

Deze instructie beschrijft de inrichting en het gebruik van een Debian Linux-systeem als beheercentrum voor het installeren van alternatieve besturingssystemen op smartphones van de 8 belangrijkste fabrikanten.

## Overzicht Mappenstructuur & Scriptlocatie (Debian Flashing Station)

Voor een correcte werking van het `flash-master.sh` script is het essentieel dat de bestanden exact op de volgende locaties staan binnen je Gebruikersmap (`~`).

### 1. Locatie van het Master-Script
Plaats het script direct in de `android` hoofdmap voor snelle toegang:
* **Bestandspad:** `~/android/flash-master.sh`
* **Rechten:** Uitvoerbaar maken met `chmod +x ~/android/flash-master.sh`

---

### 2. De Volledige Mappenboom
De mappen worden automatisch beheerd door het script en je Ansible-setup:

```text
/home/[gebruiker]/
├── platform-tools/              # De nieuwste Google binaries (adb/fastboot)
└── android/                     # Hoofdmap Flashing Station
    ├── flash-master.sh          # Het centrale Dashboard script
    ├── global/
    │   └── apps/                # Plaats hier je .apk bestanden voor auto-install
    ├── google/                  # Leverancier 1
    │   ├── grapheneos/          # ROM 1
    │   │   ├── images/          # .img en .zip bestanden
    │   │   ├── docs/            # Handleidingen & CHECKLIST.txt
    │   │   ├── tools/           # Specifieke flash-scripts
    │   │   └── backups/         # Toestel-specifieke backups
    │   ├── lineageos/           # ROM 2
    │   ├── eos/                 # ROM 3
    │   ├── calyxos/             # ROM 4
    │   └── evolutionx/          # ROM 5
    ├── motorola/                # Leverancier 2 (met dezelfde 5 ROM-mappen)
    ├── samsung/                 # Leverancier 3
    ├── xiaomi/                  # Leverancier 4
    ├── fairphone/               # Leverancier 5
    ├── sony/                    # Leverancier 6
    ├── nothing/                 # Leverancier 7
    └── asus/                    # Leverancier 8
```

---

## 1. Systeemconfiguratie & Eisen
Het station is technisch voorbereid om zonder beperkingen met mobiele hardware te communiceren.

* **Browserbeleid:** Gebruik uitsluitend **Chromium** voor installaties (zoals GrapheneOS en CalyxOS). Deze browsers ondersteunen *WebUSB*, wat noodzakelijk is om software vanuit de browser direct naar de telefoonkabel te sturen. Firefox is hiervoor niet geschikt.
* **USB-Herkenning:** Het systeem herkent automatisch de hardware-ID's van de volgende 8 fabrikanten:
    1.  **Google** (Pixel)
    2.  **Motorola**
    3.  **Samsung**
    4.  **Xiaomi**
    5.  **Fairphone**
    6.  **Sony**
    7.  **Nothing**
    8.  **ASUS**
* **Processtabiliteit:** De achtergronddienst `fwupd` (Firmware Update Daemon) is uitgeschakeld om te voorkomen dat het systeem de USB-poort "kaapt" tijdens een kritiek flash-proces. De firewall (`ufw`) blijft voor de veiligheid gewoon actief.

---

## 2. Organisatie: De Mappenstructuur
Alle bestanden worden strikt gescheiden opgeslagen in de map `~/android/` om fouten tussen verschillende toestellen en softwareversies te voorkomen.

**Structuur: `Fabrikant / Besturingssysteem / Categorie`**

* **`/images`**: Bevat de eigenlijke installatiebestanden (.zip of .img).
* **`/docs`**: Bevat de handleidingen, unlock-codes en de unieke CHECKLIST.txt.
* **`/tools`**: Bevat merkspecifieke hulpprogramma's (zoals de Calyx-flasher of Samsung-tools).
* **`/backups`**: De veilige plek voor de originele fabriekssoftware voordat de telefoon wordt aangepast.

---

## 3. Operationeel Stappenplan (Workflow)

Volg bij elke installatie deze drie fasen om de integriteit van de smartphone te waarborgen:

### Fase A: Voorbereiding op het Toestel
1.  Activeer de **Ontwikkelaarsopties** (7x tikken op 'Build-nummer' in de instellingen).
2.  Schakel **USB-foutopsporing** (USB Debugging) in.
3.  Schakel **OEM-ontgrendeling** in (indien beschikbaar).
4.  Maak een volledige backup van persoonlijke data naar de `/backups` map op de PC.

### Fase B: Hardware Ontgrendelen (Bootloader)
* **Google/Nothing:** Eenvoudig via een commando of de browser-installer.
* **Motorola/Xiaomi/Sony:** Vereist meestal een unieke code die via de officiële website van de fabrikant moet worden aangevraagd.
* **Samsung:** Gebruikt 'Download Mode' in combinatie met het programma **Heimdall**.

### Fase C: De Installatie uitvoeren
* **Web-installatie (GrapheneOS/CalyxOS):** Verbind de telefoon in *Fastboot-modus* en gebruik de "Install"-knop in Chromium.
* **Handmatige installatie (LineageOS/Evolution X):** Navigeer in de terminal naar de betreffende `/images` map en gebruik de opdrachten `fastboot` of `adb sideload`.
* **Systeem-update:** Bij privacy-systemen wordt de bootloader na installatie weer vergrendeld; bij hobby-systemen blijft deze vaak open.

---

## 4. Veiligheidsvoorschriften
* **Stroom:** Begin nooit aan een installatie als de accu onder de **70%** is.
* **Kabels:** Gebruik alleen originele of gecertificeerde USB-datakabels. Goedkope laadkabels kunnen halverwege de verbinding verbreken, wat leidt tot een "bricked" toestel.
* **Checklist:** Vink altijd de `CHECKLIST.txt` af die in elke `docs`-map staat voordat je op de definitieve 'Flash'-knop drukt.

---

# Top 50 Populaire Smartphones & Aanbevolen ROMs (2026 Update)

Deze lijst is geoptimaliseerd voor gebruik met je Debian Flashing Station. De "Beste ROM" is geselecteerd op basis van stabiliteit, driver-ondersteuning en privacy-garanties.

---

### 1. Google (De Privacy-Standaard)
*Besturingssysteem: **GrapheneOS** (voor maximale security) of **CalyxOS** (voor balans).*

1.  **Pixel 8 Pro** -> GrapheneOS
2.  **Pixel 8** -> GrapheneOS
3.  **Pixel 7 Pro** -> GrapheneOS
4.  **Pixel 7** -> GrapheneOS
5.  **Pixel 7a** -> GrapheneOS
6.  **Pixel 6 Pro** -> GrapheneOS
7.  **Pixel 6** -> GrapheneOS
8.  **Pixel 6a** -> GrapheneOS
9.  **Pixel 5** -> CalyxOS (vanwege aflopende Google-support)
10. **Pixel 4a (5G)** -> CalyxOS

### 2. Motorola (De Snelheid-Koning)
*Besturingssysteem: **LineageOS** (voor pure snelheid en updates).*

11. **Edge 50 Pro** -> LineageOS
12. **Edge 40** -> LineageOS
13. **Moto G84 5G** -> LineageOS
14. **Moto G54** -> LineageOS
15. **Moto G100** -> LineageOS
16. **Moto G200** -> LineageOS
17. **Edge 30 Ultra** -> LineageOS
18. **Razr (2023)** -> LineageOS (experimenteel)

### 3. Samsung (De De-Google Specialist)
*Besturingssysteem: **/e/OS** (beste ondersteuning voor Samsung hardware).*

19. **Galaxy S23 Ultra** -> /e/OS
20. **Galaxy S22** -> /e/OS
21. **Galaxy S21 FE** -> /e/OS
22. **Galaxy S20** -> /e/OS
23. **Galaxy A54** -> /e/OS
24. **Galaxy A52s 5G** -> /e/OS
25. **Galaxy Tab S8** -> /e/OS (Tablet)
26. **Galaxy Note 20** -> /e/OS

### 4. Xiaomi / Poco (De Performance-Favoriet)
*Besturingssysteem: **Evolution X** (voor Pixel-ervaring op krachtige hardware).*

27. **Poco F5** -> Evolution X
28. **Poco F3** -> Evolution X
29. **Poco X5 Pro** -> LineageOS
30. **Redmi Note 12 Pro** -> Evolution X
31. **Xiaomi 13** -> Evolution X
32. **Xiaomi 12T** -> Evolution X
33. **Mi 11 Ultra** -> LineageOS
34. **Redmi Note 10 Pro** -> Evolution X

### 5. OnePlus (De Community Classic)
*Besturingssysteem: **LineageOS** (zeer stabiele drivers).*

35. **OnePlus 11** -> LineageOS
36. **OnePlus 10 Pro** -> LineageOS
37. **OnePlus 9RT** -> LineageOS
38. **OnePlus 8T** -> LineageOS
39. **OnePlus Nord 3** -> LineageOS
40. **OnePlus Nord 2T** -> LineageOS

### 6. Fairphone (De Ethische Keuze)
*Besturingssysteem: **/e/OS** (officieel ondersteund).*

41. **Fairphone 5** -> /e/OS
42. **Fairphone 4** -> /e/OS
43. **Fairphone 3+** -> /e/OS

### 7. Sony & ASUS (De Multimedia Krachtpatsers)
*Besturingssysteem: **LineageOS** (behoud van camerakwaliteit en snelheid).*

44. **Xperia 1 V** -> LineageOS
45. **Xperia 5 IV** -> LineageOS
46. **Xperia 10 V** -> LineageOS
47. **Zenfone 10** -> LineageOS

### 8. Nothing (De Moderne Minimalist)
*Besturingssysteem: **LineageOS** of **Evolution X**.*

48. **Nothing Phone (2)** -> LineageOS
49. **Nothing Phone (1)** -> Evolution X
50. **Nothing Phone (2a)** -> LineageOS

---

## Belangrijke Controle voor Flashen:
Voordat je begint, controleer altijd het **exacte modelnummer** (bijv. SM-G991B voor Samsung). Amerikaanse varianten (Verizon/AT&T) hebben vaak vergrendelde bootloaders die niet te kraken zijn, ongeacht het station dat je gebruikt.


# Uitgebreide Top 100 Smartphones & ROM-advies (Deel 2: 51-100)

Deze lijst vult de eerdere top 50 aan en richt zich op budgetmodellen, oudere vlaggenschepen die nog uitstekend presteren met een nieuwe ROM, en tablets.

---

### 1. Google (Legacy & Tablets)
*Focus: Verlengen van levensduur van hardware.*

51. **Pixel Fold** -> GrapheneOS
52. **Pixel Tablet** -> GrapheneOS
53. **Pixel 5a** -> CalyxOS
54. **Pixel 4 XL** -> LineageOS
55. **Pixel 4** -> LineageOS
56. **Pixel 3a XL** -> LineageOS
57. **Pixel 3 XL** -> LineageOS (Legacy support)

### 2. Motorola (Budget & G-Serie)
*Focus: Maximaal resultaat uit goedkope hardware.*

58. **Moto G73 5G** -> LineageOS
59. **Moto G52** -> LineageOS
60. **Moto G42** -> LineageOS
61. **Moto G32** -> LineageOS
62. **Moto G Power (2022)** -> LineageOS
63. **Moto G Stylus 5G** -> LineageOS
64. **Edge 30 Pro** -> Evolution X
65. **Edge 20 Pro** -> LineageOS
66. **One Action** -> /e/OS

### 3. Samsung (Oudere S-Serie & A-Serie)
*Focus: De-Googling van populaire consumententoestellen.*

67. **Galaxy S10+** -> /e/OS
68. **Galaxy S10e** -> /e/OS
69. **Galaxy S9+** -> /e/OS
70. **Galaxy A72** -> /e/OS
71. **Galaxy A52 4G** -> /e/OS
72. **Galaxy A40** -> /e/OS
73. **Galaxy Note 10+** -> /e/OS
74. **Galaxy Tab S6 Lite (Wi-Fi)** -> LineageOS
75. **Galaxy Tab S5e** -> LineageOS

### 4. Xiaomi / Poco / Redmi (Middensegment)
*Focus: Verwijderen van MIUI/HyperOS advertenties en bloatware.*

76. **Poco F4** -> Evolution X
77. **Poco X4 Pro** -> Evolution X
78. **Poco M4 Pro** -> LineageOS
79. **Redmi Note 11** -> Evolution X
80. **Redmi Note 10** -> LineageOS
81. **Xiaomi 12 Pro** -> Evolution X
82. **Xiaomi 11T Pro** -> LineageOS
83. **Xiaomi Mi 10T / Pro** -> Evolution X
84. **Poco X3 NFC** -> LineageOS

### 5. OnePlus (Oudere modellen)
*Focus: Toestellen die sneller zijn dan toen ze uit de doos kwamen.*

85. **OnePlus 9 Pro** -> LineageOS
86. **OnePlus 9** -> LineageOS
87. **OnePlus 8 Pro** -> LineageOS
88. **OnePlus 8** -> LineageOS
89. **OnePlus 7T Pro** -> Evolution X
90. **OnePlus 7 Pro** -> LineageOS
91. **OnePlus 6T** -> LineageOS

### 6. Fairphone & Teracube (Duurzaamheid)
92. **Fairphone 2** -> /e/OS (Nog steeds ondersteund!)
93. **Teracube 2e** -> /e/OS / LineageOS

### 7. Sony & ASUS (Niche & Compact)
94. **Xperia 5 V** -> LineageOS
95. **Xperia 1 IV** -> LineageOS
96. **Xperia 10 IV** -> LineageOS
97. **Zenfone 8** -> LineageOS

### 8. Nothing & Lenovo
98. **Nothing Phone (2a) Plus** -> LineageOS
99. **Lenovo P11 Tablet** -> LineageOS
100. **Lenovo Yoga Tab 11** -> LineageOS

---

## Belangrijke overweging bij de Top 100:
Veel van de toestellen in de 51-100 reeks zijn **refurbished** zeer goedkoop aan te schaffen. Voor een flashing-station is dit de ideale manier om te experimenteren zonder grote financiële risico's. 

**Let op:** Bij tablets (zoals de Samsung Tab en Lenovo) is de ondersteuning voor de stylus of specifieke toetsenbord-covers soms beperkt in Custom ROMs. Controleer de "Known Issues" in de documentatie voordat je begint.

# Officiële Downloadbronnen voor de 5 ROMs

Gebruik deze links om de `.img` of `.zip` bestanden te downloaden naar de bijbehorende `~/android/[vendor]/[rom]/images/` map op je Debian station.

---

### 1. GrapheneOS (Alleen voor Google Pixel)
De meest beveiligde ROM op de markt.
* **Website:** [https://grapheneos.org/releases](https://grapheneos.org/releases)
* **Installatietip:** Gebruik de "Web Installer" in Chromium voor de makkelijkste ervaring.

### 2. LineageOS (De Universele Standaard)
De breedst ondersteunde ROM voor bijna alle fabrikanten.
* **Website:** [https://download.lineageos.org/](https://download.lineageos.org/)
* **Zoekmethode:** Zoek op de codenaam van je toestel (bijv. `curtana` voor de Redmi Note 9S).

### 3. /e/OS (De-Googled & Privacy)
Ideaal voor Samsung, Fairphone en oudere toestellen.
* **Website:** [https://doc.e.foundation/devices](https://doc.e.foundation/devices)
* **Zoekmethode:** Klik op je toestelmodel voor de directe downloadlink en specifieke installatie-instructies.

### 4. CalyxOS (Privacy met Gemak)
Een uitstekend alternatief voor GrapheneOS, ook voor de Fairphone en Motorola.
* **Website:** [https://calyxos.org/install/](https://calyxos.org/install/)
* **Installatietip:** CalyxOS gebruikt vaak een eigen `device-flasher` tool die je in de `/tools` map kunt zetten.

### 5. Evolution X (Pixel Features op andere hardware)
Voor wie alle Google Pixel-functies wil, maar dan op een Xiaomi of OnePlus.
* **Website:** [https://evolution-x.org/download](https://evolution-x.org/download)
* **Zoekmethode:** Selecteer je fabrikant en vervolgens je specifieke modelnaam.

---

## Belangrijke Veiligheidscheck (Checksums)
Bij bijna alle downloads zie je een lange reeks tekens (bijv. SHA-256). Controleer na het downloaden in je Debian terminal of het bestand niet corrupt is:

```bash
cd ~/android/[vendor]/[rom]/images/
sha256sum [bestandsnaam].zip
```

