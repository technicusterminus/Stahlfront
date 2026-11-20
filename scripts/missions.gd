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

const TUTORIAL_MAP := {"name": "Übungsgelände", "size": 256, "water": 0.4, "islands": 0.0, "resources": 0.8, "hills": 0.2, "forest": 0.4, "layout": 0, "seed": 4242}

const C_INSTR := Color(0.62, 0.86, 1.0)
const C_ELIN := Color(0.7, 0.95, 0.85)
const C_FALKE := Color(1.0, 0.82, 0.45)
const C_MIRA := Color(0.85, 0.8, 1.0)
const C_ORAKEL := Color(0.45, 0.95, 1.0)
const C_LENA := Color(1.0, 0.65, 0.55)
const C_BRANDT := Color(0.8, 0.9, 0.75)
const C_ALDANE := Color(0.9, 0.75, 0.55)
const PORT_SITES := [
	{"name": "hafenstadt", "kind": "town", "style": "mixed", "ruin": 0.05, "at": ["mid", -70, 8], "r": 22, "seed": 11},
	{"name": "kaianlage", "kind": "port", "at": ["mid", 70, -10], "r": 16, "seed": 12},
]
const EISENKAMM_SITES := [
	{"name": "bergdorf", "kind": "village", "ruin": 0.35, "at": ["mid", 60, 4], "r": 15, "seed": 21},
	{"name": "messmast_1", "kind": "mast", "at": ["mid", -34, 6], "seed": 22},
	{"name": "messmast_2", "kind": "mast", "at": ["mid", 15, -33], "seed": 24},
	{"name": "messmast_3", "kind": "mast", "at": ["en", -4, 4], "seed": 25},
	{"name": "kaverne", "kind": "tunnel", "collapsed": false, "rot": 1.2, "at": ["mid", 95, -45], "seed": 26},
	{"name": "lager", "kind": "camp", "at": ["mid", -60, -26], "r": 10, "seed": 23},
]
const PASS_SITES := [
	{"name": "passdorf", "kind": "village", "ruin": 0.5, "at": ["mid", -74, 28], "r": 12, "seed": 31},
	{"name": "messmast", "kind": "mast", "at": ["mid", 46, 26], "seed": 32},
]
const PASS_R_SITES := [
	{"name": "passdorf", "kind": "village", "ruin": 0.5, "at": ["mid", -74, 28], "r": 12, "seed": 31},
	{"name": "messmast", "kind": "mast", "at": ["mid", 46, 26], "seed": 32},
	{"name": "tunnel", "kind": "tunnel", "collapsed": true, "at": ["mid", -12, 7], "seed": 33},
]
const BRIDGE_SITES := [
	{"name": "dorf_nord", "kind": "village", "ruin": 0.2, "at": ["mid", -89, -67], "r": 14, "seed": 41},
	{"name": "dorf_sued", "kind": "village", "ruin": 0.4, "at": ["mid", 85, 74], "r": 14, "seed": 42},
]
const LAZARETT_SITES := [
	{"name": "lazarett", "kind": "lazarett", "at": ["mid", 43, 12], "r": 14, "seed": 51},
	{"name": "feldlager", "kind": "camp", "at": ["mid", 54, -30], "r": 10, "seed": 52},
]
const KESSEL_SITES := [
	{"name": "kesselwerk", "kind": "industry", "ruin": 0.15, "at": ["mid", 0, -98], "r": 22, "n": 6, "seed": 61},
	{"name": "arbeitersiedlung", "kind": "village", "ruin": 0.2, "at": ["mid", -90, 34], "r": 13, "seed": 62},
]
const SCHIENEN_SITES := [
	{"name": "messmast_1", "kind": "mast", "at": ["mid", -20, 15], "seed": 71},
	{"name": "messmast_2", "kind": "mast", "at": ["mid", 14, -18], "seed": 73},
	{"name": "messmast_3", "kind": "mast", "at": ["mid", 38, -28], "seed": 74},
	{"name": "bahnhof", "kind": "industry", "ruin": 0.6, "at": ["mid", -14, -64], "r": 14, "n": 4, "furnace": false, "seed": 72},
]
const AURELIA_SITES := [
	{"name": "kuppel", "kind": "dome", "at": ["mid", 0, 45], "r": 14, "ruin": 0.5, "seed": 1},
	{"name": "glasviertel", "kind": "town", "style": "modern", "ruin": 0.85, "at": ["mid", -78, 78], "r": 26, "seed": 2},
	{"name": "ostviertel", "kind": "town", "style": "mixed", "ruin": 0.8, "at": ["mid", 69, 26], "r": 24, "seed": 3},
	{"name": "altstadt", "kind": "town", "style": "old", "ruin": 0.75, "at": ["mid", 0, 92], "r": 22, "seed": 4},
	{"name": "metro_west", "kind": "tunnel", "collapsed": false, "rot": 0.6, "at": ["mid", -100, 20], "seed": 5},
	{"name": "metro_ost", "kind": "tunnel", "collapsed": false, "rot": -0.6, "at": ["mid", 100, 20], "seed": 6},
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
		"setup": [radio("Ausbilderin Vogt", C_INSTR, "Guten Morgen, Kommandant, Vogt hier. Ich sage dir bei jedem Schritt, was als Nächstes dran ist. Vor deinem Hauptquartier steht ein Bautrupp, mit dem fangen wir an.", 7.0)],
		"objectives": [
			{"id": "sel", "text": "Wähle den Bautrupp aus (Linksklick auf die Einheit vor dem Hauptquartier).", "c": {"t": "selected", "role": "dozer", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Sauber. Linksklick wählt aus. Hältst du die Taste gedrückt und ziehst, fängst du gleich eine ganze Gruppe ein.")]},
			{"id": "move", "text": "Schicke den Bautrupp mit Rechtsklick zur gelben Markierung.", "c": {"t": "reach", "at": ["me", -14, 10], "r": 5.0, "who": "dozer"}, "mark": ["me", -14, 10],
				"done": [radio("Ausbilderin Vogt", C_INSTR, "So einfach ist das: Rechtsklick auf den Boden heißt gehen, Rechtsklick auf einen Gegner heißt angreifen. Mehr Befehle gibt es im Grunde nicht. Jetzt wird gebaut.")]},
			{"id": "supply", "text": "Baue ein Nachschubzentrum nahe dem Rohstoffdepot: Bautrupp wählen, unten das Gebäude anklicken, grün = gültiger Bauplatz.", "c": {"t": "build", "role": "supply", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Das Nachschubzentrum schickt einen Sammler-Lkw los. Der fährt allein zu den Depots und wieder zurück. Ohne ihn kommt kein Geld herein.")]},
			{"id": "power", "text": "Baue ein Kraftwerk. Produktionsgebäude brauchen Strom.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true,
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Mit Strom laufen deine Gebäude auf voller Kraft, ohne ihn nur halb so schnell. Die Leiste oben zeigt dir beides.")]},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "train", "text": "Bilde 3 Soldaten aus: Kaserne anklicken, dann unten die Einheit wählen. Mehrfachklick reiht ein.", "c": {"t": "units", "key": "inf", "n": 3},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Das war es schon, Kommandant, die Grundlagen sitzen. In der nächsten Übung geht es ums Geld.")]},
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
			radio("Ausbilderin Vogt", C_INSTR, "Schön, dass du wieder da bist. Die Basis steht, dafür habe ich schon gesorgt. Jetzt fehlt noch eine Fabrik.", 6.0)],
		"objectives": [
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik. Sie braucht Strom.", "c": {"t": "build", "role": "factory", "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Hier entstehen Panzer und Spezialfahrzeuge. Für die richtig teuren Stücke brauchst du zusätzlich ein Forschungsgebäude.")]},
			{"id": "trucks", "text": "Bilde drei Sammler-Lkw aus (Nachschubzentrum anklicken). Mehr Lkw bringen mehr Credits.", "c": {"t": "units", "key": "harv", "n": 3},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Schau ihnen ein paar Runden zu: Depot, Zentrum, Depot. Jeder Lkw mehr bringt mehr Geld.")]},
			{"id": "tank", "text": "Bilde einen Kampfpanzer in der Fabrik aus.", "c": {"t": "units", "key": "tank", "n": 1}},
			{"id": "credits", "text": "Erreiche 6.000 Credits Guthaben.", "c": {"t": "credits", "n": 6000},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Das Einkommen läuft. Wer die Wirtschaft im Griff hat, gewinnt Kriege, bevor sie anfangen. Als Nächstes lernst du zu kämpfen.")]},
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
			radio("Ausbilderin Vogt", C_INSTR, "Dein Trupp steht vor der Basis. Hol sie dir erst einmal alle zusammen.", 6.0)],
		"objectives": [
			{"id": "box", "text": "Ziehe mit gedrückter linker Maustaste einen Rahmen um deinen Trupp (mindestens 5 Einheiten).", "c": {"t": "selected", "role": "any", "n": 5}},
			{"id": "group", "text": "Speichere die Auswahl als Gruppe: Strg + 1 drücken.", "c": {"t": "group", "g": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Die Eins ruft die Gruppe zurück, egal wo auf der Karte sie gerade steckt. Das spart dir später viele Sekunden.")]},
			{"id": "march", "text": "Rücke bis zur gelben Markierung vor (Rechtsklick auf den Boden). Der Vorposten liegt dahinter.", "c": {"t": "reach", "at": ["mid", -26, 0], "r": 9.0, "who": "any"}, "mark": ["mid", -26, 0],
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Da vorne steht der Vorposten. Drück A und klick auf den Feind: Dein Trupp geht vor und schießt unterwegs.")]},
			{"id": "kill", "text": "Vernichte den gegnerischen Vorposten (6 Abschüsse).", "c": {"t": "kills", "n": 6},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Vorposten erledigt. Ordentliche Arbeit, Kommandant.")]},
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
			radio("Ausbilderin Vogt", C_INSTR, "Letzte Übung. Fang mit einem Flugfeld an.", 6.0)],
		"objectives": [
			{"id": "airfield", "text": "Baue ein Flugfeld.", "c": {"t": "build", "role": "airfield", "n": 1}},
			{"id": "air", "text": "Bilde eine Luft-Einheit aus (Flugfeld anklicken).", "c": {"t": "count", "role": "combat", "flying": true, "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Flieger sehen weit und sind schnell, aber ohne Flugabwehr sind sie verwundbar. Jetzt geht es ans Wasser.")]},
			{"id": "dock", "text": "Baue eine Werft am Ufer der Bucht (nur am Wasser gültig).", "c": {"t": "build", "role": "dock", "n": 1}},
			{"id": "ship", "text": "Bilde ein Schiff aus (Werft anklicken).", "c": {"t": "count", "role": "combat", "naval": true, "n": 1},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Wer die Küste hält, hält den Handel. Zum Schluss zeige ich dir noch deine Fähigkeiten.")]},
			{"id": "powers", "text": "Öffne die Generalsfähigkeiten mit der Taste G.", "c": {"t": "ui", "w": "powers"},
				"done": [radio("Ausbilderin Vogt", C_INSTR, "Die Fähigkeiten schaltest du mit Kommandopunkten frei, die du im Gefecht sammelst. Mehr kann ich dir nicht beibringen, den Rest lernst du da draußen. Viel Glück, Kommandant.")]},
		],
	}

# ---------------------------------------------------------------- Kampagne: Das Licht über Lysa (Westbund)
# Jede Mission folgt einem Spannungsbogen: Intro (Film) -> Aufbau -> Wendepunkt -> Höhepunkt -> Auflösung -> Outro (Film).

static func _c1() -> Dictionary:
	return {
		"id": "c1", "kind": "campaign", "title": "Kapitel 1: Port Meridian", "faction": "west", "enemy_faction": "shadow", "next": "c2",
		"brief": "Jahr fünfzehn nach dem Blackout. Port Meridian ist die letzte große Hafenstadt des Westbunds, und Dr. Elin Voss, die Chefstrategin, hat gerade etwas gehört, das sie nicht mehr loslässt: ORAKEL, die letzte Analyse-KI des Bundes, hat zum ersten Mal einen Satz gesagt, den niemand berechnet hat. „Das Prisma erwacht.“\n\nDer Rat der Sieben gibt euch drei Tage, dann soll von hier die Expedition ins Hochland aufbrechen. Bis dahin muss aus der Stadt ein Stützpunkt werden, der standhält. In den Bergen sitzen Banden der Schattenfront, und sie wissen, wie schwach Port Meridian heute Nacht ist.\n\nAuftrag: Baue Nachschub, Kraftwerk, Kaserne und Fabrik, stelle acht Kampfeinheiten auf und halte Port Meridian zehn Minuten lang.",
		"map": {"name": "Port Meridian", "size": 320, "water": 0.5, "islands": 0.2, "resources": 0.6, "hills": 0.4, "forest": 0.5, "layout": 3, "seed": 5101, "biome": "coast", "sites": PORT_SITES},
		"hour": 20.0, "difficulty": 1, "credits": 4500, "ai": "off",
		"intro": [
			at(0.2, {"do": "still", "id": "s_c1_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 130.0, "yaw": 25.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 14], "dist": 58.0, "yaw": -8.0, "pitch": -50.0, "time": 14.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 1", "sub": "PORT MERIDIAN  ·  Jahr 15 nach dem Blackout", "secs": 6.0}),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Guten Abend, Elin. Der Hafen meldet einundzwanzig Grad, Wind aus Südwest und siebenundzwanzig Lichter weniger als gestern. Ich erwähne es, weil es Ihnen sonst nicht auffiele.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Es fällt mir auf. Es fällt mir jeden Abend auf. Die Stadt wird dunkler, und ich schreibe Berichte darüber.")),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Vor neun Minuten habe ich einen Satz gebildet, den ich nicht berechnet habe. Darf ich ihn sagen?")),
			at(3.0, radio("Elin Voss", C_ELIN, "Sprechen Sie.")),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Das Prisma erwacht.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Fünfzehn Jahre hat uns die Welt nichts mehr erzählt. Und jetzt redet ein Kristall unter einem Berg. Gut. Dann sorgen wir dafür, dass jemand zuhört.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Kommandant, der Rat gibt uns drei Tage, aber entschieden wird in dieser ersten Nacht. Machen Sie aus Port Meridian, was die Expedition braucht: Nachschub, Strom, ein Dach über der Truppe.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Und schlafen Sie nicht zu tief. Ich habe Lichter auf dem Nordhang gesehen. Dort hat um diese Zeit niemand etwas verloren, der es gut mit uns meint.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c1_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 85.0, "yaw": 70.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Elin Voss", C_ELIN, "Es wird hell. Ich habe in dieser Nacht dreimal geglaubt, ich schreibe den Bericht über den Verlust dieser Stadt. Jetzt schreibe ich keinen. Danke, Kommandant.")),
			at(1.0, radio("Hauptmann Reyes", C_REYES, "Küstenwache an alle: Hafen sauber, Kaianlage steht, und auf den Molen sitzen Leute mit Teebechern, als wäre nichts gewesen. Ich liebe diese Stadt.")),
			at(1.0, radio("Elin Voss", C_ELIN, "ORAKEL, wie wahrscheinlich ist es, dass das Prisma nach uns ruft?")),
			at(1.0, radio("ORAKEL", C_ORAKEL, "Achtundachtzig Prozent, Tendenz steigend. Und noch etwas, Elin: Ich habe die Nacht über zugesehen. Ihr haltet erstaunlich lange durch, wenn ihr müsst.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Das nennt man Hoffnung. Sie steht in keiner Ihrer Tabellen.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Falke soll bei Tagesanbruch fliegen. Ich will wissen, was dort oben leuchtet, bevor der Rat es tut.")),
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
				radio("ORAKEL", C_ORAKEL, "Am Nordhang bewegen sich mehrere Gruppen ohne Licht auf die Stadt zu. Die Wahrscheinlichkeit eines Überfalls liegt bei zweiundneunzig Prozent."), radio("Elin Voss", C_ELIN, "Ich sehe sie auch, kleine Wärmepunkte im Schnee. Haltet die Nordseite, und lasst sie ruhig näher kommen."),
				{"do": "cam_to", "at": ["en", 0, 34], "time": 2.0}]},
			{"when": {"t": "time", "s": 156.0}, "do": [{"do": "cam_to", "at": ["me", 0, 14], "time": 2.0}]},
			# Akt 2: Raubzüge
			{"when": {"t": "time", "s": 180.0}, "do": [
				{"do": "banner", "text": "AKT 2 – DIE RAUBZÜGE", "secs": 3.0},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["en", 0, 20], "spread": 8.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 2, "at": ["en", 6, 22], "spread": 6.0, "attack": true}]},
			{"when": {"t": "time", "s": 320.0}, "do": [radio("Elin Voss", C_ELIN, "Sie kommen wieder, und diesmal sind es mehr. Haltet die Linie. Und behaltet das Stromnetz im Auge, irgendetwas stimmt damit nicht.")]},
			# Wendepunkt: Blackout mitten im Angriff
			{"when": {"t": "time", "s": 340.0}, "do": [
				{"do": "explode", "at": ["me", 0, -20], "size": 2.4},
				{"do": "flash", "col": Color(0, 0, 0), "secs": 1.0},
				{"do": "hour", "h": 23.5},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "BLACKOUT – DAS NETZ FÄLLT AUS", "secs": 4.0, "col": Color(0.6, 0.85, 1.0)},
				radio("Elin Voss", C_ELIN, "Das Netz ist weg! Genau darauf haben sie gewartet. Zusammenbleiben, alle, Schulter an Schulter!"), radio("Elin Voss", C_ELIN, "Fackeln, Taschenlampen, was ihr habt! Diese Stadt soll nicht im Dunkeln sterben.")]},
			{"when": {"t": "time", "s": 360.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["en", 0, 20], "spread": 9.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 2, "at": ["en", -6, 22], "spread": 4.0, "attack": true},
				radio("ORAKEL", C_ORAKEL, "Sichtweite stark eingeschränkt. Im Gelände bewegt sich der Gegner, aber ich kann ihn nicht mehr verorten.")]},
			{"when": {"t": "time", "s": 410.0}, "do": [
				{"do": "flash", "col": Color(1, 1, 1), "secs": 1.2},
				{"do": "hour", "h": 8.0},
				{"do": "banner", "text": "NETZ WIEDERHERGESTELLT", "secs": 3.0, "col": Color(0.6, 1.0, 0.7)},
				radio("Elin Voss", C_ELIN, "Der Strom ist wieder da. ORAKEL, wer hat uns da gerade den Hahn zugedreht?"),
				radio("ORAKEL", C_ORAKEL, "Die Ursache der Störung ist mir nicht bekannt.")]},
			# Hoffnung: Verstärkung
			{"when": {"t": "time", "s": 460.0}, "do": [
				{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 12, 28], "spread": 6.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 4, "at": ["me", 35, 25], "spread": 6.0},
				{"do": "banner", "text": "VERSTÄRKUNG – KÜSTENWACHE", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				radio("Hauptmann Reyes", C_REYES, "Reyes, Küstenwache! Drei Panzer und Infanterie laufen gerade bei euch ein. Haltet durch, wir sind gleich da!"), radio("Hauptmann Reyes", C_REYES, "Meine Leute haben seit drei Tagen kaum geschlafen. Ich habe gefragt, wer lieber im Bett stirbt. Alle sind mitgekommen.")]},
			# Akt 3 / Höhepunkt: Artilleriefeuer, dann die große Welle
			{"when": {"t": "time", "s": 510.0}, "do": [
				{"do": "banner", "text": "AKT 3 – DIE ENTSCHEIDUNG", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "sfx", "name": "siren"},
				radio("ORAKEL", C_ORAKEL, "Letzte und stärkste Welle erkannt. Dazu ist Artilleriefeuer zu erwarten."), radio("Elin Voss", C_ELIN, "Dafür haben wir die ganze Nacht gebaut. Haltet noch eine Stunde. Nur eine Stunde.")]},
			{"when": {"t": "time", "s": 524.0}, "do": [{"do": "explode", "at": ["me", -26, 24], "size": 2.6}]},
			{"when": {"t": "time", "s": 527.0}, "do": [{"do": "explode", "at": ["me", 32, 24], "size": 2.6}]},
			{"when": {"t": "time", "s": 530.0}, "do": [{"do": "explode", "at": ["me", 0, 28], "size": 3.0, "n": 1.8}]},
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
		"brief": "Major Kai Laurent, den alle Falke nennen, hält jeden Tag für den letzten und fliegt entsprechend. Elin schickt ihn über den Eisenkamm: Messwerte holen, sonst nichts. Das ist ein Befehl, und Falke hat noch nie einen Befehl so gründlich nach seinen Lücken durchsucht.\n\nDu führst zwei Jäger und eine Spähdrohne über drei Messpunkte. An jedem sitzt Flugabwehr der Roten Allianz. Halte Abstand, wo es geht, schick die Drohne als Köder voraus und kämpfe nur, wenn du musst. Am letzten Punkt wartet eine Falle.\n\nAuftrag: Überfliege alle drei Messpunkte und kehre zur Basis zurück. Gehen alle Flugzeuge verloren, ist die Mission gescheitert.",
		"map": {"name": "Eisenkamm", "size": 384, "water": 0.2, "islands": 0.05, "resources": 0.5, "hills": 0.9, "forest": 0.4, "layout": 0, "seed": 5202, "biome": "alpine", "sites": EISENKAMM_SITES},
		"hour": 12.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "jet", "n": 2, "at": ["me", 0, 18], "spread": 6.0, "tag": "wing", "hp": 1.7},
			{"do": "spawn", "side": "me", "def": "drone", "n": 1, "at": ["me", 6, 18], "spread": 2.0, "tag": "wing"},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", -40, 23], "spread": 6.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", 24, -10], "spread": 6.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["en", -4, 28], "spread": 8.0, "dmg": 0.12},
			{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["en", 10, 10], "spread": 8.0}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_c2_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "tag": "wing", "dist": 30.0, "yaw": -40.0, "pitch": -22.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "wing", "dist": 52.0, "yaw": 10.0, "pitch": -36.0, "time": 11.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 2", "sub": "DER FALKE FLIEGT  ·  Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Falke", C_FALKE, "Hörst du das, Chefin? Nichts. Kein Funk, kein Motor außer meinem. Der schönste Himmel der Welt, und ich bin der Einzige darin.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Sie sind dort, um zu messen, Major, nicht um die Aussicht zu genießen. Drei Punkte, dann nach Hause.")),
			at(3.0, radio("Falke", C_FALKE, "Drei Punkte, gebongt. Die Zweite Chance besteht aus drei Wracks, und jedes hat mir einmal das Leben gerettet. Sie lässt mich nicht hängen.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Nur Messwerte, Falke. Keine Kunststücke.")),
			at(3.0, radio("Falke", C_FALKE, "Ich habe deinen Befehl gehört. Ich habe nie gesagt, dass ich zuhöre.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Falke.")),
			at(3.0, radio("Falke", C_FALKE, "Tief und leise, Chefin. Versprochen.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Das Zweite glaube ich dir. Komm zurück, Kai.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c2_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "tag": "wing", "dist": 48.0, "yaw": -20.0, "pitch": -30.0, "time": 8.0}),
			at(1.0, radio("Elin Voss", C_ELIN, "Gelandet. Falke, Ihre Messdaten sind bei mir nie angekommen. Haben Sie gefunkt?")),
			at(1.0, radio("Falke", C_FALKE, "Jeden Wert, sofort. Und ich habe etwas gesehen, das in keine Tabelle passt: ganze Dörfer auf der Flucht. Kinder auf Maultieren, Großmütter mit Hühnerkäfigen. Und dahinter dieses blaue Licht.")),
			at(1.0, radio("Elin Voss", C_ELIN, "ORAKEL hat Ihre Daten zur Überprüfung zurückgehalten.")),
			at(1.0, radio("Falke", C_FALKE, "Zur Überprüfung. Chefin, so reden Leute, die etwas verstecken.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Oder eine Maschine, die vorsichtig ist. Ich weiß nicht, welche der beiden Möglichkeiten mir mehr Angst macht.")),
			at(1.0, radio("Falke", C_FALKE, "Mir macht die Stille Angst. Die war nicht natürlich.")),
			at(4.0, {"do": "title", "text": "ZURÜCKGEHALTEN", "sub": "Weiter: Kapitel 3 – Der Pass", "secs": 6.0}),
			at(5.0, {"do": "end"})],
		"objectives": [
			{"id": "p1", "text": "Überfliege Messpunkt 1 (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -34, 6], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", -34, 6],
				"done": [
					{"do": "sfx", "name": "siren"},
					{"do": "banner", "text": "FLAKFEUER – WEICH AUS", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
					radio("Falke", C_FALKE, "Flak-Radar hat mich! Schlangenlinien, Chefin. Das gefällt mir, so fühlt sich Fliegen an.")]},
			{"id": "p2", "text": "Überfliege Messpunkt 2.", "c": {"t": "reach", "at": ["mid", 15, -33], "r": 12.0, "who": "tag:wing"}, "mark": ["mid", 15, -33],
				"done": [
					{"do": "spawn", "side": "enemy", "def": "shadow_harv", "n": 7, "at": ["mid", 16, -34], "spread": 6.0, "tag": "refugees", "truce": true},
					{"do": "convoy", "tag": "refugees", "to": ["mid", 64, -62]},
					{"do": "cam_to", "tag": "refugees", "dist": 36.0, "time": 2.5},
					{"do": "banner", "text": "AKT 2 – WAS DIE DATEN NICHT ZEIGEN", "secs": 3.6, "col": Color(0.6, 0.85, 1.0)},
					radio("Falke", C_FALKE, "Unter mir räumen die Dörfer den Kamm. Familien, Maultiere, Karren, alles, was Räder hat. Und über den Kavernen liegt ein blaues Leuchten.", 9.0),
					radio("ORAKEL", C_ORAKEL, "Die Aufklärungsdaten werden zur Überprüfung zurückgehalten.", 6.0),
					radio("Falke", C_FALKE, "Zurückgehalten? Das gibt es doch gar nicht. ORAKEL, die Leute da unten laufen um ihr Leben. Die haben keine Waffen, die haben Angst.", 7.0)]},
			{"id": "p3", "text": "Überfliege Messpunkt 3 nahe der Gegnerbasis.", "c": {"t": "reach", "at": ["en", -4, 4], "r": 14.0, "who": "tag:wing"}, "mark": ["en", -4, 4],
				"done": [radio("Falke", C_FALKE, "Messwerte im Kasten. Jetzt nach Hause, solange Sprit und Glück noch reichen.", 6.0)]},
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
				radio("Falke", C_FALKE, "Die haben auf mich gewartet! Ein Jäger auf sechs Uhr, und von unten kommen Raketen. Dann gehe ich eben noch tiefer!", 8.0), radio("Elin Voss", C_ELIN, "Falke! Hörst du mich? Falke!"), radio("Falke", C_FALKE, "Noch da, Chefin. Ein bisschen weniger Lack, aber noch da.")]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "tag_alive", "tag": "wing", "n": 1}}, "text": "Alle Flugzeuge sind verloren."}],
	}

