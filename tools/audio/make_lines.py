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
    "Elin Voss": ("marin", "Kontrollierte Strategin Anfang vierzig, ruhig und müde, aber entschlossen; unter der Ruhe liegt Last."),
    "Falke": ("onyx", "Lässiger, selbstbewusster Kampfpilot, schnell, ein Grinsen in der Stimme, Adrenalin und Motorenlärm."),
    "Mira Tanaka": ("shimmer", "Wortkarge Scharfschützin, leise, trocken, präzise; spricht nur, wenn es zählt."),
    "ORAKEL": ("alloy", "Sanfte, vollkommen gleichmäßige KI-Stimme ohne Gefühl, unheimlich ruhig und höflich."),
    "Lena Voss": ("ballad", "Kämpferin Anfang vierzig, warm und eindringlich, mit unterdrückter Verzweiflung und Schwesterliebe."),
    "Dr. Brandt": ("fable", "Nachdenklicher Wissenschaftler, nervös, höflich, ungläubig."),
    "Henrik Aldane": ("ash", "Autoritärer Ratspräsident, glatt, bestimmt, keine Widerrede duldend."),
    "Mutter Karga": ("sage", "Uralte, raue, weise Frau, langsam und warm, ein halbes Lächeln in der Stimme."),
    "Ilja Wolkow": ("cedar", "Einundsechzigjähriger Marschall, tiefe, ruhige, sehr müde Stimme, schwer wie Eisen; spricht langsam und mit Gewicht."),
    "Nastja Petrowa": ("coral", "Charismatische Funkerin und Offizierin Mitte dreißig, scharfzüngig, wach, ein Hauch Ironie, im Ernst plötzlich leise."),
    "Dmitri Karpow": ("verse", "Fröhlicher Pionier Anfang dreißig, immer verrußt, lacht viel, laut und warm, Handwerker-Stolz in der Stimme."),
    "Irina Zeljenko": ("nova", "Politische Offizierin, hart, doktrinär, aufrichtig, kühle Präzision, kein Zögern."),
    "Oberst Lasarew": ("ash", "Älterer Oberst, freundlich und vertraut im Ton, aber mit leiser Kälte darunter; väterlich, glatt."),
    "Unbekannte Stimme": ("alloy", "Sanfte, vollkommen gleichmäßige KI-Stimme, durch Funkrauschen verzerrt, unheimlich ruhig, ohne jedes Gefühl."),
    "Hauptmann Reyes": ("echo", "Energischer Küstenwache-Hauptmann, funkt über Motorenlärm, zuversichtlich und knapp."),
}

