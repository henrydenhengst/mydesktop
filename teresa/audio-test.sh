#!/usr/bin/env bash
# =============================================================================
#  audio-test.sh  -  Complete audiotest en automatische reparatie
#                    voor Linux Mint (XFCE)
#
#  Wat doet dit script?
#    1. Controleert systeem, benodigde pakketten en audio-hardware/drivers
#    2. Controleert de geluidsserver (PulseAudio of PipeWire)
#    3. Controleert apparaten, volume, balans, mute en ALSA-mixer
#    4. Test de uitvoer (boxen/koptelefoon): aparte toon links en rechts
#    5. Test de invoer (microfoon) met een opname + analyse
#    6. Probeert problemen automatisch op te lossen
#    7. Schrijft een logbestand en toont een samenvatting
#
#  Gebruik:   bash audio-test.sh [opties]
#    -n, --geen-fix          Alleen testen, niets repareren
#    -y, --niet-interactief  Geen vragen stellen (geen luistertest)
#    -h, --help              Deze hulp
#
#  Start het script als GEWONE gebruiker (niet met sudo). Waar nodig
#  vraagt het script zelf om je wachtwoord (sudo).
# =============================================================================

export LC_ALL=C

INTERACTIVE=true
AUTOFIX=true
ASOUND_CARDS="${ASOUND_CARDS:-/proc/asound/cards}"   # overschrijfbaar voor tests

usage() { sed -n '3,/^# =====/{/^# =====/!p}' "$0" | sed 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    -n|--geen-fix)          AUTOFIX=false ;;
    -y|--niet-interactief)  INTERACTIVE=false ;;
    -h|--help)              usage; exit 0 ;;
    *) echo "Onbekende optie: $arg"; usage; exit 2 ;;
  esac
done
[[ -t 0 ]] || INTERACTIVE=false

if [[ $EUID -eq 0 ]]; then
  echo "Start dit script als gewone gebruiker, niet als root/sudo."
  echo "De geluidsserver draait in jouw gebruikerssessie."
  exit 1
fi

# ----------------------------------------------------------------------------
# Opmaak, logging en hulpfuncties
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; CYN=$'\e[36m'; BLD=$'\e[1m'; RST=$'\e[0m'
else
  RED=""; GRN=""; YEL=""; CYN=""; BLD=""; RST=""
fi

LOG="$HOME/audio-test-$(date +%Y%m%d-%H%M%S).log"
TMPD=$(mktemp -d)
: > "$LOG" || { echo "Kan logbestand niet schrijven: $LOG"; exit 1; }

cleanup() { rm -rf "$TMPD"; }
on_interrupt() { echo; echo "Onderbroken door gebruiker. Logbestand: $LOG"; printf 'Onderbroken door gebruiker\n' >> "$LOG"; exit 130; }
trap cleanup EXIT
trap on_interrupt INT TERM

OKS=(); WARNS=(); FAILS=(); FIXES=()
DEF_SINK=""; DEF_SRC=""
NEED_REBOOT=false
NEED_RELOGIN=false
KLOG=""

SUDO_CMD=(sudo)
$INTERACTIVE || SUDO_CMD=(sudo -n)

strip() { sed -E 's/\x1b\[[0-9;]*m//g'; }
say()   { printf '%s\n' "$*"; printf '%s\n' "$*" | strip >> "$LOG"; }
logonly() { printf '%s\n' "$*" >> "$LOG"; }
hdr()   { say ""; say "${BLD}${CYN}=== $1 ===${RST}"; }
info()  { say "  $*"; }
ok()    { OKS+=("$1");   say "  ${GRN}[OK]${RST}        $1"; }
warn()  { WARNS+=("$1"); say "  ${YEL}[WAARSCHUWING]${RST} $1"; }
bad()   { FAILS+=("$1"); say "  ${RED}[FOUT]${RST}      $1"; }
problem() { say "  ${YEL}[PROBLEEM]${RST}  $1"; }
fixed() { FIXES+=("$1"); say "  ${GRN}[OPGELOST]${RST}  $1"; }

have()    { command -v "$1" >/dev/null 2>&1; }
as_root() { have sudo && "${SUDO_CMD[@]}" "$@"; }

runlog() {  # voer commando uit, zet commando + uitvoer alleen in het log
  logonly ""; logonly "\$ $*"
  "$@" >>"$LOG" 2>&1
}

ask_yn() {  # 0 = ja, 1 = nee, 2 = overgeslagen/niet-interactief
  $INTERACTIVE || return 2
  local a
  read -r -p "$1 [j/n/s=overslaan] " a
  case "${a,,}" in
    j|ja|y|yes) return 0 ;;
    n|nee|no)   return 1 ;;
    *)          return 2 ;;
  esac
}

pkg_installed()      { dpkg -s "$1" >/dev/null 2>&1; }
apt_pkg_available()  { apt-cache show "$1" >/dev/null 2>&1; }

apt_install() {
  $AUTOFIX || return 1
  have sudo || return 1
  info "... installeren: $*"
  local run=("${SUDO_CMD[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@")
  if "${run[@]}" >>"$LOG" 2>&1; then return 0; fi
  "${SUDO_CMD[@]}" apt-get update >>"$LOG" 2>&1
  "${run[@]}" >>"$LOG" 2>&1
}

count_cards() {
  local n=0
  [[ -r $ASOUND_CARDS ]] && n=$(grep -c '^ *[0-9][0-9]* \[' "$ASOUND_CARDS")
  echo "${n:-0}"
}
card_ids() { awk '/^ *[0-9]+ \[/{print $1}' "$ASOUND_CARDS" 2>/dev/null; }

load_kernel_log() {  # eenmalig inlezen; probeert journalctl, dmesg, sudo -n dmesg
  KLOG=$(journalctl -k -b --no-pager 2>/dev/null)
  (( $(wc -l <<<"$KLOG") < 5 )) && KLOG=$(dmesg 2>/dev/null)
  (( $(wc -l <<<"$KLOG") < 5 )) && have sudo && KLOG=$(sudo -n dmesg 2>/dev/null)
  return 0
}

real_sinks()   { pactl list short sinks   2>/dev/null | awk '{print $2}' | grep -v '^auto_null$'; }
real_sources() { pactl list short sources 2>/dev/null | awk '{print $2}' | grep -v '\.monitor$'; }

