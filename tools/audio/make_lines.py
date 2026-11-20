"""Gesprochene Funkzeilen der Missionen: Stimme und Gefühlslage je Sprecher, Ablage unter audio/lines/<hash>.wav.

Aufruf:  python tools/audio/make_lines.py [--test]
Liest alle radio("Sprecher", C_FARBE, "Text", ...) aus scripts/missions.gd, erzeugt jede Zeile mit dem KI-Sprachmodell
(Stimme und Regieanweisung aus CHARACTERS und EMOTIONS), schneidet zu, legt je nach Sprecher einen Funk- oder KI-Klang darüber
und speichert die Datei unter dem Hash des Textes. Das Spiel sucht die Aufnahme über denselben Hash (Audio.line).
Bereits vorhandene Aufnahmen werden übersprungen; ändert sich ein Text, entsteht beim nächsten Lauf eine neue Datei.
"""
import hashlib, math, os, random, re, struct, sys, wave

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import make_voice as mv
import process_voice as pv

MISSIONS = os.path.join(ROOT, "scripts", "missions.gd")
RAW = os.path.join(HERE, "raw", "lines")
OUT = os.path.join(ROOT, "audio", "lines")

# Sprecher -> (Stimme, Grundton der Rolle)
CHARACTERS = {
    "Ausbilderin Vogt": ("nova", "Warme, ermutigende Ausbilderin mit klarer Stimme, freundlich-professionell."),
    "Elin Voss": ("marin", "Kontrollierte Strategin Mitte vierzig, ruhig und müde, aber entschlossen; unter der Ruhe liegt Last."),
    "Falke": ("onyx", "Lässiger, selbstbewusster Kampfpilot, schnell, ein Grinsen in der Stimme, Adrenalin und Motorenlärm."),
    "Mira Tanaka": ("shimmer", "Wortkarge Scharfschützin, leise, trocken, präzise; spricht nur, wenn es zählt."),
    "ORAKEL": ("alloy", "Sanfte, vollkommen gleichmäßige KI-Stimme ohne Gefühl, unheimlich ruhig und höflich."),
    "Lena Voss": ("ballad", "Kämpferin Anfang vierzig, warm und eindringlich, mit unterdrückter Verzweiflung und Schwesterliebe."),
    "Dr. Brandt": ("fable", "Nachdenklicher Wissenschaftler, nervös, höflich, ungläubig."),
    "Henrik Aldane": ("ash", "Autoritärer Ratspräsident, glatt, bestimmt, keine Widerrede duldend."),
    "Mutter Karga": ("sage", "Uralte, raue, weise Frau, langsam und warm, ein halbes Lächeln in der Stimme."),
    "Hauptmann Reyes": ("echo", "Energischer Küstenwache-Hauptmann, funkt über Motorenlärm, zuversichtlich und knapp."),
}

