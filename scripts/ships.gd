extends RefCounted
## Schiffe und Werften der drei Fraktionen. Vorwaerts = +Z, Wasserlinie = y 0.
##   Westbund      – schlanke helle Rümpfe, Glasbrücken, Radar, Leuchtstreifen, Senkrechtstarter
##   Rote Allianz  – Stahlkoloss: eckige Aufbauten, Schornsteine, Doppelgeschütze, Sterne, Nieten
##   Schattenfront – Schrottschiffe: Containerstapel, Autoreifen als Fender, Flicken, Totenkopfflagge
## Kleinteile (Reling, Bullaugen, Nieten, Poller) werden je Material zu einem Netz gebündelt.

const M = preload("res://scripts/models.gd")
const D = preload("res://scripts/arch_detail.gd")

# ---------------------------------------------------------------- Rumpf

static func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)

static func _prof(t: float, sharp: float) -> float:
	var p = 1.0
	if t > 0.5:
		p = 1.0 - pow((t - 0.5) / 0.5, 1.7) * sharp
	return p * (0.88 + 0.12 * smoothstep(0.0, 0.3, t))

static func _hwd(length: float, beam: float, t: float, sharp: float) -> float:
	return beam * 0.5 * _prof(t, sharp)

static func _deck_y(deck: float, t: float) -> float:
	return deck + 0.55 * pow(t, 3.0)

## Gelofteter Schiffsrumpf: spitzer Bug, Sprung nach vorn, Spiegelheck.
## Fläche 0 = Seiten und Boden, 1 = Deck, 2 = farbiges Band an der Wasserlinie.
static func hull(r: Node3D, length: float, beam: float, deck: float, keel: float, side: Material, deck_m: Material, sharp := 0.9, band: Material = null) -> void:
	var n = 16
	var tops: Array = []
	var bots: Array = []
	for i in n + 1:
		var t = float(i) / n
		var z = -length * 0.5 + t * length
		var hw = _hwd(length, beam, t, sharp)
		var top = _deck_y(deck, t)
		var bot = -keel * (1.0 - 0.45 * pow(t, 4.0))
		tops.append([Vector3(-hw, top, z), Vector3(hw, top, z)])
		bots.append([Vector3(-hw * 0.5, bot, z), Vector3(hw * 0.5, bot, z)])
	var s0 = SurfaceTool.new()
	s0.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s1 = SurfaceTool.new()
	s1.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s2 = SurfaceTool.new()
	s2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a = tops[i]
		var b = tops[i + 1]
		var c = bots[i]
		var d = bots[i + 1]
		_q(s0, b[1], a[1], c[1], d[1])
		_q(s0, a[0], b[0], d[0], c[0])
		_q(s0, d[0], d[1], c[1], c[0])
		_q(s1, a[0], a[1], b[1], b[0])
		if band != null:
			var xa = _side_x(a, c, -0.12, 0.26)
			var xb = _side_x(b, d, -0.12, 0.26)
			var z0: float = a[1].z
			var z1: float = b[1].z
			_q(s2, Vector3(xb[1], 0.26, z1), Vector3(xa[1], 0.26, z0), Vector3(xa[0], -0.12, z0), Vector3(xb[0], -0.12, z1))
			_q(s2, Vector3(-xa[1], 0.26, z0), Vector3(-xb[1], 0.26, z1), Vector3(-xb[0], -0.12, z1), Vector3(-xa[0], -0.12, z0))
	_q(s0, tops[0][1], tops[0][0], bots[0][0], bots[0][1])
	_q(s0, tops[n][0], tops[n][1], bots[n][1], bots[n][0])
	s0.generate_normals()
	s1.generate_normals()
	var am = ArrayMesh.new()
	s0.commit(am)
	s1.commit(am)
	if band != null:
		s2.generate_normals()
		s2.commit(am)
	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.set_surface_override_material(0, side)
	mi.set_surface_override_material(1, deck_m)
	if band != null:
		mi.set_surface_override_material(2, band)
	r.add_child(mi)

## x der rechten Bordwand auf zwei Höhen (leicht nach außen versetzt).
static func _side_x(top: Array, bot: Array, y0: float, y1: float) -> Array:
	var ht: float = top[1].y
	var hb: float = bot[1].y
	var out = []
	for y in [y0, y1]:
		var f = clamp((y - hb) / (ht - hb), 0.0, 1.0)
		out.append(lerp(bot[1].x, top[1].x, f) + 0.012)
	return out

# ---------------------------------------------------------------- Kleinteile

## Reling, Bullaugen, Nieten und Poller – alles gebündelt.
static func _fit(r: Node3D, L: float, beam: float, deck: float, sharp: float, o: Dictionary) -> void:
	M._bt.clear()
	var steel = M.steel()
	var dark = M.dark()
	var ports = o.get("ports", null)
	var pm: Material = M.glow(ports, 2.2) if ports != null else dark
	for sd in [-1.0, 1.0]:
		var prev = null
		var z = -L * 0.40
		while z <= L * 0.38:
			var t = (z + L * 0.5) / L
			var hw = _hwd(L, beam, t, sharp) * 0.93
			var y = _deck_y(deck, t)
			var p = Vector3(sd * hw, y, z)
			M._bb(Vector3(0.025, 0.36, 0.025), p + Vector3(0, 0.18, 0), steel)
			if prev != null:
				for hh in [0.34, 0.17]:
					var a: Vector3 = prev + Vector3(0, hh, 0)
					var b: Vector3 = p + Vector3(0, hh, 0)
					var dv = b - a
					M._bb(Vector3(0.02, 0.02, Vector3(dv.x, 0, dv.z).length()), (a + b) * 0.5, steel, Vector3(0, atan2(dv.x, dv.z), 0))
			prev = p
			z += 0.8
		# Bullaugen auf halber Rumpfhöhe
		var zz = -L * 0.36
		while zz <= L * 0.28:
			var t2 = (zz + L * 0.5) / L
			var hw2 = _hwd(L, beam, t2, sharp)
			var py = deck * 0.6
			M._bs(0.07, Vector3(sd * (hw2 * 0.84 + 0.03), py, zz), pm)
			if o.get("rivets", false):
				for k in 2:
					M._bs(0.028, Vector3(sd * (hw2 * 0.9 + 0.012), deck * 0.85, zz + 0.25 + k * 0.28), steel)
			zz += 0.95
		# Poller
		for pz in [-L * 0.42, L * 0.33]:
			var tp = (pz + L * 0.5) / L
			var hp = _hwd(L, beam, tp, sharp) * 0.8
			M._bc(0.09, 0.11, 0.24, Vector3(sd * hp, _deck_y(deck, tp) + 0.12, pz), dark, Vector3.ZERO, 8)
	# Anker am Bug
	var tb = 0.93
	M._bb(Vector3(0.1, 0.34, 0.18), Vector3(0.0, _deck_y(deck, tb) + 0.17, L * 0.43), steel)
	M._bc(0.05, 0.05, 0.5, Vector3(0.0, _deck_y(deck, tb) + 0.1, L * 0.4), dark, Vector3(PI / 2, 0, 0), 6)
	M._flush(r)

static func _team_mat() -> Material:
	return M.mat(M._team, 0.2, 0.55)

## Drehendes Radar.
static func _radar(r: Node3D, pos: Vector3, s: float, out: Dictionary) -> void:
	var n = M.node(r, pos)
	M.cyl(n, 0.05, 0.07, 0.25 * s, Vector3(0, 0.12 * s, 0), M.steel(), Vector3.ZERO, 6)
	M.box(n, Vector3(1.1 * s, 0.14 * s, 0.05), Vector3(0, 0.3 * s, 0), M.dark())
	M.box(n, Vector3(1.0 * s, 0.05, 0.09), Vector3(0, 0.38 * s, 0.0), M.steel())
	D.anim(out, {"t": "spin", "n": n, "s": 2.2})

