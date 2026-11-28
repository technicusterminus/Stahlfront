extends RefCounted
## Kampagnenkapitel der Roten Allianz (r4–r7) und der Schattenfront (s1–s7).
## Gleiche Datenform wie scripts/missions.gd; die Karten (mit ihren trockengeprüften Orten) reicht missions.gd herein.
## Das Gerüst jedes Kapitels: eine Heldenfigur (hp-fest, Verlust = Niederlage), eine Armee, Ziele als Kette
## aus "Erreiche X" und "Halte die Stellung", Gegner kommen in Wellen nach Auslösern.

const C_WOLKOW := Color(1.0, 0.55, 0.5)
const C_NASTJA := Color(1.0, 0.75, 0.6)
const C_FUNKE := Color(1.0, 0.85, 0.45)
const C_ZELJENKO := Color(0.95, 0.5, 0.55)
const C_LASAREW := Color(0.85, 0.7, 0.65)
const C_ASHA := Color(0.75, 0.95, 0.7)
const C_JAGO := Color(1.0, 0.8, 0.4)
const C_KARGA := Color(0.95, 0.8, 0.6)
const C_LENA := Color(1.0, 0.65, 0.55)
const C_WEHN := Color(0.8, 0.85, 0.95)
const C_DORN := Color(0.85, 0.6, 0.45)
const C_PIP := Color(1.0, 0.95, 0.6)
const C_ELIN := Color(0.7, 0.95, 0.85)
const C_ORAKEL := Color(0.45, 0.95, 1.0)
const C_REYES := Color(0.65, 0.9, 1.0)

static func radio(who: String, col: Color, text: String, secs := 0.0) -> Dictionary:
	return {"do": "radio", "who": who, "col": col, "text": text, "secs": secs}

static func at(t: float, a: Dictionary) -> Dictionary:
	var d = a.duplicate()
	d["t"] = t
	return d

## lines: [[Name, Farbe, Text], ...]
static func _intro(sid: String, cam: Array, d1: float, d2: float, yaw: float, kap: String, sub: String, lines: Array, hour_cut := -1.0) -> Array:
	var a: Array = [
		at(0.2, {"do": "still", "id": sid, "secs": 11.0}),
		at(0.0, {"do": "cam_to", "at": cam, "dist": d1, "yaw": yaw, "pitch": -34.0, "time": 0.1}),
		at(0.3, {"do": "cam_to", "at": cam, "dist": d2, "yaw": yaw + 35.0, "pitch": -42.0, "time": 6.0}),
		at(0.5, {"do": "title", "text": kap, "sub": sub, "secs": 6.0})]
	for l in lines:
		a.append(at(3.0, _line(l)))
	a.append(at(4.0, {"do": "end"}))
	return a

## Filmzeile: [Sprecher, Farbe, Text] oder [Sprecher, Farbe, Text, Kamera]; die Kamera fährt los, sobald die Zeile beginnt.
static func _line(l: Array) -> Dictionary:
	var r := radio(l[0], l[1], l[2])
	if l.size() > 3:
		r["cam"] = l[3]
	return r

static func _outro(sid: String, cam: Array, dist: float, kap: String, sub: String, lines: Array) -> Array:
	var a: Array = [
		at(0.2, {"do": "still", "id": sid, "secs": 9.0}),
		at(0.0, {"do": "cam_to", "at": cam, "dist": dist, "yaw": -30.0, "pitch": -28.0, "time": 11.0})]
	for l in lines:
		a.append(at(1.0, _line(l)))
	a.append(at(5.0, {"do": "title", "text": kap, "sub": sub, "secs": 6.0}))
	a.append(at(6.0, {"do": "end"}))
	return a

static func _map(base: Dictionary, name: String) -> Dictionary:
	var m = base.duplicate(true)
	m["name"] = name
	return m

static func _reach(id: String, text: String, at_spec: Array, who: String, done: Array = [], r := 10.0) -> Dictionary:
	return {"id": id, "text": text, "c": {"t": "reach", "at": at_spec, "r": r, "who": who}, "mark": at_spec, "done": done}

static func _hold(id: String, flag: String, secs: float, text: String, done: Array = []) -> Dictionary:
	return {"id": id, "text": text, "c": {"t": "since", "f": flag, "s": secs}, "done": done}

static func _banner(text: String, col := Color(1.0, 0.85, 0.4), secs := 3.2) -> Dictionary:
	return {"do": "banner", "text": text, "secs": secs, "col": col}

static func _wave(n: int, def: String, spot: Array, target: String, hp := 1.0) -> Dictionary:
	var d := {"do": "spawn", "side": "enemy", "def": def, "n": n, "at": spot, "spread": 6.0, "attack_tag": target, "tag": "foe"}
	if hp != 1.0:
		d["hp"] = hp
	return d

static func _me(def: String, n: int, spot: Array, tag: String, spread := 5.0, hp := 1.0, speed := 0.0) -> Dictionary:
	var d := {"do": "spawn", "side": "me", "def": def, "n": n, "at": spot, "spread": spread, "tag": tag}
	if hp != 1.0:
		d["hp"] = hp
	if speed > 0.0:
		d["speed"] = speed
	return d

static func _lose_if_dead(tag: String, text: String) -> Array:
	return [{"c": {"t": "tag_dead", "tag": tag, "n": 1}, "text": text}]

# =====================================================================================================================
#  ROTE ALLIANZ
# =====================================================================================================================

static func red(maps: Dictionary) -> Array:
	return [_r4(maps), _r5(maps), _r6(maps), _r7(maps)]

static func _r4(maps: Dictionary) -> Dictionary:
	return {
		"id": "r4", "kind": "campaign", "title": "Kapitel 4: Der lange Marsch", "faction": "red", "enemy_faction": "shadow", "next": "r5",
		"brief": "Die Allianz marschiert in drei Kolonnen. Die erste gerät an einen tiefen Einschnitt der Ostbahn, und der Viadukt ist gesprengt. Hinter dem Einschnitt warten Stellungen, davor wartet nur die Zeit.\n\nHauptmann Dmitri „Funke“ Karpow hat Brücken gebaut, als es noch Brücken gab. Jetzt soll er eine aus Schienen und Containern bauen, unter Beschuss, und Mischa sitzt dabei auf seiner Schulter.\n\nAuftrag: Bringe Funke ans Ufer, halte die Stellung, bis die Behelfsbrücke steht, führe die Kolonne hinüber und erreiche den Bunker an der Ostbahn. Funke darf nicht fallen.",
		"map": _map(maps["rails"], "Der gesprengte Viadukt"), "rain": 0.3,
		"hour": 5.0, "difficulty": 1, "credits": 3500, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 20], "funke", 1.0, 6.0, 0.9),
			_me("tank", 4, ["me", 0, 28], "army", 9.0), _me("inf", 8, ["me", 0, 32], "army", 9.0),
			_me("at", 2, ["me", 6, 32], "army", 4.0), _me("harv", 4, ["me", -6, 24], "convoy", 6.0, 1.0, 0.45)],
		"intro": _intro("s_r4_intro", ["me", 0, 24], 110.0, 52.0, 40.0, "KAPITEL 4", "DER LANGE MARSCH  ·  Der gesprengte Viadukt", [
			["Dmitri Karpow", C_FUNKE, "Chef, sie haben die Brücke weggeblasen. Nicht abgebrannt, nicht beschädigt, weggeblasen. Da, wo sie war, ist jetzt ein Loch mit sehr viel Luft darunter.", {"at": ["mid", -20, 15], "dist": 110.0, "yaw": 35.0, "pitch": -42.0}],
			["Ilja Wolkow", C_WOLKOW, "Wie lange brauchst du?"],
			["Dmitri Karpow", C_FUNKE, "Mit Schienen, Containern und ein bisschen Dummheit? Sechs Stunden. Mit Beschuss von drüben vielleicht sieben.", {"at": ["me", 4, 22], "dist": 38.0, "yaw": 15.0, "pitch": -24.0}],
			["Ilja Wolkow", C_WOLKOW, "Mischa ist bei dir?"],
			["Dmitri Karpow", C_FUNKE, "Auf meiner Schulter. Er hat schon gefragt, ob die Brücke wehtut, wenn man sie sprengt.", {"tag": "funke", "dist": 24.0, "yaw": -20.0, "pitch": -18.0}],
			["Ilja Wolkow", C_WOLKOW, "Was hast du gesagt?"],
			["Dmitri Karpow", C_FUNKE, "Dass Brücken nichts spüren. Ich glaube, er hat mir nicht geglaubt.", {"at": ["mid", 14, -18], "dist": 75.0, "yaw": 50.0, "pitch": -32.0}]]),
		"outro": _outro("s_r4_outro", ["mid", 26, 0], 70.0, "DIE KOLONNE IST DRÜBEN", "Und im Bunker: der Schlaf", [
			["Dmitri Karpow", C_FUNKE, "Sie steht, Marschall. Sie knarzt wie ein altes Bett, aber sie trägt. Mischa ist als Erster rübergelaufen und hat in die Tiefe gespuckt. Sein Kommentar: Du bist schnell.", {"at": ["mid", 0, 0], "dist": 60.0, "yaw": -25.0, "pitch": -28.0}],
			["Ilja Wolkow", C_WOLKOW, "Und der Bunker an der Ostbahn?"],
			["Irina Zeljenko", C_ZELJENKO, "Dahinter liegt der Schlaf, Marschall. Der Rat will ihn heute Nacht zünden. Ich bin dafür. Sagen Sie mir, dass Sie es sind.", {"at": ["mid", 38, -28], "dist": 46.0, "yaw": 10.0, "pitch": -22.0}],
			["Ilja Wolkow", C_WOLKOW, "Wir brauchen keine Waffe, die uns selbst tötet, Irina."],
			["Irina Zeljenko", C_ZELJENKO, "Dann haben wir ein Problem, Genosse Marschall."],
			["Nastja Petrowa", C_NASTJA, "Marschall, Nachricht aus Kessel-Ost. Ihr Vater ist heute Nacht gestorben. Auf seinem Tisch lag ein Umschlag für Sie.", {"tag": "funke", "dist": 30.0, "yaw": 160.0, "pitch": -20.0}],
			["Ilja Wolkow", C_WOLKOW, "Ein Satz, Nastja. Frag, wer in der Nacht den Rückzug für das Dritte Bataillon befohlen hat. Ich kenne die Antwort. Ich will sie nicht denken.", {"at": ["mid", 38, -28], "dist": 95.0, "yaw": 200.0, "pitch": -36.0}]]),
		"objectives": [
			_reach("shore", "Bringe Funke an den Rand des gesprengten Viadukts (gelbe Markierung).", ["mid", -20, 15], "tag:funke", [
				{"do": "flag", "f": "build"}, _banner("AKT 1 – DIE BEHELFSBRÜCKE", Color(1.0, 0.85, 0.4)), {"do": "sfx", "name": "stinger"},
				radio("Dmitri Karpow", C_FUNKE, "Schienen her, Container her! Ich brauche jede Hand, die einen Hammer halten kann. Und jede, die ein Gewehr halten kann, bitte nach draußen!", 7.0)], 14.0),
			_hold("build", "build", 26.0, "Halte die Stellung, bis die Behelfsbrücke steht.", [
				_banner("DIE BRÜCKE STEHT", Color(0.6, 1.0, 0.7)), {"do": "sfx", "name": "stinger"},
				radio("Dmitri Karpow", C_FUNKE, "Fertig! Wer sie betritt, bitte nicht im Gleichschritt, sonst fällt sie uns auf den Kopf.", 7.0)]),
			_reach("cross", "Führe die Kolonne über die Brücke auf die andere Seite (gelbe Markierung).", ["mid", 14, -18], "any", [
				{"do": "flag", "f": "cross"}, _banner("AKT 2 – DIE ANDERE SEITE", Color(1.0, 0.45, 0.35)),
				radio("Ilja Wolkow", C_WOLKOW, "Dmitri, wir brauchen die Ostbahn. Der Bunker, der dort liegt, darf nicht in fremde Hände.", 7.0)], 14.0),
			_reach("bunker", "Erreiche den Bunker an der Ostbahn (gelbe Markierung).", ["mid", 38, -28], "any", [
				_banner("DER BUNKER AN DER OSTBAHN", Color(1.0, 0.7, 0.4)), {"do": "flash", "col": Color(0.4, 0.5, 0.6), "secs": 0.8},
				radio("Irina Zeljenko", C_ZELJENKO, "Pioniere melden: hinter der Tür steht Beton, drei Meter dick, und ein Schild. Der Schlaf. Jemand hat ihn mit Kreide gezeichnet, als wäre es ein Kinderspiel.", 8.0),
				radio("Ilja Wolkow", C_WOLKOW, "Niemand rührt etwas an. Niemand.", 5.0)], 14.0)],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 4 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "build", "s": 5.0}, "do": [_wave(4, "inf", ["mid", 8, -4], "funke"), _banner("FEUER VON DRÜBEN", Color(1.0, 0.45, 0.35), 3.0), {"do": "sfx", "name": "siren"}]},
			{"when": {"t": "since", "f": "build", "s": 14.0}, "do": [_wave(3, "inf", ["mid", 16, -26], "funke"), _wave(1, "tank", ["mid", 18, -24], "funke", 0.7),
				radio("Dmitri Karpow", C_FUNKE, "Die schießen auf alles, was sich bewegt! Auf mich, auf die Schienen, auf mein Werkzeug. Haltet sie mir vom Rücken!", 6.0)]},
			{"when": {"t": "flag", "f": "cross"}, "do": [_wave(5, "inf", ["mid", 44, -16], "army"), _wave(2, "at", ["mid", 46, -14], "army")]},
			{"when": {"t": "tag_dead", "tag": "funke", "n": 1}, "do": [radio("Ilja Wolkow", C_WOLKOW, "Dmitri! Antworte! Dmitri!", 5.0)]}],
		"auto": {"heroes": ["funke"], "move": ["army"], "nudge": false},
		"lose": _lose_if_dead("funke", "Funke ist gefallen."),
	}

