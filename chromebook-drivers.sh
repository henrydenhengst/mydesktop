# Alle benodigde packages
sudo apt install -y \
    firmware-sof-signed \
    alsa-ucm-conf \
    firmware-misc-nonfree \
    xserver-xorg-input-synaptics \
    xserver-xorg-input-libinput \
    xserver-xorg-input-evdev \
    acpi acpitool lm-sensors \
    intel-gpu-tools

# Modules laden
sudo modprobe i915
sudo modprobe sof_pci
sudo modprobe snd_soc_skl
sudo modprobe snd_soc_rt5682
sudo modprobe elan_i2c
sudo modprobe atmel_mxt_ts

# Herstart
sudo reboot