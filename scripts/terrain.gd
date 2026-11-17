extends Node3D
## Prozedurales Gelände: Höhenfeld, Mesh, Wasser, Bäume und Felsen, Begehbarkeitsraster.

const SIZE := 240
const N := 241
const WATER_Y := -0.6

var heights = PackedFloat32Array()
var blocked = PackedByteArray()   # Game.GRID * Game.GRID, 1 = unpassierbar
var mat: ShaderMaterial
var water_mat: ShaderMaterial
var tree_cells: Array = []
var seed_used = 0

func generate(seed_val: int, starts: Array, depots: Array) -> void:
	var tries = 0
	while tries < 12:
		if _try_generate(seed_val + tries * 101, starts, depots):
			seed_used = seed_val + tries * 101
			break
		tries += 1
	_build_mesh()
	_build_water()
	_build_props()

func _try_generate(seed_val: int, starts: Array, depots: Array) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var n1 = FastNoiseLite.new()
	n1.seed = seed_val
	n1.frequency = 0.007
	n1.fractal_octaves = 4
	var n2 = FastNoiseLite.new()
	n2.seed = seed_val + 7
	n2.frequency = 0.022
	n2.fractal_octaves = 3
	var lake = FastNoiseLite.new()
	lake.seed = seed_val + 13
	lake.frequency = 0.011
	var ridge = FastNoiseLite.new()
	ridge.seed = seed_val + 21
	ridge.frequency = 0.013
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 2

	var flats: Array = []
	for s in starts:
		flats.append(Vector3(s.x, s.y, 34.0))
	for d in depots:
		flats.append(Vector3(d.x, d.y, 9.0))

	heights.resize(N * N)
	for iz in N:
		for ix in N:
			var x = float(ix) - 120.0
			var z = float(iz) - 120.0
			var h = n1.get_noise_2d(x, z) * 7.5 + n2.get_noise_2d(x, z) * 1.6 + 2.2
			var r = ridge.get_noise_2d(x, z)
			if r > 0.55:
				h += (r - 0.55) * 26.0
			var l = lake.get_noise_2d(x, z)
			if l > 0.3:
				h -= (l - 0.3) * 32.0
			var e: float = min(120.0 - abs(x), 120.0 - abs(z))
			if e < 16.0:
				h += (16.0 - e) * (16.0 - e) * 0.085
			for f in flats:
				var d = Vector2(x, z).distance_to(Vector2(f.x, f.y))
				if d < f.z:
					var t = smoothstep(f.z, f.z * 0.6, d)
					h = lerp(h, 3.0, t)
			heights[iz * N + ix] = h

	# Begehbarkeit je 2-m-Zelle
	var G: int = Game.GRID
	blocked.resize(G * G)
	blocked.fill(0)
	for cz in G:
		for cx in G:
			var mn = 999.0
			var mx = -999.0
			var sum = 0.0
			for oz in 3:
				for ox in 3:
					var hv = heights[(cz * 2 + oz) * N + cx * 2 + ox]
					mn = min(mn, hv)
					mx = max(mx, hv)
					sum += hv
			var avg = sum / 9.0
			if avg < WATER_Y + 0.25 or mx - mn > 1.9 or cx < 5 or cz < 5 or cx >= G - 5 or cz >= G - 5:
				blocked[cz * G + cx] = 1

	# Waldstuecke
	tree_cells.clear()
	var forest = FastNoiseLite.new()
	forest.seed = seed_val + 33
	forest.frequency = 0.03
	for cz in G:
		for cx in G:
			if blocked[cz * G + cx] == 1:
				continue
			var wp = Vector2(cx * 2.0 - 119.0, cz * 2.0 - 119.0)
			var near_flat = false
			for f in flats:
				if wp.distance_to(Vector2(f.x, f.y)) < f.z + 4.0:
					near_flat = true
					break
			if near_flat:
				continue
			if forest.get_noise_2d(wp.x, wp.y) > 0.32 and rng.randf() < 0.55:
				blocked[cz * G + cx] = 1
				tree_cells.append(Vector2i(cx, cz))

	# Erreichbarkeit: alles, was vom ersten Start nicht erreichbar ist, sperren
	var start_c = _cell_of(starts[0])
	if blocked[start_c.y * G + start_c.x] == 1:
		return false
	var seen = PackedByteArray()
	seen.resize(G * G)
	seen.fill(0)
	var stack: Array = [start_c]
	seen[start_c.y * G + start_c.x] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if n.x < 0 or n.y < 0 or n.x >= G or n.y >= G:
				continue
			var i = n.y * G + n.x
			if seen[i] == 1 or blocked[i] == 1:
				continue
			seen[i] = 1
			stack.append(n)
	for p in starts + depots:
		var c = _cell_of(p)
		if seen[c.y * G + c.x] == 0:
			return false
	for i in G * G:
		if seen[i] == 0:
			blocked[i] = 1
	return true

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + 120.0) / 2.0), int((p.y + 120.0) / 2.0))