# Stichwort im Text -> Regieanweisung (erste Übereinstimmung gewinnt)
EMOTIONS = [
    ("Falke an Basis", "Frech und gelassen, voller Vorfreude."),
    ("Flak-Radar erfasst", "Gespielt locker, doch mit echtem Stress im Atem; presst die Worte zwischen den Manövern hervor."),
    ("Das ist komisch", "Leise, verstört, bemüht sachlich; sucht nach Worten."),
    ("Zurückgehalten?", "Ungläubig und zunehmend wütend."),
    ("Sie hatten mich auf dem Schirm", "Panisch angespannt, laut über Motorenlärm, hastig."),
    ("Rakete aus den Felsen", "Schrei, Schock, Atemnot; es bleiben nur Sekunden."),
    ("Messwerte im Kasten", "Erleichtert und erschöpft, ein kurzes Lachen im Ton."),
    ("Ich habe sie sofort gefunkt", "Leise und bedrückt, voller Selbstvorwürfe."),
    ("Ich verspreche nichts", "Schelmisch, fast übermütig."),
    ("Nur Messwerte", "Streng, mit mühsam verborgener Sorge."),
    ("Das Netz fällt aus", "Angespannt, scharfer Befehlston, volle Konzentration."),
    ("Der Strom ist zurück", "Aufatmend, gereizt, mit einem misstrauischen Unterton."),
    ("Lena. Alle Einheiten", "Beherrscht, doch die Stimme bricht kurz; jedes Wort kostet Kraft."),
    ("Lena... Das war nicht", "Gebrochen, ein verzweifeltes Flüstern."),
    ("Port Meridian steht", "Leise Erleichterung, Stolz und Müdigkeit."),
    ("Falke ist runter", "Gepresst, bemüht ruhig, das Herz rast."),
    ("stelle ORAKEL", "Kalt und entschlossen, ein Entschluss, der Folgen haben wird."),
    ("Vor dem Vorfall", "Erschüttert, dann eiskalte Erkenntnis."),
    ("Elin! Nicht schießen", "Dringende Bitte, atemlos, voller Angst und Hoffnung."),
    ("Die Zahlen lügen", "Eindringlich und traurig, sie meint jedes Wort."),
    ("Bewegung auf den Hängen", "Angespannt flüsternd, hochkonzentriert."),
    ("Sperrfeuer", "Schreiend dringlich, Panik unter Kontrolle."),
    ("Westbund-Bauart", "Kalter Verdacht, ungläubig und leise."),
    ("Westbund-Kennzeichen", "Fassungslos, erschüttert."),
    ("Der Westbund hat seinen eigenen", "Schwer und leise, vom Gewicht der eigenen Worte erschüttert."),
    ("Vor 41 Stunden", "Eiskalt, ruhig, unmenschlich sachlich."),
    ("Keine Westbund-Einheit", "Flach, kalt, leicht ausweichend."),
    ("Wahrscheinlichkeit eines Raubzugs", "Warnend, völlig ruhig."),
    ("Verstärkung", "Zuversichtlich und energisch, Motorenlärm im Hintergrund."),
    ("Zwei Nächte in einer Höhle", "Erschöpft, mit trockenem Humor, Schmerz im Atem."),
    ("Du bist der, der zu tief fliegt", "Langsam, warm, mit uralter Gewissheit."),
    ("Falke, ich komme dich holen", "Knapp, trocken, kaum hörbare Erleichterung."),
    ("Du siehst furchtbar aus", "Trocken, kurz, fast zärtlich."),
    ("Auch schön, dich zu sehen", "Müde und herzlich, ein schiefes Grinsen."),
    ("Streife, drei Mann", "Leise, scharf beobachtend."),
    ("Das sind keine Freunde", "Hastig, alarmiert."),
    ("Du sagst, was du gesehen hast", "Leise und bestimmt, ein Versprechen."),
    ("Datenspur sichern", "Scharf und konzentriert, Befehlston."),
    ("Neunzig Sekunden", "Nervös, aber sachlich."),
    ("Sicherheitsstufe Rot", "Kalt, amtlich, keine Widerrede."),
    ("Elitegarde? Gegen uns", "Ungläubig, dann eisig."),
    ("auf Anforderung des Rates", "Flach, höflich, unmenschlich."),
    ("gegen einen Spiegel", "Bitter und müde, mit schwarzem Humor."),
    ("Die Spur ist authentisch", "Aufgeregt, überschlägt sich fast."),
    ("Dann sage ich es laut", "Leise, entschlossen, ein einziger gerader Satz."),
    ("Meine Armee ist da", "Stark und klar, Erleichterung unter Autorität."),
    ("Pip! Nein", "Verzweifelt, Panik, Stimme bricht."),
    ("Die Spur ist echt", "Ernst, schwer, jedes Wort wiegt."),
    ("ORAKEL hat den Konvoi", "Kalt und klar, die Erkenntnis sitzt wie ein Messer."),
    ("Dann handle ich gegen den Beschluss", "Entschlossen und ruhig, ein Entschluss, der alles ändert."),
    ("Dann fliege ich voraus", "Trotzig, mit einem schmerzverzerrten Lächeln."),
    ("Das kann nicht sein", "Erschrocken, ungläubig, stockend."),
    ("Zwölf", "Müde, ironisch."),
    ("Sechs Fahrzeuge", "Nachdenklich und besorgt, trockener Humor."),
    ("Ich führe den Übergang", "Höflich, aber fest; sie lässt sich nicht lenken."),
    ("Elin, der Rat erwartet", "Glatt und bestimmt, Druck hinter jedem Satz."),
    ("Falke hat den Himmel", "Locker mit einem leisen ungutem Unterton."),
    ("Wer hat die Daten", "Nachdenklich und besorgt."),
    ("Das habe ich befürchtet", "Trocken, mit einem kleinen Lächeln."),
    ("Wer hat uns da gerade", "Misstrauisch und scharf."),
    ("Ursache der Störung", "Flach, höflich, nichtssagend."),
]

