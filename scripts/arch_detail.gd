extends RefCounted
## Detailstufe für Gebäude: Fenster mit Rahmen, Türen, Treppen, Geländer, Rohre, Lüfter,
## Paletten, Fahrzeuge, Beete, Arbeiter – plus Animationen (out["anims"]), die building.gd abspielt.
## Animationstypen: spin, blink, wave, walk, slide, bob, swing, weld.

const M = preload("res://scripts/models.gd")

# ================================================================ Bausteine

static func anim(out: Dictionary, a: Dictionary) -> void:
	if not out.has("anims"):
		out["anims"] = []
	out["anims"].append(a)

static func glass() -> Material:
	return M.mat(Color(0.08, 0.15, 0.22), 0.9, 0.06)

static func lit(col := Color(1.0, 0.82, 0.5), e := 2.2) -> Material:
	return M.glow(col, e)

## Fensterreihe auf einer Wand: Rahmen, Glas (teils beleuchtet), Sims.
## origin = Wandmitte, dir = Richtung entlang der Wand, nrm = Wandnormale.
static func windows(p: Node3D, origin: Vector3, dir: Vector3, nrm: Vector3, length: float, count: int, ww := 0.55, wh := 0.7, frame: Material = null) -> void:
	var fr = frame if frame != null else M.dark()
	var rot_y = atan2(nrm.x, nrm.z)
	for i in count:
		var c = origin + dir * (-length * 0.5 + length * (i + 0.5) / count) + nrm * 0.03
		var n = M.node(p, c)
		n.rotation.y = rot_y
		M.box(n, Vector3(ww + 0.12, wh + 0.12, 0.05), Vector3.ZERO, fr)
		M.box(n, Vector3(ww, wh, 0.06), Vector3(0, 0, 0.01), lit() if (i * 7 + int(c.x * 3.0)) % 3 == 0 else glass())
		M.box(n, Vector3(0.04, wh, 0.07), Vector3(0, 0, 0.02), fr)
		M.box(n, Vector3(ww + 0.2, 0.06, 0.16), Vector3(0, -wh * 0.5 - 0.07, 0.06), M.concrete())

static func door(p: Node3D, pos: Vector3, rot_y: float, dw := 1.1, dh := 2.0, lamp := true) -> void:
	var n = M.node(p, pos)
	n.rotation.y = rot_y
	M.box(n, Vector3(dw + 0.2, dh + 0.15, 0.08), Vector3(0, dh * 0.5, 0), M.dark())
	M.box(n, Vector3(dw, dh, 0.06), Vector3(0, dh * 0.5, 0.03), M.mat(Color(0.25, 0.27, 0.3), 0.6, 0.5))
	M.box(n, Vector3(0.04, 0.25, 0.05), Vector3(dw * 0.35, dh * 0.5, 0.08), M.steel())
	M.box(n, Vector3(dw + 0.5, 0.12, 0.6), Vector3(0, dh + 0.2, 0.3), M.dark())
	if lamp:
		M.box(n, Vector3(0.25, 0.08, 0.15), Vector3(0, dh + 0.12, 0.5), lit(Color(1.0, 0.9, 0.7), 5.0))
	M.box(n, Vector3(dw + 0.4, 0.12, 0.6), Vector3(0, 0.06, 0.32), M.concrete())

static func stairs(p: Node3D, pos: Vector3, rot_y: float, steps: int, sw := 1.6, step_h := 0.16, step_d := 0.32) -> void:
	var n = M.node(p, pos)
	n.rotation.y = rot_y
	for i in steps:
		M.box(n, Vector3(sw, step_h * (steps - i), step_d), Vector3(0, step_h * (steps - i) * 0.5, i * step_d), M.concrete())

static func railing(p: Node3D, a: Vector3, b: Vector3, h := 0.9, m: Material = null) -> void:
	var mm = m if m != null else M.steel()
	var d = b - a
	var ln = d.length()
	var n = int(ln / 1.0) + 1
	for i in n + 1:
		var q = a + d * (float(i) / n)
		M.box(p, Vector3(0.04, h, 0.04), q + Vector3(0, h * 0.5, 0), mm)
	var mid = (a + b) * 0.5
	var ry = atan2(d.x, d.z)
	M.box(p, Vector3(0.05, 0.05, ln), mid + Vector3(0, h, 0), mm, Vector3(0, ry, 0))
	M.box(p, Vector3(0.03, 0.03, ln), mid + Vector3(0, h * 0.5, 0), mm, Vector3(0, ry, 0))

static func pipe(p: Node3D, a: Vector3, b: Vector3, r := 0.09, m: Material = null) -> void:
	var mm = m if m != null else M.steel()
	var d = b - a
	var mi = M.cyl(p, r, r, d.length(), (a + b) * 0.5, mm, Vector3.ZERO, 8)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	M.sph(p, r * 1.4, a, mm)
	M.sph(p, r * 1.4, b, mm)

## Dachlüfter mit drehendem Ventilator.
static func vent(p: Node3D, pos: Vector3, out: Dictionary, s := 1.0) -> void:
	M.box(p, Vector3(0.9, 0.5, 0.9) * s, pos + Vector3(0, 0.25 * s, 0), M.steel())
	var f = M.node(p, pos + Vector3(0, 0.52 * s, 0))
	M.cyl(p, 0.38 * s, 0.38 * s, 0.04, pos + Vector3(0, 0.5 * s, 0), M.dark(), Vector3.ZERO, 16)
	for k in 3:
		M.box(f, Vector3(0.65 * s, 0.02, 0.12 * s), Vector3.ZERO, M.steel(), Vector3(0, k * PI / 3, 0.25))
	anim(out, {"t": "spin", "n": f, "s": 6.0})

static func ac_unit(p: Node3D, pos: Vector3, rot_y: float, out: Dictionary) -> void:
	var n = M.node(p, pos)
	n.rotation.y = rot_y
	M.box(n, Vector3(1.0, 0.6, 0.5), Vector3(0, 0.3, 0), M.mat(Color(0.75, 0.76, 0.77), 0.4, 0.5))
	M.cyl(n, 0.22, 0.22, 0.03, Vector3(0, 0.35, 0.26), M.dark(), Vector3(PI / 2, 0, 0), 14)
	var f = M.node(n, Vector3(0, 0.35, 0.27))
	for k in 2:
		M.box(f, Vector3(0.38, 0.06, 0.01), Vector3.ZERO, M.steel(), Vector3(0, 0, k * PI / 2))
	anim(out, {"t": "spin_z", "n": f, "s": 10.0})

static func blink_light(p: Node3D, pos: Vector3, col: Color, out: Dictionary, period := 1.2, offset := 0.0) -> void:
	var b = M.sph(p, 0.09, pos, M.glow(col, 9.0))
	anim(out, {"t": "blink", "n": b, "p": period, "o": offset})

