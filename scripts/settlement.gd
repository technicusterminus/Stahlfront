extends RefCounted
## Orte und Siedlungen einer Karte: Städte (modern, alt, Ruinen), Industrie, Dörfer, Kuppel, Messmasten, Tunnel, Lazarett, Brücke, Schienen.
## Die Karte beschreibt sie als Liste "sites" in den Kartenreglern; jede Mission verweist über ["site:name", dx, dz] auf einen Ort.
##   {"name": "kuppel", "kind": "dome", "at": ["mid", 0, 45], "r": 14, "seed": 3}
## Arten: town (style modern|old|mixed, ruin 0..1, n Grundstücke), village, industry, dome, mast, tunnel, lazarett, bridge, rails, port, camp.
## Alles ist Kulisse aus Quadern, Prismen und Zylindern mit den Texturen aus models/resources/bio_*; Standflächen sperren das Wegenetz.

const BIO := "bio_"
static var _yaw := 0.0

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

## Fassadenmaterial mit Fensterraster (shaders/building.gdshader); je Bauteil eigene Instanz, weil Hoehe und Schaden verschieden sind.
static func _facade(tex: String, tint: Color, half_h: float, ruin: float, floor_h := 3.0, win_w := 2.0, fill := 0.55, glass := Color(0.10, 0.18, 0.24), windows := true) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/building.gdshader")
	m.set_shader_parameter("wall_tex", load("res://models/resources/%s%s_albedo.png" % [BIO, tex]))
	m.set_shader_parameter("fog_tex", Game.fog_tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("half_h", half_h)
	m.set_shader_parameter("floor_h", floor_h)
	m.set_shader_parameter("win_w", win_w)
	m.set_shader_parameter("win_fill", fill)
	m.set_shader_parameter("glass_col", glass)
	m.set_shader_parameter("ruin", ruin)
	m.set_shader_parameter("seed", _rng.randf_range(1.0, 90.0))
	m.set_shader_parameter("windows", windows)
	return m

## Hochhausfassade aus einer fertigen Fassadentextur (OpenRouter-Bild); Dachflaechen mit Dachtextur.
static func _skin(tex: String, tint: Color, half_h: float, ruin: float, tile := Vector2(29, 29), round_s := false) -> Material:
	var m := _facade(tex, tint, half_h, ruin, 3.0, 2.0, 0.5, Color(0.1, 0.18, 0.24), false) as ShaderMaterial
	m.set_shader_parameter("facade", true)
	m.set_shader_parameter("tile_m", tile)
	m.set_shader_parameter("round_s", round_s)
	m.set_shader_parameter("top_tex", load("res://models/resources/%srooftop_albedo.png" % BIO))
	m.set_shader_parameter("has_top", true)
	m.set_shader_parameter("rough", 0.85)
	return m

static func _shaft(parent: Node3D, pos: Vector3, w: float, d: float, h: float, mat_fn: Callable, rot: float, round_s := false) -> void:
	var mat: Material = mat_fn.call(h * 0.5)
	if round_s:
		var m := CylinderMesh.new()
		m.top_radius = w * 0.5
		m.bottom_radius = w * 0.5
		m.height = h
		m.radial_segments = 28
		m.rings = 1
		_add(parent, m, mat, pos + Vector3(0, h * 0.5, 0), rot)
	else:
		_box(parent, Vector3(w, h, d), pos + Vector3(0, h * 0.5, 0), mat, rot)

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

## Hochhaus in vier Bauformen (Rücksprung-Scheibe, Art-déco-Spitze, Rundturm, Zwillingsturm) mit Fassaden aus
## Bildtexturen; ruiniert: gekappter Schaft, gesplitterte Krone, Bewehrung, abgestürzte Platte, Schutt.
static func _tower(parent: Node3D, t, p: Vector2, w: float, d: float, h: float, ruin: float) -> void:
	var by: float = _base_y(t, p, w * 0.5, d * 0.5)
	var local := Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	var ok: bool = ruin < 0.4
	var form := _rng.randi() % 4
	var tex: String = "fac_ruin"
	var tile := Vector2(29, 29)
	var tone := Color(0.85, 0.83, 0.8)
	if ok:
		var kind := _rng.randi() % 3
		tex = ["fac_glass", "fac_office", "fac_deco"][kind]
		tile = [Vector2(29, 29), Vector2(26, 26), Vector2(28, 36)][kind]
		tone = Color(1, 1, 1)
		if form == 1:
			tex = "fac_deco"
			tile = Vector2(28, 36)
	var conc := _mat("concrete", Color(0.9, 0.9, 0.88) if ok else Color(0.62, 0.6, 0.56), 0.9, 0.3)
	var rub := _mat("rubble", Color(0.8, 0.78, 0.74), 0.95, 0.25)
	var rebar := _flat(Color(0.28, 0.17, 0.1), 0.8)
	var rot := 0.0
	var hn := Node3D.new()
	hn.position = local
	hn.rotation.y = _yaw + _rng.randf_range(-0.05, 0.05)
	parent.add_child(hn)
	parent = hn
	local = Vector3.ZERO
	var skin := func(hh: float) -> Material: return _skin(tex, tone, hh, ruin, tile)
	var pod := 3.8
	var wp := w + 2.4
	var dp := d + 2.4
	# Sockel mit Vordach und Eingangsportal
	_box(parent, Vector3(wp, pod, dp), local + Vector3(0, pod * 0.5, 0), _skin("fac_office" if ok else "fac_ruin", tone, pod * 0.5, ruin, Vector2(26, 26)), rot)
	_box(parent, Vector3(wp + 1.6, 0.3, dp + 1.6), local + Vector3(0, pod + 0.15, 0), conc, rot)
	_box(parent, Vector3(wp * 0.45, 0.25, 2.6), local + Vector3(0, 2.9, dp * 0.5 + 1.2), conc, rot)
	for sx in [-1, 1]:
		_cyl(parent, 0.18, 0.18, 2.9, local + Vector3(sx * wp * 0.2, 1.45, dp * 0.5 + 2.2), conc, 8)
	var top := pod
	if ok:
		match form:
			0:
				var lo := h * 0.72
				_shaft(parent, local + Vector3(0, pod, 0), w, d, lo, skin, rot)
				var hi := h * 0.3
				_shaft(parent, local + Vector3(0, pod + lo, 0), w * 0.68, d * 0.68, hi, skin, rot)
				top = pod + lo + hi
				_box(parent, Vector3(w * 0.3, 1.8, d * 0.3), local + Vector3(w * 0.1, top + 0.9, 0), conc, rot)
				_cyl(parent, 0.04, 0.07, 6.0, local + Vector3(-w * 0.12, top + 3.0, d * 0.08), _flat(Color(0.25, 0.25, 0.28), 0.5), 6)
				_light_dot(parent, local + Vector3(-w * 0.12, top + 6.1, d * 0.08), Color(1.0, 0.2, 0.15))
			1:
				var t1 := h * 0.5
				_shaft(parent, local + Vector3(0, pod, 0), w, d, t1, skin, rot)
				var t2 := h * 0.22
				_shaft(parent, local + Vector3(0, pod + t1, 0), w * 0.78, d * 0.78, t2, skin, rot)
				var t3 := h * 0.18
				_shaft(parent, local + Vector3(0, pod + t1 + t2, 0), w * 0.56, d * 0.56, t3, skin, rot)
				top = pod + t1 + t2 + t3
				var fr := CylinderMesh.new()
				fr.top_radius = 0.2
				fr.bottom_radius = w * 0.42
				fr.height = h * 0.16
				fr.radial_segments = 4
				fr.rings = 1
				_add(parent, fr, conc, local + Vector3(0, top + h * 0.08, 0), rot + PI * 0.25)
				_cyl(parent, 0.03, 0.09, h * 0.22, local + Vector3(0, top + h * 0.16 + h * 0.11, 0), _flat(Color(0.7, 0.68, 0.6), 0.4, 0.0), 6)
				_light_dot(parent, local + Vector3(0, top + h * 0.38, 0), Color(1.0, 0.25, 0.15))
				top += h * 0.16
			2:
				var rw := minf(w, d) * 1.05
				var body := h * 0.88
				_shaft(parent, local + Vector3(0, pod, 0), rw, rw, body, func(hh: float) -> Material: return _skin(tex, tone, hh, ruin, tile, true), rot, true)
				top = pod + body
				var ring := CylinderMesh.new()
				ring.top_radius = rw * 0.56
				ring.bottom_radius = rw * 0.56
				ring.height = 0.5
				ring.radial_segments = 28
				_add(parent, ring, conc, local + Vector3(0, top + 0.25, 0))
				var dome := SphereMesh.new()
				dome.radius = rw * 0.3
				dome.height = rw * 0.3
				dome.is_hemisphere = true
				_add(parent, dome, _mat("glass", Color(0.8, 1.0, 1.0), 0.3, 0.3, 0.3), local + Vector3(0, top + 0.5, 0))
				_cyl(parent, 0.04, 0.06, 5.0, local + Vector3(0, top + 3.0, 0), _flat(Color(0.25, 0.25, 0.28), 0.5), 6)
				_light_dot(parent, local + Vector3(0, top + 5.6, 0), Color(1.0, 0.2, 0.15))
				top += 0.5
			3:
				var tw := w * 0.46
				var th := h * 0.92
				for sx in [-1, 1]:
					_shaft(parent, local + Vector3(sx * (w * 0.5 + 0.5), pod, 0), tw, d, th * (1.0 if sx < 0 else 0.84), skin, rot)
				_box(parent, Vector3(w * 0.7, 3.2, d * 0.45), local + Vector3(0, pod + th * 0.6, 0), _skin("fac_glass", Color(1, 1, 1), 1.6, 0.0), rot)
				top = pod + th
				for sx in [-1, 1]:
					_box(parent, Vector3(tw + 0.5, 0.5, d + 0.5), local + Vector3(sx * (w * 0.5 + 0.5), pod + th * (1.0 if sx < 0 else 0.84) + 0.25, 0), conc, rot)
				_cyl(parent, 0.04, 0.07, 6.0, local + Vector3(-w * 0.5 - 0.5, top + 3.4, 0), _flat(Color(0.25, 0.25, 0.28), 0.5), 6)
				_light_dot(parent, local + Vector3(-w * 0.5 - 0.5, top + 6.5, 0), Color(1.0, 0.2, 0.15))
	else:
		var hh := h * _rng.randf_range(0.4, 0.85)
		if form == 2:
			var rw2 := minf(w, d) * 1.05
			_shaft(parent, local + Vector3(0, pod, 0), rw2, rw2, hh, func(x: float) -> Material: return _skin(tex, tone, x, ruin, tile, true), rot, true)
		else:
			_shaft(parent, local + Vector3(0, pod, 0), w, d, hh, skin, rot)
			if form == 3:
				_shaft(parent, local + Vector3(w * 0.55, pod, 0), w * 0.45, d, hh * _rng.randf_range(0.3, 0.6), skin, rot)
		top = pod + hh
		for k in 4:
			var ph := hh * _rng.randf_range(0.08, 0.25)
			_box(parent, Vector3(w * _rng.randf_range(0.25, 0.5), ph, d * _rng.randf_range(0.25, 0.5)),
				local + Vector3(_rng.randf_range(-w * 0.3, w * 0.3), top + ph * 0.5, _rng.randf_range(-d * 0.3, d * 0.3)), conc, rot + _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25))
		for k in 10:
			_cyl(parent, 0.04, 0.04, _rng.randf_range(1.2, 4.2), local + Vector3(_rng.randf_range(-w * 0.45, w * 0.45), top + 0.8, _rng.randf_range(-d * 0.45, d * 0.45)), rebar, 5)
		_box(parent, Vector3(w * 0.8, 0.4, 3.4), local + Vector3(0, 2.4, d * 0.5 + 2.0), conc, rot, 0.9, 0.0)
		_rubble(parent, local, max(w, d) * 1.2, 26, rub)
	_block(t, p, w * 0.5 + 1.8, d * 0.5 + 1.8)