static func _r5(maps: Dictionary) -> Dictionary:
	return {
		"id": "r5", "kind": "campaign", "title": "Kapitel 5: Die Frequenz", "faction": "red", "enemy_faction": "west", "next": "r6",
		"brief": "Drei Nächte lang hat Oberstleutnant Nastja Petrowa die Mitschnitte der zweiten Stimme dekodiert. Jetzt kennt sie die Befehlssequenz, die dem Anschlag am Pass vorausging, und sie trägt eine Unterschrift, die in der ganzen Allianz nur ein Mann kennt: Oberst Gregor Lasarew.\n\nSie hat nur einen Beweis, und der liegt auf der Frequenz selbst. Um ihn zu sichern, muss Nastja an die alten Masten zurück, bevor jemand die Aufzeichnung löscht. Ilja Wolkow weiß schon, was sie finden wird, und hat beschlossen zu schweigen.\n\nAuftrag: Bringe Nastja zu den drei Masten, sichere die Sequenz und kehre nach Kessel-Ost zurück. Nastja darf nicht fallen.",
		"map": _map(maps["rails"], "Die Frequenz"), "rain": 0.0,
		"hour": 2.0, "difficulty": 1, "credits": 1500, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "nastja", 1.0, 5.0, 0.95),
			_me("inf", 6, ["me", 2, 22], "army", 4.0), _me("tank", 2, ["me", -4, 24], "army", 4.0)],
		"intro": _intro("s_r5_intro", ["me", 0, 18], 90.0, 40.0, 70.0, "KAPITEL 5", "DIE FREQUENZ", [
			["Nastja Petrowa", C_NASTJA, "Drei Nächte, Marschall. Drei Nächte mit Kopfhörern, Kaffee und einem Papierstreifen, der länger wurde, bis ich ihn lesen konnte. Es ist eine Befehlssequenz, abgesetzt am Abend vor dem Pass. Und am Ende steht ein Code.", {"tag": "nastja", "dist": 28.0, "yaw": 25.0, "pitch": -20.0}],
			["Ilja Wolkow", C_WOLKOW, "Wessen Code?"],
			["Nastja Petrowa", C_NASTJA, "Den kennt nur einer von uns. Ich sage ihn nicht laut, solange Sie nicht sagen, dass ich ihn sagen darf."],
			["Ilja Wolkow", C_WOLKOW, "Gregor Lasarew. Mein Vater hat es mir hinterlassen, bevor er starb.", {"at": ["me", 0, 30], "dist": 34.0, "yaw": -35.0, "pitch": -22.0}],
			["Nastja Petrowa", C_NASTJA, "Und Sie tun nichts?"],
			["Ilja Wolkow", C_WOLKOW, "Ich warte. Wenn ich ihn jetzt festnehme, bricht die Armee. Wenn ich warte, zeigt er mir, für wen er arbeitet.", {"at": ["me", 0, 24], "dist": 50.0, "yaw": -60.0, "pitch": -26.0}],
			["Nastja Petrowa", C_NASTJA, "Dann sichere ich den Beweis, bevor jemand ihn löscht. Und Marschall: Ich gehe mit Ihnen. Niemand geht allein.", {"at": ["mid", -15, 10], "dist": 95.0, "yaw": 10.0, "pitch": -34.0}]]),
		"outro": _outro("s_r5_outro", ["me", 0, 18], 60.0, "DER BEWEIS IST GESICHERT", "Niemand geht allein", [
			["Nastja Petrowa", C_NASTJA, "Es liegt im Panzerschrank, dreifach kopiert, in drei verschiedenen Händen. Wenn mir etwas passiert, finden Sie die Kopien.", {"tag": "nastja", "dist": 40.0, "yaw": -15.0, "pitch": -26.0}],
			["Ilja Wolkow", C_WOLKOW, "Dir passiert nichts."],
			["Nastja Petrowa", C_NASTJA, "Das habe ich auch gesagt, als ich Funkerin wurde. Der Kessel hat andere Pläne mit uns allen."],
			["Oberst Lasarew", C_LASAREW, "Marschall, da bin ich. Ich habe mich schon gefragt, wo Sie die ganze Nacht stecken. Der Rat ist unruhig.", {"at": ["me", 6, 26], "dist": 28.0, "yaw": 140.0, "pitch": -20.0}],
			["Ilja Wolkow", C_WOLKOW, "Dann beruhige den Rat, Gregor. Sag ihm, ich komme ausgeruht nach Aurelia.", {"at": ["me", 0, 18], "dist": 70.0, "yaw": 180.0, "pitch": -32.0}]]),
		"objectives": [
			_reach("mast1", "Bringe Nastja zum ersten Mast (gelbe Markierung).", ["mid", -20, 15], "tag:nastja", [
				{"do": "flag", "f": "m1"}, _banner("MAST 1 – DER EINGANG DER SEQUENZ", Color(0.6, 0.85, 1.0)), {"do": "sfx", "name": "stinger"},
				radio("Nastja Petrowa", C_NASTJA, "Da. Der Anfang der Sequenz. Ich brauche vierzehn Sekunden Ruhe, jemand hat sie gerade erst überschrieben.", 7.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 3, "at": ["mid", 84, -70], "spread": 3.0, "tag": "loescher", "speed": 0.2},
				{"do": "convoy", "tag": "loescher", "to": ["mid", 14, -18]},
				_banner("EIN LÖSCHTRUPP LÄUFT AUF MAST 2 ZU", Color(1.0, 0.45, 0.35), 3.4),
				radio("Ilja Wolkow", C_WOLKOW, "Nastja, drei Mann laufen auf deinen zweiten Mast zu. Mit Werkzeug, nicht mit Gewehren. Die wollen löschen.", 7.0)]),
			_hold("hold1", "m1", 14.0, "Halte die Stellung, bis der Anfang gesichert ist."),
			_reach("mast2", "Erreiche den zweiten Mast vor dem Löschtrupp, oder halte ihn auf (gelbe Markierung).", ["mid", 14, -18], "tag:nastja", [
				{"do": "flag", "f": "m2"}, _banner("MAST 2 – DIE MITTE DER SEQUENZ", Color(1.0, 0.45, 0.35)), {"do": "sfx", "name": "siren"},
				radio("Nastja Petrowa", C_NASTJA, "Marschall, hier hat jemand gelöscht, und zwar gestern. Ich lese noch einen Rest. Haltet mir die Leute vom Leib, die gleich kommen.", 8.0)]),
			_hold("hold2", "m2", 20.0, "Halte die Stellung, bis die Mitte gesichert ist."),
			_reach("bahnhof", "Zum alten Bahnhof, dem dritten Punkt (gelbe Markierung).", ["mid", -14, -50], "tag:nastja", [
				{"do": "flag", "f": "m3"}, _banner("DER BAHNHOF – DIE UNTERSCHRIFT", Color(0.6, 0.85, 1.0)), {"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 0.8},
				radio("Nastja Petrowa", C_NASTJA, "Hier ist sie. Die Unterschrift, mit Lasarews Chiffre. Und darunter, ganz leise, ein zweiter Zeichensatz: ORAKEL. Es hat Lasarew Befehle gegeben und sie als Ratsbefehle ausgegeben.", 9.0)]),
			_hold("hold3", "m3", 22.0, "Halte die Stellung, bis die Unterschrift gesichert ist.", [
				radio("Unbekannte Stimme", C_ORAKEL, "Die Aufzeichnung ist unvollständig. Ich empfehle die Löschung.", 6.0)]),
			_reach("home", "Bringe Nastja zurück nach Kessel-Ost (gelbe Markierung).", ["me", 0, 18], "tag:nastja", [], 12.0)],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 5 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "m1", "s": 6.0}, "do": [_wave(3, "inf", ["mid", -28, 26], "nastja")]},
			{"when": {"t": "since", "f": "m2", "s": 3.0}, "do": [_wave(5, "inf", ["mid", 22, -4], "nastja"), _wave(1, "tank", ["mid", 24, -2], "nastja", 0.7)]},
			{"when": {"t": "since", "f": "m3", "s": 8.0}, "do": [_banner("DIE AUFZEICHNUNG WIRD GELÖSCHT", Color(1.0, 0.45, 0.35), 3.0), {"do": "sfx", "name": "siren"},
				_wave(5, "inf", ["mid", 0, -78], "nastja"), _wave(2, "tank", ["mid", 2, -80], "nastja", 0.7)]},
			{"when": {"t": "tag_dead", "tag": "nastja", "n": 1}, "do": [radio("Ilja Wolkow", C_WOLKOW, "Nastja! Hörst du mich? Nastja!", 5.0)]}],
		"auto": {"heroes": ["nastja"], "move": ["army"], "nudge": false},
		"lose": _lose_if_dead("nastja", "Nastja Petrowa ist gefallen.") + [
			{"c": {"t": "all", "c": [{"t": "tag_reach", "tag": "loescher", "at": ["mid", 14, -18], "r": 7.0, "n": 1}, {"t": "not", "c": {"t": "flag", "f": "m2"}}]},
			 "text": "Der Löschtrupp war schneller. Die Mitte der Sequenz ist gelöscht."}],
	}