## Fahne an Mast, weht im Wind.
static func flag(p: Node3D, pos: Vector3, h: float, col: Color, out: Dictionary) -> void:
	M.cyl(p, 0.04, 0.05, h, pos + Vector3(0, h * 0.5, 0), M.steel(), Vector3.ZERO, 6)
	M.sph(p, 0.07, pos + Vector3(0, h, 0), M.mat(Color(0.8, 0.7, 0.3), 0.8, 0.3))
	var piv = M.node(p, pos + Vector3(0, h - 0.45, 0))
	var segs = []
	var prev: Node3D = piv
	for i in 4:
		var s = M.node(prev, Vector3(0, 0, 0.0 if i == 0 else 0.32))
		M.box(s, Vector3(0.02, 0.7, 0.32), Vector3(0, 0, 0.16), M.mat(col.darkened(0.08 * i), 0.0, 0.8))
		segs.append(s)
		prev = s
	anim(out, {"t": "wave", "segs": segs, "o": pos.x * 0.7 + pos.z})

static func pallet(p: Node3D, pos: Vector3, rot_y: float, crates: int) -> void:
	var n = M.node(p, pos)
	n.rotation.y = rot_y
	var wood = M.mat(Color(0.55, 0.42, 0.26), 0.0, 0.9)
	M.box(n, Vector3(1.2, 0.14, 1.0), Vector3(0, 0.07, 0), wood)
	for i in crates:
		var c = M.box(n, Vector3(0.5, 0.45, 0.45), Vector3(-0.28 + (i % 2) * 0.56, 0.37 + (i / 4) * 0.45, -0.24 + ((i / 2) % 2) * 0.48), M.mat(Color(0.5, 0.38, 0.22).lerp(Color(0.35, 0.4, 0.3), float(i % 3) * 0.3), 0.0, 0.9))
		c.rotation.y = (i % 3) * 0.06

static func barrels(p: Node3D, pos: Vector3, n: int, col := Color(0.25, 0.3, 0.22)) -> void:
	for i in n:
		M.cyl(p, 0.27, 0.27, 0.85, pos + Vector3((i % 3) * 0.58, 0.43, (i / 3) * 0.58), M.mat(col if i % 4 != 1 else Color(0.5, 0.15, 0.1), 0.5, 0.6), Vector3.ZERO, 12)

static func planter(p: Node3D, pos: Vector3, r := 0.8) -> void:
	M.cyl(p, r, r, 0.45, pos + Vector3(0, 0.22, 0), M.concrete(), Vector3.ZERO, 12)
	M.cyl(p, r * 0.9, r * 0.9, 0.05, pos + Vector3(0, 0.45, 0), M.mat(Color(0.18, 0.12, 0.08), 0, 1), Vector3.ZERO, 12)
	M.cyl(p, 0.06, 0.09, 1.4, pos + Vector3(0, 1.1, 0), M.mat(Color(0.3, 0.2, 0.12), 0, 0.9), Vector3.ZERO, 6)
	M.sph(p, r * 0.85, pos + Vector3(0, 2.0, 0), M.mat(Color(0.2, 0.38, 0.14), 0, 0.85), Vector3(1, 0.85, 1))
	for i in 5:
		var a = TAU * i / 5.0
		M.sph(p, 0.07, pos + Vector3(cos(a) * r * 0.6, 0.52, sin(a) * r * 0.6), M.mat([Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.8, 0.5, 1)][i % 3], 0, 0.7))

## Fahrzeug aus dem Einheitenbaukasten als Deko (Stil wird danach wiederhergestellt).
static func vehicle(p: Node3D, model: String, pos: Vector3, rot_y: float, s := 0.85) -> Node3D:
	var f = M._fac
	var tcol = M._team
	var bld = M._bld
	var v = M.build_unit(model, tcol, f)["root"]
	M.set_style(f, tcol, bld)
	v.position = pos
	v.rotation.y = rot_y
	v.scale = Vector3.ONE * s
	p.add_child(v)
	return v

