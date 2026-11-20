# Stahlfront

**Echtzeitstrategie in Godot 4.7** – drei grundverschiedene Fraktionen, Basisbau mit Nachschub-Wirtschaft, Generalsfähigkeiten, Superwaffen, Nebel des Krieges, Luftwaffe und ein Computergegner. Alle Grafik, Effekte und der Großteil der Modelle entstehen im Code oder in Blender-Skripten; es werden keine fremden Assets verwendet.

> Stand: spielbarer Prototyp (Skirmish gegen KI oder Zuschauermodus). Vier Tutorials und der Beginn einer Kampagne, Ton (Stimmen und Geräusche), kein Mehrspieler. Siehe [Stand und bekannte Lücken](#stand-und-bekannte-lücken).

## Visuelle Testfassung

Öffne `project.godot` mit Godot 4.7, lass die Modelle importieren und starte mit F5. Unter Windows startet `Start-Stahlfront.cmd` das Spiel mit einem installierten Godot-4.7-Build. Beim ersten Durchlauf importiert Godot Land-, Luft- und Seemodelle sowie Gebäude und Texturen. Das kann einige Minuten dauern.

- Der Westbund-Falke hat ein eigenes Modell mit geformter Wanne, niedrigerem Turm und einzeln bewegten Kettengliedern. Der Lack zeigt in der Nahsicht Abrieb und vertikale Laufspuren. Am Laufwerk setzt sich mehr Staub ab als am Turm. Räder und Ketten verwenden in Godot instanzierte Meshes. Andere Bodenfahrzeuge neigen ihre Aufbauten beim Beschleunigen und Bremsen.
- Die neun Modellvarianten für Infanterie, Panzerabwehrtrupps und Arbeiter tragen verstärkte Handschuhe und Knieschoner. Der Westbund setzt auf segmentierte Schutzplatten, die Rotfront auf gepolsterte Gewebewesten und die Schattenfraktion auf gewickelten Staubschutz. Die GLB-Dateien enthalten die Animationen für Stehen, Gehen, Schießen und Fallen.
- Bei Fahrzeugen, Luftfahrzeugen und Schiffen bleiben gebackene Texturen auf dem Originallack erhalten. Lackierte Oberflächen sind zurückhaltender eingefärbt, Kurvenbewegungen flüssiger und Heckwellen vom Tempo abhängig.
- Gebäude erhalten differenzierte Oberflächen und Zugangsbereiche. In Fabriken und Werften schließt der Greifer an der Kiste, hebt sie, setzt sie an der zweiten Station ab und fährt leer zurück. Rollen, Winde und einzelne Kettenglieder bewegen sich mit. An Nachschubzentren fährt ein Lastschlitten, und am Flugfeld arbeiten Windsack und Lauflichter. Lüfter laufen bei Strommangel aus. Betriebsanzeigen und Fabrikschranken reagieren auf Produktion und Auslieferung.

### Rohstoffvorkommen

Die fünf Vorkommen (Nachschubdepot, Holzlager, Erzfels, Ölquelle, Goldader) sind neu gestaltet: Gesteinsformen aus verformten Kugeln mit Facetten, Stammstapel mit Rinden- und Schnitttextur, Erzfels mit Rostadern und Lore auf Schienen, Pumpe mit Pendelbalken, Fässern und Rohrleitung, Goldader aus hellem Quarzgestein mit leuchtenden Adern und Nuggetkiste, Holzkisten mit Spanngurten und Plane. Entwurfsblatt und Farbtexturen wurden mit einem Bildmodell erzeugt: `tools/art/resource_art.py` (Prompts in `tools/art/resource_prompts.json`) legt die Quellbilder unter `models/source/resources/` ab, samt Kosten in `provenance.json`; `tools/art/resource_textures.py` macht daraus kachelbare Spieltexturen unter `models/resources/`. Das Material `shaders/resource.gdshader` projiziert sie dreiseitig und beachtet den Nebel des Krieges. Test: `--depotshow` (alle fünf nebeneinander), `--depotreal=gold|wood|iron|oil|supply` (nächstes echtes Vorkommen), `--depotfocus=0..4`.

### Oberflächen-Entwürfe

Die Entwurfsblätter legen Materialwahl und Formensprache für Gebäude, Fahrzeuge und Fußtruppen fest. Vier Materialvorlagen liefern Metall, Beton, Gewebe und Holz. Das Blender-Skript `tools/blender/make_surface_detail.py` gleicht Beleuchtungsverläufe aus und erzeugt kachelbare Detail-, Rauheits- und Reliefkarten. Godot mischt sie über die vorhandenen Materialien. Stahlfront verwendet beim Spielen lokale Texturen und läuft offline.

Die Entwurfsdaten (Prompts, Modell, die vier Materialvorlagen) liegen unter `tools/` und `models/source/`. Die Laufzeitkarten lassen sich mit `make_surface_detail.py` erneut erzeugen (Aufruf im Kopfkommentar des Skripts). Für einen direkten Vergleich lässt sich der Durchgang mit `--plain-surfaces` ausblenden.

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

Gegen einen menschlichen Spieler setzt die KI auf Leicht und Mittel offensive Generalsfähigkeiten (Sperrfeuer, Luftschlag, Gift, Fallschirmjäger) erst 180 Sekunden nach Gefechtsbeginn ein, damit der erste Wirtschaftsaufbau nicht sofort beschossen wird; auf Schwer sowie in KI gegen KI (Zuschauermodus, Balance-Messungen) gilt keine Sperre. Beim ersten Bauschritt markiert das Spiel Baudrohne und Nachschubdepot über der Szene.

Du startest mit einem Hauptquartier, 5.000 Credits und einem Bautrupp. Die Schattenfront beginnt mit zwei Arbeitern. Die Kommandoleiste zeigt während des Einstiegs den nächsten Bauschritt für deine Fraktion. Der Hinweis bleibt auch bei ausgewählten Einheiten sichtbar und endet mit der ersten fertigen Fahrzeugfabrik.

1. **Nachschub:** Baue ein Nachschubzentrum nahe einem Depot. Es liefert einen Sammler-Lkw mit, der automatisch Credits aus dem Depot holt. Ohne Nachschubzentrum gibt es kein Einkommen.
2. **Strom** (Westbund und Rote Allianz): Kraftwerke versorgen Produktionsgebäude. Bei Strommangel halbiert sich die Produktion, Abwehr und Superwaffe fallen aus. Die Schattenfront braucht keinen Strom.
3. **Produktion:** Kaserne für Infanterie, Fabrik für Fahrzeuge, Flugfeld für Luftwaffe. Spätere Einheiten setzen das Forschungsgebäude voraus.
4. **Generalsrang:** Abschüsse bringen Erfahrung. Jeder Rang gibt einen **Generalspunkt**, mit dem du eine von drei Fähigkeiten freischaltest (Taste **G**).
5. **Superwaffe:** Forschung, dann das Superwaffen-Gebäude (5.000 Credits). Nach der Aufladezeit wählst du ein Ziel.
6. **Sieg:** Zerstöre alle Gebäude und Einheiten der Gegner.

### Ressourcenbaum

Neben Credits gibt es vier Rohstoffe auf der Karte und einen veredelten:

| Rohstoff | Fundort | Verwendung |
|---|---|---|
| **Holz** | Wäldchen mit Stammstapeln, je zwei neben jeder Startbasis | fast alle Gebäude |
| **Eisen** | Erzfelsen neben jeder Startbasis | wird zu Stahl geschmolzen |
| **Öl** | Ölquellen mit nickendem Förderbock am Rand jeder Startbasis | Stahlwerk und alle Flugzeuge |
| **Gold** | Adern in der Kartenmitte, umkämpft | Forschung, Superwaffen, teuerste Einheiten |
| **Stahl** | entsteht automatisch: jedes fertige Nachschubgebäude schmilzt pro Sekunde aus 2 Eisen und 1 Öl einen Stahl | Fabriken, Abwehr, schwere Fahrzeuge |

Sammler holen jeden Rohstoff: Rechtsklick auf ein Vorkommen, oder die Schaltflächen *Holz / Eisen / Öl / Gold sammeln*. Die Kosten stehen im Tooltip jeder Schaltfläche, die Kopfleiste zeigt alle Vorräte. Mehrere Nachschubgebäude schmelzen schneller. Die KI verteilt ihre Sammler reihum auf alle Rohstoffe.

### Seestreitkräfte

Die Karte hat einen **Mittelsee**, vier **Kanäle** zu den Ecken und je eine **Bucht** vor jeder Startbasis. Das Wasser bildet einen Baum ohne Schleifen und sperrt das Land nirgends ab. Ab dem Fabrikbau bauen Spieler am Ufer eine **Werft** (muss am Meer stehen, Pier zeigt zum Wasser). Schiffe fahren nur auf dem Meer, stampfen und rollen im Seegang und ziehen Heckwellen.

| | Werft | leichtes Schiff | schwerer Kreuzer (braucht Forschung) |
|---|---|---|---|
| **Westbund** | Marinewerft mit Glashalle und Portalkran | Sentinel-Korvette: Raketen gegen Boote und Flugzeuge, Schildgenerator | Aegis-Kreuzer: Senkrechtstarter, Artillerie 52 m, Hubschrauberdeck |
| **Rote Allianz** | Schiffswerft mit Sägedach, Schlot, Drehkran | Sturm-Kanonenboot: billig und robust | Oktober-Schlachtkreuzer: drei Doppelgeschütze, zerlegt Gebäude |
| **Schattenfront** | Schmugglerhafen aus Holz, Zeltplane, Ausguck | Schmuggler-Kutter: schnell, MG | Piraten-Fregatte: Raketensalven, Containerstapel, Totenkopfflagge |

Alle Schiffe haben Reling, Bullaugen, Rettungsboote, Besatzung, drehendes Radar, wehende Flaggen und Rauch. Die KI baut eine Werft und eine Flotte von höchstens sechs Schiffen, die ab drei Schiffen die Werft oder Küste des Gegners angreift. Test: `--seashow` stellt Werft und alle Schiffe in die Heimatbucht. Test der Abwehrbauten: `--defensetest` (Drehung, Ausrichtung, Schaden je Fraktion). Karten: `--map=1..40`, `--size= --water= --islands= --resources= --hills= --forest= --seed=` und `--mapimg=datei.png` (Kartenbild in `shots/`); Tageszeit: `--hour=` und `--daycycle=` (Minuten pro Tag); Explosionen: `--boomtest`; Menü: `--mapdialog`, `--menupick=N`. Schnellboot (Rote Allianz) und Jetski (Schattenfront) sind schnelle, zerbrechliche Ergänzungen der Werft; der Westbund hat mit der Korvette sein Schnellschiff. Nahaufnahme der Arbeiterfiguren: `--workershow`. U-Boote (Rote Allianz, Schattenfront) sind getaucht unsichtbar, solange kein Gegner näher als 10 m ist, und tauchen nur nach einem Torpedoschuss kurz auf. Der Atlas-Flugzeugträger (Westbund) baut selbstständig bis zu vier Falken-Kampfdrohnen (je 250 Credits).

Der **Nebel des Krieges** verdeckt Gelände, das du noch nicht erkundet hast. Bauplätze müssen erkundet sein.

---

### Karten und Tageszeit

Im Startmenü öffnet **Karte und Tageszeit …** einen Dialog mit Vorschau:

- **40 Standardkarten:** zehn Landschaftstypen (Kreuzsee, Windungen, Seenplatte, Uferkanal, Hochland, Inselmeer, Waldwelt, Steppe, Schären, Klamm) in je vier Größen und Abwandlungen.
- **Regler für eigene Karten:** Größe (160 bis 336 m), Wasseranteil, Inseln, Rohstoffe, Hügel, Wald, dazu Gewässerform und Zufallszahl. Die Vorschau zeigt Gewässer, Höhen, Startpunkte und Vorkommen. „Zufällige Karte" würfelt alles.
- **Gewässerformen:** *Kreuzsee* (Mittelsee mit vier Kanälen zu den Buchten), *Windungen* (geschwungene Kanäle), *Getrennte Seen* (eigene See je Basis, keine Seeverbindung), *Uferkanal* (Kanal entlang dreier Ränder). Landbrücken sichern, dass alle Basen und Vorkommen zu Fuß erreichbar bleiben.
- **Tag und Nacht:** Startzeit und Tagesdauer (fest, 6, 14 oder 30 Minuten pro Tag). Sonne und Mond wandern, Himmel, Nebel und Belichtung wechseln, die Uhr steht in der Kopfleiste. Nachts sehen Einheiten und Gebäude etwa ein Viertel weniger weit.
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

## Kampagne und Tutorial

Im Hauptmenü öffnet **Kampagne und Tutorial …** die Missionsliste. Jede Mission beginnt mit einer Einsatzbesprechung, zeigt links oben die Ziele (abgehakt, sobald erfüllt) und meldet sich per Funk mit Sprechern. Fortschritt wird unter `user://campaign.json` gespeichert; Kampagnenkapitel schalten nacheinander frei, Tutorials sind immer offen.

- **Tutorials** (mit der im Hauptmenü gewählten Fraktion, ohne Gegner-KI): 1 Erste Schritte (Auswählen, Bewegen, Nachschub, Strom, Kaserne, Truppe), 2 Wirtschaft und Fabrik, 3 Gefechtsbefehle (Rahmen, Gruppen, Angriffsmarsch), 4 Luft, See und Fähigkeiten.
- **Kampagne „Das Licht über Lysa“ (Westbund)**, sieben Kapitel nach der Erzählung: 1 Port Meridian (Basis aufbauen, Raubzüge der Schattenfront abwehren, zehn Minuten halten), 2 Der Falke fliegt (Messpunkte mit Jägern und Drohne überfliegen, Flugabwehr umgehen), 3 Der Pass (Konvoi mit sechs Lkw eskortieren, zwei Hinterhalte überstehen, eine Drohne ohne Kennsignal abschießen), 4 Die Brücke über Lysa (Brücke erobern, Elins Begegnung mit Lena, Falke wird abgeschossen, Gegenangriff abwehren), 5 Zeugen (Falke und das Kind Pip heimgeleiten, das Lazarett gegen die Elitegarde des Rates halten, bis Dr. Brandt die Datenspur gesichert hat), 6 Die Nacht von Aurelia (Falke hält den Himmel, Mira und Brandt gehen zur Kuppel am Lysa-Ufer, Aldane wird entwaffnet, die letzte Welle abgewehrt), 7 Das Licht (Elin kappt ORAKEL, die Kuppel gegen drei Wellen halten, bis das Prisma den Lichtschild legt; Ende des Westbund-Feldzugs).
- **Kampagne „Der lange Marsch nach Aurelia“ (Rote Allianz)**, im Aufbau: alle drei Kampagnen erzählen dieselbe Geschichte aus ihrer Sicht (`docs/story/`). Bisher spielbar: 1 Die Halle in Kessel-Ost (Basis aus eigener Kraft aufbauen, Hordenbonus nutzen, Raubzüge der Schattenfront und einen Stromausfall überstehen). Das Kampagnenmenü zeigt je Fraktion eine eigene Kapitelreihe mit eigener Freischaltung.
- **Missionen schreiben:** `scripts/missions.gd` beschreibt jede Mission als Daten (Karte, Start, Ziele, Ereignisse, Funksprüche, Niederlage); `scripts/mission_runner.gd` führt sie aus. Neue Bedingungen und Aktionen stehen in `_cond` und `_do`.
- **Spannungsbogen und Inszenierung:** Die Kampagnenkapitel haben ein filmisches Intro und Outro (Letterbox, Kamerafahrt, Titelkarte, Funksprüche; mit Leertaste überspringbar) und gliedern sich in Akte mit Bannern: Aufbau, Wendepunkt, Höhepunkt, Auflösung. Skript-Ereignisse sind unter anderem Alarmsirenen, Kamerafahrten zum Geschehen, Blackout mit Tageszeitwechsel, Artillerieeinschläge, Verstärkung, Abschüsse und Fluchtbewegungen. Entscheidungen zählen: In Kapitel 4 bleibt Lena nur am Leben, wenn du sie nicht ausdrücklich angreifst.
- **Gesprochene Funksprüche:** Jede Funkzeile der Missionen ist vertont, mit eigener Stimme und Gefühlslage je Sprecher. `tools/audio/make_lines.py` liest die Funksprüche aus `scripts/missions.gd`, erzeugt fehlende oder geänderte Zeilen und legt sie unter `audio/lines/` ab (Dateiname = Hash des Textes). Wer einen Text ändert, startet das Skript erneut.
- **Test:** `--mission=<id>` startet eine Mission direkt (`t1`–`t4`, `c1`–`c3`), `--missionauto` überspringt die Besprechung, `--missioncheck` wertet alle Bedingungen aus, `--missionplay` spielt Tutorial 1 und 3 automatisch durch, `--missionchain` startet danach die Folgemission, `--cine` zeigt Intro und Outro auch mit `--missionauto`, `--campaignmenu` zeigt die Liste.

## Ton

- **Einheitenstimmen:** Beim Auswählen, Marschbefehl, Angriffsbefehl, Bauen und Nachschubholen spricht eine Einheit eine Funkzeile, je Fraktion mit eigener Stimme und eigenem Ton (Westbund kühl und präzise, Rote Allianz tief und streng mit Funkverzerrung, Schattenfront rau und lässig). Luft- und Seeeinheiten haben eigene Marschzeilen.
- **Gebäudegeräusche:** Klick auf ein eigenes Gebäude spielt einen Klang je Rolle (Hauptquartier, Kraftwerk, Nachschub, Kaserne, Fabrik, Flugfeld, Werft, Abwehr, Forschung, Superwaffe). Dazu Platzieren und „Einheit fertig“.
- **Bedienung:** F8 schaltet den Ton ein und aus.
- **Erzeugung:** `tools/audio/make_voice.py` erzeugt die Sprachzeilen mit einem KI-Sprachmodell (Schlüssel aus einer Umgebungsvariable, siehe Kopfkommentar), `tools/audio/process_voice.py` schneidet zu und legt den Funkfilter darüber, `tools/audio/make_sfx.py` synthetisiert die Geräusche. Test: `--audiotest`.

## Story

Drei Erzählungen derselben Ereignisse – in jeder gewinnt die erzählende Fraktion, jede hat eigene Helden und besondere Charaktere.

- [Die Welt: Der Kessel, Aurelia und das Prisma](docs/story/00_welt.md)
- [Das Licht über Lysa – Westbund](docs/story/01_westbund.md) (Elin, Falke, Glas)
- [Der lange Marsch nach Aurelia – Rote Allianz](docs/story/02_rote_allianz.md) (Wolkow, Nastja, Funke)
- [Wer am Feuer sitzt – Schattenfront](docs/story/03_schattenfront.md) (Asha, Jago, Karga)

Der Beginn der Westbund-Kampagne ist spielbar (siehe Abschnitt Kampagne und Tutorial). Spielbare Helden gibt es noch nicht.

---

## Grafik und Technik

- **Rendering:** Forward+ mit SSAO, SSIL, Glow, ACES-Tonemapping, Volumennebel, 4-stufige Sonnenschatten.
- **Gelände:** prozedural aus Rauschfeldern (Seen, Grate, Täler), Begehbarkeitsraster und Erreichbarkeitsprüfung; Material mit Gras, Erde, Fels, Sand und fraktionsspezifischen Basisböden (Betonplatten, Risse und Öl, festgefahrene Erde).
- **Vegetation:** Wind-animiertes Gras in Kacheln mit Sichtweiten-Ausblendung, Blumen, Büsche, Schilf, Nadel- und Laubbäume, verformte Felsen mit Moos. Gras verschwindet unter Gebäuden.
- **Vegetationszonen:** Wiese, trockene Steppe (hohes strohgelbes Gras), Heide und Moor (niedrig, rötlich, violette Blüten), Waldboden (dunkles Moos) und Fels und Geröll. Die Zonen gehen weich ineinander über, färben den Boden im Shader und steuern Dichte, Wuchshöhe, Farbe, Blumen und Büsche. Das Gras besteht aus dünnen, dicht stehenden Halmen in drei Wuchshöhen.
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
| `tools/blender/export_falke_game.py` | Westbund-Falke aus `models/source/west_falke.blend` als GLB für Godot |
| `tools/blender/make_soldier.py` | Soldaten (Infanterist, Panzerjäger, Arbeiter) je Fraktion, Rig und Animationen Idle/Walk/Shoot/Die |
| `tools/blender/make_west_hq.py`, `make_red_hq.py`, `make_shadow_hq.py` | Hauptquartiere |
| `tools/blender/make_factories.py <west\|red\|shadow>` | Fabriken |
| `tools/blender/make_barracks.py <west\|red\|shadow>` | Kasernen |
| `tools/blender/make_power.py <west\|red\|shadow>` | Kraftwerke (Fusionsreaktor, Kohlekraftwerk, Generatorenschuppen) |
| `tools/blender/make_supply.py <west\|red\|shadow>` | Nachschubgebäude (Logistikzentrum, Versorgungsdepot, Umschlagplatz) |
| `tools/blender/make_defense.py <west\|red\|shadow>` | Abwehr mit drehbarem Aufbau (Patriot, Gatling-Bunker, Stinger) |
| `tools/blender/make_tech.py <west\|red\|shadow>` | Forschung (Kuppellabor, Propagandazentrum, Schwarzmarkt) |
| `tools/blender/make_airfield.py <west\|red\|shadow>` | Flugfelder |
| `tools/blender/make_super.py <west\|red\|shadow>` | Superwaffen (Orbitalkanone, Atomsilo, Giftraketen-Silo) |
| `tools/blender/make_vehicles.py <modell>` | Lkw, Flak, Artillerie, Raketenwerfer, Scud-Träger, Koloss, Hubschrauber, Jäger (Turm, Rohr, Rotor als eigene Teile) |
| `tools/blender/make_ships.py <modell>` | Korvette, Kreuzer, Kanonenboot, Schlachtkreuzer, Kutter, Fregatte, Raketen-Schnellboot (Rot), Jetski-Räuber (Schatten), Oktober-U-Boot (Rot), Schmuggler-Tauchboot (Schatten), Atlas-Flugzeugträger (West) (gelofteter Rumpf, Turm/Rohr/Radar als eigene Teile; Flaggen, Besatzung, Rauch setzt `ships.gd:dress_custom` zur Laufzeit) |
| `tools/blender/make_docks.py <fraktion>` | Marinewerft, Schiffswerft, Schmugglerhafen (Halle, 9 m Steg mit Pfählen und Fendern, Kran bzw. Radar als drehendes Teil `Spin`) |
| `tools/blender/make_trucks.py <fraktion>` | Nachschub-Lkw je Fraktion: Kofferlaster (West), Armeelaster mit Plane (Rot), Schrott-Pickup (Schatten) |
| `tools/blender/sf_bld.py` | gemeinsame Bausteine der Gebäudeskripte (Materialien, Fenster, bewegliche Teile) |
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
| `--uitest` | Automatisierter Bedientest mit simulierten Mausklicks (`--nowarp`: echte Maus bleibt unbewegt, prüft den Betrieb ohne Fensterfokus) |
| `--verbose` | Meldet u.a. jede KI-Generalsfähigkeit mit Zeit und Ziel |

**Balance-Messreihe:** `tools/balance_test.ps1` simuliert KI-Gefechte ohne Fenster, rotiert Fraktionen und Startpositionen über mehrere Karten und fasst Überlebensquote, Abschüsse, Verluste und Skriptfehler je Fraktion zusammen:

```
powershell -File tools/balance_test.ps1 -Godot <pfad\zu\godot_console.exe> -Seeds "7,31,55" -Quit 650 -Out ergebnis.txt
```

---

## Stand und bekannte Lücken

**Spielbar:** Gefechte gegen KI und Zuschauermodus mit drei Fraktionen, Basisbau, Rohstoffwirtschaft, Land-, Luft- und Seeeinheiten, Generalsfähigkeiten und Superwaffen. Verfügbar sind 40 Standardkarten sowie ein Dialog für eigene Karten. Viele Einheiten und Gebäude haben eigene Blender-Modelle. Die [Modellübersicht](#eigene-modelle-und-blender-werkzeuge) listet die vorhandenen Exporte und die Modellskripte.

**Offen:**

- **Balance:** In KI-Messungen war die Schattenfront auffällig oft früh unterlegen; wird untersucht.
- **Helden:** Die Story-Helden sind noch keine spielbaren Einheiten.
- **Kampagne:** alle sieben Kapitel des Westbunds und Kapitel 1 der Roten Allianz sind spielbar; die übrigen Kapitel der Roten Allianz und die Schattenfront fehlen noch.
- **Musik:** nicht vorhanden. Stimmen und Geräusche gibt es (siehe Abschnitt Ton).
- **Mehrspieler:** nicht vorhanden.
- **Plattformen:** nur unter Windows 11 getestet.

---

*Alle Inhalte (Code, Modelle, Texte) sind Eigenentwicklungen. Das Spiel ist von Echtzeitstrategie-Klassikern inspiriert, verwendet aber keine fremden Namen, Marken oder Assets.*
