#!/bin/bash
# Rescata una ISO que quedó en build/ si el script se cortó (uso: sudo bash tools/finalizar-prueba.sh out/pruebaN)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"; SALIDA="$(cd "$1" && pwd)"; USUARIO="${SUDO_USER:-root}"
ISO_ORIG=$(ls -t "$RAIZ"/build/*.iso | head -1)
ISO="$SALIDA/maospix-xfce-$(basename "$SALIDA")-$(date +%Y.%m.%d).iso"
mv "$ISO_ORIG" "$ISO"
(cd "$SALIDA" && sha256sum "$(basename "$ISO")" > SHA256SUMS)
INICIO=$(stat -c %W "$SALIDA")
bash "$RAIZ/tools/verificar-iso.sh" "$ISO" "$INICIO" | tee "$SALIDA/verificacion.txt"
echo OK > "$SALIDA/ESTADO"; chown -R "$USUARIO": "$SALIDA"
