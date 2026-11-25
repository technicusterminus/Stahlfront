"""Fotorealistische Einzelbilder für Rauch und Feuer (Bildmodell) zu Partikel-Bildbögen verarbeiten.

Aufruf:  python tools/art/fx_art.py            (erzeugt fehlende Quellbilder, baut die Bögen neu)
         python tools/art/fx_art.py --build    (nur Bögen aus vorhandenen Quellbildern bauen)
Quellen: models/source/fx/<art>_<n>.png (vor schwarzem Hintergrund)
Bögen:   models/fx/smoke_atlas.png  – 2×2 Rauchwolken, weiß mit Transparenz aus der Helligkeit (Farbe kommt im Spiel dazu)
         models/fx/fire_atlas.png   – 2×2 Feuerbälle, farbig auf Schwarz (für additive Mischung) mit weichem Rand
"""
import io, os, sys
from PIL import Image, ImageChops, ImageFilter, ImageOps, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import resource_art as ra

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "models", "source", "fx")
OUT = os.path.join(ROOT, "models", "fx")
MODEL = "black-forest-labs/flux.2-pro"
BASE = (" Isolated in the exact center on a pure black background, nothing else in the image, the whole element fully visible with "
        "empty black margin on all sides, photorealistic VFX element photographed for a game particle texture, no text.")
JOBS = {
    "smoke": [
        "A single dense billowing puff of grey smoke, soft volumetric cauliflower shape, lit from above.",
        "A single round cloud of thick dark grey battlefield smoke, wispy soft edges.",
        "A single irregular puff of light grey dust and smoke, soft and diffuse.",
        "A single rolling ball of grey smoke with curling billows, volumetric.",
    ],
    "fire": [
        "A single compact fireball explosion, bright orange and yellow flames with dark red edges.",
        "A single burst of fire with licking orange flames, compact and round.",
        "A single ball of burning gasoline fire, deep orange with bright yellow core.",
        "A single fiery explosion cloud, orange flame turning to red, compact.",
    ],
}


def fetch():
    os.makedirs(SRC, exist_ok=True)
    key = ra.api_key()
    total = 0.0
    for kind, prompts in JOBS.items():
        for i, p in enumerate(prompts):
            path = os.path.join(SRC, "%s_%d.png" % (kind, i))
            if os.path.exists(path):
                continue
            png, cost = ra.generate(key, MODEL, p + BASE, "1:1")
            Image.open(io.BytesIO(png)).convert("RGB").save(path)
            total += cost or 0.0
            print("ok", kind, i, cost)
    print("Kosten", round(total, 3))


def radial_mask(size, inner=0.62, outer=0.98):
    """Weicher Kreis: garantiert, dass nichts am Kachelrand hart abschneidet."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    steps = 40
    for k in range(steps):
        t = k / (steps - 1)
        r = outer - (outer - inner) * t
        v = int(255 * t)
        rr = r * size / 2
        d.ellipse((size / 2 - rr, size / 2 - rr, size / 2 + rr, size / 2 + rr), fill=v)
    return m.filter(ImageFilter.GaussianBlur(size / 40))


def tile(kind, img, size=512):
    img = img.resize((size, size), Image.LANCZOS)
    lum = ImageOps.grayscale(img)
    # schwarzer Hintergrund -> durchsichtig; leicht anheben, damit dünner Rauch nicht verschwindet
    # Deckung aus der Helligkeit, kräftig angehoben: dünner Rauch bleibt sichtbar, dichter Rauch deckt voll
    gain = 3.2 if kind == "smoke" else 2.6
    a = lum.point(lambda v: 0 if v < 6 else min(255, int(((v - 6) / 249.0) ** 0.7 * 255 * gain)))
    a = ImageChops.multiply(a, radial_mask(size, 0.7, 0.99))
    if kind == "smoke":
        # Farbe neutral hell, die Helligkeitsstruktur (Licht und Schatten der Wolke) bleibt in RGB erhalten
        shade = lum.point(lambda v: min(255, int(110 + v * 0.75)))
        rgb = Image.merge("RGB", (shade, shade, shade))
        return Image.merge("RGBA", (*rgb.split(), a))
    # Feuer: Farbe behalten, Rand weich auslaufen lassen (für additive Mischung zählt RGB)
    faded = Image.composite(img, Image.new("RGB", img.size, (0, 0, 0)), radial_mask(size))
    return Image.merge("RGBA", (*faded.split(), a))


def build():
    os.makedirs(OUT, exist_ok=True)
    for kind in JOBS:
        atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        for i in range(4):
            src = Image.open(os.path.join(SRC, "%s_%d.png" % (kind, i))).convert("RGB")
            atlas.paste(tile(kind, src), ((i % 2) * 512, (i // 2) * 512))
        atlas.save(os.path.join(OUT, "%s_atlas.png" % kind))
        print("Bogen", kind)


if __name__ == "__main__":
    if "--build" not in sys.argv:
        fetch()
    build()
