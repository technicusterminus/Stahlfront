"""Quellbilder der Rohstoffe (models/source/resources) in kachelbare Spieltexturen umwandeln (models/resources).

Aufruf:  python tools/art/resource_textures.py
Je Textur entstehen <id>_albedo.png (Farbe, 512 x 512, nahtlos überblendet) und <id>_normal.png (Relief aus der Helligkeit).
log_end (Stammschnittfläche) wird nicht kachelbar gemacht, nur verkleinert. Benötigt Pillow.
"""
import os
from PIL import Image, ImageChops, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "models", "source", "resources")
DST = os.path.join(ROOT, "models", "resources")
SIZE = 512
TILES = ["rock_iron", "rock_gold", "bark", "oil_sludge", "crate_wood", "rust_metal"]
SINGLE = ["log_end"]


def smooth_mask(size, horizontal):
    """Gewicht 0 in der Mitte, 1 an den Rändern (weicher Verlauf) für die Überblendung."""
    m = Image.new("L", (size, size))
    px = m.load()
    for y in range(size):
        for x in range(size):
            t = (x if horizontal else y) / (size - 1) * 2.0 - 1.0
            w = max(0.0, min(1.0, (abs(t) - 0.53) / 0.32))
            w = w * w * (3.0 - 2.0 * w)
            px[x, y] = int(w * 255)
    return m


def seamless(img):
    """Ränder mit einer um die halbe Kantenlänge versetzten Kopie überblenden: oben/unten und links/rechts passen nahtlos."""
    s = img.size[0]
    for horizontal in (True, False):
        shifted = ImageChops.offset(img, s // 2 if horizontal else 0, 0 if horizontal else s // 2)
        img = Image.composite(shifted, img, smooth_mask(s, horizontal))
    return img


def normal_from(img, strength=3.0):
    g = img.convert("L").filter(ImageFilter.GaussianBlur(1.1))
    kx = ImageFilter.Kernel((3, 3), (-1, 0, 1, -2, 0, 2, -1, 0, 1), scale=1, offset=128)
    ky = ImageFilter.Kernel((3, 3), (-1, -2, -1, 0, 0, 0, 1, 2, 1), scale=1, offset=128)
    dx = g.filter(kx).point(lambda v: max(0, min(255, int(128 + (v - 128) * strength / 4.0))))
    dy = g.filter(ky).point(lambda v: max(0, min(255, int(128 + (v - 128) * strength / 4.0))))
    dy = ImageChops.invert(dy)
    return Image.merge("RGB", (dx, dy, Image.new("L", g.size, 235)))


def main():
    os.makedirs(DST, exist_ok=True)
    for name in TILES:
        src = Image.open(os.path.join(SRC, name + ".png")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        tile = seamless(src)
        tile.save(os.path.join(DST, name + "_albedo.png"))
        normal_from(tile).save(os.path.join(DST, name + "_normal.png"))
        print("ok", name)
    for name in SINGLE:
        src = Image.open(os.path.join(SRC, name + ".png")).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        src.save(os.path.join(DST, name + "_albedo.png"))
        print("ok", name, "(einzeln)")


if __name__ == "__main__":
    main()