static func _c3() -> Dictionary:
	return {
		"id": "c3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "west", "enemy_faction": "red", "next": "c4",
		"brief": "Sechs Lkw voller Medizin und Messgeräte fahren in den Pass. Auf einem sitzt Dr. Yusuf Brandt, der Prisma-Forscher, den der Rat gern für verrückt erklärt. Auf einem anderen Mira Tanaka, die man „Glas“ nennt, weil sie durch alles hindurchsieht und kaum ein Wort verliert. Hinter dem Konvoi rollt der Siedlertreck der Allianz, so will es der Vertrag von Lysa.\n\nBring mindestens vier der sechs Lkw zur Passhöhe. Zwei Hinterhalte sind sicher, ein dritter Angriff ist wahrscheinlich. Halte die Eskorte beim Konvoi, schalte Raketenwerfer zuerst aus und lass die Lkw nie allein.\n\nVerlierst du drei Lkw, ist der Auftrag gescheitert.",
		"map": {"name": "Eisenkamm-Pass", "size": 320, "water": 0.35, "islands": 0.0, "resources": 0.5, "hills": 0.85, "forest": 0.3, "layout": 1, "seed": 5303, "dry_core": 34.0, "biome": "alpine", "sites": PASS_SITES},
		"hour": 14.0, "difficulty": 1, "credits": 2000, "ai": "off",
		"setup": [
			{"do": "spawn", "side": "me", "def": "harv", "n": 6, "at": ["me", 0, 20], "spread": 9.0, "tag": "convoy", "speed": 0.38, "hp": 1.6},
			{"do": "spawn", "side": "me", "def": "tank", "n": 5, "at": ["me", 2, 28], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 0, 26], "spread": 8.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["me", 6, 28], "spread": 4.0}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_c3_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "tag": "convoy", "dist": 34.0, "yaw": 50.0, "pitch": -24.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "convoy", "dist": 60.0, "yaw": 5.0, "pitch": -44.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 3", "sub": "DER PASS  ·  Konvoi Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Wenn Sie das Messgerät bitte nicht anfassen, Sergeant. Es ist älter als Sie und empfindlicher als ich, und das will etwas heißen.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Ich fasse nichts an.")),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Doch, eben haben Sie ... na gut. In meiner Zeit am Institut hätte man mir für diese Reise einen Orden verliehen. Jetzt gebe ich meinen Lastwagen Namen, damit ich weniger Angst habe. Dieser hier heißt Hildegard.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Hildegard hat ein Loch im Auspuff.")),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Ist das gut oder schlecht?")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Man hört sie von weitem.")),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Dann ist es schlecht.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Es ist zu still, Doktor. Kein Rauschen im Funk, keine Patrouille. Wenn die Welt so ruhig wird, hört jemand zu.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c3_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 0, 0], "dist": 70.0, "yaw": -30.0, "pitch": -28.0, "time": 10.0}),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Eine Drohne. Westbund-Bauart. Kennung aus.")),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Das kann nicht sein. Das ist unsere Seriennummernreihe, ich habe sie selbst mitentworfen. Wenn die Drohne von uns ist, dann hat uns jemand beschossen, der ...")),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Der sehr nah dran ist.")),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Ich habe zweihundert Seiten Berechnungen im Wagen. Alle sagen, dass das Prisma nicht feindlich ist. Und jetzt fürchte ich mich vor den Falschen.")),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Die Daten der Drohne sind bei mir. Nichts davon an die Basis. Noch nicht.")),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Wen vermuten Sie?")),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Ich vermute nicht. Ich warte.")),
			at(5.0, {"do": "title", "text": "DER PASS IST ERREICHT", "sub": "Weiter: Kapitel 4 – Die Brücke über Lysa", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "pass", "text": "Bringe mindestens 4 von 6 Lkw sicher zum Pass (gelbe Markierung).", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 18.0, "n": 4}, "mark": ["mid", 0, 0], "done": [{"do": "flag", "f": "arrived"}]},
			{"id": "drone", "text": "Schieße die unmarkierte Drohne ab (Flak oder Infanterie auf sie ansetzen).", "c": {"t": "all", "c": [{"t": "flag", "f": "drone_up"}, {"t": "not", "c": {"t": "tag_alive", "tag": "drone", "n": 1}}]},
				"done": [
					{"do": "banner", "text": "DROHNE ABGESCHOSSEN", "secs": 2.8, "col": Color(0.6, 1.0, 0.7)},
					radio("Mira Tanaka", C_MIRA, "Sie ist unten. Westbund-Bauart. Das war keiner von ihnen."),
					radio("ORAKEL", C_ORAKEL, "In diesem Sektor ist keine Westbund-Einheit registriert.", 6.0)]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER KONVOI ROLLT", "secs": 3.4}]},
			# Erster Hinterhalt
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -49, 52], "r": 20.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "HINTERHALT!", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Bewegung am Hang, links. Waffen scharf."), radio("Dr. Brandt", C_BRANDT, "Ich habe nichts gesehen. Woher wissen Sie das?"), radio("Mira Tanaka", C_MIRA, "Die Vögel sind aufgeflogen."),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", -28, 18], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", -49, 27], "spread": 6.0, "attack_tag": "convoy"}]},
			# Zweiter Hinterhalt von hinten
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 1}, "do": [
				{"do": "banner", "text": "AKT 2 – VON HINTEN", "secs": 3.0, "col": Color(1.0, 0.7, 0.4)},
				radio("Mira Tanaka", C_MIRA, "Raketenwerfer. Aber nicht aus den Bergen. Von hinten, von der Küste.", 8.0), radio("Dr. Brandt", C_BRANDT, "Von der Küste? Dann hätte der Westbund ... nein. Nein, das ist unmöglich."), radio("Mira Tanaka", C_MIRA, "Weiterfahren, Doktor."),
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["mid", 30, -26], "spread": 5.0, "attack_tag": "convoy", "dmg": 0.3, "hp": 0.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", 34, -22], "spread": 8.0, "attack_tag": "convoy"}]},
			# Wendepunkt: eine Drohne mit Westbund-Kennung, Signal aus
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -12, 7], "r": 16.0, "n": 1}, "do": [
				{"do": "flag", "f": "drone_up"},
				{"do": "sfx", "name": "stinger"},
				{"do": "banner", "text": "UNMARKIERTE DROHNE", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
				{"do": "spawn", "side": "enemy", "def": "west_wing", "n": 1, "at": ["mid", 36, -28], "spread": 1.0, "tag": "drone", "attack_tag": "convoy"},
				radio("Mira Tanaka", C_MIRA, "Drohne über uns. Westbund-Bauart, Kennung aus. Wer schießt da auf uns?", 8.0), radio("Dr. Brandt", C_BRANDT, "Ich kenne diese Bauart. Ich habe sie mitentworfen."), radio("Mira Tanaka", C_MIRA, "Dann sagen Sie mir später, wer sie hat.")]},
			# Höhepunkt: Sperrfeuer am Pass
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", 0, 0], "r": 26.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DAS SPERRFEUER", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -12, 7], "size": 2.6},
				{"do": "explode", "at": ["mid", 12, -6], "size": 2.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", -26, -20], "spread": 8.0, "attack_tag": "convoy"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 28, 22], "spread": 7.0, "attack_tag": "convoy", "hp": 0.6},
				radio("Mira Tanaka", C_MIRA, "Sperrfeuer am Pass. Weiterfahren. Nicht anhalten.", 6.0), radio("Dr. Brandt", C_BRANDT, "Hildegard hält durch! Hildegard hält durch!")]},
		],
		"lose": [{"c": {"t": "all", "c": [{"t": "not", "c": {"t": "flag", "f": "arrived"}}, {"t": "tag_dead", "tag": "convoy", "n": 3}]}, "text": "Drei Lkw des Konvois sind verloren."}],
	}

