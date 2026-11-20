extends RefCounted
## Dekor ("Doodads"): Baumstümpfe, Baumstämme, Pilzringe, Steinhügel, Menhire, Knochen, Feuerstellen,
## Kisten, Zäune, Heuhaufen, Wracks, Wegweiser. Reine Optik, keine Kollision, in Gruppen gestreut,
## gewichtet nach Biom. Alles als MultiMesh-Kacheln (wie die Vegetation).

const Veg = preload("res://scripts/vegetation.gd")

# Gewichte je Biom; "" ist die gemäßigte Standardlandschaft
const WEIGHTS := {
	"": {"stump": 2.0, "log": 2.0, "mushroom": 1.5, "cairn": 0.5, "stone": 0.4, "bones": 0.2, "camp": 0.3, "fence": 0.4, "hay": 0.3, "sign": 0.3, "crates": 0.2},
	"alpine": {"cairn": 3.0, "stone": 2.0, "log": 1.0, "stump": 1.0, "bones": 0.6, "camp": 0.4, "sign": 0.5, "wreck": 0.2},
	"steppe": {"hay": 1.8, "fence": 1.2, "bones": 1.0, "wreck": 0.7, "stump": 0.3, "camp": 0.5, "sign": 0.5, "crates": 0.4, "stone": 0.5},
	"boreal": {"stump": 3.0, "log": 3.0, "mushroom": 3.0, "camp": 0.6, "cairn": 0.3, "bones": 0.3, "sign": 0.3},
	"marsh": {"log": 2.0, "stump": 1.2, "mushroom": 2.4, "bones": 0.5, "wreck": 0.3, "stone": 0.3},
	"coast": {"crates": 1.8, "wreck": 0.7, "cairn": 0.6, "log": 0.8, "sign": 0.6, "fence": 0.5, "camp": 0.4},
	"ashland": {"wreck": 2.2, "bones": 1.6, "camp": 1.2, "crates": 1.0, "sign": 0.6, "fence": 0.6, "stump": 0.6, "stone": 0.3},
	"highland": {"stone": 3.0, "cairn": 2.0, "fence": 0.7, "hay": 0.3, "camp": 0.6, "bones": 0.5, "log": 0.5, "sign": 0.4},
	"tropical": {"log": 2.1, "stump": 1.8, "crates": 1.0, "wreck": 0.6, "mushroom": 0.45},
	"volcanic": {"stone": 3.3, "cairn": 1.6, "wreck": 0.8, "sign": 0.6, "bones": 0.4},
}

# Grundfarbe und Rauheit je Dekor-Art
const LOOK := {
	"stump": [Color(0.36, 0.26, 0.17), 0.95], "log": [Color(0.32, 0.23, 0.15), 0.95], "mushroom": [Color(0.8, 0.28, 0.2), 0.7],
	"cairn": [Color(0.5, 0.48, 0.44), 0.95], "stone": [Color(0.42, 0.42, 0.4), 0.95], "bones": [Color(0.85, 0.82, 0.72), 0.9],
	"camp": [Color(0.16, 0.14, 0.12), 0.95], "fence": [Color(0.4, 0.3, 0.2), 0.95], "hay": [Color(0.82, 0.68, 0.34), 0.95],
	"wreck": [Color(0.34, 0.24, 0.17), 0.8], "sign": [Color(0.45, 0.34, 0.22), 0.9], "crates": [Color(0.5, 0.38, 0.22), 0.9],
}