## Kleine Arbeiterfigur: rundliche Glieder mit Knie, Ellbogen, Händen und Füßen; Beine und Arme sind
## einzeln beweglich (LegL/LegR mit ShinL/ShinR, ArmL/ArmR mit ForeL/ForeR).
static func worker(faction: String) -> Node3D:
	var n = Node3D.new()
	var suit: Color
	var hat: Color
	match faction:
		"west":
			suit = Color(0.85, 0.87, 0.9)
			hat = Color(0.2, 0.45, 0.95)
		"red":
			suit = Color(0.32, 0.34, 0.3)
			hat = Color(0.75, 0.15, 0.1)
		_:
			suit = Color(0.62, 0.53, 0.38)
			hat = Color(0.25, 0.22, 0.18)
	var sm = M.mat(suit, 0.0, 0.85)
	var pants = M.mat(suit.darkened(0.32), 0.0, 0.9)
	var skin = M.mat(Color(0.78, 0.6, 0.47), 0, 0.8)
	var boot = M.mat(Color(0.12, 0.1, 0.09), 0.1, 0.8)
	var glove = M.mat(Color(0.25, 0.22, 0.18) if faction != "west" else Color(0.9, 0.9, 0.92), 0.0, 0.8)
	# Becken und Rumpf: weich geformt
	M.sph(n, 0.15, Vector3(0, 0.8, 0), pants, Vector3(1.15, 0.8, 0.95))
	M.sph(n, 0.2, Vector3(0, 1.1, 0), sm, Vector3(1.1, 1.3, 0.8))
	M.cyl(n, 0.13, 0.15, 0.2, Vector3(0, 0.95, 0), sm, Vector3.ZERO, 10)
	M.sph(n, 0.1, Vector3(-0.24, 1.27, 0), sm)
	M.sph(n, 0.1, Vector3(0.24, 1.27, 0), sm)
	M.cyl(n, 0.05, 0.06, 0.1, Vector3(0, 1.35, 0), skin, Vector3.ZERO, 8)
	M.sph(n, 0.125, Vector3(0, 1.47, 0), skin, Vector3(0.95, 1.05, 1.0))
	M.sph(n, 0.025, Vector3(0, 1.45, 0.12), M.mat(Color(0.65, 0.48, 0.38), 0, 0.8))
	# Gürtel
	M.cyl(n, 0.17, 0.17, 0.05, Vector3(0, 0.86, 0), M.mat(Color(0.15, 0.12, 0.1), 0.2, 0.7), Vector3.ZERO, 12)
	# Beine: Oberschenkel, Knie, Wade mit Stiefel
	for sx in [-0.095, 0.095]:
		var left = sx < 0
		var leg = M.node(n, Vector3(sx, 0.78, 0))
		leg.name = "LegL" if left else "LegR"
		leg.rotation.x = 0.1   # im Stand leicht gebeugt: Knie sichtbar
		M.cyl(leg, 0.08, 0.06, 0.4, Vector3(0, -0.2, 0), pants, Vector3.ZERO, 10)
		M.sph(leg, 0.085, Vector3(0, -0.07, -0.01), pants, Vector3(1.0, 1.4, 1.1))   # Oberschenkelmuskel
		M.sph(leg, 0.075, Vector3(0, -0.4, 0.02), pants, Vector3(1.0, 0.95, 1.1))   # Kniescheibe
		M.sph(leg, 0.058, Vector3(0, -0.4, 0.07), boot, Vector3(1.1, 0.8, 0.7))   # Knieschoner
		var shin = M.node(leg, Vector3(0, -0.4, 0))
		shin.name = "ShinL" if left else "ShinR"
		shin.rotation.x = 0.28
		M.cyl(shin, 0.058, 0.04, 0.34, Vector3(0, -0.18, 0), pants, Vector3.ZERO, 10)
		M.sph(shin, 0.062, Vector3(0, -0.1, -0.025), pants, Vector3(1.0, 1.5, 1.0))   # Wade
		M.sph(shin, 0.062, Vector3(0, -0.38, 0.045), boot, Vector3(0.95, 0.7, 1.7))
	# Arme: Oberarm, Ellbogen, Unterarm, Hand
	for sx in [-0.25, 0.25]:
		var left2 = sx < 0
		var arm = M.node(n, Vector3(sx, 1.27, 0))
		arm.name = "ArmL" if left2 else "ArmR"
		M.cyl(arm, 0.058, 0.05, 0.3, Vector3(0, -0.15, 0), sm, Vector3.ZERO, 8)
		M.sph(arm, 0.052, Vector3(0, -0.3, 0), sm)
		var fore = M.node(arm, Vector3(0, -0.3, 0))
		fore.name = "ForeL" if left2 else "ForeR"
		fore.rotation.x = -0.35
		M.cyl(fore, 0.05, 0.04, 0.28, Vector3(0, -0.14, 0), sm, Vector3.ZERO, 8)
		M.sph(fore, 0.055, Vector3(0, -0.3, 0), glove)
	match faction:
		"west":
			# Leuchtweste, Helm mit Visier
			M.sph(n, 0.215, Vector3(0, 1.13, 0), M.glow(Color(0.9, 1.0, 0.3), 1.2), Vector3(1.12, 0.45, 0.85))
			M.sph(n, 0.15, Vector3(0, 1.53, 0), M.mat(hat, 0.2, 0.5), Vector3(1.0, 0.65, 1.1))
			M.sph(n, 0.07, Vector3(0, 1.49, 0.1), M.mat(Color(0.1, 0.2, 0.3), 0.8, 0.1), Vector3(1.3, 0.5, 0.6))
		"red":
			# Schirmmütze mit Stern, Schulterklappen
			M.sph(n, 0.14, Vector3(0, 1.54, 0), M.mat(hat, 0.1, 0.7), Vector3(1.0, 0.55, 1.05))
			M.box(n, Vector3(0.2, 0.025, 0.1), Vector3(0, 1.5, 0.13), M.mat(hat.darkened(0.4), 0.1, 0.7), Vector3(0.15, 0, 0))
			M.sph(n, 0.02, Vector3(0, 1.55, 0.14), M.glow(Color(1.0, 0.82, 0.2), 1.0))
			for sx in [-0.24, 0.24]:
				M.box(n, Vector3(0.12, 0.02, 0.1), Vector3(sx, 1.33, 0), M.mat(Color(0.7, 0.6, 0.25), 0.4, 0.5))
		_:
			# Kopftuch, Hut mit Krempe, Rucksack
			M.sph(n, 0.135, Vector3(0, 1.53, 0), M.mat(hat, 0, 0.9), Vector3(1.0, 0.5, 1.05))
			M.cyl(n, 0.2, 0.2, 0.025, Vector3(0, 1.53, 0), M.mat(hat, 0, 0.9), Vector3.ZERO, 14)
			M.sph(n, 0.1, Vector3(0, 1.41, 0.07), M.mat(Color(0.55, 0.2, 0.15), 0, 0.9), Vector3(1.1, 0.55, 0.8))
			M.sph(n, 0.17, Vector3(0, 1.12, -0.19), M.mat(Color(0.35, 0.28, 0.18), 0, 0.9), Vector3(1.0, 1.3, 0.7))
	n.scale = Vector3.ONE * 1.15
	return n
## Arbeiter, der einen Rundweg (lokale Punkte) abläuft.
static func walker(p: Node3D, faction: String, pts: Array, out: Dictionary, speed := 1.2) -> void:
	var w = worker(faction)
	w.position = pts[0]
	p.add_child(w)
	anim(out, {"t": "walk", "n": w, "pts": pts, "i": 1, "s": speed})

## Gabelstapler, der eine Route fährt.
static func forklift(p: Node3D, pts: Array, out: Dictionary) -> void:
	var n = Node3D.new()
	var y = M.mat(Color(0.95, 0.7, 0.08), 0.3, 0.5)
	M.box(n, Vector3(0.9, 0.5, 1.3), Vector3(0, 0.45, 0), y)
	M.box(n, Vector3(0.85, 0.06, 0.9), Vector3(0, 1.6, -0.15), M.dark())
	for sx in [-0.4, 0.4]:
		M.box(n, Vector3(0.05, 1.2, 0.05), Vector3(sx, 1.05, -0.55), M.dark())
		M.box(n, Vector3(0.05, 1.8, 0.08), Vector3(sx * 0.7, 0.95, 0.72), M.dark())
		M.box(n, Vector3(0.1, 0.05, 0.8), Vector3(sx * 0.5, 0.25, 1.1), M.steel())
		M.cyl(n, 0.2, 0.2, 0.12, Vector3(sx * 1.15, 0.2, 0.35), M.dark(), Vector3(0, 0, PI / 2), 10)
		M.cyl(n, 0.16, 0.16, 0.12, Vector3(sx * 1.15, 0.16, -0.4), M.dark(), Vector3(0, 0, PI / 2), 10)
	M.box(n, Vector3(0.55, 0.45, 0.5), Vector3(0, 0.55, 1.05), M.mat(Color(0.5, 0.38, 0.22), 0, 0.9))
	var drv = worker("west")
	drv.scale = Vector3.ONE * 0.9
	drv.position = Vector3(0, 0.3, -0.1)
	n.add_child(drv)
	M.box(n, Vector3(0.8, 0.6, 0.3), Vector3(0, 0.6, -0.7), M.dark())
	n.position = pts[0]
	p.add_child(n)
	anim(out, {"t": "walk", "n": n, "pts": pts, "i": 1, "s": 2.2, "vehicle": true})

static func lattice_mast(p: Node3D, pos: Vector3, h: float, out: Dictionary) -> void:
	var m = M.mat(Color(0.75, 0.2, 0.15), 0.5, 0.5)
	var w2 = M.mat(Color(0.9, 0.9, 0.88), 0.5, 0.5)
	for cx in [-0.25, 0.25]:
		for cz in [-0.25, 0.25]:
			M.box(p, Vector3(0.05, h, 0.05), pos + Vector3(cx, h * 0.5, cz), m)
	var n = int(h / 0.8)
	for i in n:
		M.box(p, Vector3(0.5, 0.04, 0.5), pos + Vector3(0, (i + 1) * 0.8, 0), m if i % 2 == 0 else w2)
		M.box(p, Vector3(0.68, 0.03, 0.03), pos + Vector3(0, i * 0.8 + 0.4, 0.25), m, Vector3(0, 0, 0.9 if i % 2 == 0 else -0.9))
	blink_light(p, pos + Vector3(0, h + 0.1, 0), Color(1, 0.1, 0.05), out, 1.4)
	blink_light(p, pos + Vector3(0, h * 0.55, 0.3), Color(1, 0.1, 0.05), out, 1.4, 0.7)

