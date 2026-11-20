"""Wassertexturen (Wellen, Schaum, Kaustik) mit einem Bildmodell erzeugen und kachelbar machen.

Aufruf:  python tools/art/water_art.py
Schluessel aus der Umgebungsvariablen (nie ausgegeben). Rohbilder in models/source/water, Spieltexturen in models/water:
<id>_albedo.png (nahtlos) und fuer die Wellenbilder <id>_normal.png (Relief aus der Helligkeit).
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import resource_art as ra
import resource_textures as rt
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "models", "source", "water")
DST = os.path.join(ROOT, "models", "water")
MODEL = "black-forest-labs/flux.2-pro"
SUF = " Seamless tileable, flat orthographic top-down view, even lighting, no horizon, no objects, no text, fills the whole frame."
IMAGES = [
    ("water_ripple", True, "Top-down close-up of a calm lake surface with fine overlapping ripples and small wind waves, grey-blue monochrome, high contrast crests and troughs, like a height map." + SUF),
    ("water_swell", True, "Top-down view of broad rolling ocean swell and wave crests on dark water, large soft undulations with small ripples on top, grey-blue monochrome height-map look." + SUF),
    ("water_foam", False, "Top-down view of white sea foam lace and bubbles on dark teal water: irregular web of foam streaks and holes, bright white on dark, high contrast." + SUF),
    ("water_caustics", False, "Top-down underwater caustics light pattern: bright network of thin cyan-white light lines forming cells on a dark blue sandy lake bed, high contrast." + SUF),
]

def main():
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(DST, exist_ok=True)
    key = ra.api_key()
    for name, normal, prompt in IMAGES:
        path = os.path.join(SRC, name + ".png")
        if not os.path.exists(path):
            png, cost = ra.generate(key, MODEL, prompt, "1:1")
            open(path, "wb").write(png)
            print("ok", name, "Kosten", cost)
        img = Image.open(path).convert("RGB").resize((rt.SIZE, rt.SIZE), Image.LANCZOS)
        img = rt.seamless(img)
        img.save(os.path.join(DST, name + "_albedo.png"))
        if normal:
            rt.normal_from(img, 4.0).save(os.path.join(DST, name + "_normal.png"))

if __name__ == "__main__":
    main()
