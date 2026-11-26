#!/usr/bin/env python3
"""Genera los wallpapers de identidad MAOSPIX-Niri (3840x2160).

Misma familia que Maospix KDE: Maospix, Nord, Negro y Grafito (colores sólidos
con cuadrícula suave), con el logo neón de Niri, "NIRI" y el lema.

Uso: python3 assets/gen-wallpapers.py            → maospix-niri-*.png (NIRI)
     python3 assets/gen-wallpapers.py xfce       → maospix-xfce-*.png (XFCE, DEBIAN | XFCE | LIBRE)
Fuentes Montserrat: variable MAOSPIX_FONTS (por defecto la de iNiR o la del sistema).
Salida: assets/wallpapers/generated/
"""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/branding/maospix-logo-neon.png"
FONTS = Path(os.environ.get("MAOSPIX_FONTS", "/usr/share/fonts/truetype/montserrat"))
EDICIONES = {
    "niri": ("NIRI", "ARCH  |  NIRI  |  LIBRE"),
    "xfce": ("XFCE", "DEBIAN  |  XFCE  |  LIBRE"),
}
EDICION = sys.argv[1] if len(sys.argv) > 1 else "niri"
TITULO, LEMA = EDICIONES[EDICION]
OUT = ROOT / "assets/wallpapers/generated"
W, H = 3840, 2160

CYAN = (79, 216, 232)
VIOLET = (179, 147, 245)

# nombre: (color de fondo, color de cuadrícula, brillo cian/violeta 0..1)
VARIANTES = {
    "maospix": ((15, 21, 36), (32, 44, 68), 1.0),
    "nord": ((46, 58, 76), (62, 76, 98), 0.55),
    "negro": ((7, 9, 13), (20, 26, 34), 0.8),
    "grafito": ((43, 44, 49), (58, 59, 66), 0.45),
    "oscuro": ((0, 0, 0), (13, 15, 19), 0.3),      # negro puro, cuadrícula casi invisible
}
ESPECIALES = ("retrowave",)                        # fondos con dibujo propio (ver retrowave())

# Retrowave: cielo violeta→magenta, sol con franjas detrás del logo, piso con grilla en perspectiva
RW_CIELO = ((10, 2, 34), (46, 6, 74), (190, 24, 120))   # arriba, medio, horizonte
RW_SOL = ((255, 214, 92), (255, 60, 150))               # arriba amarillo → abajo rosa
RW_PISO = (8, 2, 26)
RW_GRILLA = (255, 46, 170)
HORIZONTE = 1340


def fondo(bg, grid, glow):
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)
    step = 80
    for x in range(0, W, step):
        d.line([(x, 0), (x, H)], fill=grid, width=2)
    for y in range(0, H, step):
        d.line([(0, y), (W, y)], fill=grid, width=2)
    # la cuadrícula se desvanece hacia los bordes (viñeta) para no cansar la vista
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse((-W * 0.1, -H * 0.3, W * 1.1, H * 1.3), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(500))
    im = Image.composite(im, Image.new("RGB", (W, H), bg), mask)

    # halos de color de la marca: cian detrás del logo, violeta abajo a la derecha
    for (cx, cy, r, col, a) in ((960, 1080, 900, CYAN, 70), (3300, 1900, 1100, VIOLET, 55)):
        layer = Image.new("RGB", (W, H), col)
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(a * glow))
        im = Image.composite(layer, im, m.filter(ImageFilter.GaussianBlur(r * 0.6)))
    return im


def degradado_v(y0, y1, colores):
    """Imagen W x (y1-y0) con degradado vertical entre varios colores."""
    im = Image.new("RGB", (W, y1 - y0))
    d = ImageDraw.Draw(im)
    n = len(colores) - 1
    for y in range(y1 - y0):
        t = y / max(1, y1 - y0 - 1) * n
        i = min(int(t), n - 1)
        f = t - i
        c = tuple(int(colores[i][k] * (1 - f) + colores[i + 1][k] * f) for k in range(3))
        d.line([(0, y), (W, y)], fill=c)
    return im


