extends RefCounted
## Fraktionsarchitektur: eigene Gebäudeformen je Fraktion und Rolle.
##   Westbund     – Glas, Stahl, Kuppeln, Leuchtbänder, Schildpylone, Drohnenbuchten
##   Rote Allianz – Sichtbeton, Schlote, Kühltürme, Sterne, Lautsprecher, Kasernenblöcke
##   Schattenfront – Felsversteck, Zelte, Container, Wellblech, Schrottberge, Tarnnetze
## Vorne (Ausgang für Einheiten) ist +Z.

const M = preload("res://scripts/models.gd")
const D = preload("res://scripts/arch_detail.gd")

static func build(r: Node3D, faction: String, role: String, w: float, pc: Material, wl: Material, out: Dictionary) -> bool:
	var fn = "_%s_%s" % [faction, role]
	match fn:
		"_west_hq": D.west_hq(r, w, pc, wl, out)
		"_west_power": _west_power(r, w, pc, wl, out)
		"_west_supply": _west_supply(r, w, pc, wl, out)
		"_west_barracks": _west_barracks(r, w, pc, wl, out)
		"_west_factory": D.west_factory(r, w, pc, wl, out)
		"_west_airfield": _west_airfield(r, w, pc, wl, out)
		"_west_tech": _west_tech(r, w, pc, wl, out)
		"_red_hq": D.red_hq(r, w, pc, wl, out)
		"_red_power": _red_power(r, w, pc, wl, out)
		"_red_supply": _red_supply(r, w, pc, wl, out)
		"_red_barracks": _red_barracks(r, w, pc, wl, out)
		"_red_factory": D.red_factory(r, w, pc, wl, out)
		"_red_airfield": _red_airfield(r, w, pc, wl, out)
		"_red_tech": _red_tech(r, w, pc, wl, out)
		"_shadow_hq": D.shadow_hq(r, w, pc, wl, out)
		"_shadow_supply": _shadow_supply(r, w, pc, wl, out)
		"_shadow_barracks": _shadow_barracks(r, w, pc, wl, out)
		"_shadow_factory": D.shadow_factory(r, w, pc, wl, out)
		"_shadow_tech": _shadow_tech(r, w, pc, wl, out)
		_:
			return false
	return true

# ---------------------------------------------------------------- Bausteine

static func _glass() -> Material:
	return M.mat(Color(0.08, 0.16, 0.24), 0.9, 0.06)

static func _cyan(e := 3.0) -> Material:
	return M.glow(Color(0.35, 0.8, 1.0), e)

static func _warm(e := 2.5) -> Material:
	return M.glow(Color(1.0, 0.82, 0.5), e)