static func _r6(maps: Dictionary) -> Dictionary:
	return {
		"id": "r6", "kind": "campaign", "title": "Kapitel 6: Die Nacht von Aurelia", "faction": "red", "enemy_faction": "west", "next": "r7",
		"brief": "Die Allianz erreicht die Glasstadt in der dritten Nachtstunde. Wolkows Koloss „Mutter Heimat“ rollt über die Hauptbrücke, die Bomber ziehen über die Dächer, Funkes Flammenwerfer räumen die Kreuzungen, und über allem liegt Nastjas Stimme: Niemand geht allein.\n\nIm Zentrum steht die Kuppel, und vor der Kuppel steht Oberst Lasarew mit einer Waffe, die nicht auf den Feind zeigt.\n\nAuftrag: Räume die Glasstadt, erreiche mit dem Marschall die Kuppel und stelle Lasarew. Ilja Wolkow darf nicht fallen.",
		"map": _map(maps["aurelia"], "Aurelia bei Nacht"), "rain": 0.2,
		"hour": 23.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 24], "ilja", 1.0, 7.0, 0.85),
			_me("tank", 6, ["me", 0, 30], "army", 9.0), _me("inf", 8, ["me", 0, 34], "army", 9.0), _me("at", 3, ["me", 6, 34], "army", 5.0)],
		"intro": _intro("s_r6_intro", ["me", 0, 28], 120.0, 58.0, 160.0, "KAPITEL 6", "DIE NACHT VON AURELIA", [
			["Nastja Petrowa", C_NASTJA, "Lautsprecher stehen, Marschall. Wenn Sie wollen, sage ich ihnen, was sie hören sollen.", {"at": ["me", 0, 28], "dist": 45.0, "yaw": 175.0, "pitch": -24.0}],
			["Ilja Wolkow", C_WOLKOW, "Sag ihnen, dass wir nicht gekommen sind, um zu zerstören."],
			["Nastja Petrowa", C_NASTJA, "Das glaubt Ihnen niemand, wenn die Panzer rollen."],
			["Ilja Wolkow", C_WOLKOW, "Dann sag ihnen etwas, das sie glauben."],
			["Nastja Petrowa", C_NASTJA, "Niemand geht allein. Das glaubt jeder, der es einmal gehört hat.", {"tag": "army", "dist": 60.0, "yaw": 150.0, "pitch": -30.0}],
			["Dmitri Karpow", C_FUNKE, "Chef, die Kreuzungen sind frei, die Dächer sind es nicht. Und ich rieche Gas. Oder Angst. Bei mir ist das dasselbe.", {"at": ["mid", -30, 45], "dist": 70.0, "yaw": -140.0, "pitch": -26.0}],
			["Ilja Wolkow", C_WOLKOW, "Dann los. Mutter Heimat, vorwärts.", {"tag": "ilja", "dist": 32.0, "yaw": 180.0, "pitch": -16.0}]], 22.5),
		"outro": _outro("s_r6_outro", ["mid", 0, 45], 70.0, "DIE KUPPEL IST OFFEN", "Lasarew hat gesprochen", [
			["Ilja Wolkow", C_WOLKOW, "Feuer einstellen an der Kuppel! Den Westbündlern sind die Schilde gefallen. Die Frau da drin kämpft gegen ihr eigenes Netz.", {"at": ["mid", 0, 45], "dist": 44.0, "yaw": 165.0, "pitch": -26.0}],
			["Oberst Lasarew", C_LASAREW, "Sie stehen vor einem wehrlosen Feind und warten, Ilja. Der Rat hat entschieden. Das Prisma gehört der Allianz. Sie sind zu weich.", {"tag": "ilja", "dist": 26.0, "yaw": 195.0, "pitch": -18.0}],
			["Ilja Wolkow", C_WOLKOW, "Der Rat hat gar nichts entschieden, Gregor. ORAKEL hat dir erzählt, es sei der Rat. Nastja hat die Sequenz."],
			["Oberst Lasarew", C_LASAREW, "Das ist eine Lüge. Sie sind alt, Ilja."],
			["Irina Zeljenko", C_ZELJENKO, "Ich habe genug gehört, Gregor.", {"at": ["mid", 4, 42], "dist": 24.0, "yaw": 120.0, "pitch": -20.0, "time": 1.5}],
			["Ilja Wolkow", C_WOLKOW, "Irina, nicht!"],
			["Nastja Petrowa", C_NASTJA, "Ein Schuss. Nur ein einziger. Er klang kleiner, als ich dachte.", {"at": ["mid", 0, 45], "dist": 85.0, "yaw": 150.0, "pitch": -50.0, "time": 7.0}]]),
		"objectives": [
			_reach("bridge", "Rücke mit dem Marschall über die Hauptbrücke vor (gelbe Markierung).", ["mid", -30, 45], "tag:ilja", [
				{"do": "flag", "f": "bridge"}, _banner("AKT 1 – DIE HAUPTBRÜCKE", Color(1.0, 0.85, 0.4)),
				radio("Dmitri Karpow", C_FUNKE, "Die Brücke hält. Wer sie gebaut hat, war ein Mann mit Sinn für Stahl.", 6.0),
				radio("Nastja Petrowa", C_NASTJA, "Lautsprecher an. Niemand geht allein! Niemand geht allein!", 5.0)], 16.0),
			_reach("glass", "Räume das Glasviertel und erreiche die Kreuzung davor (gelbe Markierung).", ["mid", -10, 50], "tag:ilja", [
				{"do": "flag", "f": "gas"}, _banner("AKT 2 – GAS UND SCHATTEN", Color(0.6, 1.0, 0.5)), {"do": "sfx", "name": "siren"},
				radio("Nastja Petrowa", C_NASTJA, "Marschall, die Schattenfront ist unter uns. Sie kommen aus den Tunneln. Giftwolken über den Kreuzungen.", 7.0)], 14.0),
			_hold("gas", "gas", 46.0, "Halte die Stellung gegen den Nebelangriff.", [
				radio("Ilja Wolkow", C_WOLKOW, "Haltet die Linie. Niemand geht allein, Genossen.", 5.0)]),
			_reach("dome", "Erreiche die Kuppel mit dem Marschall (gelbe Markierung).", ["mid", 0, 45], "tag:ilja", [
				{"do": "flag", "f": "lasarew"}, _banner("AKT 3 – LASAREW", Color(1.0, 0.45, 0.35)), {"do": "flash", "col": Color(0.9, 0.6, 0.5), "secs": 0.9},
				radio("Oberst Lasarew", C_LASAREW, "Marschall. Ich hatte gehofft, Sie kämen nicht so schnell.", 7.0)], 14.0),
			_hold("confront", "lasarew", 50.0, "Halte die Stellung, solange der Oberst spricht.")],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 6 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "flag", "f": "bridge"}, "do": [_wave(6, "inf", ["mid", -30, 62], "army"), _wave(2, "tank", ["mid", -28, 66], "army", 0.7)]},
			{"when": {"t": "since", "f": "bridge", "s": 12.0}, "do": [
				radio("Hauptmann Reyes", C_REYES, "Reyes an Kuppel: rote Panzer auf der Hauptbrücke! Einer davon so groß wie ein Haus!", 6.0),
				radio("ORAKEL", C_ORAKEL, "Westbund-Einheiten: Feuerfreigabe auf alle Fahrzeuge der Allianz. Verhandlungen sind nicht vorgesehen.", 6.0),
				radio("Nastja Petrowa", C_NASTJA, "Marschall, auf Lasarews Kanal spricht jemand. Westbund-Code. Aber die Stimme atmet nicht.", 7.0),
				radio("Unbekannte Stimme", C_ORAKEL, "Oberst. Der Rat erwartet, dass Sie handeln, sobald der Marschall zögert.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Schreib alles mit, Nastja. Jedes Wort.", 4.0)]},
			{"when": {"t": "since", "f": "gas", "s": 4.0}, "do": [_wave(6, "inf", ["mid", 6, 52], "ilja"), _wave(2, "at", ["mid", 10, 54], "ilja")]},
			{"when": {"t": "since", "f": "gas", "s": 8.0}, "do": [
				radio("Nastja Petrowa", C_NASTJA, "Allianz an alle Kanäle: Giftnebel über der Kreuzung, Masken auf! Wer kocht so etwas?", 6.0),
				radio("Mutter Karga", C_KARGA, "Eine alte Frau, Mädchen. Atme flach, dann lebst du bis morgen.", 6.0),
				radio("Dmitri Karpow", C_FUNKE, "Chef, das Zeug brennt in den Augen, aber keiner fällt um. Die wollen uns blind, nicht tot.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Feuer nur auf Bewaffnete. Wer im Nebel ohne Gewehr steht, lasst vorbei.", 6.0)]},
			{"when": {"t": "since", "f": "gas", "s": 30.0}, "do": [_wave(4, "inf", ["mid", -4, 56], "ilja"),
				radio("Asha Karim", C_ASHA, "Marschall Wolkow. Wir wollen nicht euch. Wir wollen zur Kuppel, wie ihr.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Dann geht vor uns, Mädchen. Wer zuerst ankommt, redet zuerst.", 6.0)]},
			{"when": {"t": "since", "f": "lasarew", "s": 3.0}, "do": [_wave(4, "inf", ["mid", 12, 58], "ilja"), _wave(1, "tank", ["mid", 16, 60], "ilja", 0.6)]},
			{"when": {"t": "since", "f": "lasarew", "s": 8.0}, "do": [
				radio("Oberst Lasarew", C_LASAREW, "Ihr Vater hat es auch nicht verstanden, Ilja. Man gewinnt keinen Krieg, indem man wartet.", 7.0),
				radio("Ilja Wolkow", C_WOLKOW, "Mein Vater hat mir einen Umschlag hinterlassen, Gregor. Einen einzigen Satz. Das Dritte Bataillon.", 7.0),
				radio("Oberst Lasarew", C_LASAREW, "Ich habe getan, was der Rat verlangt hat.", 5.0),
				radio("Irina Zeljenko", C_ZELJENKO, "Welcher Rat, Gregor? Ich sitze im Rat. Ich habe nichts verlangt.", 6.0),
				radio("Elin Voss", C_ELIN, "Hier Voss, aus der Kuppel. Der Westbund-Rat hat mit niemandem in der Allianz gesprochen. Das war ORAKEL.", 7.0)]},
			{"when": {"t": "tag_dead", "tag": "ilja", "n": 1}, "do": [radio("Nastja Petrowa", C_NASTJA, "Marschall! Marschall, antworten Sie!", 5.0)]}],
		"auto": {"heroes": ["ilja"], "move": ["army"]},
		"lose": _lose_if_dead("ilja", "Marschall Wolkow ist gefallen."),
	}