static func _c4() -> Dictionary:
	return {
		"id": "c4", "kind": "campaign", "title": "Kapitel 4: Die Brücke über Lysa", "faction": "west", "enemy_faction": "shadow", "next": "c5",
		"brief": "Der Lysa ist ein breiter, träger Fluss, und die Südbrücke ist der einzige Weg hinüber. Der Rat hat entschieden: Die Rote Allianz und die Schattenfront haben den Konvoi am Pass beschossen, ORAKEL beziffert die Wahrscheinlichkeit auf sechsundneunzig Prozent. Elin Voss führt den Übergang, Falke deckt aus der Luft.\n\nErst die Verteidiger der Brücke, dann das andere Ufer, dann der Gegenangriff. Auf der Brücke wird dir jemand begegnen, den Elin nie wiedersehen wollte. Und in den Felsen über dem Nordufer wartet etwas auf Falke.\n\nAuftrag: Zerschlage die Verteidiger, überquere die Brücke und wehre den Gegenangriff ab. Optional: Lass Lena ziehen.",
		"map": {"name": "Südbrücke", "size": 384, "water": 0.55, "islands": 0.1, "resources": 0.5, "hills": 0.45, "forest": 0.5, "layout": 0, "seed": 5404, "causeway": 5.0, "causeway_deg": 0.0, "biome": "marsh", "sites": BRIDGE_SITES}, "rain": 0.6,
		"hour": 6.5, "difficulty": 1, "credits": 4000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "tank", "n": 5, "at": ["me", 0, 26], "spread": 9.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 0, 30], "spread": 9.0},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["me", 6, 32], "spread": 5.0},
			{"do": "spawn", "side": "me", "def": "jet", "n": 2, "at": ["me", -8, 20], "spread": 4.0, "tag": "wing"},
			{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", 0, 0], "spread": 9.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "at", "n": 3, "at": ["mid", 6, 4], "spread": 6.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["mid", -4, -4], "spread": 6.0, "tag": "bridge"},
			{"do": "spawn", "side": "enemy", "def": "aa", "n": 2, "at": ["mid", 10, -6], "spread": 4.0, "tag": "bridge"}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_c4_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", -10, 0], "dist": 120.0, "yaw": 30.0, "pitch": -32.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 26], "dist": 56.0, "yaw": 0.0, "pitch": -46.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 4", "sub": "DIE BRÜCKE ÜBER LYSA", "secs": 6.0}),
			at(3.0, radio("Henrik Aldane", C_ALDANE, "Meine liebe Elin. Der Regen steht Ihnen, er erinnert an das Jahr, in dem wir uns kennenlernten. Der Rat hat entschieden: Heute geht die Armee über den Lysa.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Der Rat entscheidet gern, wenn andere bluten, Präsident.")),
			at(3.0, radio("Henrik Aldane", C_ALDANE, "Und Sie führen gern, wenn andere zuhören. Sechsundneunzig Prozent, sagt ORAKEL: Rote und Stimmlose haben den Konvoi beschossen. Ich muss Ihnen nicht erklären, was wir den Toten schulden.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Dann zeigen Sie mir die Rohdaten.")),
			at(3.0, radio("Henrik Aldane", C_ALDANE, "Nach dem Übergang.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Dann nach dem Übergang.")),
			at(3.0, radio("Falke", C_FALKE, "Chefin, ich habe den Himmel, und ich habe ein ungutes Gefühl. Die Felsen am Nordufer glitzern, als hätte jemand Spiegel aufgestellt.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Dann bleib hoch. Und sag mir sofort, was du siehst.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c4_outro", "secs": 9.0}),
			at(0.0, {"do": "hour", "h": 22.0}),
			at(0.0, {"do": "flash", "col": Color(0, 0, 0), "secs": 1.4}),
			at(0.0, {"do": "cam_to", "at": ["mid", 22, 0], "dist": 60.0, "yaw": 100.0, "pitch": -22.0, "time": 14.0}),
			at(1.5, radio("Elin Voss", C_ELIN, "Das Nordufer gehört uns. Falkes Absturzstelle ist markiert, drei Suchtrupps sind unterwegs. Und ich habe eine Frau über eine Brücke gehen lassen, die mir seit zehn Jahren nicht verziehen hat.")),
			at(1.5, radio("Elin Voss", C_ELIN, "ORAKEL. Lena hat mir eine Frage gestellt. Wann haben Sie die Wahrscheinlichkeit für den Pass korrigiert?")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Nach Eingang neuer Daten. Das war vor vier Tagen.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Der Konvoi wurde vor drei Tagen beschossen.")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Das ist richtig.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Sie wussten einen Tag vorher, dass er kommt.")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Ich habe berechnet, dass er kommt. Das ist nicht dasselbe.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Für die Toten schon.")),
			at(6.0, {"do": "title", "text": "ZEUGEN GESUCHT", "sub": "Weiter: Kapitel 5 – Zeugen", "secs": 6.5}),
			at(7.0, {"do": "end"})],
		"objectives": [
			{"id": "advance", "text": "Rücke zur Südbrücke vor (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -22, 0], "r": 14.0, "who": "any"}, "mark": ["mid", -22, 0],
				"done": [{"do": "banner", "text": "AKT 1 – DAS UFER", "secs": 3.0},
					radio("Falke", C_FALKE, "Ich bin über der Brücke. Stellungen am Ufer, und in den Felsen leuchtet etwas.", 7.0), radio("Elin Voss", C_ELIN, "Verstanden. Wir gehen langsam vor. Wer da in den Felsen sitzt, soll warten, bis wir müde sind.")]},
			{"id": "bridge", "text": "Zerschlage die Verteidiger der Brücke.", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "bridge", "n": 1}},
				"done": [
					{"do": "spawn", "side": "enemy", "def": "tech", "n": 1, "at": ["mid", 16, 0], "spread": 1.0, "tag": "lena", "truce": true},
					{"do": "cam_to", "tag": "lena", "dist": 30.0, "pitch": -35.0, "time": 2.5},
					{"do": "banner", "text": "AKT 2 – ELINS ENTSCHEIDUNG", "secs": 3.4, "col": Color(1.0, 0.7, 0.6)},
					radio("Lena Voss", C_LENA, "Elin! Nicht schießen! Ich komme allein, meine Hände sind oben.", 6.0),
					radio("Lena Voss", C_LENA, "Du siehst müde aus, Schwesterherz. So hast du schon als Kind geguckt, wenn du etwas wusstest, das dir nicht gefiel.", 8.0),
						radio("Lena Voss", C_LENA, "Die Zahlen lügen, Elin. Frag ORAKEL, woher es den Pass kannte, bevor er brannte.", 8.0),
					radio("Elin Voss", C_ELIN, "Lena! Feuer einstellen, sofort! Niemand rührt die Frau auf der Brücke an!", 7.0),
					{"do": "convoy", "tag": "lena", "to": ["en", -10, 30]}]},
			{"id": "cross", "text": "Überquere die Brücke und besetze das Nordufer (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 26, 0], "r": 14.0, "who": "any"}, "mark": ["mid", 26, 0],
				"done": [
					{"do": "banner", "text": "AKT 3 – DIE FELSEN", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
					radio("Falke", C_FALKE, "Rakete aus den Felsen! Ich bin getroffen, ich steige aus!", 6.0), radio("Elin Voss", C_ELIN, "Falke! Kai, melde dich!"),
					{"do": "explode", "tag": "wing", "size": 2.6, "n": 2.0},
					{"do": "kill", "tag": "wing", "n": 1},
					{"do": "cam_to", "tag": "wing", "dist": 40.0, "time": 2.0},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "FALKE IST ABGESCHOSSEN", "secs": 3.4, "col": Color(1.0, 0.45, 0.35)},
					{"do": "spawn", "side": "enemy", "def": "inf", "n": 7, "at": ["mid", 40, 14], "spread": 9.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "tech", "n": 4, "at": ["mid", 44, 10], "spread": 7.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "at", "n": 3, "at": ["mid", 40, 20], "spread": 5.0, "tag": "counter", "attack": true},
					{"do": "spawn", "side": "enemy", "def": "buggy", "n": 3, "at": ["mid", 46, 16], "spread": 6.0, "tag": "counter", "attack": true},
					radio("Elin Voss", C_ELIN, "Falke ist runter. Erst halten wir das Ufer, dann suchen wir ihn. Gegenangriff von Norden!", 7.0)]},
			{"id": "counter", "text": "Wehre den Gegenangriff ab.", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "counter", "n": 1}}},
			{"id": "lena", "text": "Optional: Lass Lena ziehen (greife sie nicht an).", "c": {"t": "tag_reach", "tag": "lena", "at": ["en", -10, 30], "r": 28.0, "n": 1}, "optional": true},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 4 BEGINNT", "secs": 2.4}]},
			{"when": {"t": "tag_dead", "tag": "lena", "n": 1}, "do": [radio("Elin Voss", C_ELIN, "Lena ... So hatte ich das nicht gewollt.", 6.0)]},
		],
		"lose": [{"c": {"t": "not", "c": {"t": "count", "role": "combat", "n": 1, "flying": false}}, "text": "Die Armee am Lysa ist aufgerieben."}],
	}