## Besatzungsmitglied: bleibt stehen und schaut sich um.
static func _crew(r: Node3D, faction: String, pos: Vector3, yaw: float, out: Dictionary, k := 0) -> void:
	var w = D.worker(faction)
	w.scale = Vector3.ONE * 0.62
	w.position = pos
	w.rotation.y = yaw
	r.add_child(w)
	D.anim(out, {"t": "sway", "n": w, "b": yaw, "o": k * 1.7})

static func _lifeboat(r: Node3D, pos: Vector3, col: Color, side: float) -> void:
	var hm = M.mat(col, 0.1, 0.6)
	var boat = M.sph(r, 0.5, pos + Vector3(0, 0.0, 0), hm, Vector3(0.9, 0.55, 2.4))
	M.box(r, Vector3(0.7, 0.05, 1.7), pos + Vector3(0, 0.22, 0), M.mat(Color(0.9, 0.85, 0.7), 0.0, 0.8))
	for dz in [-0.6, 0.6]:
		M.box(r, Vector3(0.05, 0.9, 0.05), pos + Vector3(side * 0.35, 0.15, dz), M.steel())
		M.box(r, Vector3(0.4, 0.05, 0.05), pos + Vector3(side * 0.17, 0.62, dz), M.steel())

static func _deckbox(r: Node3D, pos: Vector3, rot: float, col: Color) -> void:
	var b = M.box(r, Vector3(0.45, 0.34, 0.45), pos + Vector3(0, 0.17, 0), M.mat(col, 0.2, 0.7))
	b.rotation.y = rot
	M.cyl(r, 0.12, 0.12, 0.05, pos + Vector3(0, 0.36, 0), M.dark(), Vector3.ZERO, 8)

static func _hatch(r: Node3D, pos: Vector3, rr := 0.3) -> void:
	M.cyl(r, rr, rr, 0.06, pos + Vector3(0, 0.03, 0), M.steel(), Vector3.ZERO, 10)
	M.box(r, Vector3(rr * 1.4, 0.04, 0.05), pos + Vector3(0, 0.08, 0), M.dark())

static func _vent(r: Node3D, pos: Vector3) -> void:
	M.cyl(r, 0.1, 0.1, 0.4, pos + Vector3(0, 0.2, 0), M.dark(), Vector3.ZERO, 8)
	M.sph(r, 0.17, pos + Vector3(0, 0.45, 0), M.dark(), Vector3(1, 0.6, 1), true)

static func _navlights(r: Node3D, x: float, y: float, z: float) -> void:
	M.sph(r, 0.07, Vector3(x, y, z), M.glow(Color(0.1, 1.0, 0.3), 6.0))
	M.sph(r, 0.07, Vector3(-x, y, z), M.glow(Color(1.0, 0.1, 0.1), 6.0))

static func _smoke(r: Node3D, pos: Vector3) -> void:
	load("res://scripts/fx.gd").smoke_column(r, pos, true, false)

# ---------------------------------------------------------------- Einheiten

static func build(r: Node3D, model: String, faction: String, pc: Material, out: Dictionary) -> void:
	match model:
		"corvette": _corvette(r, pc, out)
		"cruiser": _cruiser(r, pc, out)
		"gunboat": _gunboat(r, pc, out)
		"battleship": _battleship(r, pc, out)
		"skiff": _skiff(r, pc, out)
		"frigate": _frigate(r, pc, out)
	out["height"] = 3.0

## Animationen (Radar, Fahnen, Besatzung) für Einheiten; Gebäude haben ihr eigenes Gegenstück.
static func play(anims: Array, delta: float, t: float) -> void:
	for a in anims:
		match a["t"]:
			"spin":
				a["n"].rotation.y += delta * a["s"]
			"blink":
				a["n"].visible = fmod(t + a["o"], a["p"]) < a["p"] * 0.5
			"wave":
				var i = 0
				for s in a["segs"]:
					s.rotation.y = sin(t * 3.0 + a["o"] + i * 0.9) * (0.15 + i * 0.08) + (0.6 if i == 0 else 0.0)
					i += 1
			"sway":
				a["n"].rotation.y = a["b"] + sin(t * 0.6 + a["o"]) * 0.7

static func _corvette(r: Node3D, pc: Material, out: Dictionary) -> void:
	var white = M.mat(Color(0.8, 0.84, 0.88), 0.5, 0.35)
	hull(r, 9.6, 2.7, 1.0, 0.85, white, M.mat(Color(0.2, 0.22, 0.25), 0.3, 0.7), 0.88, _team_mat())
	M.box(r, Vector3(0.04, 0.06, 6.0), Vector3(1.28, 0.55, 0.0), M.glow(Color(0.4, 0.85, 1.0), 3.0))
	M.box(r, Vector3(0.04, 0.06, 6.0), Vector3(-1.28, 0.55, 0.0), M.glow(Color(0.4, 0.85, 1.0), 3.0))
	_fit(r, 9.6, 2.7, 1.0, 0.88, {"ports": Color(0.7, 0.92, 1.0)})
	# Glasbrücke mit Dachkante, Rahmen und Antennen
	M.box(r, Vector3(1.8, 0.7, 2.4), Vector3(0, 1.4, -1.0), white)
	M.box(r, Vector3(1.72, 0.42, 2.0), Vector3(0, 1.58, -0.9), M.glass())
	for k in 4:
		M.box(r, Vector3(0.05, 0.5, 0.05), Vector3(-0.8 + k * 0.53, 1.58, 0.1), white)
	M.box(r, Vector3(1.4, 0.2, 2.1), Vector3(0, 1.9, -1.0), pc)
	_radar(r, Vector3(0, 2.0, -1.5), 1.0, out)
	D.flag(r, Vector3(0, 2.0, -0.2), 1.6, M._team, out)
	_navlights(r, 0.85, 1.7, 0.18)
	for sx in [-1.0, 1.0]:
		M.cyl(r, 0.03, 0.03, 0.8, Vector3(sx * 0.6, 2.4, -1.9), M.dark(), Vector3.ZERO, 4)
	# Schildgenerator am Heck mit Ringen
	M.sph(r, 0.32, Vector3(0, 1.3, -3.6), M.glow(Color(0.4, 0.9, 1.0), 4.0))
	for k in 2:
		M.cyl(r, 0.4 + k * 0.1, 0.4 + k * 0.1, 0.03, Vector3(0, 1.05 + k * 0.15, -3.6), M.glow(Color(0.4, 0.9, 1.0), 2.0), Vector3.ZERO, 14)
	M.cyl(r, 0.12, 0.2, 0.4, Vector3(0, 1.0, -3.6), M.steel(), Vector3.ZERO, 8)
	# Rettungsinsel, Kisten, Lüfter
	M.cyl(r, 0.28, 0.28, 0.5, Vector3(0.7, 1.35, -2.8), M.mat(Color(1.0, 0.5, 0.1), 0.0, 0.7), Vector3(0, 0, PI / 2), 10)
	_deckbox(r, Vector3(-0.7, 1.0, -2.9), 0.3, Color(0.55, 0.6, 0.65))
	_vent(r, Vector3(-0.6, 1.0, 0.9))
	_crew(r, "west", Vector3(0.55, 1.0, 1.0), 0.4, out, 1)
	_crew(r, "west", Vector3(-0.4, 1.0, -2.2), 2.6, out, 2)
	# Raketenwerfer vorn, mit Abdeckung und Zielleuchte
	var t = M.node(r, Vector3(0, 1.1, 2.6))
	M.cyl(t, 0.5, 0.55, 0.35, Vector3(0, 0.1, 0), pc, Vector3.ZERO, 12)
	M.sph(t, 0.06, Vector3(0.45, 0.35, -0.2), M.glow(Color(1.0, 0.3, 0.2), 6.0))
	var br = M.node(t, Vector3(0, 0.45, 0))
	for sx in [-0.28, 0.28]:
		M.box(br, Vector3(0.42, 0.4, 1.5), Vector3(sx, 0, 0.5), M.dark(), Vector3(-0.35, 0, 0))
		M.box(br, Vector3(0.46, 0.05, 1.4), Vector3(sx, 0.22, 0.45), white, Vector3(-0.35, 0, 0))
		M.cyl(br, 0.12, 0.12, 0.05, Vector3(sx, 0.2, 1.25), M.glow(Color(0.5, 0.9, 1.0), 2.0), Vector3(-0.35 + PI / 2, 0, 0), 8)
	out["turret"] = t
	out["barrel"] = br
	out["muzzle"] = Vector3(0, 0.75, 1.5)

