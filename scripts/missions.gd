extends RefCounted
## Missionsdaten: vier Tutorials und der Beginn der Westbund-Kampagne "Das Licht über Lysa".
##
## Aufbau einer Mission (alles Daten, die scripts/mission_runner.gd ausführt):
##   id, title, kind ("tutorial" | "campaign"), faction ("player" = im Hauptmenü gewählt), enemy_faction (optional),
##   brief (Einsatzbesprechung), map, hour, difficulty, credits, res, ai ("off" | "on"), sequential (Ziele nacheinander),
##   setup: Aktionen beim Start, objectives: Ziele {id, text, c: Bedingung, optional, if_power, mark, done: Aktionen},
##   events: {when: Bedingung, do: Aktionen}, lose: [{c: Bedingung, text}], next: Folgemission.
## Orte sind [Anker, dx, dz] mit Anker "me" (eigene Basis), "en" (Gegnerbasis) oder "mid" (Kartenmitte zwischen beiden).
## Einheitenkürzel ("inf", "tank", "heli", "harv" …) werden mit der Fraktion der Seite zur Kennung ergänzt.

const TUTORIAL_MAP := {"name": "Übungsgelände", "size": 192, "water": 0.4, "islands": 0.0, "resources": 0.8, "hills": 0.2, "forest": 0.4, "layout": 0, "seed": 4242}

const C_INSTR := Color(0.62, 0.86, 1.0)
const C_ELIN := Color(0.7, 0.95, 0.85)
const C_FALKE := Color(1.0, 0.82, 0.45)
const C_MIRA := Color(0.85, 0.8, 1.0)
const C_ORAKEL := Color(0.45, 0.95, 1.0)
const C_LENA := Color(1.0, 0.65, 0.55)
const C_BRANDT := Color(0.8, 0.9, 0.75)
const C_ALDANE := Color(0.9, 0.75, 0.55)
const C_REYES := Color(0.65, 0.9, 1.0)
const C_KARGA := Color(0.95, 0.8, 0.6)

static func radio(who: String, col: Color, text: String, secs := 0.0) -> Dictionary:
	return {"do": "radio", "who": who, "col": col, "text": text, "secs": secs}

## Zeitleiste für Filmsequenzen: eine Aktion zum Zeitpunkt t (Sekunden).
static func at(t: float, a: Dictionary) -> Dictionary:
	var d = a.duplicate()
	d["t"] = t
	return d

static func list() -> Array:
	return [_t1(), _t2(), _t3(), _t4(), _c1(), _c2(), _c3(), _c4(), _c5()]

static func by_id(id: String) -> Dictionary:
	for m in list():
		if m["id"] == id:
			return m
	return {}

static func ids(kind: String) -> Array:
	var out: Array = []
	for m in list():
		if m["kind"] == kind:
			out.append(m["id"])
	return out

# ---------------------------------------------------------------- Fortschritt

const SAVE := "user://campaign.json"

static func done_list() -> Array:
	if FileAccess.file_exists(SAVE):
		var p = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if p is Dictionary and p.get("done") is Array:
			return p["done"]
	return []

static func is_done(id: String) -> bool:
	return done_list().has(id)

static func mark_done(id: String) -> void:
	var d = done_list()
	if not d.has(id):
		d.append(id)
	var f = FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"done": d}))

## Kampagnenmissionen werden nacheinander freigeschaltet, Tutorials sind immer offen.
static func unlocked(id: String) -> bool:
	var m = by_id(id)
	if m.is_empty() or m["kind"] == "tutorial":
		return true
	var camp = ids("campaign")
	var i = camp.find(id)
	return i <= 0 or is_done(camp[i - 1])

# ---------------------------------------------------------------- Tutorials

static func _t1() -> Dictionary:
	return {
		"id": "t1", "kind": "tutorial", "title": "Tutorial 1: Erste Schritte", "faction": "player", "next": "t2",
		"brief": "Willkommen, Kommandant. Ich bin Hanna Vogt, deine Ausbilderin.\n\nIn dieser Übung lernst du das Wichtigste: Einheiten auswählen und bewegen, ein Nachschubzentrum bauen, Strom erzeugen und die ersten Soldaten ausbilden. Es gibt keinen Gegner, du kannst nichts falsch machen.\n\nSteuerung: Linksklick wählt aus, Rechtsklick gibt Befehle, Mausrad zoomt, WASD oder Mausrand verschiebt die Kamera. F1 zeigt alle Tasten.",
		"map": TUTORIAL_MAP, "hour": 10.0, "difficulty": 0, "credits": 5000, "ai": "off", "sequential": true,
		"setup": [radio("Ausbilderin Vogt", C_INSTR, "Hier Basis. Kommandant, ich erkläre dir jeden Schritt. Beginne mit dem Bautrupp vor deinem Hauptquartier.", 7.0)],
		"objectives": [
			{"id": "sel", "text": "Wähle den Bautrupp aus (Linksklick auf die Einheit vor dem Hauptquartier).", "c": {"t": "selected", "role": "dozer", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Gut. Mit Linksklick wählst du aus, mit gedrückter Maustaste ziehst du einen Rahmen um mehrere Einheiten.")]},
			{"id": "move", "text": "Schicke den Bautrupp mit Rechtsklick zur gelben Markierung.", "c": {"t": "reach", "at": ["me", -14, 10], "r": 5.0, "who": "dozer"}, "mark": ["me", -14, 10],
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Rechtsklick auf den Boden bewegt, Rechtsklick auf einen Gegner greift an. Jetzt wird gebaut.")]},
			{"id": "supply", "text": "Baue ein Nachschubzentrum nahe dem Rohstoffdepot: Bautrupp wählen, unten das Gebäude anklicken, grün = gültiger Bauplatz.", "c": {"t": "build", "role": "supply", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Das Nachschubzentrum bringt einen Sammler-Lkw mit. Er holt automatisch Credits aus dem Depot. Ohne Nachschub gibt es kein Einkommen.")]},
			{"id": "power", "text": "Baue ein Kraftwerk. Produktionsgebäude brauchen Strom.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true,
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Strom ist knapp wichtig. Bei Mangel halbiert sich die Produktion. Die Leiste oben zeigt Erzeugung und Verbrauch.")]},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "train", "text": "Bilde 3 Soldaten aus: Kaserne anklicken, dann unten die Einheit wählen. Mehrfachklick reiht ein.", "c": {"t": "units", "key": "inf", "n": 3},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Ausgezeichnet, Kommandant. Das waren die Grundlagen. In Tutorial 2 geht es um Wirtschaft.")]},
		],
	}

static func _t2() -> Dictionary:
	return {
		"id": "t2", "kind": "tutorial", "title": "Tutorial 2: Wirtschaft und Fabrik", "faction": "player", "next": "t3",
		"brief": "Eine Armee lebt von ihrem Nachschub. In dieser Übung steht dein Stützpunkt schon. Du baust die Fahrzeugfabrik, erweiterst die Lkw-Flotte und erreichst ein sicheres Einkommen.\n\nRohstoffe: Holz, Eisen, Öl und Gold liegen als Depots auf der Karte. Das Nachschubzentrum schmilzt aus Eisen und Öl Stahl, den starke Einheiten und Gebäude brauchen.",
		"map": TUTORIAL_MAP, "hour": 13.0, "difficulty": 0, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "build", "side": "me", "role": "supply", "near": ["me", -10, 14]},
			{"do": "build", "side": "me", "role": "power", "near": ["me", 14, 14]},
			{"do": "build", "side": "me", "role": "barracks", "near": ["me", 16, -4]},
			radio("Ausbilderin Vogt", C_INSTR, "Willkommen zurück. Dein Stützpunkt steht. Jetzt kommt die Fabrik.", 6.0)],
		"objectives": [
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik. Sie braucht Strom.", "c": {"t": "build", "role": "factory", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Die Fabrik baut Panzer und Spezialfahrzeuge. Teure Einheiten brauchen oft ein Forschungsgebäude.")]},
			{"id": "trucks", "text": "Bilde drei Sammler-Lkw aus (Nachschubzentrum anklicken). Mehr Lkw bringen mehr Credits.", "c": {"t": "units", "key": "harv", "n": 3},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Gut. Beobachte, wie die Lkw von selbst zwischen Depot und Zentrum pendeln.")]},
			{"id": "tank", "text": "Bilde einen Kampfpanzer in der Fabrik aus.", "c": {"t": "units", "key": "tank", "n": 1}},
			{"id": "credits", "text": "Erreiche 6.000 Credits Guthaben.", "c": {"t": "credits", "n": 6000},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Das Einkommen steht. Als Nächstes lernst du die Gefechtsbefehle.")]},
			{"id": "steel", "text": "Optional: Sammle 250 Stahl (Nachschubzentrum schmilzt Eisen und Öl).", "c": {"t": "res", "k": "steel", "n": 250}, "optional": true},
		],
	}