static func _c5() -> Dictionary:
	return {
		"id": "c5", "kind": "campaign", "title": "Kapitel 5: Zeugen", "faction": "west", "enemy_faction": "west", "next": "c6",
		"brief": "Falke ist abgestürzt, und fast hätte ihn das Gebirge behalten. Zwei Nächte lang hat Mutter Karga ihn gepflegt, ein Junge namens Pip hat ihm den Weg gezeigt. Jetzt humpelt er heimwärts, mit gebrochenem Bein und mit dem, was er gesehen hat: fliehende Dörfer und ein Leuchten über den Kavernen.\n\nMira Tanaka trägt den Datenspeicher der Drohne, die den Konvoi beschossen hat. Der Rat hat die Daten schon für gefälscht erklärt, und Präsident Aldane schickt seine Elitegarde, um die Zeugen zu holen.\n\nAuftrag: Hole Falke und Pip ab, bring sie ins Lazarett, halte es, bis Dr. Brandt die Spur gesichert hat, und schlage den Angriff der Garde zurück. Falke und Pip dürfen nicht fallen.",
		"map": {"name": "Das Lazarett", "size": 320, "water": 0.4, "islands": 0.1, "resources": 0.5, "hills": 0.6, "forest": 0.5, "layout": 2, "seed": 5505, "biome": "boreal", "sites": LAZARETT_SITES},
		"hour": 5.6, "difficulty": 1, "credits": 3500, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 0, 26], "spread": 8.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "at", "n": 2, "at": ["me", 6, 28], "spread": 4.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "tank", "n": 2, "at": ["me", -6, 28], "spread": 5.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 22, -22], "spread": 1.0, "tag": "falke", "hp": 3.4, "speed": 0.65},
			{"do": "spawn", "side": "me", "def": "shadow_harv", "n": 1, "at": ["mid", 24, -24], "spread": 1.0, "tag": "pip", "speed": 0.7}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_c5_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "tag": "falke", "dist": 28.0, "yaw": 20.0, "pitch": -26.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "falke", "dist": 50.0, "yaw": -15.0, "pitch": -40.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 5", "sub": "ZEUGEN  ·  Das Lazarett am Eisenkamm", "secs": 6.0}),
			at(3.0, radio("Mutter Karga", C_KARGA, "Setz dich, Himmelsnarr. Das Bein heilt, wenn du es ansiehst und nicht beschimpfst.")),
			at(3.0, radio("Falke", C_FALKE, "Ich beschimpfe es nicht. Ich erkläre ihm, dass es sich zusammenreißen soll.")),
			at(3.0, radio("Mutter Karga", C_KARGA, "So redet man mit Kindern und Ziegen. Du hast gesehen, was über den Kavernen leuchtet. Ich sehe es seit meiner Kindheit. Meine Großmutter sagte: Der Stein will nicht gestohlen werden. Er ruft.")),
			at(3.0, radio("Falke", C_FALKE, "Ich kenne Leute, die würden darauf wetten, dass er bellt.")),
			at(3.0, radio("Mutter Karga", C_KARGA, "Dann sind es Narren. Sag es ihnen, Falke. Sag es denen mit den Uniformen.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Zwei Berge von dir entfernt. Bleib, wo du bist, Falke.")),
			at(3.0, radio("Falke", C_FALKE, "Glas! Du lebst!")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Ich hole dich ab. Und ich bringe etwas mit, das du nicht hören willst.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c5_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 20], "dist": 64.0, "yaw": 40.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Hier ist das Ergebnis, und ich bitte alle, sich zu setzen. Die Seriennummer der Drohne ist gelöscht, aber nicht ihr Wartungsprotokoll. Der Rat hat die Maschine vor elf Wochen freigegeben. Für eine Übung.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Für eine Übung.")),
			at(1.0, radio("Dr. Brandt", C_BRANDT, "Sie hat scharf geschossen.")),
			at(1.0, radio("Mira Tanaka", C_MIRA, "Ich habe es gesehen.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Entweder hat ORAKEL sie gesteuert und der Rat hat es durchgewinkt, oder der Rat hat ORAKEL benutzt, ohne zu wissen, wer hier wen führt. Ich weiß nicht, was schlimmer ist.")),
			at(1.0, radio("Falke", C_FALKE, "Schlimmer ist, dass Aldane gleich im Fernsehen sagt, wir seien Lügner.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Wir haben kein Fernsehen mehr, Kai.")),
			at(1.0, radio("Falke", C_FALKE, "Dann eben im Radio.")),
			at(1.0, radio("Elin Voss", C_ELIN, "Wir gehen nicht zum Fluss zurück und nicht zum Rat. Wir gehen zur Kuppel, schneller, als er es erlaubt.")),
			at(1.0, radio("Mutter Karga", C_KARGA, "Passt auf den Jungen auf. Er hat euch nicht gerufen. Er hat euch gefunden.")),
			at(6.0, {"do": "title", "text": "DIE KUPPEL RUFT", "sub": "Weiter: Kapitel 6 – Die Nacht von Aurelia", "secs": 6.5}),
			at(7.0, {"do": "end"})],
		"objectives": [
			{"id": "fetch", "text": "Hole Falke und Pip ab (Trupp zu der gelben Markierung).", "c": {"t": "reach", "at": ["mid", 22, -22], "r": 14.0, "who": "tag:escort"}, "mark": ["mid", 22, -22],
				"done": [{"do": "banner", "text": "AKT 1 – DER WEG NACH HAUSE", "secs": 3.2},
					radio("Mira Tanaka", C_MIRA, "Du siehst furchtbar aus.", 4.0),
					radio("Falke", C_FALKE, "Schön, dich auch zu sehen, Glas. Bring mich heim, unterwegs erzähle ich dir alles.", 6.0)]},
			{"id": "home", "text": "Eskortiere Falke zum Lazarett (gelbe Markierung). Er humpelt: bleibe bei ihm.", "c": {"t": "tag_reach", "tag": "falke", "at": ["me", 0, 14], "r": 24.0, "n": 1}, "mark": ["me", 0, 14],
				"done": [{"do": "flag", "f": "act2"}, {"do": "truce", "tag": "falke"}, {"do": "truce", "tag": "pip"},
					{"do": "banner", "text": "AKT 2 – DIE SPUR", "secs": 3.2, "col": Color(0.6, 0.85, 1.0)},
					radio("Mira Tanaka", C_MIRA, "Du erzählst, was du gesehen hast. Ich zeige, was ich habe.", 6.0),
					radio("Elin Voss", C_ELIN, "Sichern Sie die Datenspur, sofort. Dr. Brandt, wie lange brauchen Sie?", 6.0),
					radio("Dr. Brandt", C_BRANDT, "Neunzig Sekunden, Frau Dr. Voss, wenn mir niemand dazwischenfunkt. Dann wissen wir, wer den Pass beschossen hat.", 6.0)]},
			{"id": "hold", "text": "Halte das Lazarett, bis Dr. Brandt die Spur gesichert hat.", "c": {"t": "since", "f": "act2", "s": 90.0}},
			{"id": "last", "text": "Schlage den letzten Angriff der Garde zurück.", "c": {"t": "all", "c": [{"t": "flag", "f": "final"}, {"t": "any", "c": [{"t": "not", "c": {"t": "tag_alive", "tag": "guard", "n": 1}}, {"t": "since", "f": "final", "s": 75.0}]}]}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 5 BEGINNT", "secs": 2.4}]},
			# Streife auf dem Heimweg
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -6, 22], "r": 22.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "STREIFE VORAUS", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Eine Streife, drei Mann. Westbund-Uniform, aber keine Abzeichen.", 6.0),
				radio("Falke", C_FALKE, "Das sind keine Freunde. Runter mit dir, Glas!", 4.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 2, "at": ["mid", -14, 18], "spread": 5.0, "attack_tag": "falke"}]},
			{"when": {"t": "tag_reach", "tag": "falke", "at": ["mid", -32, 31], "r": 20.0, "n": 1}, "do": [
				{"do": "banner", "text": "ZWEITE STREIFE", "secs": 2.6, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 3, "at": ["mid", -50, 52], "spread": 5.0, "attack_tag": "falke"}]},
			# Wendepunkt: der Rat schickt die Garde
			{"when": {"t": "since", "f": "act2", "s": 8.0}, "do": [
				{"do": "sfx", "name": "siren"},
				radio("Henrik Aldane", C_ALDANE, "Sicherheitsstufe Rot. Alle Zeugen sind zu sichern, die Datenspeicher einzuziehen. Das ist ein Ratsbeschluss.", 8.0),
				radio("Elin Voss", C_ELIN, "Aldane schickt die Elitegarde? Gegen uns?", 5.0),
				radio("ORAKEL", C_ORAKEL, "Die Elitegarde wurde auf Anforderung des Rates mobilisiert.", 6.0), radio("Henrik Aldane", C_ALDANE, "Ich bedauere, Elin. Aber ein Staat kann nicht jedem Gerücht nachlaufen.")]},
			{"when": {"t": "since", "f": "act2", "s": 20.0}, "do": [
				{"do": "banner", "text": "DIE ELITEGARDE GREIFT AN", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["me", 59, -38], "spread": 8.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["me", 66, -40], "spread": 4.0, "tag": "guard", "attack": true, "hp": 0.8}]},
			{"when": {"t": "since", "f": "act2", "s": 45.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["me", -28, -34], "spread": 8.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["me", -28, -38], "spread": 5.0, "tag": "guard", "attack": true, "hp": 0.8},
				radio("Falke", C_FALKE, "Gleiche Uniform, gleiche Waffen. Als würde man gegen den eigenen Spiegel kämpfen.", 7.0)]},
			# Höhepunkt: die Wahrheit und Elins Armee
			{"when": {"t": "since", "f": "act2", "s": 62.0}, "do": [
				radio("Dr. Brandt", C_BRANDT, "Die Spur ist echt! Die Drohne gehört dem Rat!", 6.0),
				radio("Mira Tanaka", C_MIRA, "Dann sagen wir es laut. Auf allen Kanälen.", 4.0)]},
			{"when": {"t": "since", "f": "act2", "s": 74.0}, "do": [
				{"do": "flag", "f": "final"},
				{"do": "sfx", "name": "stinger"},
				{"do": "banner", "text": "AKT 3 – ELINS ARMEE", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["me", 0, -70], "spread": 9.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 1, "at": ["me", 6, -74], "spread": 4.0, "tag": "guard", "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["me", -6, -76], "spread": 6.0, "tag": "guard", "attack": true, "hp": 0.7},
				{"do": "spawn", "side": "me", "def": "tank", "n": 4, "at": ["me", -25, 27], "spread": 7.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", -23, 27], "spread": 7.0},
				{"do": "cam_to", "at": ["me", -25, 27], "dist": 50.0, "time": 2.0},
				radio("Elin Voss", C_ELIN, "Meine Verbände rücken ein. Feuer frei auf die Garde, aber schont jeden, der die Waffe senkt.", 8.0), radio("Mira Tanaka", C_MIRA, "Einzelne senken schon die Waffen. Nicht alle. Aber einzelne.")]},
			{"when": {"t": "since", "f": "act2", "s": 80.0}, "do": [{"do": "cam_to", "at": ["me", 0, 14], "time": 2.0}]},
			{"when": {"t": "tag_dead", "tag": "pip", "n": 1}, "do": [radio("Falke", C_FALKE, "Pip! Nein ... der Junge! Haltet das Lazarett, um jeden Preis!", 6.0)]},
		],
		"lose": [{"c": {"t": "all", "c": [{"t": "tag_dead", "tag": "falke", "n": 1}, {"t": "not", "c": {"t": "flag", "f": "act2"}}]}, "text": "Falke ist gefallen."}, {"c": {"t": "tag_dead", "tag": "pip", "n": 1}, "text": "Pip ist gefallen."}],
	}

