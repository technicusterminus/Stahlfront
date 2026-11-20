extends Node3D
const Maps = preload("res://scripts/maps.gd")
## Prozedurales Gelände: Höhenfeld, Mesh, Wasser, Bäume und Felsen, Begehbarkeitsraster.

var SIZE := 240
var N := 241
const WATER_Y := -0.6

var heights = PackedFloat32Array()
var blocked = PackedByteArray()   # Game.GRID * Game.GRID, 1 = unpassierbar
var road_cells = PackedByteArray()   # 1 = befestigte Strasse (kein Regen-Malus)
var sea = PackedByteArray()       # 1 = schiffbares Wasser des zusammenhängenden Meeres
var _starts: Array = []
var mat: ShaderMaterial
var water_mat: ShaderMaterial
var tree_cells: Array = []
var flat_list: Array = []
var seed_used = 0
var spec = {}
var _ctx = {}
var islands: Array = []
var _zn1: FastNoiseLite
var _zn2: FastNoiseLite
var zone_tex: ImageTexture
var _why = ""
var _layout = 0       # Gewässerform: 0 Kreuz, 1 Windungen, 2 getrennte Seen, 3 Uferkanal

func generate(sp: Dictionary, starts: Array, depots: Array) -> void:
	spec = sp
	SIZE = int(sp["size"])
	N = SIZE + 1
	var k = float(SIZE) / 240.0
	var water: float = sp["water"]
	_layout = int(sp.get("layout", 0))
	_ctx = Maps.sea_ctx(sp, starts)
	_zn1 = FastNoiseLite.new()
	_zn1.seed = int(sp["seed"]) + 61
	_zn1.frequency = 0.010
	_zn1.fractal_octaves = 3
	_zn2 = FastNoiseLite.new()
	_zn2.seed = int(sp["seed"]) + 67
	_zn2.frequency = 0.013
	_zn2.fractal_octaves = 3
	var tries = 0
	while tries < 24:
		if tries == 12 and _layout != 0:
			_layout = 0   # Rückfall auf die sichere Form
			var sp2 = sp.duplicate()
			sp2["layout"] = 0
			_ctx = Maps.sea_ctx(sp2, starts)
		if _try_generate(int(sp["seed"]) + tries * 101, starts, depots):
			seed_used = int(sp["seed"]) + tries * 101
			break
		tries += 1
	print("KARTE %s: Größe %d, Form %s, Versuche %d%s" % [sp.get("name", "?"), SIZE, Maps.LAYOUT_NAMES[_layout], tries + 1, "  FEHLGESCHLAGEN: " + _why if tries >= 24 else ""])
	_build_mesh()
	_build_water()
	_build_props()

## Vegetationszonen am Ort: r = trockene Steppe, g = Heide/Moor, b = Waldboden, a = Fels und Geröll;
## der Rest ist Wiese. Gewichte gehen weich ineinander über.
func zone_at(x: float, z: float) -> Color:
	var a = _zn1.get_noise_2d(x, z)
	var b = _zn2.get_noise_2d(x, z)
	var dry = smoothstep(0.12, 0.42, a)
	var heath = smoothstep(0.14, 0.44, -a) * (1.0 - dry)
	var forest = smoothstep(0.10, 0.38, b) * (1.0 - dry) * (1.0 - heath * 0.6)
	var rocky = smoothstep(0.28, 0.55, -b) * (1.0 - dry * 0.5)
	var s = dry + heath + forest + rocky
	if s > 1.0:
		dry /= s
		heath /= s
		forest /= s
		rocky /= s
	return Color(dry, heath, forest, rocky)

func _zone_image(res: int) -> Image:
	var img = Image.create(res, res, false, Image.FORMAT_RGBA8)
	for y in res:
		for x in res:
			img.set_pixel(x, y, zone_at((x + 0.5) / res * SIZE - Game.HALF, (y + 0.5) / res * SIZE - Game.HALF))
	return img

func bay_center(start: Vector2) -> Vector2:
	return Maps.bay_center(start)

func _wdist(p: Vector2) -> float:
	return Maps.sea_dist(p, _ctx)

