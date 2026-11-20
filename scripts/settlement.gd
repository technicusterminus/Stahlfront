extends RefCounted
## Orte und Siedlungen einer Karte: Städte (modern, alt, Ruinen), Industrie, Dörfer, Kuppel, Messmasten, Tunnel, Lazarett, Brücke, Schienen.
## Die Karte beschreibt sie als Liste "sites" in den Kartenreglern; jede Mission verweist über ["site:name", dx, dz] auf einen Ort.
##   {"name": "kuppel", "kind": "dome", "at": ["mid", 0, 45], "r": 14, "seed": 3}
## Arten: town (style modern|old|mixed, ruin 0..1, n Grundstücke), village, industry, dome, mast, tunnel, lazarett, bridge, rails, port, camp.
## Alles ist Kulisse aus Quadern, Prismen und Zylindern mit den Texturen aus models/resources/bio_*; Standflächen sperren das Wegenetz.

const BIO := "bio_"

static var _rng := RandomNumberGenerator.new()

## Ankerpunkt einer Ortsangabe in Weltkoordinaten (x, z).
static func resolve(at: Array, starts: Array) -> Vector2:
	var a := String(at[0])
	var base := Vector2.ZERO
	if a == "me":
		base = starts[0]
	elif a == "en":
		base = starts[1]
	else:
		base = (starts[0] + starts[1]) * 0.5
	return base + Vector2(float(at[1]), float(at[2]))

## Ebene Flächen, die der Geländebau für die Orte einebnen soll: Vector3(x, z, Radius).
static func flats(sp: Dictionary, starts: Array) -> Array:
	var out: Array = []
	for s in sp.get("sites", []):
		if s.get("kind", "") in ["rails", "bridge"]:
			continue
		var c := resolve(s["at"], starts)
		out.append(Vector3(c.x, c.y, float(s.get("r", 12.0)) + 4.0))
	return out

# ---------------------------------------------------------------- Aufbau

static func build(world: Node3D, t, sp: Dictionary, starts: Array) -> Dictionary:
	var old = world.get_node_or_null("Sites")
	if old != null:
		world.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "Sites"
	world.add_child(root)
	var found := {}
	for s in sp.get("sites", []):
		var c := resolve(s["at"], starts)
		var y: float = t.height_at(c.x, c.y)
		var node := Node3D.new()
		node.name = String(s.get("name", s["kind"]))
		node.position = Vector3(c.x, y, c.y)
		root.add_child(node)
		_rng.seed = int(sp["seed"]) * 31 + int(s.get("seed", 1)) * 977
		var r: float = float(s.get("r", 12.0))
		match String(s["kind"]):
			"town": _town(node, t, c, r, s)
			"village": _village(node, t, c, r, s)
			"industry": _industry(node, t, c, r, s)
			"dome": _dome(node, t, c, r, s)
			"mast": _mast(node, t, c, s)
			"tunnel": _tunnel(node, t, c, s)
			"lazarett": _lazarett(node, t, c, r, s)
			"bridge": _bridge(node, t, c, s)
			"rails": _rails(node, t, c, s, starts)
			"port": _port(node, t, c, r, s)
			"camp": _camp(node, t, c, r, s)
		found[String(s.get("name", s["kind"]))] = Vector3(c.x, y, c.y)
	return found

# ---------------------------------------------------------------- Bausteine

static func _mat(tex: String, tint: Color, rough := 0.85, scale := 0.35, metal := 0.0, vein := 0.0) -> Material:
	return Game.resource_material(BIO + tex, tint, rough, scale, vein, metal, false)

static func _flat(col: Color, rough := 0.7, glow := 0.0) -> Material:
	return Game.fog_material(col, rough, glow)

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_y := 0.0, rot_x := 0.0, rot_z := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(rot_x, rot_y, rot_z)
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, rot_x := 0.0, rot_z := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, mat, pos, rot_y, rot_x, rot_z)

static func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, seg := 14) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return _add(parent, m, mat, pos)

