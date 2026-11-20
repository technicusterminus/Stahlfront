extends RefCounted
## Vegetation und Felsen: Gras, Blumen, Büsche, Schilf, Nadel- und Laubbäume, Felsbrocken.
## Alles als MultiMesh in Kacheln (für Sichtbarkeits-Culling), Wind per Shader.

const CHUNK := 30.0

static func build(t, seed_val: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 5
	var dens = FastNoiseLite.new()
	dens.seed = seed_val + 41
	dens.frequency = 0.035
	var dry = FastNoiseLite.new()
	dry.seed = seed_val + 43
	dry.frequency = 0.02
	var kind = FastNoiseLite.new()
	kind.seed = seed_val + 47
	kind.frequency = 0.03

	var grass_mesh = _clump(rng, 15, 0.55, 0.032, 0.30)
	var short_mesh = _clump(rng, 13, 0.26, 0.028, 0.22)
	var tall_mesh = _clump(rng, 13, 1.0, 0.03, 0.32)
	var reed_mesh = _clump(rng, 7, 1.7, 0.035, 0.2)
	var flower_mesh = _flowers(rng)
	var bush_mesh = _blob_mesh(rng, 5, 0.55, 0.35)

	var grass_m = _foliage(Color(0.42, 0.52, 0.28), Color(0.95, 1.0, 0.75), 0.13, 0.6, true, 0.45)
	var reed_m = _foliage(Color(0.35, 0.4, 0.22), Color(0.75, 0.7, 0.45), 0.2, 1.7, true, 0.3)
	var flower_m = _foliage(Color(0.9, 0.9, 0.9), Color(1, 1, 1), 0.1, 0.5, true, 0.5)
	var bush_m = _foliage(Color(0.38, 0.45, 0.3), Color(0.75, 0.8, 0.6), 0.05, 1.2, true, 0.2)

	var grass := {}
	var grass_s := {}
	var grass_t := {}
	var flowers := {}
	var reeds := {}
	var bushes := {}
	var flats: Array = t.flat_list
	var bio: Dictionary = load("res://scripts/biome.gd").of(t)
	var gdens: float = float(bio.get("grass_dens", 1.0))

	var lim: float = Game.HALF - 8.0
	var x: float = -lim
	while x < lim:
		var z: float = -lim
		while z < lim:
			var px = x + rng.randf_range(-0.45, 0.45)
			var pz = z + rng.randf_range(-0.45, 0.45)
			z += 0.64
			var h: float = t.height_at(px, pz)
			var n: Vector3 = t.normal_at(px, pz)
			# Schilf am Ufer und im Flachwasser
			if h > t.WATER_Y - 0.3 and h < t.WATER_Y + 0.45:
				if rng.randf() < 0.55:
					var s = rng.randf_range(0.7, 1.2)
					_add(reeds, Vector3(px, h, pz), s, rng, Color(0.75, 0.8, 0.55).lerp(Color(0.6, 0.5, 0.3), rng.randf() * 0.5))
				continue
			if h < t.WATER_Y + 0.45 or n.y < 0.84:
				continue
			var d = dens.get_noise_2d(px, pz) * 0.5 + 0.5
			var zr: Color = t.zone_at(px, pz)
			var meadow = max(1.0 - (zr.r + zr.g + zr.b + zr.a), 0.0)
			var dmul = meadow + zr.r * 0.75 + zr.g * 0.9 + zr.b * 0.95 + zr.a * 0.22
			if rng.randf() > d * 1.15 * dmul * gdens:
				continue
			var dr = clamp(dry.get_noise_2d(px, pz) * 1.6 + 0.2, 0.0, 1.0)
			var gc = Color(0.55, 0.8, 0.4).lerp(Color(0.95, 0.85, 0.5), dr * 0.7)
			gc = gc.lerp(Color(0.4, 0.6, 0.3), rng.randf() * 0.3)
			# Farbe nach Zone: Steppe strohgelb, Heide rötlich-braun, Waldboden dunkel, Fels grau-grün
			gc = gc.lerp(Color(0.9, 0.8, 0.42), zr.r * 0.8).lerp(Color(0.62, 0.46, 0.44), zr.g * 0.8)
			gc = gc.lerp(Color(0.28, 0.48, 0.26), zr.b * 0.7).lerp(Color(0.56, 0.6, 0.46), zr.a * 0.7)
			if bio.has("blade"):
				gc = gc.lerp(bio["blade"], float(bio["blade_amt"]) * (0.75 + rng.randf() * 0.4))
			var gs = rng.randf_range(0.7, 1.3)
			var pick = rng.randf()
			if pick < zr.g * 0.9 + zr.a * 0.85:
				_add(grass_s, Vector3(px, h, pz), gs, rng, gc)
			elif pick < zr.g * 0.9 + zr.a * 0.85 + zr.r * 1.1:
				_add(grass_t, Vector3(px, h, pz), gs * rng.randf_range(0.85, 1.15), rng, gc)
			else:
				_add(grass, Vector3(px, h, pz), gs, rng, gc)
			var fl = 0.035 * meadow * (1.0 - dr) + zr.g * 0.09 + zr.r * 0.012 + zr.b * 0.01
			if rng.randf() < fl:
				var fc = [Color(1, 1, 1), Color(1, 0.85, 0.2), Color(0.7, 0.45, 1.0), Color(0.95, 0.25, 0.2), Color(0.4, 0.6, 1.0)][rng.randi() % 5]
				if zr.g > 0.4:
					fc = [Color(0.75, 0.3, 0.7), Color(0.85, 0.4, 0.75), Color(0.6, 0.25, 0.6)][rng.randi() % 3]
				elif zr.r > 0.4:
					fc = [Color(1, 0.85, 0.25), Color(0.95, 0.6, 0.2)][rng.randi() % 2]
				_add(flowers, Vector3(px, h, pz), rng.randf_range(0.8, 1.2), rng, fc)
			if rng.randf() < 0.012 + zr.g * 0.02 + zr.b * 0.014 + zr.a * 0.004 and not _in_flat(px, pz, flats):
				var bc = Color(0.3, 0.45, 0.2).lerp(Color(0.45, 0.42, 0.22), dr * 0.6 + rng.randf() * 0.2)
				bc = bc.lerp(Color(0.4, 0.3, 0.3), zr.g * 0.7)
				_add(bushes, Vector3(px, h - 0.1, pz), rng.randf_range(0.7, 1.6), rng, bc)
		x += 0.64

	_emit_chunks(t, grass, grass_mesh, grass_m, 150.0)
	_emit_chunks(t, grass_s, short_mesh, grass_m, 120.0)
	_emit_chunks(t, grass_t, tall_mesh, grass_m, 150.0)
	_emit_chunks(t, flowers, flower_mesh, flower_m, 130.0)
	_emit_chunks(t, reeds, reed_mesh, reed_m, 170.0)
	_emit_chunks(t, bushes, bush_mesh, bush_m, 220.0, true)
	_trees(t, rng, kind)
	_rocks(t, rng)

static func _in_flat(x: float, z: float, flats: Array) -> bool:
	for f in flats:
		if Vector2(x, z).distance_to(Vector2(f.x, f.y)) < f.z:
			return true
	return false

static func _add(dict: Dictionary, p: Vector3, s: float, rng, col: Color) -> void:
	var k = Vector2i(int(floor(p.x / CHUNK)), int(floor(p.z / CHUNK)))
	if not dict.has(k):
		dict[k] = []
	var b = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
	dict[k].append([Transform3D(b, p), col])

static func _emit_chunks(t, dict: Dictionary, mesh: Mesh, m: Material, vis_end: float, shadows := false) -> void:
	for k in dict:
		var arr: Array = dict[k]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i][0])
			mm.set_instance_color(i, arr[i][1])
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		t.add_child(mmi)

