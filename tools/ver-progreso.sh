#!/bin/bash
# maospix-xfce — muestra el progreso del build (Ctrl+C solo cierra esta vista)
# Uso: bash tools/ver-progreso.sh [out/pruebaN]
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="${1:-$(ls -d "$RAIZ"/out/prueba* 2>/dev/null | sort -V | tail -1)}"
[ -d "$SALIDA" ] || { echo "No hay builds en out/"; exit 1; }
LOG="$SALIDA/build.log"
INICIO=$(cat "$SALIDA/.inicio" 2>/dev/null || stat -c %Y "$SALIDA")

etapa(){
  local c
  c=$(grep -oE '\] lb [a-z0-9_-]+' "$LOG" 2>/dev/null | tail -1 | awk '{print $3}')
  case "$c" in
    bootstrap|bootstrap_cache|bootstrap_debootstrap) echo "5|Descargando sistema base";;
    bootstrap_*)                                      echo "15|Preparando sistema base";;
    chroot|chroot_prep|chroot_*archives|chroot_apt*|chroot_firmware) echo "25|Preparando chroot";;
    chroot_install-packages|chroot_package-lists|chroot_linux-image) echo "35|Instalando paquetes";;
    chroot_hooks|chroot_hacks|chroot_*)               echo "55|Ajustando el sistema";;
    binary|binary_chroot|binary_manifest|binary_package-lists|binary_linux-image) echo "60|Preparando imagen";;
    binary_rootfs)                                    echo "65|Comprimiendo squashfs (lo más lento)";;
    binary_grub*|binary_syslinux|binary_loopback*|binary_*efi*|binary_hooks|binary_includes|binary_checksums) echo "85|Instalando arranque UEFI/legacy";;
    binary_iso|binary_zsync)                          echo "92|Generando ISO";;
    source*)                                          echo "97|Finalizando";;
    *)                                                echo "1|Iniciando";;
  esac
}

echo "== Progreso $(basename "$SALIDA") — inicio: $(date -d @"$INICIO" '+%F %H:%M:%S') =="
MAX=0
while [ ! -f "$SALIDA/ESTADO" ]; do
  IFS='|' read -r PCT TXT <<< "$(etapa)"
  [ "${PCT:-0}" -gt "$MAX" ] && MAX=$PCT
  T=$(( $(date +%s) - INICIO ))
  printf "\r  [%s] %3d%%  %-38s transcurrido %02d:%02d " "$(date +%H:%M:%S)" "$MAX" "$TXT" $((T/60)) $((T%60))
  sleep 5
done
echo
FIN=$(cat "$SALIDA/.fin" 2>/dev/null || date +%s); T=$((FIN - INICIO))
if [ "$(cat "$SALIDA/ESTADO")" = OK ]; then
  printf "  [%s] 100%%  Build terminado en %02d:%02d\n\n" "$(date -d @"$FIN" +%H:%M:%S)" $((T/60)) $((T%60))
  cat "$SALIDA/verificacion.txt"
else
  echo "ERROR en el build. Últimas líneas del log:"; tail -30 "$LOG"
fi
