#!/bin/bash
# maospix-xfce — revisa una ISO antes de probarla
# Uso: bash tools/verificar-iso.sh out/pruebaN/archivo.iso [epoch_inicio_build]
set -uo pipefail
ISO="$1"; INICIO="${2:-0}"
OK=0; FALLA=0
bien(){ echo "  [OK]    $*"; OK=$((OK+1)); }
mal(){  echo "  [FALLA] $*"; FALLA=$((FALLA+1)); }

echo "== Verificando $(basename "$ISO") =="
[ -f "$ISO" ] || { echo "No existe $ISO"; exit 1; }

TAM=$(du -h "$ISO" | cut -f1); bien "Tamaño: $TAM"

MT=$(stat -c %W "$ISO"); [ "$MT" -gt 0 ] || MT=$(stat -c %Z "$ISO")  # birth (live-build fija mtime)
[ "$MT" -ge "$INICIO" ] && bien "ISO creada en este build ($(date -d @"$MT" '+%F %T'))" \
                        || mal "La ISO es más vieja que el build: ¿ISO vieja?"

SHA=$(sha256sum "$ISO" | cut -d' ' -f1); bien "SHA-256: $SHA"
DIR=$(realpath "$(dirname "$ISO")")
for s in "$DIR"/../prueba*/SHA256SUMS; do
  [ -f "$s" ] && [ "$(realpath "$(dirname "$s")")" != "$DIR" ] || continue
  grep -q "$SHA" "$s" && mal "SHA-256 igual a $(basename "$(dirname "$s")"): ¡es la misma ISO!"
done

LISTA=$(xorriso -indev "$ISO" -find / -type f 2>/dev/null)
for f in /live/vmlinuz /live/initrd.img /live/filesystem.squashfs /EFI/boot/bootx64.efi /isolinux/isolinux.bin; do
  grep -qi "^'\?$f" <<< "$LISTA" && bien "Contiene $f" || mal "Falta $f"
done

xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null | grep -q "El Torito boot img" \
  && bien "Booteable El Torito (BIOS/UEFI)" || mal "Sin entradas El Torito"

# Repo interno de la ISO (GRUB para que Calamares instale sin internet)
if [ -f "$(dirname "$0")/../config/package-lists/grub-bios.list.binary" ]; then
  grep -q "^'\?/dists/forky/Release" <<< "$LISTA" && bien "Repo interno dists/forky" || mal "Falta /dists/forky/Release"
  for p in grub-pc_ grub-efi-amd64_ grub-efi-amd64-bin_; do
    grep -q "/pool/.*/$p" <<< "$LISTA" && bien "Repo interno tiene ${p%_}" || mal "Repo interno sin ${p%_}"
  done
fi

# Menú de arranque maospix (hook 9000-arranque-maospix)
MENU=$(mktemp)
for f in /isolinux/live.cfg /boot/grub/grub.cfg; do
  rm -f "$MENU"; xorriso -osirrox on -indev "$ISO" -extract "$f" "$MENU" >/dev/null 2>&1
  grep -q 'Iniciar maospix-xfce' "$MENU" 2>/dev/null \
    && bien "Menú de arranque maospix en $f" || mal "$f sin el menú maospix"
done
rm -f "$MENU"