static func _roof(parent: Node3D, w: float, d: float, h: float, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = Vector3(w, h, d)
	return _add(parent, m, mat, pos, rot_y)

## Gelände unter der Grundfläche liegt bündig: Sockel bis unter die tiefste Stelle.
static func _base_y(t, p: Vector2, hw: float, hd: float) -> float:
	var lo := 1e9
	for dx in [-hw, 0.0, hw]:
		for dz in [-hd, 0.0, hd]:
			lo = min(lo, t.height_at(p.x + dx, p.y + dz))
	return lo

static func _block(t, p: Vector2, hw: float, hd: float) -> void:
	var G: int = Game.GRID
	var x0 := int(floor((p.x - hw + Game.HALF) / 2.0))
	var x1 := int(floor((p.x + hw + Game.HALF) / 2.0))
	var z0 := int(floor((p.y - hd + Game.HALF) / 2.0))
	var z1 := int(floor((p.y + hd + Game.HALF) / 2.0))
	for cz in range(max(z0, 0), min(z1, G - 1) + 1):
		for cx in range(max(x0, 0), min(x1, G - 1) + 1):
			t.blocked[cz * G + cx] = 1

static func _rubble(parent: Node3D, center: Vector3, r: float, n: int, mat: Material) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var s := _rng.randf_range(0.25, 0.9)
		_box(parent, Vector3(s * _rng.randf_range(0.8, 1.8), s * _rng.randf_range(0.4, 1.0), s * _rng.randf_range(0.8, 1.8)),
			center + Vector3(cos(a) * d, s * 0.25, sin(a) * d), mat, _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))

# ---------------------------------------------------------------- Gebäude

## Moderner Turm; ruiniert: gesplitterte Krone, freiliegende Bewehrung, Schutthaufen.
static func _tower(parent: Node3D, t, p: Vector2, w: float, d: float, h: float, ruin: float) -> void:
	var by: float = _base_y(t, p, w * 0.5, d * 0.5)
	var local := Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	var glass := _mat("glass", Color(0.95, 1.0, 1.0) if ruin < 0.4 else Color(0.62, 0.66, 0.66), 0.35, 0.28, 0.25)
	var conc := _mat("concrete", Color(0.9, 0.9, 0.88) if ruin < 0.4 else Color(0.62, 0.6, 0.56), 0.9, 0.3)
	var rub := _mat("rubble", Color(0.8, 0.78, 0.74), 0.95, 0.25)
	var rot := _rng.randf_range(-0.12, 0.12)
	if ruin < 0.4:
		_box(parent, Vector3(w, h, d), local + Vector3(0, h * 0.5, 0), glass, rot)
		_box(parent, Vector3(w + 0.5, 0.6, d + 0.5), local + Vector3(0, h + 0.3, 0), conc, rot)
		_box(parent, Vector3(0.25, 3.0, 0.25), local + Vector3(w * 0.25, h + 2.1, 0), conc, rot)
		_cyl(parent, 0.05, 0.05, 2.0, local + Vector3(-w * 0.25, h + 1.6, d * 0.2), _flat(Color(0.2, 0.2, 0.22), 0.5, 0.0), 6)
		_light_dot(parent, local + Vector3(w * 0.25, h + 3.7, 0), Color(1.0, 0.2, 0.15))
	else:
		var hh := h * _rng.randf_range(0.35, 0.8)
		_box(parent, Vector3(w, hh, d), local + Vector3(0, hh * 0.5, 0), glass, rot)
		for k in 3:
			var ph := hh * _rng.randf_range(0.15, 0.4)
			_box(parent, Vector3(w * _rng.randf_range(0.25, 0.5), ph, d * _rng.randf_range(0.25, 0.5)),
				local + Vector3(_rng.randf_range(-w * 0.3, w * 0.3), hh + ph * 0.5, _rng.randf_range(-d * 0.3, d * 0.3)), conc, rot + _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))
		var rebar := _flat(Color(0.28, 0.17, 0.1), 0.8)
		for k in 7:
			_cyl(parent, 0.04, 0.04, _rng.randf_range(1.2, 3.2), local + Vector3(_rng.randf_range(-w * 0.45, w * 0.45), hh + 0.8, _rng.randf_range(-d * 0.45, d * 0.45)), rebar, 5)
		_rubble(parent, local + Vector3(0, 0, 0), max(w, d) * 0.9, 16, rub)
	_block(t, p, w * 0.5 + 0.5, d * 0.5 + 0.5)

