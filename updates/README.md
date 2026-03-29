# Functionele Beschrijving: Geoptimaliseerd Systeemonderhoud (Vloot-beheer)

Dit Ansible-playbook voert periodiek onderhoud uit op Linux-nodes binnen het cluster. 
Het is specifiek ontworpen voor oudere hardware ("Windows-refurbished") waarbij 
efficiëntie, schijfruimte en hardware-gezondheid prioriteit hebben boven zware 
container-runtimes zoals Flatpak.

## 1. APT Pakketbeheer & Opschoning
* **Dist-Upgrade:** Zorgt dat niet alleen de pakketten, maar ook de afhankelijkheden 
  en kernel-gerelateerde patches worden bijgewerkt naar de nieuwste stabiele versie.
* **Autoremove & Purge:** Verwijdert overbodige pakketten en oude configuratiebestanden 
  die achterblijven na updates, wat cruciaal is voor het schoonhouden van kleine schijven.

## 2. SSD-Levensduur (FSTRIM)
* **Active Trimming:** Voert `fstrim` uit op alle gekoppelde bestandssystemen. 
  Dit is essentieel voor oudere SSD's om schrijfprestaties te behouden en 
  "wear leveling" te optimaliseren, waardoor de schijf langer meegaat.

## 3. Firmware & Microcode Integratie
* **fwupdmgr:** Controleert op BIOS- en firmware-updates voor de specifieke hardware.
* **Initramfs Update:** Genereert het opstartbestand opnieuw om te garanderen dat de 
  laatste CPU-microcode en hardware-drivers (uit de hardware-master) correct 
  worden ingeladen tijdens het booten.

## 4. Schijfruimtebeheer (Kernel Purge)
* **Kernel Management:** Identificeert en verwijdert automatisch alle oude, 
  ongebruikte Linux-kernels. Dit voorkomt dat de `/boot` partitie of de root-partitie 
  volloopt, een veelvoorkomend probleem bij langdurig Debian/Ubuntu gebruik.

## 5. Desktop & Icoon Consistentie
* **Desktop Database:** Ververst de applicatie-index. Dit zorgt ervoor dat nieuwe 
  scripts of handmatige installaties direct zichtbaar zijn in het startmenu en 
  de Nemo-verkenner zonder dat een herstart nodig is.

## 6. Gezondheidscontrole (Telemetry)
* **Real-time Status:** Rapporteert na afloop direct drie kritieke waarden:
    - **Uptime:** Om te controleren of een node onverwacht is herstart.
    - **Disk Usage:** Directe waarschuwing als een node bijna vol zit.
    - **CPU Temperatuur:** Cruciaal voor oude laptops om te monitoren of fans 
      of koelpasta aan vervanging toe zijn (voorkomen van thermische schade).
