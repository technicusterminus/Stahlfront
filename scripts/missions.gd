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

static func radio(who: String, col: Color, text: String, secs := 0.0) -> Dictionary:
	return {"do": "radio", "who": who, "col": col, "text": text, "secs": secs}

static func list() -> Array:
	return [_t1(), _t2(), _t3(), _t4(), _c1(), _c2(), _c3()]

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

static func _c1() -> Dictionary:
	return {
		"id": "c1", "kind": "campaign", "title": "Kapitel 1: Port Meridian", "faction": "west", "enemy_faction": "shadow", "next": "c2",
		"brief": "Jahr fünfzehn nach dem Blackout. Dr. Elin Voss, Chefstrategin der Küstenarmee, steht im Kontrollraum von Port Meridian. ORAKEL, die letzte Analyse-KI, hat zum ersten Mal einen Satz gesagt, den niemand berechnet hat: „Das Prisma erwacht. Wir müssen vor den anderen dort sein.“\n\nDer Rat der Sieben gibt dir drei Tage. Bis dahin muss Port Meridian zum Ausgangspunkt der Expedition werden: Basis aufbauen, Truppe aufstellen, und Raubzüge aus den Bergen abwehren.\n\nAuftrag: Baue Nachschub, Kraftwerk, Kaserne und Fabrik, stelle acht Kampfeinheiten auf und halte Port Meridian zehn Minuten.",
		"map": {"name": "Port Meridian", "size": 240, "water": 0.5, "islands": 0.2, "resources": 0.6, "hills": 0.4, "forest": 0.5, "layout": 3, "seed": 5101},
		"hour": 7.0, "difficulty": 1, "credits": 4500, "ai": "off",
		"setup": [radio("Elin Voss", C_ELIN, "Port Meridian, hier Voss. Wir haben nicht viel Zeit. Baut den Stützpunkt auf, ich will in zehn Minuten eine Armee.", 8.0)],
		"objectives": [
			{"id": "supply", "text": "Baue ein Nachschubzentrum.", "c": {"t": "build", "role": "supply", "n": 1}},
			{"id": "power", "text": "Baue ein Kraftwerk.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik.", "c": {"t": "build", "role": "factory", "n": 1}},
			{"id": "army", "text": "Stelle 8 Kampfeinheiten auf.", "c": {"t": "count", "role": "combat", "n": 8, "naval": false, "flying": false}},
			{"id": "hold", "text": "Halte Port Meridian, bis die Uhr 10:00 zeigt.", "c": {"t": "time", "s": 600.0}},
		],
		"events": [
			{"when": {"t": "time", "s": 150.0}, "do": [radio("ORAKEL", C_ORAKEL, "Warnung: Bewegung im Nordhang. Wahrscheinlichkeit eines Raubzugs 92 Prozent.", 7.0)]},
			{"when": {"t": "time", "s": 180.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["en", 0, 20], "spread": 8.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 2, "at": ["en", 6, 22], "spread": 6.0, "attack": true}]},
			{"when": {"t": "time", "s": 330.0}, "do": [radio("Elin Voss", C_ELIN, "Sie kommen wieder, diesmal mehr. Haltet die Linie.", 6.0)]},
			{"when": {"t": "time", "s": 360.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["en", 0, 20], "spread": 9.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 2, "at": ["en", -6, 22], "spread": 4.0, "attack": true}]},
			{"when": {"t": "time", "s": 520.0}, "do": [radio("ORAKEL", C_ORAKEL, "Letzte Welle erkannt. Starke Bewegung.", 6.0)]},
			{"when": {"t": "time", "s": 540.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 8, "at": ["en", 0, 20], "spread": 10.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 4, "at": ["en", 6, 22], "spread": 7.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "buggy", "n": 3, "at": ["en", -8, 22], "spread": 6.0, "attack": true}]},
			{"when": {"t": "time", "s": 600.0}, "do": [radio("Elin Voss", C_ELIN, "Port Meridian steht. Das Prisma hat uns nicht vergessen. Wir fliegen bei Tagesanbruch.", 8.0)]},
		],
		"lose": [],
	}

