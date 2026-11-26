#!/usr/bin/env python3
"""Imágenes del branding de Calamares (instalador) maospix.

Uso: python3 assets/gen-calamares.py   (Montserrat en MAOSPIX_FONTS)
Salida: config/includes.chroot_after_packages/etc/calamares/branding/maospix/
  maospix-logo.png (256x256), welcome.png (600x340), slide1..3.png (800x440)
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/branding/maospix-logo-neon.png"
FONTS = Path(os.environ.get("MAOSPIX_FONTS", "/usr/share/fonts/truetype/montserrat"))
OUT = ROOT / "config/includes.chroot_after_packages/etc/calamares/branding/maospix"
BG, GRID = (15, 21, 36), (24, 33, 53)
CYAN, VIOLET, TEXT, DIM = (79, 216, 232), (179, 147, 245), (226, 232, 245), (150, 165, 195)


def font(peso, tam):
    return ImageFont.truetype(str(FONTS / f"Montserrat-{peso}.ttf"), tam)


def fondo(w, h, brillos):
    """Navy con grilla suave y manchas de luz cian/violeta."""
    im = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(im)
    for x in range(0, w, 32):
        d.line([(x, 0), (x, h)], fill=GRID)
    for y in range(0, h, 32):
        d.line([(0, y), (w, y)], fill=GRID)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * .1, -h * .3, w * 1.1, h * 1.3), fill=255)
    im = Image.composite(im, Image.new("RGB", (w, h), BG), mask.filter(ImageFilter.GaussianBlur(w / 8)))
    for (cx, cy, r, col, a) in brillos:
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=a)
        im = Image.composite(Image.new("RGB", (w, h), col), im, m.filter(ImageFilter.GaussianBlur(r * .6)))
    return im


def logo(tam):
    lg = Image.open(LOGO).convert("RGBA").resize((tam, tam), Image.LANCZOS)
    glow = Image.new("RGBA", lg.size, CYAN + (0,))
    glow.putalpha(lg.getchannel("A").point(lambda a: a * .5))
    return lg, glow.filter(ImageFilter.GaussianBlur(tam / 18))


def pegar_logo(im, tam, x, y):
    lg, glow = logo(tam)
    im.paste(glow, (x, y), glow)
    im.paste(lg, (x, y), lg)


def slide(titulo, lineas, acento):
    w, h = 800, 440
    im = fondo(w, h, ((150, 220, 260, CYAN, 50), (w * .9, h * .95, 320, acento, 45)))
    pegar_logo(im, 190, 55, 125)
    d = ImageDraw.Draw(im)
    d.text((290, 120), titulo, font=font("SemiBold", 34), fill=TEXT)
    d.line([(292, 172), (380, 172)], fill=acento, width=4)
    y = 200
    for ln in lineas:
        d.ellipse((294, y + 9, 302, y + 17), fill=acento)
        d.text((316, y), ln, font=font("Medium", 19), fill=DIM)
        y += 38
    return im


OUT.mkdir(parents=True, exist_ok=True)

# Logo (ícono de ventana y barra lateral)
lg, glow = logo(256)
ic = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
ic.alpha_composite(glow)
ic.alpha_composite(lg)
ic.save(OUT / "maospix-logo.png", optimize=True)

# Bienvenida
w, h = 600, 340
im = fondo(w, h, ((w / 2, 130, 200, CYAN, 55), (w * .9, h, 240, VIOLET, 40)))
pegar_logo(im, 210, (w - 210) // 2, 18)
d = ImageDraw.Draw(im)
d.text((w / 2, 262), "maospix XFCE", font=font("SemiBold", 34), fill=TEXT, anchor="mm")
d.text((w / 2, 302), "D E B I A N   ·   X F C E   ·   L I B R E", font=font("Medium", 14), fill=DIM, anchor="mm")
im.save(OUT / "welcome.png", optimize=True)

# Diapositivas mientras instala
slide("Bienvenido a maospix", ["Debian + XFCE, moderno y liviano.",
                               "Pensado también para PCs viejas.",
                               "La instalación sigue sola: son unos minutos."], CYAN).save(OUT / "slide1.png", optimize=True)
slide("Todo listo para usar", ["Brave, kitty, Thunar, mpv y más.",
                               "Shell fish con fastfetch.",
                               "Tema oscuro maospix en todo el sistema."], VIOLET).save(OUT / "slide2.png", optimize=True)
slide("Hecho en Paraguay", ["Español de Paraguay por defecto.",
                            "Teclado latinoamericano y hora de Asunción.",
                            "Software libre: github.com/maospy"], CYAN).save(OUT / "slide3.png", optimize=True)
print("OK", OUT)