static func build(t, seed_val: int) -> void:
	var bio_name: String = String(t.spec.get("biome", ""))
	var table: Dictionary = WEIGHTS.get(bio_name, WEIGHTS[""])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 911
	var meshes := {}
	for k in LOOK:
		meshes[k] = _mesh_for(k, rng)
	var mats := {}
	var tex := {"stump": "bio_bark", "log": "bio_bark", "cairn": "bio_stone", "stone": "bio_stone", "fence": "bio_wood", "sign": "bio_wood",
		"crates": "bio_wood", "hay": "bio_hay", "wreck": "bio_rust"}
	for k in LOOK:
		if tex.has(k):
			mats[k] = Game.resource_material(tex[k], Color(1, 1, 1), float(LOOK[k][1]), 0.9, 0.0, 0.0, false)
		else:
			mats[k] = Game.fog_material(LOOK[k][0], LOOK[k][1])
	var lists := {}
	for k in LOOK:
		lists[k] = {}
	var total := 0.0
	for k in table:
		total += float(table[k])
	var clusters: int = int(170.0 * pow(float(t.SIZE) / 240.0, 2.0))
	var lim: float = Game.HALF - 10.0
	var G: int = Game.GRID
	for c in clusters:
		var roll: float = rng.randf() * total
		var kind := ""
		for k in table:
			roll -= float(table[k])
			if roll <= 0.0:
				kind = k
				break
		if kind == "":
			continue
		var cx: float = rng.randf_range(-lim, lim)
		var cz: float = rng.randf_range(-lim, lim)
		var n_items: int = rng.randi_range(2, 6)
		if kind == "wreck" or kind == "hay" or kind == "camp" or kind == "sign" or kind == "cairn":
			n_items = rng.randi_range(1, 3)
		var line_dir: float = rng.randf() * TAU
		for i in n_items:
			var p := Vector2(cx, cz)
			if kind == "fence":
				p += Vector2(cos(line_dir), sin(line_dir)) * (i * 2.1)
			else:
				p += Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
			if absf(p.x) > lim or absf(p.y) > lim:
				continue
			var h: float = t.height_at(p.x, p.y)
			if h < t.WATER_Y + 0.5:
				continue
			var nrm: Vector3 = t.normal_at(p.x, p.y)
			if nrm.y < 0.86 and kind != "stone" and kind != "cairn":
				continue
			var cell: Vector2i = Game.world_to_cell(Vector3(p.x, 0, p.y))
			if cell.x < 1 or cell.y < 1 or cell.x >= G - 1 or cell.y >= G - 1 or t.blocked[cell.y * G + cell.x] == 1:
				continue
			if Veg._in_flat(p.x, p.y, t.flat_list):
				continue
			var s: float = rng.randf_range(0.8, 1.35)
			var yaw: float = line_dir if kind == "fence" else rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
			var v: float = rng.randf_range(0.8, 1.15)
			var col := Color(v, v, v)
			if kind == "mushroom":
				col = [Color(1, 1, 1), Color(1.2, 1.1, 0.6), Color(0.9, 0.6, 0.9)][rng.randi() % 3]
			var chunk := Vector2i(int(floor(p.x / Veg.CHUNK)), int(floor(p.y / Veg.CHUNK)))
			if not lists[kind].has(chunk):
				lists[kind][chunk] = []
			lists[kind][chunk].append([Transform3D(b, Vector3(p.x, h - 0.05, p.y)), col])
	for k in LOOK:
		Veg._emit_chunks(t, lists[k], meshes[k], mats[k], 170.0, true)

# ---------------------------------------------------------------- Meshe

static func _part(st: SurfaceTool, m: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot)
	st.append_from(m, 0, Transform3D(b, pos))