# Contenido del sistema live (squashfs)
if command -v unsquashfs >/dev/null; then
  # En el disco, al lado de la ISO: /tmp es tmpfs (RAM) y el squashfs pesa ~2 GB
  TMP=$(mktemp -d -p "$(dirname "$ISO")" .verif.XXXX); trap 'rm -rf "$TMP"' EXIT
  xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$TMP/fs.sqfs" >/dev/null 2>&1
  ARCH=$(unsquashfs -l "$TMP/fs.sqfs" 2>/dev/null)
  for f in /usr/bin/xfce4-session /usr/sbin/lightdm /usr/sbin/lightdm-gtk-greeter /usr/bin/calamares \
           /usr/bin/brave-browser /usr/bin/kitty /usr/bin/fastfetch /usr/bin/btop /usr/bin/htop /usr/bin/curl /usr/bin/wget /usr/bin/nm-applet /usr/bin/wireplumber /usr/lib/systemd/user/dbus.socket /usr/bin/pactl /usr/bin/aplay /usr/libexec/xfce-polkit; do
    grep -q "^squashfs-root$f\$" <<< "$ARCH" && bien "Sistema live tiene $f" || mal "Sistema live sin $f"
  done
  unsquashfs -lls "$TMP/fs.sqfs" etc/localtime 2>/dev/null | grep -q 'America/Asuncion' \
    && bien "Zona horaria America/Asuncion" || mal "Zona horaria no es America/Asuncion"
  # Identidad maospix (paquete maospix-xfce-settings)
  for f in /usr/share/themes/Maospix-Dark/gtk-3.0/gtk.css /usr/share/themes/Maospix-Dark/xfwm4/themerc \
           /usr/share/icons/Maospix-Papirus-Dark/index.theme /usr/share/icons/Bibata-Modern-Ice/index.theme \
           /usr/share/backgrounds/maospix/maospix-maospix.png /usr/share/maospix/maospix-logo.ansi \
           /usr/bin/fish /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libdocklike.so \
           /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml /etc/skel/.config/fish/config.fish \
           /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libweather.so /usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libgenmon.so \
           /usr/bin/devilspie2 /usr/bin/curl /usr/bin/maospix-clima /usr/libexec/maospix/reloj \
           /etc/skel/.config/devilspie2/maximizar.lua /etc/xdg/autostart/maospix-ventanas.desktop; do
    grep -q "^squashfs-root$f\$" <<< "$ARCH" && bien "Sistema live tiene $f" || mal "Sistema live sin $f"
  done
  unsquashfs -cat "$TMP/fs.sqfs" etc/adduser.conf 2>/dev/null | grep -q '^DSHELL=/usr/bin/fish' \
    && bien "fish es la shell por defecto de usuarios nuevos" || mal "adduser.conf sin DSHELL=/usr/bin/fish"
  if grep -q calamares-sources-media <<< "$ARCH"; then
    unsquashfs -cat "$TMP/fs.sqfs" usr/share/calamares/helpers/calamares-sources-media 2>/dev/null \
      | grep -q '^RELEASE="forky"' && bien "Calamares apunta al repo forky" || mal "Calamares sigue con RELEASE=trixie"
  fi
  # Instalador maospix (bloque 2)
  for f in /etc/calamares/branding/maospix/branding.desc /etc/calamares/branding/maospix/show.qml \
           /etc/calamares/branding/maospix/welcome.png /etc/calamares/branding/maospix/slide3.png \
           /etc/calamares/modules/locale.conf /etc/calamares/modules/shellprocess-limpiar-live.conf \
           /usr/share/applications/maospix-instalar.desktop /usr/libexec/maospix/instalar-icono \
           /etc/xdg/autostart/maospix-instalar-icono.desktop /etc/calamares/branding/maospix/stylesheet.qss \
           /usr/sbin/mkfs.fat /usr/sbin/mkfs.btrfs /usr/sbin/mkfs.xfs /usr/bin/unsquashfs /usr/sbin/mkfs.ntfs /usr/bin/efibootmgr \
           /usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/qmldir /usr/lib/x86_64-linux-gnu/qt6/qml/QtQuick/Window/qmldir \
           /usr/share/qt6/translations/qtbase_es.qm; do
    grep -q "^squashfs-root$f\$" <<< "$ARCH" && bien "Sistema live tiene $f" || mal "Sistema live sin $f"
  done
  grep -q '^squashfs-root/etc/xdg/autostart/calamares-desktop-icon.desktop$' <<< "$ARCH" \
    && mal "Sigue el ícono 'Install Debian' de Debian" || bien "Sin ícono 'Install Debian' de Debian"
  cq(){ unsquashfs -cat "$TMP/fs.sqfs" "$1" 2>/dev/null | grep -q "$2" && bien "$3" || mal "$3 ($1)"; }
  cq etc/calamares/settings.conf '^branding: maospix' "Calamares usa el branding maospix"
  cq etc/calamares/settings.conf 'shellprocess@limpiar-live' "Calamares limpia lo del live al instalar"
  cq etc/calamares/modules/welcome.conf 'requiredStorage: *10$' "Calamares pide 10 GB de disco"
  cq etc/calamares/modules/locale.conf 'Asuncion' "Calamares arranca en Asunción (es_PY)"
  cq etc/calamares/modules/users.conf 'shell: /usr/bin/fish' "Usuario instalado con fish"
  cq etc/calamares/modules/users.conf '^allowWeakPasswords: true' "Calamares permite contraseñas cortas"
  cq etc/skel/.config/devilspie2/maximizar.lua '"calamares"' "Calamares no se abre maximizado"
  cq usr/share/calamares/helpers/calamares-sources-final 'RELEASE="forky"' "Sistema instalado queda con repos forky"
  cq usr/share/applications/calamares-install-debian.desktop '^NoDisplay=true' "'Install Debian' oculto del menú"
  cq etc/skel/.config/fastfetch/config.jsonc 'maospix-xfce' "fastfetch muestra maospix-xfce como SO"
  cq etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml '"Super_L" type="string" value="xfce4-popup-whiskermenu"' "Tecla Windows abre el menú"
  cq etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml '&lt;Super&gt;Return" type="string" value="exo-open --launch TerminalEmulator"' "Super+Enter abre la terminal"
  cq etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml '&lt;Super&gt;q" type="string" value="close_window_key"' "Super+Q cierra la ventana"
  cq etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml '&lt;Super&gt;Left" type="string" value="tile_left_key"' "Super+flechas acomodan ventanas (mosaico)"
  cq etc/xdg/autostart/maospix-fondos.desktop '^Exec=/usr/libexec/maospix/fondos-usuario' "Fondos se copian a ~/Imágenes/Fondos al primer inicio"
  cq usr/share/lightdm/lightdm.conf.d/60-maospix.conf "^greeter-hide-users=false" "Inicio de sesión muestra los usuarios"
  cq etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml "workspace_names" "Áreas de trabajo con números"
  cq etc/calamares/modules/users.conf "minLength: 1" "Calamares acepta contraseñas cortas"
  cq etc/calamares/modules/partition.conf "^initialSwapChoice: file" "Calamares: swap en archivo por defecto"
  cq etc/calamares/branding/maospix/stylesheet.qss "QCheckBox::indicator" "Calamares: casillas visibles"
  cq etc/calamares/modules/partition.conf "availableFileSystemTypes: \[ \"ext4\", \"btrfs\", \"xfs\" \]" "Calamares: elegir ext4, btrfs o xfs"
  cq etc/calamares/modules/mount.conf "subvolume: /@home" "Calamares: subvolúmenes btrfs"
  cq etc/calamares/modules/users.conf "^displayAutologin: true" "Calamares: casilla de inicio automático"
  cq etc/calamares/modules/shellprocess-limpiar-live.conf "autologin-user=liveuser" "Limpieza respeta el autologin elegido"
  grep -q "^squashfs-root/usr/libexec/maospix/fondos-usuario$" <<< "$ARCH" && bien "Sistema live tiene fondos-usuario" || mal "Sistema live sin /usr/libexec/maospix/fondos-usuario"
  for w in oscuro retrowave; do grep -q "^squashfs-root/usr/share/backgrounds/maospix/maospix-$w.png$" <<< "$ARCH" && bien "Fondo $w" || mal "Falta fondo $w"; done
else
  mal "Falta unsquashfs (sudo apt install squashfs-tools)"
fi

echo
echo "Resultado: $OK OK, $FALLA FALLA"
[ "$FALLA" = 0 ] && echo ">> Lista para probar en VirtualBox." || echo ">> NO la pruebes todavía, avisale a Claude."
