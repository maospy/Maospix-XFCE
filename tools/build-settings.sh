#!/bin/bash
# maospix-xfce — arma el paquete maospix-xfce-settings (.deb) y lo deja en
# config/packages.chroot/ para que live-build lo instale en la ISO.
# Uso: bash tools/build-settings.sh     (no necesita sudo; build-iso.sh lo llama solo)
#
# Qué genera además de los archivos fijos de packages/maospix-xfce-settings/raiz:
#  - Tema GTK/xfwm4 "Maospix-Dark": copia de Orchis-Dark con la paleta maospix.
#  - Íconos "Maospix-Papirus-Dark": hereda Papirus-Dark, carpetas en cian.
#  - Wallpapers y logos desde assets/.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$RAIZ/packages/maospix-xfce-settings"
CACHE="$RAIZ/packages/.cache"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ST="$TMP/st"                        # árbol del paquete
VERSION="$(cat "$PKG/VERSION")"
MIRROR=http://deb.debian.org/debian
LISTAS="http://deb.debian.org/debian/dists/forky/main/binary-amd64/Packages.xz"

# ---------- 1. Bajar Orchis y Papirus (solo para generar los temas derivados) ----------
mkdir -p "$CACHE"
if [ ! -s "$CACHE/Packages" ] || [ -n "$(find "$CACHE/Packages" -mtime +7)" ]; then
  echo "· Bajando índice de paquetes de forky…"
  curl -fsSL "$LISTAS" | xz -d > "$CACHE/Packages"
fi
bajar(){  # $1 = paquete → imprime ruta local del .deb
  local f; f=$(awk -v p="$1" '$1=="Package:"{ok=($2==p)} ok&&$1=="Filename:"{print $2; exit}' "$CACHE/Packages")
  [ -n "$f" ] || { echo "ERROR: $1 no está en forky" >&2; exit 1; }
  [ -s "$CACHE/$(basename "$f")" ] || { echo "· Bajando $(basename "$f")…" >&2; curl -fsSL -o "$CACHE/$(basename "$f")" "$MIRROR/$f"; }
  echo "$CACHE/$(basename "$f")"
}
ORCHIS=$(bajar orchis-gtk-theme)
PAPIRUS=$(bajar papirus-icon-theme)
mkdir -p "$TMP/orchis" "$TMP/papirus"
dpkg-deb -x "$ORCHIS" "$TMP/orchis"
dpkg-deb -x "$PAPIRUS" "$TMP/papirus"

# ---------- 2. Archivos fijos ----------
mkdir -p "$ST"
cp -a "$PKG/raiz/." "$ST/"

# ---------- 3. Tema Maospix-Dark (desde Orchis-Dark) ----------
T="$ST/usr/share/themes/Maospix-Dark"
mkdir -p "$T"
cp -a "$TMP/orchis/usr/share/themes/Orchis-Dark/"{gtk-3.0,gtk-4.0,xfwm4,index.theme} "$T/"
# Paleta: gris de Orchis → navy maospix; azul de acento → cian maospix
mapa='s/#3281EA/#4FD8E8/gi; s/#212121/#0F1524/gi; s/#242424/#121A2B/gi; s/#2C2C2C/#161F33/gi;
      s/#3C3C3C/#222D45/gi; s/#404040/#26324B/gi; s/#1A73E8/#4FD8E8/gi'
find "$T" -type f \( -name '*.css' -o -name '*.xpm' -o -name 'themerc' -o -name '*.svg' \) -print0 \
  | xargs -0 sed -i -E "$mapa"
# El cian es claro: texto seleccionado en navy en vez de blanco (contraste)
for css in "$T"/gtk-3.0/*.css "$T"/gtk-4.0/*.css; do
  perl -0pi -e 's/(background-color: #4FD8E8;\s*\n\s*color:) white;/$1 #0F1524;/gi;
                s/(\@define-color theme_selected_fg_color) white;/$1 #0F1524;/gi' "$css"
done
sed -i -e 's/^Name=.*/Name=Maospix-Dark/' -e 's/^Comment=.*/Comment=Tema oscuro maospix (basado en Orchis, GPL-3.0)/' \
       -e 's/Orchis-Dark/Maospix-Dark/g' "$T/index.theme"