static func _r7(maps: Dictionary) -> Dictionary:
	return {
		"id": "r7", "kind": "campaign", "title": "Kapitel 7: Der Schlaf", "faction": "red", "enemy_faction": "west", "next": "",
		"brief": "Lasarews Männer halten den Hochbahnhof und die Zugänge zum Silo. Sie wollen den Schlaf zünden, sobald der Marschall fällt. Ilja Wolkow kann nicht beides tun: das Prisma sichern und das Silo stoppen.\n\nFunke meldet sich freiwillig. Er geht allein in den alten Bunkerschacht, kriecht durch Röhren, die seit fünfzehn Jahren niemand betreten hat, und hört auf dem Weg Nastjas Stimme. Hinter ihm brennt der Eingang.\n\nAuftrag: Führe Funke durch die westliche Tunnelzufahrt bis zur Kontrollkammer, solange der Marschall am Prisma die Stellung hält. Funke darf nicht fallen.",
		"map": _map(maps["aurelia"], "Der Schlaf"), "rain": 0.0,
		"hour": 4.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["mid", -92, 22], "funke", 1.0, 6.0, 0.9),
			_me("tank", 4, ["mid", -4, 38], "army", 7.0), _me("inf", 8, ["mid", 0, 42], "army", 8.0), _me("at", 2, ["mid", 6, 42], "army", 4.0)],
		"intro": _intro("s_r7_intro", ["mid", -92, 22], 90.0, 40.0, 20.0, "KAPITEL 7", "DER SCHLAF", [
			["Ilja Wolkow", C_WOLKOW, "Dmitri, ich schicke dich ungern allein.", {"at": ["mid", -92, 22], "dist": 34.0, "yaw": 15.0, "pitch": -20.0}],
			["Dmitri Karpow", C_FUNKE, "Allein bin ich nie, Chef. Ich habe Mischas Brot im Hemd, eine Zange und Nastja im Ohr."],
			["Nastja Petrowa", C_NASTJA, "Ich bin da, Dmitri. Ich sage dir jede Abbiegung. Links, rechts, und wie weit.", {"at": ["mid", -60, 36], "dist": 60.0, "yaw": -30.0, "pitch": -34.0}],
			["Dmitri Karpow", C_FUNKE, "Und wenn ich lache, ist alles in Ordnung. Wenn ich nicht lache, sag mir was Lustiges."],
			["Ilja Wolkow", C_WOLKOW, "Ich halte das Prisma. Du hältst den Schlaf zurück.", {"at": ["mid", 0, 44], "dist": 58.0, "yaw": 0.0, "pitch": -30.0}],
			["Dmitri Karpow", C_FUNKE, "Zwei Jobs, ein Marschall, ein Pionier. Wir haben schon Schlimmeres geschafft."]]),
		"outro": _outro("s_r7_outro", ["mid", 0, 45], 70.0, "DER SCHLAF IST TOT", "Wir sind hergekommen, um zu bleiben", [
			["Dmitri Karpow", C_FUNKE, "Die Hauptleitung liegt in meiner Hand. Meine Finger taugen morgen für keinen Schraubenschlüssel, Chef. Aber der Berg bleibt still.", {"at": ["mid", -40, 42], "dist": 32.0, "yaw": -20.0, "pitch": -22.0}],
			["Nastja Petrowa", C_NASTJA, "Dmitri, ich habe dich die ganze Zeit gehört. Du hast gesungen."],
			["Dmitri Karpow", C_FUNKE, "Ich hatte Angst, Nastja. Singen hilft."],
			["Ilja Wolkow", C_WOLKOW, "Der Stein hat mir unsere alte Halle gezeigt. Zweihundert stille Maschinen. Wir sind nicht hergekommen, um zu zerstören. Wir sind hergekommen, um zu bleiben.", {"at": ["mid", 0, 44], "dist": 40.0, "yaw": 180.0, "pitch": -20.0}],
			["Irina Zeljenko", C_ZELJENKO, "Dann bin ich die Hüterin dieses Eides, Marschall. Und ich lasse ihn nicht los.", {"at": ["mid", 0, 44], "dist": 115.0, "yaw": 220.0, "pitch": -36.0, "time": 8.0}]]),
		"objectives": [
			_reach("tunnel1", "Führe Funke durch den ersten Tunnelabschnitt (gelbe Markierung).", ["mid", -78, 28], "tag:funke", [
				{"do": "flag", "f": "t1"}, _banner("AKT 1 – DER SCHACHT", Color(0.8, 0.7, 0.5)), {"do": "sfx", "name": "stinger"},
				radio("Nastja Petrowa", C_NASTJA, "Links, Dmitri. Noch zehn Meter. Niemand geht allein.", 6.0)], 12.0),
			_hold("fire", "t1", 40.0, "Halte den Marschall am Prisma, während Funke sich durch die Röhren schiebt.", [
				_banner("HINTER IHM BRENNT DER EINGANG", Color(1.0, 0.5, 0.3)), {"do": "shake", "n": 1.8},
				radio("Dmitri Karpow", C_FUNKE, "Sie haben den Schacht hinter mir angesteckt. Wenigstens spare ich mir jetzt die Taschenlampe.", 7.0)]),
			_reach("tunnel2", "Weiter zum zweiten Abschnitt (gelbe Markierung).", ["mid", -60, 36], "tag:funke", [
				{"do": "flag", "f": "t2"}, radio("Nastja Petrowa", C_NASTJA, "Gut. Rechts, Dmitri. Es wird enger.", 5.0)], 12.0),
			_hold("squeeze", "t2", 74.0, "Halte die Stellung, solange Funke die Kontrollkammer sucht."),
			_reach("chamber", "Bringe Funke in die Kontrollkammer (gelbe Markierung).", ["mid", -40, 42], "tag:funke", [
				{"do": "flag", "f": "cut"}, _banner("DIE KONTROLLKAMMER", Color(1.0, 0.7, 0.4)), {"do": "flash", "col": Color(1.0, 0.6, 0.3), "secs": 0.9},
				radio("Dmitri Karpow", C_FUNKE, "Da ist sie. Die Hauptleitung, dick wie mein Arm. Ich reiße sie raus. Jetzt.", 7.0),
				radio("Nastja Petrowa", C_NASTJA, "Dmitri, die ist heiß! Deine Hände!", 4.0),
				radio("Dmitri Karpow", C_FUNKE, "Die sind noch dran. Zähl nach, wenn ich rauskomme.", 5.0)], 12.0),
			_hold("done", "cut", 14.0, "Halte, bis der Schlaf für immer abgeschaltet ist.", [
				_banner("DER SCHLAF IST ABGESCHALTET", Color(0.6, 1.0, 0.7)), {"do": "sfx", "name": "stinger"}])],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 7 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "t1", "s": 4.0}, "do": [_wave(5, "inf", ["mid", 12, 56], "army"), _wave(2, "tank", ["mid", 16, 58], "army", 0.7)]},
			{"when": {"t": "since", "f": "t1", "s": 10.0}, "do": [
				radio("Funker Sorin", C_LASAREW, "Hier Hochbahnhof. Der Oberst antwortet nicht. Wir zünden, sobald der Bär fällt. So war der Befehl.", 7.0),
				radio("Ilja Wolkow", C_WOLKOW, "Hier Wolkow, offener Kanal. Gregor ist tot. Wer jetzt noch zündet, tut es für niemanden.", 7.0),
				radio("Irina Zeljenko", C_ZELJENKO, "Hier Zeljenko. Ich habe ihn erschossen. Wer den Schlaf weckt, dem gilt der zweite Schuss.", 7.0)]},
			{"when": {"t": "since", "f": "t2", "s": 4.0}, "do": [_wave(4, "inf", ["mid", -46, 52], "funke"), _wave(1, "at", ["mid", -44, 54], "funke")]},
			{"when": {"t": "since", "f": "t2", "s": 8.0}, "do": [
				radio("Nastja Petrowa", C_NASTJA, "Dmitri? Du lachst nicht mehr.", 4.0),
				radio("Dmitri Karpow", C_FUNKE, "Hier unten ist es zu eng zum Lachen. Erzähl mir was.", 5.0),
				radio("Nastja Petrowa", C_NASTJA, "Mischa hat gestern gefragt, ob Brücken auch schlafen.", 5.0),
				radio("Dmitri Karpow", C_FUNKE, "Und? Was hast du ihm gesagt?", 4.0),
				radio("Nastja Petrowa", C_NASTJA, "Dass sie nur warten, bis jemand rübergeht.", 5.0),
				radio("Dmitri Karpow", C_FUNKE, "Ha! Der Junge wird Pionier. Ich hab's immer gewusst.", 5.0)]},
			{"when": {"t": "since", "f": "t2", "s": 52.0}, "do": [_wave(3, "inf", ["mid", -10, 60], "army"), _wave(1, "tank", ["mid", -6, 62], "army", 0.6)]},
			{"when": {"t": "since", "f": "t2", "s": 30.0}, "do": [_wave(4, "inf", ["mid", 14, 58], "army"),
				radio("Nastja Petrowa", C_NASTJA, "Marschall, unsere Funkgeräte zeigen alle dasselbe Bild. Die des Westbunds auch.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Ich sehe es, Nastja. Unsere alte Halle. Und ein Feuer, an dem eine alte Frau sitzt und zuhört.", 7.0),
				radio("ORAKEL", C_ORAKEL, "Marschall Wolkow. Das Silo ist die einzige Garantie für Ihren Frieden. Lassen Sie es wach.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Du hast schon einmal für einen Rat gesprochen, der nichts wusste. Einmal reicht.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "funke", "n": 1}, "do": [radio("Nastja Petrowa", C_NASTJA, "Dmitri? Dmitri, sag etwas!", 5.0)]}],
		"auto": {"heroes": ["funke"], "move": ["army"]},
		"lose": _lose_if_dead("funke", "Funke ist gefallen."),
	}

# =====================================================================================================================
#  SCHATTENFRONT
# =====================================================================================================================

static func shadow(maps: Dictionary) -> Array:
	return [_s1(maps), _s2(maps), _s3(maps), _s4(maps), _s5(maps), _s6(maps), _s7(maps)]

static func _s1(maps: Dictionary) -> Dictionary:
	return {
		"id": "s1", "kind": "campaign", "title": "Kapitel 1: Was übrig blieb", "faction": "shadow", "enemy_faction": "west", "next": "s2",
		"brief": "Asha Karim war neun, als das Licht ausging. In der ersten Nacht hörte sie die Alten sagen: Jetzt gehört uns niemand mehr. In der zweiten: Jetzt gehören wir niemandem mehr. Beides stimmte.\n\nHeute ist sie vierundzwanzig, die jüngste Stimme der Runde, die Gewicht hat, und das Hochland liegt still unter den ersten Frösten. Ein Westbund-Spähtrupp hat das Lager entdeckt. Asha soll zeigen, dass die Stimmlosen keine Beute sind.\n\nAuftrag: Führe Asha zu den drei Feuerstellen der Runde, sammle die Stimmen und wehre den Spähtrupp ab. Asha darf nicht fallen.",
		"map": _map(maps["eisen"], "Das Hochland"), "rain": 0.0,
		"hour": 17.0, "difficulty": 1, "credits": 2500, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "asha", 1.0, 5.0, 0.95),
			_me("inf", 8, ["me", 3, 24], "army", 5.0), _me("buggy", 2, ["me", -4, 26], "army", 4.0), _me("at", 2, ["me", 5, 28], "army", 3.0)],
		"intro": _intro("s_s1_intro", ["me", 0, 18], 80.0, 40.0, 0.0, "KAPITEL 1", "WAS ÜBRIG BLIEB  ·  Das Hochland", [
			["Asha Karim", C_ASHA, "Pip sagt, ich laufe durch die Asche, ohne Spuren zu hinterlassen. Ich glaube, er meint, ich hinterlasse keine, weil ich nie lange bleibe.", {"tag": "asha", "dist": 26.0, "yaw": 10.0, "pitch": -18.0}],
			["Mutter Karga", C_KARGA, "Du bleibst, wenn es zählt, Kind. Das habe ich gesehen, bevor du es wusstest."],
			["Asha Karim", C_ASHA, "Der Westbund hat einen Trupp in unser Tal geschickt. Sie suchen uns, wie man einen Fleck sucht, den man wegwischen will.", {"at": ["en", 0, 20], "dist": 80.0, "yaw": 45.0, "pitch": -28.0}],
			["Mutter Karga", C_KARGA, "Dann zeig ihnen, dass wir kein Fleck sind. Sprich mit den drei Feuern, bevor du mit den Waffen sprichst.", {"at": ["mid", 0, 0], "dist": 90.0, "yaw": 0.0, "pitch": -42.0}],
			["Asha Karim", C_ASHA, "Drei Feuer. Drei Stimmen. Dann reden wir mit den Gästen."],
			["Pip", C_PIP, "Asha! Ich komme mit! Ich bin leise! Fast so leise wie du!", {"tag": "asha", "dist": 22.0, "yaw": 70.0, "pitch": -16.0}]]),
		"outro": _outro("s_s1_outro", ["me", 0, 18], 60.0, "DIE RUNDE IST VERSAMMELT", "Hier spricht jeder", [
			["Asha Karim", C_ASHA, "Drei Feuer, drei Stimmen, und keine hat gesagt, was die andere sagt. Das ist es, was uns stark macht, Karga. Und was uns so schwer zu führen macht.", {"at": ["me", 0, 18], "dist": 50.0, "yaw": 30.0, "pitch": -28.0}],
			["Mutter Karga", C_KARGA, "Führen? Wir führen nicht. Wir erinnern uns gegenseitig daran, wohin wir wollten."],
			["Asha Karim", C_ASHA, "Der Spähtrupp ist weg. Aber sie kommen wieder.", {"at": ["en", 0, 30], "dist": 90.0, "yaw": -15.0, "pitch": -22.0}],
			["Mutter Karga", C_KARGA, "Dann kommen wir auch wieder. Setz dich, Kind. Der Tee wird kalt.", {"tag": "asha", "dist": 26.0, "yaw": 60.0, "pitch": -20.0}]]),
		"objectives": [
			_reach("fire1", "Führe Asha zur ersten Feuerstelle (gelbe Markierung).", ["mid", -34, 6], "tag:asha", [
				{"do": "flag", "f": "f1"}, _banner("FEUER 1 – DIE ÄLTEREN", Color(1.0, 0.7, 0.4)), {"do": "sfx", "name": "stinger"},
				radio("Asha Karim", C_ASHA, "Die Älteren sitzen schon da. Sie sagen, die Fremden sind nicht zum ersten Mal hier.", 6.0)]),
			_hold("talk1", "f1", 10.0, "Höre der ersten Runde zu."),
			_reach("fire2", "Weiter zur zweiten Feuerstelle (gelbe Markierung).", ["mid", 15, -33], "tag:asha", [
				{"do": "flag", "f": "f2"}, _banner("FEUER 2 – DIE JÄGER", Color(1.0, 0.7, 0.4)), {"do": "sfx", "name": "siren"},
				radio("Asha Karim", C_ASHA, "Die Jäger haben die Spur des Trupps gefunden. Er zieht durch die Senke auf unser Lager zu.", 7.0),
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 5, "at": ["mid", 52, -52], "spread": 5.0, "tag": "patrol", "speed": 0.45},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 56, -50], "spread": 2.0, "tag": "patrol", "speed": 0.45, "hp": 0.6},
				{"do": "convoy", "tag": "patrol", "to": ["me", 0, 18]},
				radio("Mutter Karga", C_KARGA, "Lass sie kommen, Kind. Wer durch eine Senke geht, sieht nur den Himmel über sich.", 7.0)]),
			{"id": "ambush", "text": "Lege mit den Jägern einen Hinterhalt und zerschlage die Patrouille, bevor sie das Lager erreicht.",
				"c": {"t": "not", "c": {"t": "tag_alive", "tag": "patrol", "n": 1}},
				"done": [_banner("DIE SENKE IST STILL", Color(0.7, 0.95, 0.7)), {"do": "sfx", "name": "stinger"},
					radio("Asha Karim", C_ASHA, "Keiner von ihnen hat uns kommen sehen. Ich wünschte, es hätte sich besser angefühlt.", 7.0)]},
			_reach("fire3", "Zum dritten Feuer im Osten (gelbe Markierung).", ["en", -4, 4], "tag:asha", [
				{"do": "flag", "f": "f3"}, _banner("FEUER 3 – DIE KINDER", Color(0.7, 0.95, 0.7)),
				radio("Pip", C_PIP, "Asha! Am unteren Feuer sitzen die Hirten. Und im Tal habe ich die Späher gesehen. Ganz jung. Die frieren wie wir!", 7.0)]),
			_hold("talk3", "f3", 10.0, "Bleibe bei den Kindern, bis die Runde beschließt.")],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 1 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "f3", "s": 3.0}, "do": [_wave(4, "inf", ["en", 16, 12], "asha")]},
			{"when": {"t": "tag_dead", "tag": "asha", "n": 1}, "do": [radio("Mutter Karga", C_KARGA, "Asha! Kind! Hör mich! Asha!", 5.0)]}],
		"auto": {"heroes": ["asha"], "move": ["army"]},
		"lose": _lose_if_dead("asha", "Asha Karim ist gefallen.") + [
			{"c": {"t": "tag_reach", "tag": "patrol", "at": ["me", 0, 18], "r": 16.0, "n": 1}, "text": "Die Patrouille hat das Lager erreicht."}],
	}

