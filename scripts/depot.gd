extends Node3D
## Rohstoffvorkommen: Nachschubdepot (Holzkisten, Paletten), Holzlager (Stammstapel), Erzfels mit Lore (Eisen),
## Ölquelle mit nickender Pumpe, Fässern und Rohrleitung (Öl) und Goldader in hellem Quarzgestein.
## Oberflächen: Farbtexturen aus models/resources (Entwurfsblatt models/source/resources/direction-resources.png),
## Gesteinsformen aus verformten Kugeln mit Facetten.

var is_unit = false
var is_building = false
var is_depot = true
var alive = true
var flying = false
var owner_id = -1
var radius = 2.6
var kind = "supply"
var supply = 40000.0
var max_supply = 40000.0
var def = {"name": "Nachschubdepot", "cost": 0}
var crates: Array = []
var selected = false
var _beam: Node3D = null
var _t = 0.0
static var _rocks: Dictionary = {}

func _ready() -> void:
	set_process(kind == "oil")

func _process(delta: float) -> void:
	if _beam != null:
		_t += delta
		_beam.rotation.x = sin(_t * 1.6) * 0.22 * (1.0 if supply > 0.0 else 0.0)

# ---------------------------------------------------------------- Hilfen

func _mi(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	add_child(mi)
	return mi

func _box(size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm = BoxMesh.new()
	bm.size = size
	return _mi(bm, m, pos, rot)

func _cyl(rt: float, rb: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var cm = CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	return _mi(cm, m, pos, rot)

## Unregelmäßiger Felsbrocken: Kugel mit Rauschen verformt, flache Facetten.
func _rock(rad: float, seed_: int, squash := 0.85) -> ArrayMesh:
	var key = "%d_%d_%d" % [int(rad * 100), seed_, int(squash * 100)]
	if _rocks.has(key):
		return _rocks[key]
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 7
	var arrays = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise = FastNoiseLite.new()
	noise.seed = seed_
	noise.frequency = 1.1
	for i in verts.size():
		var v = verts[i]
		var d = 1.0 + noise.get_noise_3dv(v * 1.8) * 0.55 + noise.get_noise_3dv(v * 4.5) * 0.12
		verts[i] = Vector3(v.x * d * rad, max(v.y * d * rad * squash, -rad * 0.25 * squash), v.z * d * rad)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st = SurfaceTool.new()
	st.create_from(am, 0)
	st.deindex()
	st.generate_normals()
	var out = st.commit()
	_rocks[key] = out
	return out

func _tex(id: String, tint := Color.WHITE, rough := 0.9, scale := 0.45, vein := 0.0, metal := 0.0, uv := false) -> ShaderMaterial:
	return Game.resource_material(id, tint, rough, scale, vein, metal, uv)

func _pad(col: Color, rad := 3.9) -> void:
	_cyl(rad, rad + 0.1, 0.22, Game.fog_material(col, 0.97), Vector3(0, 0.0, 0), Vector3.ZERO, 18)

func build() -> void:
	def = {"name": Defs.RES_NAMES[kind] + ("depot" if kind == "supply" else "vorkommen"), "cost": 0}
	match kind:
		"wood":
			_build_wood()
		"iron":
			_build_iron()
		"oil":
			_build_oil()
		"gold":
			_build_gold()
		_:
			_build_crates()

# ---------------------------------------------------------------- Nachschub: Holzkisten, Paletten, Plane

func _build_crates() -> void:
	_box(Vector3(6.2, 0.22, 6.2), Game.fog_material(Color(0.42, 0.41, 0.4), 0.95), Vector3(0, 0.0, 0))
	var wood = _tex("crate_wood", Color(1, 1, 1), 0.85, 0.7)
	var wood2 = _tex("crate_wood", Color(0.78, 0.82, 0.7), 0.85, 0.7)
	var strap = Game.fog_material(Color(0.12, 0.11, 0.1), 0.7)
	var bm = BoxMesh.new()
	bm.size = Vector3(1.05, 1.05, 1.05)
	for y in 3:
		for z in 4:
			for x in 4:
				if y == 2 and (x == 0 or x == 3 or z == 0 or z == 3):
					continue
				if y == 1 and (x + z) % 3 == 0 and (x == 0 or z == 0):
					continue
				var pos = Vector3(-1.65 + x * 1.1, 0.78 + y * 1.08, -1.65 + z * 1.1)
				var c = _mi(bm, wood if (x + y + z) % 4 != 0 else wood2, pos)
				c.rotation.y = randf_range(-0.1, 0.1)
				crates.append(c)
				if (x + y + z) % 3 == 0:
					var s = _box(Vector3(1.09, 0.08, 1.09), strap, pos + Vector3(0, 0.0, 0))
					s.rotation.y = c.rotation.y
					s.reparent(c, true)
	# Palette mit Plane davor, Fässer daneben
	_box(Vector3(1.6, 0.14, 1.6), wood, Vector3(2.6, 0.3, -1.6))
	var tarp = _box(Vector3(1.5, 1.0, 1.5), Game.fog_material(Color(0.5, 0.47, 0.34), 0.95), Vector3(2.6, 0.9, -1.6), Vector3(0, 0.3, 0))
	crates.append(tarp)
	for s2 in [-0.35, 0.35]:
		_box(Vector3(1.56, 0.06, 0.07), strap, Vector3(2.6, 1.0, -1.6 + s2), Vector3(0, 0.3, 0))
	var barrel = _tex("rust_metal", Color(0.8, 0.85, 0.9), 0.55, 0.9, 0.0, 0.35)
	for b in 2:
		crates.append(_cyl(0.4, 0.4, 0.95, barrel, Vector3(-2.8 + b * 0.85, 0.7, 2.6), Vector3.ZERO, 14))

# ---------------------------------------------------------------- Holz: Stammstapel mit Rinde und Schnittfläche

func _log(pos: Vector3, rad: float, length: float, bark: ShaderMaterial, cut: ShaderMaterial, along_z := true) -> MeshInstance3D:
	var cm = CylinderMesh.new()
	cm.top_radius = rad * 0.94
	cm.bottom_radius = rad
	cm.height = length
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	var lg = _mi(cm, bark, pos, Vector3(PI / 2, 0, 0) if along_z else Vector3.ZERO)
	for e in [-1.0, 1.0]:
		var dm = CylinderMesh.new()
		dm.top_radius = rad * 0.94 if e > 0 else rad
		dm.bottom_radius = dm.top_radius
		dm.height = 0.03
		dm.radial_segments = 12
		var d = MeshInstance3D.new()
		d.mesh = dm
		d.material_override = cut
		d.position = Vector3(0, e * length * 0.5, 0)
		lg.add_child(d)
	return lg

func _build_wood() -> void:
	_pad(Color(0.27, 0.21, 0.14))
	var bark = _tex("bark", Color(1.9, 1.6, 1.35), 0.95, 0.9)
	var cut = _tex("log_end", Color(1, 1, 1), 0.9, 1.0, 0.0, 0.0, true)
	var dark = Game.fog_material(Color(0.2, 0.15, 0.1), 0.9)
	var leaf = Game.fog_material(Color(0.1, 0.27, 0.13), 0.95)
	var dust = Game.fog_material(Color(0.72, 0.58, 0.36), 0.97)
	var rows = [5, 4, 3]
	for r in 3:
		for i in rows[r]:
			var x = -(rows[r] - 1) * 0.37 + i * 0.74
			var len = 4.4 - r * 0.2 + randf_range(-0.15, 0.15)
			var lg = _log(Vector3(x - 0.5, 0.52 + r * 0.62, randf_range(-0.1, 0.1)), 0.36 + randf_range(-0.03, 0.03), len, bark, cut)
			lg.rotation.z = randf_range(-0.03, 0.03)
			crates.append(lg)
	# Halteposten und Spanngurt an den Stapelenden
	for px in [-2.65, 1.65]:
		for pz in [-1.9, 1.9]:
			_cyl(0.09, 0.1, 2.0, dark, Vector3(px, 1.0, pz), Vector3.ZERO, 7)
	for pz in [-1.9, 1.9]:
		_box(Vector3(4.4, 0.06, 0.08), dark, Vector3(-0.5, 0.9, pz))
	# Sägespäne, Baumstumpf mit Axt, liegender Stamm
	for i in 9:
		var a = i * 0.8
		_cyl(0.34, 0.34, 0.03, dust, Vector3(2.2 + cos(a) * 0.9, 0.14, 1.2 + sin(a) * 0.9), Vector3.ZERO, 8)
	var stump = _cyl(0.42, 0.5, 0.55, bark, Vector3(2.7, 0.4, 2.0), Vector3.ZERO, 12)
	var top = _cyl(0.41, 0.41, 0.03, cut, Vector3(2.7, 0.69, 2.0), Vector3.ZERO, 12)
	_box(Vector3(0.07, 0.07, 0.8), dark, Vector3(2.55, 0.9, 2.0), Vector3(0.5, 0.3, 0))
	_box(Vector3(0.28, 0.22, 0.05), Game.fog_material(Color(0.55, 0.56, 0.6), 0.4), Vector3(2.48, 1.08, 1.7), Vector3(0.5, 0.3, 0))
	_log(Vector3(-3.2, 0.34, 2.3), 0.3, 3.0, bark, cut).rotation = Vector3(PI / 2, 0.35, 0)
	# stehende Fichten dahinter
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 2.0
	cone.radial_segments = 8
	for i in 5:
		var a2 = i * 1.26 + 0.4
		var base = Vector3(cos(a2) * 3.9, 0.0, sin(a2) * 3.9 - 1.2)
		_cyl(0.12, 0.17, 1.0, bark, base + Vector3(0, 0.5, 0), Vector3.ZERO, 7)
		var sc = 0.9 + randf() * 0.4
		for tier in 3:
			_mi(cone, leaf, base + Vector3(0, 1.1 + tier * 0.85 * sc, 0), Vector3.ZERO, Vector3(1.15 - tier * 0.3, 1.0 * sc, 1.15 - tier * 0.3) * sc)

# ---------------------------------------------------------------- Eisen: Erzfelsen mit Rostadern, Lore auf Schienen

func _build_iron() -> void:
	_pad(Color(0.26, 0.24, 0.22))
	var rock = _tex("rock_iron", Color(1.45, 1.4, 1.35), 0.9, 0.5)
	var rock2 = _tex("rock_iron", Color(1.25, 1.15, 1.1), 0.85, 0.42)
	var metal = _tex("rust_metal", Color(1.35, 1.3, 1.3), 0.6, 0.8, 0.0, 0.3)
	var dark = Game.fog_material(Color(0.1, 0.1, 0.11), 0.7)
	crates.append(_mi(_rock(1.9, 3, 0.95), rock, Vector3(-0.6, 1.0, -0.8), Vector3(0, 0.6, 0)))
	for i in 7:
		var a = i * 0.9 + 0.3
		var rr = randf_range(0.6, 1.15)
		crates.append(_mi(_rock(rr, 11 + i, 0.8), rock if i % 2 == 0 else rock2, Vector3(-0.6 + cos(a) * (1.9 + (i % 3) * 0.35), 0.3 + rr * 0.2, -0.8 + sin(a) * (1.9 + (i % 3) * 0.35)), Vector3(0, randf() * 6.0, 0)))
	# lose Erzbrocken
	for i in 16:
		var a2 = i * 0.77
		var rr2 = randf_range(0.16, 0.3)
		crates.append(_mi(_rock(rr2, 40 + i, 0.8), rock2, Vector3(1.0 + cos(a2) * (1.2 + (i % 4) * 0.35), 0.18, 1.6 + sin(a2) * (1.0 + (i % 3) * 0.4)), Vector3(0, randf() * 6.0, 0)))
	# Schienen, Schwellen, Lore mit Erz
	for sx in [-0.4, 0.4]:
		_box(Vector3(0.1, 0.1, 5.4), metal, Vector3(2.4 + sx, 0.3, 1.0))
	for i in 8:
		_box(Vector3(1.3, 0.08, 0.16), dark, Vector3(2.4, 0.22, -1.2 + i * 0.7))
	var cart = Node3D.new()
	cart.position = Vector3(2.4, 0.0, 1.1)
	add_child(cart)
	var body = BoxMesh.new()
	body.size = Vector3(1.3, 0.65, 1.7)
	var bm = MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = metal
	bm.position = Vector3(0, 0.85, 0)
	cart.add_child(bm)
	for wx in [-0.55, 0.55]:
		for wz in [-0.55, 0.55]:
			var wh = CylinderMesh.new()
			wh.top_radius = 0.22
			wh.bottom_radius = 0.22
			wh.height = 0.1
			wh.radial_segments = 12
			var w = MeshInstance3D.new()
			w.mesh = wh
			w.material_override = dark
			w.position = Vector3(wx, 0.5, wz)
			w.rotation.z = PI / 2
			cart.add_child(w)
	for i in 6:
		var o = MeshInstance3D.new()
		o.mesh = _rock(randf_range(0.2, 0.32), 80 + i, 0.8)
		o.material_override = rock2
		o.position = Vector3(randf_range(-0.4, 0.4), 1.2, randf_range(-0.6, 0.6))
		cart.add_child(o)
		crates.append(o)
	# helle Metallflecken im Gestein
	var shiny = Game.fog_material(Color(0.75, 0.78, 0.85), 0.3)
	var fm = BoxMesh.new()
	fm.size = Vector3(0.14, 0.14, 0.14)
	for i in 8:
		var a3 = i * 0.8
		crates.append(_mi(fm, shiny, Vector3(-0.6 + cos(a3) * 1.7, 0.7 + (i % 3) * 0.5, -0.8 + sin(a3) * 1.7), Vector3(randf(), randf(), randf())))

# ---------------------------------------------------------------- Öl: Pumpe mit Pendelbalken, Teerlache, Fässer, Rohre

func _build_oil() -> void:
	_pad(Color(0.2, 0.18, 0.16), 4.2)
	var tar = _tex("oil_sludge", Color(0.7, 0.7, 0.72), 0.12, 0.7, 0.0, 0.25)
	_cyl(2.5, 2.5, 0.05, tar, Vector3(0.7, 0.2, 0.9), Vector3.ZERO, 22)
	_cyl(1.7, 1.7, 0.06, tar, Vector3(1.9, 0.2, 0.1), Vector3.ZERO, 16)
	var steel = _tex("rust_metal", Color(1.5, 1.3, 1.2), 0.55, 0.8, 0.0, 0.3)
	var dark = Game.fog_material(Color(0.1, 0.1, 0.12), 0.7)
	var pipe = Game.fog_material(Color(0.55, 0.58, 0.6), 0.35)
	_box(Vector3(2.2, 0.4, 3.4), dark, Vector3(-1.4, 0.4, -0.6))
	# A-Gestell der Pumpe
	for sz in [-0.55, 0.55]:
		_box(Vector3(0.14, 3.0, 0.14), steel, Vector3(-1.75, 1.9, -0.6 + sz), Vector3(0, 0, -0.18))
		_box(Vector3(0.14, 3.0, 0.14), steel, Vector3(-1.05, 1.9, -0.6 + sz), Vector3(0, 0, 0.18))
	for ty in [0.9, 1.7, 2.5]:
		_box(Vector3(0.7 - ty * 0.12, 0.07, 1.2), steel, Vector3(-1.4, ty + 0.2, -0.6))
	_beam = Node3D.new()
	_beam.position = Vector3(-1.4, 3.3, -0.6)
	add_child(_beam)
	var arm = BoxMesh.new()
	arm.size = Vector3(0.3, 0.34, 4.2)
	var am = MeshInstance3D.new()
	am.mesh = arm
	am.material_override = steel
	_beam.add_child(am)
	var head = CylinderMesh.new()
	head.top_radius = 0.62
	head.bottom_radius = 0.62
	head.height = 0.3
	head.radial_segments = 14
	var hm = MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = steel
	hm.position = Vector3(0, -0.2, 2.1)
	hm.rotation.z = PI / 2
	_beam.add_child(hm)
	var wt = BoxMesh.new()
	wt.size = Vector3(0.7, 1.0, 0.6)
	var wm = MeshInstance3D.new()
	wm.mesh = wt
	wm.material_override = dark
	wm.position = Vector3(0, -0.3, -2.0)
	_beam.add_child(wm)
	_box(Vector3(0.5, 0.6, 0.7), dark, Vector3(-1.4, 0.85, -2.1))
	# Fässer mit Spannringen
	var barrel = _tex("rust_metal", Color(1.45, 1.3, 1.25), 0.55, 0.9, 0.0, 0.3)
	var band = Game.fog_material(Color(0.15, 0.14, 0.14), 0.5)
	for i in 5:
		var pos = Vector3(1.6 + (i % 3) * 1.05, 0.78, 2.3 - (i / 3) * 1.15)
		var b = _cyl(0.47, 0.47, 1.1, barrel, pos, Vector3.ZERO, 16)
		for by in [-0.28, 0.28]:
			var bd = _cyl(0.485, 0.485, 0.07, band, Vector3(0, by, 0), Vector3.ZERO, 16)
			bd.reparent(b, false)
			bd.position = Vector3(0, by, 0)
		crates.append(b)
	_cyl(0.47, 0.47, 1.1, barrel, Vector3(3.9, 0.55, 0.9), Vector3(0, 0.5, PI / 2), 16)
	# Rohrleitung mit Ventil und kleinem Tank
	_cyl(0.14, 0.14, 2.8, pipe, Vector3(-0.1, 0.55, 0.5), Vector3(0, 0, PI / 2), 10)
	_cyl(0.14, 0.14, 1.8, pipe, Vector3(1.3, 0.55, 1.4), Vector3(PI / 2, 0, 0), 10)
	_mi(SphereMesh.new(), pipe, Vector3(1.3, 0.55, 0.5), Vector3.ZERO, Vector3.ONE * 0.2)
	_cyl(0.17, 0.17, 0.05, Game.fog_material(Color(0.6, 0.12, 0.1), 0.5), Vector3(0.6, 0.78, 0.5), Vector3.ZERO, 12)
	_cyl(0.05, 0.05, 0.3, pipe, Vector3(0.6, 0.7, 0.5), Vector3.ZERO, 6)
	crates.append(_cyl(0.95, 0.95, 1.7, steel, Vector3(-3.1, 0.95, 1.8), Vector3.ZERO, 18))

# ---------------------------------------------------------------- Gold: Quarzfelsen mit Goldadern, Kiste mit Nuggets

func _build_gold() -> void:
	_pad(Color(0.34, 0.31, 0.26))
	var rock = _tex("rock_gold", Color(1, 1, 1), 0.88, 0.5, 0.85)
	var rock2 = _tex("rock_gold", Color(0.9, 0.88, 0.84), 0.85, 0.4, 0.85)
	var gold = Game.fog_material(Color(1.0, 0.8, 0.22), 0.22, 0.45)
	var wood = _tex("crate_wood", Color(1, 1, 1), 0.85, 0.7)
	var metal = Game.fog_material(Color(0.45, 0.46, 0.5), 0.45)
	crates.append(_mi(_rock(1.7, 21, 1.15), rock, Vector3(-0.4, 1.35, -0.7), Vector3(0, 0.4, 0)))
	for i in 6:
		var a = i * 1.05 + 0.2
		var rr = randf_range(0.55, 1.0)
		crates.append(_mi(_rock(rr, 31 + i, 0.9), rock if i % 2 == 0 else rock2, Vector3(-0.4 + cos(a) * 2.1, 0.25 + rr * 0.25, -0.7 + sin(a) * 2.1), Vector3(0, randf() * 6.0, 0)))
	# Goldadern: dünne leuchtende Scherben in den Fels eingelassen
	var vm = BoxMesh.new()
	vm.size = Vector3(0.12, 1.4, 0.6)
	for i in 12:
		var a2 = i * 0.8 + 0.5
		var v = _mi(vm, gold, Vector3(-0.4 + cos(a2) * 1.35, 0.9 + (i % 4) * 0.4, -0.7 + sin(a2) * 1.35), Vector3(randf_range(-0.4, 0.4), -a2, randf_range(-0.7, 0.7)))
		v.scale = Vector3.ONE * randf_range(0.8, 1.5)
		crates.append(v)
	# offene Kiste mit Nuggets
	var cx = Vector3(2.5, 0.0, 1.4)
	_box(Vector3(1.5, 0.1, 1.1), wood, cx + Vector3(0, 0.15, 0))
	for sz in [-0.55, 0.55]:
		_box(Vector3(1.5, 0.6, 0.08), wood, cx + Vector3(0, 0.45, sz))
	for sx in [-0.75, 0.75]:
		_box(Vector3(0.08, 0.6, 1.1), wood, cx + Vector3(sx, 0.45, 0))
	for k in [Vector3(-0.72, 0.45, -0.52), Vector3(0.72, 0.45, -0.52), Vector3(-0.72, 0.45, 0.52), Vector3(0.72, 0.45, 0.52)]:
		_box(Vector3(0.14, 0.64, 0.14), metal, cx + k)
	for i in 9:
		var n = _mi(_rock(randf_range(0.14, 0.25), 60 + i, 0.8), gold, cx + Vector3(randf_range(-0.5, 0.5), 0.62 + (i % 3) * 0.1, randf_range(-0.35, 0.35)), Vector3(0, randf() * 6.0, 0))
		crates.append(n)
	for i in 8:
		var a3 = i * 0.9
		crates.append(_mi(_rock(randf_range(0.1, 0.2), 90 + i, 0.8), gold, Vector3(cos(a3) * (2.4 + (i % 3) * 0.4) + 0.4, 0.2, sin(a3) * (2.4 + (i % 3) * 0.4)), Vector3(0, randf() * 6.0, 0)))
	var lt = OmniLight3D.new()
	lt.light_color = Color(1.0, 0.85, 0.4)
	lt.light_energy = 0.75
	lt.omni_range = 7.5
	lt.light_volumetric_fog_energy = 0.0
	lt.position = Vector3(0, 2.4, 0)
	add_child(lt)

func take(amount: float) -> float:
	var got: float = min(amount, supply)
	supply -= got
	var keep = int(ceil(crates.size() * supply / max_supply))
	for i in crates.size():
		crates[i].visible = i < keep
	return got

func aim_point() -> Vector3:
	return position + Vector3(0, 1.5, 0)