cp "$TMP/orchis/usr/share/doc/orchis-gtk-theme/copyright" "$T/COPYRIGHT-Orchis" 2>/dev/null || true

# ---------- 4. Íconos Maospix-Papirus-Dark (carpetas cian) ----------
I="$ST/usr/share/icons/Maospix-Papirus-Dark"
mkdir -p "$I"
P="$TMP/papirus/usr/share/icons/Papirus"
DIRS=""
for d in "$P"/*/places; do
  tam=$(basename "$(dirname "$d")")
  mkdir -p "$I/$tam/places"
  # Cada folder-cyan-XXX.svg / user-cyan-XXX.svg pasa a ser folder-XXX.svg / user-XXX.svg
  for f in "$d"/folder-cyan*.svg "$d"/user-cyan-*.svg; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); n=${b/-cyan/}
    ln -s "/usr/share/icons/Papirus/$tam/places/$b" "$I/$tam/places/$n"
  done
  DIRS="$DIRS${DIRS:+,}$tam/places"
done
{
  echo "[Icon Theme]"
  echo "Name=Maospix-Papirus-Dark"
  echo "Comment=Papirus-Dark con carpetas cian (maospix)"
  echo "Inherits=Papirus-Dark,Adwaita,hicolor"
  echo "Directories=$DIRS"
  echo
  for x in ${DIRS//,/ }; do
    awk -v s="[$x]" '$0==s{p=1;print;next} /^\[/{p=0} p' "$P/index.theme"; echo
  done
} > "$I/index.theme"

# ---------- 5. Wallpapers y logos ----------
W="$ST/usr/share/backgrounds/maospix"; mkdir -p "$W"
for w in maospix nord negro grafito oscuro retrowave; do
  cp "$RAIZ/assets/wallpapers/generated/maospix-xfce-$w.png" "$W/maospix-$w.png"
done
M="$ST/usr/share/maospix"; mkdir -p "$M"
cp "$RAIZ/assets/branding/maospix-logo.ansi" "$RAIZ/assets/branding/maospix-logo.svg" \
   "$RAIZ/assets/branding/maospix-logo-neon.png" "$M/"
mkdir -p "$ST/usr/share/icons/hicolor/scalable/apps"
cp "$RAIZ/assets/branding/maospix-logo.svg" "$ST/usr/share/icons/hicolor/scalable/apps/maospix.svg"
# Fondo por defecto de xfdesktop en Debian (si no hay configuración propia)
mkdir -p "$ST/usr/share/images/desktop-base"
ln -s /usr/share/backgrounds/maospix/maospix-maospix.png "$ST/usr/share/images/desktop-base/default"

# ---------- 6. Control y empaquetado ----------
mkdir -p "$ST/DEBIAN"
sed "s/@VERSION@/$VERSION/; s/@SIZE@/$(du -sk --exclude=DEBIAN "$ST" | cut -f1)/" "$PKG/debian/control" > "$ST/DEBIAN/control"
for s in postinst postrm; do install -m755 "$PKG/debian/$s" "$ST/DEBIAN/$s"; done
( cd "$ST" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | sort -z | xargs -0 md5sum > DEBIAN/md5sums )
chmod -R u+rwX,go+rX,go-w "$ST"

DEST="$RAIZ/config/packages.chroot"; mkdir -p "$DEST"
rm -f "$DEST"/maospix-xfce-settings_*.deb
DEB="$DEST/maospix-xfce-settings_${VERSION}_all.deb"
dpkg-deb --root-owner-group -Zxz --build "$ST" "$DEB" >/dev/null
echo "OK: $DEB ($(du -h "$DEB" | cut -f1))"
