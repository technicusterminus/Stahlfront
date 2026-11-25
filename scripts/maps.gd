extends RefCounted
## Kartenbeschreibung: Regler (Spec) und daraus abgeleitete Lage von Startpunkten und Rohstoffvorkommen.
##   size       Weltgröße in Metern (160 … 336)
##   water      Wasseranteil 0 … 1 (Mittelsee, Kanäle, Buchten, natürliche Seen)
##   islands    Inselreichtum 0 … 1 (Inseln im Meer)
##   resources  Rohstoffreichtum 0 … 1 (Menge je Vorkommen und Zahl zusätzlicher Vorkommen)
##   hills      Geländeunruhe 0 … 1 (Höhenunterschiede, Grate)
##   forest     Waldanteil 0 … 1
##   layout     Gewässerform: 0 Kreuz, 1 Windungen, 2 getrennte Seen, 3 Uferkanal
##   seed       Zufallszahl der Karte
##   dry_core   Radius (m) um die Kartenmitte, der trocken bleibt (Pässe, Hochebenen im Zentrum); 0 = aus
##   causeway   halbe Breite (m) eines Damms/einer Brücke quer über den Mittelsee; 0 = aus
##   causeway_deg  Richtung des Damms in Grad (0 = entlang der x-Achse)
##   biome      Landschaftsprägung (Pflanzen, Farben, Schneegrenze, Tiere), siehe scripts/biome.gd; "" = Standard
##   sites      Orte der Karte (Städte, Ruinen, Kuppel, Masten ...), siehe scripts/settlement.gd

const SIZE_MIN := 256
const SIZE_MAX := 640

static func default_spec() -> Dictionary:
	return {"name": "Standardkarte", "size": 240, "water": 0.5, "islands": 0.3, "resources": 0.5, "hills": 0.5, "forest": 0.5, "layout": 0, "seed": 7, "dry_core": 0.0, "causeway": 0.0, "causeway_deg": 0.0, "biome": "", "sites": []}

const LAYOUT_NAMES := ["Kreuzsee", "Windungen", "Getrennte Seen", "Uferkanal"]
const ARCH := [
	{"n": ["Kreuzsee", "Silberkreuz", "Morgenbucht", "Nordstern"], "l": 0, "w": 0.5, "i": 0.3, "r": 0.5, "h": 0.5, "f": 0.5},
	{"n": ["Windungen", "Schlangenbach", "Silberschleife", "Mäandertal"], "l": 1, "w": 0.55, "i": 0.35, "r": 0.5, "h": 0.4, "f": 0.6},
	{"n": ["Seenplatte", "Tausend Teiche", "Blaue Lagune", "Moorland"], "l": 2, "w": 0.75, "i": 0.5, "r": 0.5, "h": 0.3, "f": 0.5},
	{"n": ["Uferkanal", "Hafenring", "Küstenpass", "Kanalstadt"], "l": 3, "w": 0.6, "i": 0.2, "r": 0.5, "h": 0.5, "f": 0.4},
	{"n": ["Hochland", "Adlerhorst", "Felsplateau", "Nebelberge"], "l": 0, "w": 0.2, "i": 0.05, "r": 0.6, "h": 1.0, "f": 0.6},
	{"n": ["Inselmeer", "Korallenriff", "Archipel", "Perlenkette"], "l": 1, "w": 1.0, "i": 1.0, "r": 0.7, "h": 0.3, "f": 0.5},
	{"n": ["Waldwelt", "Schwarzwald", "Grünes Dach", "Jagdrevier"], "l": 2, "w": 0.3, "i": 0.1, "r": 0.5, "h": 0.5, "f": 1.0},
	{"n": ["Steppe", "Weites Land", "Goldene Ebene", "Staubfeld"], "l": 0, "w": 0.1, "i": 0.0, "r": 0.7, "h": 0.1, "f": 0.1},
	{"n": ["Schären", "Nordfjord", "Stürmische See", "Klippenküste"], "l": 3, "w": 0.85, "i": 0.9, "r": 0.4, "h": 0.6, "f": 0.4},
	{"n": ["Klamm", "Felsenschlucht", "Rotes Tal", "Eisenpass"], "l": 1, "w": 0.35, "i": 0.1, "r": 0.9, "h": 0.9, "f": 0.3},
]
const SIZES := [320, 400, 480, 560]
static var _presets: Array = []