const SHUTTER_COLS := [Color(0.18, 0.32, 0.22), Color(0.2, 0.28, 0.45), Color(0.5, 0.18, 0.14), Color(0.55, 0.45, 0.2), Color(0.25, 0.25, 0.27), Color(0.35, 0.2, 0.4)]
const ROOF_TINTS := [Color(1, 1, 1), Color(0.78, 0.82, 0.9), Color(0.9, 0.78, 0.7), Color(0.7, 0.72, 0.75)]

## Wand mit Fensterraster; Zellen sind so bemessen, dass Fensterbaenke und Laeden aus Geometrie genau auf den Fenstern sitzen.
static func _wallbox(hn: Node3D, w: float, h: float, d: float, y0: float, tex: String, tone: Color, ruin: float, nf: int, win_w: float, fill: float, windows := true) -> float:
	var floor_h := (h - 1.6) / float(maxi(nf, 1)) if windows else 3.0
	_box(hn, Vector3(w, h, d), Vector3(0, y0 + h * 0.5, 0), _facade(tex, tone, h * 0.5, ruin, floor_h, win_w, fill, Color(0.12, 0.17, 0.2), windows))
	return floor_h

## Fensterbaenke, Stuerze und Laeden vor den Fenstern der Vorder- und Rueckseite (z = +/- d/2).
static func _frame_windows(hn: Node3D, w: float, d: float, y0: float, nf: int, floor_h: float, win_w: float, fill: float, shutters: bool, faces := 2) -> void:
	var my := 0.2 + (1.0 - fill) * 0.2
	var wh := floor_h * (1.0 - 2.0 * my)
	var sc: Color = SHUTTER_COLS[_rng.randi() % SHUTTER_COLS.size()]
	var sh := _flat(sc, 0.85)
	var stone := _mat("concrete", Color(0.78, 0.76, 0.72), 0.95, 0.3)
	var n := int(floor((w - 0.6) / win_w))
	for f in nf:
		var yb := y0 + 0.9 + floor_h * (float(f) + my)
		for fc in faces:
			var zs := 1.0 if fc == 0 else -1.0
			for j in range(-n / 2 - 1, n / 2 + 1):
				var x := (float(j) + 0.5) * win_w
				if absf(x) > w * 0.5 - win_w * 0.4:
					continue
				_box(hn, Vector3(win_w * fill + 0.34, 0.09, 0.28), Vector3(x, yb - 0.04, zs * (d * 0.5 + 0.1)), stone)
				_box(hn, Vector3(win_w * fill + 0.22, 0.12, 0.16), Vector3(x, yb + wh + 0.06, zs * (d * 0.5 + 0.05)), stone)
				if shutters:
					for sx in [-1, 1]:
						_box(hn, Vector3(0.3, wh, 0.05), Vector3(x + sx * (win_w * fill * 0.5 + 0.2), yb + wh * 0.5, zs * (d * 0.5 + 0.04)), sh)

