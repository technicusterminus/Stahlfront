"""Sprachzeilen der Einheiten mit einem KI-Sprachmodell erzeugen (Modell openai/gpt-audio-mini, Ausgabe als Sprache).

Aufruf:  python tools/audio/make_voice.py [--only west] [--test]
  --test   erzeugt nur eine einzige Zeile zum Ausprobieren
Der Schlüssel kommt aus einer Umgebungsvariable (Name siehe api_key()) und wird nie ausgegeben.
Ergebnis: tools/audio/raw/<fraktion>/<art>_<n>.wav (24 kHz, 16 Bit, mono, ungefiltert) und raw/index.json.
Danach:  python tools/audio/process_voice.py   (Funkfilter, Zuschneiden, Ablage unter audio/voice)
"""
import base64, json, os, subprocess, sys, urllib.request, wave

MODEL = "openai/gpt-audio-mini"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

# Stimme und Sprechweise je Fraktion
STYLE = {
    "west": ("sage", "Kühl, präzise und professionell wie ein moderner Funker einer Hightech-Armee. Mittleres Tempo, klare Aussprache, kaum Emotion."),
    "red": ("ash", "Tief, streng und markig wie ein altgedienter Offizier. Langsam und gewichtig, mit leichtem slawischem Akzent im Deutschen."),
    "shadow": ("verse", "Rau, lässig und schelmisch wie ein Schmuggler. Schnell, leicht heiser, mit einem Grinsen in der Stimme."),
}

LINES = {
    "west": {
        "select": ["Einheit bereit.", "Bereit.", "Hier Falke, bereit.", "Warte auf Befehl.", "Sentinel meldet sich."],
        "move": ["Verstanden.", "Bin unterwegs.", "Positionswechsel.", "Kurs bestätigt.", "Wird ausgeführt."],
        "attack": ["Ziel erfasst.", "Feuer frei.", "Angriff läuft.", "Eröffne Feuer.", "Ziel anvisiert."],
        "air_move": ["Abflug bestätigt.", "Steige auf.", "Flugroute gesetzt."],
        "naval_move": ["Kurs gesetzt.", "Volle Fahrt voraus.", "Ruder liegt an."],
        "build": ["Bau beginnt.", "Wird errichtet.", "Baustelle übernommen."],
        "harvest": ["Nachschub unterwegs.", "Fahre zum Depot.", "Ladung wird geholt."],
    },
    "red": {
        "select": ["Zu Befehl, Genosse.", "Ich höre.", "Die Allianz ruft.", "Bereit zum Dienst.", "Jawohl."],
        "move": ["Jawohl, Genosse.", "Vorwärts.", "Wir marschieren.", "Für die Allianz.", "Verstanden."],
        "attack": ["Feuer.", "Für die Heimat.", "Zerschlagt sie.", "Angriff.", "Vernichten."],
        "air_move": ["Starte, Genosse.", "Wir steigen auf.", "Flugziel erhalten."],
        "naval_move": ["Kurs liegt an.", "Maschinen voraus.", "Volle Kraft."],
        "build": ["Wir bauen.", "Das Fundament wird gelegt.", "Arbeit beginnt."],
        "harvest": ["Nachschub kommt.", "Zum Depot, Genosse.", "Wir holen die Ladung."],
    },
    "shadow": {
        "select": ["Was gibt's?", "Ich bin dabei.", "Na los.", "Bin wach.", "Sag an."],
        "move": ["Alles klar.", "Wird gemacht.", "Auf geht's.", "Bin schon unterwegs.", "Schleichen wir los."],
        "attack": ["Das wird laut.", "Bedient euch.", "Zeit für Beute.", "Los jetzt.", "Draufhalten."],
        "air_move": ["Ab in die Luft.", "Wir fliegen tief.", "Kurs steht."],
        "naval_move": ["Segel gesetzt.", "Ab aufs Wasser.", "Wir legen ab."],
        "build": ["Wird zusammengenagelt.", "Ich leg los.", "Aus Schrott wird ein Haus."],
        "harvest": ["Beute holen.", "Ich fahr hin.", "Ladung wird geklaut."],
    },
}


def api_key():
    k = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not k:
        try:
            k = subprocess.run(
                ["powershell", "-NoProfile", "-Command", "[Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','User')"],
                capture_output=True, text=True, timeout=20).stdout.strip()
        except Exception:
            k = ""
    if not k:
        sys.exit("OPENROUTER_API_KEY fehlt.")
    return k


def speak(key, voice, style, text):
    """Eine Zeile als PCM16 (24 kHz, mono) holen: Chat-Anfrage mit Audio-Ausgabe, als Stream gelesen."""
    body = {
        "model": MODEL,
        "stream": True,
        "modalities": ["text", "audio"],
        "audio": {"voice": voice, "format": "pcm16"},
        "messages": [
            {"role": "system", "content": "Du bist eine reine Vorlese-Maschine für Spielfiguren. Du sprichst ausschließlich den Text, den der Nutzer in Anführungszeichen nennt, Wort für Wort. Du antwortest nie selbst, erklärst nichts und ergänzt keine Wörter."},
            {"role": "user", "content": "Lies exakt diesen einen Text laut vor, kein Wort davor, kein Wort danach, keine Wiederholung: „" + text + "“\nSprechweise: " + style},
        ],
    }
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST")
    pcm = bytearray()
    speak.transcript = ""
    with urllib.request.urlopen(req, timeout=120) as r:
        for raw in r:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if payload == "[DONE]":
                break
            try:
                obj = json.loads(payload)
            except ValueError:
                continue
            for ch in obj.get("choices", []):
                a = (ch.get("delta") or {}).get("audio") or {}
                if a.get("data"):
                    pcm += base64.b64decode(a["data"])
                if a.get("transcript"):
                    speak.transcript += a["transcript"]
    return bytes(pcm)


def _norm(t):
    return "".join(c for c in t.lower() if c.isalnum())


def _same(got, want):
    g, w = _norm(got), _norm(want)
    return bool(g) and (g == w or (w in g and len(g) <= len(w) + 6))


def save_wav(path, pcm, rate=24000):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)


def main():
    only = None
    test = "--test" in sys.argv
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
    key = api_key()
    index = {}
    done = 0
    for f, kinds in LINES.items():
        if only and f != only:
            continue
        voice, style = STYLE[f]
        os.makedirs(os.path.join(RAW, f), exist_ok=True)
        index[f] = {}
        for kind, texts in kinds.items():
            n = 0
            for i, text in enumerate(texts):
                path = os.path.join(RAW, f, "%s_%d.wav" % (kind, i))
                if not os.path.exists(path):
                    pcm = b""
                    for attempt in range(4):
                        pcm = speak(key, voice, style, text)
                        if len(pcm) >= 2000 and _same(speak.transcript, text):
                            break
                        print("  Abweichung, neuer Versuch:", repr(speak.transcript))
                        pcm = b""
                    if not pcm:
                        print("Keine brauchbaren Audiodaten für", f, kind, i, text)
                        continue
                    save_wav(path, pcm)
                    print("ok", f, kind, i, "%.2f s" % (len(pcm) / 2 / 24000.0), text, "| gesprochen:", speak.transcript)
                n += 1
                done += 1
                if test:
                    break
            index[f][kind] = n
            if test:
                break
        if test:
            break
    if not test:
        old = {}
        p = os.path.join(RAW, "index.json")
        if os.path.exists(p):
            old = json.load(open(p, encoding="utf-8"))
        old.update(index)
        json.dump(old, open(p, "w", encoding="utf-8"), indent=1)
    print("Fertig:", done, "Zeilen")


if __name__ == "__main__":
    main()