static func _cruiser(r: Node3D, pc: Material, out: Dictionary) -> void:
	var white = M.mat(Color(0.78, 0.82, 0.87), 0.5, 0.35)
	hull(r, 14.0, 3.9, 1.1, 0.95, white, M.mat(Color(0.19, 0.21, 0.24), 0.3, 0.7), 0.86, _team_mat())
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.04, 0.06, 10.0), Vector3(sx * 1.9, 0.6, 0.0), M.glow(Color(0.4, 0.85, 1.0), 3.0))
	_fit(r, 14.0, 3.9, 1.1, 0.86, {"ports": Color(0.7, 0.92, 1.0)})
	# Senkrechtstarter-Felder auf dem Vordeck mit Rahmen
	M.box(r, Vector3(2.4, 0.05, 3.9), Vector3(0, 1.15, 3.3), M.dark())
	for gx in 3:
		for gz in 5:
			M.box(r, Vector3(0.5, 0.06, 0.5), Vector3(-0.7 + gx * 0.7, 1.19 + 0.02 * gz, 2.0 + gz * 0.65), M.steel())
			M.sph(r, 0.05, Vector3(-0.7 + gx * 0.7, 1.25 + 0.02 * gz, 2.0 + gz * 0.65), M.glow(Color(0.4, 0.9, 1.0), 3.0))
	# Brückenturm in Stufen, Fensterbänder, Radar
	M.box(r, Vector3(2.4, 1.0, 3.0), Vector3(0, 1.7, -1.4), white)
	M.box(r, Vector3(2.2, 0.5, 2.7), Vector3(0, 2.35, -1.3), M.glass())
	for k in 6:
		M.box(r, Vector3(0.05, 0.55, 2.74), Vector3(-1.0 + k * 0.4, 2.35, -1.3), white)
	M.box(r, Vector3(1.9, 0.9, 1.8), Vector3(0, 2.9, -1.4), white)
	M.box(r, Vector3(1.8, 0.4, 1.5), Vector3(0, 3.0, -1.3), M.glass())
	M.box(r, Vector3(2.0, 0.14, 2.0), Vector3(0, 3.42, -1.4), pc)
	_radar(r, Vector3(0, 3.5, -1.9), 1.5, out)
	M.cyl(r, 0.1, 0.12, 1.8, Vector3(0, 4.3, -0.9), M.steel(), Vector3.ZERO, 6)
	M.sph(r, 0.35, Vector3(0, 5.2, -0.9), M.mat(Color(0.93, 0.95, 0.97), 0.2, 0.35), Vector3(1, 0.8, 1), true)
	D.flag(r, Vector3(0, 3.5, -0.4), 2.6, M._team, out)
	_navlights(r, 1.2, 2.5, -0.1)
	# Hubschrauberdeck achtern mit Hangar, Ringen und Windsack
	M.cyl(r, 1.5, 1.5, 0.05, Vector3(0, 1.17, -5.0), M.mat(Color(0.2, 0.22, 0.26), 0.2, 0.7), Vector3.ZERO, 24)
	M.cyl(r, 1.25, 1.25, 0.06, Vector3(0, 1.18, -5.0), M.mat(Color(0.82, 0.84, 0.86), 0.0, 0.6), Vector3.ZERO, 24).scale = Vector3(1, 0.5, 1)
	M.box(r, Vector3(0.14, 0.02, 0.9), Vector3(-0.3, 1.24, -5.0), M.dark())
	M.box(r, Vector3(0.14, 0.02, 0.9), Vector3(0.3, 1.24, -5.0), M.dark())
	M.box(r, Vector3(0.74, 0.02, 0.14), Vector3(0, 1.24, -5.0), M.dark())
	for i in 8:
		var a = TAU * i / 8.0
		M.sph(r, 0.06, Vector3(cos(a) * 1.4, 1.22, -5.0 + sin(a) * 1.4), M.glow(Color(0.4, 0.9, 1.0), 5.0))
	M.box(r, Vector3(2.4, 1.0, 1.2), Vector3(0, 1.65, -3.5), white).scale = Vector3(1, 1, 1)
	M.box(r, Vector3(2.0, 0.7, 0.05), Vector3(0, 1.6, -2.88), M.dark())
	# Schildemitter
	for sx in [-1.0, 1.0]:
		M.cyl(r, 0.06, 0.1, 1.2, Vector3(sx * 1.5, 1.6, -3.2), M.steel(), Vector3.ZERO, 6)
		M.sph(r, 0.2, Vector3(sx * 1.5, 2.25, -3.2), M.glow(Color(0.4, 0.9, 1.0), 5.0))
		_lifeboat(r, Vector3(sx * 1.55, 1.45, 0.3), Color(1.0, 0.55, 0.12), -sx)
	for k in 3:
		_crew(r, "west", Vector3(-0.8 + k * 0.9, 1.1, 5.8 - k * 0.2), 0.2 + k, out, k)
	_hatch(r, Vector3(0.9, 1.1, 1.0))
	_vent(r, Vector3(-0.9, 1.1, 0.8))
	# Drehbare Raketenlafette mit Panzerplatten
	var t = M.node(r, Vector3(0, 1.15, 4.2))
	M.cyl(t, 0.7, 0.8, 0.4, Vector3(0, 0.2, 0), pc, Vector3.ZERO, 14)
	M.sph(t, 0.07, Vector3(0.65, 0.5, -0.3), M.glow(Color(1.0, 0.3, 0.2), 6.0))
	var br = M.node(t, Vector3(0, 0.5, 0))
	for sx in [-0.3, 0.3]:
		M.box(br, Vector3(0.5, 0.5, 2.0), Vector3(sx, 0.1, 0.6), M.dark(), Vector3(-0.45, 0, 0))
		M.box(br, Vector3(0.54, 0.05, 1.9), Vector3(sx, 0.36, 0.55), white, Vector3(-0.45, 0, 0))
		M.cyl(br, 0.14, 0.14, 0.05, Vector3(sx, 0.55, 1.5), M.glow(Color(0.5, 0.9, 1.0), 2.5), Vector3(-0.45 + PI / 2, 0, 0), 8)
	out["turret"] = t
	out["barrel"] = br
	out["muzzle"] = Vector3(0, 1.0, 1.8)