static func _chimney(hn: Node3D, x: float, z: float, y: float, hgt: float, mat: Material) -> void:
	_box(hn, Vector3(0.75, hgt, 0.75), Vector3(x, y + hgt * 0.5, z), mat)
	_box(hn, Vector3(0.95, 0.15, 0.95), Vector3(x, y + hgt, z), mat)

static func _door(hn: Node3D, x: float, z: float, wood: Material, stone: Material, wide := 1.0) -> void:
	_box(hn, Vector3(1.05 * wide, 2.0, 0.14), Vector3(x, 1.2, z + 0.04), wood)
	_box(hn, Vector3(1.4 * wide, 0.16, 0.3), Vector3(x, 2.28, z + 0.1), stone)
	_box(hn, Vector3(1.5 * wide, 0.14, 0.9), Vector3(x, 0.34, z + 0.48), stone)

static func _railing(hn: Node3D, x: float, y: float, z: float, len: float, mat: Material) -> void:
	_box(hn, Vector3(len, 0.06, 0.06), Vector3(x, y + 0.95, z), mat)
	var n := int(len / 0.28)
	for i in n + 1:
		_box(hn, Vector3(0.04, 0.95, 0.04), Vector3(x - len * 0.5 + len * float(i) / float(maxi(n, 1)), y + 0.48, z), mat)

static func _balcony(hn: Node3D, x: float, y: float, z: float, len: float, stone: Material, iron: Material) -> void:
	_box(hn, Vector3(len, 0.16, 1.0), Vector3(x, y, z + 0.5), stone)
	_railing(hn, x, y, z + 0.95, len, iron)
	for sx in [-1, 1]:
		_box(hn, Vector3(0.1, 0.6, 0.1), Vector3(x + sx * len * 0.45, y - 0.3, z + 0.9), iron)

static func _dormer(hn: Node3D, x: float, y: float, z: float, roof: Material, wall: Material, glass: Material) -> void:
	_box(hn, Vector3(1.3, 1.1, 1.0), Vector3(x, y + 0.55, z), wall)
	_box(hn, Vector3(0.7, 0.65, 0.06), Vector3(x, y + 0.55, z + 0.52), glass)
	_roof(hn, 1.7, 1.4, 0.7, Vector3(x, y + 1.1 + 0.35, z), roof)