# Alle kanaalpercentages (bijv. "64" "64"), een per regel.
sink_vols() { pactl get-sink-volume "$1"   2>/dev/null | grep -o '[0-9]*%' | tr -d '%'; }
src_vols()  { pactl get-source-volume "$1" 2>/dev/null | grep -o '[0-9]*%' | tr -d '%'; }
sink_vol()  { sink_vols "$1" | sort -n | tail -n1; }
src_vol()   { src_vols  "$1" | sort -n | tail -n1; }

# Geven "yes", "no" of "unknown" terug (string, niet exitcode).
sink_mute_state() {
  local out
  out=$(pactl get-sink-mute "$1" 2>/dev/null) || { echo unknown; return; }
  [[ -z $out ]] && { echo unknown; return; }
  if grep -qi 'yes' <<<"$out"; then echo yes; else echo no; fi
}
src_mute_state() {
  local out
  out=$(pactl get-source-mute "$1" 2>/dev/null) || { echo unknown; return; }
  [[ -z $out ]] && { echo unknown; return; }
  if grep -qi 'yes' <<<"$out"; then echo yes; else echo no; fi
}

server_alive() { pactl info >/dev/null 2>&1; }

restart_server() {
  info "... geluidsserver herstarten"
  local name use_pw=false
  name=$(pactl info 2>/dev/null | sed -n 's/^Server Name: //p')
  if grep -qi pipewire <<<"$name"; then
    use_pw=true
  elif [[ -z $name ]] && pkg_installed pipewire-pulse; then
    use_pw=true
  fi
  if $use_pw && systemctl --user cat pipewire-pulse.service >/dev/null 2>&1; then
    systemctl --user restart pipewire pipewire-pulse wireplumber >>"$LOG" 2>&1
  elif have pulseaudio; then
    pulseaudio --kill >>"$LOG" 2>&1; sleep 1
    pulseaudio --start >>"$LOG" 2>&1
  fi
  sleep 3
  server_alive
}

fix_card_profiles() {  # zet kaarten met profiel 'off' op een bruikbaar profiel
                      # retourneert 0 als er iets is gewijzigd, 1 als niets
  local card active prof did_change=1
  while IFS= read -r card; do
    [[ -z $card ]] && continue
    active=$(pactl list cards 2>/dev/null | awk -v c="$card" '/^Card #/{f=0} index($0,"Name: " c){f=1} f && /Active Profile:/{print $3; exit}')
    if [[ $active == off || -z $active ]]; then
      prof=$(pactl list cards 2>/dev/null | awk -v c="$card" '/^Card #/{f=0} index($0,"Name: " c){f=1} f && /^\t\t[a-z]/ && /sinks: [1-9]/ && !/available: no/ {sub(/^\t\t/,""); sub(/: .*/,""); print; exit}')
      if [[ -n $prof ]] && pactl set-card-profile "$card" "$prof" >>"$LOG" 2>&1; then
        info "Kaartprofiel van $card gezet op: $prof"
        did_change=0
      fi
    fi
  done < <(pactl list short cards 2>/dev/null | awk '{print $2}')
  return $did_change
}

# ----------------------------------------------------------------------------
# 1. Systeem
# ----------------------------------------------------------------------------
section_system() {
  hdr "1. Systeem"
  local pretty
  pretty=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-onbekend}")
  info "Datum        : $(date '+%F %T')"
  info "Computer     : $(hostname)"
  info "Distributie  : $pretty"
  info "Kernel       : $(uname -r)"
  info "Desktop      : ${XDG_CURRENT_DESKTOP:-onbekend}"
  info "Gebruiker    : ${USER:-$(id -un)}"
  info "Opties       : autofix=$AUTOFIX interactief=$INTERACTIVE"
  if [[ -z ${XDG_RUNTIME_DIR:-} ]]; then
    warn "XDG_RUNTIME_DIR is niet gezet; start dit script in een gewone desktopsessie (geen su/ssh)."
  fi
  if $AUTOFIX; then
    if ! have sudo; then
      warn "sudo ontbreekt: herstel dat root-rechten nodig heeft (pakketten, kernelmodules) wordt overgeslagen."
    elif ! $INTERACTIVE && ! sudo -n true 2>/dev/null; then
      warn "Niet-interactief zonder wachtwoordloze sudo: herstel dat root-rechten nodig heeft wordt overgeslagen."
    fi
  fi
}