static func _gunboat(r: Node3D, pc: Material, out: Dictionary) -> void:
	hull(r, 8.6, 2.9, 1.0, 0.8, M.steel(), M.dark(), 0.8, M.mat(Color(0.5, 0.08, 0.06), 0.2, 0.6))
	_fit(r, 8.6, 2.9, 1.0, 0.8, {"ports": Color(1.0, 0.82, 0.5), "rivets": true})
	# Brücke, Fenster, Schornstein mit Rauch
	M.box(r, Vector3(1.9, 1.0, 2.2), Vector3(0, 1.5, -1.0), pc)
	M.box(r, Vector3(1.7, 0.3, 0.05), Vector3(0, 1.75, 0.12), M.glass())
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.05, 0.3, 1.2), Vector3(sx * 0.96, 1.75, -0.8), M.glass())
	M.box(r, Vector3(2.1, 0.12, 2.4), Vector3(0, 2.05, -1.0), M.dark())
	M.cyl(r, 0.4, 0.46, 1.4, Vector3(0, 2.0, -2.6), M.dark(), Vector3.ZERO, 12)
	M.cyl(r, 0.42, 0.42, 0.2, Vector3(0, 2.6, -2.6), M.mat(Color(0.7, 0.1, 0.08), 0.1, 0.6), Vector3.ZERO, 12)
	_smoke(r, Vector3(0, 2.8, -2.6))
	M._star(r, Vector3(0.96, 1.55, -1.0), 0.28, M.glow(Color(1.0, 0.82, 0.2), 1.2)).rotation.y = PI / 2
	M._star(r, Vector3(-0.96, 1.55, -1.0), 0.28, M.glow(Color(1.0, 0.82, 0.2), 1.2)).rotation.y = -PI / 2
	_radar(r, Vector3(0, 2.1, -0.5), 0.8, out)
	D.flag(r, Vector3(0, 2.1, -1.6), 1.6, M._team, out)
	_navlights(r, 1.0, 1.8, 0.1)
	M.sph(r, 0.14, Vector3(0.5, 2.2, 0.0), M.glow(Color(1.0, 0.95, 0.8), 3.0))
	# Rettungsringe, Rettungsboot, Kisten
	for sx in [-1.0, 1.0]:
		M.cyl(r, 0.28, 0.28, 0.07, Vector3(sx * 1.35, 1.1, -2.2), M.paint(Color.WHITE), Vector3(0, 0, PI / 2), 12)
	_lifeboat(r, Vector3(1.0, 1.1, -2.9), Color(0.75, 0.2, 0.12), -1.0)
	_deckbox(r, Vector3(-0.95, 1.0, -2.4), 0.2, Color(0.3, 0.34, 0.24))
	_hatch(r, Vector3(0.5, 1.0, 1.0))
	_crew(r, "red", Vector3(0.6, 1.0, 0.7), 0.6, out, 1)
	_crew(r, "red", Vector3(-0.7, 1.0, -2.7), 2.4, out, 2)
	# Kanone mit Schutzschild
	var t = M.node(r, Vector3(0, 1.1, 2.3))
	M.cyl(t, 0.62, 0.7, 0.55, Vector3(0, 0.28, 0), pc, Vector3.ZERO, 12)
	M.box(t, Vector3(0.9, 0.5, 0.8), Vector3(0, 0.4, 0.3), pc, Vector3(-0.2, 0, 0))
	M.box(t, Vector3(0.12, 0.5, 0.5), Vector3(0.48, 0.5, 0.1), M.dark())
	var br = M.node(t, Vector3(0, 0.45, 0))
	M.cyl(br, 0.09, 0.11, 2.2, Vector3(0, 0, 1.5), M.steel(), Vector3(PI / 2, 0, 0), 10)
	M.cyl(br, 0.14, 0.14, 0.3, Vector3(0, 0, 2.6), M.dark(), Vector3(PI / 2, 0, 0), 10)
	out["turret"] = t
	out["barrel"] = br
	out["muzzle"] = Vector3(0, 0.45, 2.8)

static func _battleship(r: Node3D, pc: Material, out: Dictionary) -> void:
	hull(r, 14.6, 4.6, 1.3, 1.0, M.steel(), M.dark(), 0.84, M.mat(Color(0.5, 0.08, 0.06), 0.2, 0.6))
	_fit(r, 14.6, 4.6, 1.3, 0.84, {"ports": Color(1.0, 0.82, 0.5), "rivets": true})
	# Turm in Stufen mit Fensterbändern
	M.box(r, Vector3(3.0, 1.2, 3.6), Vector3(0, 2.0, -0.6), pc)
	M.box(r, Vector3(3.05, 0.1, 3.65), Vector3(0, 2.6, -0.6), M.dark())
	M.box(r, Vector3(2.6, 0.9, 2.6), Vector3(0, 3.05, -0.6), pc)
	M.box(r, Vector3(2.5, 0.3, 0.05), Vector3(0, 3.2, 0.72), M.glass())
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.05, 0.3, 1.8), Vector3(sx * 1.3, 3.2, -0.6), M.glass())
	M.box(r, Vector3(2.0, 0.7, 1.7), Vector3(0, 3.85, -0.6), pc)
	M.box(r, Vector3(2.2, 0.12, 1.9), Vector3(0, 4.25, -0.6), M.dark())
	for k in 2:
		M.cyl(r, 0.55, 0.65, 2.0, Vector3(0, 2.7, -2.8 - k * 1.5), M.dark(), Vector3.ZERO, 12)
		M.cyl(r, 0.58, 0.58, 0.24, Vector3(0, 3.62, -2.8 - k * 1.5), M.mat(Color(0.7, 0.1, 0.08), 0.1, 0.6), Vector3.ZERO, 12)
		M.cyl(r, 0.5, 0.5, 0.08, Vector3(0, 3.76, -2.8 - k * 1.5), _team_mat(), Vector3.ZERO, 12)
		_smoke(r, Vector3(0, 3.9, -2.8 - k * 1.5))
	M._star(r, Vector3(1.52, 2.1, -0.6), 0.45, M.glow(Color(1.0, 0.82, 0.2), 1.2)).rotation.y = PI / 2
	M._star(r, Vector3(-1.52, 2.1, -0.6), 0.45, M.glow(Color(1.0, 0.82, 0.2), 1.2)).rotation.y = -PI / 2
	_radar(r, Vector3(0, 4.35, -0.9), 1.5, out)
	M.cyl(r, 0.06, 0.08, 2.0, Vector3(0, 5.3, -0.2), M.dark(), Vector3.ZERO, 6)
	D.flag(r, Vector3(0, 4.3, 0.1), 3.0, M._team, out)
	_navlights(r, 1.35, 3.4, 0.7)
	# Flak-Vierlinge, Rettungsboote, Kranarm
	for sx in [-1.0, 1.0]:
		M.cyl(r, 0.12, 0.14, 0.5, Vector3(sx * 1.9, 1.55, 1.8), M.steel(), Vector3.ZERO, 6)
		for k in 2:
			M.cyl(r, 0.04, 0.04, 0.9, Vector3(sx * 1.9 + (k - 0.5) * 0.18, 2.0, 2.1), M.dark(), Vector3(PI / 2 - 0.5, 0, 0), 6)
		_lifeboat(r, Vector3(sx * 1.95, 1.8, -1.0), Color(0.75, 0.2, 0.12), -sx)
		_lifeboat(r, Vector3(sx * 1.95, 1.8, -2.8), Color(0.75, 0.2, 0.12), -sx)
	for k in 4:
		_crew(r, "red", Vector3(-1.0 + k * 0.7, 1.3, 7.0 - k * 0.15), 0.3 * k, out, k)
	for k in 3:
		_hatch(r, Vector3(-0.9 + k * 0.9, 1.3, -6.0))
	_vent(r, Vector3(1.4, 1.3, -4.6))
	_vent(r, Vector3(-1.4, 1.3, -4.9))
	# Zwei Doppelgeschütze vorn, eines achtern (nur das vorderste dreht sich im Spiel)
	var tmain = null
	var brmain = null
	for cfg in [[4.9, 1.45], [2.7, 1.9], [-5.0, 1.45]]:
		var t = M.node(r, Vector3(0, cfg[1], cfg[0]))
		M.cyl(t, 0.9, 1.0, 0.45, Vector3(0, 0.22, 0), pc, Vector3.ZERO, 14)
		M.box(t, Vector3(1.5, 0.55, 1.5), Vector3(0, 0.55, 0.1), pc, Vector3(-0.1, 0, 0))
		M.box(t, Vector3(1.4, 0.1, 1.2), Vector3(0, 0.88, -0.1), M.dark())
		for sx in [-0.8, 0.8]:
			M.box(t, Vector3(0.05, 0.4, 1.2), Vector3(sx, 0.5, 0.0), M.steel())
		var br = M.node(t, Vector3(0, 0.55, 0))
		for sx in [-0.34, 0.34]:
			M.cyl(br, 0.1, 0.12, 2.8, Vector3(sx, 0, 1.9), M.steel(), Vector3(PI / 2, 0, 0), 10)
			M.cyl(br, 0.15, 0.15, 0.3, Vector3(sx, 0, 3.3), M.dark(), Vector3(PI / 2, 0, 0), 10)
		if cfg[0] < -2.0:
			t.rotation.y = PI
		if tmain == null:
			tmain = t
			brmain = br
	out["turret"] = tmain
	out["barrel"] = brmain
	out["muzzle"] = Vector3(0, 0.55, 3.55)