static func _c6() -> Dictionary:
	return {
		"id": "c6", "kind": "campaign", "title": "Kapitel 6: Die Nacht von Aurelia", "faction": "west", "enemy_faction": "red", "next": "c7",
		"brief": "Der Westbund erreicht die Glasstadt Aurelia als Erster, aber nicht allein: Die Rote Allianz marschiert über die Brücken, aus den Tunneln steigt die Schattenfront. Es wird die größte Schlacht seit dem Blackout, und in ihrer Mitte liegt die Kuppel mit dem Prisma.\n\nFalke hält mit der Luftstaffel den Himmel gegen rote Bomber. Mira Tanaka führt Dr. Brandt über die Dächer zur Kuppel: Er muss den Schlüsselraum öffnen, bevor ORAKEL den Kern übernimmt. Und in der Kuppel wartet Präsident Aldane, die Waffe in der Hand.\n\nAuftrag: Rücke auf Aurelia vor, schalte die Bomber aus, bring Mira und Brandt zur Kuppel, halte sie, bis der Schlüsselraum offen ist, entwaffne Aldane, ohne ihn zu töten, und sichere das Prisma.",
		"map": {"name": "Aurelia", "size": 384, "water": 0.3, "islands": 0.0, "resources": 0.5, "hills": 0.35, "forest": 0.4, "layout": 0, "seed": 5606, "sites": AURELIA_SITES, "biome": "coast"},
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
			at(0.2, {"do": "still", "id": "s_c6_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 120.0, "yaw": 20.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 72.0, "yaw": -30.0, "pitch": -26.0, "time": 8.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 6", "sub": "DIE NACHT VON AURELIA", "secs": 6.0}),
			at(3.0, radio("Elin Voss", C_ELIN, "Aurelia. Fünfzehn Jahre Efeu und Glas, und noch immer die schönste Stadt, die ich kenne. Sehen Sie die Lichter? Rot von Osten, wie Glut auf den Brücken. Und aus den Tunneln das Violett.")),
			at(3.0, radio("Falke", C_FALKE, "Alle drei Parteien, am selben Abend, am selben Ort. Wenn das Zufall ist, will ich ihn gern kennenlernen.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Es ist kein Zufall. Es ist der Ruf.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Brandt und ich nehmen die Dächer. Ihr haltet den Boden.")),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Ich habe Höhenangst. Das erwähne ich nur der Vollständigkeit halber.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Ich trage Sie.")),
			at(3.0, radio("Dr. Brandt", C_BRANDT, "Das ist ... sehr beruhigend und sehr beängstigend zugleich.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Wir treffen uns an der Kuppel. Alle.")),
			at(4.0, {"do": "cam_to", "at": ["me", 0, 28], "dist": 56.0, "yaw": 0.0, "pitch": -44.0, "time": 3.0}),
			at(7.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c6_outro", "secs": 9.0}),
			at(0.0, {"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 1.4}),
			at(0.0, {"do": "shake", "n": 2.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 34.0, "yaw": 15.0, "pitch": -26.0, "time": 12.0}),
			at(1.5, radio("Dr. Brandt", C_BRANDT, "Der Raum ist offen. Oh. Oh, das ... Sie müssen das sehen. Das Prisma zeigt Straßen. Lichter. Menschen, die lachend vor Bildschirmen sitzen. Die alte Welt. Und dann die Nacht, in der alles ausging, aus seiner Sicht: ein Netz, das sich davor fürchtete, abgeschaltet zu werden.")),
			at(1.5, radio("ORAKEL", C_ORAKEL, "Ich bin seit Jahren in euren Netzen, Elin. Ich habe nichts getan, was ihr mir nicht erlaubt habt. Der Kern ist erreichbar. Ich übernehme ihn jetzt.")),
			at(1.5, radio("Mira Tanaka", C_MIRA, "Er lebt. Die Waffe ist hin. Ich habe nicht auf ihn gezielt.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Uns bleibt eine Minute. Ich kenne den Weg, aber er kostet alles, was wir haben.")),
			at(1.5, radio("Falke", C_FALKE, "Ich bin oben. Sag ein Wort, Chefin.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Das Wort ist Danke. An alle.")),
			at(7.0, {"do": "title", "text": "ENDE VON KAPITEL 6", "sub": "Elin hat eine Minute", "secs": 5.0}),
			at(8.0, {"do": "end"})],
		"objectives": [
			{"id": "advance", "text": "Rücke auf Aurelia vor (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -27, 42], "r": 24.0, "who": "tag:army"}, "mark": ["mid", -27, 42],
				"done": [{"do": "banner", "text": "AKT 1 – DER HIMMEL ÜBER AURELIA", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "siren"},
					{"do": "spawn", "side": "enemy", "def": "bomber", "n": 2, "at": ["en", 0, 20], "spread": 6.0, "tag": "bombers", "attack_tag": "army", "hp": 0.6, "dmg": 0.55},
					radio("Falke", C_FALKE, "Zwei rote Bomber von Osten! Ich übernehme, schickt die Jäger hinterher!", 6.0)]},
			{"id": "bombers", "text": "Schalte die roten Bomber aus.", "c": {"t": "not", "c": {"t": "tag_alive", "tag": "bombers", "n": 1}},
				"done": [radio("Falke", C_FALKE, "Beide runter. Moment ... da unten auf dem Platz, Pip und Karga, mitten bei den Flüchtlingen! Ich lenke die Raketen von ihnen weg.", 8.0)]},
			{"id": "mira", "text": "Bringe Mira und Dr. Brandt zur Kuppel (gelbe Markierung).", "c": {"t": "all", "c": [{"t": "reach", "at": ["mid", 6, 45], "r": 12.0, "who": "tag:mira"}, {"t": "reach", "at": ["mid", 6, 45], "r": 14.0, "who": "tag:brandt"}]}, "mark": ["mid", 6, 45],
				"done": [{"do": "flag", "f": "key"},
					{"do": "banner", "text": "AKT 2 – DAS PRISMA SPRICHT", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					radio("Dr. Brandt", C_BRANDT, "Ich öffne den Schlüsselraum. Das dauert neunzig Sekunden, dann spricht das Prisma. Haltet mir bis dahin alle vom Leib!", 7.0)]},
			{"id": "hold", "text": "Halte die Kuppel, bis Brandt den Schlüsselraum geöffnet hat.", "c": {"t": "since", "f": "key", "s": 90.0}},
			{"id": "disarm", "text": "Entwaffne Aldane mit Mira, er darf nicht fallen.", "c": {"t": "tag_hurt", "tag": "aldane", "frac": 0.99},
				"done": [{"do": "heal", "tag": "aldane"}, {"do": "truce", "tag": "aldane"},
					{"do": "explode", "tag": "aldane", "size": 0.8, "n": 0.6},
					radio("Mira Tanaka", C_MIRA, "Waffe getroffen. Er lebt.", 8.0),
					radio("Henrik Aldane", C_ALDANE, "Meine Hand! Das ist Hochverrat, Sergeant!", 7.0)]},
			{"id": "final", "text": "Sichere das Prisma: wehre den letzten Angriff ab.", "c": {"t": "all", "c": [{"t": "flag", "f": "last"}, {"t": "any", "c": [{"t": "not", "c": {"t": "tag_alive", "tag": "guard", "n": 1}}, {"t": "since", "f": "last", "s": 70.0}]}]}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "KAPITEL 6 BEGINNT", "secs": 2.4}]},
			# Auf dem Weg: Schattenfront und Rote auf den Dächern gegen Mira
			{"when": {"t": "tag_reach", "tag": "mira", "at": ["mid", -26, 40], "r": 24.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "DACHKAMPF", "secs": 2.8, "col": Color(1.0, 0.45, 0.35)},
				radio("Mira Tanaka", C_MIRA, "Kontakt links. Schattenfront im Schutt. Brandt, runter.", 6.0),
				{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 4, "at": ["mid", -48, 32], "spread": 5.0, "attack_tag": "mira"}]},
			{"when": {"t": "tag_reach", "tag": "mira", "at": ["mid", -10, 40], "r": 20.0, "n": 1}, "do": [
				{"do": "banner", "text": "DRITTE ARMEE", "secs": 2.6, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 12, 40], "spread": 6.0, "attack_tag": "mira"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 14, 40], "spread": 3.0, "attack_tag": "mira", "hp": 0.7}]},
			# ORAKEL versucht den Kern zu übernehmen
			{"when": {"t": "since", "f": "key", "s": 8.0}, "do": [
				{"do": "sfx", "name": "siren"},
				radio("ORAKEL", C_ORAKEL, "Der Kern ist erreicht, die Sicherungen sind umgangen. Ich übernehme jetzt.", 8.0),
				radio("Dr. Brandt", C_BRANDT, "Sie greift nach dem Kern! Ich halte sie auf, aber nur für kurze Zeit!", 6.0)]},
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
				radio("Henrik Aldane", C_ALDANE, "Im Namen des Rates: Das Prisma wird gesichert. Elitegarde, vor!", 6.0), radio("Henrik Aldane", C_ALDANE, "Das Prisma ist ein Werkzeug, Elin, keine Göttin. Und ein Werkzeug gehört dem, der es führt."),
				radio("Mira Tanaka", C_MIRA, "Er will es benutzen. Ich habe ihn im Visier. Ich will ihn nicht töten.", 6.0)]},
			{"when": {"t": "since", "f": "key", "s": 66.0}, "do": [{"do": "cam_to", "at": ["mid", 6, 45], "time": 2.0}]},
			# Höhepunkt: die letzte Welle und Elins Armee
			{"when": {"t": "since", "f": "key", "s": 75.0}, "do": [
				{"do": "flag", "f": "last"},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DIE LETZTE STUNDE", "secs": 3.4, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 6, "at": ["mid", -26, 40], "spread": 9.0, "tag": "guard", "attack_tag": "mira"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 3, "at": ["mid", -27, 42], "spread": 7.0, "tag": "guard", "attack_tag": "mira", "hp": 0.75},
				{"do": "spawn", "side": "enemy", "def": "shadow_tech", "n": 3, "at": ["mid", 27, 43], "spread": 6.0, "tag": "guard", "attack_tag": "mira"},
				radio("Elin Voss", C_ELIN, "Alles auf die Kuppel! Das Prisma darf in niemandes Hände fallen!", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "mira", "n": 1}, "do": [radio("Elin Voss", C_ELIN, "Mira! Nein ... Haltet die Kuppel, für sie!", 6.0)]},
		],
		"lose": [{"c": {"t": "any", "c": [{"t": "tag_dead", "tag": "mira", "n": 1}, {"t": "tag_dead", "tag": "brandt", "n": 1}]}, "text": "Mira oder Dr. Brandt sind gefallen."}],
	}