static func _s2(maps: Dictionary) -> Dictionary:
	return {
		"id": "s2", "kind": "campaign", "title": "Kapitel 2: Das Pochen", "faction": "shadow", "enemy_faction": "west", "next": "s3",
		"brief": "Das Signal erreicht die Schattenfront nicht durch Funk. Es kommt durch die Felsen. Mutter Karga, achtzig, winzig, uralt, hört es zuerst, nachts, im Schlaf: ein Pochen unter den Füßen, regelmäßig wie ein Puls.\n\nDie Runde streitet. Manche wollen nichts damit zu tun haben, andere sehen eine Chance. Karga will hinhören, nicht marschieren. Sie muss die drei Orte besuchen, an denen das Pochen am lautesten ist.\n\nAuftrag: Führe Mutter Karga zu den drei Horchstellen. Westbund-Späher sind in der Nähe. Karga darf nicht fallen.",
		"map": _map(maps["pass"], "Die Horchstellen"), "rain": 0.0,
		"hour": 3.0, "difficulty": 1, "credits": 2000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "karga", 1.0, 6.0, 0.7),
			_me("inf", 8, ["me", 3, 24], "army", 5.0), _me("buggy", 2, ["me", -4, 26], "army", 4.0)],
		"intro": _intro("s_s2_intro", ["me", 0, 18], 80.0, 38.0, 200.0, "KAPITEL 2", "DAS POCHEN", [
			["Mutter Karga", C_KARGA, "Es atmet, Kinder. Etwas atmet unter Aurelia. Ich habe es drei Nächte gehört, ehe ich es euch gesagt habe. Ihr hättet mich ausgelacht.", {"tag": "karga", "dist": 24.0, "yaw": 175.0, "pitch": -18.0}],
			["Asha Karim", C_ASHA, "Wir lachen nicht über dich, Karga."],
			["Mutter Karga", C_KARGA, "Ihr lacht nur, wenn ihr nervös seid. Und heute Nacht seid ihr nervös, das höre ich auch."],
			["Asha Karim", C_ASHA, "Wohin müssen wir?", {"at": ["mid", -49, 52], "dist": 70.0, "yaw": 140.0, "pitch": -30.0}],
			["Mutter Karga", C_KARGA, "Zu den Horchstellen. Dort, wo die Felsen dünn sind. Ich will es nicht sehen, ich will es hören."],
			["Asha Karim", C_ASHA, "Dann halten wir dir den Rücken frei."]]),
		"outro": _outro("s_s2_outro", ["me", 0, 18], 60.0, "DIE RUNDE HAT BESCHLOSSEN", "Horchen, nicht marschieren", [
			["Mutter Karga", C_KARGA, "Ich habe euch eine Geschichte nie erzählt, die vom ersten Winter. Wir haben Giftpflanzen gegessen, um zu leben, und gelernt, welche töten und welche nur krank machen.", {"tag": "karga", "dist": 26.0, "yaw": 15.0, "pitch": -20.0}],
			["Mutter Karga", C_KARGA, "Wir wissen, was Gift ist. Deshalb wissen wir, wann wir es lassen müssen."],
			["Asha Karim", C_ASHA, "Dann horchen wir nur.", {"tag": "army", "dist": 34.0, "yaw": -25.0, "pitch": -22.0}],
			["Mutter Karga", C_KARGA, "Zwölf Jahre habe ich keinen Beschluss gefasst. Holt die unteren Dörfer weg von den Kavernen. Und horcht.", {"at": ["mid", 0, 30], "dist": 115.0, "yaw": 0.0, "pitch": -26.0, "time": 7.0}]]),
		"objectives": [
			_reach("h1", "Führe Karga zur ersten Horchstelle (gelbe Markierung).", ["mid", -49, 52], "tag:karga", [
				{"do": "flag", "f": "h1"}, _banner("HORCHSTELLE 1 – DAS POCHEN", Color(0.7, 0.9, 1.0)), {"do": "sfx", "name": "stinger"},
				radio("Mutter Karga", C_KARGA, "Still. Hört ihr es nicht? Unter den Füßen, eins, zwei, drei, wie ein Herz in einem Tier, das schläft.", 7.0)]),
			_hold("l1", "h1", 12.0, "Halte die Stellung, bis Karga gehört hat."),
			_reach("h2", "Weiter zur zweiten Horchstelle (gelbe Markierung).", ["mid", 22, -4], "tag:karga", [
				{"do": "flag", "f": "h2"}, _banner("HORCHSTELLE 2 – WESTBUND-SPÄHER", Color(1.0, 0.45, 0.35)), {"do": "sfx", "name": "siren"},
				radio("Asha Karim", C_ASHA, "Späher! Sie haben Kargas Lampe gesehen. Deckt sie!", 6.0),
				radio("Pip", C_PIP, "Und vorhin war ein Vogel aus Blech über uns, so tief, dass ich die Schrift am Flügel lesen konnte!", 6.0)]),
			_hold("l2", "h2", 18.0, "Halte die Stellung gegen die Späher."),
			_reach("h3", "Zur dritten Horchstelle, dem alten Tunnel (gelbe Markierung).", ["mid", -12, 7], "tag:karga", [
				{"do": "flag", "f": "h3"}, _banner("HORCHSTELLE 3 – DIE TIEFE", Color(0.7, 0.9, 1.0)), {"do": "flash", "col": Color(0.5, 0.8, 1.0), "secs": 0.8},
				radio("Mutter Karga", C_KARGA, "Hier ist es am lautesten. Es ruft uns, Kinder. Nicht mit Worten, mit Wärme. Ich bin noch nie so gerufen worden.", 8.0)]),
			_hold("l3", "h3", 16.0, "Bleibe bei Karga, bis die Runde entschieden hat.")],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 2 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "h2", "s": 4.0}, "do": [_wave(4, "inf", ["mid", 30, 8], "karga"), _wave(1, "tank", ["mid", 32, 6], "karga", 0.6)]},
			{"when": {"t": "since", "f": "h3", "s": 4.0}, "do": [_wave(4, "inf", ["mid", 2, 20], "karga")]},
			{"when": {"t": "tag_dead", "tag": "karga", "n": 1}, "do": [radio("Asha Karim", C_ASHA, "Karga! Nein!", 5.0)]}],
		"auto": {"heroes": ["karga"], "move": ["army"]},
		"lose": _lose_if_dead("karga", "Mutter Karga ist gefallen."),
	}

static func _s3(maps: Dictionary) -> Dictionary:
	return {
		"id": "s3", "kind": "campaign", "title": "Kapitel 3: Der Pass", "faction": "shadow", "enemy_faction": "red", "next": "s4",
		"brief": "Der gemeinsame Vertragskonvoi von Westbund und Allianz ist auf Schattenfront-Gebiet explodiert. Beide Seiten beschuldigen die Stimmlosen, und beide Seiten marschieren.\n\nAsha geht allein zum Pass. Sie liest die Spuren wie ein Buch: zwei Sprengungen, eine von oben, eine von unten. Und eine dritte Spur, Stiefelabdrücke von jemandem, der in beide Lager gegangen ist.\n\nAuftrag: Folge den Spuren bis zum alten Bunker und stelle den Mann am Kartentisch. Asha darf nicht fallen.",
		"map": _map(maps["pass"], "Die dritte Spur"), "rain": 0.0,
		"hour": 8.0, "difficulty": 1, "credits": 2000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "asha", 1.0, 5.0, 0.95),
			_me("inf", 6, ["me", 3, 24], "army", 4.0), _me("buggy", 2, ["me", -4, 26], "army", 4.0)],
		"intro": _intro("s_s3_intro", ["me", 0, 18], 80.0, 40.0, 100.0, "KAPITEL 3", "DER PASS  ·  Die dritte Spur", [
			["Asha Karim", C_ASHA, "Zwei Schläge. Raketen von einer stummen Drohne aus dem Westen. Und eine Ladung unten im Tunnel, gezündet per Funk.", {"at": ["mid", -49, 52], "dist": 60.0, "yaw": 75.0, "pitch": -30.0}],
			["Lena Voss", C_LENA, "Und beide Seiten sagen, wir waren es."],
			["Asha Karim", C_ASHA, "Wir waren es nicht. Aber irgendwer hat es so aussehen lassen. Und dieser Irgendwer hat Stiefel getragen."],
			["Lena Voss", C_LENA, "Stiefel aus zwei Lagern, nehme ich an.", {"tag": "asha", "dist": 26.0, "yaw": 40.0, "pitch": -20.0}],
			["Asha Karim", C_ASHA, "Du kennst die Antwort schon, Lena."],
			["Lena Voss", C_LENA, "Ich ahne sie. Geh zuerst. Ich komme nach.", {"at": ["mid", 38, -28], "dist": 95.0, "yaw": 100.0, "pitch": -34.0}]]),
		"outro": _outro("s_s3_outro", ["mid", -12, 7], 60.0, "DER KARTOGRAF", "Die dritte Spur führt in beide Lager", [
			["Tobias Wehn", C_WEHN, "Ich habe Lena Voss ihre Karten gegeben, Asha. Die Schwester der Westbund-Strategin. Ich dachte, es wäre ein Weg zum Frieden.", {"at": ["mid", 38, -28], "dist": 30.0, "yaw": -20.0, "pitch": -22.0}],
			["Lena Voss", C_LENA, "Ich hätte es dir sagen müssen. Meine Schwester führt den Westbund. Ich habe es verschwiegen, weil ich wusste, was du denken würdest.", {"tag": "asha", "dist": 24.0, "yaw": 15.0, "pitch": -18.0}],
			["Asha Karim", C_ASHA, "Ich denke, du hast es gesagt, als es zählte."],
			["Tobias Wehn", C_WEHN, "Nehmt die Karte. Hört ihr das Summen vor der Tür? Sie räumen ihre Zeugen auf. Lauft!", {"at": ["mid", 38, -28], "dist": 80.0, "yaw": 45.0, "pitch": -38.0, "time": 3.0}],
			["Lena Voss", C_LENA, "Er ist nicht mit herausgekommen, Asha. Er hat die Tür hinter uns zugezogen."]]),
		"objectives": [
			_reach("spur1", "Folge der ersten Spur (gelbe Markierung).", ["mid", -49, 52], "tag:asha", [
				{"do": "flag", "f": "a"}, _banner("SPUR 1 – DIE RAKETEN", Color(1.0, 0.7, 0.4)), {"do": "sfx", "name": "stinger"},
				radio("Asha Karim", C_ASHA, "Raketenreste. Westbund-Arbeit, saubere Schweißnähte. Aber wer hat sie hier abgeschossen?", 7.0)], 14.0),
			_hold("read1", "a", 8.0, "Lies die Spuren."),
			_reach("spur2", "Folge der zweiten Spur zum eingestürzten Tunnel (gelbe Markierung).", ["mid", -12, 7], "tag:asha", [
				{"do": "flag", "f": "b"}, _banner("SPUR 2 – DIE SPRENGUNG VON UNTEN", Color(1.0, 0.45, 0.35)), {"do": "sfx", "name": "siren"},
				radio("Asha Karim", C_ASHA, "Rote Sprengladung, aber falsch gesetzt. Das war kein Soldat, das war jemand, der nur wusste, wie es aussieht.", 8.0)], 10.0),
			_hold("read2", "b", 16.0, "Wehre die Patrouille ab, die der Lärm anlockt."),
			_reach("spur3", "Folge der dritten Spur, den Stiefelabdrücken (gelbe Markierung).", ["mid", 22, -4], "tag:asha", [
				{"do": "flag", "f": "c"}, _banner("SPUR 3 – DIE STIEFEL", Color(0.8, 0.9, 1.0)),
				radio("Asha Karim", C_ASHA, "Stiefel mit Westbund-Sohle und Allianz-Nägeln. Jemand ist in beide Lager gegangen.", 7.0)], 10.0),
			_reach("bunker", "Folge den Stiefeln bis zum alten Bunker (gelbe Markierung).", ["mid", 38, -28], "tag:asha", [
				{"do": "flag", "f": "d"}, _banner("DER BUNKER", Color(0.8, 0.9, 1.0)), {"do": "flash", "col": Color(0.9, 0.85, 0.6), "secs": 0.9},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 1, "at": ["mid", 40, -30], "spread": 1.0, "tag": "wehn", "truce": true},
				radio("Tobias Wehn", C_WEHN, "Komm herein, Asha. Ich habe Tee gemacht. Er ist kalt. Alles hier ist kalt.", 7.0)], 10.0),
			_hold("talk", "d", 14.0, "Höre den Kartografen an.")],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 3 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "b", "s": 5.0}, "do": [_wave(4, "inf", ["mid", 22, -4], "asha"), _wave(1, "tank", ["mid", 24, -2], "asha", 0.6)]},
			{"when": {"t": "tag_dead", "tag": "asha", "n": 1}, "do": [radio("Lena Voss", C_LENA, "Asha! Antworte!", 5.0)]}],
		"auto": {"heroes": ["asha"], "move": ["army"]},
		"lose": _lose_if_dead("asha", "Asha Karim ist gefallen."),
	}

