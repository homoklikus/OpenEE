#!/usr/bin/env python3
"""Nagłówek launchera z grafiki referencyjnej: wycięcie, usunięcie podpisu, powiększenie ×2, podpisy PL/EN.
Użycie: python3 narzedzia/baner_launchera.py <grafika_referencyjna.png> [katalog_wyjscia=dane/launcher/grafika]
Wymaga: Pillow, numpy, opencv-python, czcionki DejaVu Sans."""
import sys, os
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OBSZAR = (220, 47, 1536, 201)        # nagłówek na grafice referencyjnej 1536×1024
PODPIS = (242, 520, 104, 134)        # x0, x1, y0, y1 (współrzędne wycinka)
LEWA, LINIA_BAZOWA, SZER_PL = 246, 124, 267
S = 2
CZCIONKA = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
PODTYTULY = {"pl": "Otwarty silnik Empire Earth", "en": "Open-source Empire Earth engine"}

src, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "dane/launcher/grafika")
os.makedirs(out, exist_ok=True)
a = np.array(Image.open(src).convert("RGB").crop(OBSZAR))
x0, x1, y0, y1 = PODPIS
mask = np.zeros(a.shape[:2], np.uint8)
m = (a[y0:y1, x0:x1].mean(axis=2) > 45).astype(np.uint8) * 255
mask[y0:y1, x0:x1] = cv2.dilate(m, np.ones((5, 5), np.uint8), iterations=2)
czysty = cv2.cvtColor(cv2.inpaint(cv2.cvtColor(a, cv2.COLOR_RGB2BGR), mask, 9, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
baza = Image.fromarray(czysty)
duzy = baza.resize((baza.width * S, baza.height * S), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 40, 2))
duzy.save(os.path.join(out, "baner_bez_podtytulu.png"))

rozm = next(s for s in range(60, 20, -1) if ImageFont.truetype(CZCIONKA, s).getbbox(PODTYTULY["pl"])[2] <= SZER_PL * S)
f = ImageFont.truetype(CZCIONKA, rozm)
for jez, tekst in PODTYTULY.items():
    img = duzy.copy().convert("RGBA")
    mk = Image.new("L", img.size, 0)
    ImageDraw.Draw(mk).text((LEWA * S, LINIA_BAZOWA * S - f.getmetrics()[0]), tekst, font=f, fill=255)
    cien = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cien.putalpha(mk.filter(ImageFilter.GaussianBlur(3)).point(lambda v: min(255, int(v * 1.3))))
    img.alpha_composite(cien, (2, 3))
    bb = mk.getbbox()
    g = np.zeros((img.height, img.width, 3), np.uint8)
    for yy in range(bb[1], bb[3]):
        t = (yy - bb[1]) / max(1, bb[3] - bb[1] - 1)
        g[yy, :] = np.array([255, 242, 190]) * (1 - t) + np.array([228, 176, 92]) * t
    gi = Image.fromarray(g).convert("RGBA"); gi.putalpha(mk)
    img.alpha_composite(gi)
    img.convert("RGB").save(os.path.join(out, f"baner_{jez}.png"))
print("zapisano", out, "czcionka", rozm)