static func _foliage(base: Color, tip: Color, wind: float, sway_h: float, occ: bool, transl: float) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("fog_tex", Game.fog_tex)
	m.set_shader_parameter("occ_tex", Game.occ_tex)
	m.set_shader_parameter("use_occ", occ)
	m.set_shader_parameter("wind", wind)
	m.set_shader_parameter("sway_h", sway_h)
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("tip_col", tip)
	m.set_shader_parameter("translucency", transl)
	return m

# ---------------------------------------------------------------- Meshes

## Grasbüschel: einzelne, leicht gebogene Halme (je zwei Dreiecke).
static func _clump(rng, blades: int, h: float, w: float, spread: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in blades:
		var a = rng.randf() * TAU
		var r = sqrt(rng.randf()) * spread
		var base = Vector3(cos(a) * r, 0, sin(a) * r)
		var face = rng.randf() * TAU
		var right = Vector3(cos(face), 0, sin(face)) * w
		var hh = h * rng.randf_range(0.6, 1.1)
		var lean = Vector3(cos(a), 0, sin(a)) * hh * rng.randf_range(0.1, 0.35)
		var mid = base + lean * 0.35 + Vector3(0, hh * 0.55, 0)
		var tip = base + lean + Vector3(0, hh, 0)
		st.set_normal(Vector3.UP)
		for v in [base - right, base + right, mid + right * 0.6, base - right, mid + right * 0.6, mid - right * 0.6,
				mid - right * 0.6, mid + right * 0.6, tip]:
			st.set_normal(Vector3(0, 1, 0))
			st.add_vertex(v)
	return st.commit()

static func _flowers(rng) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a = rng.randf() * TAU
		var r = rng.randf() * 0.18
		var p = Vector3(cos(a) * r, rng.randf_range(0.3, 0.48), sin(a) * r)
		var s = 0.06
		# kleine Blüte aus zwei gekreuzten Quadraten
		for q in [[Vector3(s, 0, 0), Vector3(0, 0, s)], [Vector3(s, 0, 0), Vector3(0, s, 0)]]:
			var u: Vector3 = q[0]
			var v: Vector3 = q[1]
			for vert in [p - u - v, p + u - v, p + u + v, p - u - v, p + u + v, p - u + v]:
				st.set_normal(Vector3.UP)
				st.add_vertex(vert)
	return st.commit()

## Unregelmäßiger Klumpen aus mehreren Kugeln (Büsche, Laubkronen).
static func _blob_mesh(rng, blobs: int, r: float, spread: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sm = SphereMesh.new()
	sm.radial_segments = 8
	sm.rings = 5
	for i in blobs:
		var rr = r * rng.randf_range(0.7, 1.1)
		sm.radius = rr
		sm.height = rr * 1.7
		var a = rng.randf() * TAU
		var off = Vector3(cos(a) * spread * rng.randf(), rr * 0.75 + rng.randf() * spread * 0.6, sin(a) * spread * rng.randf())
		st.append_from(sm, 0, Transform3D(Basis(), off))
	return st.commit()

static func _rock_mesh(rng) -> ArrayMesh:
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.5
	sm.radial_segments = 12
	sm.rings = 7
	var arr = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz = FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.9
	for i in verts.size():
		var v = verts[i]
		var k = 1.0 + nz.get_noise_3dv(v) * 0.35
		v *= k
		v.y = max(v.y, -0.15) # flache Unterseite
		verts[i] = Vector3(round(v.x * 6.0) / 6.0, v.y, round(v.z * 6.0) / 6.0).lerp(v, 0.6)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()

# ---------------------------------------------------------------- Bäume

static func _trees(t, rng, kind) -> void:
	var fog_trunk = Game.fog_material(Color(0.24, 0.17, 0.11), 0.95)
	var trunk = CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.26
	trunk.height = 2.4
	trunk.radial_segments = 7
	# Nadelbaum: drei gestapelte Kegel
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.radial_segments = 9
	cone.rings = 1
	for k in 3:
		cone.bottom_radius = 1.75 - k * 0.45
		cone.height = 2.6 - k * 0.4
		st.append_from(cone, 0, Transform3D(Basis(), Vector3(0, 1.3 + k * 1.35 + cone.height * 0.5, 0)))
	var conifer = st.commit()
	var leafy = _blob_mesh(rng, 6, 1.2, 1.0)
	var conif_m = _foliage(Color(0.45, 0.55, 0.42), Color(0.8, 0.95, 0.7), 0.1, 6.0, false, 0.2)
	var leafy_m = _foliage(Color(0.5, 0.6, 0.4), Color(1.0, 1.05, 0.8), 0.14, 5.0, false, 0.35)

	var bio: Dictionary = load("res://scripts/biome.gd").of(t)
	var tmul: float = float(bio.get("trees", 1.0))
	var trunks := []
	var cons := []
	var leafs := []
	var root_groups := []
	for c in t.tree_cells:
		for k in 2:
			if tmul < 1.0 and rng.randf() > tmul:
				continue
			var x: float = c.x * 2.0 - Game.HALF + rng.randf_range(0.2, 1.8)
			var z: float = c.y * 2.0 - Game.HALF + rng.randf_range(0.2, 1.8)
			var y: float = t.height_at(x, z)
			var s = rng.randf_range(0.75, 1.4)
			var b = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			trunks.append([Transform3D(b, Vector3(x, y + 1.2 * s, z)), Color(1, 1, 1)])
			if bio.get("mangrove", false) and y < 2.8:
				root_groups.append([Transform3D(b, Vector3(x, y, z)), Color.WHITE])
			var is_conifer = y > 4.0 or kind.get_noise_2d(x, z) > 0.0
			if bio.has("conifer"):
				var cf: float = float(bio["conifer"])
				is_conifer = rng.randf() < cf if y < 4.0 or cf < 0.5 else true
			var dead: bool = rng.randf() < float(bio.get("dead", 0.0))
			if is_conifer:
				var g = Color(0.14, 0.28, 0.13).lerp(Color(0.2, 0.3, 0.12), rng.randf())
				if dead:
					g = Color(0.2, 0.17, 0.13)
				cons.append([Transform3D(b, Vector3(x, y, z)), g])
			else:
				var g2 = Color(0.25, 0.42, 0.15).lerp(Color(0.5, 0.48, 0.15), rng.randf() * 0.4)
				if bio.has("leaf"):
					g2 = g2.lerp(bio["leaf"], float(bio["leaf_amt"]))
				if dead:
					g2 = Color(0.22, 0.18, 0.13)
				var bl = b.scaled(Vector3(1.0, rng.randf_range(0.85, 1.15), 1.0))
				leafs.append([Transform3D(bl, Vector3(x, y + 2.1 * s, z)), g2])
	_emit_list(t, trunks, trunk, fog_trunk, true)
	_emit_list(t, cons, conifer, conif_m, true)
	_emit_list(t, leafs, leafy, leafy_m, true)
	if not root_groups.is_empty():
		_emit_list(t, root_groups, _mangrove_roots(), fog_trunk, true)

static func _mangrove_roots() -> Mesh:
	var roots := SurfaceTool.new()
	roots.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strut := CylinderMesh.new()
	strut.radial_segments = 7
	strut.rings = 1
	strut.top_radius = 0.13
	strut.bottom_radius = 0.055
	var top := Vector3(0.0, 1.25, 0.0)
	for i in 5:
		var yaw := TAU * float(i) / 5.0
		var foot := Vector3(cos(yaw) * 1.2, 0.0, sin(yaw) * 1.2)
		var span := top - foot
		strut.height = span.length()
		var turn := Basis(Quaternion(Vector3.UP, span.normalized()))
		roots.append_from(strut, 0, Transform3D(turn, (top + foot) * 0.5))
	return roots.commit()

static func _emit_list(t, arr: Array, mesh: Mesh, m: Material, shadows: bool) -> void:
	var dict := {}
	for e in arr:
		var p: Vector3 = e[0].origin
		var k = Vector2i(int(floor(p.x / CHUNK)), int(floor(p.z / CHUNK)))
		if not dict.has(k):
			dict[k] = []
		dict[k].append(e)
	_emit_chunks(t, dict, mesh, m, 400.0, shadows)

# ---------------------------------------------------------------- Felsen

static func _rocks(t, rng) -> void:
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/rock.gdshader")
	m.set_shader_parameter("fog_tex", Game.fog_tex)
	var nt = NoiseTexture2D.new()
	nt.seamless = true
	var fn = FastNoiseLite.new()
	fn.frequency = 0.03
	fn.fractal_octaves = 5
	nt.noise = fn
	var nn = NoiseTexture2D.new()
	nn.seamless = true
	nn.as_normal_map = true
	nn.bump_strength = 12.0
	var fn2 = FastNoiseLite.new()
	fn2.frequency = 0.05
	fn2.fractal_octaves = 4
	nn.noise = fn2
	m.set_shader_parameter("noise_tex", nt)
	m.set_shader_parameter("noise_n", nn)
	var meshes = [_rock_mesh(rng), _rock_mesh(rng), _rock_mesh(rng)]
	var lists = [[], [], []]
	var rbio: Dictionary = load("res://scripts/biome.gd").of(t)
	for i in int(1400 * float(rbio.get("rocks", 1.0))):
		var x = rng.randf_range(-110, 110)
		var z = rng.randf_range(-110, 110)
		var n: Vector3 = t.normal_at(x, z)
		var h: float = t.height_at(x, z)
		if h < t.WATER_Y + 0.2:
			continue
		var steep = n.y < 0.9
		if not steep and rng.randf() > 0.06:
			continue
		var s = rng.randf_range(0.6, 2.4) if steep else rng.randf_range(0.3, 0.9)
		var b = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.3, 0.3))
		b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s))
		var gv = rng.randf_range(0.3, 0.42)
		var col = Color(gv, gv * 0.97, gv * 0.9).lerp(Color(0.42, 0.36, 0.28), rng.randf() * 0.4)
		lists[rng.randi() % 3].append([Transform3D(b, Vector3(x, h - 0.15 * s, z)), col])
	for j in 3:
		_emit_list(t, lists[j], meshes[j], m, true)