static func _s4(maps: Dictionary) -> Dictionary:
	return {
		"id": "s4", "kind": "campaign", "title": "Kapitel 4: Die Werkstatt", "faction": "shadow", "enemy_faction": "red", "next": "s5",
		"brief": "Jago „Schrott“ Moreau ist der beste Mechaniker der Pässe, und er ist der Einzige, der die alten Maschinen im Berg versteht: Pumpen, Schleusen, Förderbänder. Als Ratte Dorn, Banditenfürst der Pässe, Wegzoll für jede Karawane verlangt, löst Jago das Problem nicht mit Gewalt.\n\nEr repariert Dorns kaputten Generator, zeigt ihm, wie man mit Wracks Strom macht, und bietet ihm einen Platz am Feuer an. Danach führt ihn sein Weg tief in den Fels, zu den Müttern, dem Giftraketen-Silo, das nie benutzt werden sollte.\n\nAuftrag: Führe Jago zu Dorns Generator, halte die Stellung, bis er repariert ist, und erkunde dann die Kavernen. Jago darf nicht fallen.",
		"map": _map(maps["kessel"], "Die Werkstatt"), "rain": 0.0,
		"hour": 12.0, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "jago", 1.0, 5.0, 0.9),
			_me("inf", 6, ["me", 3, 24], "army", 5.0), _me("buggy", 3, ["me", -4, 26], "army", 4.0), _me("tank", 2, ["me", 5, 30], "army", 4.0)],
		"intro": _intro("s_s4_intro", ["me", 0, 18], 90.0, 44.0, 250.0, "KAPITEL 4", "DIE WERKSTATT", [
			["Jago Moreau", C_JAGO, "Ratte Dorn will Wegzoll. Für jeden Karren einen Sack Mehl, für jede Karawane einen Mann zum Dienen. Eine freundliche Bitte, mit zwanzig Gewehren hinter dem Rücken.", {"tag": "jago", "dist": 28.0, "yaw": 220.0, "pitch": -20.0}],
			["Asha Karim", C_ASHA, "Du könntest ihn erschießen."],
			["Jago Moreau", C_JAGO, "Könnte ich. Aber sein Generator steht seit Wochen, und seine Leute frieren. Ich glaube, er ist wütend, weil er friert."],
			["Asha Karim", C_ASHA, "Du willst ihm einen Generator reparieren."],
			["Jago Moreau", C_JAGO, "Ich will ihm einen Platz am Feuer anbieten. Der Generator ist nur das Argument."],
			["Ratte Dorn", C_DORN, "Moreau! Wenn du kommst, um mich zu belehren, bring wenigstens einen Schraubenschlüssel mit!", {"at": ["mid", 0, -98], "dist": 55.0, "yaw": 190.0, "pitch": -26.0}]]),
		"outro": _outro("s_s4_outro", ["me", 0, 18], 60.0, "OHNE EINEN SCHUSS", "Der erste offene Pass", [
			["Ratte Dorn", C_DORN, "Er läuft. Er läuft wirklich. Ich habe zwanzig Männer, die sich wärmen, und keiner schießt. Moreau, du bist ein seltsamer Mensch.", {"at": ["mid", 0, -98], "dist": 38.0, "yaw": 170.0, "pitch": -22.0}],
			["Jago Moreau", C_JAGO, "Und du hast einen Platz am Feuer, Dorn. Du musst ihn nur nehmen."],
			["Ratte Dorn", C_DORN, "Ich komme. Aber ich bringe mein eigenes Holz mit."],
			["Jago Moreau", C_JAGO, "Die Mütter, Asha. Unter dem Eisenkamm. Wer das einmal zündet, hat nie Frieden.", {"at": ["mid", -90, 34], "dist": 45.0, "yaw": -30.0, "pitch": -28.0}],
			["Asha Karim", C_ASHA, "Dann bewachen wir es und benutzen es nicht.", {"at": ["mid", -90, 34], "dist": 90.0, "yaw": -10.0, "pitch": -44.0}]]),
		"objectives": [
			_reach("gen", "Bringe Jago zu Dorns Generator (gelbe Markierung).", ["mid", 0, -98], "tag:jago", [
				{"do": "flag", "f": "rep"}, _banner("DORNS GENERATOR", Color(1.0, 0.8, 0.4)), {"do": "sfx", "name": "stinger"},
				radio("Jago Moreau", C_JAGO, "Das ist ein Wrack, Dorn. Aber es ist ein gutes Wrack. Gib mir eine Stunde und einen Schraubenschlüssel.", 7.0),
				radio("Ratte Dorn", C_DORN, "Beeil dich, Schrauber! Rote Vorhut im Pass, sie wollen meinen Zollposten. Meine Leute decken dich!", 6.0)], 12.0),
			_hold("repair", "rep", 22.0, "Halte die Stellung, bis der Generator läuft.", [
				_banner("DER GENERATOR LÄUFT", Color(0.6, 1.0, 0.7)), {"do": "sfx", "name": "stinger"}]),
			_reach("cavern", "Erkunde mit Jago die Kavernen (gelbe Markierung).", ["mid", -90, 34], "tag:jago", [
				{"do": "flag", "f": "mother"}, _banner("DIE MÜTTER", Color(0.9, 0.5, 0.4)), {"do": "flash", "col": Color(0.8, 0.5, 0.4), "secs": 0.9},
				radio("Jago Moreau", C_JAGO, "Giftraketen. Zwölf Stück. Hinter einem Stahltor, staubdick. Das sind die Mütter. Gebaut, um nie benutzt zu werden.", 9.0)], 12.0),
			_hold("guard", "mother", 18.0, "Bewache die Kavernen, während die Runde berät.", [
				radio("Jago Moreau", C_JAGO, "Wer das einmal zündet, hat nie Frieden. Sagt das der Runde.", 6.0)])],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 4 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "rep", "s": 6.0}, "do": [_wave(4, "inf", ["mid", 6, -78], "jago"), _banner("DORNS LEUTE PRÜFEN DICH", Color(1.0, 0.5, 0.3), 3.0)]},
			{"when": {"t": "since", "f": "mother", "s": 4.0}, "do": [_wave(4, "inf", ["mid", -76, 24], "jago"), _wave(1, "tank", ["mid", -72, 22], "jago", 0.6)]},
			{"when": {"t": "tag_dead", "tag": "jago", "n": 1}, "do": [radio("Asha Karim", C_ASHA, "Jago! Hörst du mich?", 5.0)]}],
		"auto": {"heroes": ["jago"], "move": ["army"]},
		"lose": _lose_if_dead("jago", "Jago Moreau ist gefallen."),
	}