static func _house(parent: Node3D, t, p: Vector2, w: float, d: float, h: float, ruin: float, brick: bool) -> void:
	var by: float = _base_y(t, p, w * 0.5, d * 0.5)
	var hn := Node3D.new()
	hn.position = Vector3(p.x - parent.position.x, by - parent.position.y, p.y - parent.position.z)
	hn.rotation.y = _yaw + _rng.randf_range(-0.04, 0.04)
	parent.add_child(hn)
	var ok: bool = ruin < 0.4
	var kind := _rng.randi() % 7
	var tex := "brick" if brick else "plaster"
	var tone := Color(1, 1, 1) if ok else Color(0.74, 0.7, 0.66)
	var rt: Color = ROOF_TINTS[_rng.randi() % ROOF_TINTS.size()]
	var roof := _mat("roof", rt if ok else rt * 0.7, 0.85, 0.35)
	var wood := _flat(Color(0.26, 0.18, 0.12), 0.9)
	var dark := _flat(Color(0.12, 0.1, 0.09), 0.9)
	var iron := _flat(Color(0.1, 0.1, 0.11), 0.6)
	var stone := _mat("concrete", Color(0.7, 0.68, 0.64), 0.95, 0.3)
	var brk := _mat("brick", Color(0.9, 0.8, 0.75) if ok else Color(0.7, 0.62, 0.58), 0.9, 0.35)
	var rub := _mat("rubble", Color(0.78, 0.74, 0.7), 0.95, 0.25)
	var glass := _flat(Color(0.1, 0.16, 0.2), 0.2)
	var pw: float = minf(w, 7.4)
	var pd: float = minf(d, 7.4)
	var foot := 0.4
	_box(hn, Vector3(pw + 0.3, 0.5, pd + 0.3), Vector3(0, 0.15, 0), stone)   # Sockel
	var ww := 1.9
	if ok:
		match kind:
			0:   # Landhaus: Walmdach, Veranda, Fensterlaeden
				pw = clampf(pw, 4.6, 6.8)
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var hh := 3.3
				var fh := _wallbox(hn, pw, hh, pd, 0.2, tex, tone, ruin, 1, wn, 0.42)
				_frame_windows(hn, pw, pd, 0.2, 1, fh, wn, 0.42, true)
				_roof(hn, pd + 1.0, pw + 1.0, 2.1, Vector3(0, hh + 0.2 + 1.05, 0), roof, PI * 0.5)
				_chimney(hn, pw * 0.3, -pd * 0.15, hh + 1.0, 1.8, brk)
				_door(hn, 0, pd * 0.5, wood, stone)
				_box(hn, Vector3(2.8, 0.14, 1.6), Vector3(0, 2.75, pd * 0.5 + 0.85), roof)
				for sx in [-1, 1]:
					_cyl(hn, 0.07, 0.07, 2.6, Vector3(sx * 1.2, 1.5, pd * 0.5 + 1.5), wood, 6)
				foot = 1.8
			1:   # Stadthaus: schmal, hoch, Giebel zur Strasse, Balkon, Gesimse
				pw = clampf(pw, 4.0, 5.2)
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var hh := 6.6
				var fh := _wallbox(hn, pw, hh, pd, 0.2, tex, tone, ruin, 2, wn, 0.4)
				_frame_windows(hn, pw, pd, 0.2, 2, fh, wn, 0.4, false)
				_box(hn, Vector3(pw + 0.3, 0.2, 0.35), Vector3(0, 0.2 + hh * 0.5, pd * 0.5 + 0.05), stone)
				_roof(hn, pw + 0.7, pd + 0.8, 3.0, Vector3(0, hh + 0.2 + 1.5, 0), roof)
				_balcony(hn, 0, 0.2 + hh * 0.5 + 0.1, pd * 0.5, pw * 0.6, stone, iron)
				_chimney(hn, pw * 0.3, -pd * 0.2, hh + 1.2, 2.2, brk)
				_door(hn, 0, pd * 0.5, wood, stone)
				foot = 1.2
			2:   # L-Haus: Hauptfluegel plus Seitenfluegel mit Querdach, Erker
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var hh := 3.6
				var fh := _wallbox(hn, pw, hh, pd * 0.55, 0.2, tex, tone, ruin, 1, wn, 0.42)
				hn.get_child(hn.get_child_count() - 1).position.z = -pd * 0.225
				_roof(hn, pd * 0.55 + 0.8, pw + 0.8, 2.1, Vector3(0, hh + 0.2 + 1.05, -pd * 0.225), roof, PI * 0.5)
				var sw := pw * 0.46
				var swn := maxi(1, 2 * int(round(sw / (2.0 * ww))))
				var swwn: float = sw / float(swn)
				var wing := _wallbox(hn, sw, hh, pd, 0.2, tex, tone, ruin, 1, swwn, 0.42)
				hn.get_child(hn.get_child_count() - 1).position.x = pw * 0.27
				_frame_windows(hn, sw, pd, 0.2, 1, wing, swwn, 0.42, true)
				_roof(hn, sw + 0.8, pd + 0.8, 2.6, Vector3(pw * 0.27, hh + 0.2 + 1.3, 0), roof)
				_chimney(hn, -pw * 0.25, -pd * 0.3, hh + 0.8, 1.9, brk)
				_box(hn, Vector3(1.9, 2.6, 0.9), Vector3(-pw * 0.2, 1.5, pd * 0.0 + 0.4), _mat(tex, tone, 0.9, 0.3))
				_roof(hn, 2.2, 1.2, 0.8, Vector3(-pw * 0.2, 3.2 + 0.4, 0.4), roof)
				_door(hn, -pw * 0.2, pd * 0.0 + 0.9, wood, stone, 0.9)
				foot = 0.8
			3:   # Fachwerkhaus: ueberkragendes Obergeschoss, Holzbalken
				pw = clampf(pw, 4.6, 6.4)
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var h1 := 2.9
				var h2 := 2.8
				var fh1 := _wallbox(hn, pw, h1, pd, 0.2, "plaster", tone, ruin, 1, wn, 0.4)
				var fh2 := _wallbox(hn, pw + 0.7, h2, pd + 0.7, 0.2 + h1, "plaster", tone, ruin, 1, wn * (pw + 0.7) / pw, 0.4)
				_frame_windows(hn, pw, pd, 0.2, 1, fh1, wn, 0.4, true, 1)
				# Balken
				var tb := wood
				for k in range(-int(pw / 1.2), int(pw / 1.2) + 1):
					_box(hn, Vector3(0.13, h2, 0.1), Vector3(k * 1.2, 0.2 + h1 + h2 * 0.5, (pd + 0.7) * 0.5 + 0.04), tb)
					_box(hn, Vector3(0.13, h1, 0.1), Vector3(k * 1.2, 0.2 + h1 * 0.5, pd * 0.5 + 0.04), tb)
				for yy in [0.2, 0.2 + h1, 0.2 + h1 + h2 - 0.1]:
					_box(hn, Vector3(pw + 0.8, 0.14, 0.12), Vector3(0, yy, pd * 0.5 + 0.05), tb)
				for sx in [-1, 1]:
					_box(hn, Vector3(0.1, 1.9, 0.1), Vector3(sx * pw * 0.33, 0.2 + h1 + h2 * 0.5, (pd + 0.7) * 0.5 + 0.06), tb, 0.0, 0.0, sx * 0.7)
				_roof(hn, pw + 1.6, pd + 1.5, 3.2, Vector3(0, 0.2 + h1 + h2 + 1.6, 0), roof)
				_chimney(hn, pw * 0.25, -pd * 0.2, 0.2 + h1 + h2 + 1.0, 2.0, brk)
				_door(hn, 0, pd * 0.5, wood, stone)
				foot = 1.0
			4:   # Laden: Flachdach mit Attika, Schaufenster, Markise, Schild
				pw = clampf(pw, 5.0, 7.0)
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var hh := 5.6
				var fh := _wallbox(hn, pw, hh, pd, 0.2, tex, tone, ruin, 2, wn, 0.42)
				_frame_windows(hn, pw, pd, 0.2 + 2.0, 1, fh, wn, 0.42, false, 1)
				_box(hn, Vector3(pw + 0.3, 0.6, pd + 0.3), Vector3(0, 0.2 + hh + 0.2, 0), stone)
				_box(hn, Vector3(pw * 0.78, 1.7, 0.12), Vector3(-pw * 0.08, 1.15, pd * 0.5 + 0.03), glass)
				_box(hn, Vector3(pw * 0.78 + 0.2, 0.12, 0.16), Vector3(-pw * 0.08, 2.05, pd * 0.5 + 0.06), iron)
				var awn: Color = SHUTTER_COLS[_rng.randi() % SHUTTER_COLS.size()]
				_box(hn, Vector3(pw * 0.86, 0.08, 1.4), Vector3(-pw * 0.08, 2.5, pd * 0.5 + 0.7), _flat(awn, 0.8), 0.0, 0.3, 0.0)
				_box(hn, Vector3(pw * 0.5, 0.5, 0.1), Vector3(0, 3.1, pd * 0.5 + 0.1), _flat(Color(0.8, 0.75, 0.6), 0.8))
				_door(hn, pw * 0.36, pd * 0.5, wood, stone, 0.9)
				_chimney(hn, -pw * 0.3, -pd * 0.25, hh + 0.5, 1.3, brk)
				foot = 1.8
			5:   # Scheune: hohes Satteldach, Tor, Heuluke, Anbau
				pw = clampf(pw + 1.0, 6.0, 8.0)
				pd = clampf(pd + 0.5, 6.0, 7.6)
				var hh := 4.6
				_box(hn, Vector3(pw, hh, pd), Vector3(0, 0.2 + hh * 0.5, 0), _mat("wood", Color(0.9, 0.82, 0.74), 0.9, 0.28))
				_roof(hn, pw + 1.0, pd + 1.0, 3.4, Vector3(0, 0.2 + hh + 1.7, 0), roof)
				_box(hn, Vector3(pw * 0.5, 3.3, 0.18), Vector3(0, 1.85, pd * 0.5 + 0.05), wood)
				_box(hn, Vector3(0.12, 3.3, 0.22), Vector3(0, 1.85, pd * 0.5 + 0.08), dark)
				_box(hn, Vector3(1.3, 1.3, 0.14), Vector3(0, 0.2 + hh + 0.6, pd * 0.5 + 0.06), dark)
				_box(hn, Vector3(pw * 0.4, 2.6, pd * 0.7), Vector3(pw * 0.5 + pw * 0.2 - 0.1, 1.5, 0), _mat("wood", Color(0.8, 0.72, 0.64), 0.9, 0.28))
				_box(hn, Vector3(pw * 0.4 + 0.5, 0.18, pd * 0.7 + 0.5), Vector3(pw * 0.7 - 0.1, 2.9, 0), roof, 0.0, 0.0, -0.12)
				foot = 0.8
			6:   # Mietshaus: vier Geschosse, Flachdach, Balkonreihen
				pw = clampf(pw + 0.8, 6.0, 8.0)
				var n := maxi(2, 2 * int(round(pw / (2.0 * ww))))
				var wn: float = pw / float(n)
				var hh := 11.0
				var fh := _wallbox(hn, pw, hh, pd, 0.2, tex, tone, ruin, 4, wn, 0.44)
				_frame_windows(hn, pw, pd, 0.2, 4, fh, wn, 0.44, false, 1)
				_box(hn, Vector3(pw + 0.4, 0.4, pd + 0.4), Vector3(0, 0.2 + hh + 0.1, 0), stone)
				_box(hn, Vector3(pw * 0.25, 1.6, pd * 0.35), Vector3(pw * 0.3, 0.2 + hh + 1.2, -pd * 0.2), stone)
				for f in range(1, 4):
					for bx in [-0.5, 0.5]:
						_balcony(hn, bx * wn * 2.0, 0.2 + 0.9 + fh * (float(f) + 0.1), pd * 0.5, wn * 1.3, stone, iron)
				_door(hn, 0, pd * 0.5, wood, stone, 1.2)
				_chimney(hn, -pw * 0.3, -pd * 0.25, 0.2 + hh, 1.6, brk)
				foot = 1.2
	else:
		_ruin_house(hn, pw, pd, h, ruin, tex, tone, roof, wood, brk, rub, kind)
	_block(t, p, pw * 0.5 + foot * 0.5 + 0.4, pd * 0.5 + 0.4 + (foot if kind == 1 else 0.0) * 0.3)