static func _skiff(r: Node3D, pc: Material, out: Dictionary) -> void:
	var board = M.mat(Color(0.42, 0.3, 0.2), 0.0, 0.9)
	var rust = M.mat(Color(0.45, 0.22, 0.1), 0.4, 0.8)
	hull(r, 6.3, 2.2, 0.55, 0.5, rust, board, 0.75, M.mat(Color(0.12, 0.1, 0.08), 0.0, 0.9))
	_fit(r, 6.3, 2.2, 0.55, 0.75, {"rivets": true})
	# Dollbord aus Brettern mit Ausbesserungen
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.08, 0.3, 4.2), Vector3(sx * 0.95, 0.8, -0.4), board, Vector3(0, sx * 0.04, 0))
		M.box(r, Vector3(0.1, 0.22, 0.7), Vector3(sx * 0.97, 0.85, 0.3), M.mat(Color(0.5, 0.18, 0.1), 0.4, 0.8), Vector3(0, sx * 0.04, 0))
	for k in 3:
		M.box(r, Vector3(1.9, 0.07, 0.12), Vector3(0, 0.62, -2.6 + k * 1.3), board)
	# Außenborder mit Tank
	M.box(r, Vector3(0.4, 0.55, 0.5), Vector3(0, 0.8, -3.3), M.dark())
	M.box(r, Vector3(0.24, 0.1, 0.5), Vector3(0, 1.12, -3.25), M.mat(Color(0.7, 0.1, 0.08), 0.3, 0.6))
	M.cyl(r, 0.04, 0.05, 0.9, Vector3(0, 0.3, -3.5), M.steel(), Vector3.ZERO, 6)
	M.cyl(r, 0.2, 0.2, 0.04, Vector3(0, -0.15, -3.55), M.steel(), Vector3(0, 0, PI / 2), 8)
	M.box(r, Vector3(0.05, 0.05, 0.7), Vector3(0.3, 1.0, -3.0), M.dark(), Vector3(0, -0.4, 0))
	# Persenning, Kanister, Kisten, Seil, Netz
	M.box(r, Vector3(1.6, 0.5, 1.5), Vector3(0, 0.95, -1.5), M.mat(Color(0.3, 0.27, 0.2), 0.0, 0.95))
	M.box(r, Vector3(1.7, 0.06, 0.1), Vector3(0, 1.22, -1.5), M.dark())
	M.box(r, Vector3(0.5, 0.35, 0.5), Vector3(0.55, 0.78, -0.2), M.mat(Color(0.5, 0.45, 0.3), 0.0, 0.9), Vector3(0, 0.3, 0))
	for k in 2:
		M.cyl(r, 0.14, 0.14, 0.4, Vector3(-0.5 + k * 0.3, 0.78, -0.3), M.mat(Color(0.55, 0.3, 0.12), 0.3, 0.7), Vector3.ZERO, 8)
	M.cyl(r, 0.25, 0.25, 0.1, Vector3(-0.45, 0.62, 0.3), M.mat(Color(0.7, 0.62, 0.45), 0.0, 0.95), Vector3.ZERO, 10)
	M.sph(r, 0.4, Vector3(0.35, 0.5, 0.4), M.mat(Color(0.35, 0.35, 0.3), 0.0, 0.95), Vector3(1.3, 0.5, 1.0), true)
	for k in 3:
		M.cyl(r, 0.2, 0.2, 0.2, Vector3(1.05, 0.2, 1.2 - k * 1.1), M.mat(Color(0.05, 0.05, 0.05), 0.0, 0.95), Vector3(0, 0, PI / 2), 10)
	# Fahne: Teamfarbe und Piratenschwarz
	D.flag(r, Vector3(0.7, 0.9, -2.3), 1.8, M._team, out)
	D.flag(r, Vector3(-0.7, 0.9, -2.4), 2.1, Color(0.06, 0.06, 0.06), out)
	_crew(r, "shadow", Vector3(0.1, 0.55, -0.9), 3.0, out, 1)
	_crew(r, "shadow", Vector3(-0.35, 0.55, 0.9), 0.2, out, 2)
	# MG auf Pfosten mit Munitionskasten
	var t = M.node(r, Vector3(0, 1.0, 1.4))
	M.cyl(t, 0.06, 0.06, 0.5, Vector3(0, -0.05, 0), M.dark(), Vector3.ZERO, 6)
	M.box(t, Vector3(0.3, 0.26, 0.5), Vector3(0, 0.3, 0.0), M.dark())
	M.box(t, Vector3(0.36, 0.34, 0.08), Vector3(0, 0.35, 0.3), M.steel())
	M.box(t, Vector3(0.24, 0.2, 0.3), Vector3(0.27, 0.25, -0.05), M.mat(Color(0.3, 0.34, 0.22), 0.3, 0.7))
	var br = M.node(t, Vector3(0, 0.3, 0))
	M.cyl(br, 0.04, 0.04, 1.0, Vector3(0, 0, 0.8), M.dark(), Vector3(PI / 2, 0, 0), 6)
	out["turret"] = t
	out["barrel"] = br
	out["muzzle"] = Vector3(0, 0.3, 1.35)