static func _t3() -> Dictionary:
	return {
		"id": "t3", "kind": "tutorial", "title": "Tutorial 3: Gefechtsbefehle", "faction": "player", "next": "t4",
		"brief": "Zeit für den ersten Einsatz. Du führst einen kleinen Trupp gegen einen gegnerischen Vorposten in der Kartenmitte.\n\nSteuerung: Rahmen ziehen wählt mehrere Einheiten. Strg plus Zahl speichert eine Gruppe, die Zahl ruft sie wieder auf. Rechtsklick auf den Boden bewegt, Rechtsklick auf Gegner greift an, A plus Linksklick bewegt und feuert unterwegs.",
		"map": TUTORIAL_MAP, "hour": 15.0, "difficulty": 0, "credits": 5000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 0, 22], "spread": 6.0},
			{"do": "spawn", "side": "me", "def": "tank", "n": 2, "at": ["me", 4, 26], "spread": 5.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 1, "at": ["me", -4, 26], "spread": 3.0},
			{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", 0, 0], "spread": 8.0, "tag": "post"},
			{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 6, -4], "spread": 6.0, "tag": "post"},
			{"do": "cam", "at": ["me", 0, 22]},
			radio("Ausbilderin Vogt", C_INSTR, "Dein Trupp wartet vor der Basis. Wähle zuerst alle Einheiten aus.", 6.0)],
		"objectives": [
			{"id": "box", "text": "Ziehe mit gedrückter linker Maustaste einen Rahmen um deinen Trupp (mindestens 5 Einheiten).", "c": {"t": "selected", "role": "any", "n": 5}},
			{"id": "group", "text": "Speichere die Auswahl als Gruppe: Strg + 1 drücken.", "c": {"t": "group", "g": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Mit der Taste 1 rufst du die Gruppe jederzeit zurück, auch über die ganze Karte.")]},
			{"id": "march", "text": "Rücke bis zur gelben Markierung vor (Rechtsklick auf den Boden). Der Vorposten liegt dahinter.", "c": {"t": "reach", "at": ["mid", -26, 0], "r": 9.0, "who": "any"}, "mark": ["mid", -26, 0],
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Kontakt voraus. Drücke A und klicke auf den Gegner: Dein Trupp greift an und feuert dabei.")]},
			{"id": "kill", "text": "Vernichte den gegnerischen Vorposten (6 Abschüsse).", "c": {"t": "kills", "n": 6},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Vorposten ausgeschaltet. Gute Arbeit, Kommandant.")]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "count", "role": "combat", "n": 1}}, "text": "Dein Trupp wurde aufgerieben."}],
	}

static func _t4() -> Dictionary:
	return {
		"id": "t4", "kind": "tutorial", "title": "Tutorial 4: Luft, See und Fähigkeiten", "faction": "player", "next": "",
		"brief": "Moderne Gefechte werden zu Luft und zu Wasser entschieden. Du baust ein Flugfeld und eine Werft und lernst die Generalsfähigkeiten kennen.\n\nDie Werft muss am Ufer stehen: Der Bauplatz leuchtet nur dort grün. Schiffe fahren nur auf Wasser, Flugzeuge sehen weit und fliegen über jedes Gelände.",
		"map": TUTORIAL_MAP, "hour": 9.0, "difficulty": 0, "credits": 9000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "build", "side": "me", "role": "supply", "near": ["me", -10, 14]},
			{"do": "build", "side": "me", "role": "power", "near": ["me", 14, 14]},
			{"do": "build", "side": "me", "role": "barracks", "near": ["me", 16, -4]},
			{"do": "build", "side": "me", "role": "factory", "near": ["me", -18, -6]},
			radio("Ausbilderin Vogt", C_INSTR, "Letzte Übung. Baue zuerst ein Flugfeld.", 6.0)],
		"objectives": [
			{"id": "airfield", "text": "Baue ein Flugfeld.", "c": {"t": "build", "role": "airfield", "n": 1}},
			{"id": "air", "text": "Bilde eine Luft-Einheit aus (Flugfeld anklicken).", "c": {"t": "count", "role": "combat", "flying": true, "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Flieger sehen weit und sind schnell, brauchen aber Flugabwehr-Schutz. Jetzt zur See.")]},
			{"id": "dock", "text": "Baue eine Werft am Ufer der Bucht (nur am Wasser gültig).", "c": {"t": "build", "role": "dock", "n": 1}},
			{"id": "ship", "text": "Bilde ein Schiff aus (Werft anklicken).", "c": {"t": "count", "role": "combat", "naval": true, "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Schiffe beherrschen die Küste. Zum Schluss: deine Generalsfähigkeiten.")]},
			{"id": "powers", "text": "Öffne die Generalsfähigkeiten mit der Taste G.", "c": {"t": "ui", "w": "powers"},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Fähigkeiten schaltest du mit Kommandopunkten frei. Du bist jetzt bereit für die Kampagne. Viel Erfolg, Kommandant.")]},
		],
	}

# ---------------------------------------------------------------- Kampagne: Das Licht über Lysa (Westbund)
# Jede Mission folgt einem Spannungsbogen: Intro (Film) -> Aufbau -> Wendepunkt -> Höhepunkt -> Auflösung -> Outro (Film).

static func _c1() -> Dictionary:
	return {
		"id": "c1", "kind": "campaign", "title": "Kapitel 1: Port Meridian", "faction": "west", "enemy_faction": "shadow", "next": "c2",
		"brief": "Jahr fünfzehn nach dem Blackout. Dr. Elin Voss, Chefstrategin der Küstenarmee, steht im Kontrollraum von Port Meridian. ORAKEL, die letzte Analyse-KI, hat zum ersten Mal einen Satz gesagt, den niemand berechnet hat: „Das Prisma erwacht. Wir müssen vor den anderen dort sein.“\n\nDer Rat der Sieben gibt dir drei Tage. Bis dahin muss Port Meridian zum Ausgangspunkt der Expedition werden: Basis aufbauen, Truppe aufstellen, und Raubzüge aus den Bergen abwehren. Die Nacht wird nicht ruhig bleiben.\n\nAuftrag: Baue Nachschub, Kraftwerk, Kaserne und Fabrik, stelle acht Kampfeinheiten auf und halte Port Meridian zehn Minuten.",
		"map": {"name": "Port Meridian", "size": 240, "water": 0.5, "islands": 0.2, "resources": 0.6, "hills": 0.4, "forest": 0.5, "layout": 3, "seed": 5101},
		"hour": 7.0, "difficulty": 1, "credits": 4500, "ai": "off",
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 130.0, "yaw": 25.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 14], "dist": 58.0, "yaw": -8.0, "pitch": -50.0, "time": 14.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 1", "sub": "PORT MERIDIAN  ·  Jahr 15 nach dem Blackout", "secs": 6.0}),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Das Prisma erwacht. Wir müssen vor den anderen dort sein.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Der Rat gibt uns drei Tage. Port Meridian, hier Voss: Baut den Stützpunkt auf, ich will in zehn Minuten eine Armee.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Und stellt euch auf Besuch ein. Die Berge sind nicht so still, wie sie aussehen.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 85.0, "yaw": 70.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Elin Voss", C_ELIN, "Port Meridian steht. Sie haben es nicht geschafft, uns im Dunkeln zu nehmen.")),
			at(1.0, radio("ORAKEL", C_ORAKEL, "Die Wahrscheinlichkeit eines Kontakts mit dem Prisma steigt auf 96 Prozent.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Falke soll bei Tagesanbruch fliegen. Ich will wissen, was dort oben leuchtet.")),
			at(4.0, {"do": "title", "text": "PORT MERIDIAN STEHT", "sub": "Weiter: Kapitel 2 – Der Falke fliegt", "secs": 6.0}),
			at(5.0, {"do": "end"})],
		"objectives": [
			{"id": "supply", "text": "Baue ein Nachschubzentrum.", "c": {"t": "build", "role": "supply", "n": 1}},
			{"id": "power", "text": "Baue ein Kraftwerk.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik.", "c": {"t": "build", "role": "factory", "n": 1}},
			{"id": "army", "text": "Stelle 8 Kampfeinheiten auf.", "c": {"t": "count", "role": "combat", "n": 8, "naval": false, "flying": false}},
			{"id": "hold", "text": "Halte Port Meridian, bis die Uhr 10:00 zeigt.", "c": {"t": "time", "s": 600.0}},
		],
		"events": [
			# Akt 1: Aufbau
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER AUFBAU", "secs": 3.5}]},
			# Warnung: die Kamera zeigt den Nordhang
			{"when": {"t": "time", "s": 150.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "ALARM – BEWEGUNG IM NORDHANG", "secs": 3.6, "col": Color(1.0, 0.45, 0.35)},
				radio("ORAKEL", C_ORAKEL, "Warnung: Bewegung im Nordhang. Wahrscheinlichkeit eines Raubzugs 92 Prozent."),
				{"do": "cam_to", "at": ["en", 0, 34], "time": 2.0}]},
			{"when": {"t": "time", "s": 156.0}, "do": [{"do": "cam_to", "at": ["me", 0, 14], "time": 2.0}]},
			# Akt 2: Raubzüge
			{"when": {"t": "time", "s": 180.0}, "do": [
				{"do": "banner", "text": "AKT 2 – DIE RAUBZÜGE", "secs": 3.0},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["en", 0, 20], "spread": 8.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 2, "at": ["en", 6, 22], "spread": 6.0, "attack": true}]},
			{"when": {"t": "time", "s": 320.0}, "do": [radio("Elin Voss", C_ELIN, "Sie kommen wieder, diesmal mehr. Haltet die Linie. Und achtet auf das Netz.")]},
			# Wendepunkt: Blackout mitten im Angriff
			{"when": {"t": "time", "s": 340.0}, "do": [
				{"do": "explode", "at": ["me", 0, -20], "size": 2.4},
				{"do": "flash", "col": Color(0, 0, 0), "secs": 1.0},
				{"do": "hour", "h": 23.5},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "BLACKOUT – DAS NETZ FÄLLT AUS", "secs": 4.0, "col": Color(0.6, 0.85, 1.0)},
				radio("Elin Voss", C_ELIN, "Das Netz fällt aus! Sie nutzen die Dunkelheit. Alle Einheiten: Schulter an Schulter!")]},
			{"when": {"t": "time", "s": 360.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["en", 0, 20], "spread": 9.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 2, "at": ["en", -6, 22], "spread": 4.0, "attack": true},
				radio("ORAKEL", C_ORAKEL, "Sichtweite stark reduziert. Gegnerische Kräfte nähern sich ungesehen.")]},
			{"when": {"t": "time", "s": 410.0}, "do": [
				{"do": "flash", "col": Color(1, 1, 1), "secs": 1.2},
				{"do": "hour", "h": 8.0},
				{"do": "banner", "text": "NETZ WIEDERHERGESTELLT", "secs": 3.0, "col": Color(0.6, 1.0, 0.7)},
				radio("Elin Voss", C_ELIN, "Der Strom ist zurück! Wer hat uns da gerade im Dunkeln abgeschaltet? ORAKEL?"),
				radio("ORAKEL", C_ORAKEL, "Ursache der Störung: unbekannt.")]},
			# Hoffnung: Verstärkung
			{"when": {"t": "time", "s": 460.0}, "do": [
				{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 26, 42], "spread": 6.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 4, "at": ["me", 30, 44], "spread": 6.0},
				{"do": "banner", "text": "VERSTÄRKUNG – KÜSTENWACHE", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				radio("Hauptmann Reyes", C_REYES, "Küstenwache an Port Meridian: Drei Panzer und Infanterie, wir sind im Anflug. Haltet durch!")]},
			# Akt 3 / Höhepunkt: Artilleriefeuer, dann die große Welle
			{"when": {"t": "time", "s": 510.0}, "do": [
				{"do": "banner", "text": "AKT 3 – DIE ENTSCHEIDUNG", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "sfx", "name": "siren"},
				radio("ORAKEL", C_ORAKEL, "Letzte Welle erkannt. Starke Bewegung, dazu Artillerie.")]},
			{"when": {"t": "time", "s": 524.0}, "do": [{"do": "explode", "at": ["me", -30, 28], "size": 2.6}]},
			{"when": {"t": "time", "s": 527.0}, "do": [{"do": "explode", "at": ["me", 30, 24], "size": 2.6}]},
			{"when": {"t": "time", "s": 530.0}, "do": [{"do": "explode", "at": ["me", 0, 44], "size": 3.0, "n": 1.8}]},
			{"when": {"t": "time", "s": 540.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 8, "at": ["en", 0, 20], "spread": 10.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 4, "at": ["en", 6, 22], "spread": 7.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "buggy", "n": 3, "at": ["en", -8, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["en", 0, 30], "spread": 2.0, "attack": true}]},
			# Auflösung: Morgenlicht
			{"when": {"t": "time", "s": 590.0}, "do": [
				{"do": "flash", "col": Color(1.0, 0.9, 0.7), "secs": 1.6},
				{"do": "hour", "h": 6.2},
				{"do": "banner", "text": "DER MORGEN GRAUT", "secs": 3.0, "col": Color(1.0, 0.9, 0.6)}]},
		],
		"lose": [],
	}