static func _cyl(top: float, bot: float, h: float, seg := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _mesh_for(kind: String, rng: RandomNumberGenerator) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"stump":
			_part(st, _cyl(0.32, 0.42, 0.55), Vector3(0, 0.27, 0))
			_part(st, _cyl(0.2, 0.5, 0.18), Vector3(0, 0.05, 0))
		"log":
			_part(st, _cyl(0.22, 0.26, 2.6, 8), Vector3(0, 0.24, 0), Vector3(0, 0, PI * 0.5))
			_part(st, _cyl(0.06, 0.09, 0.7, 5), Vector3(0.5, 0.45, 0.1), Vector3(0.5, 0, 0.9))
		"mushroom":
			for i in 5:
				var a: float = rng.randf() * TAU
				var r: float = rng.randf_range(0.2, 0.9)
				var sc: float = rng.randf_range(0.6, 1.2)
				var pos := Vector3(cos(a) * r, 0, sin(a) * r)
				_part(st, _cyl(0.04, 0.05, 0.25 * sc, 5), pos + Vector3(0, 0.12 * sc, 0))
				_part(st, _cyl(0.02, 0.2 * sc, 0.12 * sc, 7), pos + Vector3(0, 0.3 * sc, 0))
		"cairn":
			var sp := SphereMesh.new()
			sp.radial_segments = 6
			sp.rings = 3
			for k in 4:
				sp.radius = 0.5 - k * 0.1
				sp.height = sp.radius * 1.3
				_part(st, sp, Vector3(rng.randf_range(-0.05, 0.05), 0.2 + k * 0.28, rng.randf_range(-0.05, 0.05)))
		"stone":
			_part(st, _box(0.7, 2.6, 0.45), Vector3(0, 1.2, 0), Vector3(0.05, 0.4, 0.12))
			_part(st, _box(0.9, 0.5, 0.7), Vector3(0.9, 0.2, 0.4), Vector3(0.0, 0.6, 0.1))
		"bones":
			_part(st, _box(0.08, 0.06, 1.1), Vector3(0, 0.05, 0), Vector3(0, 0.3, 0))
			for k in 5:
				_part(st, _box(0.05, 0.05, 0.6), Vector3(0, 0.16, -0.35 + k * 0.17), Vector3(0, 0.3, 0.9))
			var sk := SphereMesh.new()
			sk.radius = 0.16
			sk.height = 0.26
			sk.radial_segments = 6
			sk.rings = 3
			_part(st, sk, Vector3(0.5, 0.1, 0.55))
		"camp":
			for k in 8:
				var a := k * TAU / 8.0
				_part(st, _box(0.3, 0.2, 0.22), Vector3(cos(a) * 0.65, 0.1, sin(a) * 0.65), Vector3(0, -a, 0))
			_part(st, _cyl(0.4, 0.45, 0.04, 8), Vector3(0, 0.02, 0))
			_part(st, _box(0.07, 0.07, 0.8), Vector3(0.1, 0.12, 0), Vector3(0, 0.8, 0.2))
		"fence":
			for k in 2:
				_part(st, _cyl(0.07, 0.09, 1.2, 5), Vector3(k * 2.1 - 1.05, 0.55, 0))
			_part(st, _box(2.1, 0.09, 0.07), Vector3(0, 0.95, 0), Vector3(0, 0, 0.04))
			_part(st, _box(2.1, 0.09, 0.07), Vector3(0, 0.55, 0), Vector3(0, 0, -0.05))
		"hay":
			_part(st, _cyl(0.0, 0.9, 1.0, 8), Vector3(0, 1.2, 0))
			_part(st, _cyl(0.9, 0.95, 0.9, 8), Vector3(0, 0.45, 0))
		"wreck":
			_part(st, _box(2.6, 0.7, 1.5), Vector3(0, 0.5, 0), Vector3(0.0, 0.0, 0.12))
			_part(st, _box(1.1, 0.5, 1.0), Vector3(-0.2, 1.05, 0.1), Vector3(0.0, 0.3, 0.08))
			_part(st, _cyl(0.07, 0.07, 1.6, 6), Vector3(0.8, 1.2, 0.1), Vector3(0, 0, 1.2))
			_part(st, _cyl(0.4, 0.4, 0.3, 8), Vector3(1.1, 0.25, 0.9), Vector3(PI * 0.5, 0, 0))
		"sign":
			_part(st, _cyl(0.06, 0.08, 1.7, 5), Vector3(0, 0.85, 0))
			_part(st, _box(0.85, 0.28, 0.05), Vector3(0.28, 1.45, 0), Vector3(0, 0, 0.08))
			_part(st, _box(0.7, 0.24, 0.05), Vector3(-0.2, 1.1, 0), Vector3(0, 0, -0.1))
		"crates":
			_part(st, _box(0.8, 0.7, 0.8), Vector3(0, 0.35, 0))
			_part(st, _box(0.7, 0.6, 0.7), Vector3(0.85, 0.3, 0.2), Vector3(0, 0.4, 0))
			_part(st, _box(0.6, 0.5, 0.6), Vector3(0.3, 0.95, 0.05), Vector3(0, 0.2, 0))
			_part(st, _cyl(0.32, 0.32, 0.9, 10), Vector3(-0.8, 0.45, 0.5))
	st.generate_normals()
	return st.commit()