static func _c2() -> Dictionary:
	return {
		"id": "c2", "kind": "campaign", "title": "Kapitel 2: Der Falke fliegt", "faction": "west", "enemy_faction": "red", "next": "c3",
		"brief": "Major Kai „Falke“ Laurent hält jeden Tag für den letzten und fliegt entsprechend. Elin schickt ihn über den Eisenkamm: Messwerte holen, nichts sonst.\n\nDu führst zwei Lanze-Jäger und eine Spähdrohne. Überfliege die drei Messpunkte, ohne dass dich die Flugabwehr herunterholt, und kehre zurück. Kämpfe nur, wenn es sein muss.\n\nHinweis: Luftabwehr sitzt an den Messpunkten. Halte Abstand, wo du kannst, oder nutze die Drohne als Köder.",
		"map": {"name": "Eisenkamm", "size": 288, "water": 0.2, "islands": 0.05, "resources": 0.5, "hills": 0.9, "forest": 0.4, "layout": 0, "seed": 5202},
		"hour": 12.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "jet", "n": 2, "at": ["me", 0, 18], "spread": 6.0, "tag": "wing"},
			{"do": "spawn", "side": "me", "def": "drone", "n": 1, "at": ["me", 6, 18], "spread": 2.0, "tag": "wing"},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", -30, 14], "spread": 6.0},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", 20, -22], "spread": 6.0},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 3, "at": ["en", -20, 10], "spread": 8.0},
			{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["en", 10, 10], "spread": 8.0},
			{"do": "cam", "at": ["me", 0, 18]},
			radio("Falke", C_FALKE, "Falke an Basis. Zweite Chance ist startklar. Ich fliege tief, wie immer.", 6.0)],
		"objectives": [
			{"id": "p1", "text": "Überfliege Messpunkt 1 (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -34, 6], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", -34, 6]},
			{"id": "p2", "text": "Überfliege Messpunkt 2.", "c": {"t": "reach", "at": ["mid", 18, -30], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", 18, -30],
				"done": [radio("Falke", C_FALKE, "Das ist komisch. Sie verteidigen nicht, sie fliehen. Dörfer, Kinder auf Maultieren, und über den Kavernen leuchtet es bläulich.", 9.0),
					radio("ORAKEL", C_ORAKEL, "Aufklärungsdaten werden zur Überprüfung zurückgehalten.", 6.0),
					radio("Falke", C_FALKE, "Zurückgehalten? Das habe ich noch nie gehört.", 5.0)]},
			{"id": "p3", "text": "Überfliege Messpunkt 3 nahe der Gegnerbasis.", "c": {"t": "reach", "at": ["en", -4, 4], "r": 14.0, "who": "tag:wing"}, "mark": ["en", -4, 4]},
			{"id": "home", "text": "Kehre zur Basis zurück.", "c": {"t": "reach", "at": ["me", 0, 10], "r": 16.0, "who": "tag:wing"}, "mark": ["me", 0, 10],
				"done": [radio("Elin Voss", C_ELIN, "Falke, gute Arbeit. Aber wer hat die Daten zurückgehalten?", 7.0)]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "tag_alive", "tag": "wing", "n": 1}}, "text": "Alle Flugzeuge sind verloren."}],
	}

static func _c3() -> Dictionary:
	return {
		"id": "c3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "west", "enemy_faction": "red", "next": "",
		"brief": "Der Konvoi zum Eisenkamm-Pass transportiert Medizin, Messgeräte und Dr. Yusuf Brandt, den Prisma-Forscher. Sechs Lkw und eine Eskorte. Sergeant Mira „Glas“ Tanaka sagt zwei Sätze am Tag und sieht als Erste, wohin die Raketen wirklich fallen.\n\nBringe mindestens vier der sechs Lkw zum Pass. Zwei Hinterhalte sind wahrscheinlich: halte die Eskorte beisammen, schalte Raketenwerfer zuerst aus und lass die Lkw nie allein.\n\nVerlierst du drei Lkw, ist der Auftrag gescheitert.",
		"map": {"name": "Eisenkamm-Pass", "size": 240, "water": 0.25, "islands": 0.0, "resources": 0.5, "hills": 0.8, "forest": 0.3, "layout": 1, "seed": 5303},
		"hour": 14.0, "difficulty": 1, "credits": 2000, "ai": "off",
		"setup": [
			{"do": "spawn", "side": "me", "def": "harv", "n": 6, "at": ["me", 0, 20], "spread": 9.0, "tag": "convoy"},
			{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 0, 28], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 0, 30], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 2, "at": ["me", 6, 30], "spread": 4.0},
			{"do": "cam", "at": ["me", 0, 24]},
			radio("Mira Tanaka", C_MIRA, "Glas an Konvoi. Ich sitze auf Wagen vier. Ich traue dem Funkschatten nicht.", 7.0)],
		"objectives": [
			{"id": "pass", "text": "Bringe mindestens 4 von 6 Lkw zum Pass (gelbe Markierung): Lkw auswählen, Rechtsklick auf den Pass.", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 14.0, "n": 4}, "mark": ["mid", 0, 0]},
		],
		"events": [
			{"when": {"t": "time", "s": 35.0}, "do": [radio("Mira Tanaka", C_MIRA, "Bewegung auf den Hängen, links. Alle Waffen scharf.", 5.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", -34, 18], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", -38, 22], "spread": 6.0, "attack_tag": "convoy"}]},
			{"when": {"t": "time", "s": 90.0}, "do": [radio("Mira Tanaka", C_MIRA, "Raketenwerfer. Sie kommen nicht aus dem Hochland. Sie kommen von hinten, von der Küstenseite.", 8.0),
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 2, "at": ["mid", 30, -26], "spread": 5.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", 34, -22], "spread": 8.0, "attack_tag": "convoy"}]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "convoy", "n": 3}, "text": "Drei Lkw des Konvois sind verloren."}],
	}