## Altes Haus mit Satteldach; ruiniert: Mauerreste, Dachbalken, Schutt.
static func _house(parent: Node3D, t, p: Vector2, w: float, d: float, h: float, ruin: float, brick: bool) -> void:
	var by: float = _base_y(t, p, w * 0.5, d * 0.5)
	var local := Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	var walls := _mat("brick" if brick else "plaster", Color(1, 1, 1) if ruin < 0.4 else Color(0.74, 0.7, 0.66), 0.9, 0.3)
	var roof := _mat("roof", Color(1, 1, 1) if ruin < 0.4 else Color(0.7, 0.66, 0.62), 0.85, 0.35)
	var wood := _flat(Color(0.26, 0.18, 0.12), 0.9)
	var rub := _mat("rubble", Color(0.78, 0.74, 0.7), 0.95, 0.25)
	var rot := _rng.randf_range(-0.06, 0.06)
	if ruin < 0.4:
		_box(parent, Vector3(w, h, d), local + Vector3(0, h * 0.5, 0), walls, rot)
		_roof(parent, w + 0.7, d + 0.7, h * 0.55, local + Vector3(0, h + h * 0.275, 0), roof, rot)
		_box(parent, Vector3(0.7, h * 0.6, 0.7), local + Vector3(w * 0.25, h + h * 0.4, d * 0.15), walls, rot)
		_box(parent, Vector3(w * 0.22, h * 0.45, 0.12), local + Vector3(0, h * 0.22, d * 0.5 + 0.03), wood, rot)
	else:
		var hh := h * _rng.randf_range(0.4, 0.85)
		# Mauern: drei von vier Seiten stehen noch, unterschiedlich hoch
		for side in 4:
			var hi := hh * (1.0 if side != int(_rng.randi() % 4) else _rng.randf_range(0.2, 0.45))
			var off: Vector3 = [Vector3(0, 0, d * 0.5), Vector3(0, 0, -d * 0.5), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, 0)][side]
			var sz := Vector3(w if side < 2 else 0.5, hi, 0.5 if side < 2 else d)
			_box(parent, sz, local + off + Vector3(0, hi * 0.5, 0), walls, rot)
		for k in 4:
			_box(parent, Vector3(0.22, 0.22, w * _rng.randf_range(0.5, 0.95)), local + Vector3(_rng.randf_range(-w * 0.3, w * 0.3), hh + _rng.randf_range(0.0, 1.0), 0), wood, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.4, 0.4))
		_rubble(parent, local, max(w, d) * 0.7, 12, rub)
	_block(t, p, w * 0.5 + 0.4, d * 0.5 + 0.4)

static func _hut(parent: Node3D, t, p: Vector2, r: float) -> void:
	var by: float = _base_y(t, p, r, r)
	var local := Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	var walls := _mat("plaster", Color(0.92, 0.86, 0.74), 0.95, 0.4)
	var thatch := _mat("thatch", Color(1, 1, 1), 0.95, 0.4)
	_cyl(parent, r, r * 1.05, 1.9, local + Vector3(0, 0.95, 0), walls, 10)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = r * 1.5
	cone.height = r * 1.6
	cone.radial_segments = 10
	_add(parent, cone, thatch, local + Vector3(0, 1.9 + r * 0.8, 0))
	_box(parent, Vector3(0.6, 1.2, 0.1), local + Vector3(0, 0.6, r * 1.02), _flat(Color(0.2, 0.14, 0.1), 0.9))
	_block(t, p, r + 0.4, r + 0.4)

## Halle mit Sägedach, Schornstein und Rohren.
static func _hall(parent: Node3D, t, p: Vector2, w: float, d: float, h: float, ruin: float) -> void:
	var by: float = _base_y(t, p, w * 0.5, d * 0.5)
	var local := Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	var metal := _mat("corrugated", Color(1, 1, 1) if ruin < 0.4 else Color(0.78, 0.72, 0.68), 0.7, 0.3, 0.35)
	var conc := _mat("concrete", Color(0.8, 0.8, 0.78), 0.9, 0.3)
	_box(parent, Vector3(w, h, d), local + Vector3(0, h * 0.5, 0), metal)
	_box(parent, Vector3(w + 0.3, 0.5, d + 0.3), local + Vector3(0, 0.25, 0), conc)
	var n := int(max(2.0, round(w / 7.0)))
	for k in n:
		var x := -w * 0.5 + (float(k) + 0.5) * (w / float(n))
		_roof(parent, w / float(n), d, h * 0.28, local + Vector3(x, h + h * 0.14, 0), metal, 0.0)
	if _rng.randf() < 0.7:
		_cyl(parent, 0.8, 1.1, h * 2.4, local + Vector3(w * 0.35, h * 1.2, d * 0.55 + 1.2), _mat("brick", Color(0.85, 0.7, 0.62), 0.9, 0.3), 12)
	_cyl(parent, 0.25, 0.25, d * 0.9, local + Vector3(-w * 0.5 - 0.5, h * 0.7, 0), _mat("corrugated", Color(0.75, 0.55, 0.4), 0.6, 0.4, 0.5), 8).rotation.x = PI * 0.5
	_block(t, p, w * 0.5 + 0.6, d * 0.5 + 0.6)