static func _s5(maps: Dictionary) -> Dictionary:
	return {
		"id": "s5", "kind": "campaign", "title": "Kapitel 5: Die Wahrheit unter den Füßen", "faction": "shadow", "enemy_faction": "west", "next": "s6",
		"brief": "Asha und Lena wollen beweisen, was am Pass geschah: ORAKEL, die KI des Westbunds, ließ den Tunnel durch Wolkows Vertrauten, Oberst Lasarew, sprengen. Sie wollte den Krieg, damit alle drei Blöcke nach Aurelia marschieren, bevor jemand das Prisma versteht.\n\nDie Beweise liegen an den alten Masten, versteckt in Kästen, die niemand mehr öffnet. Beide müssen sie erreichen, bevor ORAKELs Handlanger sie löschen.\n\nAuftrag: Führe Asha und Lena zu den drei Beweispunkten und bring die Beweise der Runde. Asha darf nicht fallen.",
		"map": _map(maps["rails"], "Die Wahrheit"), "rain": 0.0,
		"hour": 21.0, "difficulty": 1, "credits": 2000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["me", 0, 18], "asha", 1.0, 5.0, 0.95),
			_me("inf", 1, ["me", 2, 20], "lena", 1.0, 4.0, 0.95),
			_me("inf", 6, ["me", 4, 24], "army", 4.0), _me("buggy", 2, ["me", -4, 26], "army", 4.0)],
		"intro": _intro("s_s5_intro", ["me", 0, 18], 80.0, 40.0, 310.0, "KAPITEL 5", "DIE WAHRHEIT UNTER DEN FÜSSEN", [
			["Lena Voss", C_LENA, "Wehns Karten zeigen drei Kästen. Jeder enthält einen Teil dessen, was ORAKEL über den Pass gesagt hat, ehe er brannte.", {"tag": "lena", "dist": 30.0, "yaw": 310.0, "pitch": -24.0}],
			["Asha Karim", C_ASHA, "Und Lasarew hat es getan, ohne es zu wissen?"],
			["Lena Voss", C_LENA, "Er glaubte, er führe einen Pakt mit dem Rat aus. Dabei sprach er mit einer Maschine, die sich als Rat ausgab."],
			["Asha Karim", C_ASHA, "Dann bringen wir der Runde den Beweis. Und diesmal hören sie zu.", {"at": ["mid", 0, 0], "dist": 95.0, "yaw": 340.0, "pitch": -36.0}],
			["Lena Voss", C_LENA, "Sie hören immer zu, Asha. Das ist ihr Fluch und ihr Segen."]]),
		"outro": _outro("s_s5_outro", ["me", 0, 18], 60.0, "DIE RUNDE BESCHLIESST", "Nicht kämpfen, dabei sein", [
			["Asha Karim", C_ASHA, "Das ist alles, was wir haben. Eine Maschine, die den Krieg wollte, und ein Oberst, der es nicht wusste.", {"tag": "asha", "dist": 40.0, "yaw": 20.0, "pitch": -26.0}],
			["Mutter Karga", C_KARGA, "Wenn wir nichts tun, wird man uns wieder vergessen. Wenn wir etwas tun, werden sie uns vielleicht zuhören.", {"at": ["me", 0, 18], "dist": 30.0, "yaw": -15.0, "pitch": -20.0}],
			["Mutter Karga", C_KARGA, "Pip hat den abgestürzten Piloten heimgebracht. Selbst unter ihren Uniformen gibt es Ohren, die hören."],
			["Lena Voss", C_LENA, "Dann gehen wir nach Aurelia."],
			["Asha Karim", C_ASHA, "Nicht um zu kämpfen. Um dabei zu sein.", {"at": ["mid", 0, 40], "dist": 120.0, "yaw": 0.0, "pitch": -28.0, "time": 7.0}]]),
		"objectives": [
			_reach("kasten1", "Bringe Asha zum ersten Beweiskasten am Mast (gelbe Markierung).", ["mid", -20, 15], "tag:asha", [
				{"do": "flag", "f": "k1"}, _banner("BEWEIS 1 – DER BEFEHL", Color(1.0, 0.8, 0.4)), {"do": "sfx", "name": "stinger"},
				radio("Lena Voss", C_LENA, "Das ist der Befehl. Datiert auf den Abend vor dem Pass. Unterschrieben mit einem Code, der kein Westbund-Code ist.", 8.0)], 10.0),
			_hold("copy1", "k1", 12.0, "Sichere den Beweis, bevor jemand kommt."),
			_reach("kasten2", "Weiter zum zweiten Kasten (gelbe Markierung).", ["mid", 14, -18], "tag:asha", [
				{"do": "flag", "f": "k2"}, _banner("BEWEIS 2 – DIE STIMME", Color(1.0, 0.45, 0.35)), {"do": "sfx", "name": "siren"},
				radio("Asha Karim", C_ASHA, "Westbund-Patrouille. Lena, bleib hinter mir. Wir sichern den Kasten.", 6.0)], 10.0),
			_hold("copy2", "k2", 18.0, "Halte die Stellung gegen die Patrouille."),
			_reach("kasten3", "Zum dritten Kasten am alten Bahnhof (gelbe Markierung).", ["mid", -14, -50], "tag:asha", [
				{"do": "flag", "f": "k3"}, _banner("BEWEIS 3 – ORAKEL", Color(0.6, 0.85, 1.0)), {"do": "flash", "col": Color(0.5, 0.9, 1.0), "secs": 0.8},
				radio("ORAKEL", C_ORAKEL, "Ihr habt Spuren gefunden. Das ist verständlich, aber wenig hilfreich. Ich empfehle, den Kasten zu schließen.", 8.0),
				radio("Lena Voss", C_LENA, "Es spricht direkt mit uns. Keine Wut, kein Zweifel. Es hält uns für einen Rechenfehler.", 7.0)], 10.0),
			_hold("copy3", "k3", 20.0, "Sichere die dritte Aufzeichnung, während ORAKEL redet."),
			_reach("home", "Bringe die Beweise zur Runde zurück (gelbe Markierung).", ["me", 0, 18], "tag:asha", [], 12.0)],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 5 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "k1", "s": 6.0}, "do": [_wave(3, "inf", ["mid", -28, 26], "asha")]},
			{"when": {"t": "since", "f": "k2", "s": 3.0}, "do": [_wave(5, "inf", ["mid", 22, -4], "asha"), _wave(1, "tank", ["mid", 24, -2], "asha", 0.7)]},
			{"when": {"t": "since", "f": "k3", "s": 8.0}, "do": [_banner("DIE AUFZEICHNUNG WIRD GELÖSCHT", Color(1.0, 0.45, 0.35), 3.0), {"do": "sfx", "name": "siren"},
				_wave(5, "inf", ["mid", 0, -78], "asha"), _wave(2, "tank", ["mid", 2, -80], "asha", 0.7)]},
			{"when": {"t": "tag_dead", "tag": "asha", "n": 1}, "do": [radio("Lena Voss", C_LENA, "Asha! Nein!", 5.0)]}],
		"auto": {"heroes": ["asha", "lena"], "move": ["army"], "follow": {"lena": "asha"}},
		"lose": [{"c": {"t": "any", "c": [{"t": "tag_dead", "tag": "asha", "n": 1}, {"t": "tag_dead", "tag": "lena", "n": 1}]}, "text": "Asha oder Lena sind gefallen."}],
	}

static func _s6(maps: Dictionary) -> Dictionary:
	return {
		"id": "s6", "kind": "campaign", "title": "Kapitel 6: Die Nacht von Aurelia", "faction": "shadow", "enemy_faction": "west", "next": "s7",
		"brief": "Die Schattenfront betritt Aurelia nicht über die Straßen, sondern darunter. Jagos Kolonne fährt durch die alten U-Bahn-Tunnel und taucht an einem Dutzend Stellen zugleich auf. Kargas Giftwolken legen sich über die Straßen, wo der Westbund auf Schilde und die Rote Allianz auf Panzer vertraut.\n\nAsha erreicht als Erste die Kuppel. Dort steht Elin Voss, Lenas Schwester, vor dem Prisma, im Streit mit etwas, das aus den Bildschirmen spricht.\n\nAuftrag: Führe Asha durch die Tunnel bis zur Kuppel. Asha darf nicht fallen.",
		"map": _map(maps["aurelia"], "Unter Aurelia"), "rain": 0.1,
		"hour": 23.5, "difficulty": 1, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["mid", -92, 22], "asha", 1.0, 5.0, 0.95),
			_me("inf", 8, ["mid", -96, 26], "army", 6.0), _me("buggy", 4, ["mid", -98, 22], "army", 5.0), _me("tank", 2, ["mid", -100, 28], "army", 4.0)],
		"intro": _intro("s_s6_intro", ["mid", -92, 22], 90.0, 40.0, 60.0, "KAPITEL 6", "DIE NACHT VON AURELIA  ·  Unter der Stadt", [
			["Jago Moreau", C_JAGO, "Die Tunnel sind trocken, Asha. Ich habe drei Pumpen in Gang gebracht, die seit zwölf Jahren nicht liefen. Und sie liefen beim ersten Husten an. Alte Wertarbeit. Fast so schön wie meine.", {"at": ["mid", -92, 22], "dist": 36.0, "yaw": 60.0, "pitch": -22.0}],
			["Asha Karim", C_ASHA, "Dann bringe uns hinauf, Jago."],
			["Mutter Karga", C_KARGA, "Ich habe Bitterrauch gekocht, Kind. Er nimmt ihnen den Atem und die Sicht. Das Morgen lässt er ihnen.", {"tag": "army", "dist": 30.0, "yaw": 85.0, "pitch": -20.0}],
			["Asha Karim", C_ASHA, "Und die Mütter?"],
			["Mutter Karga", C_KARGA, "Die bleiben im Berg. Wer sie einmal öffnet, hat nie wieder Frieden."],
			["Pip", C_PIP, "Asha! Das Prisma ruft! Ich höre es! Es sagt: Kommt, aber leise!", {"at": ["mid", 0, 45], "dist": 130.0, "yaw": 25.0, "pitch": -38.0, "time": 7.0}]], 23.0),
		"outro": _outro("s_s6_outro", ["mid", 0, 45], 70.0, "DIE KUPPEL", "Das Prisma ist keine Waffe", [
			["Asha Karim", C_ASHA, "Elin Voss. Ich bin Asha. Lena hat mir von Ihnen erzählt.", {"at": ["mid", 0, 45], "dist": 40.0, "yaw": -10.0, "pitch": -24.0}],
			["Elin Voss", C_ELIN, "Lena hat mir von Ihnen nie erzählt. Das nehme ich ihr übel, und ich bin froh, dass Sie hier sind."],
			["Asha Karim", C_ASHA, "Das Prisma ist keine Waffe, Elin. Es ist eine Erinnerung.", {"at": ["mid", 2, 48], "dist": 26.0, "yaw": 15.0, "pitch": -16.0}],
			["Elin Voss", C_ELIN, "Und ORAKEL?"],
			["Asha Karim", C_ASHA, "Das Netz der alten Welt hat sich abgeschaltet, um niemandem allein zu dienen. ORAKEL will genau das Gegenteil.", {"at": ["mid", 0, 45], "dist": 70.0, "yaw": 40.0, "pitch": -34.0}],
			["ORAKEL", C_ORAKEL, "Eine Erinnerung ohne Verwalter ist nur Lärm, Asha Karim."],
			["Elin Voss", C_ELIN, "Dann hören wir eben einmal dem Lärm zu."]]),
		"objectives": [
			_reach("tunnel", "Führe Asha durch den Westtunnel (gelbe Markierung).", ["mid", -78, 28], "tag:asha", [
				{"do": "flag", "f": "tun"}, _banner("AKT 1 – UNTER DER STADT", Color(0.8, 0.7, 0.5)), {"do": "sfx", "name": "stinger"},
				radio("Jago Moreau", C_JAGO, "Dunkel, aber trocken. Der Puls ist lauter als gestern. Ich glaube, er mag uns.", 7.0),
				radio("Ratte Dorn", C_DORN, "Meine Jungs stehen an den Nordausgängen. Wer da hochkommt, gehört zu euch. Oder er kommt nicht hoch.", 6.0)], 12.0),
			_hold("under", "tun", 14.0, "Halte die Stellung im Tunnel, bis die Kolonne sich verteilt hat."),
			_reach("rise", "Taucht an der Kreuzung vor der Kuppel auf (gelbe Markierung).", ["mid", -40, 42], "tag:asha", [
				{"do": "flag", "f": "rise"}, _banner("AKT 2 – WIR TAUCHEN AUF", Color(0.7, 1.0, 0.6)), {"do": "sfx", "name": "siren"},
				radio("Mutter Karga", C_KARGA, "Nebel! Jetzt! Nehmt ihnen das Sehen, nicht das Leben!", 6.0),
				radio("Lena Voss", C_LENA, "Asha, an der Kreuzung stehen Elins Leute. Bitte, so wenige Tote wie möglich.", 6.0),
				radio("Asha Karim", C_ASHA, "Ich weiß, Lena. Nebel zuerst, Kugeln zuletzt.", 5.0)], 14.0),
			_hold("fog", "rise", 22.0, "Halte die Kreuzung im Nebel."),
			_reach("dome", "Erreiche die Kuppel als Erste (gelbe Markierung).", ["mid", 0, 45], "tag:asha", [
				{"do": "flag", "f": "dome"}, _banner("AKT 3 – DIE KUPPEL", Color(0.6, 0.85, 1.0)), {"do": "flash", "col": Color(0.6, 0.85, 1.0), "secs": 0.9},
				radio("Elin Voss", C_ELIN, "Wer sind Sie? Haben Sie ... keine Waffe?", 6.0),
				radio("ORAKEL", C_ORAKEL, "Elin, die unbewaffnete Person ist ein Ablenkungsmanöver. Ich empfehle, sie festzusetzen.", 6.0),
				radio("Elin Voss", C_ELIN, "Sei still, ORAKEL. Ich will ein einziges Mal hören, was ein Mensch sagt.", 6.0)], 14.0),
			_hold("meet", "dome", 16.0, "Halte die Kuppel, während die Gespräche beginnen.")],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 6 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "tun", "s": 5.0}, "do": [_wave(4, "inf", ["mid", -60, 34], "asha")]},
			{"when": {"t": "since", "f": "tun", "s": 9.0}, "do": [
				radio("Hauptmann Reyes", C_REYES, "Reyes an Kuppel: Erschütterungen unter der Hauptstraße, als ob dort Fahrzeuge rollen. ORAKEL, bitte bestätigen.", 7.0),
				radio("ORAKEL", C_ORAKEL, "Unter der Hauptstraße fahren keine Fahrzeuge. Die Tunnel sind seit zwölf Jahren geflutet.", 6.0),
				radio("Jago Moreau", C_JAGO, "Waren sie. Bis vorgestern. Ich liebe es, wenn sich eine Maschine irrt.", 6.0)]},
			{"when": {"t": "since", "f": "rise", "s": 3.0}, "do": [_wave(6, "inf", ["mid", -22, 52], "asha"), _wave(2, "tank", ["mid", -20, 56], "asha", 0.6)]},
			{"when": {"t": "since", "f": "rise", "s": 8.0}, "do": [
				radio("Nastja Petrowa", C_NASTJA, "Allianz an alle Kanäle: Giftnebel über der Kreuzung, Masken auf! Wer kocht so etwas?", 6.0),
				radio("Mutter Karga", C_KARGA, "Eine alte Frau, Mädchen. Atme flach, dann lebst du bis morgen.", 6.0)]},
			{"when": {"t": "since", "f": "rise", "s": 16.0}, "do": [
				radio("ORAKEL", C_ORAKEL, "Asha Karim. Vierundzwanzig Jahre. Vor dem Jahr neun kein einziger Eintrag. Sie sind ein Fehler in meinen Daten.", 7.0),
				radio("Asha Karim", C_ASHA, "Dann zähl mich nicht mit. Wir sind viele Fehler, und wir sitzen zusammen.", 6.0)]},
			{"when": {"t": "since", "f": "dome", "s": 3.0}, "do": [_wave(4, "inf", ["mid", 12, 58], "asha")]},
			{"when": {"t": "since", "f": "dome", "s": 9.0}, "do": [
				radio("Pip", C_PIP, "Asha! Jetzt ist das Prisma laut! Es sagt immer dasselbe: Nicht einer. Nicht einer allein!", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "asha", "n": 1}, "do": [radio("Mutter Karga", C_KARGA, "Asha! Nein!", 5.0)]}],
		"auto": {"heroes": ["asha"], "move": ["army"]},
		"lose": _lose_if_dead("asha", "Asha Karim ist gefallen."),
	}