static func _frigate(r: Node3D, pc: Material, out: Dictionary) -> void:
	var rust = M.mat(Color(0.42, 0.22, 0.12), 0.4, 0.85)
	var plate = M.mat(Color(0.35, 0.37, 0.38), 0.5, 0.7)
	hull(r, 11.8, 3.5, 1.0, 0.85, rust, M.mat(Color(0.28, 0.2, 0.14), 0.0, 0.9), 0.82, M.mat(Color(0.12, 0.1, 0.08), 0.0, 0.9))
	_fit(r, 11.8, 3.5, 1.0, 0.82, {"rivets": true})
	# Blechflicken und Fender aus Autoreifen
	for k in 5:
		var sz = -4.0 + k * 2.0
		for sx in [-1.0, 1.0]:
			M.box(r, Vector3(0.05, 0.5, 0.9), Vector3(sx * (1.58 - 0.04 * (k % 2)), 0.45, sz + (k % 3) * 0.1), plate if k % 2 == 0 else M.mat(Color(0.5, 0.18, 0.1), 0.4, 0.8))
			M.cyl(r, 0.3, 0.3, 0.22, Vector3(sx * 1.62, 0.15, sz + 1.0), M.mat(Color(0.05, 0.05, 0.05), 0.0, 0.95), Vector3(0, 0, PI / 2), 12)
			M.cyl(r, 0.15, 0.15, 0.24, Vector3(sx * 1.62, 0.15, sz + 1.0), M.dark(), Vector3(0, 0, PI / 2), 8)
	# Containerstapel mittschiffs mit Türen und Zurrseilen
	var cols = [Color(0.45, 0.2, 0.12), Color(0.2, 0.3, 0.38), Color(0.32, 0.38, 0.2), Color(0.5, 0.36, 0.14)]
	for row in 2:
		for lvl in 2 if row == 0 else 1:
			var cx = -0.75 + row * 1.5
			var cy = 1.4 + lvl * 0.82
			M.box(r, Vector3(1.0, 0.8, 2.2), Vector3(cx, cy, -1.2 + lvl * 0.15), M.mat(cols[(row * 2 + lvl) % 4], 0.3, 0.8), Vector3(0, 0.03 * lvl, 0))
			M.box(r, Vector3(0.9, 0.7, 0.04), Vector3(cx, cy, -0.08 + lvl * 0.15), M.dark())
			M.box(r, Vector3(0.04, 0.7, 0.04), Vector3(cx, cy, -0.05 + lvl * 0.15), M.steel())
	M.box(r, Vector3(2.9, 0.1, 2.5), Vector3(0.1, 2.9, -1.1), M.mat(Color(0.3, 0.26, 0.2), 0.0, 0.95), Vector3(0, 0.1, 0.08))
	# Ruderhaus aus Blech mit Sichtschlitz und Schweißnähten
	M.box(r, Vector3(1.8, 1.1, 1.6), Vector3(0, 1.55, -3.5), plate)
	M.box(r, Vector3(1.6, 0.18, 0.05), Vector3(0, 1.85, -2.68), M.glow(Color(1.0, 0.8, 0.4), 1.5))
	M.box(r, Vector3(2.0, 0.1, 1.8), Vector3(0, 2.15, -3.5), rust)
	for k in 3:
		M.box(r, Vector3(0.03, 1.0, 1.5), Vector3(-0.6 + k * 0.6, 1.55, -3.5), M.mat(Color(0.2, 0.2, 0.2), 0.3, 0.8)).scale = Vector3(1, 1, 1.02)
	M.cyl(r, 0.18, 0.2, 1.0, Vector3(0.6, 2.7, -4.0), rust, Vector3.ZERO, 8)
	M.cyl(r, 0.14, 0.16, 0.7, Vector3(-0.5, 2.5, -4.1), plate, Vector3.ZERO, 8)
	_smoke(r, Vector3(0.6, 3.25, -4.0))
	# Kran und Winde
	M.cyl(r, 0.07, 0.09, 2.4, Vector3(-1.3, 2.2, 1.4), M.dark(), Vector3.ZERO, 6)
	M.box(r, Vector3(0.08, 0.08, 2.0), Vector3(-1.3, 3.3, 2.1), M.dark(), Vector3(0.2, 0, 0))
	M.cyl(r, 0.01, 0.01, 1.0, Vector3(-1.3, 2.9, 3.0), M.dark(), Vector3.ZERO, 4)
	M.cyl(r, 0.2, 0.2, 0.3, Vector3(-1.3, 1.2, 1.1), M.mat(Color(0.4, 0.35, 0.3), 0.4, 0.7), Vector3(0, 0, PI / 2), 10)
	# Piratenflagge und Teamwimpel, Laterne
	D.flag(r, Vector3(0, 2.2, -3.0), 3.0, Color(0.05, 0.05, 0.05), out)
	D.flag(r, Vector3(0.9, 2.2, -4.2), 2.0, M._team, out)
	var lamp = M.sph(r, 0.12, Vector3(0, 5.3, -3.0), M.glow(Color(1.0, 0.7, 0.3), 5.0))
	D.anim(out, {"t": "blink", "n": lamp, "p": 1.4, "o": 0.0})
	_navlights(r, 0.8, 2.3, -2.7)
	_deckbox(r, Vector3(1.2, 1.0, 2.3), 0.4, Color(0.4, 0.3, 0.18))
	_crew(r, "shadow", Vector3(0.7, 1.0, 3.9), 0.2, out, 1)
	_crew(r, "shadow", Vector3(-0.8, 1.0, -5.0), 2.9, out, 2)
	_crew(r, "shadow", Vector3(1.0, 1.0, 1.4), 1.2, out, 3)
	# Raketengestell
	var t = M.node(r, Vector3(0, 1.0, 3.0))
	M.cyl(t, 0.6, 0.7, 0.3, Vector3(0, 0.15, 0), plate, Vector3.ZERO, 10)
	var br = M.node(t, Vector3(0, 0.45, 0))
	for sx in [-0.4, 0.0, 0.4]:
		for sy in [0.0, 0.34]:
			M.cyl(br, 0.13, 0.13, 1.5, Vector3(sx, sy, 0.7), M.mat(Color(0.3, 0.32, 0.3), 0.4, 0.7), Vector3(PI / 2 - 0.3, 0, 0), 8)
			M.cyl(br, 0.09, 0.0, 0.3, Vector3(sx, sy + 0.2, 1.45), M.mat(Color(0.7, 0.2, 0.1), 0.3, 0.6), Vector3(PI / 2 - 0.3, 0, 0), 8)
	M.box(br, Vector3(1.4, 0.05, 0.06), Vector3(0, 0.2, 0.2), M.dark())
	out["turret"] = t
	out["barrel"] = br
	out["muzzle"] = Vector3(0, 0.9, 1.5)

# ---------------------------------------------------------------- Werften
# Vorne (+Z) zeigt aufs Wasser. Fundament liefert models.gd; Leben (Arbeiter, Lichter) kommt aus models._life.

const PIER_LEN := 9.0

static func _pier(r: Node3D, w: float, length: float, wide: float, planks: Material, pile: Material, faction: String) -> void:
	var z0 = w * 0.5 + length * 0.5 - 0.3
	M.box(r, Vector3(wide, 0.18, length), Vector3(0, 0.22, z0), planks)
	M._bt.clear()
	var dark = M.dark()
	var rope = M.mat(Color(0.65, 0.58, 0.4), 0.0, 0.95)
	var tire = M.mat(Color(0.05, 0.05, 0.05), 0.0, 0.95)
	for k in int(length / 1.5) + 1:
		var zz = w * 0.5 + 0.2 + k * 1.5
		for sx in [-1.0, 1.0]:
			M._bc(0.16, 0.16, 3.0, Vector3(sx * wide * 0.5, -1.0, zz), pile, Vector3.ZERO, 8)
			M._bb(Vector3(0.3, 0.12, 0.3), Vector3(sx * wide * 0.5, 0.32, zz), dark)
			M._bc(0.09, 0.11, 0.26, Vector3(sx * (wide * 0.5 - 0.1), 0.43, zz + 0.6), dark, Vector3.ZERO, 8)
			# Fender (Reifen oder Gummiwalze) an der Kante
			var fy = 0.05
			if faction == "shadow":
				M._bc(0.28, 0.28, 0.2, Vector3(sx * (wide * 0.5 + 0.2), fy, zz + 0.75), tire, Vector3(0, 0, PI / 2), 10)
			else:
				M._bc(0.16, 0.16, 0.7, Vector3(sx * (wide * 0.5 + 0.2), fy, zz + 0.75), tire, Vector3(PI / 2, 0, 0), 8)
		# Seil zwischen den Pfählen
		if k > 0:
			for sx in [-1.0, 1.0]:
				M._bb(Vector3(0.035, 0.035, 1.5), Vector3(sx * wide * 0.5, 0.52 + 0.1 * sin(k * 1.3), zz - 0.75), rope)
	# Planken-Fugen
	for k in int(length / 0.55):
		M._bb(Vector3(wide, 0.012, 0.03), Vector3(0, 0.315, w * 0.5 + 0.2 + k * 0.55), dark)
	M._flush(r)
	# Leiter ins Wasser am Pierende
	for sx in [-0.3, 0.3]:
		M.box(r, Vector3(0.04, 1.4, 0.04), Vector3(sx, -0.4, w * 0.5 + length - 0.5), M.steel())
	for k in 4:
		M.box(r, Vector3(0.6, 0.03, 0.03), Vector3(0, 0.15 - k * 0.3, w * 0.5 + length - 0.5), M.steel())