# ----------------------------------------------------------------------------
# 2. Benodigde pakketten
# ----------------------------------------------------------------------------
section_packages() {
  hdr "2. Benodigde programma's"
  declare -A NEED=(
    [aplay]=alsa-utils [arecord]=alsa-utils [amixer]=alsa-utils
    [speaker-test]=alsa-utils [alsactl]=alsa-utils
    [pactl]=pulseaudio-utils [paplay]=pulseaudio-utils [parecord]=pulseaudio-utils
    [lspci]=pciutils [lsusb]=usbutils [python3]=python3
  )
  local cmd pkgs=() missing_cmds=() p seen=" "
  for cmd in "${!NEED[@]}"; do
    if ! have "$cmd"; then
      missing_cmds+=("$cmd")
      p="${NEED[$cmd]}"
      [[ $seen == *" $p "* ]] || { pkgs+=("$p"); seen+="$p "; }
    fi
  done

  if ((${#missing_cmds[@]} == 0)); then
    ok "Alle benodigde programma's zijn aanwezig"
    return
  fi

  problem "Ontbrekend: ${missing_cmds[*]} (pakketten: ${pkgs[*]})"
  if ! $AUTOFIX; then
    bad "Ontbrekende pakketten niet geinstalleerd (autofix uitgeschakeld): ${pkgs[*]}"
    return
  fi
  if apt_install "${pkgs[@]}"; then
    local still=()
    for cmd in "${missing_cmds[@]}"; do have "$cmd" || still+=("$cmd"); done
    if ((${#still[@]} == 0)); then
      fixed "Ontbrekende pakketten geinstalleerd: ${pkgs[*]}"
    else
      bad "Nog steeds ontbrekend na installatie: ${still[*]}"
    fi
  else
    bad "Ontbrekende pakketten niet geinstalleerd: ${pkgs[*]} (installeer handmatig: sudo apt install ${pkgs[*]})"
  fi
}

# ----------------------------------------------------------------------------
# 3. Hardware en drivers
# ----------------------------------------------------------------------------
section_hardware() {
  hdr "3. Audio-hardware en drivers"
  load_kernel_log

  # PCI audio-apparaten en hun kerneldriver
  local pci_found=false dev drv
  local NODRV=()
  if have lspci; then
    while IFS='|' read -r dev drv; do
      [[ -z $dev ]] && continue
      pci_found=true
      if [[ -n $drv ]]; then
        ok "PCI-audio: ${dev#* } -> driver: $drv"
      else
        NODRV+=("${dev#* }")
      fi
    done < <(lspci -nnk 2>/dev/null | awk '
      /^[0-9a-f][0-9a-f]*:[0-9a-f]/ { if (a) print dev "|" drv; a = ($0 ~ /[Aa]udio device|Multimedia audio controller/); dev=$0; drv=""; next }
      /Kernel driver in use:/ { sub(/.*: /,""); drv=$0 }
      END { if (a) print dev "|" drv }')
    runlog lspci -nnk
  fi
  $pci_found || info "Geen PCI-audio-apparaat gevonden (kan USB-only, Bluetooth of virtuele machine zijn)."

  # USB audio
  if have lsusb; then
    local usb l
    usb=$(lsusb 2>/dev/null | grep -Ei 'audio|headset|headphone|microphone|speaker|webcam|camera')
    if [[ -n $usb ]]; then
      info "USB-apparaten met mogelijk audio:"
      while IFS= read -r l; do info "  $l"; done <<<"$usb"
    fi
  fi

  # Kernelmodules
  local mods
  mods=$(lsmod | awk '/^snd/{print $1}' | tr '\n' ' ')
  if [[ -z $mods ]]; then
    problem "Geen snd-kernelmodules geladen"
    if ! $AUTOFIX; then
      warn "Geen snd-kernelmodules geladen (autofix uitgeschakeld)"
    elif as_root modprobe snd_hda_intel >>"$LOG" 2>&1; then
      sleep 1
      fixed "snd_hda_intel geladen"
    else
      bad "Kon snd_hda_intel niet laden"
    fi
  else
    ok "Geluidsmodules geladen ($(wc -w <<<"$mods") stuks)"
    logonly "Modules: $mods"
  fi

  # Geluidskaarten in de kernel
  local n; n=$(count_cards)
  if ((n == 0)); then
    problem "Kernel ziet geen geluidskaart ($ASOUND_CARDS leeg)"
    local klog; klog=$(grep -Ei 'sof[-_]|snd|hda|alsa|audio' <<<"$KLOG" | tail -n 40)
    logonly "--- Relevante kernelmeldingen ---"; logonly "$klog"
    if ! $AUTOFIX; then
      warn "Geen geluidskaart gedetecteerd (autofix uitgeschakeld)"
    else
      as_root modprobe snd_hda_intel >>"$LOG" 2>&1
      sleep 1
      if grep -Eqi 'sof[-_a-z]*.*(firmware|failed|error)' <<<"$klog"; then
        info "Intel SOF-firmware lijkt nodig; controleren/installeren..."
        local fw=() p
        for p in firmware-sof-signed alsa-ucm-conf; do
          if apt_pkg_available "$p" && ! pkg_installed "$p"; then fw+=("$p"); fi
        done
        if ((${#fw[@]})); then
          apt_install "${fw[@]}" && NEED_REBOOT=true
        else
          info "SOF-pakketten zijn al aanwezig of niet beschikbaar in je pakketbronnen."
        fi
      fi
      as_root alsa force-reload >>"$LOG" 2>&1
      sleep 2
      n=$(count_cards)
      if ((n > 0)); then
        fixed "Geluidskaart verscheen na herstelpoging ($n kaart(en))"
      elif $NEED_REBOOT; then
        warn "Geluidskaart verschijnt mogelijk na een herstart (firmware zojuist geinstalleerd)"
      else
        bad "Geen geluidskaart gedetecteerd. Controleer BIOS/UEFI (audio aan?), kabels, of probeer een nieuwere kernel."
      fi
    fi
  else
    ok "Kernel ziet $n geluidskaart(en)"
    local l
    while IFS= read -r l; do logonly "  $l"; done < "$ASOUND_CARDS"
  fi

  # PCI-apparaten zonder driver: pas nu beoordelen, want nu weten we of er kaarten zijn
  for dev in "${NODRV[@]}"; do
    if ((n > 0)); then
      warn "PCI-audio zonder geladen driver (mogelijk ongebruikt, bijv. HDMI): $dev"
    else
      bad "PCI-audio zonder geladen driver: $dev"
    fi
  done

  # Afspeel- en opname-apparaten volgens ALSA
  if have aplay; then
    runlog aplay -l
    local pl; pl=$(aplay -l 2>/dev/null | grep -c '^card')
    if ((pl > 0)); then ok "ALSA: $pl afspeelapparaat/apparaten"; else bad "ALSA: geen afspeelapparaten (aplay -l)"; fi
  fi
  if have arecord; then
    runlog arecord -l
    local rc; rc=$(arecord -l 2>/dev/null | grep -c '^card')
    if ((rc > 0)); then ok "ALSA: $rc opname-apparaat/apparaten"; else warn "ALSA: geen opname-apparaten (geen microfoon gevonden)"; fi
  fi

  # Fouten in de kernellog
  local errs
  errs=$(grep -Ei 'snd|hda|sof[-_]|alsa|audio' <<<"$KLOG" | grep -Ei 'error|fail|timeout|unable|no codec|probe.*(fail|error)' | tail -n 10)
  if [[ -n $errs ]]; then
    warn "Audio-gerelateerde foutmeldingen in de kernellog (zie logbestand)"
    logonly "--- Kernel-fouten ---"; logonly "$errs"
  elif (( $(wc -l <<<"$KLOG") < 5 )); then
    info "Kernellog niet leesbaar zonder extra rechten; controle op kernelfouten overgeslagen."
  else
    ok "Geen audio-fouten in de kernellog"
  fi

  # Eigen ALSA-configuratie die problemen kan geven
  local f
  for f in "$HOME/.asoundrc" /etc/asound.conf; do
    [[ -s $f ]] && warn "Eigen ALSA-configuratie aanwezig: $f (kan standaardapparaat overschrijven)"
  done

  # Groepslidmaatschap
  if id -nG | tr ' ' '\n' | grep -qx audio; then
    ok "Gebruiker zit in de groep 'audio'"
  else
    problem "Gebruiker zit niet in de groep 'audio'"
    if ! $AUTOFIX; then
      warn "Gebruiker zit niet in groep 'audio' (autofix uitgeschakeld; voeg toe met: sudo usermod -aG audio ${USER:-$(id -un)})"
    elif as_root usermod -aG audio "${USER:-$(id -un)}" >>"$LOG" 2>&1; then
      fixed "Gebruiker toegevoegd aan groep 'audio' (opnieuw inloggen nodig)"
      NEED_RELOGIN=true
    else
      warn "Voeg jezelf toe met: sudo usermod -aG audio ${USER:-$(id -un)}"
    fi
  fi
}

# ----------------------------------------------------------------------------
# 4. Geluidsserver
# ----------------------------------------------------------------------------
section_server() {
  hdr "4. Geluidsserver (PulseAudio / PipeWire)"
  if ! server_alive; then
    problem "Geluidsserver reageert niet (pactl info mislukt)"
    if ! $AUTOFIX; then
      bad "Geluidsserver reageert niet (herstel uitgeschakeld)"
      return
    fi
    if ! pkg_installed pulseaudio && ! pkg_installed pipewire-pulse; then
      info "Geen geluidsserver geinstalleerd; PulseAudio installeren..."
      apt_install pulseaudio pulseaudio-utils
    fi
    if restart_server; then
      fixed "Geluidsserver reageerde niet -> herstart, nu actief"
    else
      bad "Geluidsserver blijft onbereikbaar. Probeer: systemctl --user status pipewire pulseaudio"
      return
    fi
  fi

  local sname; sname=$(pactl info 2>/dev/null | sed -n 's/^Server Name: //p')
  local sver;  sver=$(pactl info 2>/dev/null | sed -n 's/^Server Version: //p')
  ok "Geluidsserver actief: ${sname:-onbekend} ${sver}"
  runlog pactl info

  if grep -qi pipewire <<<"$sname"; then
    pgrep -x wireplumber >/dev/null || warn "WirePlumber (sessiemanager van PipeWire) draait niet"
  fi
  if pgrep -x pulseaudio >/dev/null && pgrep -x pipewire-pulse >/dev/null; then
    warn "PulseAudio en PipeWire-pulse draaien tegelijk (conflict mogelijk)"
  fi
}

# ----------------------------------------------------------------------------
# 5. Apparaten (uitvoer/invoer) en standaardkeuze
# ----------------------------------------------------------------------------
section_devices() {
  hdr "5. Audio-apparaten in de geluidsserver"
  server_alive || { bad "Overgeslagen: geen geluidsserver"; return; }

  local n; n=$(real_sinks | wc -l)
  if ((n == 0)); then
    problem "Geen echt uitvoerapparaat (alleen 'Dummy Output' of niets)"
    if ! $AUTOFIX; then
      bad "Geen uitvoerapparaat (autofix uitgeschakeld)"
    else
      fix_card_profiles
      as_root alsactl init >>"$LOG" 2>&1
      restart_server
      fix_card_profiles
      sleep 1
      n=$(real_sinks | wc -l)
      if ((n > 0)); then
        fixed "Uitvoerapparaat ontbrak -> kaartprofiel/geluidsserver hersteld"
      else
        bad "Nog steeds geen uitvoerapparaat. Controleer of de kaart in 'pactl list cards' een profiel heeft en of firmware ontbreekt."
      fi
    fi
  else
    ok "$n uitvoerapparaat/apparaten gevonden"
  fi

  local s
  while IFS= read -r s; do [[ -n $s ]] && info "  uitvoer: $s"; done < <(real_sinks)

  local m; m=$(real_sources | wc -l)
  if ((m == 0)); then
    warn "Geen invoerapparaat (microfoon) gevonden in de geluidsserver"
  else
    ok "$m invoerapparaat/apparaten gevonden"
    while IFS= read -r s; do [[ -n $s ]] && info "  invoer : $s"; done < <(real_sources)
  fi

  runlog pactl list short sinks
  runlog pactl list short sources
  runlog pactl list short cards

  # Standaard uitvoer
  DEF_SINK=$(pactl info 2>/dev/null | sed -n 's/^Default Sink: //p')
  if [[ -z $DEF_SINK || $DEF_SINK == auto_null ]] || ! real_sinks | grep -qx "$DEF_SINK"; then
    local first; first=$(real_sinks | head -n1)
    if [[ -n $first ]]; then
      problem "Standaard uitvoer ongeldig ('${DEF_SINK:-leeg}')"
      if ! $AUTOFIX; then
        bad "Standaard uitvoer ongeldig (autofix uitgeschakeld)"
      elif pactl set-default-sink "$first" >>"$LOG" 2>&1; then
        DEF_SINK="$first"
        fixed "Standaard uitvoer gezet op: $first"
      else
        bad "Standaard uitvoer ongeldig en niet te herstellen"
      fi
    else
      DEF_SINK=""   # alleen dummy: niets om te testen
    fi
  else
    ok "Standaard uitvoer: $DEF_SINK"
  fi

  # Actieve poort beschikbaar? (bijv. koptelefoon niet aangesloten)
  if [[ -n $DEF_SINK ]]; then
    local ap
    ap=$(pactl list sinks 2>/dev/null | awk -v s="$DEF_SINK" '/^Sink #/{f=0} index($0,"Name: " s){f=1} f && /Active Port:/{print $3; exit}')
    if [[ -n $ap ]]; then
      if pactl list sinks 2>/dev/null | awk -v s="$DEF_SINK" -v p="$ap" '/^Sink #/{f=0} index($0,"Name: " s){f=1} f && index($0,p ": ") && /not available/{found=1} END{exit !found}'; then
        warn "Actieve uitvoerpoort '$ap' meldt 'niet beschikbaar' (kabel/koptelefoon niet aangesloten?)"
      else
        ok "Actieve uitvoerpoort: $ap"
      fi
    fi
  fi

  # Standaard invoer
  DEF_SRC=$(pactl info 2>/dev/null | sed -n 's/^Default Source: //p')
  if [[ -z $DEF_SRC || $DEF_SRC == *.monitor ]]; then
    local fsrc; fsrc=$(real_sources | head -n1)
    if [[ -n $fsrc ]]; then
      problem "Standaard invoer is leeg of een 'monitor' (geen echte microfoon): '${DEF_SRC:-leeg}'"
      if ! $AUTOFIX; then
        bad "Standaard invoer wijst naar een monitor (autofix uitgeschakeld)"
      elif pactl set-default-source "$fsrc" >>"$LOG" 2>&1; then
        DEF_SRC="$fsrc"
        fixed "Standaard invoer gezet op: $fsrc"
      else
        bad "Standaard invoer wijst naar een monitor en kon niet worden gecorrigeerd"
      fi
    fi
  elif [[ -n $DEF_SRC ]]; then
    ok "Standaard invoer: $DEF_SRC"
  fi
}

# ----------------------------------------------------------------------------
# 6. Volume, balans en mute (geluidsserver + ALSA-mixer)
# ----------------------------------------------------------------------------
# Let op: alleen UITVOER-regelaars worden op playback aangepast en alleen
# OPNAME-regelaars op capture. De playback-schakelaar van 'Mic' of 'Line' blijft
# met opzet met rust: aanzetten geeft meekoppeling (echo/gefluit) uit de boxen.
alsa_mixer_fix() {
  # $1 = "quiet" om rapportage te onderdrukken (bijv. bij tweede aanroep)
  local quiet=false
  [[ ${1:-} == quiet ]] && quiet=true

  have amixer || return

  local card name out
  local issues=() fixes=()
  local play_ctrls=(Master Speaker Headphone PCM Front)
  local cap_ctrls=(Capture Mic "Internal Mic" "Front Mic" "Rear Mic" Line)

  for card in $(card_ids); do
    for name in "${play_ctrls[@]}"; do
      out=$(amixer -c "$card" sget "$name" 2>/dev/null) || continue
      if grep -Eq 'Playback.*\[off\]' <<<"$out"; then
        issues+=("kaart$card/$name (gedempt)")
        if $AUTOFIX && amixer -c "$card" -q sset "$name" unmute 2>>"$LOG"; then
          fixes+=("kaart$card/$name(unmute)")
        fi
      fi
      if grep -Eq 'Playback [0-9-]+ \[0%\]' <<<"$out"; then
        issues+=("kaart$card/$name (0%)")
        if $AUTOFIX && amixer -c "$card" -q sset "$name" playback 70% 2>>"$LOG"; then
          fixes+=("kaart$card/$name(70%)")
        fi
      fi
    done
    for name in "${cap_ctrls[@]}"; do
      out=$(amixer -c "$card" sget "$name" 2>/dev/null) || continue
      if grep -Eq 'Capture.*\[off\]' <<<"$out"; then
        issues+=("kaart$card/$name (opname uit)")
        if $AUTOFIX && amixer -c "$card" -q sset "$name" cap 2>>"$LOG"; then
          fixes+=("kaart$card/$name(opname aan)")
        fi
      fi
      if grep -Eq 'Capture [0-9-]+ \[0%\]' <<<"$out"; then
        issues+=("kaart$card/$name (opname 0%)")
        if $AUTOFIX && amixer -c "$card" -q sset "$name" capture 70% 2>>"$LOG"; then
          fixes+=("kaart$card/$name(opname 70%)")
        fi
      fi
    done
  done

  $quiet && return

  if (( ${#fixes[@]} )); then
    fixed "ALSA-mixer aangepast: ${fixes[*]}"
  elif (( ${#issues[@]} )); then
    if $AUTOFIX; then
      bad "ALSA-mixer: problemen konden niet worden opgelost: ${issues[*]}"
    else
      warn "ALSA-mixer: problemen gevonden (autofix uitgeschakeld): ${issues[*]}"
    fi
  else
    ok "ALSA-mixer: geen gedempte of op 0% staande regelaars gevonden"
  fi
}

section_volume() {
  hdr "6. Volume, balans en mute"
  server_alive || { bad "Overgeslagen: geen geluidsserver"; return; }

  if [[ -n $DEF_SINK ]]; then
    case $(sink_mute_state "$DEF_SINK") in
      unknown)
        warn "Kon mute-status van uitvoer niet uitlezen"
        ;;
      yes)
        problem "Uitvoer staat op MUTE"
        if ! $AUTOFIX; then
          warn "Uitvoer staat op mute (autofix uitgeschakeld)"
        elif pactl set-sink-mute "$DEF_SINK" 0 >>"$LOG" 2>&1 \
             && [[ $(sink_mute_state "$DEF_SINK") == no ]]; then
          fixed "Uitvoer-mute opgeheven"
        else
          bad "Uitvoer staat op mute en kon niet worden opgeheven"
        fi
        ;;
      no)
        ok "Uitvoer is niet gedempt"
        ;;
    esac

    local -a vols=()
    local v=0 vmin=999 x
    mapfile -t vols < <(sink_vols "$DEF_SINK")
    for x in "${vols[@]}"; do
      ((x > v)) && v=$x
      ((x < vmin)) && vmin=$x
    done

    if ((${#vols[@]} == 0)); then
      warn "Kon uitvoervolume niet uitlezen"
    else
      # Balans: links en rechts moeten (vrijwel) gelijk zijn
      if ((${#vols[@]} >= 2 && v - vmin > 3)); then
        problem "Volume links/rechts verschilt (${vmin}% tot ${v}%): een box lijkt zachter"
        if ! $AUTOFIX; then
          warn "Balans links/rechts verschilt (${vmin}% - ${v}%, autofix uitgeschakeld)"
        elif pactl set-sink-volume "$DEF_SINK" "${v}%" >>"$LOG" 2>&1; then
          fixed "Links/rechts-balans gelijkgetrokken op ${v}%"
          vmin=$v
        else
          warn "Balans links/rechts verschilt (${vmin}% - ${v}%)"
        fi
      fi

      if ((v < 20)); then
        problem "Uitvoervolume is erg laag ($v%)"
        if ! $AUTOFIX; then
          warn "Uitvoervolume laag ($v%, autofix uitgeschakeld)"
        elif pactl set-sink-volume "$DEF_SINK" 60% >>"$LOG" 2>&1; then
          fixed "Uitvoervolume van $v% naar 60% gezet"
        else
          warn "Uitvoervolume laag ($v%)"
        fi
      elif ((v > 100)); then
        warn "Uitvoervolume boven 100% ($v%): kan vervorming geven"
      else
        ok "Uitvoervolume: $v%"
      fi
    fi
  else
    warn "Geen standaard uitvoer; volumecontrole overgeslagen"
  fi

  alsa_mixer_fix
}

# ----------------------------------------------------------------------------
# 7. Test uitvoer (boxen / koptelefoon)
# ----------------------------------------------------------------------------
gen_tones() {  # stereo testtonen: links alleen links, rechts alleen rechts
  python3 - "$TMPD" <<'PY'
import sys, wave, math, struct
d = sys.argv[1]; rate = 48000; dur = 1.5
for name, (fl, fr) in {"left": (440, 0), "right": (0, 660)}.items():
    w = wave.open(f"{d}/{name}.wav", "wb")
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
    frames = bytearray()
    total = int(rate * dur)
    for i in range(total):
        env = min(1.0, i / 2400.0, (total - i) / 2400.0)
        l = int(12000 * env * math.sin(2 * math.pi * fl * i / rate)) if fl else 0
        r = int(12000 * env * math.sin(2 * math.pi * fr * i / rate)) if fr else 0
        frames += struct.pack("<hh", l, r)
    w.writeframes(bytes(frames)); w.close()
PY
}

prep_tones() {
  TONE_L=""; TONE_R=""
  if have python3 && gen_tones 2>>"$LOG" && [[ -s $TMPD/left.wav && -s $TMPD/right.wav ]]; then
    TONE_L="$TMPD/left.wav"; TONE_R="$TMPD/right.wav"
  fi
  ALSA_L=/usr/share/sounds/alsa/Front_Left.wav
  ALSA_R=/usr/share/sounds/alsa/Front_Right.wav
}

# $1 = sinknaam (leeg = standaard); return 0 = geen fout.
# Volgorde: eigen stereotonen -> ALSA-stemmen (mono, dus met kanaalkaart naar
# een kant gestuurd) -> speaker-test.
play_sink() {
  local sink="$1" dev=() rc=0
  [[ -n $sink ]] && dev=(--device="$sink")
  if have paplay && [[ -n $TONE_L && -n $TONE_R ]]; then
    info "  >> Links (lage toon)..."
    timeout 15 paplay "${dev[@]}" "$TONE_L" >>"$LOG" 2>&1 || rc=1
    info "  >> Rechts (hoge toon)..."
    timeout 15 paplay "${dev[@]}" "$TONE_R" >>"$LOG" 2>&1 || rc=1
  elif have paplay && [[ -f $ALSA_L && -f $ALSA_R ]]; then
    info "  >> Links (stem)..."
    timeout 15 paplay "${dev[@]}" --channel-map=front-left "$ALSA_L" >>"$LOG" 2>&1 || rc=1
    info "  >> Rechts (stem)..."
    timeout 15 paplay "${dev[@]}" --channel-map=front-right "$ALSA_R" >>"$LOG" 2>&1 || rc=1
  elif have speaker-test; then
    info "  >> speaker-test (links, rechts)..."
    if ! timeout 30 speaker-test -D pulse -t wav -c 2 -l 1 >>"$LOG" 2>&1; then
      info "  (terugval op ALSA 'default')"
      timeout 30 speaker-test -D default -t wav -c 2 -l 1 >>"$LOG" 2>&1 || rc=1
    fi
  else
    return 1
  fi
  return $rc
}

speaker_tips() {
  info "Mogelijke oorzaken en tips:"
  info "  - Staan de boxen aan, is de kabel aangesloten (groene jack = uitgang)?"
  info "  - Koptelefoon aangesloten? Probeer deze eruit te halen of juist erin te doen."
  info "  - Controleer fysiek volume/knop op de boxen."
  info "  - Hoorde je maar een kant? Controleer balans en kabel; pavucontrol -> Uitvoerapparaten."
  info "  - Kies het juiste apparaat in: pavucontrol -> tabblad Configuratie / Uitvoerapparaten."
  info "  - Bij HDMI/DisplayPort: kies de HDMI-uitvoer als je geluid via de monitor wilt."
}

section_speakers() {
  hdr "7. Test uitvoer (boxen / koptelefoon)"
  server_alive || { bad "Overgeslagen: geen geluidsserver"; return; }
  if [[ -z $DEF_SINK ]]; then bad "Geen uitvoerapparaat om te testen"; return; fi

  prep_tones
  info "Standaard uitvoer: $DEF_SINK"
  info "Je hoort straks eerst een geluid links, daarna rechts."
  $INTERACTIVE && { read -r -p "  Zet je boxen aan en druk op Enter om te starten... " _; }

  local tech=0
  play_sink "$DEF_SINK" || tech=1
  if ((tech)); then
    problem "Afspelen via '$DEF_SINK' gaf een foutmelding"
    if $AUTOFIX && restart_server; then
      play_sink "$DEF_SINK" && { tech=0; fixed "Afspelen werkt weer na herstarten van de geluidsserver"; }
    fi
  fi

  ask_yn "  Hoorde je beide geluiden, eerst links en daarna rechts?"; local ans=$?
  case $ans in
    0)
      if ((tech == 0)); then
        ok "Uitvoer-test geslaagd: links en rechts gehoord via $DEF_SINK"
      else
        warn "Je hoorde geluid, maar afspelen meldde fouten (zie log)"
      fi
      return
      ;;
    2)
      if ((tech == 0)); then
        warn "Uitvoer: afspelen verliep zonder fouten (niet auditief bevestigd; -y of 's' gekozen)"
      else
        bad "Uitvoer: afspelen mislukt via $DEF_SINK"
      fi
      return
      ;;
  esac

  # Antwoord was 'nee': probeer andere uitvoerapparaten
  problem "Geen (volledig) geluid gehoord via $DEF_SINK"
  local s sv found=false
  while IFS= read -r s; do
    [[ -z $s || $s == "$DEF_SINK" ]] && continue
    info "Proberen met ander uitvoerapparaat: $s"
    pactl set-sink-mute "$s" 0 >>"$LOG" 2>&1
    sv=$(sink_vol "$s")
    if [[ -n $sv ]] && ((sv < 20)); then pactl set-sink-volume "$s" 60% >>"$LOG" 2>&1; fi
    play_sink "$s"
    if ask_yn "  Hoorde je het nu (links en rechts)?"; then
      if ! $AUTOFIX; then
        warn "Werkend apparaat is $s (autofix uitgeschakeld; kies dit handmatig als standaard)"
      elif pactl set-default-sink "$s" >>"$LOG" 2>&1; then
        DEF_SINK="$s"
        fixed "Standaard uitvoer gewijzigd naar het werkende apparaat: $s"
      else
        warn "Werkend apparaat is $s (kies dit handmatig als standaard)"
      fi
      found=true; break
    fi
  done < <(real_sinks)

  if ! $found; then
    bad "Geen hoorbaar geluid via enig uitvoerapparaat"
    speaker_tips
  fi
}

# ----------------------------------------------------------------------------
# 8. Test invoer (microfoon)
# ----------------------------------------------------------------------------
mic_record() {  # $1 bron, $2 seconden, $3 bestand
  local src="$1" secs="$2" f="$3"
  rm -f "$f"
  if have parecord; then
    # SIGINT zorgt dat parecord het WAV-bestand netjes afsluit; -k 3 forceert alsnog.
    timeout -s INT -k 3 "$secs" parecord --device="$src" --format=s16le --channels=1 --rate=48000 --file-format=wav "$f" >>"$LOG" 2>&1
  elif have arecord; then
    arecord -q -D default -f S16_LE -r 48000 -c 1 -d "$secs" "$f" >>"$LOG" 2>&1
  else
    return 1
  fi
  [[ -s $f ]]
}

analyze_wav() {
  python3 - "$1" <<'PY'
import sys, wave, array, math

def load(path):
    try:
        w = wave.open(path, 'rb')
        ch, sw = w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
        w.close()
        if sw == 2 and raw:
            return ch, raw
    except Exception:
        pass
    try:                       # afgebroken opname: header niet bijgewerkt
        data = open(path, 'rb').read()
    except Exception:
        return 1, b""
    return 1, data[44:]

ch, raw = load(sys.argv[1])
a = array.array('h')
a.frombytes(raw[:len(raw) // 2 * 2])
if sys.byteorder == 'big':
    a.byteswap()
if not a:
    print("ERR leeg"); sys.exit(0)
peak = max(max(a), -min(a))
rms = math.sqrt(sum(x * x for x in a) / len(a))
db = 20 * math.log10(rms / 32768.0) if rms > 0 else -999.0
print("OK %.2f %.1f %d" % (peak / 32768.0 * 100.0, db, len(a) // max(ch, 1)))
PY
}

mic_once() {  # $1 bron -> zet MIC_PEAK, MIC_DB, MIC_STATE (ok|silent|low|clip|err)
  local src="$1" f="$TMPD/mic.wav" secs=5
  MIC_PEAK=0; MIC_DB=-999; MIC_STATE=err
  if $INTERACTIVE; then
    info "Spreek na de aftelling 5 seconden, bijvoorbeeld: 'Test, een, twee, drie'."
    local i
    for i in 3 2 1; do printf '\r  Opname start over %s... ' "$i"; sleep 1; done
    printf '\r  >> OPNEMEN: spreek nu!           \n'
  else
    info "Opnemen (3 seconden omgevingsgeluid, niet-interactief)..."
    secs=3
  fi
  mic_record "$src" "$secs" "$f" || { MIC_STATE=err; return 1; }
  local res; res=$(analyze_wav "$f")
  logonly "Analyse ($src): $res"
  if [[ $res != OK* ]]; then MIC_STATE=err; return 1; fi
  read -r _ MIC_PEAK MIC_DB _ <<<"$res"
  if   awk "BEGIN{exit !($MIC_PEAK < 0.05)}"; then MIC_STATE=silent
  elif awk "BEGIN{exit !($MIC_PEAK >= 99)}";  then MIC_STATE=clip
  elif $INTERACTIVE && awk "BEGIN{exit !($MIC_PEAK < 3)}"; then MIC_STATE=low
  else MIC_STATE=ok; fi
  return 0
}

mic_unmute_boost() {  # $1 bron -> 0 = er is iets gewijzigd, 1 = niets
  local src="$1" changed=0 v
  if [[ $(src_mute_state "$src") == yes ]]; then
    pactl set-source-mute "$src" 0 >>"$LOG" 2>&1 && changed=1
  fi
  v=$(src_vol "$src")
  if [[ -n $v ]] && ((v < 60)); then
    pactl set-source-volume "$src" 80% >>"$LOG" 2>&1 && changed=1
  fi
  return $((1 - changed))
}

section_mic() {
  hdr "8. Test invoer (microfoon)"
  server_alive || { bad "Overgeslagen: geen geluidsserver"; return; }

  local sources; sources=$(real_sources)
  if [[ -z $sources ]]; then
    bad "Geen microfoon gevonden. Controleer: roze jack/headset-aansluiting, USB-microfoon, BIOS, kabel."
    info "Tip: bij een headset met 1 jack (4-polig) kan 'pavucontrol -> Configuratie' een 'Headset'-profiel bieden."
    return
  fi

  local src="$DEF_SRC"
  if [[ -z $src || $src == *.monitor ]] || ! grep -qx "$src" <<<"$sources"; then
    src=$(head -n1 <<<"$sources")
  fi
  info "Geteste microfoon: $src"
  $INTERACTIVE || info "Niet-interactief: alleen omgevingsgeluid wordt gemeten, geen spraak."

  # Mute en volume corrigeren vooraf
  case $(src_mute_state "$src") in
    unknown) warn "Kon mute-status van microfoon niet uitlezen" ;;
    yes)
      problem "Microfoon staat op MUTE"
      if ! $AUTOFIX; then
        warn "Microfoon staat op mute (autofix uitgeschakeld)"
      elif pactl set-source-mute "$src" 0 >>"$LOG" 2>&1 \
           && [[ $(src_mute_state "$src") == no ]]; then
        fixed "Microfoon-mute opgeheven"
      else
        bad "Microfoon staat op mute en kon niet worden opgeheven"
      fi
      ;;
    no) ok "Microfoon is niet gedempt" ;;
  esac

  local v; v=$(src_vol "$src")
  if [[ -z $v ]]; then
    warn "Kon microfoonvolume niet uitlezen"
  elif ((v < 30)); then
    problem "Microfoonvolume is laag ($v%)"
    if ! $AUTOFIX; then
      warn "Microfoonvolume laag ($v%, autofix uitgeschakeld)"
    elif pactl set-source-volume "$src" 80% >>"$LOG" 2>&1; then
      fixed "Microfoonvolume van $v% naar 80% gezet"
    else
      warn "Microfoonvolume laag ($v%)"
    fi
  else
    ok "Microfoonvolume: $v%"
  fi

  # Eerste meting
  if ! mic_once "$src"; then
    bad "Opnemen mislukt via $src (zie log)"
    return
  fi

  # Evalueren, zo nodig herstellen en opnieuw proberen
  if [[ $MIC_STATE == silent ]]; then
    problem "Microfoon levert digitale stilte (piek ${MIC_PEAK}%)"
    if $AUTOFIX; then
      pactl set-source-mute "$src" 0 >>"$LOG" 2>&1
      pactl set-source-volume "$src" 100% >>"$LOG" 2>&1
      alsa_mixer_fix quiet
      info "Opnieuw proberen na mute/volume-herstel..."
      mic_once "$src"
    fi
    if [[ $MIC_STATE == silent ]] && $AUTOFIX; then
      local other found_other=false
      while IFS= read -r other; do
        [[ -z $other || $other == "$src" ]] && continue
        info "Proberen met andere microfoon: $other"
        mic_unmute_boost "$other"
        if mic_once "$other" && [[ $MIC_STATE != silent ]]; then
          pactl set-default-source "$other" >>"$LOG" 2>&1
          DEF_SRC="$other"; src="$other"; found_other=true
          fixed "Standaard microfoon gewijzigd naar werkend apparaat: $other"
          break
        fi
      done <<<"$sources"
      $found_other || MIC_STATE=silent
    fi
  fi

  case $MIC_STATE in
    ok)
      ok "Microfoon-test geslaagd (piek ${MIC_PEAK}%, gemiddeld ${MIC_DB} dBFS) via $src"
      ;;
    low)
      warn "Microfoonsignaal zeer zacht (piek ${MIC_PEAK}%): spreek luider/dichterbij of verhoog volume/boost in pavucontrol"
      ;;
    clip)
      warn "Microfoonsignaal clipt (piek ${MIC_PEAK}%): verlaag het microfoonvolume om vervorming te voorkomen"
      ;;
    silent)
      bad "Microfoon geeft alleen stilte. Controleer mute-knop op headset, aansluiting, privacyschakelaar (laptoptoets) en BIOS."
      ;;
    *)
      bad "Microfoon-analyse mislukt"
      ;;
  esac

  # Terugluisteren
  if $INTERACTIVE && [[ $MIC_STATE == ok || $MIC_STATE == low || $MIC_STATE == clip ]] && have paplay; then
    if ask_yn "  Wil je de opname terugluisteren?"; then
      paplay "$TMPD/mic.wav" >>"$LOG" 2>&1
      ask_yn "  Hoorde je jezelf duidelijk?"; local a=$?
      case $a in
        0) ok "Opname terug te horen: invoer en uitvoer werken samen" ;;
        1) warn "Opname was niet duidelijk hoorbaar (ruis/zacht/vervormd)" ;;
        2) info "Terugluisteren overgeslagen" ;;
      esac
    fi
  fi
}

# ----------------------------------------------------------------------------
# 9. Technische details naar het logbestand
# ----------------------------------------------------------------------------
section_details() {
  hdr "9. Technische details worden in het logbestand gezet"
  logonly ""; logonly "################ BIJLAGE: TECHNISCHE DETAILS ################"
  local c
  if have pactl; then runlog pactl list sinks; runlog pactl list sources; runlog pactl list cards; fi
  if have amixer; then
    for c in $(card_ids); do runlog amixer -c "$c" scontents; done
  fi
  runlog sh -c 'lsmod | grep -E "^snd"'
  runlog sh -c "cat '$ASOUND_CARDS'; echo; cat /proc/asound/modules 2>/dev/null"
  info "Details opgeslagen."
}

# ----------------------------------------------------------------------------
# Samenvatting
# ----------------------------------------------------------------------------
summary() {
  local i
  local nok=${#OKS[@]} nw=${#WARNS[@]} nf=${#FAILS[@]} nx=${#FIXES[@]}
  say ""
  say "${BLD}==============================================================${RST}"
  say "${BLD}                  SAMENVATTING AUDIOTEST${RST}"
  say "${BLD}==============================================================${RST}"
  say "  ${GRN}OK: $nok${RST}   ${YEL}Waarschuwingen: $nw${RST}   ${RED}Fouten: $nf${RST}   ${GRN}Opgelost: $nx${RST}"
  say ""

  if ((nf > 0)); then
    say "${RED}${BLD}Fouten (niet opgelost):${RST}"
    for i in "${FAILS[@]}"; do say "  ${RED}x${RST} $i"; done; say ""
  fi
  if ((nw > 0)); then
    say "${YEL}${BLD}Waarschuwingen:${RST}"
    for i in "${WARNS[@]}"; do say "  ${YEL}!${RST} $i"; done; say ""
  fi
  if ((nx > 0)); then
    say "${GRN}${BLD}Automatisch opgelost:${RST}"
    for i in "${FIXES[@]}"; do say "  ${GRN}+${RST} $i"; done; say ""
  fi
  if ((nok > 0)); then
    say "${GRN}${BLD}Geslaagd:${RST}"
    for i in "${OKS[@]}"; do say "  ${GRN}v${RST} $i"; done; say ""
  fi

  if $NEED_REBOOT; then
    say "${YEL}Let op: herstart de computer om alle wijzigingen te activeren.${RST}"
  fi
  if $NEED_RELOGIN; then
    say "${YEL}Let op: log opnieuw in om groepswijzigingen ('audio') te activeren.${RST}"
  fi

  if ((nf == 0 && nw == 0)); then
    say "${GRN}${BLD}Conclusie: alle audio werkt goed.${RST}"
  elif ((nf == 0)); then
    say "${YEL}${BLD}Conclusie: audio werkt, maar er zijn aandachtspunten.${RST}"
  else
    say "${RED}${BLD}Conclusie: er zijn audioproblemen die handmatige aandacht vragen.${RST}"
  fi
  say ""
  say "Logbestand: $LOG"
  say "Tip: voor handmatig beheer: pavucontrol (installeren: sudo apt install pavucontrol)"
}

# ----------------------------------------------------------------------------
# Hoofdprogramma
# ----------------------------------------------------------------------------
say "${BLD}Audiotest voor Linux Mint (XFCE)${RST}  -  $(date '+%F %T')"
say "Logbestand: $LOG"

section_system
section_packages
section_hardware
section_server
section_devices
section_volume
section_speakers
section_mic
section_details
summary

((${#FAILS[@]} == 0)) && exit 0 || exit 1