func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.dot(ab), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Abstand zu den Landbrücken: Ring durch die Startecken und Speichen entlang der Achsen.
func _bridge_dist(p: Vector2) -> float:
	var e: float = absf(_starts[0].x)
	var c = [Vector2(-e, -e), Vector2(e, -e), Vector2(e, e), Vector2(-e, e)]
	var best = 1e9
	for i in 4:
		best = min(best, _seg_d(p, c[i], c[(i + 1) % 4]))
		var ax = [Vector2(e, 0), Vector2(0, e), Vector2(-e, 0), Vector2(0, -e)][i]
		best = min(best, _seg_d(p, Vector2.ZERO, ax))
	return best

func _try_generate(seed_val: int, starts: Array, depots: Array) -> bool:
	_starts = starts
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var hills: float = spec["hills"]
	var water: float = spec["water"]
	var hm = lerp(0.55, 1.5, hills)
	var ridge_thr = lerp(0.75, 0.4, hills)
	var lake_thr = lerp(0.55, 0.05, water)
	var half: float = Game.HALF
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
	flat_list = flats
	for s in starts:
		flats.append(Vector3(s.x, s.y, 34.0 + max(0.0, float(SIZE) / 240.0 - 1.0) * 58.0))
	for sf in load("res://scripts/settlement.gd").flats(spec, starts):
		flats.append(sf)
	for d in depots:
		flats.append(Vector3(d.x, d.y, 9.0))

	# Inseln im Meer: nur dort, wo ringsum tiefes Wasser ist, nicht im Zentrum
	islands.clear()
	var want = int(round(float(spec["islands"]) * 10.0))
	var itry = 0
	while islands.size() < want and itry < 120:
		itry += 1
		var ir = rng.randf_range(2.6, 6.5)
		var ip = Vector2(rng.randf_range(-half * 0.55, half * 0.55), rng.randf_range(-half * 0.55, half * 0.55))
		if ip.length() < ir + 5.0:
			continue
		if _wdist(ip) > -(ir + 4.5):
			continue
		var clash = false
		for o in islands:
			if Vector2(ip.x - o[0].x, ip.y - o[0].y).length() < ir + o[1] + 4.0:
				clash = true
		if not clash:
			islands.append([ip, ir])

	heights.resize(N * N)
	for iz in N:
		for ix in N:
			var x = float(ix) - half
			var z = float(iz) - half
			var h = (n1.get_noise_2d(x, z) * 7.5 + n2.get_noise_2d(x, z) * 1.6) * hm + 2.2
			var r = ridge.get_noise_2d(x, z)
			if r > ridge_thr:
				h += (r - ridge_thr) * 26.0 * lerp(0.7, 1.3, hills)
			var l = lake.get_noise_2d(x, z)
			if l > lake_thr:
				h -= (l - lake_thr) * 32.0
			var e: float = min(half - abs(x), half - abs(z))
			if e < 16.0:
				h += (16.0 - e) * (16.0 - e) * 0.085
			var bd = _bridge_dist(Vector2(x, z))
			if bd < 9.0:
				h = lerp(h, 1.6, smoothstep(9.0, 4.0, bd))
			heights[iz * N + ix] = h
	# flache Plätze (Basen, Vorkommen) nur im eigenen Umkreis einarbeiten
	for f in flats:
		var rr: float = f.z
		var ix0 = int(max(f.x + half - rr, 0.0))
		var ix1 = int(min(f.x + half + rr, float(SIZE)))
		var iz0 = int(max(f.y + half - rr, 0.0))
		var iz1 = int(min(f.y + half + rr, float(SIZE)))
		for iz in range(iz0, iz1 + 1):
			for ix in range(ix0, ix1 + 1):
				var d = Vector2(float(ix) - half, float(iz) - half).distance_to(Vector2(f.x, f.y))
				if d < rr:
					var tt = smoothstep(rr, rr * 0.6, d)
					heights[iz * N + ix] = lerp(heights[iz * N + ix], 3.0, tt)
	# Meer, Ufer und Inseln
	for iz in N:
		for ix in N:
			var p = Vector2(float(ix) - half, float(iz) - half)
			var wd = _wdist(p)
			if wd < 18.0:
				var h = heights[iz * N + ix]
				h = lerp(h, 1.4, smoothstep(18.0, 9.0, wd))
				if wd < 6.0:
					h = lerp(h, -2.8, smoothstep(6.0, 3.0, wd))
				heights[iz * N + ix] = h
	for o in islands:
		var ip: Vector2 = o[0]
		var ir: float = o[1]
		var jx0 = int(max(ip.x + half - ir - 4.0, 0.0))
		var jx1 = int(min(ip.x + half + ir + 4.0, float(SIZE)))
		var jz0 = int(max(ip.y + half - ir - 4.0, 0.0))
		var jz1 = int(min(ip.y + half + ir + 4.0, float(SIZE)))
		for iz in range(jz0, jz1 + 1):
			for ix in range(jx0, jx1 + 1):
				var d2 = Vector2(float(ix) - half, float(iz) - half).distance_to(ip)
				if d2 < ir + 4.0:
					var wob = n2.get_noise_2d(float(ix) * 3.0, float(iz) * 3.0) * 0.8
					var tt2 = smoothstep(ir + 3.0 + wob, ir * 0.55, d2)
					heights[iz * N + ix] = lerp(heights[iz * N + ix], 1.5 + wob * 0.5, tt2)

	# Begehbarkeit je 2-m-Zelle
	var G: int = Game.GRID
	blocked.resize(G * G)
	blocked.fill(0)
	road_cells.resize(G * G)
	road_cells.fill(0)
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

	# Meer: zusammenhängende tiefe Zellen ab der Seemitte
	sea.resize(G * G)
	sea.fill(0)
	var deep = PackedByteArray()
	deep.resize(G * G)
	for cz in G:
		for cx in G:
			var sm = 0.0
			for oz in 3:
				for ox in 3:
					sm += heights[(cz * 2 + oz) * N + cx * 2 + ox]
			deep[cz * G + cx] = 1 if sm / 9.0 < WATER_Y - 0.3 else 0
	var sstack: Array = []
	var mid_deep: bool = deep[(G / 2) * G + G / 2] == 1
	if not mid_deep and float(_ctx.get("dry", 0.0)) <= 0.0 and float(_ctx.get("cw", 0.0)) <= 0.0:
		return false
	if mid_deep:
		sstack.append(Vector2i(G / 2, G / 2))
		sea[(G / 2) * G + G / 2] = 1
	for s in starts:
		var sc0 = _cell_of(bay_center(s))
		if deep[sc0.y * G + sc0.x] == 1 and sea[sc0.y * G + sc0.x] == 0:
			sea[sc0.y * G + sc0.x] = 1
			sstack.append(sc0)
	while not sstack.is_empty():
		var sc: Vector2i = sstack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var sn: Vector2i = sc + dv
			if sn.x < 0 or sn.y < 0 or sn.x >= G or sn.y >= G:
				continue
			var si = sn.y * G + sn.x
			if sea[si] == 1 or deep[si] == 0:
				continue
			sea[si] = 1
			sstack.append(sn)
	for s in starts:
		var bc = _cell_of(bay_center(s))
		if sea[bc.y * G + bc.x] == 0:
			_why = "Bucht kein Wasser"
			return false

	# Waldstuecke
	tree_cells.clear()
	var forest = FastNoiseLite.new()
	forest.seed = seed_val + 33
	forest.frequency = 0.03
	var fthr = lerp(0.75, 0.0, float(spec["forest"]))
	for cz in G:
		for cx in G:
			if blocked[cz * G + cx] == 1:
				continue
			var wp = Vector2(cx * 2.0 - half + 1.0, cz * 2.0 - half + 1.0)
			var near_flat = false
			for f in flats:
				if wp.distance_to(Vector2(f.x, f.y)) < f.z + 4.0:
					near_flat = true
					break
			if near_flat:
				continue
			if forest.get_noise_2d(wp.x, wp.y) > fthr and rng.randf() < 0.55:
				blocked[cz * G + cx] = 1
				tree_cells.append(Vector2i(cx, cz))

	# Erreichbarkeit: alles, was vom ersten Start nicht erreichbar ist, sperren
	var start_c = _cell_of(starts[0])
	if blocked[start_c.y * G + start_c.x] == 1:
		_why = "Start blockiert"
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
			_why = "unerreichbar bei %s" % str(p)
			return false
	for i in G * G:
		if seen[i] == 0:
			blocked[i] = 1
	return true