def retrowave():
    im = Image.new("RGB", (W, H), RW_PISO)
    im.paste(degradado_v(0, HORIZONTE, RW_CIELO), (0, 0))

    # estrellas tenues en la parte alta del cielo
    import random
    rnd = random.Random(7)
    d = ImageDraw.Draw(im)
    for _ in range(260):
        x, y = rnd.randrange(W), rnd.randrange(int(HORIZONTE * 0.6))
        b = rnd.randrange(90, 220)
        r = rnd.choice((1, 1, 2, 3))
        d.ellipse((x - r, y - r, x + r, y + r), fill=(b, b, min(255, b + 30)))

    # sol detrás del logo, apoyado en el horizonte, con franjas en la mitad de abajo
    cx, cy, r = W // 2, 960, 560
    sol = degradado_v(cy - r, cy + r, RW_SOL)
    m = Image.new("L", (2 * r, 2 * r), 0)
    md = ImageDraw.Draw(m)
    md.ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=255)
    y, alto = r + 20, 10
    while y < 2 * r:
        md.rectangle((0, y, 2 * r, y + alto), fill=0)
        y += alto + 34
        alto += 7
    tope = HORIZONTE - (cy - r)
    md.rectangle((0, tope, 2 * r, 2 * r), fill=0)
    # resplandor rosa alrededor del sol
    halo = Image.new("L", (W, H), 0)
    ImageDraw.Draw(halo).ellipse((cx - r - 120, cy - r - 120, cx + r + 120, cy + r + 120), fill=150)
    halo = halo.filter(ImageFilter.GaussianBlur(160))
    ImageDraw.Draw(halo).rectangle((0, HORIZONTE, W, H), fill=0)
    im = Image.composite(Image.new("RGB", (W, H), (255, 50, 140)), im, halo)
    im.paste(sol.crop((cx - r, 0, cx + r, 2 * r)), (cx - r, cy - r), m)

    # piso: grilla en perspectiva (líneas que fugan al centro + horizontales cada vez más juntas)
    piso = Image.new("RGB", (W, H - HORIZONTE), RW_PISO)
    pd = ImageDraw.Draw(piso)
    ph = H - HORIZONTE
    for i in range(-24, 25):
        x_abajo = cx + i * 300
        pd.line([(cx + i * 22, 0), (x_abajo, ph)], fill=RW_GRILLA, width=3)
    for k in range(60):                    # filas equiespaciadas en profundidad → y = ph / z
        yy = int(ph / (1 + k * 0.32))
        if yy < 4:
            break
        pd.line([(0, yy), (W, yy)], fill=RW_GRILLA, width=3 if yy > ph * 0.3 else 2)
    # la grilla se apaga cerca del horizonte (niebla)
    niebla = degradado_v(0, ph, ((170, 170, 170), (40, 40, 40), (0, 0, 0))).convert("L")
    piso = Image.composite(Image.new("RGB", piso.size, (60, 8, 70)), piso, niebla)
    im.paste(piso, (0, HORIZONTE))
    # línea del horizonte brillante
    linea = Image.new("L", (W, H), 0)
    ImageDraw.Draw(linea).rectangle((0, HORIZONTE - 3, W, HORIZONTE + 3), fill=255)
    im = Image.composite(Image.new("RGB", (W, H), (255, 120, 210)),
                         im, linea.filter(ImageFilter.GaussianBlur(6)))
    # oscurecer detrás del texto para que se lea
    sombra = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sombra).rectangle((cx - 760, HORIZONTE + 10, cx + 760, HORIZONTE + 330), fill=170)
    sombra = sombra.filter(ImageFilter.GaussianBlur(70))
    im = Image.composite(Image.new("RGB", (W, H), RW_PISO), im, sombra)
    return im


def texto_espaciado(d, xy_centro, txt, font, fill, espacio):
    anchos = [d.textlength(c, font=font) for c in txt]
    total = sum(anchos) + espacio * (len(txt) - 1)
    x = xy_centro[0] - total / 2
    for c, w in zip(txt, anchos):
        d.text((x, xy_centro[1]), c, font=font, fill=fill, anchor="lm")
        x += w + espacio


def marca(im):
    cx = W // 2                        # centro exacto de la pantalla (horizontal)
    logo = Image.open(LOGO).convert("RGBA")
    lh = 760
    logo = logo.resize((lh, lh), Image.LANCZOS)
    ly = 1080 - 560
    # brillo del logo
    # con margen: si no, el desenfoque se corta en el borde del logo y se ve un recuadro
    pad = 160
    alfa = Image.new("L", (lh + 2 * pad, lh + 2 * pad), 0)
    alfa.paste(logo.getchannel("A").point(lambda a: a * 0.55), (pad, pad))
    glow = Image.new("RGBA", alfa.size, CYAN + (0,))
    glow.putalpha(alfa.filter(ImageFilter.GaussianBlur(40)))
    im.paste(glow, (cx - lh // 2 - pad, ly - pad), glow)
    im.paste(logo, (cx - lh // 2, ly), logo)

    # "NIRI" con degradado cian -> violeta
    big = ImageFont.truetype(str(FONTS / "Montserrat-Bold.ttf"), 210)
    y = ly + lh + 130
    m = Image.new("L", (W, H), 0)
    texto_espaciado(ImageDraw.Draw(m), (cx, y), TITULO, big, 255, 60)
    grad = Image.new("RGB", (W, H))
    gd = ImageDraw.Draw(grad)
    x0, x1 = cx - 420, cx + 420
    for x in range(x0, x1):
        t = (x - x0) / (x1 - x0)
        gd.line([(x, 0), (x, H)], fill=tuple(int(CYAN[i] * (1 - t) + VIOLET[i] * t) for i in range(3)))
    gd.rectangle((0, 0, x0, H), fill=CYAN)
    gd.rectangle((x1, 0, W, H), fill=VIOLET)
    halo = Image.new("RGB", (W, H), CYAN)
    im.paste(halo, (0, 0), m.filter(ImageFilter.GaussianBlur(28)).point(lambda a: a * 0.5))
    im.paste(grad, (0, 0), m)

    small = ImageFont.truetype(str(FONTS / "Montserrat-Medium.ttf"), 54)
    texto_espaciado(ImageDraw.Draw(im), (cx, y + 190), LEMA, small, (180, 192, 220), 14)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for nombre, (bg, grid, glow) in VARIANTES.items():
        im = marca(fondo(bg, grid, glow))
        dst = OUT / f"maospix-{EDICION}-{nombre}.png"
        im.save(dst, optimize=True)
        print(dst)
    for nombre in ESPECIALES:
        im = marca(globals()[nombre]())
        dst = OUT / f"maospix-{EDICION}-{nombre}.png"
        im.save(dst, optimize=True)
        print(dst)


if __name__ == "__main__":
    main()