static func _light_dot(parent: Node3D, pos: Vector3, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	_add(parent, s, _flat(col, 0.3, 4.0), pos)

# ---------------------------------------------------------------- Orte

static func _town(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var style := String(s.get("style", "mixed"))
	var ruin: float = float(s.get("ruin", 0.0))
	var step := 11.0 if style == "modern" else 9.0
	var asphalt := _mat("asphalt", Color(0.9, 0.9, 0.9), 0.95, 0.15)
	# Straßenkreuz
	_road(node, t, c, Vector2(-r, 0), Vector2(r, 0), 5.0, asphalt)
	_road(node, t, c, Vector2(0, -r), Vector2(0, r), 5.0, asphalt)
	var x := -r + step * 0.5
	while x < r:
		var z := -r + step * 0.5
		while z < r:
			var p := c + Vector2(x, z) + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			z += step
			if Vector2(x, z - step).length() > r or absf(x) < 5.0 or absf(z - step) < 5.0:
				continue
			if t.height_at(p.x, p.y) < t.WATER_Y + 0.6:
				continue
			if _rng.randf() < 0.18:
				continue   # Baulücke, Platz oder Garten
			var rr := ruin if _rng.randf() < 0.9 else 0.0
			var is_modern := style == "modern" or (style == "mixed" and Vector2(x, z - step).length() < r * 0.5 and _rng.randf() < 0.65)
			if is_modern:
				_tower(node, t, p, _rng.randf_range(5.0, 8.0), _rng.randf_range(5.0, 8.0), _rng.randf_range(9.0, 22.0), rr)
			else:
				_house(node, t, p, _rng.randf_range(4.5, 7.5), _rng.randf_range(4.5, 7.0), _rng.randf_range(3.0, 5.0), rr, _rng.randf() < 0.45)
		x += step

static func _road(node: Node3D, t, c: Vector2, a: Vector2, b: Vector2, wd: float, mat: Material) -> void:
	var n := int(ceil(a.distance_to(b) / 4.0))
	for i in n:
		var q := c + a.lerp(b, (float(i) + 0.5) / float(n))
		var y: float = t.height_at(q.x, q.y)
		var ang := atan2(b.x - a.x, b.y - a.y)
		_box(node, Vector3(wd, 0.14, 4.4), Vector3(q.x - node.position.x, y - node.position.y + 0.04, q.y - node.position.z), mat, ang)

static func _village(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var n := int(s.get("n", 8))
	for i in n:
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.2, 0.2)
		var d := r * _rng.randf_range(0.45, 0.95)
		var p := c + Vector2(cos(a), sin(a)) * d
		if t.height_at(p.x, p.y) < t.WATER_Y + 0.6:
			continue
		if _rng.randf() < 0.65:
			_hut(node, t, p, _rng.randf_range(1.5, 2.2))
		else:
			_house(node, t, p, _rng.randf_range(4.0, 5.5), _rng.randf_range(4.0, 5.0), _rng.randf_range(2.6, 3.4), float(s.get("ruin", 0.0)), false)
	# Feuerstelle in der Mitte
	var fire := _flat(Color(1.0, 0.55, 0.15), 0.4, 2.5)
	var cl := Vector3(0, 0.3, 0)
	_cyl(node, 0.45, 0.6, 0.35, cl, _mat("rubble", Color(0.7, 0.68, 0.64), 0.95, 0.5), 8)
	_cyl(node, 0.0, 0.3, 0.7, cl + Vector3(0, 0.45, 0), fire, 6)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.65, 0.3)
	lamp.omni_range = 11.0
	lamp.light_energy = 1.4
	lamp.position = Vector3(0, 1.4, 0)
	node.add_child(lamp)
	_block(t, c, 1.2, 1.2)

static func _industry(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var ruin: float = float(s.get("ruin", 0.0))
	var n := int(s.get("n", 5))
	for i in n:
		var a := TAU * float(i) / float(n) + 0.4
		var d := r * (0.35 if i == 0 else _rng.randf_range(0.55, 0.9))
		var p := c + Vector2(cos(a), sin(a)) * (0.0 if i == 0 else d)
		if i == 0 and s.get("furnace", true):
			_furnace(node, t, p)
		else:
			_hall(node, t, p, _rng.randf_range(12.0, 20.0), _rng.randf_range(8.0, 12.0), _rng.randf_range(5.0, 7.5), ruin)
	# Tanks und Containerstapel
	var tank := _mat("corrugated", Color(0.9, 0.95, 1.0), 0.55, 0.3, 0.5)
	for i in 3:
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.7, 1.0)
		var by: float = _base_y(t, p, 2.5, 2.5)
		_cyl(node, 2.4, 2.4, 5.0, Vector3(p.x - node.position.x, by - node.position.y + 2.5, p.y - node.position.z), tank, 16)
		_block(t, p, 3.0, 3.0)

static func _furnace(node: Node3D, t, p: Vector2) -> void:
	var by: float = _base_y(t, p, 4.0, 4.0)
	var local := Vector3(p.x - node.position.x, by - node.position.y, p.y - node.position.z)
	var brick := _mat("brick", Color(0.7, 0.55, 0.5), 0.9, 0.3)
	var steel := _mat("corrugated", Color(0.6, 0.55, 0.5), 0.6, 0.35, 0.5)
	_cyl(node, 3.3, 3.8, 9.0, local + Vector3(0, 4.5, 0), brick, 16)
	_cyl(node, 1.4, 2.0, 14.0, local + Vector3(0, 16.0, 0), steel, 12)
	var glow := _flat(Color(1.0, 0.45, 0.1), 0.35, 4.5)
	_box(node, Vector3(2.2, 2.4, 0.4), local + Vector3(0, 1.8, 3.6), glow)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.5, 0.2)
	lamp.omni_range = 18.0
	lamp.light_energy = 2.2
	lamp.position = local + Vector3(0, 2.0, 5.0)
	node.add_child(lamp)
	_block(t, p, 4.6, 4.6)

