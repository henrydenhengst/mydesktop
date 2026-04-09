# OPNsense + Freedom Internet Functioneel Ontwerp

## Netwerkoverzicht
```
[Freedom ONT]  
      | (WAN-kabel)  
   [OPNsense igb0 - WAN]  
      |--- VLAN 6 → Internet (PPPoE)  
      |--- VLAN 4 → TV (DHCP + IGMP)  
   [OPNsense igb1 - LAN]  
      | (Trunk)  
  [Managed Switch]  
      |--- VLAN 10 → Management  
      |--- VLAN 20 → Wi-Fi main  
      |--- VLAN 30 → Wi-Fi guest  
      |--- VLAN 40 → IoT  
      |--- VLAN 4  → TV settopboxen
```

## VLAN-indeling

| VLAN | Naam          | Doel                                    |
|------|---------------|----------------------------------------|
| 4    | TV            | IPTV settopboxen (multicast via IGMP)  |
| 6    | Internet      | PPPoE verbinding naar Freedom Internet |
| 10   | Management    | Beheer van switch, firewall, netwerk   |
| 20   | Wi-Fi main    | Bedrijf / thuis netwerk                 |
| 30   | Wi-Fi guest   | Gasten netwerk, geïsoleerd              |
| 40   | IoT           | Internet-of-Things apparaten, gescheiden|

## Logische werking

1. WAN (igb0) ontvangt internet en TV via VLAN 6 en 4.  
2. PPPoE op VLAN 6 activeert internet.  
3. VLAN 4 op WAN → IGMP proxy / multicast naar LAN en switch voor TV.  
4. LAN (igb1) fungeert als trunk naar managed switch.  
   - Alle interne VLANs (10, 20, 30, 40, 4) beschikbaar.  
   - Switchpoorten kunnen per VLAN worden toegewezen:  
     - TV-poorten → VLAN 4  
     - AP main → VLAN 20  
     - AP guest → VLAN 30  
     - IoT-apparaten → VLAN 40  
     - Management-poorten → VLAN 10  

## Netwerkdiensten

- Internet VLAN 6 → DHCP + NAT op LAN VLANs  
- TV VLAN 4 → DHCP + NAT + IGMP proxy voor multicast TV  
- Management VLAN 10 → Beheer van OPNsense + switch  
- Wi-Fi VLANs 20/30 → DHCP voor gebruikers en gasten  
- IoT VLAN 40 → DHCP voor IoT-apparaten, beperkt internet  

## Beveiliging & isolatie

- VLANs zijn gescheiden → geen directe toegang tussen Wi-Fi, gasten en IoT  
- Firewallregels per VLAN bepalen toegang tot internet of andere VLANs  
- Management VLAN apart en beveiligd  
- TV VLAN enkel multicast en internet, gescheiden van rest