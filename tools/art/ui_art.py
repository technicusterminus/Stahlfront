"""Materialtexturen fuer die Fraktionsoberflaechen (Bildmodell), nahtlos gemacht und abgedunkelt.

Aufruf:  python tools/art/ui_art.py
Legt models/ui/<fraktion>_material.png (512 px, kachelbar) ab. Rahmen, Nieten und Naehte zeichnet scripts/ui_theme.gd
weiterhin im Code darueber; das Bild liefert nur die Oberflaeche (Glas, Stahl, Leder).
"""
import io, os, sys
from PIL import Image, ImageEnhance, ImageChops, ImageFilter, ImageStat
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import resource_art as ra
import resource_textures as rt

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "models", "ui")
MODEL = "black-forest-labs/flux.2-pro"
STYLE = " Seamless tileable flat material texture, top-down orthographic, evenly lit, no perspective, no objects, no text, no logo, low contrast, subtle detail."
JOBS = {
    "west": "Dark navy blue smoked glass over fine brushed titanium, faint diagonal micro-scratches, very subtle hexagonal micro pattern.",
    "red": "Uniform dark gunmetal steel, fine even brushed grain over the whole surface, faint speckled wear, perfectly even illumination, industrial.",
    "shadow": "Dark brown oiled saddle leather, natural fine grain, faint creases and scratches, aged and handmade.",
}


def flatten(img, radius=48):
    """Grobe Helligkeitsverlaeufe entfernen (Licht im Quellbild, Ueberblendnaehte): nur das Feinkorn bleibt."""
    big = Image.new("RGB", (img.size[0] * 3, img.size[1] * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * img.size[0], j * img.size[1]))
    low = big.filter(ImageFilter.GaussianBlur(radius)).crop((img.size[0], img.size[1], img.size[0] * 2, img.size[1] * 2))
    mean = tuple(int(v) for v in ImageStat.Stat(img).mean)
    return ImageChops.add(ImageChops.subtract(img, low, 1.0, 128), Image.new("RGB", img.size, mean), 1.0, -128)


def main():
    os.makedirs(OUT, exist_ok=True)
    key = ra.api_key()
    for fid, prompt in JOBS.items():
        path = os.path.join(OUT, fid + "_material.png")
        if os.path.exists(path):
            continue
        png, cost = ra.generate(key, MODEL, prompt + STYLE, "1:1")
        img = Image.open(io.BytesIO(png)).convert("RGB").resize((512, 512), Image.LANCZOS)
        img = flatten(rt.seamless(img))
        img = ImageEnhance.Contrast(img).enhance(0.8)
        img.save(path)
        print("ok", fid, "Kosten", cost)


if __name__ == "__main__":
    if "--flatten" in sys.argv:
        for fid in JOBS:
            pth = os.path.join(OUT, fid + "_material.png")
            flatten(Image.open(pth).convert("RGB")).save(pth)
    else:
        main()
