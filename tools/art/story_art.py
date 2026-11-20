"""Figurenporträts und Standbilder der Filmsequenzen mit einem Bildmodell erzeugen.

Aufruf:  python tools/art/story_art.py [--only id] [--portraits | --stills]
Liest tools/art/story_prompts.json, ruft das Bildmodell auf (Schlüssel aus einer Umgebungsvariable, nie ausgegeben) und legt
die Bilder unter models/story/<id>.png ab. Vorhandene Bilder werden übersprungen; Kosten stehen in models/story/provenance.json.
Porträts 1:1, Standbilder 16:9. Danach einmal 'godot --import' ausführen.
"""
import io, json, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import resource_art as ra

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "models", "story")


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    want_p = "--stills" not in sys.argv
    want_s = "--portraits" not in sys.argv
    spec = json.load(open(os.path.join(HERE, "story_prompts.json"), encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    prov_path = os.path.join(OUT, "provenance.json")
    prov = json.load(open(prov_path, encoding="utf-8")) if os.path.exists(prov_path) else []
    key = ra.api_key()
    jobs = []
    if want_p:
        jobs += [(i["id"], spec["portrait_style"] + " " + i["prompt"], "1:1") for i in spec["portraits"]]
    if want_s:
        jobs += [(i["id"], i["prompt"] + " " + spec["still_style"], "16:9") for i in spec["stills"]]
    total = 0.0
    for id_, prompt, aspect in jobs:
        if only and id_ != only:
            continue
        path = os.path.join(OUT, id_ + ".jpg")
        if os.path.exists(path):
            continue
        png, cost = ra.generate(key, spec["model"], prompt, aspect)
        im = Image.open(io.BytesIO(png)).convert("RGB")
        im.thumbnail((512, 512) if aspect == "1:1" else (1600, 900), Image.LANCZOS)
        im.save(path, "JPEG", quality=90)
        prov.append({"id": id_, "model": spec["model"], "cost": cost})
        json.dump(prov, open(prov_path, "w", encoding="utf-8"), indent=2)
        total += float(cost or 0)
        print("ok", id_, os.path.getsize(path) // 1024, "KB", "Kosten", cost, flush=True)
    print("Summe", round(total, 3))


if __name__ == "__main__":
    main()