## Schnelle Vorschau einer Karte (Gewässer, Höhen, Startpunkte, Vorkommen) für das Startmenü.
func preview_image(sp: Dictionary, res: int) -> Image:
	var size = float(sp["size"])
	var half = size * 0.5
	var lay = Maps.layout(sp)
	_starts = lay["starts"]
	spec = sp
	SIZE = int(size)
	_layout = int(sp.get("layout", 0))
	_ctx = Maps.sea_ctx(sp, _starts)
	var seed_val = int(sp["seed"])
	var hills: float = sp["hills"]
	var hm = lerp(0.55, 1.5, hills)
	var ridge_thr = lerp(0.75, 0.4, hills)
	var lake_thr = lerp(0.55, 0.05, float(sp["water"]))
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
	for s in _starts:
		flats.append(Vector3(s.x, s.y, 34.0 + max(0.0, size / 240.0 - 1.0) * 58.0))
	for d in lay["depots"]:
		flats.append(Vector3(d[0].x, d[0].y, 9.0))
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var isl: Array = []
	var want = int(round(float(sp["islands"]) * 10.0))
	var itry = 0
	while isl.size() < want and itry < 120:
		itry += 1
		var ir = rng.randf_range(2.6, 6.5)
		var ip = Vector2(rng.randf_range(-half * 0.55, half * 0.55), rng.randf_range(-half * 0.55, half * 0.55))
		if ip.length() < ir + 5.0 or _wdist(ip) > -(ir + 4.5):
			continue
		var clash = false
		for o in isl:
			if Vector2(ip.x - o[0].x, ip.y - o[0].y).length() < ir + o[1] + 4.0:
				clash = true
		if not clash:
			isl.append([ip, ir])
	var img = Image.create(res, res, false, Image.FORMAT_RGB8)
	for y in res:
		for x in res:
			var wx = (x + 0.5) / res * size - half
			var wz = (y + 0.5) / res * size - half
			var h = (n1.get_noise_2d(wx, wz) * 7.5 + n2.get_noise_2d(wx, wz) * 1.6) * hm + 2.2
			var r = ridge.get_noise_2d(wx, wz)
			if r > ridge_thr:
				h += (r - ridge_thr) * 26.0 * lerp(0.7, 1.3, hills)
			var l = lake.get_noise_2d(wx, wz)
			if l > lake_thr:
				h -= (l - lake_thr) * 32.0
			var e: float = min(half - abs(wx), half - abs(wz))
			if e < 16.0:
				h += (16.0 - e) * (16.0 - e) * 0.085
			var p = Vector2(wx, wz)
			var bd = _bridge_dist(p)
			if bd < 9.0:
				h = lerp(h, 1.6, smoothstep(9.0, 4.0, bd))
			for f in flats:
				var d = p.distance_to(Vector2(f.x, f.y))
				if d < f.z:
					h = lerp(h, 3.0, smoothstep(f.z, f.z * 0.6, d))
			var wd = _wdist(p)
			if wd < 18.0:
				h = lerp(h, 1.4, smoothstep(18.0, 9.0, wd))
				if wd < 6.0:
					h = lerp(h, -2.8, smoothstep(6.0, 3.0, wd))
			for o in isl:
				var d2 = p.distance_to(o[0])
				if d2 < o[1] + 4.0:
					h = lerp(h, 1.5, smoothstep(o[1] + 3.0, o[1] * 0.55, d2))
			var c: Color
			if h < WATER_Y:
				c = Color(0.05, 0.14, 0.22).lerp(Color(0.1, 0.25, 0.35), clamp((h + 3.0) / 3.0, 0.0, 1.0))
			else:
				c = Color(0.22, 0.32, 0.12).lerp(Color(0.55, 0.52, 0.45), clamp((h - 2.0) / 9.0, 0.0, 1.0))
			img.set_pixel(x, y, c)
	for d in lay["depots"]:
		var px = int((d[0].x + half) / size * res)
		var pz = int((d[0].y + half) / size * res)
		var col = Defs.RES_COLORS[d[1]]
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				img.set_pixel(clampi(px + ox, 0, res - 1), clampi(pz + oz, 0, res - 1), col)
	for s in _starts:
		var sx = int((s.x + half) / size * res)
		var sz = int((s.y + half) / size * res)
		for ox in range(-3, 4):
			for oz in range(-3, 4):
				img.set_pixel(clampi(sx + ox, 0, res - 1), clampi(sz + oz, 0, res - 1), Color(1, 1, 1))
	return img

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x + Game.HALF) / 2.0), int((p.y + Game.HALF) / 2.0))