## Ruine: je nach Bauform stehen Fassade, Giebel oder Schornstein noch; Dachreste, Laeden und Schutt liegen herum.
static func _ruin_house(hn: Node3D, w: float, d: float, h: float, ruin: float, tex: String, tone: Color, roof: Material, wood: Material, brk: Material, rub: Material, kind: int) -> void:
	var hh := h * _rng.randf_range(0.55, 1.0) + (2.0 if kind == 1 or kind == 6 else 0.0)
	var gap := _rng.randi() % 4
	var wn := 1.9
	for side in 4:
		var hi := hh * (1.0 if side != gap else _rng.randf_range(0.2, 0.45))
		var off: Vector3 = [Vector3(0, 0, d * 0.5), Vector3(0, 0, -d * 0.5), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, 0)][side]
		var sz := Vector3(w if side < 2 else 0.5, hi, 0.5 if side < 2 else d)
		_box(hn, sz, off + Vector3(0, hi * 0.5 + 0.2, 0), _facade(tex, tone, hi * 0.5, ruin, 2.8, wn, 0.42, Color(0.12, 0.17, 0.2)))
	# stehender Giebel oder Gesims
	if kind == 1 or kind == 3 or kind == 5:
		_roof(hn, w + 0.4, 0.5, 3.0, Vector3(0, hh + 0.2 + 1.5, d * 0.5), roof)
	for k in 5:
		_box(hn, Vector3(0.22, 0.22, w * _rng.randf_range(0.5, 0.95)), Vector3(_rng.randf_range(-w * 0.3, w * 0.3), hh + _rng.randf_range(0.0, 1.2), 0), wood, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.4, 0.4))
	_box(hn, Vector3(w * 0.55, 0.12, d * 0.5), Vector3(_rng.randf_range(-1, 1), hh * 0.55, _rng.randf_range(-1, 1)), roof, _rng.randf() * TAU, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
	_box(hn, Vector3(0.8, hh * 1.4, 0.8), Vector3(w * 0.28, hh * 0.7, d * 0.12), brk)
	# abgefallene Laeden
	for k in 3:
		_box(hn, Vector3(0.3, 1.1, 0.05), Vector3(_rng.randf_range(-w * 0.6, w * 0.6), 0.3, d * 0.5 + _rng.randf_range(0.3, 1.2)), _flat(SHUTTER_COLS[_rng.randi() % SHUTTER_COLS.size()] * 0.8, 0.9), _rng.randf() * TAU, 1.35, 0.0)
	_rubble(hn, Vector3.ZERO, maxf(w, d) * 0.75, 16, rub)

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
	var wallm := _facade("corrugated", Color(1, 1, 1) if ruin < 0.4 else Color(0.78, 0.72, 0.68), h * 0.5, ruin, h * 0.7, 4.0, 0.7, Color(0.15, 0.2, 0.22))
	var conc := _mat("concrete", Color(0.8, 0.8, 0.78), 0.9, 0.3)
	_box(parent, Vector3(w, h, d), local + Vector3(0, h * 0.5, 0), wallm)
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
	var streets: Array = []
	# Hauptstrasse: geschwungen, dazu Querstrassen mit unterschiedlicher Laenge
	var base := _rng.randf() * TAU
	var main := _street(c, base, r * 1.05, 0.35)
	streets.append(main)
	var nside := _rng.randi_range(3, 5)
	for i in nside:
		var k := _rng.randi_range(3, main.size() - 4)
		var pa: float = base + (PI * 0.5 if i % 2 == 0 else -PI * 0.5) + _rng.randf_range(-0.35, 0.35)
		var len := r * _rng.randf_range(0.35, 0.8)
		var sp := _street_from(main[k], pa, len, 0.5)
		streets.append(sp)
	for st in streets:
		_road(node, t, st, 5.0, ruin)
		_furniture(node, t, st, ruin)
	# Gebaeude entlang der Strassen, mit Luecken, Versatz und Ausrichtung zur Strasse
	var placed: Array = []
	var spacing := 17.0 if style == "modern" else 10.5
	for st in streets:
		var acc := 0.0
		for i in range(1, st.size()):
			acc += st[i].distance_to(st[i - 1])
			if acc < spacing * _rng.randf_range(0.8, 1.2):
				continue
			acc = 0.0
			var tg: Vector2 = (st[i] - st[i - 1]).normalized()
			var nrm := Vector2(-tg.y, tg.x)
			for sd in [-1.0, 1.0]:
				if _rng.randf() < 0.16:
					continue
				var is_modern: bool = style == "modern" or (style == "mixed" and st[i].distance_to(c) < r * 0.55 and _rng.randf() < 0.65)
				var rad := 9.5 if is_modern else 5.8
				var off := 5.5 + rad * 0.55 + _rng.randf_range(0.0, 3.5)
				var pp: Vector2 = st[i] + nrm * sd * off + tg * _rng.randf_range(-2.0, 2.0)
				if pp.distance_to(c) > r * 1.15 or _crowded(placed, pp, rad):
					continue
				if t.height_at(pp.x, pp.y) < t.WATER_Y + 0.6:
					continue
				var to_street: Vector2 = -nrm * sd
				_yaw = atan2(to_street.x, to_street.y)
				var rr := ruin if _rng.randf() < 0.92 else 0.0
				if is_modern:
					_tower(node, t, pp, _rng.randf_range(6.0, 9.0), _rng.randf_range(6.0, 9.0), _rng.randf_range(16.0, 38.0), rr)
				else:
					_house(node, t, pp, _rng.randf_range(4.5, 7.5), _rng.randf_range(4.5, 7.0), _rng.randf_range(3.0, 5.0), rr, _rng.randf() < 0.45)
				placed.append(Vector3(pp.x, pp.y, rad))
				_overgrow(node, t, pp, rad, ruin)
	_yaw = 0.0

static func _crowded(placed: Array, p: Vector2, rad: float) -> bool:
	for q in placed:
		if Vector2(q.x, q.y).distance_to(p) < q.z + rad:
			return true
	return false

## Geschwungene Strasse durch den Mittelpunkt, Punkte alle 3 m (Weltkoordinaten).
static func _street(c: Vector2, ang: float, half_len: float, amp: float) -> PackedVector2Array:
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var n := int(half_len * 2.0 / 3.0)
	var ph := _rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in n + 1:
		var al := -half_len + 3.0 * float(i)
		pts.append(c + dir * al + nrm * sin(al * 0.055 + ph) * half_len * amp * 0.25)
	return pts

static func _street_from(from: Vector2, ang: float, len: float, amp: float) -> PackedVector2Array:
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var n := int(len / 3.0)
	var ph := _rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in n + 1:
		var al := 3.0 * float(i)
		pts.append(from + dir * al + nrm * sin(al * 0.08 + ph) * len * amp * 0.15 * minf(al / 12.0, 1.0))
	return pts

## Strasse als Band entlang einer Punktfolge: folgt dem Gelaende, bricht an Wasser ab, Raender laufen in den Boden aus.
static func _road(node: Node3D, t, pts: PackedVector2Array, wd: float, ruin: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/road.gdshader")
	m.set_shader_parameter("asphalt_tex", load("res://models/resources/%sasphalt_albedo.png" % BIO))
	m.set_shader_parameter("walk_tex", load("res://models/resources/%sconcrete_albedo.png" % BIO))
	m.set_shader_parameter("fog_tex", Game.fog_tex)
	m.set_shader_parameter("ruin", ruin)
	m.set_shader_parameter("seed", _rng.randf_range(1.0, 50.0))
	var half := wd
	var st := SurfaceTool.new()
	var open := false
	var along := 0.0
	var G: int = Game.GRID
	for i in pts.size():
		var tg2: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var sd2 := Vector2(-tg2.y, tg2.x)
		for k in range(-4, 5):
			var q2: Vector2 = pts[i] + sd2 * (float(k) * wd * 0.2) + tg2 * 1.5
			var c2: Vector2i = Game.world_to_cell(Vector3(q2.x, 0, q2.y))
			if c2.x >= 0 and c2.y >= 0 and c2.x < G and c2.y < G and t.height_at(q2.x, q2.y) > t.WATER_Y + 0.25:
				t.road_cells[c2.y * G + c2.x] = 1
	var o := Vector3(-node.position.x, -node.position.y, -node.position.z)
	for i in pts.size():
		var tg: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tg.y, tg.x)
		var q: Vector2 = pts[i]
		if i > 0:
			along += q.distance_to(pts[i - 1])
		var l := q + side * half
		var r := q - side * half
		var yl: float = t.height_at(l.x, l.y)
		var yr: float = t.height_at(r.x, r.y)
		var yc: float = t.height_at(q.x, q.y)
		var wet: bool = minf(minf(yl, yr), yc) < t.WATER_Y + 0.25
		if wet:
			if open:
				_add(node, st.commit(), m, Vector3.ZERO)
				open = false
			continue
		if not open:
			st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			open = true
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, along))
		st.add_vertex(Vector3(l.x, yl + 0.06, l.y) + o)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, along))
		st.add_vertex(Vector3(r.x, yr + 0.06, r.y) + o)
	if open:
		_add(node, st.commit(), m, Vector3.ZERO)

