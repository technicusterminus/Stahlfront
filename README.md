# Stahlfront

**Echtzeitstrategie in Godot 4.7** – drei grundverschiedene Fraktionen, Basisbau mit Nachschub-Wirtschaft, Generalsfähigkeiten, Superwaffen, Nebel des Krieges, Luftwaffe und ein Computergegner. Alle Grafik, Effekte und der Großteil der Modelle entstehen im Code oder in Blender-Skripten; es werden keine fremden Assets verwendet.

> Stand: spielbarer Prototyp (Skirmish gegen KI oder Zuschauermodus). Keine Kampagne, kein Mehrspieler, kein Ton. Siehe [Stand und bekannte Lücken](#stand-und-bekannte-lücken).

---

## Inhalt

1. [Schnellstart](#schnellstart)
2. [Spielprinzip](#spielprinzip)
3. [Die Fraktionen](#die-fraktionen)
4. [Einheiten und Gebäude](#einheiten-und-gebäude)
5. [Steuerung](#steuerung)
6. [Story](#story)
7. [Grafik und Technik](#grafik-und-technik)
8. [Eigene Modelle und Blender-Werkzeuge](#eigene-modelle-und-blender-werkzeuge)
9. [Projektstruktur](#projektstruktur)
10. [Testschalter und Balance-Messung](#testschalter-und-balance-messung)
11. [Stand und bekannte Lücken](#stand-und-bekannte-lücken)

---

## Schnellstart

**Voraussetzungen**

- [Godot 4.7](https://godotengine.org/) (Standard-Edition, Forward+ / Vulkan). Windows: `winget install GodotEngine.GodotEngine`
- Eine Grafikkarte mit Vulkan-Unterstützung. Getestet nur unter Windows 11.
- Optional: [Blender 5.1](https://www.blender.org/), nur wenn die Modelle neu erzeugt werden sollen.

**Starten**

```
godot --path .
```

oder das Projekt im Godot-Editor öffnen und F5 drücken. Das Startmenü bietet:

- **Fraktion** wählen (Westbund, Rote Allianz, Schattenfront)
- **Gegner:** 1 bis 3 KI-Gegner (jeder gegen jeden)
- **Schwierigkeit:** Leicht, Mittel, Schwer
- **KI gegen KI zuschauen:** Zuschauermodus ohne eigene Einheiten

---

## Spielprinzip

Du startest mit einem Hauptquartier und einem Bauarbeiter und 5.000 Credits.

1. **Nachschub:** Baue ein Nachschubzentrum nahe einem Depot. Es liefert einen Sammler-Lkw mit, der automatisch Credits aus dem Depot holt. Ohne Nachschubzentrum gibt es kein Einkommen.
2. **Strom** (Westbund und Rote Allianz): Kraftwerke versorgen Produktionsgebäude. Bei Strommangel halbiert sich die Produktion, Abwehr und Superwaffe fallen aus. Die Schattenfront braucht keinen Strom.
3. **Produktion:** Kaserne für Infanterie, Fabrik für Fahrzeuge, Flugfeld für Luftwaffe. Spätere Einheiten setzen das Forschungsgebäude voraus.
4. **Generalsrang:** Abschüsse bringen Erfahrung. Jeder Rang gibt einen **Generalspunkt**, mit dem du eine von drei Fähigkeiten freischaltest (Taste **G**).
5. **Superwaffe:** Forschung, dann das Superwaffen-Gebäude (5.000 Credits). Nach der Aufladezeit wählst du ein Ziel.
6. **Sieg:** Zerstöre alle Gebäude und Einheiten der Gegner.

Der **Nebel des Krieges** verdeckt Gelände, das du noch nicht erkundet hast. Bauplätze müssen erkundet sein.

---

## Die Fraktionen

| | **Westbund** | **Rote Allianz** | **Schattenfront** |
|---|---|---|---|
| **Stil** | Hightech, präzise, teuer | Masse, Panzer, Wille | Guerilla, Tarnung, Improvisation |
| **Farbe / Muster** | Blau, digitales Pixeltarn | Rot, Waldtarn, Sichtbeton | Sand und Rost, Wüstenplatten |
| **Strom** | benötigt | benötigt | nicht nötig |
| **Besonderheiten** | Energieschilde auf Fahrzeugen und Hubschraubern (laden nach 4 s ohne Treffer auf) · Fliegende Baudrohnen · Spähdrohne | Infanterie wird **paarweise** ausgebildet · Hordenbonus (+33 % Feuerrate ab vier Kameraden) · 50 % schnellere Beförderung · Propaganda-Aura des Propagandazentrums | Infanterie **tarnt sich** nach 2 s Stillstand · **Schrottbergung** (Fahrzeuge werden bis Stufe 3 stärker) · **Kopfgeld** (20 % des Werts jedes Abschusses) · Fahrzeuge reparieren sich selbst |
| **Generalsfähigkeiten** | Aufklärungsdrohne · Präzisionsluftschlag · Fallschirmjäger | Artilleriesperrfeuer · Staatsreserve (+2.000) · Volksmiliz | Giftnebel · Feldreparatur · Hinterhalt |
| **Superwaffe** | Orbitalkanone (Laserstrahl) | Atomsilo | Giftraketen-Silo |
| **Luftwaffe** | Lanze-Jäger, Aegis-Tarnkappenbomber, Sperber-Heli | Sturm-Abfangjäger, Bär-Bomber, Taifun-Heli | Schrott-Gleiter, Giftsprüher |

---

## Einheiten und Gebäude

Kosten in Credits. *(T)* = braucht das Forschungsgebäude.

### Westbund

| Einheit | Kosten | Rolle |
|---|---|---|
| Baudrohne | 800 | Fliegender Baumeister, baut über jedes Gelände |
| Logistik-Lkw | 600 | Sammler |
| Marinesoldat / Panzerjäger | 150 / 300 | Infanterie / Raketen gegen Fahrzeuge und Luft |
| Falke-Kampfpanzer | 900 | Standardpanzer |
| Hornet-Flakwagen | 700 | Flugabwehr |
| Lanzen-Raketenwerfer *(T)* | 1.200 | Weitreichende Raketenartillerie |
| Bastion-Laserpanzer *(T)* | 1.600 | Laser, trifft auch Luftziele |
| Sperber-Kampfheli | 1.500 | Schwebender Jäger |
| Spähdrohne | 300 | Aufklärer mit riesiger Sichtweite |
| Lanze-Jäger | 1.300 | Jagdflieger, Lenkraketen gegen Luft und Boden |
| Aegis-Tarnkappenbomber *(T)* | 2.400 | Bombenteppich gegen Bodenziele |

Gebäude: Kommandozentrale, Fusionsreaktor, Nachschubzentrum, Kaserne, Waffenfabrik, Flugfeld, Patriot-Batterie, Forschungszentrum, Orbitalkanone.

### Rote Allianz

| Einheit | Kosten | Rolle |
|---|---|---|
| Bautraktor | 800 | Baumeister |
| Nachschub-Lkw | 600 | Sammler |
| Volksgrenadier / Panzerfaust-Trupp | 170 / 480 | Infanterie, je **ein Paar** |
| Bär-Kampfpanzer | 800 | Standardpanzer |
| Drache-Flammpanzer | 800 | Flammen gegen Infanterie und Gebäude |
| Gatling-Flakpanzer | 850 | Flugabwehr |
| Sturm-Haubitze *(T)* | 1.100 | Schwere Artillerie |
| Koloss-Panzer *(T)* | 2.000 | Doppelkanone, 1.500 Leben |
| Taifun-Kampfheli | 1.400 | Gatling-Hubschrauber |
| Sturm-Abfangjäger | 1.200 | Jagdflieger mit Bordkanonen |
| Bär-Bomber *(T)* | 2.500 | Viermotoriger Teppichbomber |

Gebäude: Hauptquartier, Kohlekraftwerk, Versorgungsdepot, Kaserne, Panzerwerk, Hubschrauberbasis, Gatling-Bunker, Propagandazentrum, Atomsilo.

### Schattenfront

| Einheit | Kosten | Rolle |
|---|---|---|
| Arbeiter | 250 | Baumeister (schwach, billig) |
| Sammler-Pickup | 500 | Sammler |
| Rebell / RPG-Kämpfer | 150 / 300 | Infanterie, tarnt sich |
| Technical | 500 | Pickup mit MG |
| Raketenbuggy | 900 | Raketensalven auf große Distanz |
| Skorpion | 700 | Leichter Panzer |
| Toxinlaster | 700 | Gift gegen Infanterie |
| Sprengwagen | 600 | Selbstzerstörung, verheerend gegen Gebäude |
| Flak-Pickup | 600 | Mobile Flugabwehr |
| Bombardier *(T)* | 1.300 | Giftrakete mit riesiger Reichweite |
| Schrott-Gleiter | 550 | Billiger Ultraleichtflieger mit MG |
| Giftsprüher | 1.100 | Doppeldecker, sprüht Gift auf Bodentruppen |

Gebäude: Versteck, Umschlagplatz, Ausbildungslager, Schrottwerkstatt, Schotterpiste, Stinger-Stellung, Schwarzmarkt, Giftraketen-Silo.

### Waffen und Panzerungen

Jede Waffe hat gegen jede Panzerungsklasse (Infanterie, leicht, schwer, Luft, Gebäude) einen eigenen Schadensfaktor (siehe `scripts/defs.gd`, Tabelle `DMG_MOD`). MG sind stark gegen Infanterie, Kanonen gegen Fahrzeuge, Flak gegen Luft, Artillerie und Bomben gegen Gebäude, Flammen und Gift gegen Infanterie.

**Luftwaffe:** Hubschrauber schweben. **Flächenflieger** (Jäger, Bomber, Gleiter, Sprühflieger) können nicht schweben: Sie fliegen mit Wendekreis und Querneigung Angriffsschleifen und kreisen um Ziel oder Wachpunkt.

---

## Steuerung

| Aktion | Eingabe |
|---|---|
| Auswählen | Linksklick |
| Rahmenauswahl | Linksklick ziehen |
| Zur Auswahl hinzufügen | Shift |
| Alle gleichen Typs auf dem Bildschirm | Doppelklick oder Strg+Klick |
| Bewegen / Angreifen | Rechtsklick |
| Angriffsbewegung | **A**, dann Ziel anklicken |
| Stopp | **S** |
| Alle Kampfeinheiten | Strg+A |
| Kontrollgruppe speichern / wählen | Strg+1…9 / 1…9 (2× drücken: Kamera hin) |
| Nachschub sammeln | Rechtsklick eines Sammlers auf ein Depot |
| Bauen / reparieren | Bauarbeiter auswählen, Gebäude unten wählen und platzieren; Rechtsklick auf Baustelle setzt fort |
| Sammelpunkt | Produktionsgebäude auswählen, Rechtsklick ins Gelände |
| Kamera | Pfeiltasten / Bildschirmrand / mittlere Maustaste ziehen |
| Zoom / Drehen | Mausrad / **Q** und **E** |
| Zur letzten Meldung | Leertaste |
| Zum Hauptquartier | **H** |
| Generalsfähigkeiten | **G** |
| Hilfe / Menü | **F1** / **Esc** |

Beim Platzieren eines Gebäudes zeigt ein Phantom, ob der Platz gültig ist; Shift hält den Modus für mehrere Bauten.

---

## Story

Drei Erzählungen derselben Ereignisse – in jeder gewinnt die erzählende Fraktion, jede hat eigene Helden und besondere Charaktere.

- [Die Welt: Der Kessel, Aurelia und das Prisma](docs/story/00_welt.md)
- [Das Licht über Lysa – Westbund](docs/story/01_westbund.md) (Elin, Falke, Glas)
- [Der lange Marsch nach Aurelia – Rote Allianz](docs/story/02_rote_allianz.md) (Wolkow, Nastja, Funke)
- [Wer am Feuer sitzt – Schattenfront](docs/story/03_schattenfront.md) (Asha, Jago, Karga)

Missionen und spielbare Helden sind noch nicht umgesetzt.

---

## Grafik und Technik

- **Rendering:** Forward+ mit SSAO, SSIL, Glow, ACES-Tonemapping, Volumennebel, 4-stufige Sonnenschatten.
- **Gelände:** prozedural aus Rauschfeldern (Seen, Grate, Täler), Begehbarkeitsraster und Erreichbarkeitsprüfung; Material mit Gras, Erde, Fels, Sand und fraktionsspezifischen Basisböden (Betonplatten, Risse und Öl, festgefahrene Erde).
- **Vegetation:** Wind-animiertes Gras in Kacheln mit Sichtweiten-Ausblendung, Blumen, Büsche, Schilf, Nadel- und Laubbäume, verformte Felsen mit Moos. Gras verschwindet unter Gebäuden.
- **Wasser:** Tiefenfarbe, Lichtbrechung, Uferschaum, Wellen.
- **Tiere:** Hirschherden grasen und fliehen vor Einheiten und Gefechten; Vogelschwärme kreisen und fliegen bei Lärm auf.
- **Material-Shader:** `shaders/hardsurface.gdshader` projiziert Tarnmuster, Blechfugen, Nieten, Rost, Schmutz und Mikro-Normalen im Objektraum; jede Fraktion hat eigene Parameter.
- **Oberflächen:** jede Fraktion hat eine eigene, im Code erzeugte Oberfläche: Westbund Milchglas mit Cyan-Leuchtrand, Rote Allianz gebürstetes Metall mit Nieten und Messing, Schattenfront Holzbretter mit Nägeln und Leinenflicken mit Nähten; eigene Schrift, Emblem, Minikartenrahmen und Wortschatz (Mittel / Volkskasse / Beute usw.).
- **Effekte:** Flammen aus einer prozeduralen Flammentextur (Turbulenz, Funken, Rauch, flackerndes Licht), Explosionen, Leuchtspuren, Laser, Rauchsäulen, Einschlagkrater (Decals).
- **Kleine Details:** Fahrzeuge tragen fraktionstypische Anbauteile (Westbund Leuchtstreifen und Schildemitter, Rote Allianz Reaktivpanzerung, Kanister und Sowjetstern, Schattenfront Schrottplatten, Ersatzreifen und Lumpenfahne), Antenne mit Teamwimpel und Scheinwerfer; Anbauteile werden je Fahrzeug zu einem Netz gebündelt. Rückstoss wirkt nur im Rohr, Ketten wirbeln Staub auf, Schilde blitzen beim Treffer cyan auf, Anlagen haben Blinklichter, Fässer, Gabelstapler und Fahnen (abschaltbar mit `--nofit` / `--nolife`).
- **KI:** Basisbau nach Fraktions-Bauordnung, Wirtschaft, gewichtete Produktion, Angriffswellen, Verteidigung, Generalsfähigkeiten, Superwaffen. Drei Schwierigkeitsstufen.
- **Wegfindung:** A* auf einem 2-m-Raster mit Sichtlinienglättung, Trennkräften und Festsitz-Erkennung.
- **Leistung:** 40 bis 60 FPS in einem Drei-Fraktionen-Gefecht mit rund 140 Einheiten (Entwicklungsrechner).

---

## Eigene Modelle und Blender-Werkzeuge

Das Spiel lädt `.glb`-Dateien aus `models/units/` und `models/buildings/`, wenn sie vorhanden sind; sonst werden die im Code zusammengesetzten Modelle verwendet. Namen: `<fraktion>_<modell>.glb` (z. B. `west_tank.glb`) oder `<modell>.glb`.

**Konventionen im Modell:** Vorwärts = +Z (Blender: −Y), 1 Einheit = 1 m, Ursprung am Boden. Objekte mit den Namen `Turret` (dreht sich), `Muzzle` (Mündung), `Rotor`, `TailRotor`, `Spin` werden vom Spiel angesteuert. Materialien mit „Team“ im Namen erhalten das Tarnmuster der Fraktion.

**Vorhandene Blender-Modelle** (erzeugt per Skript):

| Skript | Ergebnis |
|---|---|
| `tools/blender/make_tank.py` | Kampfpanzer mit drehbarem Turm, gebackene PBR-Texturen |
| `tools/blender/make_soldier.py` | Soldaten (Infanterist, Panzerjäger, Arbeiter) je Fraktion, Rig und Animationen Idle/Walk/Shoot/Die |
| `tools/blender/make_west_hq.py`, `make_red_hq.py`, `make_shadow_hq.py` | Hauptquartiere |
| `tools/blender/make_factories.py <west\|red\|shadow>` | Fabriken |
| `tools/blender/make_barracks.py <west\|red\|shadow>` | Kasernen |
| `tools/blender/sf_common.py` | Gemeinsame Bausteine: Grundkörper mit Fasen, Booleans, UV, Verschleiß-Shader, Backen von Farbe, Rauheit und Normalen, Export |

**Modelle neu erzeugen**

```
blender -b -P tools/blender/make_barracks.py -- <projektordner> west
```

Die Quelldateien (`.blend`) und Texturen liegen in `models/source/`; der Ordner ist per `.gdignore` vom Godot-Import ausgenommen.

Alle übrigen Gebäude, Fahrzeuge und Flugzeuge entstehen noch im Code (`scripts/models.gd`, `scripts/arch.gd`, `scripts/arch_detail.gd`).

---

## Projektstruktur

```
project.godot            Godot-Projekt (Autoloads: Defs, Game)
scenes/main.tscn         Einstiegsszene
scripts/
  defs.gd                Alle Werte: Fraktionen, Einheiten, Gebäude, Fähigkeiten
  game.gd                Spielzustand, Wegfindung, Schaden, Nebel des Krieges, Sieg
  main.gd                Aufbau von Welt, Licht und Matches, Testschalter
  terrain.gd             Gelände, Wasser, Begehbarkeit
  vegetation.gd          Gras, Büsche, Bäume, Felsen
  animals.gd             Hirsche und Vögel
  unit.gd                Einheit: Bewegung, Kampf, Fraktionsfähigkeiten, Flug
  building.gd            Gebäude: Bau, Produktion, Abwehr, Superwaffe, Animationen
  weapons.gd, projectile.gd, fx.gd   Waffen, Geschosse, Effekte
  powers.gd              Generalsfähigkeiten und Superwaffen
  ai.gd                  Computergegner
  controller.gd, camera_rts.gd, hud.gd, minimap.gd   Eingabe, Kamera, Oberfläche
  models.gd, arch.gd, arch_detail.gd   Modelle im Code, Fraktionsarchitektur, Detailstufe
shaders/                 Gelände, Wasser, Material, Vegetation, Felsen, Nebel
models/                  .glb-Modelle (units, buildings) und Quellen (source)
tools/blender/           Blender-Skripte für die Modelle
tools/balance_test.ps1   Balance-Messreihe
docs/story/              Welt und drei Erzählungen
```

---

## Testschalter und Balance-Messung

Schalter folgen auf `--` hinter dem Godot-Aufruf, z. B. `godot --path . -- --autostart --faction=red --seed=7`.

| Schalter | Wirkung |
|---|---|
| `--autostart` | Überspringt das Menü, startet mit `--faction=west\|red\|shadow` |
| `--demo` | KI gegen KI (Zuschauer) |
| `--enemies=1..3`, `--difficulty=0..2` | Gegneranzahl und Stufe |
| `--seed=N` | Kartenseed |
| `--speed=N` | Zeitraffer |
| `--quit=SEK` | Beendet nach SEK Spielsekunden und gibt Statistik und FPS aus |
| `--shot=PFAD --shotdelay=SEK` | Screenshot nach SEK Sekunden |
| `--battlecam` | Kamera folgt dem Kampfgeschehen |
| `--basecam` | Baut eine Testbasis mit allen Gebäuden |
| `--showcase=tank\|inf\|jet\|bomber…` | Stellt Einheiten zum Begutachten auf (`--camdist=` für den Abstand) |
| `--firetest=GRÖSSE` | Einzelnes Feuer vor der Kamera |
| `--animalcam` | Kamera auf eine Hirschherde |
| `--uitest` | Automatisierter Bedientest mit simulierten Mausklicks |

**Balance-Messreihe:** `tools/balance_test.ps1` simuliert KI-Gefechte ohne Fenster, rotiert Fraktionen und Startpositionen über mehrere Karten und fasst Überlebensquote, Abschüsse, Verluste und Skriptfehler je Fraktion zusammen:

```
powershell -File tools/balance_test.ps1 -Godot <pfad\zu\godot_console.exe> -Seeds "7,31,55" -Quit 650 -Out ergebnis.txt
```

---

## Stand und bekannte Lücken

**Fertig:** drei Fraktionen mit Einheiten, Gebäuden, Fähigkeiten, Superwaffen und Besonderheiten · Luftwaffe · Nebel des Krieges · KI · Landschaft mit Vegetation, Wasser und Tieren · Story in drei Fassungen · Blender-Modelle für Panzer, Soldaten, Hauptquartiere, Fabriken und Kasernen.

**Offen:**

- **Balance:** In KI-Messungen war die Schattenfront auffällig oft früh unterlegen; wird untersucht.
- **Helden:** Die Story-Helden sind noch keine spielbaren Einheiten.
- **Missionen und Kampagne:** noch keine.
- **Ressourcen:** nur Credits; ein Ressourcenbaum (Öl, Holz, Eisen, Stahl, Gold) ist geplant.
- **Seestreitkräfte** und größere Wasserflächen: geplant.
- **Modelle:** Kraftwerke, Nachschubzentren, Flugfelder, Abwehr, Forschung und Superwaffen sowie alle Fahrzeuge außer dem Panzer sind noch Code-Modelle und deutlich gröber als die Blender-Modelle.
- **Ton und Musik:** nicht vorhanden.
- **Mehrspieler:** nicht vorhanden.
- **Plattformen:** nur unter Windows 11 getestet.

---

*Alle Inhalte (Code, Modelle, Texte) sind Eigenentwicklungen. Das Spiel ist von Echtzeitstrategie-Klassikern inspiriert, verwendet aber keine fremden Namen, Marken oder Assets.*