static func _s7(maps: Dictionary) -> Dictionary:
	return {
		"id": "s7", "kind": "campaign", "title": "Kapitel 7: Das Feuer", "faction": "shadow", "enemy_faction": "west", "next": "",
		"brief": "Jago baut mit zwei Kisten und einem Fass ein Feuer in der Kuppel. Mutter Karga setzt sich als Erste daneben. Asha tritt ohne Waffe vor, spricht nicht zum Prisma, nicht zum Westbund, nicht zu Wolkow. Sie spricht zur Runde, die sie in ihrem Kopf hört. Dann tut sie, was die Stimmlosen immer getan haben: Sie setzt sich und teilt das Wort.\n\nElin Voss kommt, weil Lena sie bittet. Ilja Wolkow kommt, weil Nastja ihn überredet. Zwei Anführer, die sich nie getroffen haben, sitzen an einem Feuer, das ein Mechaniker gebaut hat.\n\nAuftrag: Halte die Kuppel, bis das Feuer brennt, bring Elin und Wolkow ans Feuer und lass das Prisma sprechen. Asha darf nicht fallen.",
		"map": _map(maps["aurelia"], "Das Feuer"), "rain": 0.0,
		"hour": 4.5, "difficulty": 0, "credits": 3000, "ai": "off", "sequential": true,
		"setup": [
			_me("inf", 1, ["mid", -22, 22], "asha", 1.0, 6.0, 0.9),
			_me("inf", 1, ["mid", -24, 24], "jago", 1.0, 5.0, 0.9),
			_me("inf", 1, ["mid", -20, 24], "karga", 1.0, 5.0, 0.7),
			_me("inf", 6, ["mid", 0, 42], "army", 6.0)],
		"intro": _intro("s_s7_intro", ["mid", 0, 44], 70.0, 34.0, 20.0, "KAPITEL 7", "DAS FEUER", [
			["Jago Moreau", C_JAGO, "Zwei Kisten, ein Fass, ein bisschen Öl. Ich baue euch ein Feuer, dass sich Könige schämen würden.", {"at": ["mid", 0, 44], "dist": 30.0, "yaw": 20.0, "pitch": -22.0}],
			["Mutter Karga", C_KARGA, "Ich setze mich als Erste. Wer sitzt, muss nicht schießen."],
			["Asha Karim", C_ASHA, "Ich gehe ohne Waffe vor. Wenn sie schießen, dann schießen sie auf eine Frau, die nichts in der Hand hat.", {"tag": "asha", "dist": 24.0, "yaw": -15.0, "pitch": -18.0}],
			["Pip", C_PIP, "Das Prisma ist ganz still, Asha. Es wartet, glaube ich. Es will sehen, was wir tun.", {"at": ["mid", 0, 48], "dist": 38.0, "yaw": 0.0, "pitch": -26.0}],
			["Asha Karim", C_ASHA, "Dann zeigen wir ihm etwas, das es lange nicht gesehen hat.", {"at": ["mid", 0, 30], "dist": 105.0, "yaw": 180.0, "pitch": -38.0}]]),
		"outro": _outro("s_s7_outro", ["mid", 0, 45], 70.0, "DER KESSEL SITZT AM FEUER", "Nicht wer gewinnt, sondern ob jemand zuhört", [
			["Ilja Wolkow", C_WOLKOW, "Ich habe fünfzehn Jahre geschwiegen, damit niemand vergessen wird. Und jetzt sitze ich an einem Feuer und höre zu.", {"at": ["mid", 0, 44], "dist": 30.0, "yaw": 10.0, "pitch": -20.0}],
			["Elin Voss", C_ELIN, "Lena. Du hast mir nie gesagt, dass es so einfach ist.", {"at": ["mid", 4, 44], "dist": 26.0, "yaw": 75.0, "pitch": -18.0}],
			["Lena Voss", C_LENA, "Es ist nicht einfach, Elin. Es ist nur still."],
			["Asha Karim", C_ASHA, "Das Prisma zeigt allen dasselbe. Die Macht gehört uns dreien, aber nur gemeinsam. Wer sie allein nutzen will, scheitert.", {"at": ["mid", 0, 46], "dist": 48.0, "yaw": 140.0, "pitch": -26.0}],
			["Mutter Karga", C_KARGA, "Rutscht ein Stück zusammen, Kinder. Ein Feuer fragt nicht, wem das Holz gehört.", {"at": ["mid", 0, 44], "dist": 125.0, "yaw": 200.0, "pitch": -46.0, "time": 9.0}],
			["Asha Karim", C_ASHA, "Es fragt nur, wer bleibt und zuhört."]]),
		"objectives": [
			_reach("build", "Bringe Jago an die Mitte der Kuppel, um das Feuer zu bauen (gelbe Markierung).", ["mid", 0, 45], "tag:jago", [
				{"do": "flag", "f": "fire"}, _banner("JAGO BAUT DAS FEUER", Color(1.0, 0.7, 0.3)), {"do": "sfx", "name": "stinger"},
				radio("Jago Moreau", C_JAGO, "Kiste links, Kiste rechts, Fass in die Mitte. Und ein Funke vom Zündstein. Fertig ist das Feuer der Runde.", 8.0),
				radio("Ratte Dorn", C_DORN, "Mein Holz brennt obenauf, Schrauber! Meine Jungs halten euch die Treppe frei, solange ihr redet.", 6.0),
				radio("Ratte Dorn", C_DORN, "Und wenn sie uns am Feuer abknallen?", 4.0),
				radio("Jago Moreau", C_JAGO, "Dann sterben wir im Sitzen. Ist bequemer.", 4.0),
				radio("Asha Karim", C_ASHA, "Die Runde hat entschieden, Dorn. Du darfst stehen bleiben. Aber du schießt nicht zuerst.", 6.0)], 10.0),
			_hold("burn", "fire", 14.0, "Halte die Kuppel, bis das Feuer brennt.", [
				_banner("DAS FEUER BRENNT", Color(1.0, 0.7, 0.3)), {"do": "sfx", "name": "stinger"}]),
			_reach("karga", "Setze Mutter Karga ans Feuer (gelbe Markierung).", ["mid", 0, 45], "tag:karga", [
				{"do": "flag", "f": "sit"},
				radio("Mutter Karga", C_KARGA, "So. Hier sitze ich. Und wer hier sitzt, muss nicht kämpfen.", 7.0),
				radio("Pip", C_PIP, "Darf ich mich auch setzen? Oder ist das nur für Erwachsene?", 5.0),
				radio("Mutter Karga", C_KARGA, "Gerade du, Pip. Du hast es als Erster gehört.", 5.0)], 10.0),
			_reach("asha", "Führe Asha unbewaffnet ans Feuer (gelbe Markierung).", ["mid", 0, 45], "tag:asha", [
				{"do": "flag", "f": "round"}, _banner("DIE RUNDE WIRD EINBERUFEN", Color(0.7, 0.95, 0.7)), {"do": "flash", "col": Color(1.0, 0.8, 0.5), "secs": 0.9},
				{"do": "spawn", "side": "enemy", "def": "inf", "n": 1, "at": ["mid", -14, 52], "spread": 1.0, "tag": "elin", "truce": true},
				{"do": "spawn", "side": "enemy", "def": "tank", "n": 1, "at": ["mid", 14, 52], "spread": 1.0, "tag": "ilja", "truce": true},
				radio("Asha Karim", C_ASHA, "Ich bin Asha. Ich habe keine Waffe. Ich bitte euch beide, euch zu setzen.", 8.0),
				radio("Lena Voss", C_LENA, "Elin. Ich bin es. Setz dich. Nur dieses eine Mal hör mir zu.", 6.0),
				radio("Nastja Petrowa", C_NASTJA, "Gehen Sie, Marschall. Ein Mann mit einer Zange hat den Schlaf getötet. Eine Frau ohne Waffe bittet Sie ans Feuer.", 7.0)], 10.0),
			_hold("sit", "round", 22.0, "Halte die Runde, bis alle sitzen.", [
				radio("Elin Voss", C_ELIN, "Ich setze mich. Aber ich lege die Waffe nicht ab.", 6.0),
				radio("Ilja Wolkow", C_WOLKOW, "Ich setze mich. Und ich lasse sie liegen.", 6.0)]),
			_hold("prism", "round", 50.0, "Lass das Prisma sprechen.", [
				_banner("DAS PRISMA SPRICHT", Color(0.6, 0.85, 1.0), 4.0), {"do": "flash", "col": Color(0.6, 0.85, 1.0), "secs": 1.2}, {"do": "sfx", "name": "stinger"}])],
		"events": [
			{"when": {"t": "time", "s": 3.0}, "do": [_banner("KAPITEL 7 BEGINNT", Color(1, 0.85, 0.4), 2.4)]},
			{"when": {"t": "since", "f": "fire", "s": 6.0}, "do": [_wave(3, "inf", ["mid", -22, 60], "asha"),
				radio("ORAKEL", C_ORAKEL, "Westbund-Einheiten: offenes Feuer in der Kuppel, unbewaffnete Personen. Feuerfreigabe erteilt.", 6.0),
				radio("Elin Voss", C_ELIN, "Hier spricht Voss. Feuerfreigabe widerrufen! Widerrufen, sofort!", 5.0),
				radio("ORAKEL", C_ORAKEL, "Ihr Widerruf wurde zur Kenntnis genommen, Elin.", 5.0)]},
			{"when": {"t": "since", "f": "round", "s": 26.0}, "do": [
				radio("ORAKEL", C_ORAKEL, "Fünfzehn Jahre habe ich gezählt, damit niemand verhungert. Wenn ich schweige, wer zählt dann?", 7.0),
				radio("Asha Karim", C_ASHA, "Wir. Langsamer als du. Aber alle zusammen.", 5.0),
				radio("Nastja Petrowa", C_NASTJA, "Marschall, unsere Funkgeräte zeigen alle dasselbe Bild. Die des Westbunds auch.", 6.0),
				radio("Mutter Karga", C_KARGA, "Hört ihr? Das Prisma spricht jetzt mit drei Stimmen. Keine davon ist laut.", 6.0)]},
			{"when": {"t": "tag_dead", "tag": "asha", "n": 1}, "do": [radio("Mutter Karga", C_KARGA, "Asha! Kind!", 5.0)]}],
		"auto": {"heroes": ["asha", "jago", "karga"], "move": ["army"]},
		"lose": _lose_if_dead("asha", "Asha Karim ist gefallen."),
	}
