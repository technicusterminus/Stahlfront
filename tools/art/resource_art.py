"""Entwürfe und Texturen für die Rohstoffvorkommen mit einem Bildmodell erzeugen.

Aufruf:  python tools/art/resource_art.py [--only id] [--test]
Liest die Prompts aus tools/art/resource_prompts.json, ruft das Bildmodell auf (Schlüssel aus einer Umgebungsvariable, nie ausgegeben)
und legt die Bilder unter models/source/resources/<id>.png ab. Vorhandene Bilder werden übersprungen. Die Kosten je Bild
stehen in models/source/resources/provenance.json. Danach: python tools/art/resource_textures.py (Kachelbarkeit, Größe, Ablage in models/resources).
"""
import base64, json, os, subprocess, sys, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "models", "source", "resources")
URL = "https://openrouter.ai/api/v1/images"


def api_key():
    k = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not k:
        try:
            k = subprocess.run(["powershell", "-NoProfile", "-Command", "[Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','User')"],
                               capture_output=True, text=True, timeout=20).stdout.strip()
        except Exception:
            k = ""
    if not k:
        sys.exit("API-Schlüssel fehlt (Umgebungsvariable).")
    return k


def generate(key, model, prompt, aspect):
    body = {"model": model, "prompt": prompt, "aspect_ratio": aspect, "output_format": "png", "n": 1}
    req = urllib.request.Request(URL, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=240) as r:
            data = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit("Fehler %d: %s" % (e.code, e.read().decode("utf-8", "replace")[:300]))
    item = (data.get("data") or [{}])[0]
    b64 = item.get("b64_json")
    if not b64 or not b64.startswith("iVBORw0KGgo"):
        sys.exit("Keine PNG-Daten in der Antwort: " + json.dumps(data)[:300])
    cost = (data.get("usage") or {}).get("cost")
    return base64.b64decode(b64), cost


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    test = "--test" in sys.argv
    spec = json.load(open(os.path.join(HERE, "resource_prompts.json"), encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    prov_path = os.path.join(OUT, "provenance.json")
    prov = json.load(open(prov_path, encoding="utf-8")) if os.path.exists(prov_path) else []
    key = api_key()
    for img in spec["images"]:
        if only and img["id"] != only:
            continue
        path = os.path.join(OUT, img["id"] + ".png")
        if os.path.exists(path):
            continue
        png, cost = generate(key, spec["model"], img["prompt"], img["aspect_ratio"])
        open(path, "wb").write(png)
        prov = [p for p in prov if p["Id"] != img["id"]]
        prov.append({"Id": img["id"], "Model": spec["model"], "CostUsd": cost})
        json.dump(prov, open(prov_path, "w", encoding="utf-8"), indent=2)
        print("ok", img["id"], len(png) // 1024, "KB", "Kosten", cost)
        if test:
            break


if __name__ == "__main__":
    main()