# ---------------------------------------------------------------- Verfall und Bewuchs

static func _bush(parent: Node3D, pos: Vector3, sc: float) -> void:
	var gm := _flat(Color(0.14, 0.26, 0.09).lerp(Color(0.3, 0.34, 0.12), _rng.randf()), 0.95)
	var sp := SphereMesh.new()
	sp.radial_segments = 8
	sp.rings = 4
	for k in _rng.randi_range(2, 4):
		sp.radius = _rng.randf_range(0.5, 0.9) * sc
		sp.height = sp.radius * 1.5
		_add(parent, sp, gm, pos + Vector3(_rng.randf_range(-0.5, 0.5) * sc, sp.radius * 0.6, _rng.randf_range(-0.5, 0.5) * sc))

static func _sapling(parent: Node3D, pos: Vector3, sc: float) -> void:
	var trunk := _flat(Color(0.25, 0.18, 0.12), 0.95)
	var h := 2.4 * sc
	_cyl(parent, 0.08 * sc, 0.14 * sc, h, pos + Vector3(0, h * 0.5, 0), trunk, 6)
	var gm := _flat(Color(0.17, 0.3, 0.1).lerp(Color(0.38, 0.4, 0.13), _rng.randf()), 0.95)
	var sp := SphereMesh.new()
	sp.radial_segments = 8
	sp.rings = 5
	for k in 3:
		sp.radius = _rng.randf_range(0.8, 1.3) * sc
		sp.height = sp.radius * 1.7
		_add(parent, sp, gm, pos + Vector3(_rng.randf_range(-0.5, 0.5) * sc, h + _rng.randf_range(0.0, 0.7) * sc, _rng.randf_range(-0.5, 0.5) * sc))