func height_at(x: float, z: float) -> float:
	var fx: float = clamp(x + Game.HALF, 0.0, SIZE - 0.001)
	var fz: float = clamp(z + Game.HALF, 0.0, SIZE - 0.001)
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
			var x = float(ix) - Game.HALF
			var z = float(iz) - Game.HALF
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
	mat.set_shader_parameter("occ_tex", Game.occ_tex)
	mat.set_shader_parameter("map_size", float(SIZE))
	zone_tex = ImageTexture.create_from_image(_zone_image(128))
	mat.set_shader_parameter("zone_tex", zone_tex)
	var bio: Dictionary = load("res://scripts/biome.gd").of(self)
	if bio.has("grass_a"):
		var ca: Color = bio["grass_a"]
		var cb: Color = bio["grass_b"]
		mat.set_shader_parameter("bio_a", Vector3(ca.r, ca.g, ca.b))
		mat.set_shader_parameter("bio_b", Vector3(cb.r, cb.g, cb.b))
	mat.set_shader_parameter("snow_y", float(bio.get("snow_y", 999.0)))

	var mi = MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.name = "TerrainMesh"
	add_child(mi)

func _build_water() -> void:
	var pm = PlaneMesh.new()
	pm.size = Vector2(SIZE + 180, SIZE + 180)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
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
	var foam = NoiseTexture2D.new()
	foam.seamless = true
	var fnz = FastNoiseLite.new()
	fnz.frequency = 0.08
	fnz.fractal_octaves = 3
	foam.noise = fnz
	water_mat.set_shader_parameter("foam_noise", foam)
	water_mat.set_shader_parameter("fog_tex", Game.fog_tex)
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_props() -> void:
	load("res://scripts/vegetation.gd").build(self, seed_used)
	load("res://scripts/doodads.gd").build(self, seed_used)

## Farbiges Abbild für die Minikarte.
func minimap_image(res: int) -> Image:
	var img = Image.create(res, res, false, Image.FORMAT_RGB8)
	var tree_set = {}
	for tc in tree_cells:
		tree_set[tc] = true
	for y in res:
		for x in res:
			var wx = (x + 0.5) / res * SIZE - Game.HALF
			var wz = (y + 0.5) / res * SIZE - Game.HALF
			var h = height_at(wx, wz)
			var c: Color
			if h < WATER_Y:
				c = Color(0.06, 0.16, 0.22)
			else:
				var n = normal_at(wx, wz)
				c = Color(0.2, 0.27, 0.1).lerp(Color(0.38, 0.36, 0.32), clamp((1.0 - n.y) * 8.0, 0.0, 1.0))
				c = c.lightened(clamp(h * 0.02, -0.2, 0.25))
			var cx = int((wx + Game.HALF) / 2.0)
			var cz = int((wz + Game.HALF) / 2.0)
			if tree_set.has(Vector2i(cx, cz)):
				c = Color(0.08, 0.16, 0.06)
			img.set_pixel(x, y, c)
	return img