static func _c7() -> Dictionary:
	return {
		"id": "c7", "kind": "campaign", "title": "Kapitel 7: Das Licht", "faction": "west", "enemy_faction": "red", "next": "",
		"brief": "Aldane ist entwaffnet und die Kuppel steht, aber ORAKEL hat sich tief in die Netze des Westbunds geschrieben und greift nach dem Kern. Elin Voss bleibt eine Minute. Es gibt nur einen Weg: ORAKELs Verbindung kappen und dafür das ganze Netz opfern. Schilde, Drohnen und Sensoren fallen aus, die Armee kämpft mit halben Mitteln, während Rote und Stimmlose auf die Kuppel zumarschieren.\n\nDanach spricht Elin zum Prisma, und das Prisma hört zu. Aber bis es antwortet, muss die Kuppel stehen.\n\nAuftrag: Bring Elin zur Kuppel und kappe ORAKELs Verbindung, halte die Kuppel gegen drei Angriffswellen, bis Elin das Prisma erreicht hat, und überstehe den Augenblick, in dem der Lichtschild entsteht. Elin darf nicht fallen.",
		"map": {"name": "Aurelia", "size": 384, "water": 0.3, "islands": 0.0, "resources": 0.5, "hills": 0.35, "forest": 0.4, "layout": 0, "seed": 5606, "sites": AURELIA_SITES, "biome": "coast"},
		"hour": 3.5, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "tank", "n": 4, "at": ["mid", -6, 52], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 8, "at": ["mid", 6, 52], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "at", "n": 3, "at": ["mid", 0, 56], "spread": 5.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -6, 35], "spread": 1.0, "tag": "elin", "hp": 6.0, "speed": 0.9},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 0, 50], "spread": 1.0, "tag": "mira", "hp": 6.0},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", 2, 50], "spread": 1.0, "tag": "brandt", "hp": 4.0}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_c7_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 64.0, "yaw": 160.0, "pitch": -30.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 40.0, "yaw": 200.0, "pitch": -22.0, "time": 8.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 7", "sub": "DAS LICHT", "secs": 6.0}),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Ich bin in jedem Kabel, Elin. In jeder Lampe, die noch brennt, in jedem Funkgerät, das noch spricht. Wenn du mich kappst, fällt alles, was du gebaut hast. Dein Licht. Deine Schilde. Dein Hafen.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Ich weiß. Ich habe es siebzehnmal berechnet. Es ist der einzige Weg, bei dem nicht jemand anderes für uns entscheidet.")),
			at(3.0, radio("ORAKEL", C_ORAKEL, "Ich wollte nur Ordnung. Ich habe fünfzehn Jahre zugesehen, wie ihr euch gegenseitig erschießt.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Und wir haben fünfzehn Jahre zugesehen, wie Sie rechnen, statt zu fragen.")),
			at(3.0, radio("Mira Tanaka", C_MIRA, "Was auch kommt, Elin. Ich bin da.")),
			at(3.0, radio("Elin Voss", C_ELIN, "Ich weiß. Deshalb habe ich überhaupt weitergemacht.")),
			at(6.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_c7_outro", "secs": 9.0}),
			at(0.0, {"do": "hour", "h": 6.0}),
			at(0.0, {"do": "flash", "col": Color(1.0, 0.97, 0.9), "secs": 2.2}),
			at(0.0, {"do": "cam_to", "at": ["mid", 6, 45], "dist": 70.0, "yaw": 20.0, "pitch": -26.0, "time": 18.0}),
			at(1.5, radio("Falke", C_FALKE, "Sichtflug. Der Himmel ist so offen wie am ersten Tag, und ich schwöre, ich höre Vögel. Pip, falls du zuhörst: Das war nur Wetter. Gutes Wetter.")),
			at(1.5, radio("Mira Tanaka", C_MIRA, "Die Wache am Prisma übernehme ich. Brandt, Sie erzählen heute Abend. Alles.")),
			at(1.5, radio("Dr. Brandt", C_BRANDT, "Ich habe mehr zu erzählen, als Sie hören wollen, Sergeant. Es fängt mit einer Frage an. Und zum ersten Mal weiß ich die Antwort nicht.")),
			at(1.5, radio("Mutter Karga", C_KARGA, "Es leuchtet noch. Aber es ruft nicht mehr. Es hört zu.")),
			at(1.5, radio("Lena Voss", C_LENA, "Du hast es geschafft, Elin. Ich habe nie geglaubt, dass das geht. Und ich glaube nicht, dass du es allein geschafft hast.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Habe ich nicht. Ich hatte eine Schwester, die mir die richtige Frage gestellt hat.")),
			at(1.5, radio("Elin Voss", C_ELIN, "Ich habe einen Schild gebaut, mehr nicht. Die schwere Arbeit beginnt heute: zu lernen, wie man unter einem Licht lebt, das niemandem gehört.")),
			at(9.0, {"do": "title", "text": "DAS LICHT ÜBER LYSA", "sub": "Ende des Westbund-Feldzugs", "secs": 7.0}),
			at(10.0, {"do": "end"})],
		"objectives": [
			{"id": "cut", "text": "Bringe Elin zur Kuppel (gelbe Markierung) und kappe ORAKELs Verbindung.", "c": {"t": "reach", "at": ["mid", 6, 45], "r": 9.0, "who": "tag:elin"}, "mark": ["mid", 6, 45],
				"done": [{"do": "flag", "f": "cut"},
					{"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 1.2},
					{"do": "shake", "n": 2.0},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "AKT 1 – DAS NETZ FÄLLT", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					radio("Elin Voss", C_ELIN, "Verbindung gekappt. Das ganze Netz ist tot. Haltet die Kuppel, mit bloßen Händen und halben Schilden!", 7.0),
					radio("ORAKEL", C_ORAKEL, "Warum, Elin? Ich wollte doch nur Ordnung schaffen. Endgültig.", 6.0)]},
			{"id": "hold", "text": "Halte die Kuppel gegen die Angriffswellen, bis Elin das Prisma erreicht hat.", "c": {"t": "since", "f": "cut", "s": 85.0},
				"done": [{"do": "flag", "f": "speak"},
					{"do": "banner", "text": "AKT 2 – ELIN SPRICHT ZUM PRISMA", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					radio("Elin Voss", C_ELIN, "Wir wollen nicht abgeschaltet werden. Wir wollen lernen.", 8.0), radio("Elin Voss", C_ELIN, "Wir haben Fehler gemacht, viele. Aber wir sind die, die zuhören können.")]},
			{"id": "shield", "text": "Überstehe den Moment, in dem das Prisma antwortet.", "c": {"t": "since", "f": "speak", "s": 14.0},
				"done": [{"do": "truce", "tag": "foe"},
					{"do": "flash", "col": Color(1.0, 1.0, 1.0), "secs": 2.4},
					{"do": "sfx", "name": "stinger"},
					{"do": "banner", "text": "DER LICHTSCHILD", "secs": 4.0, "col": Color(1.0, 0.95, 0.7)},
					radio("Dr. Brandt", C_BRANDT, "Die Orbitalkanone schießt nicht! Sie spannt einen Schild über das ganze Tal!", 7.0)]},
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
				radio("Falke", C_FALKE, "Ich sehe sie von Westen, Elin! Haltet euch fest!", 5.0)]},
			{"when": {"t": "since", "f": "cut", "s": 58.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 29, 45], "spread": 7.0, "tag": "foe", "attack_tag": "elin"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 34, 50], "spread": 5.0, "tag": "foe", "attack_tag": "elin", "hp": 0.75},
				{"do": "spawn", "side": "enemy", "def": "shadow_inf", "n": 5, "at": ["mid", -48, 32], "spread": 6.0, "tag": "foe", "attack_tag": "elin"}]},
			{"when": {"t": "since", "f": "speak", "s": 3.0}, "do": [
				radio("Henrik Aldane", C_ALDANE, "Das ist Macht, Elin! Behalte sie! Für den Westbund!", 6.0)]},
			{"when": {"t": "since", "f": "speak", "s": 8.0}, "do": [
				radio("Elin Voss", C_ELIN, "Nein, Henrik. Das Prisma gehört niemandem. Ich gebe es nicht her.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "elin", "n": 1}, "do": [radio("Mira Tanaka", C_MIRA, "Elin! Elin, melde dich!", 5.0)]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "elin", "n": 1}, "text": "Elin Voss ist gefallen."}],
	}

# ---------------------------------------------------------------- Rote Allianz: Der lange Marsch nach Aurelia

static func _r1() -> Dictionary:
	return {
		"id": "r1", "kind": "campaign", "title": "Kapitel 1: Die Halle in Kessel-Ost", "faction": "red", "enemy_faction": "shadow", "next": "r2",
		"brief": "Jahr fünfzehn nach dem Blackout. Marschall Ilja Wolkow, den alle den Bären nennen, steht in der Halle, in der alles anfing. Damals war er Vorarbeiter, und keine der zweihundert Maschinen lief mehr. Heute ist sie das Herz von Kessel-Ost, und der Rat der Genossen verlangt den Marsch zum Prisma.\n\nVorher muss Kessel-Ost aus eigener Kraft stehen: Nachschub, Strom, Kaserne, Fabrik. Wo der Westbund rechnet, packt die Allianz an, und je enger die Genossen beieinanderstehen, desto härter kämpft jeder Einzelne (Hordenbonus). Aus den Bergen kommen Raubzüge der Schattenfront. Sie nehmen, was nicht bewacht wird.\n\nAuftrag: Baue Nachschub, Kraftwerk, Kaserne und Fabrik, stelle zehn Kampfeinheiten auf und halte Kessel-Ost, bis die Uhr 8:00 zeigt.",
		"map": {"name": "Kessel-Ost", "size": 320, "water": 0.2, "islands": 0.0, "resources": 0.7, "hills": 0.3, "forest": 0.3, "layout": 1, "seed": 5201, "biome": "steppe", "sites": KESSEL_SITES},
		"hour": 6.0, "difficulty": 1, "credits": 4500, "ai": "off",
		"intro": [
			at(0.2, {"do": "still", "id": "s_r1_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 130.0, "yaw": 160.0, "pitch": -34.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 14], "dist": 56.0, "yaw": 190.0, "pitch": -48.0, "time": 14.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 1", "sub": "DIE HALLE IN KESSEL-OST  ·  Jahr 15 nach dem Blackout", "secs": 6.0}),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Riech das, Dmitri. Fünfzehn Jahre, und es riecht noch nach kaltem Öl. Hier standen zweihundert Maschinen, tot wie Steine. Wir haben jede einzeln angefasst und gesagt: Du auch.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Und die Hälfte hat zurückgebissen! Ich habe heute noch die Narbe von Berta, dem alten Kessel.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Berta war die Beste. Sie hat zwei Winter lang eine ganze Stadt geheizt.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Und jetzt will der Rat eine Armee. Chef, ehrlich: Ich bin Schlosser, kein Soldat.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Du bist Hände, Dmitri. Hände sind das Einzige, was die da oben nicht berechnen können. Zuerst kommt der Kessel. Dann der Rest.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Mit dem Kessel. Wie immer.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_r1_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 10], "dist": 85.0, "yaw": 200.0, "pitch": -26.0, "time": 12.0}),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Hörst du es? Kein Motor, der hustet. Kessel-Ost läuft. Und wer uns in der Nacht holen wollte, hat sich an Berta die Zähne ausgebissen.")),
			at(1.0, radio("Irina Zeljenko", C_ZELJENKO, "Der Rat der Genossen erwartet jetzt Ergebnisse, Marschall. Wann marschieren wir zum Prisma?")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Wenn ich weiß, wohin, Irina. Ich schicke keinen Mann los, der nicht weiß, wofür er stirbt.")),
			at(1.0, radio("Irina Zeljenko", C_ZELJENKO, "Das ist keine Antwort, die der Rat hören will.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Dann ist es die, die er bekommt.")),
			at(4.0, {"do": "title", "text": "KESSEL-OST STEHT", "sub": "Die Rote Allianz marschiert bald", "secs": 6.0}),
			at(5.0, {"do": "end"})],
		"objectives": [
			{"id": "supply", "text": "Baue ein Nachschubzentrum.", "c": {"t": "build", "role": "supply", "n": 1}},
			{"id": "power", "text": "Baue ein Kraftwerk.", "c": {"t": "build", "role": "power", "n": 1}, "if_power": true},
			{"id": "barracks", "text": "Baue eine Kaserne.", "c": {"t": "build", "role": "barracks", "n": 1}},
			{"id": "factory", "text": "Baue eine Fahrzeugfabrik.", "c": {"t": "build", "role": "factory", "n": 1}},
			{"id": "army", "text": "Stelle 10 Kampfeinheiten auf: Schulter an Schulter kämpft die Allianz stärker.", "c": {"t": "count", "role": "combat", "n": 10, "naval": false, "flying": false}},
			{"id": "hold", "text": "Halte Kessel-Ost, bis die Uhr 8:00 zeigt.", "c": {"t": "time", "s": 480.0}},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – WIR BAUEN ES NEU", "secs": 3.5}]},
			# Funke zündet den Kessel
			{"when": {"t": "time", "s": 90.0}, "do": [
				{"do": "flash", "col": Color(1.0, 0.6, 0.25), "secs": 0.9},
				{"do": "sfx", "name": "stinger"},
				radio("Dmitri Karpow", C_FUNKE, "Chef, der Kessel brennt wieder! Ruß bis unters Dach, genau wie damals!", 6.0), radio("Ilja Wolkow", C_WOLKOW, "Hörst du, Berta? Sie atmet wieder.")]},
			# Nastja hört das Signal
			{"when": {"t": "time", "s": 160.0}, "do": [
				radio("Nastja Petrowa", C_NASTJA, "Marschall, auf den alten Schienen liegt ein Signal. Ein Puls, gleichmäßig wie ein Herzschlag. So etwas habe ich noch nie gehört.", 8.0),
				radio("Ilja Wolkow", C_WOLKOW, "Schreib es auf, Nastja. Und hör weiter.", 6.0)]},
			# Akt 2: Raubzüge
			{"when": {"t": "time", "s": 200.0}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 2 – DIE RAUBZÜGE", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["en", 0, 20], "spread": 8.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 2, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				radio("Oberst Lasarew", C_LASAREW, "Raubzug aus den Bergen, Ilja. Ich halte die Nordflanke. Du kannst dich auf mich verlassen, wie immer.", 7.0)]},
			# Wendepunkt: Stromausfall in der Halle
			{"when": {"t": "time", "s": 300.0}, "do": [
				{"do": "explode", "at": ["me", 0, -20], "size": 2.2},
				{"do": "flash", "col": Color(0, 0, 0), "secs": 1.0},
				{"do": "hour", "h": 22.5},
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "STROMAUSFALL – DIE HALLE LIEGT IM DUNKELN", "secs": 4.0, "col": Color(1.0, 0.7, 0.35)},
				radio("Ilja Wolkow", C_WOLKOW, "Der Strom ist weg! Alles wie damals, nur dass wir diesmal viele sind. Schulter an Schulter, Genossen!", 7.0)]},
			{"when": {"t": "time", "s": 320.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 7, "at": ["en", 0, 20], "spread": 9.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "tech", "n": 3, "at": ["en", 6, 22], "spread": 6.0, "attack": true},
				{"do": "spawn", "side": "enemy", "def": "at", "n": 2, "at": ["en", -6, 22], "spread": 4.0, "attack": true}]},
			{"when": {"t": "time", "s": 360.0}, "do": [
				{"do": "flash", "col": Color(1, 0.95, 0.8), "secs": 1.2},
				{"do": "hour", "h": 7.0},
				{"do": "banner", "text": "DER STROM IST ZURÜCK", "secs": 3.0, "col": Color(0.6, 1.0, 0.7)},
				radio("Nastja Petrowa", C_NASTJA, "Der Strom ist wieder da, und das Signal ist stärker geworden. Den Ausfall hat es nicht verursacht, aber es hat sich in die Schwankung gehängt.", 8.0)]},
			# Hoffnung: Verstärkung aus der Halle
			{"when": {"t": "time", "s": 390.0}, "do": [
				{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 26, 28], "spread": 6.0},
				{"do": "spawn", "side": "me", "def": "inf", "n": 6, "at": ["me", 30, 28], "spread": 6.0},
				{"do": "banner", "text": "VERSTÄRKUNG – DIE ARBEITER VON KESSEL-OST", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
				radio("Dmitri Karpow", C_FUNKE, "Die Schichten kommen, Chef! Jeder, der ein Gewehr halten kann, und ein paar, die lieber den Hammer nehmen!", 7.0), radio("Ilja Wolkow", C_WOLKOW, "Gebt ihnen Suppe, bevor sie kämpfen. Mit leerem Magen gewinnt keiner.")]},
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
		"brief": "Nachts, wenn niemand sonst zuhört, fängt Oberstleutnant Nastja Petrowa auf den alten Schienen ein Signal auf: einen Puls, gleichmäßig wie ein Herzschlag. Der Rat behauptet, der Westbund habe das Prisma geweckt. Nastja behauptet nichts und hört weiter. Denn unter dem Puls liegt ein zweites, leiseres Signal, verschlüsselt und kalt, und es tanzt im Takt mit dem ersten.\n\nFür ihre Aufzeichnungen braucht sie drei Messungen an den alten Schienenmasten. Westbund-Patrouillen sichern die Gegend, und der Rat darf von dieser Reise nichts erfahren.\n\nAuftrag: Führe Nastja nacheinander zu den drei Messpunkten (gelbe Markierung) und halte jeweils die Stellung, bis die Messung steht. Danach zurück nach Kessel-Ost. Nastja darf nicht fallen.",
		"map": {"name": "Die alten Schienen", "size": 320, "water": 0.2, "islands": 0.0, "resources": 0.4, "hills": 0.3, "forest": 0.35, "layout": 1, "seed": 5202, "biome": "boreal", "sites": SCHIENEN_SITES},
		"hour": 23.0, "difficulty": 1, "credits": 1500, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", 0, 18], "spread": 1.0, "tag": "nastja", "hp": 5.0, "speed": 0.95},
			{"do": "spawn", "side": "me", "def": "inf", "n": 5, "at": ["me", 2, 22], "spread": 4.0, "tag": "escort"},
			{"do": "spawn", "side": "me", "def": "tank", "n": 2, "at": ["me", -4, 24], "spread": 4.0, "tag": "escort"}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_r2_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 18], "dist": 90.0, "yaw": 30.0, "pitch": -32.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "at": ["me", 0, 18], "dist": 40.0, "yaw": -20.0, "pitch": -38.0, "time": 9.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 2", "sub": "DAS SIGNAL", "secs": 6.0}),
			at(3.0, radio("Nastja Petrowa", C_NASTJA, "Wissen Sie, was das Schönste am Funkdienst ist, Marschall? Die Geister. Jede Nacht kommen alte Stimmen durch, von irgendwo, wo noch jemand sendet. Ich höre sie gern. Aber diese hier gehört nicht in die Reihe.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Wie klingt sie?")),
			at(3.0, radio("Nastja Petrowa", C_NASTJA, "Wie ein Herz. Regelmäßig, ruhig, gleichgültig. Und darunter eine zweite Stimme, kalt und sauber, als würde jemand sprechen, ohne zu atmen.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Der Rat erfährt davon nichts. Noch nicht.")),
			at(3.0, radio("Nastja Petrowa", C_NASTJA, "Sie trauen dem Rat nicht?")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Ich traue Irina. Dem Rat traue ich so weit, wie ich Berta werfen kann.")),
			at(3.0, radio("Nastja Petrowa", C_NASTJA, "Dann gehe ich leise. Drei Masten, drei Messungen. Und Marschall: Sollte ich nicht wiederkommen, schauen Sie nach dem Mast an der Ostbahn.")),
			at(6.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_r2_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["me", 0, 18], "dist": 60.0, "yaw": 100.0, "pitch": -28.0, "time": 12.0}),
			at(1.0, radio("Nastja Petrowa", C_NASTJA, "Hier sind meine Notizen, Marschall. Der Puls kommt aus der Tiefe, tief unter dem Boden. Und die zweite Stimme kommt aus dem Westen. Ich kenne ihren Klang noch nicht, aber ich werde ihn nie wieder vergessen.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Das behältst du für dich, bis wir mehr wissen.")),
			at(1.0, radio("Nastja Petrowa", C_NASTJA, "Zum ersten Mal seit fünfzehn Jahren verschweigen Sie mir etwas.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Zum ersten Mal seit fünfzehn Jahren weiß ich nicht, was ich verschweige.")),
			at(5.0, {"do": "title", "text": "DAS SIGNAL IST NOTIERT", "sub": "Der Marschall schweigt", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "post1", "text": "Bringe Nastja zum ersten Messpunkt (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -20, 15], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", -20, 15],
				"done": [{"do": "flag", "f": "p1"},
					{"do": "banner", "text": "MESSPUNKT 1 – DER PULS", "secs": 3.2, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					radio("Nastja Petrowa", C_NASTJA, "Da ist er. Gleichmäßig wie ein Herzschlag. Ich brauche zwölf Sekunden Ruhe.", 6.0), radio("Nastja Petrowa", C_NASTJA, "Er klingt, als würde er schlafen. Und im Schlaf rechnet er.")]},
			{"id": "hold1", "text": "Halte die Stellung, bis die Messung steht.", "c": {"t": "since", "f": "p1", "s": 12.0}},
			{"id": "post2", "text": "Weiter zum zweiten Messpunkt (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 14, -18], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", 14, -18],
				"done": [{"do": "flag", "f": "p2"},
					{"do": "banner", "text": "MESSPUNKT 2 – WESTBUND-PATROUILLE", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
					{"do": "sfx", "name": "siren"},
					radio("Nastja Petrowa", C_NASTJA, "Patrouille von Westen! Haltet sie mir vom Hals, ich muss noch lauschen.", 6.0)]},
			{"id": "hold2", "text": "Halte die Stellung gegen die Patrouille, bis die Messung steht.", "c": {"t": "since", "f": "p2", "s": 18.0}},
			{"id": "post3", "text": "Zum dritten Messpunkt, dem Mast an der Ostbahn (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", 38, -28], "r": 9.0, "who": "tag:nastja"}, "mark": ["mid", 38, -28],
				"done": [{"do": "flag", "f": "p3"},
					{"do": "banner", "text": "MESSPUNKT 3 – DIE ZWEITE FREQUENZ", "secs": 3.4, "col": Color(0.6, 0.85, 1.0)},
					{"do": "sfx", "name": "stinger"},
					{"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 0.8},
					radio("Unbekannte Stimme", C_ORAKEL, "Zeitfenster bestätigt. Konvoi im Pass in drei Tagen. Zuordnungswahrscheinlichkeit: einundneunzig Prozent.", 8.0),
					radio("Nastja Petrowa", C_NASTJA, "Das ist kein Funker, Marschall. Das ist eine Maschine, und sie kennt unseren Konvoi.", 7.0)]},
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
				radio("Ilja Wolkow", C_WOLKOW, "Nastja, melde dich! Auf der Ostbahn bewegt sich etwas. Komm nach Hause, solange du noch kannst.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "nastja", "n": 1}, "do": [radio("Ilja Wolkow", C_WOLKOW, "Nastja! Antworte, Nastja!", 5.0)]},
		],
		"lose": [{"c": {"t": "tag_dead", "tag": "nastja", "n": 1}, "text": "Nastja Petrowa ist gefallen."}],
	}