## Die 40 Standardkarten: zehn Landschaftstypen in je vier Größen und Abwandlungen.
static func presets() -> Array:
	if not _presets.is_empty():
		return _presets
	for a in ARCH.size():
		var A: Dictionary = ARCH[a]
		for v in 4:
			var jit = [0.0, 0.12, -0.1, 0.06][v]
			var sp = {
				"name": A["n"][v], "layout": A["l"], "size": SIZES[(a + v) % 4],
				"water": clamp(float(A["w"]) + jit, 0.0, 1.0), "islands": clamp(float(A["i"]) - jit * 0.6, 0.0, 1.0),
				"resources": clamp(float(A["r"]) + [0.0, -0.1, 0.15, 0.05][v], 0.0, 1.0),
				"hills": clamp(float(A["h"]) - jit, 0.0, 1.0), "forest": clamp(float(A["f"]) + [0.0, 0.1, -0.1, 0.2][v], 0.0, 1.0),
				"seed": 1000 + a * 37 + v * 211,
			}
			_presets.append(clean(sp))
	return _presets

static func preset(i: int) -> Dictionary:
	var all = presets()
	return all[clampi(i - 1, 0, all.size() - 1)].duplicate()
static func clean(sp: Dictionary) -> Dictionary:
	var d = default_spec()
	d.merge(sp, true)
	d["size"] = clampi(int(round(float(d["size"]) / 16.0)) * 16, SIZE_MIN, SIZE_MAX)
	for k in ["water", "islands", "resources", "hills", "forest"]:
		d[k] = clamp(float(d[k]), 0.0, 1.0)
	d["layout"] = clampi(int(d["layout"]), 0, 3)
	d["dry_core"] = clamp(float(d["dry_core"]), 0.0, 80.0)
	d["causeway"] = clamp(float(d["causeway"]), 0.0, 20.0)
	d["causeway_deg"] = float(d["causeway_deg"])
	d["seed"] = int(d["seed"])
	return d

## Alle Ortsangaben ["me"|"en"|"mid", x, z] einer Mission (Ziele, Spawns, Kamerapunkte). Der Geländebau hält sie
## von Bäumen frei, damit dichter Wald kein Ziel überdeckt oder einen Weg dorthin sperrt.
static func mission_spots(node, out: Array = [], top := true) -> Array:
	if node is Dictionary:
		for k in node.keys():
			if top and str(k) == "map":
				continue
			mission_spots(node[k], out, false)
	elif node is Array:
		if node.size() == 3 and node[0] is String and ["me", "en", "mid"].has(node[0]) and (node[1] is float or node[1] is int) and (node[2] is float or node[2] is int):
			out.append([node[0], float(node[1]), float(node[2])])
		else:
			for v in node:
				mission_spots(v, out, false)
	return out

## Lage der Bucht vor einer Startbasis: halber Weg zur Kartenmitte.
static func bay_center(start: Vector2) -> Vector2:
	return start * 0.5

static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.dot(ab), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Vorberechnete Gewässerform (Mittelsee, Kanäle, Buchten) für schnelle Abstandsabfragen.
static func sea_ctx(sp: Dictionary, starts: Array) -> Dictionary:
	var k = float(sp["size"]) / 240.0
	var water: float = sp["water"]
	var ctx = {"R": sea_radius(sp), "chw": lerp(3.2, 6.5, water) * (0.8 + 0.2 * k), "bayr": lerp(6.0, 9.0, water) * (0.5 + 0.5 * k),
		"layout": int(sp.get("layout", 0)), "segs": [], "bays": [],
		"dry": float(sp.get("dry_core", 0.0)) * k, "cw": float(sp.get("causeway", 0.0)) * (0.6 + 0.4 * k),   # Dammbreite wächst mit der Karte wie die Ufer
		"axis": Vector2(cos(deg_to_rad(float(sp.get("causeway_deg", 0.0)))), sin(deg_to_rad(float(sp.get("causeway_deg", 0.0)))))}
	var order = [0, 2, 1, 3]
	for i in starts.size():
		var b = bay_center(starts[i])
		ctx["bays"].append(b)
		match ctx["layout"]:
			0:
				ctx["segs"].append([b, Vector2.ZERO])
			1:
				var side = Vector2(-b.y, b.x).normalized() * (0.3 * b.length()) * (1.0 if i % 2 == 0 else -1.0)
				var bend = b * 0.5 + side
				ctx["segs"].append([b, bend])
				ctx["segs"].append([bend, Vector2.ZERO])
			3:
				if i < 3:
					ctx["segs"].append([bay_center(starts[order[i]]), bay_center(starts[order[i + 1]])])
	return ctx