RADIO_RE = re.compile(r'radio\("([^"]+)",\s*C_\w+,\s*"([^"]+)"')


def line_id(text):
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:10]


def direction(who, text):
    voice, base = CHARACTERS[who]
    emo = ""
    for key, e in EMOTIONS:
        if key in text:
            emo = e
            break
    if not emo:
        emo = "Lebhaft und dringlich." if text.rstrip().endswith("!") else ("Fragend, angespannt." if text.rstrip().endswith("?") else "Natürlich, der Rolle angemessen.")
    return voice, base + " Gefühlslage dieser Zeile: " + emo + " Spiele die Szene echt, nicht vorlesend."


def collect():
    src = open(MISSIONS, encoding="utf-8").read()
    seen, out = set(), []
    for who, text in RADIO_RE.findall(src):
        if (who, text) in seen:
            continue
        seen.add((who, text))
        out.append((who, text))
    return out


def style_ai(x):
    """ORAKEL: leichter Ringmodulator und Hall für einen künstlichen Klang."""
    y = [v * (0.72 + 0.28 * math.sin(math.tau * 41.0 * i / pv.RATE)) for i, v in enumerate(x)]
    d = int(0.045 * pv.RATE)
    out = list(y) + [0.0] * d
    for i, v in enumerate(y):
        out[i + d] += v * 0.28
    return pv.biquad(out, "lp", 5200.0)


def finish(who, x):
    x = pv.trim(x, 0.012, 0.06)
    if who == "ORAKEL":
        x = style_ai(pv.biquad(x, "hp", 160.0))
    else:
        x = pv.biquad(pv.biquad(x, "hp", 130.0), "lp", 6800.0)
    peak = max(abs(v) for v in x) or 1.0
    return [v * 0.8 / peak for v in x]


def main():
    test = "--test" in sys.argv
    key = mv.api_key()
    lines = collect()
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for who, text in lines:
        if who not in CHARACTERS:
            print("Unbekannter Sprecher:", who)
            continue
        h = line_id(text)
        out_path = os.path.join(OUT, h + ".wav")
        raw_path = os.path.join(RAW, h + ".wav")
        if os.path.exists(out_path):
            continue
        voice, style = direction(who, text)
        if not os.path.exists(raw_path):
            pcm = b""
            for attempt in range(5):
                pcm = mv.speak(key, voice, style, text)
                if len(pcm) >= 2000 and mv._same(mv.speak.transcript, text):
                    break
                print("  Abweichung, neuer Versuch:", repr(mv.speak.transcript)[:70])
                pcm = b""
            if not pcm:
                print("Keine brauchbare Aufnahme:", who, text)
                continue
            mv.save_wav(raw_path, pcm)
        x = pv.read(raw_path)
        pv.write(out_path, finish(who, x))
        n += 1
        print("ok %s [%s/%s] %.1f s: %s" % (h, who, voice, len(x) / pv.RATE, text[:60]))
        if test:
            break
    print("Fertig: %d neue Zeilen von %d" % (n, len(lines)))


if __name__ == "__main__":
    main()