static func _lamp(r: Node3D, pos: Vector3, col: Color) -> void:
	M.cyl(r, 0.04, 0.05, 2.2, pos + Vector3(0, 1.1, 0), M.dark(), Vector3.ZERO, 6)
	M.box(r, Vector3(0.05, 0.05, 0.4), pos + Vector3(0, 2.2, 0.15), M.dark())
	M.sph(r, 0.1, pos + Vector3(0, 2.15, 0.34), M.glow(col, 5.0))

static func dock(r: Node3D, faction: String, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	match faction:
		"west": _west_dock(r, w, pc, wl, out)
		"red": _red_dock(r, w, pc, wl, out)
		_: _shadow_dock(r, w, pc, wl, out)

static func _west_dock(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var glass = M.mat(Color(0.08, 0.16, 0.24), 0.9, 0.06)
	var cyan = M.glow(Color(0.35, 0.8, 1.0), 3.0)
	_pier(r, w, PIER_LEN, 3.4, M.mat(Color(0.75, 0.8, 0.85), 0.5, 0.4), M.steel(), "west")
	# Glashalle mit gewölbtem Dach und Rippen
	M.box(r, Vector3(w * 0.9, 1.8, w * 0.55), Vector3(0, 0.9, -w * 0.22), wl)
	M.box(r, Vector3(w * 0.86, 1.2, 0.08), Vector3(0, 1.0, -w * 0.22 + w * 0.28), glass)
	M.cyl(r, w * 0.3, w * 0.3, w * 0.9, Vector3(0, 1.8, -w * 0.22), pc, Vector3(0, 0, PI / 2), 16).scale = Vector3(0.45, 1.0, 1.0)
	for k in 5:
		M.box(r, Vector3(0.06, 0.06, w * 0.56), Vector3(-w * 0.35 + k * w * 0.175, 2.1, -w * 0.22), M.steel())
	for k in 4:
		M.box(r, Vector3(0.06, 1.3, 0.06), Vector3(-w * 0.36 + k * w * 0.24, 1.0, -w * 0.22 + w * 0.285), M.steel())
	M.box(r, Vector3(w * 0.88, 0.06, 0.1), Vector3(0, 0.55, -w * 0.22 + w * 0.28 + 0.05), cyan)
	M.box(r, Vector3(1.6, 1.3, 0.06), Vector3(0, 0.75, -w * 0.22 + w * 0.285), M.dark())
	# Portalkran über dem Steg mit Laufkatze
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.18, 3.6, 0.18), Vector3(sx * 1.9, 1.8, w * 0.5 + 2.4), M.steel())
		M.box(r, Vector3(0.1, 3.2, 0.08), Vector3(sx * 1.9, 1.8, w * 0.5 + 2.9), M.steel(), Vector3(0.0, 0, 0))
	M.box(r, Vector3(4.2, 0.22, 0.3), Vector3(0, 3.65, w * 0.5 + 2.4), pc)
	var trolley = M.node(r, Vector3(0, 3.5, w * 0.5 + 2.4))
	M.box(trolley, Vector3(0.5, 0.25, 0.4), Vector3.ZERO, M.dark())
	M.cyl(trolley, 0.02, 0.02, 1.3, Vector3(0, -0.7, 0), M.dark(), Vector3.ZERO, 4)
	M.box(trolley, Vector3(0.3, 0.2, 0.3), Vector3(0, -1.4, 0), M.dark())
	D.anim(out, {"t": "slide", "n": trolley, "a": Vector3(-1.5, 3.5, w * 0.5 + 2.4), "b": Vector3(1.5, 3.5, w * 0.5 + 2.4), "s": 0.7})
	for k in 4:
		M.sph(r, 0.1, Vector3(0, 0.45, w * 0.5 + 1.0 + k * 2.2), cyan)
	_lamp(r, Vector3(-1.5, 0.3, w * 0.5 + 4.5), Color(0.6, 0.9, 1.0))
	# Radar und Ladestation für Drohnen
	M.cyl(r, 0.08, 0.1, 1.2, Vector3(-w * 0.3, 3.3, -w * 0.3), M.steel(), Vector3.ZERO, 6)
	var dish = M.node(r, Vector3(-w * 0.3, 3.9, -w * 0.3))
	M.sph(dish, 0.6, Vector3.ZERO, M.mat(Color(0.92, 0.94, 0.96), 0.2, 0.35), Vector3(1, 0.4, 1), true)
	M.box(dish, Vector3(0.05, 0.05, 0.7), Vector3(0, 0.3, 0.3), M.steel())
	D.anim(out, {"t": "spin", "n": dish, "s": 1.2})
	for k in 3:
		M.cyl(r, 0.35, 0.35, 0.05, Vector3(w * 0.3 - k * 0.0, 2.1 + 0.0, -w * 0.45 + k * 0.0), M.dark(), Vector3.ZERO, 8).visible = false
	out["height"] = 4.0

static func _red_dock(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	_pier(r, w, PIER_LEN, 3.6, M.mat(Color(0.4, 0.4, 0.38), 0.2, 0.9), M.concrete(), "red")
	# Hellingshalle mit Sägedach, Oberlichtern und Rolltor
	M.box(r, Vector3(w * 0.92, 2.2, w * 0.58), Vector3(0, 1.1, -w * 0.2), wl)
	for k in 3:
		var zz = -w * 0.2 - w * 0.2 + k * w * 0.2
		M.box(r, Vector3(w * 0.94, 0.9, 0.12), Vector3(0, 2.65, zz - 0.4), pc, Vector3(0.45, 0, 0))
		M.box(r, Vector3(w * 0.9, 0.5, 0.06), Vector3(0, 2.6, zz - 0.15), M.mat(Color(0.5, 0.65, 0.7, 1), 0.8, 0.1))
	M.box(r, Vector3(w * 0.46, 1.8, 0.1), Vector3(0, 0.95, -w * 0.2 + w * 0.29), M.dark())
	for k in 6:
		M.box(r, Vector3(w * 0.46, 0.05, 0.12), Vector3(0, 0.3 + k * 0.3, -w * 0.2 + w * 0.295), M.steel())
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.5, 0.45, 0.06), Vector3(sx * w * 0.36, 1.4, -w * 0.2 + w * 0.295), M.glow(Color(1.0, 0.82, 0.5), 2.0))
	# Backsteinschlot mit Rauch
	M.cyl(r, 0.3, 0.42, 5.2, Vector3(w * 0.36, 2.6, -w * 0.38), M.mat(Color(0.34, 0.2, 0.16), 0.0, 0.9), Vector3.ZERO, 10)
	M.cyl(r, 0.4, 0.4, 0.14, Vector3(w * 0.36, 4.6, -w * 0.38), M.paint(Color.WHITE), Vector3.ZERO, 10)
	out["smoke"] = [Vector3(w * 0.36, 5.3, -w * 0.38)]
	# Drehkran am Kai mit Gegengewicht (dreht sich)
	M.cyl(r, 0.2, 0.26, 3.2, Vector3(-2.0, 1.6, w * 0.5 + 0.8), M.mat(Color(0.5, 0.08, 0.06), 0.3, 0.7), Vector3.ZERO, 8)
	var jib = M.node(r, Vector3(-2.0, 3.2, w * 0.5 + 0.8))
	M.box(jib, Vector3(0.18, 0.18, 4.4), Vector3(0, 0.1, 1.7), M.mat(Color(0.5, 0.08, 0.06), 0.3, 0.7), Vector3(-0.15, 0, 0))
	M.box(jib, Vector3(0.14, 0.7, 0.14), Vector3(0, 0.3, -0.5), M.dark())
	M.box(jib, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.0, -0.7), M.dark())
	M.cyl(jib, 0.015, 0.015, 1.8, Vector3(0, -0.8, 3.6), M.dark(), Vector3.ZERO, 4)
	D.anim(out, {"t": "sweep", "n": jib, "s": 0.35, "amp": 0.5})
	M._star(r, Vector3(0, 2.0, -w * 0.2 + w * 0.3 + 0.05), 0.7, M.glow(Color(1.0, 0.82, 0.2), 1.2))
	# Tonnen (Bojen), Munitionskisten, Schweißstelle, Fahnen
	for k in 3:
		M.cyl(r, 0.16, 0.16, 0.4, Vector3(1.4 + k * 0.45, 0.45, w * 0.5 + 0.9), M.mat(Color(0.7, 0.1, 0.08), 0.3, 0.6) if k % 2 == 0 else M.paint(Color.WHITE), Vector3.ZERO, 8)
	for k in 2:
		M.box(r, Vector3(0.7, 0.45, 0.45), Vector3(1.5 + k * 0.1, 0.55 + k * 0.45, w * 0.5 + 2.2), M.mat(Color(0.28, 0.32, 0.22), 0.3, 0.7), Vector3(0, 0.1 * k, 0))
	D.anim(out, {"t": "weld", "n": M.node(r, Vector3(-1.0, 0.5, w * 0.5 + 3.0)), "p": 2.4})
	_lamp(r, Vector3(1.6, 0.3, w * 0.5 + 4.5), Color(1.0, 0.85, 0.5))
	out["height"] = 5.0