## Kuppel über dem Prisma: Trommel mit Säulen, Halbkugel, leuchtender Kristall.
static func _dome(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var ruin: float = float(s.get("ruin", 0.0))
	var by: float = _base_y(t, c, r * 0.6, r * 0.6)
	var local := Vector3(0, by - node.position.y, 0)
	var glass := _mat("glass", Color(0.8, 0.95, 1.0), 0.25, 0.2, 0.3)
	var conc := _mat("concrete", Color(0.95, 0.95, 0.92), 0.85, 0.25)
	_cyl(node, r * 0.62, r * 0.7, 2.0, local + Vector3(0, 1.0, 0), conc, 24)
	var hs := SphereMesh.new()
	hs.radius = r * 0.58
	hs.height = r * 1.16
	hs.is_hemisphere = true
	_add(node, hs, glass, local + Vector3(0, 2.0, 0))
	for k in 12:
		var a := TAU * float(k) / 12.0
		_cyl(node, 0.35, 0.45, 5.5 if ruin < 0.5 or _rng.randf() < 0.5 else 2.5, local + Vector3(cos(a) * r * 0.72, 2.75, sin(a) * r * 0.72), conc, 8)
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.3
		_box(node, Vector3(r * 0.3, 0.4, r * 0.3), local + Vector3(cos(a) * r * 0.95, 0.2, sin(a) * r * 0.95), conc, a)
	# Prisma: schwebender Kristall mit blauem Licht
	var crystal := PrismMesh.new()
	crystal.size = Vector3(1.6, 3.4, 1.6)
	var cm := _flat(Color(0.35, 0.8, 1.0), 0.2, 5.0)
	_add(node, crystal, cm, local + Vector3(0, 3.6, 0), 0.4)
	var crystal2 := PrismMesh.new()
	crystal2.size = Vector3(1.6, 3.4, 1.6)
	_add(node, crystal2, cm, local + Vector3(0, 3.6, 0), 0.4, PI)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.4, 0.8, 1.0)
	lamp.omni_range = 26.0
	lamp.light_energy = 3.0
	lamp.position = local + Vector3(0, 4.0, 0)
	node.add_child(lamp)
	_rubble(node, local, r * 1.1, int(14.0 + 40.0 * ruin), _mat("rubble", Color(0.85, 0.83, 0.8), 0.95, 0.25))
	_block(t, c, 4.5, 4.5)

