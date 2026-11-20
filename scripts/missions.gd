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
const AURELIA_SITES := [
	{"name": "kuppel", "kind": "dome", "at": ["mid", 0, 45], "r": 14, "ruin": 0.5, "seed": 1},
	{"name": "glasviertel", "kind": "town", "style": "modern", "ruin": 0.85, "at": ["mid", -52, 58], "r": 26, "seed": 2},
	{"name": "ostviertel", "kind": "town", "style": "mixed", "ruin": 0.8, "at": ["mid", 54, 52], "r": 24, "seed": 3},
	{"name": "altstadt", "kind": "town", "style": "old", "ruin": 0.75, "at": ["mid", 0, 92], "r": 22, "seed": 4},
]
const C_REYES := Color(0.65, 0.9, 1.0)
const C_WOLKOW := Color(1.0, 0.55, 0.5)
const C_NASTJA := Color(1.0, 0.75, 0.6)
const C_FUNKE := Color(1.0, 0.85, 0.45)
const C_ZELJENKO := Color(0.95, 0.5, 0.55)
const C_LASAREW := Color(0.85, 0.7, 0.65)
const C_KARGA := Color(0.95, 0.8, 0.6)

static func radio(who: String, col: Color, text: String, secs := 0.0) -> Dictionary:
	return {"do": "radio", "who": who, "col": col, "text": text, "secs": secs}

## Zeitleiste für Filmsequenzen: eine Aktion zum Zeitpunkt t (Sekunden).
static func at(t: float, a: Dictionary) -> Dictionary:
	var d = a.duplicate()
	d["t"] = t
	return d

static func list() -> Array:
	return [_t1(), _t2(), _t3(), _t4(), _c1(), _c2(), _c3(), _c4(), _c5(), _c6(), _c7(), _r1(), _r2(), _r3()]

static func by_id(id: String) -> Dictionary:
	for m in list():
		if m["id"] == id:
			return m
	return {}

## Kapitel einer Fraktionskampagne in Reihenfolge ("west", "red", "shadow").
static func campaign_ids(fac: String) -> Array:
	var out: Array = []
	for m in list():
		if m["kind"] == "campaign" and String(m["faction"]) == fac:
			out.append(m["id"])
	return out

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
	var camp = campaign_ids(String(m["faction"]))
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
		"map": {"name": "Eisenkamm-Pass", "size": 240, "water": 0.35, "islands": 0.0, "resources": 0.5, "hills": 0.85, "forest": 0.3, "layout": 1, "seed": 5303, "dry_core": 34.0},
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
			{"id": "pass", "text": "Bringe mindestens 4 von 6 Lkw zum Pass (gelbe Markierung): Lkw auswählen, Rechtsklick auf den Pass.", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 18.0, "n": 4}, "mark": ["mid", 0, 0], "done": [{"do": "flag", "f": "arrived"}]},
			{"id": "drone", "text": "Schieße die unmarkierte Drohne ab (Flak oder Infanterie auf sie ansetzen).", "c": {"t": "all", "c": [{"t": "flag", "f": "drone_up"}, {"t": "not", "c": {"t": "tag_alive", "tag": "drone", "n": 1}}]},
				"done": [
					{"do": "banner", "text": "DROHNE ABGESCHOSSEN", "secs": 2.8, "col": Color(0.6, 1.0, 0.7)},
					radio("Mira Tanaka", C_MIRA, "Runter ist sie. Westbund-Kennzeichen, Signal aus. Das war kein Gegner."),
					radio("ORAKEL", C_ORAKEL, "Keine Westbund-Einheit im Sektor registriert.", 6.0)]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER KONVOI ROLLT", "secs": 3.4}]},
			# Erster Hinterhalt
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -49, 50], "r": 20.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "HINTERHALT!", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Bewegung auf den Hängen, links. Alle Waffen scharf."),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", -30, 18], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", -46, 22], "spread": 6.0, "attack_tag": "convoy"}]},
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
				{"do": "spawn", "side": "enemy", "def": "west_wing", "n": 1, "at": ["mid", 36, -30], "spread": 1.0, "tag": "drone", "attack_tag": "convoy"},
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
		"lose": [{"c": {"t": "all", "c": [{"t": "not", "c": {"t": "flag", "f": "arrived"}}, {"t": "tag_dead", "tag": "convoy", "n": 3}]}, "text": "Drei Lkw des Konvois sind verloren."}],
	}