## Abstand zum Wasser: negativ im Wasser.
static func sea_dist(p: Vector2, ctx: Dictionary) -> float:
	var best: float = p.length() - ctx["R"]
	for b in ctx["bays"]:
		best = min(best, p.distance_to(b) - ctx["bayr"])
	for s in ctx["segs"]:
		best = min(best, _seg_d(p, s[0], s[1]) - ctx["chw"])
	# Trockener Kern (Pass, Plateau) und Damm quer über den See: überstimmen das Wasser
	if ctx["dry"] > 0.0:
		best = max(best, (ctx["dry"] - p.length()) + 6.0)
	if ctx["cw"] > 0.0:
		var ax: Vector2 = ctx["axis"]
		if absf(p.dot(ax)) < ctx["R"] + 14.0:
			best = max(best, (ctx["cw"] - absf(p.x * ax.y - p.y * ax.x)) + 6.0)
	return best
static func sea_radius(sp: Dictionary) -> float:
	return lerp(7.0, 30.0, float(sp["water"])) * float(sp["size"]) / 240.0

static func resource_factor(sp: Dictionary) -> float:
	return lerp(0.5, 1.8, float(sp["resources"]))

## Lage aller Startpunkte und Vorkommen: {starts, depots: [[Vector2, Art, Menge]]}
static func layout(sp: Dictionary) -> Dictionary:
	var size: float = float(sp["size"])
	var H = size * 0.5
	var k = size / 240.0
	var e = H * 0.683
	var starts = [Vector2(-e, e), Vector2(e, -e), Vector2(e, e), Vector2(-e, -e)]
	var rf = resource_factor(sp)
	var R = sea_radius(sp)
	var ctx = sea_ctx(sp, starts)
	var depots = []
	for s in starts:
		var dd: Vector2 = s * 0.72
		var perp = Vector2(-dd.y, dd.x).normalized()
		depots.append([dd, "supply", 45000.0 * rf])
		depots.append([dd + perp * 21.0 * (0.8 + 0.2 * k), "wood", 20000.0 * rf])
		depots.append([dd - perp * 21.0 * (0.8 + 0.2 * k), "iron", 20000.0 * rf])
		depots.append([dd * 1.18, "oil", 16000.0 * rf])
	var m = H * 0.65
	for p in [Vector2(0, -m), Vector2(0, m), Vector2(-m, 0), Vector2(m, 0)]:
		depots.append([p, "supply", 50000.0 * rf])
	depots.append([Vector2(0, R + 10.0 * k), "supply", 80000.0 * rf])
	var gd = min(R + 24.0 * k, H * 0.62) if int(sp.get("layout", 0)) != 3 else R + 14.0 * k
	for g in [Vector2(gd, 0), Vector2(-gd, 0), Vector2(0, gd), Vector2(0, -gd)]:
		depots.append([g, "gold", 9000.0 * rf])
	# zusätzliche Vorkommen auf einem Ring zwischen Basen und Mitte, abseits der Kanäle
	var rng = RandomNumberGenerator.new()
	rng.seed = int(sp["seed"]) + 991
	var extra = int(round(float(sp["resources"]) * 8.0))
	var kinds = ["iron", "wood", "oil", "gold", "supply", "iron", "wood", "oil"]
	var tries = 0
	var placed = 0
	while placed < extra and tries < 200:
		tries += 1
		var ang = rng.randf() * TAU
		var diag = abs(sin(ang * 2.0))   # 1 auf den Diagonalen: dort liegen die Kanäle
		if diag > 0.8 and rng.randf() < 0.9:
			continue
		var r = rng.randf_range(0.34, 0.6) * H
		var p = Vector2(cos(ang), sin(ang)) * r
		if p.length() < R + 14.0 * k:
			continue
		var ok = true
		for d in depots:
			if p.distance_to(d[0]) < 16.0:
				ok = false
				break
		for s in starts:
			if p.distance_to(s) < 40.0:
				ok = false
		if not ok:
			continue
		var kind: String = kinds[placed % kinds.size()]
		depots.append([p, kind, (6000.0 if kind == "gold" else 12000.0) * rf])
		placed += 1
	# Vorkommen, die im oder am Wasser liegen, wandern nach außen
	for d in depots:
		var q: Vector2 = d[0]
		var guard = 0
		while sea_dist(q, ctx) < 15.0 and guard < 14:
			q += (q.normalized() if q.length() > 1.0 else Vector2(1, 0)) * 3.0
			guard += 1
		d[0] = q
	return {"starts": starts, "depots": depots}
