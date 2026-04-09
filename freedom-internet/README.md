```
[Freedom ONT]
      |
      | (WAN)
   [OPNsense igb0]
      |--- VLAN 6 → Internet
      |--- VLAN 4 → TV
   [OPNsense igb1]
      |
      | (Trunk)
  [Managed Switch]
      |--- VLAN 10 → Management
      |--- VLAN 20 → Wi-Fi main
      |--- VLAN 30 → Wi-Fi guest
      |--- VLAN 40 → IoT
      |--- VLAN 4  → TV
```
