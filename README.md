# Stahlfront

Echtzeitstrategie in Godot 4.7: drei Fraktionen, Basisbau, Nachschub-Wirtschaft, Generalsfähigkeiten, Superwaffen, Nebel des Krieges und Computergegner.

## Starten

Godot 4.7 installieren und das Projekt öffnen oder direkt starten:

```
godot --path .
```

## Fraktionen

- **Westbund** – Hightech: Energieschilde, fliegende Baudrohnen, Spähdrohne, Laser, Orbitalkanone.
- **Rote Allianz** – Masse: Infanterie paarweise, Hordenbonus, schnellere Beförderung, Propaganda-Aura, Atomsilo.
- **Schattenfront** – Guerilla: Tarnung, Schrottbergung, Kopfgeld, kein Strom, Sprengwagen, Giftraketen.

## Steuerung

Linksklick wählen · Ziehen Rahmen · Rechtsklick Befehl · A Angriffsbewegung · S Stopp ·
Strg+1…9 Gruppen · Pfeiltasten/Rand/mittlere Maustaste Kamera · Mausrad Zoom · Q/E drehen ·
Leertaste letzte Meldung · H Hauptquartier · G Generalsfähigkeiten · F1 Hilfe.

## Eigene Modelle

`.glb`-Dateien in `models/units/` bzw. `models/buildings/` ersetzen die eingebauten Modelle
(Namen und Konventionen siehe `scripts/models.gd`). Beispiel: `tools/blender/make_tank.py`
erzeugt den Kampfpanzer mit gebackenen PBR-Texturen:

```
blender -b -P tools/blender/make_tank.py -- <projektordner>
```

## Testschalter

Nach `--`: `--autostart`, `--demo` (KI gegen KI), `--faction=red`, `--enemies=2`, `--difficulty=0..2`,
`--seed=N`, `--speed=N`, `--quit=SEK`, `--shot=PFAD --shotdelay=SEK`, `--battlecam`,
`--showcase=tank`, `--uitest`.
