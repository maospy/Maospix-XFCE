#!/usr/bin/env python3
"""Genera el logo de fastfetch (texto braille a color) desde el logo neón de MAOSPIX.
Uso: python3 tools/gen-logo-ansi.py [columnas] [salida.ansi]   (requiere Pillow)
Cada carácter braille = 2x4 puntos. Se enciende un punto donde el logo es brillante
(los bordes neón y el texto); el color de cada carácter es el promedio de sus puntos."""
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

root = Path(__file__).resolve().parent.parent
src = root / "assets/branding/maospix-logo-neon.png"
cols = int(sys.argv[1]) if len(sys.argv) > 1 else 40
out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "assets/branding/maospix-logo.ansi"

img = Image.open(src).convert("RGBA")
img = img.crop(img.getbbox())                     # recorta el fondo transparente
w, h = img.size
rows = round(cols * 2 / w * h / 4)                # aspecto: celda de terminal ~1:2
img = img.resize((cols * 2, rows * 4), Image.LANCZOS)
img = ImageEnhance.Color(img).enhance(1.4)
px = img.load()

def lit(x, y):
    r, g, b, a = px[x, y]
    return a > 128 and max(r, g, b) > 120         # neón y texto; fondo oscuro apagado

BITS = [(0, 0, 0x01), (0, 1, 0x02), (0, 2, 0x04), (1, 0, 0x08),
        (1, 1, 0x10), (1, 2, 0x20), (0, 3, 0x40), (1, 3, 0x80)]
lines = []
for cy in range(rows):
    line, last = "", None
    for cx in range(cols):
        code, acc = 0, []
        for dx, dy, bit in BITS:
            x, y = cx * 2 + dx, cy * 4 + dy
            if lit(x, y):
                code |= bit
                acc.append(px[x, y][:3])
        if not code:
            line += " "
            continue
        r, g, b = (sum(c[i] for c in acc) // len(acc) for i in range(3))
        color = f"\033[38;2;{r};{g};{b}m"
        if color != last:
            line += color
            last = color
        line += chr(0x2800 + code)
    lines.append(line.rstrip() + "\033[0m")
out.write_text("\n".join(lines) + "\n")
print(f"{out} ({cols}x{rows})")
