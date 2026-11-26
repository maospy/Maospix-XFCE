#!/bin/bash
# maospix-xfce — instala el escritorio y la identidad maospix en un Debian Forky YA instalado
# (lo mismo que trae la ISO, sin las partes del live ni Calamares).
# Uso (como root):  bash tools/instalar-en-esta-pc.sh USUARIO
# Progreso en out/instalar-pc/: etapa, instalar.log, ESTADO (OK o FALLA).
set -eo pipefail
U="${1:?Falta el usuario}"
H=$(getent passwd "$U" | cut -d: -f6)
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SAL="$RAIZ/out/instalar-pc"
DEB=$(ls "$RAIZ"/config/packages.chroot/maospix-xfce-settings_*_all.deb | sort -V | tail -1)
export DEBIAN_FRONTEND=noninteractive
etapa(){ echo "$1|$2" > "$SAL/etapa"; echo; echo "===== [$1%] $2 — $(date +%T)"; }
trap 'echo FALLA > "$SAL/ESTADO"; echo "FALLÓ en la línea $LINENO"' ERR

etapa 2 "Repos: contrib + non-free y Brave"
# Agrega contrib/non-free a las líneas de Debian (igual que la ISO)
sed -i -E '/^deb(-src)? .*(deb\.debian\.org|security\.debian\.org)/{/ contrib/! s/ main / main contrib non-free /}' /etc/apt/sources.list
install -m644 "$RAIZ/config/archives/brave.key" /usr/share/keyrings/brave-browser-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' \
  > /etc/apt/sources.list.d/brave-browser-release.list

etapa 8 "Actualizando lista de paquetes"
apt-get update

# NetworkManager no debe pelear con systemd-networkd por la red cableada (de ella depende ssh/Tailscale)
if systemctl is-active -q systemd-networkd; then
  mkdir -p /etc/NetworkManager/conf.d
  CABLE=$(networkctl list --no-legend 2>/dev/null | awk '$5=="configured"{print "interface-name:"$2}' | paste -sd';')
  [ -n "$CABLE" ] && printf '[keyfile]\nunmanaged-devices=%s\n' "$CABLE" > /etc/NetworkManager/conf.d/90-maospix-networkd.conf
fi

etapa 15 "Descargando e instalando XFCE, LightDM, apps y tema maospix (lo más largo)"
PAQ=$(grep -hvE '^\s*(#|$)' "$RAIZ/config/package-lists/xfce.list.chroot")
# shellcheck disable=SC2086
apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confold \
  $PAQ network-manager firmware-linux-free "$DEB"

etapa 80 "Predeterminados: kitty, Brave, fastfetch, watchdog"
update-alternatives --set x-terminal-emulator /usr/bin/kitty
B=$(update-alternatives --list x-www-browser 2>/dev/null | grep brave | head -1 || true)
[ -n "$B" ] && update-alternatives --set x-www-browser "$B"
grep -q maospix-fastfetch /etc/bash.bashrc || cat >> /etc/bash.bashrc <<'EOS'

# maospix-fastfetch
case $- in *i*) [ -n "$DISPLAY$WAYLAND_DISPLAY" ] && command -v fastfetch >/dev/null && fastfetch ;; esac
EOS
printf 'blacklist iTCO_wdt\nblacklist iTCO_vendor_support\nblacklist sp5100_tco\n' > /etc/modprobe.d/maospix-watchdog.conf

etapa 88 "Configuración de $U (panel, dock, tema, fish)"
# Copia la config de /etc/skel sin pisar nada que ya exista
sudo -u "$U" mkdir -p "$H/.config"
sudo -u "$U" cp -rn /etc/skel/.config/. "$H/.config/"
# fish tiene que ver los mismos programas que bash (claude, npm global, ~/.local/bin)
sudo -u "$U" mkdir -p "$H/.config/fish/conf.d"
sudo -u "$U" tee "$H/.config/fish/conf.d/maospix-path.fish" >/dev/null <<'EOF'
for d in ~/.npm-global/bin ~/.local/bin ~/bin
    test -d $d; and fish_add_path -g $d
end
EOF
chsh -s /usr/bin/fish "$U"
sudo -u "$U" env LANG=es_PY.UTF-8 xdg-user-dirs-update || true

etapa 95 "Activando LightDM al arrancar"
systemctl enable lightdm
systemctl set-default graphical.target

etapa 98 "Verificando"
F=0
for p in $PAQ maospix-xfce-settings; do
  dpkg -s "$p" >/dev/null 2>&1 || { echo "FALTA: $p"; F=1; }
done
[ "$(getent passwd "$U" | cut -d: -f7)" = /usr/bin/fish ] || { echo "FALTA: fish como shell"; F=1; }
[ -f "$H/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" ] || { echo "FALTA: panel en $H"; F=1; }
systemctl is-enabled -q lightdm || { echo "FALTA: lightdm habilitado"; F=1; }
[ $F = 0 ] || { echo FALLA > "$SAL/ESTADO"; exit 1; }
etapa 100 "Listo"
echo OK > "$SAL/ESTADO"