func height_at(x: float, z: float) -> float:
	var fx: float = clamp(x + 120.0, 0.0, 239.999)
	var fz: float = clamp(z + 120.0, 0.0, 239.999)
	var ix = int(fx)
	var iz = int(fz)
	var tx = fx - ix
	var tz = fz - iz
	var h00 = heights[iz * N + ix]
	var h10 = heights[iz * N + ix + 1]
	var h01 = heights[(iz + 1) * N + ix]
	var h11 = heights[(iz + 1) * N + ix + 1]
	return lerp(lerp(h00, h10, tx), lerp(h01, h11, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var hl = height_at(x - 1.0, z)
	var hr = height_at(x + 1.0, z)
	var hd = height_at(x, z - 1.0)
	var hu = height_at(x, z + 1.0)
	return Vector3(hl - hr, 2.0, hd - hu).normalized()

func ground_y(x: float, z: float) -> float:
	return max(height_at(x, z), WATER_Y)

## Strahl gegen Gelände (Marschieren + Bisektion).
func raycast(origin: Vector3, dir: Vector3) -> Variant:
	var t = 0.0
	var prev = origin
	var step = 1.5
	for i in 600:
		t += step
		var p = origin + dir * t
		if p.y <= ground_y(p.x, p.z):
			var a = prev
			var b = p
			for k in 10:
				var m = (a + b) * 0.5
				if m.y <= ground_y(m.x, m.z):
					b = m
				else:
					a = m
			return b
		prev = p
		if p.y < -30.0:
			break
	return null

func _build_mesh() -> void:
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs = PackedVector2Array()
	verts.resize(N * N)
	norms.resize(N * N)
	uvs.resize(N * N)
	for iz in N:
		for ix in N:
			var i = iz * N + ix
			var x = float(ix) - 120.0
			var z = float(iz) - 120.0
			verts[i] = Vector3(x, heights[i], z)
			var hl = heights[iz * N + max(ix - 1, 0)]
			var hr = heights[iz * N + min(ix + 1, N - 1)]
			var hd = heights[max(iz - 1, 0) * N + ix]
			var hu = heights[min(iz + 1, N - 1) * N + ix]
			norms[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			uvs[i] = Vector2(ix, iz) / float(N - 1)
	var idx = PackedInt32Array()
	idx.resize((N - 1) * (N - 1) * 6)
	var k = 0
	for iz in N - 1:
		for ix in N - 1:
			var a = iz * N + ix
			var b = a + 1
			var c = a + N
			var d = c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var nt = NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var nn = FastNoiseLite.new()
	nn.frequency = 0.012
	nn.fractal_octaves = 5
	nt.noise = nn
	var ntn = NoiseTexture2D.new()
	ntn.width = 512
	ntn.height = 512
	ntn.seamless = true
	ntn.as_normal_map = true
	ntn.bump_strength = 6.0
	var nn2 = FastNoiseLite.new()
	nn2.frequency = 0.05
	nn2.fractal_octaves = 3
	ntn.noise = nn2
	mat.set_shader_parameter("noise_tex", nt)
	mat.set_shader_parameter("noise_n", ntn)
	mat.set_shader_parameter("fog_tex", Game.fog_tex)
	mat.set_shader_parameter("map_size", 240.0)

	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.name = "TerrainMesh"
	add_child(mi)

func _build_water() -> void:
	var pm = PlaneMesh.new()
	pm.size = Vector2(420, 420)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var ntn = NoiseTexture2D.new()
	ntn.seamless = true
	ntn.as_normal_map = true
	ntn.bump_strength = 3.0
	var nn = FastNoiseLite.new()
	nn.frequency = 0.03
	ntn.noise = nn
	water_mat.set_shader_parameter("n1", ntn)
	water_mat.set_shader_parameter("fog_tex", Game.fog_tex)
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_props() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_used + 5
	# Bäume: Stamm + zwei Kronen-Kegel
	var trunk = CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 2.0
	trunk.radial_segments = 6
	var crown = CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.6
	crown.height = 3.6
	crown.radial_segments = 8
	var crown2 = CylinderMesh.new()
	crown2.top_radius = 0.0
	crown2.bottom_radius = 1.2
	crown2.height = 2.8
	crown2.radial_segments = 8
	var per_cell = 2
	var count = tree_cells.size() * per_cell
	var mm_t = _mm(trunk, count, Game.fog_material(Color(0.28, 0.2, 0.13), 0.95))
	var mm_c = _mm(crown, count, Game.fog_material(Color(1, 1, 1), 0.85))
	var mm_c2 = _mm(crown2, count, Game.fog_material(Color(1, 1, 1), 0.85))
	var i = 0
	for c in tree_cells:
		for k in per_cell:
			var x: float = c.x * 2.0 - 120.0 + rng.randf_range(0.2, 1.8)
			var z: float = c.y * 2.0 - 120.0 + rng.randf_range(0.2, 1.8)
			var y = height_at(x, z)
			var s = rng.randf_range(0.75, 1.35)
			var b = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm_t.multimesh.set_instance_transform(i, Transform3D(b, Vector3(x, y + 1.0 * s, z)))
			mm_t.multimesh.set_instance_color(i, Color(1, 1, 1))
			mm_c.multimesh.set_instance_transform(i, Transform3D(b, Vector3(x, y + 3.2 * s, z)))
			mm_c2.multimesh.set_instance_transform(i, Transform3D(b, Vector3(x, y + 4.9 * s, z)))
			var g = Color(0.09, 0.2 + rng.randf() * 0.1, 0.06).lerp(Color(0.2, 0.22, 0.07), rng.randf() * 0.5)
			mm_c.multimesh.set_instance_color(i, g)
			mm_c2.multimesh.set_instance_color(i, g.lightened(0.08))
			i += 1
	# Felsen an Hängen
	var rock = SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.4
	rock.radial_segments = 7
	rock.rings = 4
	var rocks: Array = []
	for t in 900:
		var x = rng.randf_range(-110, 110)
		var z = rng.randf_range(-110, 110)
		var n = normal_at(x, z)
		if n.y < 0.9 and height_at(x, z) > WATER_Y + 0.3:
			rocks.append(Vector2(x, z))
	var mm_r = _mm(rock, rocks.size(), Game.fog_material(Color(1, 1, 1), 0.9))
	for j in rocks.size():
		var p: Vector2 = rocks[j]
		var s = rng.randf_range(0.6, 2.2)
		var b = Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * 0.7, s))
		mm_r.multimesh.set_instance_transform(j, Transform3D(b, Vector3(p.x, height_at(p.x, p.y), p.y)))
		var gv = rng.randf_range(0.17, 0.27)
		mm_r.multimesh.set_instance_color(j, Color(gv, gv * 0.97, gv * 0.92))

func _mm(mesh: Mesh, count: int, m: Material) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)
	return mmi

## Farbiges Abbild für die Minikarte.
func minimap_image(res: int) -> Image:
	var img = Image.create(res, res, false, Image.FORMAT_RGB8)
	var tree_set = {}
	for tc in tree_cells:
		tree_set[tc] = true
	for y in res:
		for x in res:
			var wx = (x + 0.5) / res * 240.0 - 120.0
			var wz = (y + 0.5) / res * 240.0 - 120.0
			var h = height_at(wx, wz)
			var c: Color
			if h < WATER_Y:
				c = Color(0.06, 0.16, 0.22)
			else:
				var n = normal_at(wx, wz)
				c = Color(0.2, 0.27, 0.1).lerp(Color(0.38, 0.36, 0.32), clamp((1.0 - n.y) * 8.0, 0.0, 1.0))
				c = c.lightened(clamp(h * 0.02, -0.2, 0.25))
			var cx = int((wx + 120.0) / 2.0)
			var cz = int((wz + 120.0) / 2.0)
			if tree_set.has(Vector2i(cx, cz)):
				c = Color(0.08, 0.16, 0.06)
			img.set_pixel(x, y, c)
	return img