## Messmast an alten Schienen: Gitterturm mit Schüssel und blinkendem Licht.
static func _mast(node: Node3D, t, c: Vector2, s: Dictionary) -> void:
	var by: float = _base_y(t, c, 1.5, 1.5)
	var local := Vector3(0, by - node.position.y, 0)
	var steel := _mat("corrugated", Color(0.62, 0.6, 0.58), 0.55, 0.3, 0.55)
	var h := 13.0
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		_cyl(node, 0.1, 0.12, h, local + Vector3(cos(a) * 0.9, h * 0.5, sin(a) * 0.9), steel, 6)
	for k in 5:
		var y := 1.5 + float(k) * 2.4
		_box(node, Vector3(2.0, 0.1, 0.1), local + Vector3(0, y, 0.9), steel)
		_box(node, Vector3(2.0, 0.1, 0.1), local + Vector3(0, y, -0.9), steel)
		_box(node, Vector3(0.1, 0.1, 2.0), local + Vector3(0.9, y, 0), steel)
		_box(node, Vector3(0.1, 0.1, 2.0), local + Vector3(-0.9, y, 0), steel)
	var dish := SphereMesh.new()
	dish.radius = 1.3
	dish.height = 2.6
	dish.is_hemisphere = true
	_add(node, dish, steel, local + Vector3(0.9, h - 2.6, 0.2), 0.0, PI * 0.5)
	var col := Color(1.0, 0.25, 0.15) if String(s.get("light", "red")) == "red" else Color(0.4, 0.85, 1.0)
	_light_dot(node, local + Vector3(0, h + 0.2, 0), col)
	var lamp := OmniLight3D.new()
	lamp.light_color = col
	lamp.omni_range = 9.0
	lamp.light_energy = 0.9
	lamp.position = local + Vector3(0, h + 0.4, 0)
	node.add_child(lamp)
	# Wartungshäuschen
	_box(node, Vector3(3.0, 2.2, 2.6), local + Vector3(4.0, 1.1, 1.0), _mat("concrete", Color(0.8, 0.8, 0.76), 0.9, 0.3))
	_block(t, c, 2.0, 2.0)
	_block(t, c + Vector2(4.0, 1.0), 2.0, 1.8)

## Tunnelmund im Fels: Pfeiler, Sturz, Stützbalken, davor ein Schutthaufen (eingestürzt).
static func _tunnel(node: Node3D, t, c: Vector2, s: Dictionary) -> void:
	var by: float = _base_y(t, c, 4.0, 4.0)
	var local := Vector3(0, by - node.position.y, 0)
	var conc := _mat("concrete", Color(0.8, 0.78, 0.74), 0.95, 0.25)
	var rock := _mat("rubble", Color(0.75, 0.72, 0.68), 0.95, 0.2)
	var wood := _flat(Color(0.3, 0.2, 0.12), 0.9)
	var rot := float(s.get("rot", 0.0))
	var arch := Node3D.new()
	arch.rotation.y = rot
	node.add_child(arch)
	_box(arch, Vector3(1.8, 6.0, 3.0), local + Vector3(-3.6, 3.0, 0), conc)
	_box(arch, Vector3(1.8, 6.0, 3.0), local + Vector3(3.6, 3.0, 0), conc)
	_box(arch, Vector3(9.0, 1.6, 3.0), local + Vector3(0, 6.5, 0), conc)
	_box(arch, Vector3(11.0, 5.0, 3.0), local + Vector3(0, 8.5, -1.5), rock)
	for k in 4:
		_box(arch, Vector3(0.4, 4.4, 0.4), local + Vector3(-2.7 + float(k) * 1.8, 2.2, 1.8), wood, 0.0, 0.0, _rng.randf_range(-0.25, 0.25))
	if bool(s.get("collapsed", true)):
		_rubble(arch, local + Vector3(0, 0, 2.2), 5.5, 60, rock)
		_box(arch, Vector3(7.0, 4.0, 3.5), local + Vector3(0, 2.0, 1.2), rock, 0.0, -0.18)
	_block(t, c, 6.0, 5.0)

