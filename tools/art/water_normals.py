"""Wellen-Normalkarten neu aus den nahtlosen Wassertexturen berechnen, mit umlaufendem Rand (kein Raster an den Kachelkanten).

Aufruf:  python tools/art/water_normals.py
Liest models/water/<id>_albedo.png und schreibt models/water/<id>_normal.png. Die alte Berechnung filterte ohne Umlauf,
dadurch lag an jeder Kachelkante eine falsche Zeile: im Spiel als Gitter aus Kreuzen auf dem Wasser sichtbar.
"""
import os
from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DST = os.path.join(ROOT, "models", "water")


def normal_wrapped(img: Image.Image, strength: float) -> Image.Image:
    g = img.convert("L")
    n = g.size[0]
    big = Image.new("L", (n * 3, n * 3))
    for i in range(3):
        for j in range(3):
            big.paste(g, (i * n, j * n))
    h = big.filter(ImageFilter.GaussianBlur(1.6)).crop((n, n, 2 * n, 2 * n))
    dx = ImageChops.subtract(ImageChops.offset(h, -1, 0), ImageChops.offset(h, 1, 0), 1.0, 128)
    dy = ImageChops.subtract(ImageChops.offset(h, 0, -1), ImageChops.offset(h, 0, 1), 1.0, 128)
    dx = dx.point(lambda v: max(0, min(255, int(128 - (v - 128) * strength))))
    dy = dy.point(lambda v: max(0, min(255, int(128 + (v - 128) * strength))))
    return Image.merge("RGB", (dx, dy, Image.new("L", h.size, 235)))


def main():
    for name, strength in (("water_ripple", 5.0), ("water_swell", 4.0)):
        src = Image.open(os.path.join(DST, name + "_albedo.png"))
        normal_wrapped(src, strength).save(os.path.join(DST, name + "_normal.png"))
        print("ok", name)


if __name__ == "__main__":
    main()