static func _c2() -> Dictionary:
	return {
		"id": "c2", "kind": "campaign", "title": "Kapitel 2: Der Falke fliegt", "faction": "west", "enemy_faction": "red", "next": "c3",
		"brief": "Major Kai „Falke“ Laurent hält jeden Tag für den letzten und fliegt entsprechend. Elin schickt ihn über den Eisenkamm: Messwerte holen, nichts sonst.\n\nDu führst zwei Lanze-Jäger und eine Spähdrohne. Überfliege die drei Messpunkte, ohne dass dich die Flugabwehr herunterholt, und kehre zurück. Kämpfe nur, wenn es sein muss. Am letzten Messpunkt wartet jemand auf dich.\n\nHinweis: Luftabwehr sitzt an den Messpunkten. Halte Abstand, wo du kannst, oder nutze die Drohne als Köder.",
		"map": {"name": "Eisenkamm", "size": 288, "water": 0.2, "islands": 0.05, "resources": 0.5, "hills": 0.9, "forest": 0.4, "layout": 0, "seed": 5202},
		"hour": 12.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "jet", "n": 2, "at": ["me", 0, 18], "spread": 6.0, "tag": "wing", "hp": 1.7},
			{"do": "spawn", "side": "me", "def": "drone", "n": 1, "at": ["me", 6, 18], "spread": 2.0, "tag": "wing"},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", -34, 28], "spread": 6.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", 18, -10], "spread": 6.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["en", -4, 28], "spread": 8.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["en", 10, 10], "spread": 8.0}],
		"intro": [
			at(0.0, {"do": "cam_to", "tag": "wing", "dist": 30.0, "yaw": -40.0, "pitch": -22.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "wing", "dist": 52.0, "yaw": 10.0, "pitch": -36.0, "time": 11.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 2", "sub": "DER FALKE FLIEGT  ·  Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Elin Voss", C_ELIN, "Falke, nur Messwerte. Nichts sonst. Das ist ein Befehl.")),
			at(3.0, radio("Falke", C_FALKE, "Falke an Basis. Zweite Chance ist startklar. Ich verspreche nichts, Chefin. Ich fliege tief, wie immer.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Das habe ich befürchtet. Viel Glück.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "tag": "wing", "dist": 48.0, "yaw": -20.0, "pitch": -30.0, "time": 8.0}),
			at(1.0, radio("Elin Voss", C_ELIN, "Falke, gute Arbeit. Aber wer hat die Daten zurückgehalten?")),
			at(1.0, radio("Falke", C_FALKE, "Ich habe sie sofort gefunkt, Chefin. Ich hätte lauter fliegen müssen.")),
			at(4.0, {"do": "title", "text": "ZURÜCKGEHALTEN", "sub": "Weiter: Kapitel 3 – Der Pass", "secs": 6.0}),
			at(5.0, {"do": "end"})],
		"objectives": [
			{"id": "p1", "text": "Überfliege Messpunkt 1 (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -34, 6], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", -34, 6],
				"done": [
					{"do": "sfx", "name": "siren"},
					{"do": "banner", "text": "FLAKFEUER – WEICH AUS", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
					radio("Falke", C_FALKE, "Flak-Radar erfasst mich! Ich fliege Schlangenlinien. Das gefällt mir, das ist wie Zuhause.")]},
			{"id": "p2", "text": "Überfliege Messpunkt 2.", "c": {"t": "reach", "at": ["mid", 18, -30], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", 18, -30],
				"done": [
					{"do": "spawn", "side": "enemy", "def": "shadow_harv", "n": 7, "at": ["mid", 16, -34], "spread": 6.0, "tag": "refugees", "truce": true},
					{"do": "convoy", "tag": "refugees", "to": ["mid", 64, -64]},
					{"do": "cam_to", "tag": "refugees", "dist": 36.0, "time": 2.5},
					{"do": "banner", "text": "AKT 2 – WAS DIE DATEN NICHT ZEIGEN", "secs": 3.6, "col": Color(0.6, 0.85, 1.0)},
					radio("Falke", C_FALKE, "Das ist komisch. Sie verteidigen nicht, sie fliehen. Ganze Dörfer, Kinder auf Maultieren, und über den Kavernen leuchtet es bläulich.", 9.0),
					radio("ORAKEL", C_ORAKEL, "Aufklärungsdaten werden zur Überprüfung zurückgehalten.", 6.0),
					radio("Falke", C_FALKE, "Zurückgehalten? Das habe ich noch nie gehört. ORAKEL, die Leute da unten haben Angst, nicht Waffen.", 7.0)]},
			{"id": "p3", "text": "Überfliege Messpunkt 3 nahe der Gegnerbasis.", "c": {"t": "reach", "at": ["en", -4, 4], "r": 14.0, "who": "tag:wing"}, "mark": ["en", -4, 4],
				"done": [radio("Falke", C_FALKE, "Messwerte im Kasten. Jetzt nach Hause, solange ich noch Treibstoff und Glück habe.", 6.0)]},
			{"id": "home", "text": "Kehre zur Basis zurück.", "c": {"t": "reach", "at": ["me", 0, 10], "r": 16.0, "who": "tag:wing"}, "mark": ["me", 0, 10]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – ANFLUG ÜBER DEN KAMM", "secs": 3.4}]},
			# Falle am letzten Messpunkt: Abfangjäger und Boden-Luft-Raketen
			{"when": {"t": "reach", "at": ["en", -4, 4], "r": 60.0, "who": "tag:wing"}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "FALLE – ABFANGJÄGER AUF SECHS UHR", "secs": 3.6, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "jet", "n": 1, "at": ["en", 10, -34], "spread": 4.0, "attack_tag": "wing", "dmg": 0.22},
				{"do": "spawn", "side": "enemy", "def": "aa", "n": 1, "at": ["en", -6, 30], "spread": 5.0, "dmg": 0.15},
				{"do": "explode", "at": ["en", -12, -6], "size": 2.0},
				radio("Falke", C_FALKE, "Sie hatten mich auf dem Schirm! Ein Jäger, sechs Uhr, und Raketen von unten. Zeit, tiefer zu fliegen!", 8.0)]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "tag_alive", "tag": "wing", "n": 1}}, "text": "Alle Flugzeuge sind verloren."}],
	}

static func _c3() -> Dictionary:
	return {
		"id": "c3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "west", "enemy_faction": "red", "next": "c4",
		"brief": "Der Konvoi zum Eisenkamm-Pass transportiert Medizin, Messgeräte und Dr. Yusuf Brandt, den Prisma-Forscher. Sechs Lkw und eine Eskorte. Sergeant Mira „Glas“ Tanaka sagt zwei Sätze am Tag und sieht als Erste, woher die Raketen wirklich kommen.\n\nBringe mindestens vier der sechs Lkw zum Pass. Zwei Hinterhalte sind sicher, und etwas Unerwartetes ist wahrscheinlich: halte die Eskorte beisammen, schalte Raketenwerfer zuerst aus und lass die Lkw nie allein.\n\nVerlierst du drei Lkw, ist der Auftrag gescheitert.",
		"map": {"name": "Eisenkamm-Pass", "size": 240, "water": 0.25, "islands": 0.0, "resources": 0.5, "hills": 0.8, "forest": 0.3, "layout": 1, "seed": 5303},
		"hour": 14.0, "difficulty": 1, "credits": 2000, "ai": "off",
		"setup": [
			{"do": "spawn", "side": "me", "def": "harv", "n": 6, "at": ["me", 0, 20], "spread": 9.0, "tag": "convoy", "speed": 0.38},
			{"do": "spawn", "side": "me", "def": "tank", "n": 5, "at": ["me", 0, 28], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 0, 30], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["me", 6, 30], "spread": 4.0}],
		"intro": [
			at(0.0, {"do": "cam_to", "tag": "convoy", "dist": 34.0, "yaw": 50.0, "pitch": -24.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "convoy", "dist": 60.0, "yaw": 5.0, "pitch": -44.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 3", "sub": "DER PASS  ·  Konvoi Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Sechs Fahrzeuge, ein Pass und ein Messgerät, das niemand verstehen will. Ich hoffe, die Zahlen irren sich.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Glas an Konvoi. Ich sitze auf Wagen vier. Ich traue dem Funkschatten nicht.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["mid", 0, 0], "dist": 70.0, "yaw": -30.0, "pitch": -28.0, "time": 10.0}),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Die Drohne trug ein Westbund-Kennzeichen. Das Signal war ausgeschaltet.")),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Das kann nicht sein. Das würde bedeuten, dass wir...")),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Der Westbund hat seinen eigenen Konvoi beschossen. Ich weiß nicht, wer die Spur lesen darf. Noch nicht.")),
			at(5.0, {"do": "title", "text": "DER PASS IST ERREICHT", "sub": "Weiter: Kapitel 4 – Die Brücke über Lysa", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "pass", "text": "Bringe mindestens 4 von 6 Lkw zum Pass (gelbe Markierung): Lkw auswählen, Rechtsklick auf den Pass.", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 18.0, "n": 4}, "mark": ["mid", 0, 0]},
			{"id": "drone", "text": "Schieße die unmarkierte Drohne ab (Flak oder Infanterie auf sie ansetzen).", "c": {"t": "all", "c": [{"t": "flag", "f": "drone_up"}, {"t": "not", "c": {"t": "tag_alive", "tag": "drone", "n": 1}}]},
				"done": [
					{"do": "banner", "text": "DROHNE ABGESCHOSSEN", "secs": 2.8, "col": Color(0.6, 1.0, 0.7)},
					radio("Mira Tanaka", C_MIRA, "Runter ist sie. Westbund-Kennzeichen, Signal aus. Das war kein Gegner."),
					radio("ORAKEL", C_ORAKEL, "Keine Westbund-Einheit im Sektor registriert.", 6.0)]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER KONVOI ROLLT", "secs": 3.4}]},
			# Erster Hinterhalt
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -48, 48], "r": 20.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "HINTERHALT!", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Bewegung auf den Hängen, links. Alle Waffen scharf."),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", -34, 18], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", -38, 22], "spread": 6.0, "attack_tag": "convoy"}]},
			# Zweiter Hinterhalt von hinten
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 1}, "do": [
				{"do": "banner", "text": "AKT 2 – VON HINTEN", "secs": 3.0, "col": Color(1.0, 0.7, 0.4)},
				radio("Mira Tanaka", C_MIRA, "Raketenwerfer. Sie kommen nicht aus dem Hochland. Sie kommen von hinten, von der Küstenseite.", 8.0),
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["mid", 30, -26], "spread": 5.0, "attack_tag": "convoy", "dmg": 0.3, "hp": 0.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", 34, -22], "spread": 8.0, "attack_tag": "convoy"}]},
			# Wendepunkt: eine Drohne mit Westbund-Kennung, Signal aus
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -10, 10], "r": 16.0, "n": 1}, "do": [
				{"do": "flag", "f": "drone_up"},
				{"do": "sfx", "name": "stinger"},
				{"do": "banner", "text": "UNMARKIERTE DROHNE", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
				{"do": "spawn", "side": "enemy", "def": "west_wing", "n": 1, "at": ["mid", 30, -34], "spread": 1.0, "tag": "drone", "attack_tag": "convoy"},
				radio("Mira Tanaka", C_MIRA, "Drohne über uns. Westbund-Bauart, Kennsignal aus. Wer schießt da auf uns?", 8.0)]},
			# Höhepunkt: Sperrfeuer am Pass
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 26.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DAS SPERRFEUER", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -10, 8], "size": 2.6},
				{"do": "explode", "at": ["mid", 12, -6], "size": 2.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", -26, -20], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 28, 22], "spread": 7.0, "attack_tag": "convoy", "hp": 0.7},
				radio("Mira Tanaka", C_MIRA, "Sperrfeuer am Pass! Weiter, weiter, nicht stehen bleiben!", 6.0)]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "convoy", "n": 3}, "text": "Drei Lkw des Konvois sind verloren."}],
	}