static func _lazarett(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var white := _mat("concrete", Color(1.0, 1.0, 0.98), 0.7, 0.3)
	var canvas := _mat("plaster", Color(0.88, 0.9, 0.82), 0.95, 0.3)
	var red := _flat(Color(0.9, 0.12, 0.1), 0.6, 1.0)
	var n := int(s.get("n", 4))
	for i in n:
		var a := TAU * float(i) / float(n) + 0.5
		var p := c + Vector2(cos(a), sin(a)) * r * 0.6
		var by: float = _base_y(t, p, 3.0, 2.0)
		var l := Vector3(p.x - node.position.x, by - node.position.y, p.y - node.position.z)
		if i % 2 == 0:
			_box(node, Vector3(7.0, 3.0, 4.0), l + Vector3(0, 1.5, 0), white, a)
			_box(node, Vector3(7.2, 0.3, 4.2), l + Vector3(0, 3.1, 0), canvas, a)
			var q := _box(node, Vector3(1.4, 1.4, 0.06), l + Vector3(0, 2.0, 0) + Vector3(sin(a), 0, cos(a)) * 2.05, red, a)
		else:
			_roof(node, 6.0, 5.0, 3.0, l + Vector3(0, 1.5, 0), canvas, a)
		_block(t, p, 3.6, 3.0)
	_box(node, Vector3(1.6, 1.6, 0.08), Vector3(0, 6.0, 0), red)
	_cyl(node, 0.08, 0.08, 6.0, Vector3(0, 3.0, 0), _flat(Color(0.8, 0.8, 0.8), 0.6), 6)

## Brücke: Fahrbahn, Brüstungen, Pfeiler, Laternen entlang des Damms.
static func _bridge(node: Node3D, t, c: Vector2, s: Dictionary) -> void:
	var length: float = float(s.get("length", 60.0))
	var ang := deg_to_rad(float(s.get("deg", 0.0)))
	var ax := Vector2(cos(ang), sin(ang))
	var stone := _mat("concrete", Color(0.85, 0.83, 0.8), 0.9, 0.25)
	var asphalt := _mat("asphalt", Color(0.95, 0.95, 0.95), 0.95, 0.15)
	var iron := _flat(Color(0.18, 0.2, 0.22), 0.6)
	var y0: float = t.height_at(c.x, c.y)
	var n := int(length / 4.0)
	for i in n:
		var u := -length * 0.5 + (float(i) + 0.5) * 4.0
		var q := c + ax * u
		var y: float = max(t.height_at(q.x, q.y), 1.0) + 0.5
		var l := Vector3(q.x - node.position.x, y - node.position.y, q.y - node.position.z)
		_box(node, Vector3(4.2, 0.35, 8.4), l, asphalt, -ang + PI * 0.5 if false else atan2(ax.x, ax.y))
		var perp := Vector2(-ax.y, ax.x)
		for sg in [-1.0, 1.0]:
			var rp: Vector2 = perp * 4.0 * sg
			_box(node, Vector3(4.2, 0.9, 0.35), l + Vector3(rp.x, 0.6, rp.y), stone, atan2(ax.x, ax.y))
			if i % 3 == 0:
				_cyl(node, 0.07, 0.09, 3.6, l + Vector3(rp.x, 2.0, rp.y), iron, 6)
				_light_dot(node, l + Vector3(rp.x, 3.9, rp.y), Color(1.0, 0.85, 0.5))
		if i % 4 == 0:
			_box(node, Vector3(1.6, 3.0, 8.8), l + Vector3(0, -1.6, 0), stone, atan2(ax.x, ax.y))

## Schienenstrang mit Schwellen und Schienen entlang einer Linie (Punkte relativ zum Anker).
static func _rails(node: Node3D, t, c: Vector2, s: Dictionary, starts: Array) -> void:
	var pts: Array = s.get("pts", [])
	var rust := _mat("corrugated", Color(0.55, 0.38, 0.28), 0.6, 0.4, 0.6)
	var wood := _flat(Color(0.22, 0.15, 0.1), 0.95)
	var gravel := _mat("rubble", Color(0.7, 0.68, 0.64), 0.97, 0.3)
	var sleepers := MultiMesh.new()
	sleepers.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 0.14, 0.3)
	sleepers.mesh = bm
	var xf: Array = []
	for i in pts.size() - 1:
		var a: Vector2 = c + Vector2(float(pts[i][0]), float(pts[i][1]))
		var b: Vector2 = c + Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var len := a.distance_to(b)
		var ang := atan2(b.x - a.x, b.y - a.y)
		var steps := int(len / 0.9)
		for k in steps:
			var q := a.lerp(b, float(k) / float(steps))
			var y: float = t.height_at(q.x, q.y)
			if y < t.WATER_Y + 0.4:
				continue
			xf.append(Transform3D(Basis(Vector3.UP, ang), Vector3(q.x, y + 0.12, q.y)))
		var seg := int(len / 8.0) + 1
		for k in seg:
			var q0 := a.lerp(b, float(k) / float(seg))
			var q1 := a.lerp(b, float(k + 1) / float(seg))
			var mid := (q0 + q1) * 0.5
			var y: float = t.height_at(mid.x, mid.y)
			if y < t.WATER_Y + 0.4:
				continue
			var perp := Vector2(cos(ang), -sin(ang)) * 0.62
			for sg in [-1.0, 1.0]:
				var rp: Vector2 = perp * sg
				var rail := _box(node, Vector3(0.12, 0.14, q0.distance_to(q1) + 0.1), Vector3(mid.x + rp.x - node.position.x, y + 0.27 - node.position.y, mid.y + rp.y - node.position.z), rust, ang)
	sleepers.instance_count = xf.size()
	for i in xf.size():
		sleepers.set_instance_transform(i, Transform3D(xf[i].basis, xf[i].origin - node.position))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = sleepers
	mmi.material_override = wood
	node.add_child(mmi)