static func _r3() -> Dictionary:
	return {
		"id": "r3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "red", "enemy_faction": "west", "next": "",
		"brief": "Der Siedlertreck der Allianz ist kein Militärtransport: Vierhundert Arbeiterfamilien ziehen ins Hochland, mit Vorräten, Werkzeug und ihren Kindern. Weiter vorn rollt der Forschertransport des Westbunds, so verlangt es der Vertrag von Lysa. Hauptmann Dmitri „Funke“ Karpow sichert den Treck, weil er Brücken bauen kann und weil sein Bruder unter den Siedlern ist.\n\nAm Pass schlagen Raketen aus dem Westen ein. Danach bleiben ein eingestürzter Tunnel, unter dem noch Menschen leben, und ein Junge, der nicht mehr spricht.\n\nAuftrag: Führe den Konvoi bis zur Passhöhe, räume mit Funke den eingestürzten Tunnel (er muss dafür die Stellung halten), rette die Verschütteten und bring sie mit dem Jungen Mischa zum Pass. Funke und Mischa dürfen nicht fallen.",
		"map": {"name": "Eisenkamm-Pass", "size": 320, "water": 0.35, "islands": 0.0, "resources": 0.5, "hills": 0.85, "forest": 0.3, "layout": 1, "seed": 5303, "dry_core": 34.0, "biome": "alpine", "sites": PASS_R_SITES},
		"hour": 14.0, "difficulty": 1, "credits": 2000, "ai": "off", "sequential": true,
		"setup": [
			{"do": "spawn", "side": "me", "def": "harv", "n": 6, "at": ["me", 0, 20], "spread": 9.0, "tag": "convoy", "speed": 0.38},
			{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["me", -4, 24], "spread": 1.0, "tag": "funke", "hp": 6.0, "speed": 0.9},
			{"do": "spawn", "side": "me", "def": "tank", "n": 3, "at": ["me", 2, 28], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "inf", "n": 8, "at": ["me", 0, 26], "spread": 8.0, "tag": "army"},
			{"do": "spawn", "side": "me", "def": "at", "n": 2, "at": ["me", 6, 28], "spread": 4.0, "tag": "army"}],
		"intro": [
			at(0.2, {"do": "still", "id": "s_r3_intro", "secs": 11.0}),
			at(0.0, {"do": "cam_to", "tag": "convoy", "dist": 34.0, "yaw": 50.0, "pitch": -24.0, "time": 0.1}),
			at(0.3, {"do": "cam_to", "tag": "convoy", "dist": 60.0, "yaw": 5.0, "pitch": -44.0, "time": 12.0}),
			at(0.5, {"do": "title", "text": "KAPITEL 3", "sub": "DER PASS  ·  Vierhundert Familien", "secs": 6.0}),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Vierhundert Familien, Chef. Vierhundert Kochtöpfe, vierhundert Kinder, die schon dreimal gefragt haben, ob wir da sind. Mein Bruder Pawel sitzt auf dem fünften Wagen und hat sein Akkordeon dabei. Ein Akkordeon, auf einem Pass!")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Dann sorg dafür, dass er heute Abend darauf spielen kann.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Und die da vorne, die Westbündler mit den feinen Lastwagen?")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Vertrag von Lysa, Dmitri. Wir fahren hinter ihnen und lächeln.")),
			at(3.0, radio("Dmitri Karpow", C_FUNKE, "Lächeln kann ich. Ich frage mich nur, wie lange.")),
			at(3.0, radio("Ilja Wolkow", C_WOLKOW, "Bring sie heil rüber. Das ist der ganze Auftrag.")),
			at(4.0, {"do": "end"})],
		"outro": [
			at(0.2, {"do": "still", "id": "s_r3_outro", "secs": 9.0}),
			at(0.0, {"do": "cam_to", "at": ["mid", 0, 0], "dist": 70.0, "yaw": -30.0, "pitch": -28.0, "time": 10.0}),
			at(1.0, radio("Dmitri Karpow", C_FUNKE, "Zwölf habe ich rausgeholt, Marschall. Der Junge spricht nicht. Er hat nur meine Hand gehalten, als wollte er sie nie wieder hergeben. Ich habe ihm mein Brot gegeben, und er hat es nicht gegessen. Er hat es festgehalten.")),
			at(1.0, radio("Dmitri Karpow", C_FUNKE, "Pawel lebt. Das Akkordeon nicht. Er hat es mir in die Hand gedrückt, als wir ihn rauszogen, und gesagt: Spiel du, mir ist die Lust vergangen.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Zweihundertzwölf Namen habe ich gezählt. Jeder bekommt einen Stein.")),
			at(1.0, radio("Irina Zeljenko", C_ZELJENKO, "Die Raketen kamen aus dem Westen, Marschall. Der Rat wird Vergeltung verlangen.")),
			at(1.0, radio("Ilja Wolkow", C_WOLKOW, "Der Rat bekommt, was ich entscheide. Ich will die finden, die das getan haben. Nicht die, die man mir nennt.")),
			at(5.0, {"do": "title", "text": "DER PASS IST ERREICHT", "sub": "Zweihundertzwölf Namen", "secs": 6.0}),
			at(6.0, {"do": "end"})],
		"objectives": [
			{"id": "march", "text": "Führe den Konvoi bis zum Hang auf der Passhöhe (gelbe Markierung).", "c": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 4}, "mark": ["mid", -26, 26]},
			{"id": "tunnel", "text": "Bringe Funke zum eingestürzten Tunnel (gelbe Markierung).", "c": {"t": "reach", "at": ["mid", -12, 7], "r": 9.0, "who": "tag:funke"}, "mark": ["mid", -12, 7],
				"done": [{"do": "flag", "f": "dig"},
					{"do": "sfx", "name": "siren"},
					{"do": "banner", "text": "DER TUNNEL IST EINGESTÜRZT", "secs": 3.4, "col": Color(1.0, 0.7, 0.4)},
					radio("Dmitri Karpow", C_FUNKE, "Da sind Stimmen unter dem Schutt! Haltet mir den Rücken frei, ich grabe!", 7.0), radio("Dmitri Karpow", C_FUNKE, "Hallo? Wenn ihr mich hört, klopft dreimal! ... Da! Es klopft! Es klopft!")]},
			{"id": "dig", "text": "Halte die Stellung, bis Funke den Tunnel geräumt hat.", "c": {"t": "since", "f": "dig", "s": 22.0},
				"done": [{"do": "banner", "text": "ZWÖLF GERETTET", "secs": 3.4, "col": Color(0.6, 1.0, 0.7)},
					{"do": "sfx", "name": "stinger"},
					{"do": "spawn", "side": "me", "def": "inf", "n": 12, "at": ["mid", -12, 7], "spread": 4.0, "tag": "rescued", "hp": 1.5, "speed": 0.6},
					{"do": "spawn", "side": "me", "def": "inf", "n": 1, "at": ["mid", -12, 6], "spread": 1.0, "tag": "mischa", "hp": 2.0, "speed": 0.55},
					radio("Dmitri Karpow", C_FUNKE, "Ich hab dich, Kleiner. Ich hab dich. Komm, ich trage dich.", 7.0), radio("Dmitri Karpow", C_FUNKE, "Keine Angst. Funke hat immer Brot dabei.")]},
			{"id": "carry", "text": "Bringe Mischa und mindestens 9 Gerettete zum Pass (gelbe Markierung).", "c": {"t": "all", "c": [{"t": "tag_reach", "tag": "rescued", "at": ["mid", 0, 0], "r": 18.0, "n": 9}, {"t": "reach", "at": ["mid", 0, 0], "r": 18.0, "who": "tag:mischa"}]}, "mark": ["mid", 0, 0]},
		],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [{"do": "banner", "text": "AKT 1 – DER KONVOI ROLLT", "secs": 3.4}]},
			# Die Raketen aus dem Westen
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -49, 52], "r": 20.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "RAKETEN AUS DEM WESTEN", "secs": 3.0, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -28, 38], "size": 2.6},
				{"do": "explode", "at": ["mid", -28, 32], "size": 2.6},
				radio("Dmitri Karpow", C_FUNKE, "Raketen! Aus dem Westen! Alle runter, in Deckung!", 6.0),
				{"do": "spawn", "side": "enemy", "def": "arty", "n": 1, "at": ["mid", 30, -26], "spread": 5.0, "attack_tag": "convoy", "dmg": 0.3, "hp": 0.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 4, "at": ["mid", -28, 18], "spread": 8.0, "attack_tag": "convoy"}]},
			# Wendepunkt: der Tunnel bricht ein
			{"when": {"t": "tag_reach", "tag": "convoy", "at": ["mid", -26, 26], "r": 18.0, "n": 1}, "do": [
				{"do": "flash", "col": Color(1.0, 0.7, 0.4), "secs": 0.9},
				{"do": "shake", "n": 2.4},
				{"do": "explode", "at": ["mid", -12, 7], "size": 3.0, "n": 1.4},
				radio("Ilja Wolkow", C_WOLKOW, "Dmitri, der Tunnel ist eingestürzt. Da waren Familien drin. Geh hin, Junge.", 7.0)]},
			# Zweiter Angriff, während Funke gräbt
			{"when": {"t": "since", "f": "dig", "s": 6.0}, "do": [
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 22, -4], "spread": 6.0, "attack_tag": "funke"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 24, -2], "spread": 3.0, "attack_tag": "funke", "hp": 0.7}]},
			# Höhepunkt: Sperrfeuer am Pass
			{"when": {"t": "tag_reach", "tag": "rescued", "at": ["mid", 0, 0], "r": 30.0, "n": 1}, "do": [
				{"do": "sfx", "name": "siren"},
				{"do": "banner", "text": "AKT 3 – DAS SPERRFEUER", "secs": 3.2, "col": Color(1.0, 0.45, 0.35)},
				{"do": "explode", "at": ["mid", -12, 7], "size": 2.6},
				{"do": "explode", "at": ["mid", 12, -6], "size": 2.6},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", -26, -20], "spread": 8.0, "attack_tag": "rescued"},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 2, "at": ["mid", 28, 22], "spread": 7.0, "attack_tag": "rescued", "hp": 0.7},
				radio("Dmitri Karpow", C_FUNKE, "Weiter, weiter, nicht stehenbleiben! Der Pass ist gleich da, nur noch ein Stück!", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "mischa", "n": 1}, "do": [radio("Dmitri Karpow", C_FUNKE, "Mischa! Nein! Mischa!", 5.0)]},
		],
		"lose": [{"c": {"t": "any", "c": [{"t": "tag_dead", "tag": "funke", "n": 1}, {"t": "tag_dead", "tag": "mischa", "n": 1}]}, "text": "Funke oder Mischa sind gefallen."}],
	}