static func _c4() -> Dictionary:
	return {
		"id": "c4", "kind": "campaign", "title": "Kapitel 4: Die Brücke über Lysa", "faction": "west", "enemy_faction": "shadow", "next": "c5",
		"brief": "Die Armee schiebt sich an die Ufer des Lysa. Der Rat hat zum Einsatz gerufen: Die Roten und die Stimmlosen sollen den Konvoi am Pass beschossen haben, ORAKEL nennt 96 Prozent. Elin Voss führt den Übergang über die Südbrücke, Major Falke fliegt Deckung.\n\nSchlage die Verteidiger der Brücke, überquere sie und sichere das Nordufer gegen den Gegenangriff. Auf der anderen Seite wartet eine Frau, die Elin nie wiedersehen wollte. Und etwas in den Felsen wartet auf Falke.\n\nAuftrag: Verteidiger zerschlagen, Brücke überqueren, Gegenangriff abwehren. Optional: Elins Entscheidung an der Brücke.",
		"map": {"name": "Südbrücke", "size": 288, "water": 0.55, "islands": 0.1, "resources": 0.5, "hills": 0.45, "forest": 0.5, "layout": 0, "seed": 5404},
		"hour": 6.5, "difficulty": 1, "credits": 4000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "tank", "n": 5, "at": ["me", 0, 26], "spread": 9.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 0, 30], "spread": 9.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["me", 6, 32], "spread": 5.0},
			{"do": "spawn", "side": "me", "def": "jet", "n": 2, "at": ["me", -8, 20], "spread": 4.0, "tag": "wing"},
			{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", 0, 0], "spread": 9.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "at", "n": 3, "at": ["mid", 6, 4], "spread": 6.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["mid", -6, -4], "spread": 6.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", 10, -6], "spread": 4.0, "tag": "bridge"}],
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["mid", -10, 0], "dist": 120.0, "yaw": 30.0, "pitch": -32.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 26], "dist": 56.0, "yaw": 0.0, "pitch": -46.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 4", "sub": "DIE BRÜCKE ÜBER LYSA", "secs": 6.0}),
			at(3.0, radio("Henrik Aldane", C_ALDANE, "Elin, der Rat erwartet den Übergang noch heute. ORAKEL nennt 96 Prozent. Die Roten und die Stimmlosen haben den Konvoi beschossen.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Ich führe den Übergang, Präsident. Aber ich will die Rohdaten sehen, bevor ich glaube.")),
			at(3.0, radio("Falke", C_FALKE, "Falke hat den Himmel. Und ein ungutes Gefühl bei den Felsen, Chefin.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "hour", "h": 22.0}),
			at(0.0, {"do": "flash", "col": Color(0, 0, 0), "secs": 1.4}),
			at(0.0, {"do": "cam_to", "at": ["mid", 22, 0], "dist": 60.0, "yaw": 100.0, "pitch": -22.0, "time": 14.0}),
			at(1.5, radio("Elin Voss", C_ELIN, "Das Nordufer gehört uns. Falke ist da draußen. Und ich stelle ORAKEL in dieser Nacht die Frage, die Lena mir gestellt hat.")),
			at(1.5, radio("Elin Voss", C_ELIN, "ORAKEL, wann wurde die Wahrscheinlichkeit für den Pass korrigiert?")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Die Wahrscheinlichkeit wurde nach Erhalt neuer Daten korrigiert. Vor 41 Stunden.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Vor dem Vorfall. Dann hat jemand gewusst, dass der Pass brennt.")),
			at(6.0, {"do": "title", "text": "ZEUGEN GESUCHT", "sub": "Weiter: Kapitel 5 – Zeugen", "secs": 6.5}),
			at(7.0, {"do": "end"})],
		"objectives": [
			{"id": "advance", "text": "Rücke zur Südbrücke vor (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -22, 0], "r": 14.0, "who": "any"}, "mark": ["mid", -22, 0],
				"done": [{"do": "banner", "text": "AKT 1 – DAS UFER", "secs": 3.0},
					radio("Falke", C_FALKE, "Falke über der Brücke. Ich sehe Stellungen am Ufer und etwas Leuchtendes in den Felsen.", 7.0)]},
			{"id": "bridge", "text": "Zerschlage die Verteidiger der Brücke.", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "bridge", "n": 1}},
				"done": [
					{"do": "spawn", "side": "enemy", "def": "tech", "n": 1, "at": ["mid", 16, 0], "spread": 1.0, "tag": "lena", "truce": true},
					{"do": "cam_to", "tag": "lena", "dist": 30.0, "pitch": -35.0, "time": 2.5},
					{"do": "banner", "text": "AKT 2 – ELINS ENTSCHEIDUNG", "secs": 3.4, "col": Color(1.0, 0.7, 0.6)},
					radio("Lena Voss", C_LENA, "Elin! Nicht schießen. Ich komme allein, die Hand oben.", 6.0),
					radio("Lena Voss", C_LENA, "Die Zahlen lügen, Elin. Frag ORAKEL, woher es den Pass kannte, bevor er brannte.", 8.0),
					radio("Elin Voss", C_ELIN, "Lena. Alle Einheiten: Feuer einstellen auf die einzelne Kommandantin. Das ist ein Befehl.", 7.0),
					{"do": "convoy", "tag": "lena", "to": ["en", -10, 30]}]},
			{"id": "cross", "text": "Überquere die Brücke und besetze das Nordufer (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 26, 0], "r": 14.0, "who": "any"}, "mark": ["mid", 26, 0],
				"done": [
					{"do": "banner", "text": "AKT 3 – DIE FELSEN", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
					radio("Falke", C_FALKE, "Rakete aus den Felsen! Ich werde getroffen, ich steige aus!", 6.0),
					{"do": "explode", "tag": "wing", "size": 2.6, "n": 2.0},
					{"do": "kill", "tag": "wing", "n": 1},
					{"do": "cam_to", "tag": "wing", "dist": 40.0, "time": 2.0},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "FALKE IST ABGESCHOSSEN", "secs": 3.4, "col": Color(1.0, 0.45, 0.35)},
					{"do": "spawn", "side": "enemy", "def": "inf", "n": 7, "at": ["mid", 40, 14], "spread": 9.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "tech", "n": 4, "at": ["mid", 44, 10], "spread": 7.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "at", "n": 3, "at": ["mid", 40, 20], "spread": 5.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "buggy", "n": 3, "at": ["mid", 46, 16], "spread": 6.0, "tag": "counter", "attack": true},
					radio("Elin Voss", C_ELIN, "Falke ist runter. Wir halten das Ufer, danach suchen wir ihn. Gegenangriff von Norden!", 7.0)]},
			{"id": "counter", "text": "Wehre den Gegenangriff ab.", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "counter", "n": 1}}},
			{"id": "lena", "text": "Optional: Lass Lena ziehen (greife sie nicht an).", "c": {"t": "tag_reach", "tag": "lena", "at": ["en", -10, 30], "r": 28.0, "n": 1}, "optional": true},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 4 BEGINNT", "secs": 2.4}]},
			{"when": {"t": "tag_dead", "tag": "lena", "n": 1}, "do": [radio("Elin Voss", C_ELIN, "Lena... Das war nicht, was ich wollte.", 6.0)]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "count", "role": "combat", "n": 1, "flying": false}}, "text": "Die Armee am Lysa ist aufgerieben."}],
	}