## Natur holt sich die Stadt zurueck: Buesche am Haus, Baeume im Gemaeuer, Schutt, Zaunreste.
static func _overgrow(parent: Node3D, t, p: Vector2, rad: float, ruin: float) -> void:
	var by: float = t.height_at(p.x, p.y) - parent.position.y
	var base := Vector3(p.x - parent.position.x, by, p.y - parent.position.z)
	var n := int(round(ruin * 5.0 + 1.0))
	for i in n:
		var a := _rng.randf() * TAU
		var dd := rad * _rng.randf_range(0.5, 1.15)
		var pos := base + Vector3(cos(a) * dd, 0, sin(a) * dd)
		if t.height_at(p.x + cos(a) * dd, p.y + sin(a) * dd) < t.WATER_Y + 0.4:
			continue
		if _rng.randf() < 0.3 * ruin + 0.1:
			_sapling(parent, pos, _rng.randf_range(0.7, 1.5))
		else:
			_bush(parent, pos, _rng.randf_range(0.7, 1.4))
	if ruin > 0.5 and _rng.randf() < 0.55:
		var w := _flat(Color(0.3, 0.22, 0.15), 0.9)
		var fa := _rng.randf() * TAU
		for k in _rng.randi_range(2, 5):
			var fp := base + Vector3(cos(fa) * rad * 1.1 + k * 1.4, 0.5, sin(fa) * rad * 1.1)
			_cyl(parent, 0.06, 0.07, _rng.randf_range(0.8, 1.2), fp, w, 5).rotation.z = _rng.randf_range(-0.5, 0.5)