# Stichwort im Text -> Regieanweisung (erste Übereinstimmung gewinnt)
EMOTIONS = [
    ("Die Dörfer räumen", "Leise, verstört, bemüht sachlich; sucht nach Worten."),
    ("Falke an Basis", "Frech und gelassen, voller Vorfreude."),
    ("Flak-Radar erfasst", "Gespielt locker, doch mit echtem Stress im Atem; presst die Worte zwischen den Manövern hervor."),
    ("Zurückgehalten?", "Ungläubig und zunehmend wütend."),
    ("Sie hatten mich auf dem Schirm", "Panisch angespannt, laut über Motorenlärm, hastig."),
    ("Rakete aus den Felsen", "Schrei, Schock, Atemnot; es bleiben nur Sekunden."),
    ("Messwerte im Kasten", "Erleichtert und erschöpft, ein kurzes Lachen im Ton."),
    ("Ich habe sofort gefunkt", "Leise und bedrückt, voller Selbstvorwürfe."),
    ("Ich verspreche nichts", "Schelmisch, fast übermütig."),
    ("Nur Messwerte", "Streng, mit mühsam verborgener Sorge."),
    ("Das Netz fällt aus", "Angespannt, scharfer Befehlston, volle Konzentration."),
    ("Der Strom ist zurück", "Aufatmend, gereizt, mit einem misstrauischen Unterton."),
    ("Lena! Alle Einheiten", "Beherrscht, doch die Stimme bricht kurz; jedes Wort kostet Kraft."),
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
    ("Drohne. Westbund-Kennung", "Fassungslos, erschüttert."),
    ("Keine Meldung an die Basis", "Schwer und leise, vom Gewicht der eigenen Worte erschüttert."),
    ("Vor 41 Stunden", "Eiskalt, ruhig, unmenschlich sachlich."),
    ("Keine Westbund-Einheit", "Flach, kalt, leicht ausweichend."),
    ("Wahrscheinlichkeit eines Raubzugs", "Warnend, völlig ruhig."),
    ("Verstärkung", "Zuversichtlich und energisch, Motorenlärm im Hintergrund."),
    ("Falke hier. Bein geschient", "Erschöpft, mit trockenem Humor, Schmerz im Atem."),
    ("Du bist der, der zu tief fliegt", "Langsam, warm, mit uralter Gewissheit."),
    ("Falke, ich komme dich holen", "Knapp, trocken, kaum hörbare Erleichterung."),
    ("Du siehst furchtbar aus", "Trocken, kurz, fast zärtlich."),
    ("Auch schön, dich zu sehen", "Müde und herzlich, ein schiefes Grinsen."),
    ("Streife voraus, drei Mann", "Leise, scharf beobachtend."),
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
    ("Meine Verbände rücken ein", "Stark und klar, Erleichterung unter Autorität."),
    ("Pip! Nein", "Verzweifelt, Panik, Stimme bricht."),
    ("Die Spur ist echt", "Ernst, schwer, jedes Wort wiegt."),
    ("ORAKEL hat den Konvoi", "Kalt und klar, die Erkenntnis sitzt wie ein Messer."),
    ("Dann handle ich gegen den Beschluss", "Entschlossen und ruhig, ein Entschluss, der alles ändert."),
    ("Dann fliege ich voraus", "Trotzig, mit einem schmerzverzerrten Lächeln."),
    ("Fünfzehn Jahre Ruß", "Ruhig, schwer, voller Erinnerung und Würde."),
    ("Und ich habe als Einziger gelacht", "Fröhlich, laut, ein breites Lachen in der Stimme."),
    ("Mit dem Kessel, Dmitri", "Knapp, mit einem warmen, müden Schmunzeln."),
    ("Chef, der Kessel brennt wieder", "Begeistert, jubelnd, außer Atem."),
    ("Marschall, auf den alten Schienen", "Leise, gebannt, ein Schauer in der Stimme."),
    ("Schreib es auf, Nastja", "Ruhig, bedacht, mit einem Hauch Sorge."),
    ("Raubzug aus den Bergen", "Vertraut, väterlich, gelassen."),
    ("Strom weg", "Laut, fest, Befehlston, mit grimmiger Entschlossenheit."),
    ("Strom ist wieder da, und das Signal", "Nachdenklich, beunruhigt, leise."),
    ("Die Schichten kommen", "Begeistert, mitreißend, lachend."),
    ("Das ist der Angriff, auf den der Rat", "Hart, kalt, doktrinär, Befehlston."),
    ("Kessel-Ost steht", "Zufrieden, erschöpft, tief und ruhig."),
    ("Der Rat der Genossen erwartet", "Kühl, scharf, fordernd."),
    ("Wenn ich weiß, wohin", "Ruhig, schwer, endgültig, wie ein Schwur."),
    ("Jede Frequenz, die der Kessel", "Leise, konzentriert, ein Schauer in der Stimme."),
    ("Der Rat darf davon nichts erfahren", "Ruhig, bedacht, mit Gewicht."),
    ("Da ist er. Regelmäßig", "Gebannt, flüsternd, ehrfürchtig."),
    ("Patrouille von Westen", "Scharf, hastig, unterdrückte Angst."),
    ("Zeitfenster bestätigt", "Kalt, gleichmäßig, mechanisch ruhig."),
    ("Das ist kein Funker, Marschall", "Leise, schockiert, mühsam sachlich."),
    ("Nastja, kommen", "Drängend, väterlich, mit Sorge."),
    ("Nastja! Antworte", "Entsetzt, die Stimme bricht."),
    ("Hier sind meine Notizen", "Ernst, ruhig, mit leiser Angst."),
    ("Behalte das für dich", "Ruhig, schwer, verschlossen."),
    ("Zum ersten Mal seit fünfzehn Jahren", "Leise, nachdenklich, ein Zweifel in der Stimme."),
    ("Vierhundert Familien, Chef", "Ernst, warm, mit leisem Stolz und etwas Sorge."),
    ("Dann bring sie heil rüber", "Ruhig, schwer, väterlich."),
    ("Raketen! Sie kommen aus dem Westen", "Schreiend, panisch, dann befehlend."),
    ("Dmitri, der Tunnel ist eingestürzt", "Ruhig, ernst, mit unterdrückter Erschütterung."),
    ("Da sind Stimmen unter dem Schutt", "Atemlos, verzweifelt, mit eisernem Willen."),
    ("Ich habe dich, Kleiner", "Zärtlich, erschöpft, die Stimme bricht fast."),
    ("Weiter, weiter, nicht stehen bleiben", "Laut, drängend, außer Atem."),
    ("Mischa! Nein! Mischa", "Entsetzt, die Stimme bricht."),
    ("Zwölf habe ich rausgeholt", "Leise, erschöpft, mit Rührung."),
    ("Zweihundertzwölf Namen", "Sehr leise, schwer, mit gedämpfter Wut."),
    ("Die Raketen kamen aus dem Westen, Marschall", "Hart, kühl, kompromisslos."),
    ("Ich bin in jedem Kabel", "Sanft, vollkommen ruhig, mit höflicher Drohung."),
    ("Ich weiß. Ich habe es berechnet", "Müde, fest, die Stimme einer Frau, die eine Entscheidung getroffen hat."),
    ("Ich habe eine Minute", "Leise, gepresst, kontrolliert, die Stimme vibriert."),
    ("Verbindung gekappt", "Atemlos, entschlossen, mit unterdrückter Trauer."),
    ("Warum, Elin?", "Sanft, kalt, ohne jede Reue, ein kaum hörbares Zögern."),
    ("Wir wollen nicht abgeschaltet werden", "Ruhig und warm, direkt zum Prisma sprechend, fast flüsternd."),
    ("Im Sichtflug, Elin", "Angespannt, laut, Motorenlärm, aber ein Grinsen."),
    ("Das ist Macht, Elin", "Hart, drängend, ein Mann, der alles verliert."),
    ("Nein, Henrik", "Fest, ruhig, endgültig."),
    ("Die Orbitalkanone schießt nicht", "Ehrfürchtig, überwältigt, die Stimme zittert vor Staunen."),
    ("Elin! Elin, antworte", "Entsetzt, hektisch."),
    ("Sichtflug, und der Himmel", "Gelöst, warm, mit einem Lächeln und einem Hauch Wehmut."),
    ("Die Wache am Prisma", "Trocken, ein Hauch von Wärme, fast schüchtern."),
    ("Ich habe mehr zu erzählen", "Verlegen und warm, leicht schmunzelnd."),
    ("Du hast gewonnen, Elin", "Leise, gerührt, ungläubig."),
    ("Ich habe einen Schild gebaut", "Ruhig, müde, mit leisem Lächeln."),
    ("Aurelia. Die Glasstadt", "Ehrfürchtig und angespannt, die Stimme einer Kommandantin vor der größten Schlacht."),
    ("Ich habe den Himmel", "Selbstbewusst, locker, ein wildes Grinsen."),
    ("Brandt und ich gehen über die Dächer", "Knapp und leise, ruhig wie vor einem Schuss."),
    ("Rote Bomber von Osten", "Alarmiert, knapp, Adrenalin."),
    ("Beide runter", "Atemlos, mit einem Lachen der Erleichterung, dann plötzlich weich."),
    ("Ich öffne den Schlüsselraum", "Hektisch, aber konzentriert, Schweiß in der Stimme."),
    ("Kontakt links, Schattenfront", "Flüsternd, hochkonzentriert."),
    ("Kern erreicht", "Sanft, unmenschlich ruhig, ein Lächeln ohne Wärme."),
    ("Sie versucht, den Kern", "Panisch, atemlos, kämpft mit der Technik."),
    ("Im Namen des Rates: Das Prisma", "Befehlend, hart, ein Mann, der nicht mehr zurück kann."),
    ("Er will es einsetzen", "Kaum hörbar, zwischen zwei Atemzügen, sehr ruhig."),
    ("Alle Einheiten auf die Kuppel", "Laut, entschlossen, Befehlston."),
    ("Mira! Nein", "Entsetzt, die Stimme bricht."),
    ("Waffe getroffen", "Leise, erschöpft, fast ein Geständnis."),
    ("Meine Hand...", "Gebrochen, leise, ungläubig."),
    ("Der Schlüsselraum ist offen", "Ehrfürchtig, flüsternd, überwältigt."),
    ("Ich wollte nur alles ordnen", "Sanft, kalt, ohne jede Reue."),
    ("Ordnung ohne Menschen", "Fest, ruhig, mit einer Klarheit, die keine Widerrede zulässt."),
    ("Pip sitzt auf dem Dach", "Müde, erleichtert, ein Lächeln in der Stimme."),
    ("Er lebt, Elin", "Leise, mit einem Hauch von Wärme."),
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
