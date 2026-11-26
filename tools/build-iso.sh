#!/bin/bash
# maospix-xfce — construye la ISO en build/ y la deja en out/pruebaN/
# Uso: sudo bash tools/build-iso.sh
# El build corre en segundo plano (sobrevive a Ctrl+C o corte de ssh).
# Para volver a ver el progreso: bash tools/ver-progreso.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Ejecutar con sudo: sudo bash tools/build-iso.sh"; exit 1; }

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
USUARIO="${SUDO_USER:-root}"
BUILD="$RAIZ/build"

if [ -z "${MAOSPIX_BG:-}" ]; then
  # ---- Parte visible: prepara y lanza el build en segundo plano ----
  if pgrep -f 'MAOSPIX_BG_RUN' >/dev/null || pgrep -x lb >/dev/null; then
    echo "Ya hay un build corriendo. Ver progreso: bash tools/ver-progreso.sh"; exit 1
  fi
  # Paquete de identidad maospix (como usuario normal, antes de lanzar el build)
  sudo -u "$USUARIO" bash "$RAIZ/tools/build-settings.sh" || { echo "ERROR armando maospix-xfce-settings"; exit 1; }
  N=1; while [ -d "$RAIZ/out/prueba$N" ]; do N=$((N+1)); done
  SALIDA="$RAIZ/out/prueba$N"; mkdir -p "$SALIDA"
  date +%s > "$SALIDA/.inicio"
  echo "== maospix-xfce: prueba$N — inicio: $(date '+%F %H:%M:%S') =="
  echo "   Log: $SALIDA/build.log"
  echo "   (Si se corta el ssh, el build sigue. Volver a mirar: bash tools/ver-progreso.sh)"
  MAOSPIX_BG=1 SALIDA="$SALIDA" USUARIO="$USUARIO" \
    setsid nohup bash "$0" MAOSPIX_BG_RUN >/dev/null 2>&1 < /dev/null &
  sleep 1
  exec bash "$RAIZ/tools/ver-progreso.sh" "$SALIDA"
fi

# ---- Parte en segundo plano ----
LOG="$SALIDA/build.log"
INICIO=$(cat "$SALIDA/.inicio")
termina(){ echo "$1" > "$SALIDA/ESTADO"; chown -R "$USUARIO": "$SALIDA"; }
trap 'termina ERROR' ERR

mkdir -p "$BUILD"; cd "$BUILD"
lb clean >>"$LOG" 2>&1 || true          # conserva cache/ (descargas)
rm -rf config auto ./*.iso
bash "$RAIZ/tools/lb-config.sh" >>"$LOG" 2>&1
# Si cambió la config del bootstrap (distribución, opciones de debootstrap...), rehacer la base cacheada
HUELLA=$(grep -h -E '^LB_(DISTRIBUTION|ARCHITECTURE|ARCHIVE_AREAS|MIRROR_BOOTSTRAP)|^DEBOOTSTRAP_OPTIONS' config/bootstrap config/common | sha256sum | cut -c1-16)
if [ "$(cat cache/.huella-bootstrap 2>/dev/null)" != "$HUELLA" ]; then
  echo "Config del bootstrap cambió: se descarta cache/bootstrap" >>"$LOG"
  rm -rf cache/bootstrap; mkdir -p cache; echo "$HUELLA" > cache/.huella-bootstrap
fi
cp -a "$RAIZ/config/." config/           # superponer nuestro perfil

lb build >>"$LOG" 2>&1
date +%s > "$SALIDA/.fin"

ISO_ORIG=$(ls -t "$BUILD"/*.iso 2>/dev/null | head -1 || true)
[ -n "$ISO_ORIG" ] || { echo "ERROR: no se generó ninguna ISO" >>"$LOG"; termina ERROR; exit 1; }
N=$(basename "$SALIDA")
ISO="$SALIDA/maospix-xfce-$N-$(date +%Y.%m.%d).iso"
mv "$ISO_ORIG" "$ISO"
(cd "$SALIDA" && sha256sum "$(basename "$ISO")" > SHA256SUMS)
bash "$RAIZ/tools/verificar-iso.sh" "$ISO" "$INICIO" > "$SALIDA/verificacion.txt" 2>&1 || true
termina OK
