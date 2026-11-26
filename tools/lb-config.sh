#!/bin/bash
# Configuración base de live-build para maospix-xfce (se ejecuta dentro de build/)
set -e
lb config noauto \
  --mode debian \
  --distribution forky \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap http://deb.debian.org/debian/ \
  --mirror-binary http://deb.debian.org/debian/ \
  --security false \
  --updates false \
  --apt-recommends false \
  --binary-images iso-hybrid \
  --bootloaders "grub-efi,syslinux" \
  --debian-installer none \
  --debootstrap-options "--include=ca-certificates" \
  --firmware-chroot true \
  --iso-application "maospix-xfce" \
  --iso-volume "MAOSPIX-XFCE" \
  --iso-publisher "maospy" \
  --bootappend-live "boot=live components quiet splash loglevel=3 hostname=maospix username=liveuser locales=es_PY.UTF-8 keyboard-layouts=latam timezone=America/Asuncion modprobe.blacklist=iTCO_wdt,iTCO_vendor_support,sp5100_tco" \
  "$@"
