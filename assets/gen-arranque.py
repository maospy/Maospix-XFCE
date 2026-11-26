#!/usr/bin/env python3
"""Fondos del menú de arranque del live (isolinux 640x480 y GRUB 800x600).

Uso: python3 assets/gen-arranque.py   (Montserrat en MAOSPIX_FONTS)
Salida: config/bootloaders/maospix/splash-640.png y splash-800.png
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/branding/maospix-logo-neon.png"
FONTS = Path(os.environ.get("MAOSPIX_FONTS", "/usr/share/fonts/truetype/montserrat"))
OUT = ROOT / "config/bootloaders/maospix"
BG, GRID = (15, 21, 36), (26, 35, 56)
CYAN, VIOLET = (79, 216, 232), (179, 147, 245)


def splash(w, h, logo_h, logo_y, text_y):
    im = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(im)
    for x in range(0, w, 32):
        d.line([(x, 0), (x, h)], fill=GRID)
    for y in range(0, h, 32):
        d.line([(0, y), (w, y)], fill=GRID)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * .1, -h * .3, w * 1.1, h * 1.3), fill=255)
    im = Image.composite(im, Image.new("RGB", (w, h), BG), mask.filter(ImageFilter.GaussianBlur(w / 8)))
    for (cx, cy, r, col, a) in ((w / 2, logo_y + logo_h / 2, w / 3, CYAN, 55), (w * .9, h * .95, w / 2.5, VIOLET, 45)):
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=a)
        im = Image.composite(Image.new("RGB", (w, h), col), im, m.filter(ImageFilter.GaussianBlur(r * .6)))
    logo = Image.open(LOGO).convert("RGBA").resize((logo_h, logo_h), Image.LANCZOS)
    glow = Image.new("RGBA", logo.size, CYAN + (0,))
    glow.putalpha(logo.getchannel("A").point(lambda a: a * .5))
    glow = glow.filter(ImageFilter.GaussianBlur(logo_h / 18))
    x = (w - logo_h) // 2
    im.paste(glow, (x, logo_y), glow)
    im.paste(logo, (x, logo_y), logo)
    f = ImageFont.truetype(str(FONTS / "Montserrat-Medium.ttf"), max(13, w // 46))
    d = ImageDraw.Draw(im)
    d.text((w / 2, text_y), "D E B I A N   ·   X F C E   ·   L I B R E", font=f, fill=(150, 165, 195), anchor="mm")
    return im


OUT.mkdir(parents=True, exist_ok=True)
# isolinux: el menú ocupa desde ~y=210 (menu vshift 13); logo arriba
splash(640, 480, 150, 22, 190).save(OUT / "splash-640.png", optimize=True)
# GRUB: el menú arranca en 52% (y=312)
splash(800, 600, 210, 30, 268).save(OUT / "splash-800.png", optimize=True)
print("OK", OUT)