static func _shadow_dock(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	var wood = M.mat(Color(0.4, 0.28, 0.17), 0.0, 0.92)
	var cloth = M.mat(Color(0.3, 0.27, 0.2), 0.0, 0.95)
	var rust = M.mat(Color(0.45, 0.22, 0.1), 0.4, 0.8)
	_pier(r, w, PIER_LEN, 3.0, wood, M.mat(Color(0.25, 0.18, 0.12), 0.0, 0.95), "shadow")
	# Bretterhütte mit schrägem Wellblechdach, Fensterläden und Rohrkamin
	M.box(r, Vector3(w * 0.8, 1.9, w * 0.5), Vector3(0, 0.95, -w * 0.22), wood)
	for k in 7:
		M.box(r, Vector3(0.04, 1.9, w * 0.52), Vector3(-w * 0.36 + k * w * 0.12, 0.95, -w * 0.22), M.mat(Color(0.3, 0.2, 0.12), 0.0, 0.95))
	M.box(r, Vector3(w * 0.9, 0.12, w * 0.62), Vector3(0, 2.05, -w * 0.22), rust, Vector3(0.12, 0, 0.05))
	for k in 6:
		M.box(r, Vector3(0.06, 0.05, w * 0.64), Vector3(-w * 0.4 + k * w * 0.16, 2.12, -w * 0.22), M.mat(Color(0.55, 0.28, 0.14), 0.4, 0.8), Vector3(0.12, 0, 0.05))
	M.box(r, Vector3(1.3, 1.5, 0.08), Vector3(w * 0.1, 0.8, -w * 0.22 + w * 0.25), M.dark())
	for sx in [-1.0, 1.0]:
		M.box(r, Vector3(0.6, 0.6, 0.06), Vector3(w * 0.1 + sx * 1.6, 1.2, -w * 0.22 + w * 0.255), M.glow(Color(1.0, 0.75, 0.4), 1.5))
		M.box(r, Vector3(0.34, 0.62, 0.05), Vector3(w * 0.1 + sx * 1.6 + sx * 0.38, 1.2, -w * 0.22 + w * 0.26), wood, Vector3(0, sx * -0.5, 0))
	M.cyl(r, 0.14, 0.16, 1.4, Vector3(w * 0.3, 2.7, -w * 0.4), M.mat(Color(0.3, 0.3, 0.3), 0.5, 0.7), Vector3.ZERO, 8)
	out["smoke"] = [Vector3(w * 0.3, 3.5, -w * 0.4)]
	# Zeltplane über der Kaikante
	M.box(r, Vector3(2.6, 0.06, 2.0), Vector3(-1.2, 2.3, w * 0.5 + 0.5), cloth, Vector3(0.15, 0.1, 0.0))
	for sx in [-2.3, -0.1]:
		M.cyl(r, 0.05, 0.06, 2.3, Vector3(sx, 1.15, w * 0.5 + 1.4), M.dark(), Vector3.ZERO, 6)
	# Fässer, Kisten, Netze, Ruderboot an Land
	for k in 4:
		M.cyl(r, 0.28, 0.28, 0.6, Vector3(1.4 + (k % 2) * 0.6, 0.5, w * 0.5 + 0.4 + (k / 2) * 0.6), M.mat(Color(0.5, 0.25, 0.12) if k % 2 == 0 else Color(0.2, 0.3, 0.38), 0.3, 0.8), Vector3.ZERO, 10)
	M.box(r, Vector3(0.9, 0.6, 0.7), Vector3(1.6, 0.55, w * 0.5 + 2.2), M.mat(Color(0.5, 0.4, 0.25), 0.0, 0.9), Vector3(0, 0.3, 0))
	M.box(r, Vector3(0.7, 0.5, 0.6), Vector3(1.55, 1.05, w * 0.5 + 2.2), M.mat(Color(0.45, 0.35, 0.2), 0.0, 0.9), Vector3(0, -0.2, 0))
	M.sph(r, 0.7, Vector3(-1.5, 0.5, w * 0.5 + 3.2), M.mat(Color(0.35, 0.35, 0.3), 0.0, 0.95), Vector3(1.3, 0.5, 1.0), true)
	for k in 3:
		M.sph(r, 0.12, Vector3(-1.9 + k * 0.5, 0.75, w * 0.5 + 3.0 + k * 0.1), M.mat(Color(0.8, 0.8, 0.7), 0.0, 0.9))
	var dinghy = M.sph(r, 0.5, Vector3(-w * 0.42, 0.3, w * 0.1), M.mat(Color(0.35, 0.25, 0.16), 0.0, 0.9), Vector3(0.9, 0.55, 2.2))
	dinghy.rotation.y = 0.5
	# Ausguck mit Laterne, Fahne und Totenkopf
	M.cyl(r, 0.06, 0.09, 4.2, Vector3(-w * 0.3, 2.1, -w * 0.3), M.dark(), Vector3.ZERO, 6)
	M.box(r, Vector3(0.9, 0.08, 0.9), Vector3(-w * 0.3, 4.2, -w * 0.3), wood)
	for sx in [-0.4, 0.4]:
		M.box(r, Vector3(0.04, 0.4, 0.04), Vector3(-w * 0.3 + sx, 4.4, -w * 0.3), M.dark())
	var lamp = M.sph(r, 0.14, Vector3(-w * 0.3, 4.45, -w * 0.3), M.glow(Color(1.0, 0.8, 0.4), 4.0))
	D.anim(out, {"t": "blink", "n": lamp, "p": 1.8, "o": 0.0})
	D.flag(r, Vector3(-w * 0.3, 4.2, -w * 0.3), 1.6, Color(0.06, 0.06, 0.06), out)
	_lamp(r, Vector3(1.5, 0.3, w * 0.5 + 4.5), Color(1.0, 0.75, 0.4))
	out["height"] = 3.6
