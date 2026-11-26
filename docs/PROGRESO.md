# Progreso — maospix-xfce

## Versión 1.0 (2026-11-26)
Primera versión pública. Base: Debian 14 Forky (testing) + XFCE 4.20, construida con live-build.
Probada en VirtualBox (UEFI y BIOS legacy) y en una PC real (instalación en disco, sonido, red).

Hecho:
- ISO live híbrida (UEFI + BIOS legacy) con menú de arranque maospix en español.
- Escritorio XFCE tematizado con el paquete `maospix-xfce-settings` (0.9): panel + dock, menú Whisker,
  reloj y clima, fish + fastfetch, 6 fondos, atajos de teclado (Super, Super+Enter, Super+Q, Super+flechas).
- Calamares con branding maospix: ext4/btrfs/xfs, swap en archivo, contraseñas cortas, autologin opcional,
  limpieza del usuario live al instalar.
- LightDM con greeter tematizado que muestra los usuarios.
- Sonido con PipeWire + WirePlumber (incluye `dbus-user-session`).
- `tools/verificar-iso.sh`: 100 controles automáticos sobre el contenido de la ISO.

## Pendiente (próximas versiones)
1. Plymouth con tema maospix y GRUB tematizado en el sistema instalado (hoy arranca en texto).
2. Flatpak + Flathub preconfigurado.
3. Medir y recortar RAM en reposo (objetivo < 700 MB) y firmware/paquetes de sobra.
4. Herramientas "estilo Omarchy": `maospix-tema` (cambia tema, terminal y fondo juntos), lanzador rofi.
5. Probar en hardware viejo real (i3 2ª gen, 4 GB, GPU NVIDIA Kepler, BIOS legacy).
