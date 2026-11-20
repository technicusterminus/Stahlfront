"""Texturen für Siedlungen und Landschaften (Beton, Backstein, Glas, Asphalt ...) mit einem Bildmodell erzeugen und kachelbar machen.

Aufruf:  python tools/art/biome_art.py [--only id]
Liest tools/art/biome_prompts.json, ruft das Bildmodell auf (Schlüssel aus einer Umgebungsvariable, nie ausgegeben), legt die Rohbilder unter
models/source/biome/<id>.png ab (vorhandene werden übersprungen) und erzeugt daraus mit resource_textures die Spieltexturen
models/resources/<id>_albedo.png und <id>_normal.png.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import resource_art as ra
import resource_textures as rt

ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(ROOT, "models", "source", "biome")


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    spec = json.load(open(os.path.join(HERE, "biome_prompts.json"), encoding="utf-8"))
    os.makedirs(SRC, exist_ok=True)
    prov_path = os.path.join(SRC, "provenance.json")
    prov = json.load(open(prov_path, encoding="utf-8")) if os.path.exists(prov_path) else []
    key = ra.api_key()
    ids = []
    for img in spec["images"]:
        if only and img["id"] != only:
            continue
        ids.append(img["id"])
        path = os.path.join(SRC, img["id"] + ".png")
        if os.path.exists(path):
            continue
        png, cost = ra.generate(key, spec["model"], img["prompt"], img["aspect_ratio"])
        open(path, "wb").write(png)
        prov.append({"id": img["id"], "model": spec["model"], "cost": cost})
        json.dump(prov, open(prov_path, "w", encoding="utf-8"), indent=2)
        print("ok", img["id"], "Kosten", cost)
    rt.SRC = SRC
    rt.TILES = ids
    rt.SINGLE = []
    rt.main()


if __name__ == "__main__":
    main()