static func prism(p: Node3D, wd: float, h: float, l: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	## Dreiecksprisma entlang Z (Satteldach, Zelt).
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a = Vector3(-wd * 0.5, 0, 0)
	var b = Vector3(wd * 0.5, 0, 0)
	var c = Vector3(0, h, 0)
	var z0 = Vector3(0, 0, -l * 0.5)
	var z1 = Vector3(0, 0, l * 0.5)
	for tri in [[a + z1, b + z1, c + z1], [b + z0, a + z0, c + z0]]:
		for v in tri:
			st.add_vertex(v)
	for q in [[a, c], [c, b], [b, a]]:
		var p0: Vector3 = q[0]
		var p1: Vector3 = q[1]
		for v in [p0 + z0, p1 + z0, p1 + z1, p0 + z0, p1 + z1, p0 + z1]:
			st.add_vertex(v)
	st.generate_normals()
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func _container(p: Node3D, pos: Vector3, rot_y: float, col: Color) -> void:
	var m = M.mat(col, 0.5, 0.65)
	var n = M.node(p, pos)
	n.rotation.y = rot_y
	M.box(n, Vector3(1.2, 1.25, 2.9), Vector3(0, 0.62, 0), m)
	for i in 6:
		M.box(n, Vector3(1.24, 1.1, 0.04), Vector3(0, 0.62, -1.25 + i * 0.5), M.mat(col.darkened(0.25), 0.5, 0.7))
	M.box(n, Vector3(1.1, 1.1, 0.04), Vector3(0, 0.62, 1.46), M.mat(col.darkened(0.35), 0.5, 0.7))

static func _wreck(p: Node3D, pos: Vector3, rot: Vector3) -> void:
	var rust = M.mat(Color(0.3, 0.17, 0.09), 0.4, 0.85)
	var n = M.node(p, pos)
	n.rotation = rot
	M.box(n, Vector3(1.8, 0.7, 3.2), Vector3(0, 0.35, 0), rust)
	M.box(n, Vector3(1.2, 0.5, 1.4), Vector3(0, 0.95, -0.3), M.mat(Color(0.22, 0.18, 0.14), 0.5, 0.8), Vector3(0.1, 0.4, 0.15))
	M.cyl(n, 0.07, 0.07, 1.8, Vector3(0.1, 1.1, 0.8), rust, Vector3(PI / 2 - 0.3, 0.2, 0), 6)

static func _searchlight(p: Node3D, pos: Vector3) -> void:
	M.cyl(p, 0.08, 0.1, pos.y, Vector3(pos.x, pos.y * 0.5, pos.z), M.dark(), Vector3.ZERO, 6)
	M.cyl(p, 0.25, 0.18, 0.4, pos + Vector3(0, 0.1, 0.1), M.steel(), Vector3(PI / 2 - 0.5, 0, 0), 10)
	M.cyl(p, 0.2, 0.2, 0.03, pos + Vector3(0, 0.2, 0.31), _warm(8.0), Vector3(PI / 2 - 0.5, 0, 0), 10)

static func _dish(p: Node3D, pos: Vector3, rad: float) -> Node3D:
	var n = M.node(p, pos)
	M.cyl(n, 0.08, 0.12, 1.2, Vector3(0, 0.6, 0), M.steel(), Vector3.ZERO, 8)
	var d = M.node(n, Vector3(0, 1.3, 0))
	d.rotation.x = -0.7
	M.cyl(d, rad, rad * 0.3, rad * 0.35, Vector3.ZERO, M.steel(), Vector3.ZERO, 16)
	M.cyl(d, 0.03, 0.03, rad * 0.9, Vector3(0, rad * 0.45, 0), M.dark(), Vector3.ZERO, 4)
	return n

# ================================================================ WESTBUND

static func _west_power(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Fusionsreaktor: Plasmakugel in Torusring, vier Pylone, Kühlleitungen
	M.cyl(r, w * 0.46, w * 0.5, 0.6, Vector3(0, 0.3, 0), wl, Vector3.ZERO, 8)
	M.sph(r, 0.8, Vector3(0, 1.9, 0), M.glow(Color(0.5, 0.85, 1.0), 7.0))
	var ring = M.node(r, Vector3(0, 1.9, 0))
	var tm = TorusMesh.new()
	tm.inner_radius = 1.25
	tm.outer_radius = 1.6
	tm.rings = 28
	tm.ring_segments = 10
	var ti = MeshInstance3D.new()
	ti.mesh = tm
	ti.material_override = M.steel()
	ring.add_child(ti)
	ring.rotation.x = 0.35
	out["spin"] = ring
	for i in 4:
		var a = PI / 4 + i * PI / 2
		var p = Vector3(cos(a), 0, sin(a)) * (w * 0.38)
		M.box(r, Vector3(0.35, 3.2, 0.35), p + Vector3(0, 1.6, 0), pc)
		M.box(r, Vector3(0.12, 0.12, 0.12), p + Vector3(0, 3.25, 0), _cyan(6.0))
		M.cyl(r, 0.12, 0.12, w * 0.3, p * 0.55 + Vector3(0, 0.75, 0), M.steel(), Vector3(PI / 2, -a + PI / 2, 0), 8)
	out["height"] = 3.6

static func _west_supply(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Logistikhalle mit Glasfront, Roboterarm, Containern in Teamfarbe
	M.box(r, Vector3(w * 0.62, 2.4, w * 0.6), Vector3(-w * 0.15, 1.2, -w * 0.12), wl)
	M.box(r, Vector3(w * 0.64, 0.15, w * 0.62), Vector3(-w * 0.15, 2.45, -w * 0.12), pc, Vector3(0.08, 0, 0))
	M.box(r, Vector3(w * 0.55, 1.6, 0.06), Vector3(-w * 0.15, 0.9, w * 0.18 + 0.01), _glass())
	M.box(r, Vector3(w * 0.6, 0.06, 0.08), Vector3(-w * 0.15, 1.75, w * 0.19), _cyan())
	var arm = M.node(r, Vector3(w * 0.32, 0, w * 0.2))
	M.cyl(arm, 0.3, 0.4, 0.4, Vector3(0, 0.2, 0), M.steel())
	M.box(arm, Vector3(0.25, 1.8, 0.25), Vector3(0, 1.2, 0), M.paint(Color.WHITE), Vector3(0, 0, 0.3))
	M.box(arm, Vector3(1.4, 0.2, 0.2), Vector3(-0.5, 2.0, 0), M.paint(Color.WHITE), Vector3(0, 0, -0.4))
	_container(r, Vector3(w * 0.32, 0, -w * 0.25), 0.0, M._team.lerp(Color(0.5, 0.5, 0.5), 0.3))
	_container(r, Vector3(w * 0.32, 1.25, -w * 0.25), 0.05, Color(0.75, 0.76, 0.78))
	out["height"] = 2.8

static func _west_barracks(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Zwei Wohnkapseln (liegende Zylinder) mit Glasgang
	for sx in [-1, 1]:
		var c = M.cyl(r, w * 0.17, w * 0.17, w * 0.75, Vector3(sx * w * 0.24, w * 0.15, -0.2), wl, Vector3(PI / 2, 0, 0), 14)
		c.scale = Vector3(1, 1, 0.85)
		M.box(r, Vector3(w * 0.06, 0.08, w * 0.7), Vector3(sx * w * 0.24, w * 0.3, -0.2), pc)
		for k in 4:
			M.box(r, Vector3(0.04, 0.3, 0.5), Vector3(sx * (w * 0.24 + w * 0.16 * 0.95), w * 0.16, -w * 0.28 + k * w * 0.18), _warm())
	M.box(r, Vector3(w * 0.2, 1.3, 1.2), Vector3(0, 0.65, 0.2), _glass())
	M.box(r, Vector3(w * 0.22, 0.1, 1.3), Vector3(0, 1.35, 0.2), pc)
	# Trainingsring (Hologramm)
	M.cyl(r, 0.9, 0.9, 0.04, Vector3(0, 0.12, w * 0.38), _cyan(2.0), Vector3.ZERO, 24)
	out["height"] = w * 0.33

static func _west_airfield(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	M.box(r, Vector3(w, 0.25, w), Vector3(0, 0.12, 0), M.mat(Color(0.18, 0.19, 0.21), 0.2, 0.7))
	for pz in [-w * 0.2, w * 0.22]:
		M.cyl(r, 1.6, 1.6, 0.03, Vector3(-w * 0.12, 0.26, pz), M.mat(Color(0.85, 0.85, 0.85), 0, 0.6), Vector3.ZERO, 32)
		M.cyl(r, 1.45, 1.45, 0.04, Vector3(-w * 0.12, 0.27, pz), M.mat(Color(0.18, 0.19, 0.21), 0.2, 0.7), Vector3.ZERO, 32)
		for i in 8:
			var a = TAU * i / 8.0
			M.sph(r, 0.07, Vector3(-w * 0.12 + cos(a) * 1.7, 0.3, pz + sin(a) * 1.7), _cyan(6.0))
	# Kontrollturm aus Glas
	M.cyl(r, 0.6, 0.7, 3.5, Vector3(w * 0.36, 1.75, -w * 0.32), wl, Vector3.ZERO, 8)
	M.cyl(r, 1.2, 0.9, 1.0, Vector3(w * 0.36, 4.0, -w * 0.32), _glass(), Vector3.ZERO, 8)
	M.cyl(r, 1.3, 1.3, 0.15, Vector3(w * 0.36, 4.55, -w * 0.32), pc, Vector3.ZERO, 8)
	out["spin"] = _dish(r, Vector3(w * 0.36, 4.6, -w * 0.32), 0.5)
	out["height"] = 4.8

static func _west_tech(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Forschungskuppel mit Schildpylonen (Energieschilde)
	M.cyl(r, w * 0.45, w * 0.48, 0.8, Vector3(0, 0.4, 0), wl, Vector3.ZERO, 12)
	M.sph(r, w * 0.36, Vector3(0, 0.8, 0), _glass(), Vector3(1, 0.8, 1), true)
	M.sph(r, w * 0.37, Vector3(0, 0.79, 0), M.mat(Color(0.4, 0.8, 1.0, 1), 0.0, 0.2, 0.6), Vector3(1, 0.81, 1), true).transparency = 0.75
	M.sph(r, 0.4, Vector3(0, 1.4, 0), _cyan(5.0))
	for i in 3:
		var a = TAU * i / 3.0 + 0.5
		var p = Vector3(cos(a), 0, sin(a)) * (w * 0.43)
		M.cyl(r, 0.08, 0.2, 2.6, p + Vector3(0, 1.3, 0), M.steel(), Vector3.ZERO, 6)
		M.sph(r, 0.22, p + Vector3(0, 2.7, 0), _cyan(6.0))
	out["height"] = 3.0

# ================================================================ ROTE ALLIANZ

static func _cooling_tower(r: Node3D, pos: Vector3, s: float) -> void:
	var c = M.concrete()
	M.cyl(r, 1.2 * s, 1.75 * s, 2.2 * s, pos + Vector3(0, 1.1 * s, 0), c, Vector3.ZERO, 18)
	M.cyl(r, 1.15 * s, 1.2 * s, 0.7 * s, pos + Vector3(0, 2.55 * s, 0), c, Vector3.ZERO, 18)
	M.cyl(r, 1.35 * s, 1.15 * s, 1.5 * s, pos + Vector3(0, 3.65 * s, 0), c, Vector3.ZERO, 18)
	M.cyl(r, 1.3 * s, 1.3 * s, 0.05, pos + Vector3(0, 4.38 * s, 0), M.dark(), Vector3.ZERO, 18)
	M.box(r, Vector3(2.6 * s, 0.3, 0.1), pos + Vector3(0, 3.0 * s, 1.17 * s), M.paint(Color.WHITE))

static func _red_power(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Kohlekraftwerk: Kühlturm, Schlot, Kohlehalde, Förderband
	_cooling_tower(r, Vector3(-w * 0.18, 0, -w * 0.15), 0.85)
	M.box(r, Vector3(w * 0.35, 1.8, w * 0.42), Vector3(w * 0.28, 0.9, -w * 0.18), wl)
	M.box(r, Vector3(w * 0.37, 0.15, w * 0.44), Vector3(w * 0.28, 1.85, -w * 0.18), pc)
	M.cyl(r, 0.28, 0.38, 5.5, Vector3(w * 0.36, 2.75, -w * 0.32), M.mat(Color(0.32, 0.22, 0.18), 0.0, 0.9), Vector3.ZERO, 10)
	for k in 3:
		M.cyl(r, 0.4, 0.4, 0.12, Vector3(w * 0.36, 4.2 + k * 0.4, -w * 0.32), M.paint(Color.WHITE) if k % 2 == 0 else M.dark(), Vector3.ZERO, 10)
	var coal = M.sph(r, 1.1, Vector3(w * 0.15, 0.0, w * 0.3), M.mat(Color(0.05, 0.05, 0.05), 0.1, 0.95), Vector3(1.2, 0.5, 0.8), true)
	coal.rotation.y = 0.4
	M.box(r, Vector3(0.4, 0.1, 2.8), Vector3(w * 0.22, 1.0, w * 0.08), M.dark(), Vector3(0.45, 0, 0))
	out["smoke"] = [Vector3(-w * 0.18, 3.8, -w * 0.15), Vector3(w * 0.36, 5.6, -w * 0.32)]
	out["height"] = 4.2

static func _red_supply(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Versorgungsdepot: Betonlager und zwei große Tanks
	M.box(r, Vector3(w * 0.55, 2.2, w * 0.55), Vector3(-w * 0.18, 1.1, -w * 0.15), wl)
	M.box(r, Vector3(w * 0.57, 0.14, w * 0.57), Vector3(-w * 0.18, 2.25, -w * 0.15), pc)
	M.box(r, Vector3(w * 0.35, 1.6, 0.1), Vector3(-w * 0.18, 0.8, w * 0.13), M.dark())
	for k in 2:
		var p = Vector3(w * 0.3, 0, -w * 0.3 + k * w * 0.35)
		M.cyl(r, 0.85, 0.85, 2.4, p + Vector3(0, 1.2, 0), M.steel(), Vector3.ZERO, 16)
		M.sph(r, 0.85, p + Vector3(0, 2.4, 0), M.steel(), Vector3(1, 0.35, 1), true)
		M.box(r, Vector3(0.05, 1.6, 0.05), p + Vector3(0.86, 1.3, 0), M.dark())
		M.box(r, Vector3(1.75, 0.3, 0.02), p + Vector3(0, 1.6, 0.86), pc)
	out["height"] = 2.8

static func _red_barracks(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Zwei lange Kasernenblöcke (Massenaushebung) mit Exerzierplatz und Wachturm
	for sx in [-1, 1]:
		M.box(r, Vector3(w * 0.3, 1.8, w * 0.82), Vector3(sx * w * 0.3, 0.9, -0.1), wl)
		prism(r, w * 0.34, 0.8, w * 0.86, Vector3(sx * w * 0.3, 1.8, -0.1), pc)
		for k in 4:
			M.box(r, Vector3(0.05, 0.5, 0.45), Vector3(sx * (w * 0.3 - w * 0.15) - sx * 0.01, 1.1, -w * 0.32 + k * w * 0.2), _warm(1.5))
	# Exerzierplatz-Linien
	for k in 3:
		M.box(r, Vector3(w * 0.22, 0.02, 0.06), Vector3(0, 0.03, -w * 0.25 + k * w * 0.2), M.mat(Color(0.85, 0.85, 0.8), 0, 0.7))
	# Wachturm
	for sx in [-0.4, 0.4]:
		for sz in [-0.4, 0.4]:
			M.box(r, Vector3(0.12, 3.6, 0.12), Vector3(sx, 1.8, -w * 0.4 + sz), M.dark())
	M.box(r, Vector3(1.3, 0.12, 1.3), Vector3(0, 3.6, -w * 0.4), M.dark())
	prism(r, 1.5, 0.6, 1.5, Vector3(0, 4.3, -w * 0.4), pc)
	_searchlight(r, Vector3(0.4, 3.75, -w * 0.4 + 0.4))
	out["height"] = 3.2

static func _red_airfield(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	M.box(r, Vector3(w, 0.25, w), Vector3(0, 0.12, 0), M.concrete())
	for k in 4:
		M.box(r, Vector3(w, 0.02, 0.05), Vector3(0, 0.26, -w * 0.4 + k * w * 0.27), M.dark())
	M.cyl(r, 1.6, 1.6, 0.03, Vector3(-w * 0.15, 0.27, w * 0.1), M.mat(Color(0.9, 0.8, 0.1), 0, 0.6), Vector3.ZERO, 24)
	M.cyl(r, 1.45, 1.45, 0.04, Vector3(-w * 0.15, 0.28, w * 0.1), M.concrete(), Vector3.ZERO, 24)
	load("res://scripts/models.gd")._star(r, Vector3(-w * 0.15, 0.31, w * 0.1), 1.1, pc).rotation.x = -PI / 2
	# Bunkerhangar (gewölbter Beton)
	var hg = M.cyl(r, 1.8, 1.8, 3.5, Vector3(w * 0.25, 0.25, -w * 0.25), M.concrete(), Vector3(PI / 2, 0, 0), 14)
	hg.scale = Vector3(1, 1, 0.85)
	M.box(r, Vector3(2.4, 1.4, 0.1), Vector3(w * 0.25, 0.9, -w * 0.25 + 1.76), M.dark())
	out["height"] = 2.6

static func _red_tech(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Propagandazentrum: Turm mit Lautsprecherkranz und Großbildwand (Aura)
	M.box(r, Vector3(w * 0.7, 1.4, w * 0.6), Vector3(0, 0.7, -0.3), wl)
	M.box(r, Vector3(1.2, 5.0, 1.2), Vector3(0, 3.5, -0.6), wl)
	M.box(r, Vector3(1.3, 0.15, 1.3), Vector3(0, 6.05, -0.6), pc)
	for i in 4:
		var a = i * PI / 2
		var dir = Vector3(sin(a), 0, cos(a))
		M.cyl(r, 0.12, 0.42, 0.7, Vector3(0, 5.5, -0.6) + dir * 0.85, M.steel(), Vector3(PI / 2, a, 0), 10)
		M.cyl(r, 0.12, 0.42, 0.7, Vector3(0, 4.6, -0.6) + dir * 0.85, M.steel(), Vector3(PI / 2, a, 0), 10)
	# Großbildwand mit Stern
	M.box(r, Vector3(w * 0.6, 2.0, 0.15), Vector3(0, 2.4, w * 0.02), M.dark())
	M.box(r, Vector3(w * 0.55, 1.8, 0.05), Vector3(0, 2.4, w * 0.02 + 0.08), M.glow(Color(0.8, 0.12, 0.08), 1.6))
	load("res://scripts/models.gd")._star(r, Vector3(0, 2.4, w * 0.02 + 0.12), 0.7, M.glow(Color(1.0, 0.85, 0.2), 3.0))
	M.cyl(r, 0.04, 0.04, 2.5, Vector3(0, 7.3, -0.6), M.dark(), Vector3.ZERO, 6)
	M.sph(r, 0.12, Vector3(0, 8.6, -0.6), M.glow(Color(1, 0.15, 0.1), 8.0))
	out["height"] = 6.2

# ================================================================ SCHATTENFRONT

static func _shadow_supply(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Umschlagplatz: Marktstände mit Planen, Kistenstapel, Container
	for k in 3:
		var p = Vector3(-w * 0.3 + k * w * 0.3, 0, -w * 0.22)
		for sx in [-0.8, 0.8]:
			for sz in [-0.7, 0.7]:
				M.box(r, Vector3(0.1, 2.0, 0.1), p + Vector3(sx, 1.0, sz), M.mat(Color(0.35, 0.24, 0.13), 0, 0.9))
		M.box(r, Vector3(1.9, 0.05, 1.7), p + Vector3(0, 2.05, 0), pc, Vector3(0.15 * (k - 1), 0, 0.1))
		M.box(r, Vector3(1.4, 0.7, 0.9), p + Vector3(0, 0.35, 0), M.mat(Color(0.45, 0.33, 0.18), 0, 0.9))
	_container(r, Vector3(w * 0.3, 0, w * 0.22), PI / 2, Color(0.25, 0.4, 0.55))
	for i in 5:
		M.box(r, Vector3(0.7, 0.6, 0.7), Vector3(-w * 0.35 + (i % 3) * 0.75, 0.3 + (i / 3) * 0.6, w * 0.25), M.mat(Color(0.5, 0.38, 0.2), 0, 0.9), Vector3(0, 0.2 * i, 0))
	out["height"] = 2.4

static func _shadow_barracks(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Ausbildungslager: Zelte, Lagerfeuer, Übungspuppen
	prism(r, 2.4, 1.9, w * 0.55, Vector3(-w * 0.24, 0, -w * 0.15), pc)
	prism(r, 2.0, 1.6, w * 0.45, Vector3(w * 0.26, 0, -w * 0.2), M.mat(Color(0.4, 0.38, 0.25), 0, 0.95))
	M.box(r, Vector3(0.8, 1.4, 0.02), Vector3(-w * 0.24, 0.7, -w * 0.15 + w * 0.275 + 0.01), M.mat(Color(0.05, 0.05, 0.05), 0, 1))
	# Feuerstelle
	for i in 6:
		var a = TAU * i / 6.0
		M.box(r, Vector3(0.25, 0.18, 0.2), Vector3(cos(a) * 0.45, 0.09, w * 0.22 + sin(a) * 0.45), M.mat(Color(0.35, 0.33, 0.3), 0, 1), Vector3(0, a, 0))
	load("res://scripts/fx.gd").flame(r, Vector3(0, 0.12, w * 0.22), 1.0)
	# Übungspuppen
	for k in 2:
		var p = Vector3(w * 0.3, 0, w * 0.15 + k * 0.9)
		M.box(r, Vector3(0.08, 1.4, 0.08), p + Vector3(0, 0.7, 0), M.mat(Color(0.35, 0.24, 0.13), 0, 0.9))
		M.box(r, Vector3(0.45, 0.6, 0.25), p + Vector3(0, 1.1, 0), M.mat(Color(0.6, 0.55, 0.4), 0, 0.95))
	out["height"] = 2.0

static func _shadow_tech(r: Node3D, w: float, pc: Material, wl: Material, out: Dictionary) -> void:
	# Schwarzmarkt: gestapelte Container unter Planen, Lichterketten
	_container(r, Vector3(-w * 0.2, 0, -w * 0.15), 0.0, Color(0.55, 0.2, 0.12))
	_container(r, Vector3(w * 0.05, 0, -w * 0.15), 0.0, Color(0.2, 0.35, 0.25))
	_container(r, Vector3(-w * 0.08, 1.25, -w * 0.15), 0.1, Color(0.6, 0.5, 0.15))
	_container(r, Vector3(w * 0.32, 0, w * 0.1), PI / 2, Color(0.25, 0.3, 0.45))
	M.box(r, Vector3(w * 0.6, 0.05, 2.0), Vector3(-w * 0.05, 2.9, w * 0.12), pc, Vector3(0.18, 0, 0))
	for i in 10:
		var x = -w * 0.35 + i * w * 0.07
		M.sph(r, 0.05, Vector3(x, 2.4 + sin(i * 1.3) * 0.08, w * 0.3), M.glow([Color(1, 0.3, 0.2), Color(1, 0.85, 0.2), Color(0.3, 1, 0.4)][i % 3], 6.0))
	M.box(r, Vector3(1.0, 0.8, 0.6), Vector3(-w * 0.3, 0.4, w * 0.28), M.mat(Color(0.45, 0.33, 0.18), 0, 0.9))
	out["height"] = 2.6