static func _port(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var ruin: float = float(s.get("ruin", 0.0))
	var steel := _mat("corrugated", Color(0.95, 0.85, 0.7), 0.55, 0.3, 0.5)
	var cols := [Color(0.7, 0.25, 0.2), Color(0.2, 0.4, 0.6), Color(0.85, 0.7, 0.25), Color(0.25, 0.5, 0.35), Color(0.8, 0.8, 0.78)]
	for k in int(s.get("n", 4)):
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.3, 0.9)
		_hall(node, t, p, _rng.randf_range(12.0, 18.0), _rng.randf_range(7.0, 10.0), _rng.randf_range(4.5, 6.0), ruin)
	# Container-Stapel
	for k in 6:
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.5, 1.0)
		var by: float = _base_y(t, p, 3.0, 1.5)
		var l := Vector3(p.x - node.position.x, by - node.position.y, p.y - node.position.z)
		var rot := _rng.randf() * TAU
		for lvl in _rng.randi_range(1, 3):
			_box(node, Vector3(6.0, 2.5, 2.4), l + Vector3(0, 1.25 + float(lvl) * 2.5, 0), _mat("corrugated", cols[_rng.randi() % cols.size()], 0.6, 0.3, 0.4), rot)
		_block(t, p, 3.4, 3.4)
	# Kran
	var kp := c + Vector2(r * 0.9, 0)
	var by: float = _base_y(t, kp, 2.0, 2.0)
	var kl := Vector3(kp.x - node.position.x, by - node.position.y, kp.y - node.position.z)
	_box(node, Vector3(1.0, 20.0, 1.0), kl + Vector3(-1.5, 10.0, 0), steel)
	_box(node, Vector3(1.0, 20.0, 1.0), kl + Vector3(1.5, 10.0, 0), steel)
	_box(node, Vector3(18.0, 1.0, 1.4), kl + Vector3(5.0, 20.0, 0), steel)
	_light_dot(node, kl + Vector3(13.8, 20.8, 0), Color(1.0, 0.25, 0.15))
	_block(t, kp, 3.0, 3.0)
	# Leuchtturm
	var lp := c + Vector2(-r * 0.9, r * 0.5)
	var lby: float = _base_y(t, lp, 2.0, 2.0)
	var ll := Vector3(lp.x - node.position.x, lby - node.position.y, lp.y - node.position.z)
	_cyl(node, 1.1, 1.8, 15.0, ll + Vector3(0, 7.5, 0), _mat("plaster", Color(1.0, 0.97, 0.92), 0.8, 0.3), 14)
	_cyl(node, 1.4, 1.4, 1.4, ll + Vector3(0, 15.7, 0), _flat(Color(1.0, 0.95, 0.7), 0.3, 3.5), 12)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 1.6
	_add(node, cone, _flat(Color(0.7, 0.2, 0.18), 0.6), ll + Vector3(0, 17.2, 0))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.92, 0.65)
	lamp.omni_range = 40.0
	lamp.light_energy = 2.0
	lamp.position = ll + Vector3(0, 16.0, 0)
	node.add_child(lamp)
	_block(t, lp, 2.4, 2.4)

static func _camp(node: Node3D, t, c: Vector2, r: float, s: Dictionary) -> void:
	var canvas := _mat("plaster", Color(0.62, 0.6, 0.48), 0.95, 0.3)
	var n := int(s.get("n", 5))
	for i in n:
		var a := TAU * float(i) / float(n) + 0.3
		var p := c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.4, 0.9)
		var by: float = _base_y(t, p, 2.0, 2.0)
		_roof(node, 4.4, 3.8, 2.4, Vector3(p.x - node.position.x, by - node.position.y + 1.2, p.y - node.position.z), canvas, a)
		_block(t, p, 2.4, 2.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.35)
	lamp.omni_range = 12.0
	lamp.light_energy = 1.2
	lamp.position = Vector3(0, 1.4, 0)
	node.add_child(lamp)