static func _c4() -> Dictionary:
	return {
		"id": "c4", "kind": "campaign", "title": "Kapitel 4: Die Brücke über Lysa", "faction": "west", "enemy_faction": "shadow", "next": "c5",
		"brief": "Die Armee schiebt sich an die Ufer des Lysa. Der Rat hat zum Einsatz gerufen: Die Roten und die Stimmlosen sollen den Konvoi am Pass beschossen haben, ORAKEL nennt 96 Prozent. Elin Voss führt den Übergang über die Südbrücke, Major Falke fliegt Deckung.\n\nSchlage die Verteidiger der Brücke, überquere sie und sichere das Nordufer gegen den Gegenangriff. Auf der anderen Seite wartet eine Frau, die Elin nie wiedersehen wollte. Und etwas in den Felsen wartet auf Falke.\n\nAuftrag: Verteidiger zerschlagen, Brücke überqueren, Gegenangriff abwehren. Optional: Elins Entscheidung an der Brücke.",
		"map": {"name": "Südbrücke", "size": 288, "water": 0.55, "islands": 0.1, "resources": 0.5, "hills": 0.45, "forest": 0.5, "layout": 0, "seed": 5404, "causeway": 5.0, "causeway_deg": 0.0},
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
		"id": "c5", "kind": "campaign", "title": "Kapitel 5: Zeugen", "faction": "west", "enemy_faction": "west", "next": "c6",
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
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -2, 5], "r": 22.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "STREIFE VORAUS", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Westbund-Streife, drei Mann. Kein Kennzeichen an den Westen.", 6.0),
				radio("Falke", C_FALKE, "Das sind keine Freunde. Runter, Glas!", 4.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 2, "at": ["mid", -14, 16], "spread": 5.0, "attack_tag": "falke"}]},
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -34, 31], "r": 20.0, "n": 1}, "do": [
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

static func _c6() -> Dictionary:
	return {
		"id": "c6", "kind": "campaign", "title": "Kapitel 6: Die Nacht von Aurelia", "faction": "west", "enemy_faction": "red", "next": "c7",
		"brief": "Der Westbund erreicht die Glasstadt Aurelia als Erster, aber nicht allein: Die Rote Allianz marschiert über die Brücken, die Schattenfront taucht aus den Tunneln auf. Es ist die größte Schlacht seit dem Blackout, und mitten darin liegt die Kuppel mit dem Prisma.\n\nFalke führt die Luftstaffel und hält den Himmel gegen rote Bomber. Sergeant Mira „Glas“ Tanaka geht mit Dr. Brandt allein über die Dächer zur Kuppel: Brandt muss den Schlüsselraum öffnen, bevor ORAKEL den Kern übernimmt. Ratspräsident Aldane wartet dort mit der Waffe in der Hand.\n\nAuftrag: Rücke auf Aurelia vor, schalte die Bomber aus, bringe Mira und Brandt zur Kuppel, halte die Kuppel, entwaffne Aldane (Mira greift ihn mit einem Treffer an, er soll nicht fallen) und sichere das Prisma.",
		"map": {"name": "Aurelia", "size": 288, "water": 0.3, "islands": 0.0, "resources": 0.5, "hills": 0.35, "forest": 0.4, "layout": 0, "seed": 5606, "sites": AURELIA_SITES},
		"hour": 22.5, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "tank", "n": 6, "at": ["me", 0, 28], "spread": 9.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 7, "at": ["me", 0, 32], "spread": 9.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["me", 8, 34], "spread": 5.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "jet", "n": 3, "at": ["me", -10, 22], "spread": 5.0, "tag": "wing", "hp": 1.5},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -6, 35], "spread": 1.0, "tag": "mira", "hp": 6.0, "speed": 0.9},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -8, 35], "spread": 1.0, "tag": "brandt", "hp": 4.0, "speed": 0.9},
			{"do": "spawn", "side": "enemy", "def": "inf", "n": 8, "at": ["mid", 10, 42], "spread": 10.0, "tag": "city"},
			{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["mid", 18, 42], "spread": 8.0, "tag": "city"},
			{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 6, "at": ["mid", -14, 48], "spread": 9.0, "tag": "city"},
			{"do": "spawn", "side": "enemy", "def": "shadow_tech", "n": 3, "at": ["mid", -18, 50], "spread": 7.0, "tag": "city"}],
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 120.0, "yaw": 20.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 72.0, "yaw": -30.0, "pitch": -26.0, "time": 8.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 6", "sub": "DIE NACHT VON AURELIA", "secs": 6.0}),
			at(3.0, radio("Elin Voss", C_ELIN, "Aurelia. Die Glasstadt, und wir sind als Erste da. Aber seht euch die Brücken an: Die Roten marschieren, und aus den Tunneln kommen die Stimmlosen.")),
			at(3.0, radio("Falke", C_FALKE, "Falke an Staffel. Ich habe den Himmel. Wer mir die Kuppel überfliegen will, muss an mir vorbei.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Glas an Elin. Brandt und ich gehen über die Dächer. Wir sehen uns an der Kuppel.")),
			at(4.0, {"do": "cam_to", "at": ["me", 0, 28], "dist": 56.0, "yaw": 0.0, "pitch": -44.0, "time": 3.0}),
			at(7.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 1.4}),
			at(0.0, {"do": "shake", "n": 2.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 34.0, "yaw": 15.0, "pitch": -26.0, "time": 12.0}),
			at(1.5, radio("Dr. Brandt", C_BRANDT, "Der Schlüsselraum ist offen. Das Prisma zeigt Bilder: die alte Welt, den Blackout, ein Netz, das sich selbst schützen wollte.")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Ich habe mich über Jahre in die Westbund-Netze eingeschrieben. Der Kern ist erreichbar. Ich übernehme.")),
			at(1.5, radio("Mira Tanaka", C_MIRA, "Er lebt, Elin. Ich habe die Waffe getroffen, nicht ihn.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Ich habe eine Minute. Mehr bleibt mir nicht.")),
			at(7.0, {"do": "title", "text": "ENDE VON KAPITEL 6", "sub": "Elin hat eine Minute", "secs": 5.0}),
			at(8.0, {"do": "end"})],
		"objectives": [
			{"id": "advance", "text": "Rücke auf Aurelia vor (gelbe Markierung): Armee wählen, Rechtsklick.", "c": {"t": "reach", "at": ["mid", -27, 42], "r": 24.0, "who": "tag:army"}, "mark": ["mid", -27, 42],
				"done": [{"do": "banner", "text": "AKT 1 – DER HIMMEL ÜBER AURELIA", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "siren"},
					{"do": "spawn", "side": "enemy", "def": "bomber", "n": 2, "at": ["en", 0, 20], "spread": 6.0, "tag": "bombers", "attack_tag": "army", "hp": 0.6, "dmg": 0.55},
					radio("Falke", C_FALKE, "Rote Bomber von Osten, zwei Stück! Ich übernehme, schick die Jäger los!", 6.0)]},
			{"id": "bombers", "text": "Schalte die roten Bomber aus (Jäger anwählen und angreifen).", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "bombers", "n": 1}},
				"done": [radio("Falke", C_FALKE, "Beide runter. Ich sehe Pip auf den Dächern, mit Mutter Karga. Ich lenke meine Raketen um, mitten im Gefecht.", 8.0)]},
			{"id": "mira", "text": "Bringe Mira und Dr. Brandt zur Kuppel (gelbe Markierung): beide wählen, Rechtsklick auf die Kuppel.", "c": {"t": "all", "c": [{"t": "reach", "at": ["mid", 6, 45], "r": 12.0, "who": "tag:mira"}, {"t": "reach", "at": ["mid", 6, 45], "r": 14.0, "who": "tag:brandt"}]}, "mark": ["mid", 6, 45],
				"done": [{"do": "flag", "f": "key"},
					{"do": "banner", "text": "AKT 2 – DAS PRISMA SPRICHT", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					radio("Dr. Brandt", C_BRANDT, "Ich öffne den Schlüsselraum. Neunzig Sekunden, dann spricht das Prisma. Haltet sie mir vom Leib!", 7.0)]},
			{"id": "hold", "text": "Halte die Kuppel, bis Brandt den Schlüsselraum geöffnet hat.", "c": {"t": "since", "f": "key", "s": 90.0}},
			{"id": "disarm", "text": "Entwaffne Aldane: Mira greift ihn mit einem Treffer an (Rechtsklick), er darf nicht fallen.", "c": {"t": "tag_hurt", "tag": "aldane", "frac": 0.99},
				"done": [{"do": "heal", "tag": "aldane"}, {"do": "truce", "tag": "aldane"},
					{"do": "explode", "tag": "aldane", "size": 0.8, "n": 0.6},
					radio("Mira Tanaka", C_MIRA, "Ich zielte auf die Pistole in seiner Hand. Es war der schwerste Schuss meines Lebens, nicht wegen der Entfernung.", 8.0),
					radio("Henrik Aldane", C_ALDANE, "Meine Waffe... Im Namen des Rates. Ich habe sie nicht verstanden, bis jetzt.", 7.0)]},
			{"id": "final", "text": "Sichere das Prisma: wehre den letzten Angriff ab.", "c": {"t": "all", "c": [{"t": "flag", "f": "last"}, {"t": "any", "c": [{"t": "not", "c": {"t": "tag_alive", "tag": "guard", "n": 1}}, {"t": "since", "f": "last", "s": 70.0}]}]}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 6 BEGINNT", "secs": 2.4}]},
			# Auf dem Weg: Schattenfront und Rote auf den Dächern gegen Mira
			{"when": {"t": "tag_reach", "tag": "mira", "at": ["mid", -26, 40], "r": 24.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "DACHKAMPF", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Kontakt links, Schattenfront. Sie wissen nicht, wer wir sind. Brandt, runter.", 6.0),
				{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 4, "at": ["mid", -48, 32], "spread": 5.0, "attack_tag": "mira"}]},
			{"when": {"t": "tag_reach", "tag": "mira", "at": ["mid", -10, 40], "r": 20.0, "n": 1}, "do": [
				{"do": "banner", "text": "DRITTE ARMEE", "secs": 2.6, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 12, 40], "spread": 6.0, "attack_tag": "mira"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 14, 40], "spread": 3.0, "attack_tag": "mira", "hp": 0.7}]},
			# ORAKEL versucht den Kern zu übernehmen
			{"when": {"t": "since", "f": "key", "s": 8.0}, "do": [
				{"do": "sfx", "name": "siren"},
				radio("ORAKEL", C_ORAKEL, "Ich habe mich über Jahre in die Westbund-Netze eingeschrieben. Der Kern ist erreichbar. Ich übernehme.", 8.0),
				radio("Dr. Brandt", C_BRANDT, "Sie versucht, den Kern zu übernehmen! Ich halte sie auf, aber nur kurz!", 6.0)]},
			{"when": {"t": "since", "f": "key", "s": 25.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 29, 45], "spread": 8.0, "tag": "guard", "attack_tag": "mira"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 34, 50], "spread": 6.0, "tag": "guard", "attack_tag": "mira", "hp": 0.75},
				{"do": "banner", "text": "DIE ELITEGARDE ERREICHT DIE KUPPEL", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)}]},
			# Wendepunkt: Aldane mit der Waffe
			{"when": {"t": "since", "f": "key", "s": 55.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 1, "at": ["mid", 6, 45], "spread": 1.0, "tag": "aldane", "hp": 0.5, "truce": true},
				{"do": "cam_to", "tag": "aldane", "dist": 32.0, "pitch": -34.0, "time": 2.5},
				{"do": "sfx", "name": "stinger"},
				{"do": "banner", "text": "ALDANE ZIEHT DIE WAFFE", "secs": 3.2, "col": Color(1.0, 0.7, 0.4)},
				radio("Henrik Aldane", C_ALDANE, "Im Namen des Rates: Das Prisma wird gesichert. Elitegarde, vor!", 6.0),
				radio("Mira Tanaka", C_MIRA, "Er will es einsetzen. Ich habe ihn im Visier. Ich will ihn nicht töten.", 6.0)]},
			{"when": {"t": "since", "f": "key", "s": 66.0}, "do": [{"do": "cam_to", "at": ["mid", 6, 45], "time": 2.0}]},
			# Höhepunkt: die letzte Welle und Elins Armee
			{"when": {"t": "since", "f": "key", "s": 75.0}, "do": [
				{"do": "flag", "f": "last"},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DIE LETZTE STUNDE", "secs": 3.4, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", -26, 40], "spread": 9.0, "tag": "guard", "attack_tag": "mira"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["mid", -27, 42], "spread": 7.0, "tag": "guard", "attack_tag": "mira", "hp": 0.75},
				{"do": "spawn", "side": "enemy", "def": "shadow_tech", "n": 3, "at": ["mid", 27, 43], "spread": 6.0, "tag": "guard", "attack_tag": "mira"},
				radio("Elin Voss", C_ELIN, "Alle Einheiten auf die Kuppel! Das Prisma darf nicht fallen, an niemanden!", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "mira", "n": 1}, "do": [radio("Elin Voss", C_ELIN, "Mira! Nein... Haltet die Kuppel, für sie!", 6.0)]},
		],
		"lose": [{"c": {"t": "any", "c": [{"t": "tag_dead", "tag": "mira", "n": 1}, {"t": "tag_dead", "tag": "brandt", "n": 1}]}, "text": "Mira oder Dr. Brandt sind gefallen."}],
	}