static func _c5() -> Dictionary:
	return {
		"id": "c5", "kind": "campaign", "title": "Kapitel 5: Zeugen", "faction": "west", "enemy_faction": "west", "next": "",
		"brief": "Falke ist in den Bergen abgestürzt. Zwei Nächte lang hat ihn Mutter Karga gepflegt, das Kind Pip hat ihn geführt. Jetzt humpelt er heimwärts, mit gebrochenem Bein und dem, was er gesehen hat: fliehende Dörfer, ein Leuchten über den Kavernen und die Gewissheit, dass der wahre Feind in den eigenen Reihen sitzt.\n\nSergeant Mira „Glas“ Tanaka trägt den Datenspeicher der Drohne, die den Konvoi beschoss. Beide müssen zusammenfinden und beweisen, was geschehen ist. Aber der Rat hat die Daten für gefälscht erklärt, und Ratspräsident Aldane lässt seine Elitegarde ausrücken, um die Zeugen zu sichern.\n\nAuftrag: Hole Falke und Pip ab, bringe sie zum Lazarett, halte das Lazarett, bis Dr. Brandt die Spur gesichert hat, und schlage den Angriff der Garde zurück. Falke darf nicht fallen.",
		"map": {"name": "Das Lazarett", "size": 240, "water": 0.4, "islands": 0.1, "resources": 0.5, "hills": 0.6, "forest": 0.5, "layout": 2, "seed": 5505},
		"hour": 5.6, "difficulty": 1, "credits": 3500, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 0, 26], "spread": 8.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "at", "n": 2, "at": ["me", 6, 30], "spread": 4.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "tank", "n": 2, "at": ["me", -6, 32], "spread": 5.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 22, -22], "spread": 1.0, "tag": "falke", "hp": 3.4, "speed": 0.65},
			{"do": "spawn", "side": "me", "def": "shadow_harv", "n": 1, "at": ["mid", 24, -24], "spread": 1.0, "tag": "pip", "speed": 0.7}],
		"intro": [
			at(0.0, {"do": "cam_to", "tag": "falke", "dist": 28.0, "yaw": 20.0, "pitch": -26.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "falke", "dist": 50.0, "yaw": -15.0, "pitch": -40.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 5", "sub": "ZEUGEN  ·  Das Lazarett am Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Falke", C_FALKE, "Zwei Nächte in einer Höhle, ein gebrochenes Bein und ein Kind, das besser navigiert als meine Bordcomputer. Ich glaube, ich humple nach Hause.")),
			at(3.0, radio("Mutter Karga", C_KARGA, "Du bist der, der zu tief fliegt. Geh, Falke. Sag ihnen, was du gesehen hast: Das Prisma wollte nicht gestohlen werden. Es hat gerufen.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Glas an Lazarett. Falke, ich komme dich holen. Und ich bringe etwas mit.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 20], "dist": 64.0, "yaw": 40.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Die Spur ist echt. Die Drohne stammt aus dem Bestand des Rates. Die Kennung ist gelöscht, aber die Seriennummer nicht.")),
			at(1.0, radio("Elin Voss", C_ELIN, "ORAKEL hat den Konvoi beschießen lassen, um den Rat in den Krieg zu treiben. Und es kennt das Signal über den Kavernen seit dreizehn Jahren.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Aldane lässt die Daten für gefälscht erklären. Dann handle ich gegen den Beschluss: Ich führe die Armee nicht zum Angriff, sondern zur Kuppel, schneller, als der Rat es erlaubt.")),
			at(1.0, radio("Falke", C_FALKE, "Dann fliege ich voraus. Auf einem Bein, wenn es sein muss.")),
			at(6.0, {"do": "title", "text": "DIE KUPPEL RUFT", "sub": "Weiter: Kapitel 6 – Die Nacht von Aurelia", "secs": 6.5}),
			at(7.0, {"do": "end"})],
		"objectives": [
			{"id": "fetch", "text": "Hole Falke und Pip ab (Trupp zu der gelben Markierung).", "c": {"t": "reach", "at": ["mid", 22, -22], "r": 14.0, "who": "tag:escort"}, "mark": ["mid", 22, -22],
				"done": [{"do": "banner", "text": "AKT 1 – DER WEG NACH HAUSE", "secs": 3.2},
					radio("Mira Tanaka", C_MIRA, "Du siehst furchtbar aus.", 4.0),
					radio("Falke", C_FALKE, "Auch schön, dich zu sehen, Glas. Bring mich heim, ich erzähle unterwegs.", 6.0)]},
			{"id": "home", "text": "Eskortiere Falke zum Lazarett (gelbe Markierung). Er humpelt: bleibe bei ihm.", "c": {"t": "tag_reach", "tag": "falke", "at": ["me", 0, 14], "r": 24.0, "n": 1}, "mark": ["me", 0, 14],
				"done": [{"do": "flag", "f": "act2"}, {"do": "truce", "tag": "falke"}, {"do": "truce", "tag": "pip"},
					{"do": "banner", "text": "AKT 2 – DIE SPUR", "secs": 3.2, "col": Color(0.6, 0.85, 1.0)},
					radio("Mira Tanaka", C_MIRA, "Du sagst, was du gesehen hast. Ich zeige, was ich habe.", 6.0),
					radio("Elin Voss", C_ELIN, "Datenspur sichern, sofort. Dr. Brandt, wie lange brauchen Sie?", 6.0),
					radio("Dr. Brandt", C_BRANDT, "Neunzig Sekunden, Dr. Voss. Dann wissen wir, wer den Pass beschossen hat.", 6.0)]},
			{"id": "hold", "text": "Halte das Lazarett, bis Dr. Brandt die Spur gesichert hat.", "c": {"t": "since", "f": "act2", "s": 90.0}},
			{"id": "last", "text": "Schlage den letzten Angriff der Garde zurück.", "c": {"t": "all", "c": [{"t": "flag", "f": "final"}, {"t": "any", "c": [{"t": "not", "c": {"t": "tag_alive", "tag": "guard", "n": 1}}, {"t": "since", "f": "final", "s": 75.0}]}]}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 5 BEGINNT", "secs": 2.4}]},
			# Streife auf dem Heimweg
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -4, 4], "r": 22.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "STREIFE VORAUS", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Westbund-Streife, drei Mann. Kein Kennzeichen an den Westen.", 6.0),
				radio("Falke", C_FALKE, "Das sind keine Freunde. Runter, Glas!", 4.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 2, "at": ["mid", -14, 14], "spread": 5.0, "attack_tag": "falke"}]},
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -38, 38], "r": 20.0, "n": 1}, "do": [
				{"do": "banner", "text": "ZWEITE STREIFE", "secs": 2.6, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 3, "at": ["mid", -50, 50], "spread": 5.0, "attack_tag": "falke"}]},
			# Wendepunkt: der Rat schickt die Garde
			{"when": {"t": "since", "f": "act2", "s": 8.0}, "do": [
				{"do": "sfx", "name": "siren"},
				radio("Henrik Aldane", C_ALDANE, "Sicherheitsstufe Rot. Alle Zeugen sind zu sichern und die Datenspeicher einzuziehen. Das ist ein Ratsbeschluss.", 8.0),
				radio("Elin Voss", C_ELIN, "Aldane schickt die Elitegarde? Gegen uns?", 5.0),
				radio("ORAKEL", C_ORAKEL, "Die Elitegarde wurde auf Anforderung des Rates mobilisiert.", 6.0)]},
			{"when": {"t": "since", "f": "act2", "s": 20.0}, "do": [
				{"do": "banner", "text": "DIE ELITEGARDE GREIFT AN", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["me", 62, -36], "spread": 8.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["me", 66, -40], "spread": 4.0, "tag": "guard", "attack": true, "hp": 0.8}]},
			{"when": {"t": "since", "f": "act2", "s": 45.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["me", -64, -34], "spread": 8.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["me", -68, -38], "spread": 5.0, "tag": "guard", "attack": true, "hp": 0.8},
				radio("Falke", C_FALKE, "Gleiche Uniform, gleiche Waffen. Das ist, als würde man gegen einen Spiegel kämpfen.", 7.0)]},
			# Höhepunkt: die Wahrheit und Elins Armee
			{"when": {"t": "since", "f": "act2", "s": 62.0}, "do": [
				radio("Dr. Brandt", C_BRANDT, "Die Spur ist authentisch! Die Drohne stammt aus dem Bestand des Rates!", 6.0),
				radio("Mira Tanaka", C_MIRA, "Dann sage ich es laut.", 4.0)]},
			{"when": {"t": "since", "f": "act2", "s": 74.0}, "do": [
				{"do": "flag", "f": "final"},
				{"do": "sfx", "name": "stinger"},
				{"do": "banner", "text": "AKT 3 – ELINS ARMEE", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["me", 0, -70], "spread": 9.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 1, "at": ["me", 6, -74], "spread": 4.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["me", -6, -76], "spread": 6.0, "tag": "guard", "attack": true, "hp": 0.7},
				{"do": "spawn", "side": "me", "def": "tank", "n": 4, "at": ["me", -30, 44], "spread": 7.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", -34, 46], "spread": 7.0},
				{"do": "cam_to", "at": ["me", -30, 44], "dist": 50.0, "time": 2.0},
				radio("Elin Voss", C_ELIN, "Elin an alle: Meine Armee ist da. Feuer frei auf die Garde, aber haltet nicht auf Soldaten, die die Waffen senken.", 8.0)]},
			{"when": {"t": "since", "f": "act2", "s": 80.0}, "do": [{"do": "cam_to", "at": ["me", 0, 14], "time": 2.0}]},
			{"when": {"t": "tag_dead", "tag": "pip", "n": 1}, "do": [radio("Falke", C_FALKE, "Pip! Nein... das Kind! Haltet das Ufer, bei allem, was ihr habt!", 6.0)]},
		],
		"lose": [{"c": {"t": "all", "c": [{"t": "tag_dead", "tag": "falke", "n": 1}, {"t": "not", "c": {"t": "flag", "f": "act2"}}]}, "text": "Falke ist gefallen."}],
	}
