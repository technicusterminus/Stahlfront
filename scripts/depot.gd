extends Node3D
## Rohstoffvorkommen: Nachschubdepot (Kisten), Wäldchen (Holz), Erzfels (Eisen),
## Ölquelle mit nickendem Förderbock (Öl) und Goldader (Gold).

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

func _ready() -> void:
	set_process(kind == "oil")

func _process(delta: float) -> void:
	if _beam != null:
		_t += delta
		_beam.rotation.x = sin(_t * 1.6) * 0.22 * (1.0 if supply > 0.0 else 0.0)

func _mi(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi

func _pad(col: Color, size := 5.5) -> void:
	var pm = BoxMesh.new()
	pm.size = Vector3(size, 0.3, size)
	_mi(pm, Game.fog_material(col, 0.95), Vector3(0, 0.1, 0))

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

func _build_crates() -> void:
	_pad(Color(0.35, 0.33, 0.3))
	var bm = BoxMesh.new()
	bm.size = Vector3(1.05, 1.05, 1.05)
	var m = Game.fog_material(Color(0.55, 0.42, 0.22), 0.85)
	var m2 = Game.fog_material(Color(0.25, 0.35, 0.2), 0.8)
	for y in 3:
		for z in 4:
			for x in 4:
				if y == 2 and (x == 0 or x == 3 or z == 0 or z == 3):
					continue
				if y == 1 and (x + z) % 3 == 0 and (x == 0 or z == 0):
					continue
				var c = _mi(bm, m if (x + y + z) % 4 != 0 else m2, Vector3(-1.65 + x * 1.1, 0.78 + y * 1.08, -1.65 + z * 1.1))
				c.rotation.y = randf_range(-0.12, 0.12)
				crates.append(c)

## Baumstämme in Pyramide, Sägespäne, stehende Fichten dahinter.
func _build_wood() -> void:
	_pad(Color(0.3, 0.24, 0.16))
	var bark = Game.fog_material(Color(0.4, 0.27, 0.15), 0.95)
	var cut = Game.fog_material(Color(0.78, 0.62, 0.38), 0.9)
	var leaf = Game.fog_material(Color(0.12, 0.3, 0.14), 0.95)
	var cm = CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.38
	cm.height = 4.2
	cm.radial_segments = 8
	var rows = [4, 3, 2]
	for r in 3:
		for i in rows[r]:
			var x = -(rows[r] - 1) * 0.4 + i * 0.8
			var lg = _mi(cm, bark, Vector3(x * 1.0 - 0.6, 0.55 + r * 0.62, 0.0 + randf_range(-0.08, 0.08)), Vector3(PI / 2, 0, randf_range(-0.05, 0.05)))
			crates.append(lg)
			# helle Schnittfläche
			var disc = CylinderMesh.new()
			disc.top_radius = 0.33
			disc.bottom_radius = 0.33
			disc.height = 0.04
			disc.radial_segments = 8
			var d = MeshInstance3D.new()
			d.mesh = disc
			d.material_override = cut
			d.position = Vector3(0, 2.12, 0)
			lg.add_child(d)
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 3.0
	cone.radial_segments = 7
	for i in 5:
		var a = i * 1.26 + 0.4
		var tr = _mi(cone, leaf, Vector3(cos(a) * 3.3, 1.9, sin(a) * 3.3 - 1.0))
		tr.scale = Vector3(1.0, 1.0 + randf() * 0.5, 1.0) * (0.9 + randf() * 0.5)
		var stem = CylinderMesh.new()
		stem.top_radius = 0.12
		stem.bottom_radius = 0.16
		stem.height = 0.8
		var st = _mi(stem, bark, Vector3(cos(a) * 3.3, 0.45, sin(a) * 3.3 - 1.0))

## Graue Felsbrocken mit rostigen Erzadern.
func _build_iron() -> void:
	_pad(Color(0.32, 0.31, 0.3))
	var rock = Game.fog_material(Color(0.4, 0.4, 0.43), 0.9)
	var ore = Game.fog_material(Color(0.55, 0.25, 0.12), 0.6)
	var shiny = Game.fog_material(Color(0.7, 0.72, 0.78), 0.35)
	for i in 9:
		var sm = SphereMesh.new()
		var rr = randf_range(0.6, 1.3)
		sm.radius = rr
		sm.height = rr * 1.5
		sm.radial_segments = 7
		sm.rings = 4
		var a = i * 0.7
		var rad = 0.5 + (i % 3) * 0.9
		var m = rock if i % 3 != 0 else ore
		var rk = _mi(sm, m, Vector3(cos(a) * rad, 0.5 + rr * 0.3, sin(a) * rad), Vector3(randf() * 3, randf() * 3, randf() * 3))
		crates.append(rk)
	var bm = BoxMesh.new()
	bm.size = Vector3(0.28, 0.28, 0.28)
	for i in 6:
		var a2 = i * 1.1
		var sp = _mi(bm, shiny, Vector3(cos(a2) * 2.1, 0.5 + (i % 2) * 0.9, sin(a2) * 2.1), Vector3(randf(), randf(), randf()))
		crates.append(sp)

## Schwarze Lache und Förderbock mit Pendelbalken.
func _build_oil() -> void:
	_pad(Color(0.22, 0.2, 0.18), 6.0)
	var puddle = CylinderMesh.new()
	puddle.top_radius = 2.6
	puddle.bottom_radius = 2.6
	puddle.height = 0.04
	puddle.radial_segments = 20
	_mi(puddle, Game.fog_material(Color(0.03, 0.03, 0.04), 0.1), Vector3(0.6, 0.27, 0.8))
	var steel = Game.fog_material(Color(0.5, 0.15, 0.1), 0.6)
	var dark = Game.fog_material(Color(0.12, 0.12, 0.14), 0.7)
	var base = BoxMesh.new()
	base.size = Vector3(1.4, 0.4, 2.8)
	_mi(base, dark, Vector3(-1.4, 0.45, -0.6))
	for sz in [-1.0, 1.0]:
		var leg = BoxMesh.new()
		leg.size = Vector3(0.14, 2.6, 0.14)
		_mi(leg, steel, Vector3(-1.4, 1.6, -0.6 + sz * 0.5), Vector3(0, 0, 0.0))
		_mi(leg, steel, Vector3(-1.1, 1.6, -0.6 + sz * 0.5), Vector3(0, 0, 0.0))
	_beam = Node3D.new()
	_beam.position = Vector3(-1.25, 2.8, -0.6)
	add_child(_beam)
	var arm = BoxMesh.new()
	arm.size = Vector3(0.28, 0.3, 3.8)
	var am = MeshInstance3D.new()
	am.mesh = arm
	am.material_override = steel
	_beam.add_child(am)
	var head = SphereMesh.new()
	head.radius = 0.5
	head.height = 0.9
	var hm = MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = steel
	hm.position = Vector3(0, -0.1, 2.0)
	_beam.add_child(hm)
	var wt = BoxMesh.new()
	wt.size = Vector3(0.5, 0.9, 0.5)
	var wm = MeshInstance3D.new()
	wm.mesh = wt
	wm.material_override = dark
	wm.position = Vector3(0, -0.2, -1.9)
	_beam.add_child(wm)
	for i in 3:
		var bar = CylinderMesh.new()
		bar.top_radius = 0.5
		bar.bottom_radius = 0.5
		bar.height = 1.1
		bar.radial_segments = 10
		crates.append(_mi(bar, Game.fog_material(Color(0.15, 0.17, 0.2), 0.5), Vector3(1.8 + i * 1.05, 0.85, 1.8 - (i % 2) * 0.5)))

## Heller Fels mit leuchtenden Goldadern und Nuggets.
func _build_gold() -> void:
	_pad(Color(0.36, 0.33, 0.28))
	var rock = Game.fog_material(Color(0.5, 0.46, 0.4), 0.9)
	var gold = Game.fog_material(Color(1.0, 0.8, 0.2), 0.25, 0.35)
	for i in 6:
		var sm = SphereMesh.new()
		var rr = randf_range(0.7, 1.3)
		sm.radius = rr
		sm.height = rr * 1.7
		sm.radial_segments = 7
		sm.rings = 4
		var a = i * 1.05
		var rk = _mi(sm, rock, Vector3(cos(a) * 1.3, 0.55 + rr * 0.35, sin(a) * 1.3), Vector3(randf() * 3, randf() * 3, randf() * 3))
		crates.append(rk)
	var bm = BoxMesh.new()
	bm.size = Vector3(0.32, 0.26, 0.3)
	for i in 14:
		var a2 = i * 0.9
		var rad = 0.9 + (i % 4) * 0.45
		var nug = _mi(bm, gold, Vector3(cos(a2) * rad, 1.0 + (i % 3) * 0.35, sin(a2) * rad), Vector3(randf() * 3, randf() * 3, randf() * 3))
		nug.scale = Vector3.ONE * randf_range(0.7, 1.5)
		crates.append(nug)
	var lt = OmniLight3D.new()
	lt.light_color = Color(1.0, 0.85, 0.4)
	lt.light_energy = 0.7
	lt.omni_range = 7.0
	lt.light_volumetric_fog_energy = 0.0
	lt.position = Vector3(0, 2.2, 0)
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