# ================================================================ WESTBUND

static func west_hq(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var R = w * 0.42
	var cz = -0.4
	# Sockel und Freitreppe
	M.cyl(r, R + 0.6, R + 0.7, 0.45, Vector3(0, 0.22, cz), M.concrete(), Vector3.ZERO, 8)
	stairs(r, Vector3(0, 0, cz + R + 0.45), 0.0, 3, 2.6, 0.15, 0.3)
	# Etage 1
	M.cyl(r, R, R, 2.3, Vector3(0, 1.6, cz), wl, Vector3.ZERO, 8)
	M.cyl(r, R + 0.02, R + 0.02, 1.1, Vector3(0, 1.75, cz), glass(), Vector3.ZERO, 8)
	for i in 16:
		var a = TAU * i / 16.0
		M.box(r, Vector3(0.06, 1.15, 0.06), Vector3(cos(a) * (R + 0.04), 1.75, cz + sin(a) * (R + 0.04)), M.steel())
	for i in 8:
		var a = TAU * i / 8.0 + TAU / 16.0
		M.box(r, Vector3(0.25, 2.3, 0.25), Vector3(cos(a) * (R + 0.05), 1.6, cz + sin(a) * (R + 0.05)), wl)
	M.cyl(r, R + 0.15, R + 0.15, 0.18, Vector3(0, 2.84, cz), pc, Vector3.ZERO, 8)
	M.cyl(r, R + 0.17, R + 0.17, 0.05, Vector3(0, 2.72, cz), M.glow(Color(0.35, 0.8, 1.0), 3.0), Vector3.ZERO, 8)
	# Terrasse auf Etage 1 mit Geländer, Klimageräten
	for i in 8:
		var a0 = TAU * i / 8.0 + TAU / 16.0
		var a1 = TAU * (i + 1) / 8.0 + TAU / 16.0
		var q0 = Vector3(cos(a0) * R, 2.93, cz + sin(a0) * R)
		var q1 = Vector3(cos(a1) * R, 2.93, cz + sin(a1) * R)
		railing(r, q0, q1, 0.6)
	ac_unit(r, Vector3(-R * 0.62, 2.93, cz - R * 0.45), 0.6, out)
	ac_unit(r, Vector3(R * 0.62, 2.93, cz - R * 0.45), -0.6, out)
	vent(r, Vector3(0, 2.93, cz - R * 0.78), out, 0.8)
	# Etage 2
	var R2 = R * 0.66
	M.cyl(r, R2, R2, 2.0, Vector3(0, 3.95, cz), wl, Vector3.ZERO, 8)
	M.cyl(r, R2 + 0.02, R2 + 0.02, 1.0, Vector3(0, 4.05, cz), glass(), Vector3.ZERO, 8)
	for i in 12:
		var a = TAU * i / 12.0
		M.box(r, Vector3(0.05, 1.05, 0.05), Vector3(cos(a) * (R2 + 0.04), 4.05, cz + sin(a) * (R2 + 0.04)), M.steel())
	M.cyl(r, R2 + 0.2, R2 + 0.2, 0.16, Vector3(0, 5.0, cz), pc, Vector3.ZERO, 8)
	# Dachlandeplatz mit geparktem Hubschrauber und Randbefeuerung
	M.cyl(r, R2 * 0.95, R2 * 0.95, 0.04, Vector3(0, 5.1, cz), M.mat(Color(0.14, 0.15, 0.17), 0.2, 0.7), Vector3.ZERO, 24)
	for i in 10:
		var a = TAU * i / 10.0
		blink_light(r, Vector3(cos(a) * R2 * 0.9, 5.15, cz + sin(a) * R2 * 0.9), Color(0.35, 0.8, 1.0), out, 2.0, i * 0.2)
	var heli = vehicle(r, "heli", Vector3(0, 5.6, cz), 0.8, 0.55)
	heli.position.y = 5.75
	# Radar, Antennenmast
	out["spin"] = load("res://scripts/arch.gd")._dish(r, Vector3(R * 0.75, 2.93, cz + R * 0.35), 0.75)
	M.cyl(r, 0.04, 0.05, 3.2, Vector3(-R2 * 0.7, 6.7, cz - 0.4), M.steel(), Vector3.ZERO, 6)
	for k in 3:
		M.box(r, Vector3(0.5 - k * 0.12, 0.03, 0.03), Vector3(-R2 * 0.7, 5.8 + k * 0.7, cz - 0.4), M.steel())
	blink_light(r, Vector3(-R2 * 0.7, 8.35, cz - 0.4), Color(1, 0.1, 0.05), out, 1.5)
	# Eingang: Glasvordach, Schiebetür, Pflanzkübel, Fahnen
	var ez = cz + R
	M.box(r, Vector3(2.4, 2.0, 0.12), Vector3(0, 1.45, ez + 0.02), M.glow(Color(0.6, 0.85, 1.0), 0.8))
	M.box(r, Vector3(3.6, 0.1, 1.8), Vector3(0, 2.55, ez + 0.8), glass())
	M.box(r, Vector3(3.7, 0.08, 0.08), Vector3(0, 2.6, ez + 1.7), pc)
	for sx in [-1.7, 1.7]:
		M.cyl(r, 0.05, 0.05, 2.1, Vector3(sx, 1.5, ez + 1.6), M.steel(), Vector3.ZERO, 8)
	planter(r, Vector3(-2.6, 0.45, ez + 0.9), 0.55)
	planter(r, Vector3(2.6, 0.45, ez + 0.9), 0.55)
	for k in 3:
		flag(r, Vector3(-1.2 + k * 1.2, 0.0, ez + 2.4), 3.6, M._team if k != 1 else Color(0.9, 0.92, 0.95), out)
	# Fahrzeug, Wachposten, Arbeiter
	vehicle(r, "aa", Vector3(w * 0.36, 0.0, w * 0.32), 2.6, 0.55)
	walker(r, "west", [Vector3(-w * 0.45, 0, w * 0.45), Vector3(w * 0.45, 0, w * 0.45), Vector3(w * 0.45, 0, -w * 0.45), Vector3(-w * 0.45, 0, -w * 0.45)], out, 1.1)
	walker(r, "west", [Vector3(-1.0, 0.45, ez + 0.8), Vector3(1.0, 0.45, ez + 0.8)], out, 0.6)
	out["height"] = 5.4

static func west_factory(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var cz = -w * 0.12
	var L = w * 0.62
	# Gewölbehalle mit Rippen
	M.box(r, Vector3(w * 0.66, 0.8, L), Vector3(-w * 0.1, 0.4, cz), wl)
	var vault = M.cyl(r, w * 0.33, w * 0.33, L, Vector3(-w * 0.1, 0.8, cz), wl, Vector3(PI / 2, 0, 0), 22)
	vault.scale = Vector3(1, 1, 0.7)
	for k in 7:
		M.cyl(r, w * 0.335, w * 0.335, 0.1, Vector3(-w * 0.1, 0.8, cz - L * 0.5 + k * L / 6.0), pc, Vector3(PI / 2, 0, 0), 22).scale = Vector3(1, 1, 0.7)
	# Oberlichtband
	M.box(r, Vector3(0.6, 0.1, L * 0.9), Vector3(-w * 0.1, 0.8 + w * 0.33 * 0.7, cz), glass(), Vector3.ZERO)
	# Rolltor halb offen mit Panzer darin
	var fz = cz + L * 0.5
	M.box(r, Vector3(w * 0.42, 2.8, 0.1), Vector3(-w * 0.1, 1.4, fz - 0.4), M.mat(Color(0.03, 0.03, 0.035), 0, 1))
	M.box(r, Vector3(w * 0.44, 1.2, 0.12), Vector3(-w * 0.1, 2.4, fz + 0.01), M.mat(Color(0.6, 0.62, 0.65), 0.6, 0.4))
	for k in 5:
		M.box(r, Vector3(w * 0.44, 0.03, 0.14), Vector3(-w * 0.1, 1.85 + k * 0.24, fz + 0.02), M.dark())
	M.box(r, Vector3(w * 0.46, 0.08, 0.1), Vector3(-w * 0.1, 3.0, fz + 0.05), M.glow(Color(0.35, 0.8, 1.0), 3.0))
	vehicle(r, "tank", Vector3(-w * 0.1, 0.0, fz - 1.4), 0.0, 0.62)
	for sx in [-1, 1]:
		M.box(r, Vector3(0.15, 0.6, 0.15), Vector3(-w * 0.1 + sx * w * 0.24, 0.3, fz + 0.4), M.mat(Color(0.95, 0.7, 0.08), 0.2, 0.5))
	# Bürotrakt mit Fensterreihen, Tür, Außentreppe
	var ox = w * 0.33
	M.box(r, Vector3(w * 0.28, 3.4, L * 0.7), Vector3(ox, 1.7, cz - L * 0.12), wl)
	M.box(r, Vector3(w * 0.3, 0.14, L * 0.72), Vector3(ox, 3.45, cz - L * 0.12), pc)
	windows(r, Vector3(ox + w * 0.14, 1.2, cz - L * 0.12), Vector3(0, 0, 1), Vector3(1, 0, 0), L * 0.6, 4, 0.5, 0.6)
	windows(r, Vector3(ox + w * 0.14, 2.6, cz - L * 0.12), Vector3(0, 0, 1), Vector3(1, 0, 0), L * 0.6, 4, 0.5, 0.6)
	windows(r, Vector3(ox, 2.6, cz - L * 0.12 + L * 0.35), Vector3(1, 0, 0), Vector3(0, 0, 1), w * 0.22, 2, 0.5, 0.6)
	door(r, Vector3(ox, 0.0, cz - L * 0.12 + L * 0.35), 0.0, 0.9, 1.9)
	ac_unit(r, Vector3(ox - 0.4, 3.52, cz - L * 0.3), 0.0, out)
	vent(r, Vector3(ox + 0.5, 3.52, cz), out, 0.7)
	# Drohnenbucht auf dem Dach, schwebende Drohne
	var dz = cz - L * 0.25
	M.cyl(r, 0.8, 0.8, 0.06, Vector3(-w * 0.1, 0.8 + w * 0.33 * 0.7 + 0.05, dz), M.dark(), Vector3.ZERO, 18)
	for i in 6:
		var a = TAU * i / 6.0
		blink_light(r, Vector3(-w * 0.1 + cos(a) * 0.85, 0.8 + w * 0.33 * 0.7 + 0.1, dz + sin(a) * 0.85), Color(0.35, 0.8, 1.0), out, 1.0, i * 0.16)
	var dr = vehicle(r, "drone", Vector3(-w * 0.1, 0.8 + w * 0.33 * 0.7 + 1.6, dz), 0.0, 0.8)
	anim(out, {"t": "bob", "n": dr, "base": dr.position, "amp": 0.35, "s": 1.6})
	# Rohrleitungen an der Seitenwand
	pipe(r, Vector3(-w * 0.43, 0.5, cz - L * 0.4), Vector3(-w * 0.43, 0.5, cz + L * 0.4), 0.1)
	pipe(r, Vector3(-w * 0.45, 0.85, cz - L * 0.4), Vector3(-w * 0.45, 0.85, cz + L * 0.4), 0.07, M.mat(Color(0.2, 0.5, 0.8), 0.6, 0.4))
	# Portalkran mit fahrender Laufkatze
	for sx in [-1, 1]:
		M.box(r, Vector3(0.22, 4.2, 0.22), Vector3(sx * w * 0.46, 2.1, w * 0.43), M.mat(Color(0.95, 0.95, 0.95), 0.5, 0.4))
	M.box(r, Vector3(w * 0.95, 0.3, 0.4), Vector3(0, 4.2, w * 0.43), M.mat(Color(0.95, 0.95, 0.95), 0.5, 0.4))
	var trolley = M.node(r, Vector3(0, 3.95, w * 0.43))
	M.box(trolley, Vector3(0.6, 0.3, 0.6), Vector3.ZERO, M.dark())
	M.cyl(trolley, 0.015, 0.015, 2.0, Vector3(0, -1.1, 0), M.dark(), Vector3.ZERO, 4)
	M.box(trolley, Vector3(0.8, 0.5, 0.6), Vector3(0, -2.3, 0), M.mat(Color(0.5, 0.38, 0.22), 0, 0.9))
	anim(out, {"t": "slide", "n": trolley, "a": Vector3(-w * 0.38, 3.95, w * 0.43), "b": Vector3(w * 0.38, 3.95, w * 0.43), "s": 0.35})
	# Hof: Paletten, Gabelstapler, Arbeiter
	pallet(r, Vector3(w * 0.36, 0, w * 0.3), 0.2, 6)
	pallet(r, Vector3(w * 0.22, 0, w * 0.36), -0.1, 4)
	forklift(r, [Vector3(w * 0.3, 0, w * 0.15), Vector3(-w * 0.35, 0, w * 0.18), Vector3(-w * 0.35, 0, w * 0.4), Vector3(w * 0.3, 0, w * 0.4)], out)
	walker(r, "west", [Vector3(w * 0.45, 0, -w * 0.45), Vector3(w * 0.45, 0, w * 0.1), Vector3(w * 0.2, 0, w * 0.1)], out, 1.0)
	out["height"] = 4.4

# ================================================================ ROTE ALLIANZ

static func red_hq(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var cz = -0.6
	# Drei Stufen Sichtbeton mit Fensterreihen
	var tiers = [[w * 0.9, 1.9, w * 0.72], [w * 0.68, 1.7, w * 0.55], [w * 0.42, 1.6, w * 0.38]]
	var y = 0.0
	for i in 3:
		var t: Array = tiers[i]
		var tz = cz - i * 0.35
		M.box(r, Vector3(t[0], t[1], t[2]), Vector3(0, y + t[1] * 0.5, tz), wl)
		M.box(r, Vector3(t[0] + 0.15, 0.16, t[2] + 0.15), Vector3(0, y + t[1], tz), pc)
		M.box(r, Vector3(t[0] + 0.06, 0.08, t[2] + 0.06), Vector3(0, y + 0.2, tz), M.dark())
		var n = int(t[0] / 1.0)
		windows(r, Vector3(0, y + t[1] * 0.55, tz + t[2] * 0.5), Vector3(1, 0, 0), Vector3(0, 0, 1), t[0] * 0.86, n, 0.42, 0.62)
		windows(r, Vector3(t[0] * 0.5, y + t[1] * 0.55, tz), Vector3(0, 0, 1), Vector3(1, 0, 0), t[2] * 0.8, int(t[2] / 1.1), 0.42, 0.62)
		windows(r, Vector3(-t[0] * 0.5, y + t[1] * 0.55, tz), Vector3(0, 0, 1), Vector3(-1, 0, 0), t[2] * 0.8, int(t[2] / 1.1), 0.42, 0.62)
		y += t[1]
	# Säulenportikus mit Giebel und großem Stern
	var fz = cz + w * 0.36
	for k in 4:
		M.cyl(r, 0.18, 0.2, 2.6, Vector3(-1.65 + k * 1.1, 1.3, fz + 0.9), M.concrete(), Vector3.ZERO, 12)
	M.box(r, Vector3(4.3, 0.3, 1.4), Vector3(0, 2.7, fz + 0.55), M.concrete())
	load("res://scripts/arch.gd").prism(r, 4.3, 0.9, 1.4, Vector3(0, 2.85, fz + 0.55), pc, Vector3(0, PI / 2, 0)).rotation = Vector3(0, 0, 0)
	M._star(r, Vector3(0, 3.25, fz + 1.27), 0.38, M.glow(Color(1.0, 0.82, 0.15), 2.5))
	M.box(r, Vector3(1.8, 1.9, 0.1), Vector3(0, 0.95, fz + 0.02), M.mat(Color(0.35, 0.12, 0.08), 0.3, 0.6))
	stairs(r, Vector3(0, 0, fz + 1.25), 0.0, 3, 4.6, 0.12, 0.3)
	# Großer Stern an der obersten Stufe
	M._star(r, Vector3(0, y - 0.8, cz - 0.7 + w * 0.19 + 0.02), 0.65, M.glow(Color(1.0, 0.8, 0.15), 2.0))
	# Denkmal auf dem Platz
	var mx = -w * 0.36
	var mz = w * 0.38
	M.box(r, Vector3(1.0, 1.1, 1.0), Vector3(mx, 0.55, mz), M.concrete())
	M.box(r, Vector3(0.8, 0.12, 0.8), Vector3(mx, 1.16, mz), M.mat(Color(0.6, 0.5, 0.25), 0.8, 0.35))
	var st = worker("red")
	st.position = Vector3(mx, 1.2, mz)
	st.scale = Vector3.ONE * 1.4
	_bronze(st)
	r.add_child(st)
	M.box(st, Vector3(0.08, 0.6, 0.08), Vector3(0.25, 1.75, 0.05), M.mat(Color(0.5, 0.35, 0.15), 0.85, 0.35), Vector3(0, 0, -0.5))
	# Dachfahnen, Funkmast, Scheinwerfer, Lautsprecher
	flag(r, Vector3(-w * 0.15, y, cz - 0.7), 2.4, M._team, out)
	flag(r, Vector3(w * 0.15, y, cz - 0.7), 2.4, M._team, out)
	lattice_mast(r, Vector3(w * 0.38, 1.9, cz - w * 0.25), 5.5, out)
	for sx in [-1, 1]:
		var sl = M.node(r, Vector3(sx * w * 0.42, 1.9, cz + w * 0.3))
		M.cyl(sl, 0.2, 0.15, 0.35, Vector3(0, 0.15, 0), M.steel(), Vector3(PI / 2 - 0.5, 0, 0), 10)
		M.cyl(sl, 0.17, 0.17, 0.03, Vector3(0, 0.25, 0.18), M.glow(Color(1, 0.9, 0.7), 8.0), Vector3(PI / 2 - 0.5, 0, 0), 10)
		anim(out, {"t": "sweep", "n": sl, "s": 0.5 + sx * 0.1, "amp": 0.9})
	# Lkw und marschierende Soldaten im Gleichschritt
	vehicle(r, "truck", Vector3(w * 0.38, 0, w * 0.36), PI * 0.5, 0.6)
	for k in 2:
		walker(r, "red", [Vector3(-w * 0.15 + k * 0.6, 0, w * 0.46), Vector3(w * 0.25 + k * 0.6, 0, w * 0.46)], out, 1.0)
	out["height"] = y + 0.2

static func _bronze(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = M.mat(Color(0.45, 0.32, 0.16), 0.85, 0.35)
	for c in n.get_children():
		_bronze(c)

static func red_factory(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var cz = -w * 0.1
	var L = w * 0.66
	var H = 3.6
	M.box(r, Vector3(w * 0.88, H, L), Vector3(0, H * 0.5, cz), wl)
	# Sheddach mit Glasflächen
	var P = load("res://scripts/arch.gd")
	for k in 5:
		var z = cz - L * 0.5 + 0.45 + k * L / 5.0
		P.prism(r, 0.9, 0.85, w * 0.86, Vector3(0, H, z), pc, Vector3(0, PI / 2, 0))
		M.box(r, Vector3(w * 0.84, 0.75, 0.05), Vector3(0, H + 0.38, z + 0.42), glass(), Vector3(-0.15, 0, 0))
	# Pilaster und Fensterbänder seitlich
	for sx in [-1, 1]:
		for k in 5:
			M.box(r, Vector3(0.25, H, 0.3), Vector3(sx * w * 0.44, H * 0.5, cz - L * 0.4 + k * L * 0.2), M.concrete())
		windows(r, Vector3(sx * w * 0.44, 2.5, cz), Vector3(0, 0, 1), Vector3(sx, 0, 0), L * 0.8, 4, 0.9, 0.7)
	# Rolltor halb oben, Panzer fährt heraus
	var fz = cz + L * 0.5
	M.box(r, Vector3(w * 0.5, 3.0, 0.1), Vector3(0, 1.5, fz - 0.3), M.mat(Color(0.03, 0.03, 0.03), 0, 1))
	for k in 6:
		M.box(r, Vector3(w * 0.52, 0.2, 0.14), Vector3(0, 2.0 + k * 0.17, fz + 0.02), M.steel() if k % 2 == 0 else M.dark())
	M.box(r, Vector3(w * 0.56, 0.4, 0.3), Vector3(0, 3.2, fz + 0.1), M.concrete())
	M._star(r, Vector3(0, 3.2, fz + 0.27), 0.3, M.glow(Color(1, 0.82, 0.15), 2.0))
	vehicle(r, "tank", Vector3(0, 0, fz + 0.6), 0.0, 0.6)
	# Zwei Schlote mit Steigleitern und Ringen
	for sx in [-1, 1]:
		var cx = sx * w * 0.32
		var ccz = cz - L * 0.42
		M.cyl(r, 0.42, 0.58, 7.5, Vector3(cx, 3.75, ccz), M.mat(Color(0.42, 0.22, 0.16), 0, 0.9), Vector3.ZERO, 12)
		for k in 3:
			M.cyl(r, 0.5 - k * 0.03, 0.5 - k * 0.03, 0.25, Vector3(cx, 4.5 + k * 1.1, ccz), M.mat(Color(0.9, 0.9, 0.88), 0, 0.7) if k % 2 == 0 else M.mat(Color(0.75, 0.12, 0.08), 0, 0.7), Vector3.ZERO, 12)
		for k in 14:
			M.box(r, Vector3(0.3, 0.03, 0.03), Vector3(cx, 0.6 + k * 0.5, ccz + 0.6), M.steel())
		blink_light(r, Vector3(cx, 7.55, ccz), Color(1, 0.1, 0.05), out, 1.6, sx * 0.4)
	out["smoke"] = [Vector3(-w * 0.32, 7.6, cz - L * 0.42), Vector3(w * 0.32, 7.6, cz - L * 0.42)]
	# Silo mit Rohrbrücke
	var sp = Vector3(-w * 0.36, 0, w * 0.32)
	M.cyl(r, 0.9, 0.9, 3.6, sp + Vector3(0, 1.8, 0), M.steel(), Vector3.ZERO, 16)
	M.cyl(r, 0.9, 0.2, 0.7, sp + Vector3(0, 3.95, 0), M.steel(), Vector3.ZERO, 16)
	pipe(r, sp + Vector3(0, 3.4, -0.8), Vector3(-w * 0.36, 3.4, fz - 0.2), 0.12, M.mat(Color(0.6, 0.15, 0.1), 0.5, 0.6))
	# Gleis mit Flachwagen
	for k in 9:
		M.box(r, Vector3(1.6, 0.08, 0.2), Vector3(w * 0.36, 0.04, -w * 0.4 + k * 0.6), M.mat(Color(0.3, 0.22, 0.14), 0, 0.95))
	for sx in [-0.5, 0.5]:
		M.box(r, Vector3(0.07, 0.1, 5.2), Vector3(w * 0.36 + sx, 0.12, -w * 0.4 + 2.4), M.steel())
	var car = M.node(r, Vector3(w * 0.36, 0.3, -w * 0.1))
	M.box(car, Vector3(1.5, 0.2, 2.6), Vector3.ZERO, M.dark())
	M.box(car, Vector3(1.2, 0.6, 1.4), Vector3(0, 0.4, 0), pc)
	M.cyl(car, 0.07, 0.07, 1.8, Vector3(0, 0.55, 1.2), M.steel(), Vector3(PI / 2, 0, 0), 8)
	# Arbeiter und Gabelstapler
	forklift(r, [Vector3(-w * 0.2, 0, w * 0.42), Vector3(w * 0.2, 0, w * 0.42), Vector3(w * 0.2, 0, w * 0.3)], out)
	walker(r, "red", [Vector3(w * 0.25, 0, -w * 0.46), Vector3(-w * 0.25, 0, -w * 0.46)], out, 0.9)
	barrels(r, Vector3(-w * 0.46, 0, -w * 0.05), 5, Color(0.3, 0.32, 0.25))
	out["height"] = H + 1.0

# ================================================================ SCHATTENFRONT

static func shadow_hq(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var rock = M.mat(Color(0.42, 0.38, 0.32), 0.0, 0.95)
	var a = M.sph(r, w * 0.4, Vector3(-w * 0.06, 0.0, -w * 0.15), rock, Vector3(1.15, 0.72, 0.9), true)
	a.rotation.y = 0.3
	M.sph(r, w * 0.24, Vector3(w * 0.28, 0.0, -w * 0.3), rock, Vector3(1, 0.95, 1), true)
	M.sph(r, w * 0.18, Vector3(-w * 0.38, 0.0, 0.0), rock, Vector3(1, 0.7, 1.1), true)
	for i in 6:
		var q = Vector3(cos(i * 1.7) * w * 0.3, 0, -w * 0.15 + sin(i * 1.3) * w * 0.25)
		M.sph(r, 0.4 + (i % 3) * 0.15, q + Vector3(0, 0.1, 0), rock, Vector3(1.2, 0.7, 1))
	# Tunneleingang mit Holzrahmen, Laterne
	var tz = w * 0.22
	M.box(r, Vector3(2.4, 2.1, 1.8), Vector3(0, 1.05, tz), M.mat(Color(0.02, 0.02, 0.02), 0, 1))
	var wood = M.mat(Color(0.35, 0.24, 0.13), 0.0, 0.9)
	for sx in [-1.3, 1.3]:
		M.box(r, Vector3(0.25, 2.3, 0.25), Vector3(sx, 1.15, tz + 0.9), wood)
	M.box(r, Vector3(3.0, 0.3, 0.3), Vector3(0, 2.35, tz + 0.9), wood)
	M.box(r, Vector3(0.18, 0.25, 0.18), Vector3(1.0, 2.0, tz + 1.1), M.glow(Color(1.0, 0.65, 0.25), 6.0))
	# Tarnnetze auf Stangen
	for k in 3:
		var nz = -w * 0.05 + k * 0.4
		M.box(r, Vector3(w * 0.35, 0.05, w * 0.3), Vector3(-w * 0.2 + k * w * 0.2, w * 0.3 - k * 0.2, nz), pc if k % 2 == 0 else M.mat(Color(0.3, 0.32, 0.2), 0, 0.95), Vector3(0.15 * (k - 1), 0.4 * k, 0.1))
	# Holzwachturm mit Leiter und Wachposten
	var wx = w * 0.38
	var wz = w * 0.2
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			M.box(r, Vector3(0.14, 3.8, 0.14), Vector3(wx + sx, 1.9, wz + sz), wood, Vector3(sz * 0.08, 0, -sx * 0.08))
	M.box(r, Vector3(1.4, 0.12, 1.4), Vector3(wx, 3.7, wz), wood)
	for sx in [-0.65, 0.65]:
		M.box(r, Vector3(0.08, 0.55, 1.4), Vector3(wx + sx, 4.0, wz), wood)
	load("res://scripts/arch.gd").prism(r, 1.8, 0.7, 1.8, Vector3(wx, 4.7, wz), pc)
	for k in 7:
		M.box(r, Vector3(0.5, 0.04, 0.04), Vector3(wx, 0.4 + k * 0.5, wz + 0.75), wood)
	var guard = worker("shadow")
	guard.position = Vector3(wx, 3.76, wz)
	r.add_child(guard)
	anim(out, {"t": "sweep", "n": guard, "s": 0.4, "amp": 1.4})
	# Generator mit Lichterkette, Zelte, Feuer, Pickup, Ziege
	M.box(r, Vector3(0.9, 0.7, 0.6), Vector3(-w * 0.4, 0.35, w * 0.35), M.mat(Color(0.3, 0.4, 0.25), 0.4, 0.7))
	for i in 9:
		var x = -w * 0.4 + i * 0.7
		blink_light(r, Vector3(x, 2.2 + sin(i * 0.9) * 0.1, w * 0.4), [Color(1, 0.3, 0.2), Color(1, 0.85, 0.2), Color(0.3, 1, 0.4)][i % 3], out, 3.0, i * 0.3)
	load("res://scripts/arch.gd").prism(r, 2.0, 1.6, 2.4, Vector3(-w * 0.32, 0, w * 0.05), M.mat(Color(0.45, 0.4, 0.28), 0, 0.95), Vector3(0, 0.3, 0))
	M.sph(r, 0.18, Vector3(-w * 0.12, 0.15, w * 0.42), M.glow(Color(1.0, 0.45, 0.1), 5.0))
	vehicle(r, "technical", Vector3(w * 0.1, 0, w * 0.44), PI * 0.6, 0.6)
	_goat(r, Vector3(-w * 0.2, 0, w * 0.3), out)
	walker(r, "shadow", [Vector3(-1.0, 0, tz + 1.4), Vector3(-w * 0.3, 0, w * 0.4), Vector3(w * 0.2, 0, w * 0.35)], out, 0.8)
	out["height"] = w * 0.34

static func _goat(r: Node3D, pos: Vector3, out: Dictionary) -> void:
	var g = Node3D.new()
	var fur = M.mat(Color(0.85, 0.82, 0.75), 0, 0.95)
	M.box(g, Vector3(0.3, 0.3, 0.6), Vector3(0, 0.5, 0), fur)
	M.box(g, Vector3(0.18, 0.2, 0.28), Vector3(0, 0.72, 0.36), fur, Vector3(0.4, 0, 0))
	for sx in [-0.08, 0.08]:
		M.box(g, Vector3(0.03, 0.18, 0.03), Vector3(sx, 0.9, 0.3), M.dark(), Vector3(-0.6, 0, 0))
		for sz in [-0.22, 0.22]:
			M.box(g, Vector3(0.06, 0.38, 0.06), Vector3(sx * 1.4, 0.19, sz), M.mat(Color(0.3, 0.25, 0.2), 0, 0.9))
	g.position = pos
	r.add_child(g)
	anim(out, {"t": "walk", "n": g, "pts": [pos, pos + Vector3(1.8, 0, -0.6), pos + Vector3(0.6, 0, 1.0)], "i": 1, "s": 0.35})

static func shadow_factory(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var P = load("res://scripts/arch.gd")
	var cx = -w * 0.18
	var cz = -w * 0.18
	# Wellblechschuppen auf Holzpfosten
	M.box(r, Vector3(w * 0.55, 2.6, w * 0.5), Vector3(cx, 1.3, cz), wl)
	var tin = M.mat(Color(0.48, 0.45, 0.4), 0.65, 0.55)
	var rust = M.mat(Color(0.42, 0.22, 0.1), 0.4, 0.8)
	for k in 10:
		M.box(r, Vector3(w * 0.058, 0.05, w * 0.56), Vector3(cx - w * 0.28 + k * w * 0.058 + 0.15, 2.72 + (k % 2) * 0.05, cz), tin if k % 3 != 1 else rust, Vector3(0.1, 0, 0))
	M.box(r, Vector3(w * 0.32, 2.2, 0.08), Vector3(cx, 1.1, cz + w * 0.25 + 0.01), M.mat(Color(0.02, 0.02, 0.02), 0, 1))
	# Halbfertiger Buggy auf Böcken mit Schweißer
	var bg = vehicle(r, "buggy", Vector3(cx, 0.5, cz + w * 0.33), 0.4, 0.6)
	for sx in [-0.45, 0.45]:
		M.box(r, Vector3(0.18, 0.5, 0.18), Vector3(cx + sx, 0.25, cz + w * 0.33), M.dark())
	var welder = worker("shadow")
	welder.position = Vector3(cx + 1.1, 0, cz + w * 0.33)
	welder.rotation.y = -PI / 2
	r.add_child(welder)
	var spark = M.sph(r, 0.05, Vector3(cx + 0.7, 0.9, cz + w * 0.33), M.glow(Color(0.7, 0.85, 1.0), 12.0))
	anim(out, {"t": "blink", "n": spark, "p": 0.25, "o": 0.0})
	anim(out, {"t": "weld", "n": spark, "p": 0.6})
	# Schrottberge
	P._wreck(r, Vector3(w * 0.28, 0, -w * 0.3), Vector3(0.1, 0.6, 0.15))
	P._wreck(r, Vector3(w * 0.32, 0.6, -w * 0.25), Vector3(-0.2, 1.8, 0.4))
	P._wreck(r, Vector3(w * 0.18, 0, -w * 0.42), Vector3(0.3, 2.2, -0.1))
	for i in 8:
		M.box(r, Vector3(0.4 + (i % 3) * 0.2, 0.15, 0.6), Vector3(w * 0.3 + cos(i) * 1.2, 0.1 + (i % 2) * 0.15, -w * 0.32 + sin(i) * 1.0), rust, Vector3(i * 0.3, i * 0.7, i * 0.2))
	# Schrottkran mit schwingendem Magneten
	var kx = w * 0.4
	var kz = w * 0.15
	M.box(r, Vector3(0.35, 4.6, 0.35), Vector3(kx, 2.3, kz), rust)
	M.box(r, Vector3(0.6, 0.6, 0.6), Vector3(kx, 0.3, kz), M.dark())
	var arm = M.node(r, Vector3(kx, 4.6, kz))
	M.box(arm, Vector3(4.0, 0.25, 0.25), Vector3(-1.6, 0, 0), rust, Vector3(0, 0, -0.08))
	M.box(arm, Vector3(0.8, 0.6, 0.6), Vector3(0.6, -0.1, 0), M.concrete())
	var hook = M.node(arm, Vector3(-3.4, -0.2, 0))
	M.cyl(hook, 0.015, 0.015, 1.8, Vector3(0, -0.9, 0), M.dark(), Vector3.ZERO, 4)
	M.cyl(hook, 0.45, 0.45, 0.2, Vector3(0, -1.9, 0), M.dark(), Vector3.ZERO, 12)
	anim(out, {"t": "sweep", "n": arm, "s": 0.25, "amp": 0.7})
	anim(out, {"t": "swing", "n": hook, "s": 1.3, "amp": 0.15})
	# Schrottpresse mit Stempel
	var px = -w * 0.4
	var pz = w * 0.3
	M.box(r, Vector3(1.4, 0.8, 1.4), Vector3(px, 0.4, pz), M.dark())
	for sx in [-0.6, 0.6]:
		M.box(r, Vector3(0.15, 2.4, 0.15), Vector3(px + sx, 1.2, pz), rust)
	M.box(r, Vector3(1.4, 0.2, 0.3), Vector3(px, 2.4, pz), rust)
	var ram = M.node(r, Vector3(px, 1.6, pz))
	M.box(ram, Vector3(1.1, 0.25, 1.1), Vector3.ZERO, M.steel())
	anim(out, {"t": "slide", "n": ram, "a": Vector3(px, 1.0, pz), "b": Vector3(px, 2.1, pz), "s": 0.6})
	# Reifen, Fässer, Arbeiter
	for i in 4:
		M._tire(r, Vector3(-w * 0.42, 0.15 + i * 0.28, -w * 0.05))
	barrels(r, Vector3(w * 0.05, 0, w * 0.38), 4, Color(0.25, 0.3, 0.38))
	walker(r, "shadow", [Vector3(w * 0.1, 0, w * 0.1), Vector3(w * 0.3, 0, w * 0.4), Vector3(-w * 0.2, 0, w * 0.45)], out, 0.9)
	out["height"] = 3.4