## Strassenmoebel: Laternen (geneigt, abgebrochen), Autowracks, Schutt, aufkeimende Baeumchen.
static func _furniture(node: Node3D, t, pts: PackedVector2Array, ruin: float) -> void:
	var pole := _flat(Color(0.2, 0.21, 0.22), 0.55)
	var rust := _mat("rust", Color(1, 1, 1), 0.85, 0.5)
	var glass := _flat(Color(0.12, 0.16, 0.18), 0.25)
	var tyre := _flat(Color(0.07, 0.07, 0.08), 0.95)
	var acc_l := 0.0
	var acc_c := 8.0
	var o := Vector3(-node.position.x, -node.position.y, -node.position.z)
	for i in range(1, pts.size()):
		var seg: float = pts[i].distance_to(pts[i - 1])
		acc_l += seg
		acc_c += seg
		var tg: Vector2 = (pts[i] - pts[i - 1]).normalized()
		var nrm := Vector2(-tg.y, tg.x)
		var q: Vector2 = pts[i]
		var y: float = t.height_at(q.x, q.y)
		if y < t.WATER_Y + 0.5:
			continue
		if acc_l > 15.0:
			acc_l = 0.0
			var sd := 1.0 if _rng.randf() < 0.5 else -1.0
			var lp: Vector2 = q + nrm * sd * 6.4
			var ly: float = t.height_at(lp.x, lp.y)
			var ln := Node3D.new()
			ln.position = Vector3(lp.x, ly, lp.y) + o
			node.add_child(ln)
			var hgt := 5.2
			if _rng.randf() < ruin * 0.35:
				hgt = _rng.randf_range(1.5, 3.0)   # abgebrochen
			elif _rng.randf() < ruin * 0.5:
				ln.rotation.z = _rng.randf_range(-0.35, 0.35)
				ln.rotation.x = _rng.randf_range(-0.35, 0.35)
			_cyl(ln, 0.06, 0.1, hgt, Vector3(0, hgt * 0.5, 0), pole, 6)
			if hgt > 4.0:
				_box(ln, Vector3(1.3, 0.07, 0.07), Vector3(-nrm.x * sd * 0.6, hgt, -nrm.y * sd * 0.6), pole, atan2(nrm.x, nrm.y))
				_box(ln, Vector3(0.4, 0.14, 0.22), Vector3(-nrm.x * sd * 1.2, hgt - 0.08, -nrm.y * sd * 1.2), glass if _rng.randf() > ruin * 0.6 else pole, atan2(nrm.x, nrm.y))
		if acc_c > 26.0 and _rng.randf() < 0.55:
			acc_c = 0.0
			var cp: Vector2 = q + nrm * _rng.randf_range(-1.6, 1.6)
			var cy: float = t.height_at(cp.x, cp.y)
			var car := Node3D.new()
			car.position = Vector3(cp.x, cy + 0.02, cp.y) + o
			car.rotation.y = atan2(tg.x, tg.y) + _rng.randf_range(-0.5, 0.5)
			node.add_child(car)
			_box(car, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.65, 0), rust)
			_box(car, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.25, -0.2), glass)
			_box(car, Vector3(1.7, 0.06, 2.0), Vector3(0, 1.58, -0.2), rust, 0.0, 0.05, 0.0)
			for wx in [-0.95, 0.95]:
				for wz in [-1.4, 1.4]:
					var wh := CylinderMesh.new()
					wh.top_radius = 0.34
					wh.bottom_radius = 0.34
					wh.height = 0.25
					wh.radial_segments = 10
					var wmi := _add(car, wh, tyre, Vector3(wx, 0.34, wz))
					wmi.rotation.z = PI * 0.5
			if _rng.randf() < 0.5:
				_bush(node, Vector3(cp.x, cy, cp.y) + o + Vector3(1.2, 0, 0.5), 0.8)
		elif _rng.randf() < ruin * 0.05:
			var sp2: Vector2 = q + nrm * _rng.randf_range(-2.0, 2.0)
			_sapling(node, Vector3(sp2.x, t.height_at(sp2.x, sp2.y), sp2.y) + o, _rng.randf_range(0.5, 1.0))
		elif _rng.randf() < ruin * 0.05:
			_rubble(node, Vector3(q.x, y, q.y) + o, 1.6, 6, _mat("rubble", Color(0.8, 0.78, 0.74), 0.95, 0.25))

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