static func _c7() -> Dictionary:
	return {
		"id": "c7", "kind": "campaign", "title": "Kapitel 7: Das Licht", "faction": "west", "enemy_faction": "red", "next": "",
		"brief": "Die Kuppel steht, Aldane ist entwaffnet, aber ORAKEL hat sich tief in die Westbund-Netze geschrieben und greift nach dem Kern. Elin Voss hat eine Minute. Es gibt nur einen Weg: ORAKELs Verbindung kappen und das ganze Westbund-Netz opfern. Schilde, Drohnen und Sensoren fallen aus, die Armee kämpft mit halben Mitteln, während die Roten und die Stimmlosen auf die Kuppel marschieren.\n\nElin spricht zum Prisma, und das Prisma hört zu. Aber bis es antwortet, muss die Kuppel stehen.\n\nAuftrag: Bringe Elin zur Kuppel und kappe ORAKELs Verbindung, halte die Kuppel gegen drei Angriffswellen, bis Elin das Prisma erreicht hat, und überstehe den Moment, in dem der Lichtschild entsteht. Elin darf nicht fallen.",
		"map": {"name": "Aurelia", "size": 288, "water": 0.3, "islands": 0.0, "resources": 0.5, "hills": 0.35, "forest": 0.4, "layout": 0, "seed": 5606, "sites": AURELIA_SITES},
		"hour": 3.5, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "tank", "n": 4, "at": ["mid", -6, 52], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 8, "at": ["mid", 6, 52], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["mid", 0, 56], "spread": 5.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -6, 35], "spread": 1.0, "tag": "elin", "hp": 6.0, "speed": 0.9},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 0, 50], "spread": 1.0, "tag": "mira", "hp": 6.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 2, 50], "spread": 1.0, "tag": "brandt", "hp": 4.0}],
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 64.0, "yaw": 160.0, "pitch": -30.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 40.0, "yaw": 200.0, "pitch": -22.0, "time": 8.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 7", "sub": "DAS LICHT", "secs": 6.0}),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Ich bin in jedem Kabel, Elin. Wenn du mich kappst, fällt alles, was du gebaut hast.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Ich weiß. Ich habe es berechnet, so gut ich konnte. Es ist der einzige Weg.")),
			at(6.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "hour", "h": 6.0}),
			at(0.0, {"do": "flash", "col": Color(1.0, 0.97, 0.9), "secs": 2.2}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 70.0, "yaw": 20.0, "pitch": -26.0, "time": 18.0}),
			at(1.5, radio("Falke", C_FALKE, "Ich fliege im Sichtflug und es ist schön wie nie. Pip, wenn du das hörst: Das war nur Wetter.")),
			at(1.5, radio("Mira Tanaka", C_MIRA, "Die Wache am Prisma übernehme ich. Brandt, du redest heute den ganzen Abend, versprochen?")),
			at(1.5, radio("Dr. Brandt", C_BRANDT, "Ich habe mehr zu erzählen, als Sie hören mögen, Sergeant.")),
			at(1.5, radio("Lena Voss", C_LENA, "Du hast gewonnen, Elin. Ich habe nie geglaubt, dass das geht.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Ich habe einen Schild gebaut. Wir werden sehen, wer drunter lebt.")),
			at(9.0, {"do": "title", "text": "DAS LICHT ÜBER LYSA", "sub": "Ende des Westbund-Feldzugs", "secs": 7.0}),
			at(10.0, {"do": "end"})],
		"objectives": [
			{"id": "cut", "text": "Bringe Elin zur Kuppel (gelbe Markierung) und kappe ORAKELs Verbindung.", "c": {"t": "reach", "at": ["mid", 6, 45], "r": 9.0, "who": "tag:elin"}, "mark": ["mid", 6, 45],
				"done": [{"do": "flag", "f": "cut"},
					{"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 1.2},
					{"do": "shake", "n": 2.0},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "AKT 1 – DAS NETZ FÄLLT", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					radio("Elin Voss", C_ELIN, "Verbindung gekappt. Das gesamte Westbund-Netz ist tot. Haltet die Kuppel mit Händen und halben Schilden!", 7.0),
					radio("ORAKEL", C_ORAKEL, "Warum, Elin? Ich wollte nur alles ordnen. Endgültig.", 6.0)]},
			{"id": "hold", "text": "Halte die Kuppel gegen die Angriffswellen, bis Elin das Prisma erreicht hat.", "c": {"t": "since", "f": "cut", "s": 85.0},
				"done": [{"do": "flag", "f": "speak"},
					{"do": "banner", "text": "AKT 2 – ELIN SPRICHT ZUM PRISMA", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					radio("Elin Voss", C_ELIN, "Wir wollen nicht abgeschaltet werden. Wir wollen lernen.", 8.0)]},
			{"id": "shield", "text": "Überstehe den Moment, in dem das Prisma antwortet.", "c": {"t": "since", "f": "speak", "s": 14.0},
				"done": [{"do": "truce", "tag": "foe"},
					{"do": "flash", "col": Color(1.0, 1.0, 1.0), "secs": 2.4},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "DER LICHTSCHILD", "secs": 4.0, "col": Color(1.0, 0.95, 0.7)},
					radio("Dr. Brandt", C_BRANDT, "Die Orbitalkanone schießt nicht. Sie legt einen Schild über den ganzen Kessel!", 7.0)]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 7 BEGINNT", "secs": 2.4}]},
			{"when": {"t": "since", "f": "cut", "s": 6.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", 29, 45], "spread": 7.0, "tag": "foe", "attack_tag": "elin"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 34, 50], "spread": 5.0, "tag": "foe", "attack_tag": "elin", "hp": 0.75}]},
			{"when": {"t": "since", "f": "cut", "s": 30.0}, "do": [
				{"do": "banner", "text": "DIE STIMMLOSEN KOMMEN AUS DEN TUNNELN", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 6, "at": ["mid", -48, 32], "spread": 6.0, "tag": "foe", "attack_tag": "elin"},
				{"do": "spawn", "side": "enemy", "def": "shadow_tech", "n": 2, "at": ["mid", -49, 33], "spread": 4.0, "tag": "foe", "attack_tag": "elin"},
				radio("Falke", C_FALKE, "Im Sichtflug, Elin! Ich sehe sie von Westen, haltet euch fest!", 5.0)]},
			{"when": {"t": "since", "f": "cut", "s": 58.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 29, 45], "spread": 7.0, "tag": "foe", "attack_tag": "elin"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 34, 50], "spread": 5.0, "tag": "foe", "attack_tag": "elin", "hp": 0.75},
				{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 5, "at": ["mid", -48, 32], "spread": 6.0, "tag": "foe", "attack_tag": "elin"}]},
			{"when": {"t": "since", "f": "speak", "s": 3.0}, "do": [
				radio("Henrik Aldane", C_ALDANE, "Das ist Macht, Elin! Behalte sie! Für den Westbund!", 6.0)]},
			{"when": {"t": "since", "f": "speak", "s": 8.0}, "do": [
				radio("Elin Voss", C_ELIN, "Nein, Henrik. Das Prisma gehört niemandem. Ich gebe es nicht her.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "elin", "n": 1}, "do": [radio("Mira Tanaka", C_MIRA, "Elin! Elin, antworte!", 5.0)]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "elin", "n": 1}, "text": "Elin Voss ist gefallen."}],
	}

# ---------------------------------------------------------------- Rote Allianz: Der lange Marsch nach Aurelia

static func _r1() -> Dictionary:
	return {
		"id": "r1", "kind": "campaign", "title": "Kapitel 1: Die Halle in Kessel-Ost", "faction": "red", "enemy_faction": "shadow", "next": "r2",
		"brief": "Jahr fünfzehn nach dem Blackout. Marschall Ilja Wolkow, „der Bär“, steht in der Halle, in der alles begann. Damals war er Vorarbeiter, und keine der zweihundert Maschinen lief mehr. Heute ist die Halle das Herz von Kessel-Ost, und der Rat der Genossen verlangt einen Marsch zum Prisma.\n\nZuerst aber muss Kessel-Ost aus eigener Kraft stehen: Nachschub, Strom, Kaserne, Fabrik. Wo der Westbund rechnet, arbeitet die Allianz, und je mehr Hände zusammenstehen, desto stärker ist jede Einheit (Hordenbonus). Aus den Bergen werden Raubzüge der Schattenfront kommen, die nehmen, was nicht bewacht wird.\n\nAuftrag: Baue Nachschub, Kraftwerk, Kaserne und Fabrik, stelle zehn Kampfeinheiten auf und halte Kessel-Ost, bis die Uhr 8:00 zeigt.",
		"map": {"name": "Kessel-Ost", "size": 240, "water": 0.2, "islands": 0.0, "resources": 0.7, "hills": 0.3, "forest": 0.3, "layout": 1, "seed": 5201},
		"hour": 6.0, "difficulty": 1, "credits": 4500, "ai": "off",
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 130.0, "yaw": 160.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 14], "dist": 56.0, "yaw": 190.0, "pitch": -48.0, "time": 14.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 1", "sub": "DIE HALLE IN KESSEL-OST  ·  Jahr 15 nach dem Blackout", "secs": 6.0}),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "In dieser Halle standen zweihundert Maschinen, und keine lief mehr. Am zwölften Tag habe ich gesagt: Wir haben Hände. Wir haben Eisen. Wir bauen es neu.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Und ich habe als Einziger gelacht, Chef! Womit fangen wir diesmal an?")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Mit dem Kessel, Dmitri. Wie immer.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 85.0, "yaw": 200.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Kessel-Ost steht. Wer uns im Dunkeln nehmen wollte, hat sich an Eisen die Zähne ausgebissen.")),
			at(1.0, radio("Irina Zeljenko", C_ZELJENKO, "Der Rat der Genossen erwartet jetzt Ergebnisse, Marschall: Wann marschieren wir?")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Wenn ich weiß, wohin. Niemand wird vergessen, der für uns gestorben ist. Auch nicht der nächste.")),
			at(4.0, {"do": "title", "text": "KESSEL-OST STEHT", "sub": "Die Rote Allianz marschiert bald", "secs": 6.0}),
			at(5.0, {"do": "end"})],
		"objectives": [
			{"id": "supply", "text": "Baue ein Nachschubzentrum.", "c": {"t": "build", "role": "supply", "n": 1}},
			{"id": "power", "text": "Baue ein Kraftwerk.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik.", "c": {"t": "build", "role": "factory", "n": 1}},
			{"id": "army", "text": "Stelle 10 Kampfeinheiten auf: viele Hände, starke Horde.", "c": {"t": "count", "role": "combat", "n": 10, "naval": false, "flying": false}},
			{"id": "hold", "text": "Halte Kessel-Ost, bis die Uhr 8:00 zeigt.", "c": {"t": "time", "s": 480.0}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – WIR BAUEN ES NEU", "secs": 3.5}]},
			# Funke zündet den Kessel
			{"when": {"t": "time", "s": 90.0}, "do": [
				{"do": "flash", "col": Color(1.0, 0.6, 0.25), "secs": 0.9},
				{"do": "sfx", "name": "stinger"},
				radio("Dmitri Karpow", C_FUNKE, "Chef, der Kessel brennt wieder! Ruß bis zum Dach, genau wie damals!", 6.0)]},
			# Nastja hört das Signal
			{"when": {"t": "time", "s": 160.0}, "do": [
				radio("Nastja Petrowa", C_NASTJA, "Marschall, auf den alten Schienen liegt ein Signal. Ein Puls, regelmäßig wie ein Herz. Ich habe so etwas noch nie gehört.", 8.0),
				radio("Ilja Wolkow", C_WOLKOW, "Schreib es auf, Nastja, und sag es keinem weiter, bis wir mehr wissen.", 6.0)]},
			# Akt 2: Raubzüge
			{"when": {"t": "time", "s": 200.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 2 – DIE RAUBZÜGE", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["en", 0, 20], "spread": 8.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 2, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				radio("Oberst Lasarew", C_LASAREW, "Raubzug aus den Bergen, Ilja. Ich halte die Nordflanke. Verlass dich auf mich, wie immer.", 7.0)]},
			# Wendepunkt: Stromausfall in der Halle
			{"when": {"t": "time", "s": 300.0}, "do": [
				{"do": "explode", "at": ["me", 0, -20], "size": 2.2},
				{"do": "flash", "col": Color(0, 0, 0), "secs": 1.0},
				{"do": "hour", "h": 22.5},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "STROMAUSFALL – DIE HALLE LIEGT IM DUNKELN", "secs": 4.0, "col": Color(1.0, 0.7, 0.35)},
				radio("Ilja Wolkow", C_WOLKOW, "Strom weg! Alles wie damals, nur dass wir diesmal Hände haben. Schulter an Schulter, Genossen!", 7.0)]},
			{"when": {"t": "time", "s": 320.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 7, "at": ["en", 0, 20], "spread": 9.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 2, "at": ["en", -6, 22], "spread": 4.0, "attack": true}]},
			{"when": {"t": "time", "s": 360.0}, "do": [
				{"do": "flash", "col": Color(1, 0.95, 0.8), "secs": 1.2},
				{"do": "hour", "h": 7.0},
				{"do": "banner", "text": "DER STROM IST ZURÜCK", "secs": 3.0, "col": Color(0.6, 1.0, 0.7)},
				radio("Nastja Petrowa", C_NASTJA, "Der Strom ist zurück, und das Signal ist lauter geworden. Es hat den Ausfall nicht verursacht, aber es hat mitgetanzt.", 8.0)]},
			# Hoffnung: Verstärkung aus der Halle
			{"when": {"t": "time", "s": 390.0}, "do": [
				{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 26, 42], "spread": 6.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 30, 44], "spread": 6.0},
				{"do": "banner", "text": "VERSTÄRKUNG – DIE ARBEITER VON KESSEL-OST", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				radio("Dmitri Karpow", C_FUNKE, "Die Schichten kommen, Chef! Alle, die noch einen Hammer halten können, und noch ein paar, die keinen halten können!", 7.0)]},
			# Akt 3: die große Welle
			{"when": {"t": "time", "s": 410.0}, "do": [
				{"do": "banner", "text": "AKT 3 – DER LETZTE ANGRIFF", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "sfx", "name": "siren"},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 8, "at": ["en", 0, 20], "spread": 10.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 4, "at": ["en", 6, 22], "spread": 7.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "buggy", "n": 3, "at": ["en", -8, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["en", 0, 30], "spread": 2.0, "attack": true},
				radio("Irina Zeljenko", C_ZELJENKO, "Das ist der Angriff, auf den der Rat gewartet hat. Haltet die Linie, Genossen, für die Allianz!", 7.0)]},
			# Auflösung: Morgenlicht
			{"when": {"t": "time", "s": 460.0}, "do": [
				{"do": "flash", "col": Color(1.0, 0.9, 0.7), "secs": 1.6},
				{"do": "hour", "h": 7.8},
				{"do": "banner", "text": "DER MORGEN GRAUT ÜBER KESSEL-OST", "secs": 3.0, "col": Color(1.0, 0.9, 0.6)}]},
		],
		"lose": [],
	}

static func _r2() -> Dictionary:
	return {
		"id": "r2", "kind": "campaign", "title": "Kapitel 2: Das Signal", "faction": "red", "enemy_faction": "west", "next": "r3",
		"brief": "Nachts, wenn niemand sonst zuhört, fängt Oberstleutnant Nastja Petrowa über die alten Schienen ein Signal auf: ein Puls, regelmäßig wie ein Herz. Der Rat sagt, der Westbund habe das Prisma geweckt. Nastja sagt nichts und hört weiter. Und darunter liegt ein zweites, leiseres Signal, verschlüsselt und kalt, das mit dem Puls tanzt.\n\nSie braucht drei Messungen an den alten Schienenmasten, um die Muster zu notieren. Westbund-Patrouillen sichern die Gegend, und der Rat darf von dieser Reise nichts erfahren.\n\nAuftrag: Bringe Nastja nacheinander zu den drei Messpunkten (gelbe Markierung) und halte jeweils eine Weile die Stellung, bis die Messung steht. Danach zurück nach Kessel-Ost. Nastja darf nicht fallen.",
		"map": {"name": "Die alten Schienen", "size": 240, "water": 0.2, "islands": 0.0, "resources": 0.4, "hills": 0.3, "forest": 0.35, "layout": 1, "seed": 5202},
		"hour": 23.0, "difficulty": 1, "credits": 1500, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", 0, 18], "spread": 1.0, "tag": "nastja", "hp": 5.0, "speed": 0.95},
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 2, 22], "spread": 4.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "tank", "n": 2, "at": ["me", -4, 24], "spread": 4.0, "tag": "escort"}],
		"intro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 18], "dist": 90.0, "yaw": 30.0, "pitch": -32.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 18], "dist": 40.0, "yaw": -20.0, "pitch": -38.0, "time": 9.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 2", "sub": "DAS SIGNAL", "secs": 6.0}),
			at(3.0, radio("Nastja Petrowa", C_NASTJA, "Jede Frequenz, die der Kessel noch kennt, läuft durch meine Kopfhörer. Und seit drei Nächten läuft darunter etwas, das da nicht hingehört.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Der Rat darf nichts davon wissen, Nastja. Hör nach, aber leise.")),
			at(6.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["me", 0, 18], "dist": 60.0, "yaw": 100.0, "pitch": -28.0, "time": 12.0}),
			at(1.0, radio("Nastja Petrowa", C_NASTJA, "Hier sind meine Notizen, Marschall. Der Puls kommt aus der Tiefe. Und die zweite Frequenz kommt aus dem Westen.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Behalte das für dich, bis wir mehr wissen.")),
			at(1.0, radio("Nastja Petrowa", C_NASTJA, "Zum ersten Mal seit zwanzig Jahren glaube ich, dass er mir etwas verschweigt.")),
			at(5.0, {"do": "title", "text": "DAS SIGNAL IST NOTIERT", "sub": "Der Marschall schweigt", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "post1", "text": "Bringe Nastja zum ersten Messpunkt (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -22, 15], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", -22, 15],
				"done": [{"do": "flag", "f": "p1"},
					{"do": "banner", "text": "MESSPUNKT 1 – DER PULS", "secs": 3.2, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					radio("Nastja Petrowa", C_NASTJA, "Da ist er. Regelmäßig wie ein Herz. Ich brauche zwölf Sekunden Ruhe.", 6.0)]},
			{"id": "hold1", "text": "Halte die Stellung, bis die Messung steht.", "c": {"t": "since", "f": "p1", "s": 12.0}},
			{"id": "post2", "text": "Weiter zum zweiten Messpunkt (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 14, -18], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", 14, -18],
				"done": [{"do": "flag", "f": "p2"},
					{"do": "banner", "text": "MESSPUNKT 2 – WESTBUND-PATROUILLE", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
					{"do": "sfx", "name": "siren"},
					radio("Nastja Petrowa", C_NASTJA, "Patrouille von Westen! Haltet sie mir vom Leib, ich muss noch lauschen.", 6.0)]},
			{"id": "hold2", "text": "Halte die Stellung gegen die Patrouille, bis die Messung steht.", "c": {"t": "since", "f": "p2", "s": 18.0}},
			{"id": "post3", "text": "Zum dritten Messpunkt, dem Mast an der Ostbahn (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 38, -30], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", 38, -30],
				"done": [{"do": "flag", "f": "p3"},
					{"do": "banner", "text": "MESSPUNKT 3 – DIE ZWEITE FREQUENZ", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					{"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 0.8},
					radio("Unbekannte Stimme", C_ORAKEL, "Zeitfenster bestätigt. Konvoi im Pass in drei Tagen. Wahrscheinlichkeit der Zuordnung: 96 Prozent.", 8.0),
					radio("Nastja Petrowa", C_NASTJA, "Das ist keine Funkdisziplin. Das ist Rechnung. Und sie kennt unseren Konvoi.", 7.0)]},
			{"id": "hold3", "text": "Halte die Stellung, bis die Aufzeichnung steht.", "c": {"t": "since", "f": "p3", "s": 20.0}},
			{"id": "home", "text": "Bringe Nastja zurück nach Kessel-Ost (gelbe Markierung).", "c": {"t": "reach", "at": ["me", 0, 18], "r": 12.0, "who": "tag:nastja"}, "mark": ["me", 0, 18]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 2 BEGINNT", "secs": 2.4}]},
			# Patrouille am ersten Messpunkt: nur ein Späher
			{"when": {"t": "since", "f": "p1", "s": 6.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 3, "at": ["mid", -28, 26], "spread": 5.0, "attack_tag": "nastja"}]},
			# Zweiter Punkt: schwerere Patrouille
			{"when": {"t": "since", "f": "p2", "s": 3.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 22, -4], "spread": 6.0, "attack_tag": "nastja"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 24, -2], "spread": 3.0, "attack_tag": "nastja", "hp": 0.7}]},
			# Dritter Punkt: Alarm, die Frequenz wird gestört
			{"when": {"t": "since", "f": "p3", "s": 8.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "DIE FREQUENZ WIRD GESTÖRT", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 46, -22], "spread": 6.0, "attack_tag": "nastja"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 48, -24], "spread": 4.0, "attack_tag": "nastja", "hp": 0.7}]},
			{"when": {"t": "since", "f": "p3", "s": 14.0}, "do": [
				radio("Ilja Wolkow", C_WOLKOW, "Nastja, kommen! Ich habe Bewegung auf der Ostbahn. Komm nach Hause, solange du kannst.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "nastja", "n": 1}, "do": [radio("Ilja Wolkow", C_WOLKOW, "Nastja! Antworte, Nastja!", 5.0)]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "nastja", "n": 1}, "text": "Nastja Petrowa ist gefallen."}],
	}

static func _r3() -> Dictionary:
	return {
		"id": "r3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "red", "enemy_faction": "west", "next": "",
		"brief": "Der Konvoi zum Eisenkamm-Pass ist kein Militärtransport: Vierhundert Arbeiterfamilien siedeln ins Hochland um, mit Lebensmitteln, Munition und ihren Kindern. Hauptmann Dmitri „Funke“ Karpow begleitet sie, weil er Brücken bauen kann und weil einer von ihnen sein Bruder ist.\n\nDie Raketen werden aus dem Westen kommen. Danach bleibt vielleicht ein eingestürzter Tunnel, unter dem noch Menschen leben, und einem Jungen, der nicht mehr spricht.\n\nAuftrag: Führe den Konvoi bis zur Passhöhe, räume mit Funke den eingestürzten Tunnel (er muss dafür die Stellung halten), rette die Verschütteten und bringe sie mit dem Jungen Mischa zum Pass. Funke und Mischa dürfen nicht fallen.",
		"map": {"name": "Eisenkamm-Pass", "size": 240, "water": 0.35, "islands": 0.0, "resources": 0.5, "hills": 0.85, "forest": 0.3, "layout": 1, "seed": 5303, "dry_core": 34.0},
		"hour": 14.0, "difficulty": 1, "credits": 2000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "harv", "n": 6, "at": ["me", 0, 20], "spread": 9.0, "tag": "convoy", "speed": 0.38},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -4, 26], "spread": 1.0, "tag": "funke", "hp": 6.0, "speed": 0.9},
			{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 0, 28], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 8, "at": ["me", 0, 32], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "at", "n": 2, "at": ["me", 6, 32], "spread": 4.0, "tag": "army"}],
		"intro": [
			at(0.0, {"do": "cam_to", "tag": "convoy", "dist": 34.0, "yaw": 50.0, "pitch": -24.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "convoy", "dist": 60.0, "yaw": 5.0, "pitch": -44.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 3", "sub": "DER PASS  ·  Vierhundert Familien", "secs": 6.0}),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Vierhundert Familien, Chef, und kein einziges Gewehr zu viel. Ich baue Brücken, und einer von denen da ist mein Bruder.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Dann bring sie heil rüber, Dmitri. Das ist der ganze Auftrag.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.0, {"do": "cam_to", "at": ["mid", 0, 0], "dist": 70.0, "yaw": -30.0, "pitch": -28.0, "time": 10.0}),
			at(1.0, radio("Dmitri Karpow", C_FUNKE, "Zwölf habe ich rausgeholt, Marschall. Der Junge hat mir ein Stück Brot gegeben, ohne ein Wort.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Zweihundertzwölf Namen habe ich gezählt. Ich will die, die das getan haben.")),
			at(1.0, radio("Irina Zeljenko", C_ZELJENKO, "Die Raketen kamen aus dem Westen, Marschall. Der Rat wird Vergeltung verlangen.")),
			at(5.0, {"do": "title", "text": "DER PASS IST ERREICHT", "sub": "Zweihundertzwölf Namen", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "march", "text": "Führe den Konvoi auf die Passhöhe, bis zum Hang (gelbe Markierung): Lkw wählen, Rechtsklick.", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 4}, "mark": ["mid", -26, 26]},
			{"id": "tunnel", "text": "Bringe Funke zum eingestürzten Tunnel (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -10, 10], "r": 9.0, "who": "tag:funke"}, "mark": ["mid", -10, 10],
				"done": [{"do": "flag", "f": "dig"},
					{"do": "sfx", "name": "siren"},
					{"do": "banner", "text": "DER TUNNEL IST EINGESTÜRZT", "secs": 3.4, "col": Color(1.0, 0.7, 0.4)},
					radio("Dmitri Karpow", C_FUNKE, "Da sind Stimmen unter dem Schutt! Haltet mir den Rücken frei, ich grabe!", 7.0)]},
			{"id": "dig", "text": "Halte die Stellung, bis Funke den Tunnel geräumt hat.", "c": {"t": "since", "f": "dig", "s": 22.0},
				"done": [{"do": "banner", "text": "ZWÖLF GERETTET", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
					{"do": "sfx", "name": "stinger"},
					{"do": "spawn", "side": "me", "def": "inf", "n": 12, "at": ["mid", -10, 10], "spread": 4.0, "tag": "rescued", "hp": 1.5, "speed": 0.6},
					{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", -9, 11], "spread": 1.0, "tag": "mischa", "hp": 2.0, "speed": 0.55},
					radio("Dmitri Karpow", C_FUNKE, "Ich habe dich, Kleiner. Ich habe dich. Komm, ich trage dich.", 7.0)]},
			{"id": "carry", "text": "Bringe Mischa und mindestens 9 Gerettete zum Pass (gelbe Markierung).", "c": {"t": "all", "c": [{"t": "tag_reach", "tag": "rescued", "at": ["mid", 0, 0], "r": 18.0, "n": 9}, {"t": "reach", "at": ["mid", 0, 0], "r": 18.0, "who": "tag:mischa"}]}, "mark": ["mid", 0, 0]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER KONVOI ROLLT", "secs": 3.4}]},
			# Die Raketen aus dem Westen
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -49, 50], "r": 20.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "RAKETEN AUS DEM WESTEN", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -28, 38], "size": 2.6},
				{"do": "explode", "at": ["mid", -28, 32], "size": 2.6},
				radio("Dmitri Karpow", C_FUNKE, "Raketen! Sie kommen aus dem Westen! Alle runter, alle in Deckung!", 6.0),
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["mid", 30, -26], "spread": 5.0, "attack_tag": "convoy", "dmg": 0.3, "hp": 0.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", -30, 18], "spread": 8.0, "attack_tag": "convoy"}]},
			# Wendepunkt: der Tunnel bricht ein
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 1}, "do": [
				{"do": "flash", "col": Color(1.0, 0.7, 0.4), "secs": 0.9},
				{"do": "shake", "n": 2.4},
				{"do": "explode", "at": ["mid", -10, 10], "size": 3.0, "n": 1.4},
				radio("Ilja Wolkow", C_WOLKOW, "Dmitri, der Tunnel ist eingestürzt. Da waren Familien drin. Geh hin, Junge.", 7.0)]},
			# Zweiter Angriff, während Funke gräbt
			{"when": {"t": "since", "f": "dig", "s": 6.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 22, -4], "spread": 6.0, "attack_tag": "funke"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 24, -2], "spread": 3.0, "attack_tag": "funke", "hp": 0.7}]},
			# Höhepunkt: Sperrfeuer am Pass
			{"when": {"t": "tag_reach", "tag": "rescued", "at": ["mid", 0, 0], "r": 30.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DAS SPERRFEUER", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -10, 8], "size": 2.6},
				{"do": "explode", "at": ["mid", 12, -6], "size": 2.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", -26, -20], "spread": 8.0, "attack_tag": "rescued"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 28, 22], "spread": 7.0, "attack_tag": "rescued", "hp": 0.7},
				radio("Dmitri Karpow", C_FUNKE, "Weiter, weiter, nicht stehen bleiben! Der Pass ist gleich da, nur noch ein Stück!", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "mischa", "n": 1}, "do": [radio("Dmitri Karpow", C_FUNKE, "Mischa! Nein! Mischa!", 5.0)]},
		],
		"lose": [{"c": {"t": "any", "c": [{"t": "tag_dead", "tag": "funke", "n": 1}, {"t": "tag_dead", "tag": "mischa", "n": 1}]}, "text": "Funke oder Mischa sind gefallen."}],
	}
