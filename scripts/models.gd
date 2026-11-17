extends RefCounted
## Prozedurale Modelle aus Grundkoerpern. Vorwaerts = +Z.

static var _meshes = {}
static var _mats = {}

# ---------------------------------------------------------------- Materialien

static func mat(col: Color, metal := 0.3, rough := 0.55, emit := 0.0) -> StandardMaterial3D:
	var key = "%s|%s|%s|%s" % [col.to_html(), metal, rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

# ---------------------------------------------------------------- Fraktionsstil
# Waehrend ein Modell gebaut wird, liefern paint/dark/steel/olive/wall/concrete
# Hard-Surface-Materialien im Stil der Fraktion (Tarnmuster, Fugen, Rost, Schmutz).

static var _fac = ""
static var _team = Color.WHITE
static var _bld = false
static var _tex = {}

const STYLE = {
	"west":   {"panel": 1.7, "pw": 0.018, "rivet": 0.0, "rust": 0.03, "dirt": 0.18, "metal": 0.55, "rough": 0.3, "grain": 0.1, "nd": 0.35, "ds": 2.4, "camo_scale": 0.075},
	"red":    {"panel": 0.85, "pw": 0.028, "rivet": 1.0, "rust": 0.24, "dirt": 0.5, "metal": 0.35, "rough": 0.56, "grain": 0.2, "nd": 0.8, "ds": 1.6, "camo_scale": 0.13},
	"shadow": {"panel": 1.15, "pw": 0.034, "rivet": 0.6, "rust": 0.5, "dirt": 0.65, "metal": 0.2, "rough": 0.72, "grain": 0.3, "nd": 1.3, "ds": 1.2, "camo_scale": 0.12},
}

static func set_style(faction: String, team: Color, building := false) -> void:
	_fac = faction
	_team = team
	_bld = building

static func clear_style() -> void:
	_fac = ""

static func _gradient(stops: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cols = PackedColorArray()
	for s in stops:
		offs.append(s[0])
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g

## Tarnmuster je Fraktion, mit einem Farbton der Spielerfarbe.
static func camo_tex(faction: String, team: Color) -> Texture2D:
	var key = "camo_%s_%s" % [faction, team.to_html()]
	if _tex.has(key):
		return _tex[key]
	var nt = NoiseTexture2D.new()
	nt.seamless = true
	var fn = FastNoiseLite.new()
	fn.seed = hash(faction)
	match faction:
		"west":   # digitales Pixelmuster
			nt.width = 64
			nt.height = 64
			fn.frequency = 0.09
			fn.fractal_octaves = 2
			nt.color_ramp = _gradient([[0.0, Color(0.27, 0.3, 0.35)], [0.42, Color(0.47, 0.5, 0.54)], [0.62, Color(0.6, 0.62, 0.64)], [0.8, team.lerp(Color(0.45, 0.48, 0.52), 0.35)]])
		"red":    # grobes Waldmuster
			nt.width = 512
			nt.height = 512
			fn.frequency = 0.011
			fn.fractal_octaves = 3
			nt.color_ramp = _gradient([[0.0, Color(0.06, 0.08, 0.05)], [0.33, Color(0.19, 0.23, 0.12)], [0.6, Color(0.3, 0.27, 0.16)], [0.8, (team * 0.6).lerp(Color(0.2, 0.15, 0.1), 0.3)]])
		_:        # zusammengeflickte Wuestenplatten
			nt.width = 512
			nt.height = 512
			fn.noise_type = FastNoiseLite.TYPE_CELLULAR
			fn.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			fn.frequency = 0.022
			nt.color_ramp = _gradient([[0.0, Color(0.5, 0.41, 0.27)], [0.3, Color(0.63, 0.54, 0.37)], [0.55, Color(0.36, 0.24, 0.14)], [0.75, team.lerp(Color(0.55, 0.45, 0.3), 0.4)]])
	nt.noise = fn
	_tex[key] = nt
	return nt

static func _shared(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var nt = NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var fn = FastNoiseLite.new()
	fn.fractal_octaves = 5
	if name == "grime":
		fn.frequency = 0.02
	else:
		fn.frequency = 0.06
		nt.as_normal_map = true
		nt.bump_strength = 10.0
	nt.noise = fn
	_tex[name] = nt
	return nt

## Hard-Surface-Material. kind: camo, roof, dark, steel, olive, wall, concrete.
static func hard(kind: String, col := Color.WHITE) -> Material:
	var key = "hs_%s_%s_%s_%s" % [_fac, kind, _team.to_html(), col.to_html()]
	if _mats.has(key):
		return _mats[key]
	var st: Dictionary = STYLE[_fac]
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/hardsurface.gdshader")
	m.set_shader_parameter("grime", _shared("grime"))
	m.set_shader_parameter("detail_n", _shared("detail"))
	m.set_shader_parameter("panel_scale", st["panel"])
	m.set_shader_parameter("panel_width", st["pw"])
	m.set_shader_parameter("rivet", st["rivet"])
	m.set_shader_parameter("rust", st["rust"])
	m.set_shader_parameter("dirt", st["dirt"])
	m.set_shader_parameter("grain", st["grain"])
	m.set_shader_parameter("metallic_v", st["metal"])
	m.set_shader_parameter("rough_v", st["rough"])
	m.set_shader_parameter("normal_depth", st["nd"])
	m.set_shader_parameter("detail_scale", st["ds"])
	m.set_shader_parameter("camo_scale", st["camo_scale"])
	m.set_shader_parameter("use_camo", kind == "camo" or kind == "uniform")
	if kind == "uniform":
		m.set_shader_parameter("camo_scale", st["camo_scale"] * 6.0)
		m.set_shader_parameter("panel_scale", 0.01)
		m.set_shader_parameter("rivet", 0.0)
		m.set_shader_parameter("metallic_v", 0.0)
		m.set_shader_parameter("rough_v", 0.9)
		m.set_shader_parameter("rust", 0.0)
	m.set_shader_parameter("camo", camo_tex(_fac, _team))
	var base := col
	match kind:
		"roof":
			base = _team.lerp(Color(0.4, 0.4, 0.38), 0.3)
		"dark":
			base = Color(0.07, 0.07, 0.075)
		"steel":
			base = Color(0.42, 0.43, 0.45)
			m.set_shader_parameter("metallic_v", 0.85)
			m.set_shader_parameter("rough_v", st["rough"] * 0.6)
		"olive":
			base = {"west": Color(0.3, 0.32, 0.34), "red": Color(0.2, 0.23, 0.13), "shadow": Color(0.42, 0.34, 0.22)}[_fac]
		"wall", "concrete":
			base = col
			m.set_shader_parameter("metallic_v", 0.05 if kind == "concrete" or _fac != "west" else 0.3)
			m.set_shader_parameter("rough_v", 0.85 if kind == "concrete" or _fac == "shadow" else 0.55)
			m.set_shader_parameter("panel_scale", st["panel"] * 0.45)
			m.set_shader_parameter("rivet", 0.0)
			m.set_shader_parameter("dirt", st["dirt"] * 0.8)
	m.set_shader_parameter("base_col", base)
	_mats[key] = m
	return m

static func paint(col: Color) -> Material:
	if _fac != "":
		return hard("roof" if _bld else "camo")
	return mat(col, 0.55, 0.38)

static func dark() -> Material:
	if _fac != "":
		return hard("dark")
	return mat(Color(0.09, 0.09, 0.1), 0.5, 0.7)

static func steel() -> Material:
	if _fac != "":
		return hard("steel")
	return mat(Color(0.45, 0.46, 0.48), 0.85, 0.32)

static func olive() -> Material:
	if _fac != "":
		return hard("olive")
	return mat(Color(0.24, 0.27, 0.17), 0.2, 0.75)

static func concrete() -> Material:
	if _fac != "":
		return hard("concrete", Color(0.46, 0.46, 0.45))
	return mat(Color(0.46, 0.46, 0.45), 0.0, 0.92)

static func glass() -> StandardMaterial3D:
	return mat(Color(0.05, 0.08, 0.1), 0.9, 0.08)

static func glow(col: Color, e := 3.0) -> StandardMaterial3D:
	return mat(col, 0.0, 0.4, e)

static func wall(faction: String) -> Material:
	var c: Color
	match faction:
		"west":
			c = Color(0.62, 0.64, 0.67)
		"red":
			c = Color(0.5, 0.43, 0.38)
		_:
			c = Color(0.6, 0.5, 0.36)
	if _fac != "":
		return hard("wall", c)
	return mat(c, 0.1, 0.8)

# ---------------------------------------------------------------- Grundkoerper

static func _mi(p: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

static func box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key = "b%s" % size
	if not _meshes.has(key):
		var bm = BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _mi(p, _meshes[key], pos, m, rot)

static func cyl(p: Node3D, rt: float, rb: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var key = "c%s_%s_%s_%s" % [rt, rb, h, seg]
	if not _meshes.has(key):
		var cm = CylinderMesh.new()
		cm.top_radius = rt
		cm.bottom_radius = rb
		cm.height = h
		cm.radial_segments = seg
		cm.rings = 1
		_meshes[key] = cm
	return _mi(p, _meshes[key], pos, m, rot)

static func sph(p: Node3D, r: float, pos: Vector3, m: Material, scl := Vector3.ONE, hemi := false) -> MeshInstance3D:
	var key = "s%s_%s" % [r, hemi]
	if not _meshes.has(key):
		var sm = SphereMesh.new()
		sm.radius = r
		sm.height = r * (1.0 if hemi else 2.0)
		sm.is_hemisphere = hemi
		sm.radial_segments = 18
		sm.rings = 9
		_meshes[key] = sm
	var mi = _mi(p, _meshes[key], pos, m, Vector3.ZERO)
	mi.scale = scl
	return mi

static func node(p: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	p.add_child(n)
	return n

static func wheels(p: Node3D, xs: float, zs: Array, r := 0.42, y := 0.42) -> void:
	for z in zs:
		for sx in [-1.0, 1.0]:
			cyl(p, r, r, 0.35, Vector3(sx * xs, y, z), dark(), Vector3(0, 0, PI / 2), 10)

# ---------------------------------------------------------------- Einheiten

# ---------------------------------------------------------------- Eigene Modelle (.glb)
# Suchreihenfolge: models/units/<fraktion>_<modell>.glb, dann models/units/<modell>.glb
# (Gebaeude: models/buildings/<fraktion>_<rolle>.glb bzw. <rolle>.glb).
# Konventionen im Modell: Vorwaerts = +Z (in Blender: -Y), 1 Einheit = 1 m, Ursprung am Boden.
# Optionale Objektnamen: Turret (dreht sich), Muzzle (Muendung), Rotor, TailRotor, Spin.
# Materialien, deren Name "Team" enthaelt, werden in der Spielerfarbe eingefaerbt.

static func load_custom(dir: String, names: Array, col: Color) -> Dictionary:
	for n in names:
		var p = "res://models/%s/%s.glb" % [dir, n]
		if not ResourceLoader.exists(p):
			continue
		var scene = load(p)
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate()
		var root = Node3D.new()
		root.add_child(inst)
		_teamcolor(inst, col)
		var out = {"root": root, "turret": null, "muzzle": Vector3(0, 1.2, 1.0), "rotor": null,
			"tail_rotor": null, "spin": null, "height": 2.0, "smoke": [], "custom": true}
		var t = inst.find_child("Turret", true, false)
		if t != null:
			out["turret"] = t
		var m = inst.find_child("Muzzle", true, false)
		if m != null:
			var ref: Node3D = t if t != null else root
			out["muzzle"] = (_rel(ref, root).affine_inverse() * _rel(m, root)).origin
		for key in [["Rotor", "rotor"], ["TailRotor", "tail_rotor"], ["Spin", "spin"]]:
			var nd = inst.find_child(key[0], true, false)
			if nd != null:
				out[key[1]] = nd
		var top = 0.0
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var aabb: AABB = _rel(mi, root) * (mi as MeshInstance3D).get_aabb()
			top = max(top, aabb.end.y)
		out["height"] = max(top, 0.5)
		return out
	return {}

## Transformation eines Knotens relativ zu einem Vorfahren (funktioniert ausserhalb des Baums).
static func _rel(n: Node3D, ancestor: Node3D) -> Transform3D:
	var tf = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			tf = (cur as Node3D).transform * tf
		cur = cur.get_parent()
	return tf

static func _teamcolor(n: Node, col: Color) -> void:
	if n is MeshInstance3D:
		var mi = n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D and "team" in String(m.resource_name).to_lower():
				if _fac != "":
					# Fraktionslack (Tarnmuster, Fugen, Rost) statt Einheitsfarbe
					mi.set_surface_override_material(i, hard("camo"))
				else:
					var dm: BaseMaterial3D = m.duplicate()
					dm.albedo_color = col.lerp(Color(0.45, 0.45, 0.42), 0.25)
					mi.set_surface_override_material(i, dm)
	for c in n.get_children():
		_teamcolor(c, col)

static func build_unit(model: String, col: Color, faction: String) -> Dictionary:
	set_style(faction, col, false)
	var out = _build_unit(model, col, faction)
	clear_style()
	return out

static func _build_unit(model: String, col: Color, faction: String) -> Dictionary:
	var custom = load_custom("units", [faction + "_" + model, model], col)
	if not custom.is_empty():
		return custom
	var root = Node3D.new()
	var out = {"root": root, "turret": null, "muzzle": Vector3(0, 1.2, 1.0), "rotor": null, "height": 2.0}
	var pc = paint(col)
	match model:
		"inf", "inf_at", "worker":
			_inf(root, col, faction, model, out)
		"tank", "laser_tank", "flame_tank", "scorpion":
			_tank(root, pc, model, out)
		"heavy_tank":
			_heavy(root, pc, out)
		"aa":
			_aa(root, pc, faction, out)
		"truck":
			_truck(root, pc, out)
		"dozer":
			_dozer(root, pc, out)
		"rocketlauncher":
			_rocketlauncher(root, pc, out)
		"artillery":
			_artillery(root, pc, out)
		"heli":
			_heli(root, pc, faction, out)
		"technical", "technical_aa":
			_technical(root, pc, model == "technical_aa", out)
		"buggy":
			_buggy(root, pc, out)
		"toxin_truck":
			_toxin(root, pc, out)
		"scud":
			_scud(root, pc, out)
		"drone", "builddrone":
			_drone(root, pc, model == "builddrone", out)
		"bombtruck":
			_bombtruck(root, pc, out)
		_:
			box(root, Vector3(2, 1, 3), Vector3(0, 0.5, 0), pc)
	return out

static func _inf(r: Node3D, col: Color, faction: String, model: String, out: Dictionary) -> void:
	var s = node(r)
	s.scale = Vector3(1.3, 1.3, 1.3)
	# Uniform im Tarnmuster der Fraktion (feiner skaliert), Teamfarbe als Armbinde/Schulterband
	var uni: Material = hard("uniform") if _fac != "" else mat(Color(0.4, 0.4, 0.32), 0.0, 0.85)
	if model == "worker":
		uni = mat(Color(0.85, 0.45, 0.1), 0.0, 0.8)
	box(s, Vector3(0.16, 0.75, 0.2), Vector3(-0.11, 0.38, 0), uni)
	box(s, Vector3(0.16, 0.75, 0.2), Vector3(0.11, 0.38, 0), uni)
	box(s, Vector3(0.18, 0.14, 0.24), Vector3(-0.11, 0.07, 0.02), dark())
	box(s, Vector3(0.18, 0.14, 0.24), Vector3(0.11, 0.07, 0.02), dark())
	box(s, Vector3(0.48, 0.6, 0.3), Vector3(0, 1.05, 0), uni)
	box(s, Vector3(0.5, 0.12, 0.32), Vector3(0, 1.3, 0), mat(col, 0.1, 0.6))
	box(s, Vector3(0.36, 0.34, 0.14), Vector3(0, 1.05, -0.2), olive())
	sph(s, 0.15, Vector3(0, 1.52, 0), mat(Color(0.75, 0.58, 0.45), 0.0, 0.8))
	if faction == "shadow" and model != "worker":
		sph(s, 0.17, Vector3(0, 1.56, -0.01), mat(Color(0.2, 0.18, 0.16), 0.0, 0.9), Vector3(1, 0.75, 1))
	else:
		sph(s, 0.17, Vector3(0, 1.6, 0), paint(col.darkened(0.2)), Vector3(1, 0.62, 1.05))
	if model == "inf_at":
		cyl(s, 0.08, 0.08, 1.1, Vector3(0.2, 1.42, 0.1), olive(), Vector3(PI / 2, 0, 0), 8)
		out["muzzle"] = Vector3(0.26, 1.85, 0.9)
	elif model == "worker":
		box(s, Vector3(0.3, 0.25, 0.2), Vector3(0.28, 0.75, 0.1), steel())
	else:
		box(s, Vector3(0.06, 0.09, 0.75), Vector3(0.17, 1.1, 0.32), dark())
		out["muzzle"] = Vector3(0.22, 1.43, 0.95)
	out["height"] = 2.2

static func _tank(r: Node3D, pc: Material, model: String, out: Dictionary) -> void:
	var small = model == "scorpion"
	var k = 0.82 if small else 1.0
	for sx in [-1.0, 1.0]:
		box(r, Vector3(0.7 * k, 0.8, 4.3 * k), Vector3(sx * 1.15 * k, 0.45, 0), dark())
		box(r, Vector3(0.74 * k, 0.12, 4.0 * k), Vector3(sx * 1.15 * k, 0.88, 0), pc)
	box(r, Vector3(2.0 * k, 0.65, 3.8 * k), Vector3(0, 0.95, -0.1), pc)
	box(r, Vector3(2.0 * k, 0.4, 0.9 * k), Vector3(0, 0.9, 1.95 * k), pc, Vector3(-0.45, 0, 0))
	box(r, Vector3(1.6 * k, 0.3, 0.6), Vector3(0, 1.2, -1.85 * k), dark())
	var t = node(r, Vector3(0, 1.28, -0.1))
	box(t, Vector3(1.55 * k, 0.55, 1.9 * k), Vector3(0, 0.27, 0), pc)
	box(t, Vector3(1.2 * k, 0.35, 0.5), Vector3(0, 0.25, 1.1 * k), pc, Vector3(-0.5, 0, 0))
	cyl(t, 0.22, 0.25, 0.25, Vector3(0.35, 0.65, -0.3), pc)
	match model:
		"laser_tank":
			cyl(t, 0.16, 0.2, 2.2, Vector3(0, 0.3, 1.9), steel(), Vector3(PI / 2, 0, 0))
			cyl(t, 0.22, 0.22, 0.5, Vector3(0, 0.3, 0.9), glow(Color(0.2, 0.9, 1.0), 4.0), Vector3(PI / 2, 0, 0))
			sph(t, 0.18, Vector3(0, 0.3, 3.0), glow(Color(0.4, 1.0, 1.0), 6.0))
			out["muzzle"] = Vector3(0, 0.3, 3.1)
		"flame_tank":
			cyl(t, 0.14, 0.2, 1.2, Vector3(0, 0.3, 1.4), steel(), Vector3(PI / 2, 0, 0))
			for sx in [-0.5, 0.5]:
				cyl(r, 0.32, 0.32, 1.4, Vector3(sx, 1.45, -1.4), mat(Color(0.5, 0.18, 0.1), 0.4, 0.5), Vector3(PI / 2, 0, 0))
			out["muzzle"] = Vector3(0, 0.3, 2.1)
		_:
			cyl(t, 0.09, 0.11, 2.6 * k, Vector3(0, 0.3, 1.9 * k), steel(), Vector3(PI / 2, 0, 0), 10)
			cyl(t, 0.14, 0.14, 0.35, Vector3(0, 0.3, 3.1 * k), dark(), Vector3(PI / 2, 0, 0), 10)
			out["muzzle"] = Vector3(0, 0.3, 3.3 * k)
	if small:
		box(t, Vector3(0.4, 0.35, 0.9), Vector3(0.9, 0.35, -0.2), olive())
	out["turret"] = t
	out["height"] = 2.2

static func _heavy(r: Node3D, pc: Material, out: Dictionary) -> void:
	for sx in [-1.0, 1.0]:
		box(r, Vector3(0.9, 1.0, 4.8), Vector3(sx * 1.5, 0.55, 0), dark())
		box(r, Vector3(1.0, 0.16, 4.6), Vector3(sx * 1.5, 1.08, 0), pc)
	box(r, Vector3(2.6, 0.85, 4.4), Vector3(0, 1.15, -0.1), pc)
	box(r, Vector3(2.6, 0.5, 1.0), Vector3(0, 1.05, 2.3), pc, Vector3(-0.45, 0, 0))
	box(r, Vector3(0.8, 0.8, 0.8), Vector3(1.4, 1.9, -1.8), dark())
	var t = node(r, Vector3(0, 1.58, -0.3))
	box(t, Vector3(2.1, 0.75, 2.4), Vector3(0, 0.37, 0), pc)
	box(t, Vector3(1.8, 0.4, 0.7), Vector3(0, 0.3, 1.4), pc, Vector3(-0.5, 0, 0))
	for sx in [-0.35, 0.35]:
		cyl(t, 0.11, 0.13, 3.0, Vector3(sx, 0.4, 2.3), steel(), Vector3(PI / 2, 0, 0), 10)
	box(t, Vector3(0.6, 0.4, 0.6), Vector3(-0.6, 0.95, -0.4), dark())
	out["turret"] = t
	out["muzzle"] = Vector3(0, 0.4, 3.8)
	out["height"] = 2.8

static func _aa(r: Node3D, pc: Material, faction: String, out: Dictionary) -> void:
	if faction == "red":
		for sx in [-1.0, 1.0]:
			box(r, Vector3(0.7, 0.8, 4.0), Vector3(sx * 1.1, 0.45, 0), dark())
	else:
		wheels(r, 1.05, [-1.3, 0.0, 1.3])
	box(r, Vector3(2.0, 0.8, 3.7), Vector3(0, 1.0, 0), pc)
	box(r, Vector3(1.8, 0.5, 0.8), Vector3(0, 1.1, 1.9), pc, Vector3(-0.4, 0, 0))
	var t = node(r, Vector3(0, 1.45, -0.3))
	cyl(t, 0.7, 0.8, 0.4, Vector3(0, 0.2, 0), pc)
	box(t, Vector3(1.2, 0.6, 1.0), Vector3(0, 0.6, 0), pc)
	for sx in [-0.45, 0.45]:
		for sy in [0.45, 0.75]:
			cyl(t, 0.06, 0.06, 1.8, Vector3(sx, sy, 1.1), steel(), Vector3(PI / 2 - 0.35, 0, 0), 8)
	box(t, Vector3(0.5, 0.35, 0.4), Vector3(0, 1.05, -0.2), dark())
	out["turret"] = t
	out["muzzle"] = Vector3(0, 0.9, 1.9)

static func _truck(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.0, [-1.4, -0.4, 1.5])
	box(r, Vector3(1.9, 0.4, 4.4), Vector3(0, 0.75, 0), dark())
	box(r, Vector3(2.0, 1.3, 1.3), Vector3(0, 1.55, 1.5), pc)
	box(r, Vector3(1.8, 0.5, 0.05), Vector3(0, 1.85, 2.16), glass())
	box(r, Vector3(2.0, 0.9, 2.6), Vector3(0, 1.4, -0.75), olive())
	for i in 3:
		box(r, Vector3(0.7, 0.6, 0.7), Vector3(-0.45 + (i % 2) * 0.9, 2.15, -0.3 - i * 0.7), mat(Color(0.5, 0.38, 0.2), 0.0, 0.9))
	out["height"] = 2.6

static func _dozer(r: Node3D, pc: Material, out: Dictionary) -> void:
	for sx in [-1.0, 1.0]:
		box(r, Vector3(0.6, 0.7, 3.4), Vector3(sx * 1.0, 0.4, 0), dark())
	box(r, Vector3(1.6, 0.8, 3.0), Vector3(0, 1.0, -0.2), mat(Color(0.95, 0.72, 0.1), 0.4, 0.5))
	box(r, Vector3(1.3, 1.1, 1.2), Vector3(0, 1.9, -0.6), pc)
	box(r, Vector3(1.2, 0.5, 0.05), Vector3(0, 2.1, 0.02), glass())
	box(r, Vector3(2.8, 0.9, 0.25), Vector3(0, 0.6, 2.0), steel(), Vector3(-0.2, 0, 0))
	for sx in [-0.8, 0.8]:
		box(r, Vector3(0.15, 0.15, 1.2), Vector3(sx, 0.8, 1.3), steel())
	sph(r, 0.12, Vector3(0.5, 2.55, -0.6), glow(Color(1, 0.6, 0.1), 5.0))
	out["height"] = 2.6

static func _rocketlauncher(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.05, [-1.5, -0.4, 1.4])
	box(r, Vector3(2.0, 0.5, 4.6), Vector3(0, 0.85, 0), dark())
	box(r, Vector3(2.0, 1.2, 1.2), Vector3(0, 1.6, 1.7), pc)
	box(r, Vector3(1.8, 0.45, 0.05), Vector3(0, 1.85, 2.31), glass())
	var t = node(r, Vector3(0, 1.4, -0.9))
	var pod = node(t, Vector3(0, 0.4, 0))
	pod.rotation.x = -0.45
	box(pod, Vector3(1.7, 0.9, 2.4), Vector3(0, 0, 0), pc)
	for ix in 4:
		for iy in 2:
			cyl(pod, 0.15, 0.15, 0.1, Vector3(-0.6 + ix * 0.4, -0.2 + iy * 0.4, 1.21), dark(), Vector3(PI / 2, 0, 0), 8)
	out["turret"] = t
	out["muzzle"] = Vector3(0, 1.2, 1.2)
	out["height"] = 2.8

static func _artillery(r: Node3D, pc: Material, out: Dictionary) -> void:
	for sx in [-1.0, 1.0]:
		box(r, Vector3(0.7, 0.8, 4.4), Vector3(sx * 1.15, 0.45, 0), dark())
	box(r, Vector3(2.0, 0.8, 4.2), Vector3(0, 1.0, 0), pc)
	var t = node(r, Vector3(0, 1.4, -0.5))
	box(t, Vector3(1.9, 1.0, 2.4), Vector3(0, 0.5, 0), pc)
	var b = node(t, Vector3(0, 0.6, 1.0))
	b.rotation.x = -0.4
	cyl(b, 0.14, 0.18, 4.4, Vector3(0, 0, 2.2), steel(), Vector3(PI / 2, 0, 0), 10)
	cyl(b, 0.22, 0.22, 0.5, Vector3(0, 0, 4.3), dark(), Vector3(PI / 2, 0, 0), 10)
	out["turret"] = t
	out["muzzle"] = Vector3(0, 2.4, 5.0)
	out["height"] = 2.8

static func _heli(r: Node3D, pc: Material, faction: String, out: Dictionary) -> void:
	var b = node(r)
	sph(b, 1.0, Vector3(0, 0, 0.2), pc, Vector3(0.85, 0.8, 2.1))
	sph(b, 0.6, Vector3(0, 0.2, 1.6), glass(), Vector3(0.9, 0.8, 1.2))
	cyl(b, 0.12, 0.28, 3.6, Vector3(0, 0.25, -2.8), pc, Vector3(PI / 2, 0, 0), 10)
	box(b, Vector3(0.1, 1.1, 0.7), Vector3(0, 0.75, -4.5), pc)
	box(b, Vector3(1.4, 0.08, 0.5), Vector3(0, 0.3, -4.3), pc)
	box(b, Vector3(3.0, 0.12, 0.7), Vector3(0, -0.1, 0.0), pc)
	for sx in [-1.35, 1.35]:
		cyl(b, 0.18, 0.18, 1.1, Vector3(sx, -0.3, 0.1), olive(), Vector3(PI / 2, 0, 0), 8)
	for sx in [-0.7, 0.7]:
		box(b, Vector3(0.08, 0.08, 2.4), Vector3(sx, -1.0, 0.1), dark())
	cyl(b, 0.12, 0.12, 0.6, Vector3(0, 0.95, 0), dark())
	var rot = node(b, Vector3(0, 1.25, 0))
	box(rot, Vector3(0.3, 0.05, 8.0), Vector3.ZERO, dark())
	box(rot, Vector3(8.0, 0.05, 0.3), Vector3.ZERO, dark())
	var tr = node(b, Vector3(0.15, 0.75, -4.5))
	box(tr, Vector3(0.03, 1.4, 0.15), Vector3.ZERO, dark())
	out["rotor"] = rot
	out["tail_rotor"] = tr
	out["muzzle"] = Vector3(1.35, -0.3, 0.8)
	if faction == "red":
		cyl(b, 0.08, 0.08, 0.9, Vector3(0, -0.6, 1.8), steel(), Vector3(PI / 2, 0, 0), 8)
		out["muzzle"] = Vector3(0, -0.6, 2.4)
	out["height"] = 2.0

static func _technical(r: Node3D, pc: Material, aa: bool, out: Dictionary) -> void:
	wheels(r, 0.95, [-1.2, 1.3], 0.4, 0.4)
	box(r, Vector3(1.8, 0.5, 4.0), Vector3(0, 0.8, 0), pc)
	box(r, Vector3(1.7, 0.75, 1.3), Vector3(0, 1.4, 0.6), pc)
	box(r, Vector3(1.6, 0.5, 0.05), Vector3(0, 1.5, 1.26), glass())
	box(r, Vector3(1.8, 0.35, 0.1), Vector3(0, 1.2, -1.95), pc)
	var t = node(r, Vector3(0, 1.2, -1.0))
	cyl(t, 0.08, 0.1, 0.8, Vector3(0, 0.4, 0), dark(), Vector3.ZERO, 8)
	if aa:
		for sx in [-0.2, 0.2]:
			cyl(t, 0.06, 0.06, 1.6, Vector3(sx, 0.95, 0.6), steel(), Vector3(PI / 2 - 0.5, 0, 0), 8)
		out["muzzle"] = Vector3(0, 1.4, 1.3)
	else:
		box(t, Vector3(0.25, 0.25, 0.6), Vector3(0, 0.85, 0.1), dark())
		cyl(t, 0.05, 0.05, 1.0, Vector3(0, 0.85, 0.8), steel(), Vector3(PI / 2, 0, 0), 8)
		box(t, Vector3(0.7, 0.4, 0.06), Vector3(0, 0.95, 0.35), steel())
		out["muzzle"] = Vector3(0, 0.85, 1.3)
	out["turret"] = t

static func _buggy(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.0, [-1.2, 1.2], 0.55, 0.55)
	box(r, Vector3(1.4, 0.35, 3.2), Vector3(0, 0.75, 0), pc)
	for sx in [-0.6, 0.6]:
		box(r, Vector3(0.08, 0.9, 0.08), Vector3(sx, 1.35, 0.3), dark())
		box(r, Vector3(0.08, 0.08, 1.6), Vector3(sx, 1.8, -0.3), dark())
	box(r, Vector3(1.3, 0.08, 0.08), Vector3(0, 1.8, 0.4), dark())
	var t = node(r, Vector3(0, 1.0, -1.0))
	var pod = node(t, Vector3(0, 0.4, 0))
	pod.rotation.x = -0.3
	box(pod, Vector3(1.1, 0.5, 1.1), Vector3.ZERO, olive())
	for ix in 3:
		cyl(pod, 0.12, 0.12, 0.08, Vector3(-0.35 + ix * 0.35, 0, 0.56), dark(), Vector3(PI / 2, 0, 0), 8)
	out["turret"] = t
	out["muzzle"] = Vector3(0, 0.6, 0.8)

static func _toxin(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.0, [-1.4, -0.4, 1.5])
	box(r, Vector3(1.9, 0.4, 4.4), Vector3(0, 0.75, 0), dark())
	box(r, Vector3(1.9, 1.2, 1.2), Vector3(0, 1.5, 1.55), pc)
	box(r, Vector3(1.7, 0.45, 0.05), Vector3(0, 1.75, 2.16), glass())
	cyl(r, 0.8, 0.8, 2.6, Vector3(0, 1.75, -0.75), mat(Color(0.3, 0.75, 0.15), 0.4, 0.4), Vector3(PI / 2, 0, 0))
	cyl(r, 0.82, 0.82, 0.2, Vector3(0, 1.75, -0.2), glow(Color(0.5, 1.0, 0.2), 2.5), Vector3(PI / 2, 0, 0))
	var t = node(r, Vector3(0, 2.2, 0.6))
	cyl(t, 0.08, 0.12, 1.0, Vector3(0, 0.2, 0.5), steel(), Vector3(PI / 2, 0, 0), 8)
	out["turret"] = t
	out["muzzle"] = Vector3(0, 0.2, 1.1)

static func _scud(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.1, [-2.0, -0.9, 0.9, 2.0])
	box(r, Vector3(2.1, 0.5, 6.0), Vector3(0, 0.9, 0), dark())
	box(r, Vector3(2.1, 1.3, 1.4), Vector3(0, 1.75, 2.4), pc)
	box(r, Vector3(1.9, 0.45, 0.05), Vector3(0, 2.0, 3.11), glass())
	var t = node(r, Vector3(0, 1.3, -0.4))
	var rail = node(t, Vector3(0, 0.3, -1.6))
	rail.rotation.x = -0.25
	box(rail, Vector3(0.6, 0.2, 4.2), Vector3(0, 0, 1.6), steel())
	cyl(rail, 0.38, 0.38, 3.8, Vector3(0, 0.45, 1.6), mat(Color(0.7, 0.72, 0.68), 0.5, 0.4), Vector3(PI / 2, 0, 0))
	cyl(rail, 0.0, 0.38, 0.9, Vector3(0, 0.45, 3.95), glow(Color(0.4, 1.0, 0.2), 2.0), Vector3(PI / 2, 0, 0))
	out["turret"] = t
	out["muzzle"] = Vector3(0, 1.6, 2.6)
	out["height"] = 2.8

## Quadrocopter; als Baudrohne größer mit Greifarm und Warnleuchten.
static func _drone(r: Node3D, pc: Material, builder: bool, out: Dictionary) -> void:
	var b = node(r)
	var k = 1.5 if builder else 1.0
	b.scale = Vector3(k, k, k)
	box(b, Vector3(1.0, 0.35, 1.4), Vector3.ZERO, pc)
	box(b, Vector3(0.8, 0.12, 1.2), Vector3(0, 0.22, 0), dark())
	sph(b, 0.18, Vector3(0, -0.12, 0.65), glass())
	var rot = node(b)
	for i in 4:
		var a = PI / 4 + i * PI / 2
		var arm = Vector3(cos(a), 0, sin(a)) * 1.0
		box(b, Vector3(0.12, 0.08, 1.0), arm * 0.5, dark(), Vector3(0, -a + PI / 2, 0))
		cyl(b, 0.12, 0.12, 0.2, arm + Vector3(0, 0.08, 0), steel(), Vector3.ZERO, 8)
		var prop = cyl(rot, 0.48, 0.48, 0.02, arm + Vector3(0, 0.2, 0), mat(Color(0.2, 0.2, 0.22), 0.2, 0.5), Vector3.ZERO, 16)
		prop.transparency = 0.6
	sph(b, 0.07, Vector3(0.5, 0, -0.7), glow(Color(1, 0.15, 0.1), 6.0))
	sph(b, 0.07, Vector3(-0.5, 0, -0.7), glow(Color(0.2, 1.0, 0.3), 6.0))
	if builder:
		box(b, Vector3(0.1, 0.9, 0.1), Vector3(0, -0.6, 0.3), steel())
		box(b, Vector3(0.5, 0.08, 0.35), Vector3(0, -1.05, 0.3), mat(Color(0.95, 0.72, 0.1), 0.4, 0.5))
		sph(b, 0.1, Vector3(0, 0.32, -0.3), glow(Color(1, 0.6, 0.1), 6.0))
	else:
		cyl(b, 0.14, 0.14, 0.25, Vector3(0, -0.28, 0.5), dark(), Vector3.ZERO, 10)
		sph(b, 0.09, Vector3(0, -0.42, 0.5), glow(Color(0.4, 0.9, 1.0), 4.0))
	out["height"] = 1.0

static func _bombtruck(r: Node3D, pc: Material, out: Dictionary) -> void:
	wheels(r, 1.0, [-1.4, -0.4, 1.5])
	box(r, Vector3(1.9, 0.4, 4.4), Vector3(0, 0.75, 0), dark())
	box(r, Vector3(1.9, 1.2, 1.2), Vector3(0, 1.5, 1.55), pc)
	box(r, Vector3(1.7, 0.45, 0.05), Vector3(0, 1.75, 2.16), glass())
	var barrel_m = mat(Color(0.55, 0.12, 0.08), 0.5, 0.55)
	for ix in 2:
		for iz in 3:
			cyl(r, 0.38, 0.38, 1.0, Vector3(-0.45 + ix * 0.9, 1.45, -1.6 + iz * 0.8), barrel_m, Vector3.ZERO, 12)
			cyl(r, 0.39, 0.39, 0.06, Vector3(-0.45 + ix * 0.9, 1.6, -1.6 + iz * 0.8), mat(Color(0.95, 0.8, 0.1), 0.3, 0.5), Vector3.ZERO, 12)
	box(r, Vector3(1.6, 0.05, 2.4), Vector3(0, 1.98, -0.8), mat(Color(0.3, 0.27, 0.18), 0.0, 0.95))
	sph(r, 0.12, Vector3(0, 2.2, 1.6), glow(Color(1, 0.1, 0.05), 8.0))
	out["height"] = 2.4

# ---------------------------------------------------------------- Flugzeug für Fähigkeiten

static func build_plane(col: Color) -> Node3D:
	var r = Node3D.new()
	var pc = paint(col)
	sph(r, 1.0, Vector3.ZERO, pc, Vector3(0.8, 0.7, 4.0))
	box(r, Vector3(9.0, 0.15, 1.8), Vector3(0, 0, -0.5), pc)
	box(r, Vector3(3.2, 0.12, 0.9), Vector3(0, 0.1, -3.4), pc)
	box(r, Vector3(0.12, 1.4, 1.0), Vector3(0, 0.8, -3.4), pc)
	sph(r, 0.5, Vector3(0, 0.35, 1.8), glass(), Vector3(0.8, 0.7, 1.6))
	for sx in [-0.5, 0.5]:
		sph(r, 0.25, Vector3(sx, -0.1, -3.9), glow(Color(1.0, 0.6, 0.2), 6.0))
	return r

# ---------------------------------------------------------------- Gebäude

static func build_building(d: Dictionary, col: Color) -> Dictionary:
	set_style(d["faction"], col, true)
	var out = _build_building(d, col)
	clear_style()
	return out

static func _build_building(d: Dictionary, col: Color) -> Dictionary:
	var custom = load_custom("buildings", [String(d["faction"]) + "_" + String(d["role"]), d["role"]], col)
	if not custom.is_empty():
		return custom
	var root = Node3D.new()
	var faction: String = d["faction"]
	var role: String = d["role"]
	var s: int = d["size"]
	var w = s * 2.0 - 0.6
	var out = {"root": root, "turret": null, "muzzle": Vector3(0, 3, 0), "spin": null, "height": 4.0, "smoke": []}
	var wl = wall(faction)
	var pc = paint(col)
	# Fundament (reicht in den Boden, deckt Hanglagen ab)
	box(root, Vector3(w + 0.4, 3.0, w + 0.4), Vector3(0, -1.3, 0), concrete())
	match role:
		"hq":
			_hq(root, w, wl, pc, faction, out)
		"power":
			_power(root, w, wl, pc, faction, out)
		"supply":
			_supply(root, w, wl, pc, faction, out)
		"barracks":
			_barracks(root, w, wl, pc, faction, out)
		"factory":
			_factory(root, w, wl, pc, faction, out)
		"airfield":
			_airfield(root, w, wl, pc, out)
		"defense":
			_defense(root, w, wl, pc, faction, out)
		"tech":
			_tech(root, w, wl, pc, faction, out)
		"super":
			_super(root, w, wl, pc, faction, out)
	return out

static func _windows(p: Node3D, w: float, y: float, z: float, n: int, col := Color(1.0, 0.85, 0.55)) -> void:
	for i in n:
		var x = -w * 0.4 + (w * 0.8) * (i + 0.5) / n
		box(p, Vector3(w * 0.8 / n * 0.6, 0.35, 0.05), Vector3(x, y, z), glow(col, 2.2))

static func _flag(p: Node3D, pos: Vector3, pc: Material) -> void:
	cyl(p, 0.05, 0.05, 4.0, pos + Vector3(0, 2.0, 0), steel(), Vector3.ZERO, 6)
	box(p, Vector3(0.05, 0.8, 1.3), pos + Vector3(0, 3.5, 0.68), pc)

static func _tarp(p: Node3D, w: float, l: float, y: float, pc: Material) -> void:
	box(p, Vector3(w * 0.55, 0.08, l), Vector3(-w * 0.24, y, 0), pc, Vector3(0, 0, 0.45))
	box(p, Vector3(w * 0.55, 0.08, l), Vector3(w * 0.24, y, 0), pc, Vector3(0, 0, -0.45))

static func _hq(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	if faction == "shadow":
		box(r, Vector3(w * 0.8, 2.6, w * 0.6), Vector3(0, 1.3, -0.5), wl)
		_tarp(r, w * 0.9, w * 0.65, 3.0, pc)
		for i in 6:
			box(r, Vector3(0.9, 0.5, 0.5), Vector3(-w * 0.4 + i * 1.5, 0.25, w * 0.42), mat(Color(0.5, 0.45, 0.3), 0.0, 1.0))
		cyl(r, 0.08, 0.08, 6.0, Vector3(w * 0.35, 3.0, -w * 0.3), steel(), Vector3.ZERO, 6)
		out["height"] = 4.0
		return
	box(r, Vector3(w * 0.9, 3.2, w * 0.75), Vector3(0, 1.6, -0.3), wl)
	box(r, Vector3(w * 0.92, 0.3, w * 0.77), Vector3(0, 3.25, -0.3), pc)
	_windows(r, w * 0.9, 2.2, w * 0.75 * 0.5 - 0.3 + 0.03, 6)
	box(r, Vector3(3.0, 3.2, 3.0), Vector3(-w * 0.2, 4.8, -0.8), wl)
	_windows(r, 3.0, 5.4, -0.8 + 1.53, 2, Color(0.5, 0.9, 1.0))
	var sp = node(r, Vector3(w * 0.25, 3.4, -1.0))
	cyl(sp, 0.12, 0.12, 1.2, Vector3(0, 0.6, 0), steel(), Vector3.ZERO, 6)
	var dish = cyl(sp, 1.3, 0.3, 0.3, Vector3(0, 1.4, 0.2), steel(), Vector3(0.9, 0, 0))
	dish.scale = Vector3(1, 1, 1)
	out["spin"] = sp
	cyl(r, 0.05, 0.05, 4.0, Vector3(-w * 0.2 + 0.8, 8.3, -0.3), steel(), Vector3.ZERO, 6)
	sph(r, 0.12, Vector3(-w * 0.2 + 0.8, 10.3, -0.3), glow(Color(1, 0.15, 0.1), 8.0))
	box(r, Vector3(2.6, 2.0, 0.4), Vector3(0, 1.0, w * 0.37), dark())
	out["height"] = 6.4

static func _power(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	if faction == "west":
		box(r, Vector3(w, 1.0, w), Vector3(0, 0.5, 0), wl)
		sph(r, 2.0, Vector3(0, 1.0, 0), glass(), Vector3(1, 1, 1), true)
		cyl(r, 1.0, 1.0, 0.6, Vector3(0, 1.3, 0), glow(Color(0.3, 0.8, 1.0), 5.0))
		var sp = node(r, Vector3(0, 2.5, 0))
		var ring = cyl(sp, 2.4, 2.4, 0.15, Vector3.ZERO, glow(Color(0.3, 0.8, 1.0), 2.0), Vector3(0.3, 0, 0), 24)
		ring.scale = Vector3(1, 1, 1)
		out["spin"] = sp
		for sx in [-1, 1]:
			box(r, Vector3(0.4, 2.2, 0.4), Vector3(sx * (w * 0.5 - 0.3), 1.6, w * 0.5 - 0.3), pc)
		out["height"] = 3.6
	else:
		box(r, Vector3(w * 0.5, 2.0, w * 0.9), Vector3(-w * 0.22, 1.0, 0), wl)
		box(r, Vector3(w * 0.52, 0.2, w * 0.92), Vector3(-w * 0.22, 2.05, 0), pc)
		cyl(r, 1.0, 1.4, 4.6, Vector3(w * 0.22, 2.3, -w * 0.18), concrete(), Vector3.ZERO, 16)
		cyl(r, 0.25, 0.3, 5.5, Vector3(-w * 0.3, 2.75, w * 0.3), mat(Color(0.35, 0.25, 0.2), 0.0, 0.9), Vector3.ZERO, 8)
		box(r, Vector3(0.6, 0.2, 0.6), Vector3(-w * 0.3, 5.0, w * 0.3), pc)
		out["smoke"] = [Vector3(w * 0.22, 4.8, -w * 0.18), Vector3(-w * 0.3, 5.6, w * 0.3)]
		out["height"] = 5.0

static func _supply(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	box(r, Vector3(w * 0.75, 2.4, w * 0.6), Vector3(-w * 0.1, 1.2, -w * 0.15), wl)
	if faction == "shadow":
		_tarp(r, w * 0.8, w * 0.65, 2.7, pc)
	else:
		var roof = cyl(r, w * 0.3, w * 0.3, w * 0.6, Vector3(-w * 0.1, 2.4, -w * 0.15), pc, Vector3(PI / 2, 0, 0), 16)
		roof.scale = Vector3(1.25, 1, 0.45)
	box(r, Vector3(w * 0.3, 1.8, 0.1), Vector3(-w * 0.1, 0.9, w * 0.15 + 0.01), dark())
	for i in 5:
		box(r, Vector3(0.8, 0.8, 0.8), Vector3(w * 0.35, 0.4 + (i / 3) * 0.8, -w * 0.3 + (i % 3) * 0.95), mat(Color(0.48, 0.36, 0.2), 0.0, 0.9))
	box(r, Vector3(w * 0.9, 0.15, 1.2), Vector3(0, 0.1, w * 0.4), mat(Color(0.95, 0.75, 0.1), 0.0, 0.7))
	out["height"] = 3.5

static func _barracks(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	box(r, Vector3(w * 0.9, 2.2, w * 0.55), Vector3(0, 1.1, -w * 0.1), wl)
	if faction == "shadow":
		_tarp(r, w * 0.95, w * 0.6, 2.5, pc)
	else:
		box(r, Vector3(w * 0.52, 0.12, w * 0.6), Vector3(-w * 0.22, 2.55, -w * 0.1), pc, Vector3(0, 0, 0.35))
		box(r, Vector3(w * 0.52, 0.12, w * 0.6), Vector3(w * 0.22, 2.55, -w * 0.1), pc, Vector3(0, 0, -0.35))
	box(r, Vector3(1.2, 1.7, 0.1), Vector3(0, 0.85, w * 0.18 + 0.01), dark())
	_windows(r, w * 0.9, 1.5, w * 0.18 + 0.02, 4)
	_flag(r, Vector3(w * 0.42, 0, w * 0.4), pc)
	for i in 4:
		box(r, Vector3(0.9, 0.45, 0.45), Vector3(-w * 0.4 + i * 1.0, 0.22, w * 0.42), mat(Color(0.5, 0.46, 0.32), 0.0, 1.0))
	out["height"] = 3.2

static func _factory(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	box(r, Vector3(w * 0.9, 4.0, w * 0.7), Vector3(0, 2.0, -w * 0.12), wl)
	if faction == "shadow":
		_tarp(r, w * 0.95, w * 0.75, 4.4, pc)
		for i in 3:
			box(r, Vector3(1.4, 0.7, 1.0), Vector3(w * 0.38, 0.35 + i * 0.5, w * 0.35), mat(Color(0.3, 0.22, 0.15), 0.6, 0.8), Vector3(0, i * 0.6, 0.1 * i))
	else:
		for i in 4:
			box(r, Vector3(w * 0.9 / 4.0 - 0.1, 0.9, w * 0.7), Vector3(-w * 0.45 + w * 0.9 / 8.0 + i * w * 0.9 / 4.0, 4.3, -w * 0.12), pc, Vector3(0, 0, 0.35))
	box(r, Vector3(w * 0.5, 3.0, 0.1), Vector3(0, 1.5, w * 0.23 + 0.01), dark())
	box(r, Vector3(w * 0.52, 0.2, 0.15), Vector3(0, 3.1, w * 0.23 + 0.05), mat(Color(0.95, 0.75, 0.1), 0.0, 0.7))
	cyl(r, 0.45, 0.55, 6.0, Vector3(-w * 0.38, 3.0, -w * 0.38), mat(Color(0.3, 0.3, 0.3), 0.5, 0.6), Vector3.ZERO, 10)
	out["smoke"] = [Vector3(-w * 0.38, 6.1, -w * 0.38)]
	for sx in [-1, 1]:
		box(r, Vector3(0.3, 4.6, 0.3), Vector3(sx * w * 0.42, 2.3, w * 0.4), steel())
	box(r, Vector3(w * 0.9, 0.35, 0.35), Vector3(0, 4.6, w * 0.4), steel())
	out["height"] = 5.0

static func _airfield(r: Node3D, w: float, wl: Material, pc: Material, out: Dictionary) -> void:
	box(r, Vector3(w, 0.3, w), Vector3(0, 0.15, 0), mat(Color(0.16, 0.16, 0.17), 0.0, 0.85))
	var white = mat(Color(0.9, 0.9, 0.9), 0.0, 0.7)
	box(r, Vector3(0.5, 0.05, 3.4), Vector3(-1.0, 0.32, 0.4), white)
	box(r, Vector3(0.5, 0.05, 3.4), Vector3(1.0, 0.32, 0.4), white)
	box(r, Vector3(1.6, 0.05, 0.5), Vector3(0, 0.32, 0.4), white)
	for i in 8:
		var a = TAU * i / 8.0
		sph(r, 0.12, Vector3(cos(a) * 3.0, 0.35, 0.4 + sin(a) * 3.0), glow(Color(1, 0.7, 0.2), 6.0))
	box(r, Vector3(1.8, 3.5, 1.8), Vector3(w * 0.38, 1.75, -w * 0.38), wl)
	box(r, Vector3(2.4, 1.0, 2.4), Vector3(w * 0.38, 4.0, -w * 0.38), glass())
	box(r, Vector3(2.5, 0.2, 2.5), Vector3(w * 0.38, 4.6, -w * 0.38), pc)
	out["height"] = 4.8

static func _defense(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	if faction == "red":
		box(r, Vector3(w * 0.85, 1.6, w * 0.85), Vector3(0, 0.8, 0), concrete())
		box(r, Vector3(w * 0.7, 0.6, w * 0.7), Vector3(0, 1.9, 0), wl)
		var t = node(r, Vector3(0, 2.2, 0))
		cyl(t, 0.7, 0.8, 0.6, Vector3(0, 0.3, 0), pc)
		for i in 6:
			var a = TAU * i / 6.0
			cyl(t, 0.05, 0.05, 1.8, Vector3(cos(a) * 0.15, 0.6 + sin(a) * 0.15, 1.2), steel(), Vector3(PI / 2, 0, 0), 6)
		out["turret"] = t
		out["muzzle"] = Vector3(0, 0.6, 2.1)
		out["height"] = 3.2
		return
	if faction == "shadow":
		for i in 8:
			var a = TAU * i / 8.0
			box(r, Vector3(1.0, 0.5, 0.5), Vector3(cos(a) * 2.0, 0.25, sin(a) * 2.0), mat(Color(0.5, 0.46, 0.32), 0.0, 1.0), Vector3(0, -a, 0))
	else:
		box(r, Vector3(w * 0.8, 0.8, w * 0.8), Vector3(0, 0.4, 0), wl)
	var t2 = node(r, Vector3(0, 0.9, 0))
	cyl(t2, 0.5, 0.6, 0.8, Vector3(0, 0.4, 0), pc)
	var pod = node(t2, Vector3(0, 1.2, 0))
	pod.rotation.x = -0.35
	for sx in [-0.6, 0.6]:
		box(pod, Vector3(0.7, 0.7, 2.0), Vector3(sx, 0, 0.3), pc if faction == "west" else olive())
		for k in 4:
			cyl(pod, 0.1, 0.1, 0.05, Vector3(sx - 0.15 + (k % 2) * 0.3, -0.15 + (k / 2) * 0.3, 1.31), dark(), Vector3(PI / 2, 0, 0), 6)
	out["turret"] = t2
	out["muzzle"] = Vector3(0, 1.5, 1.4)
	out["height"] = 3.0

static func _tech(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	if faction == "shadow":
		box(r, Vector3(w * 0.85, 2.0, w * 0.7), Vector3(0, 1.0, -0.4), wl)
		_tarp(r, w * 0.9, w * 0.75, 2.4, pc)
		for i in 3:
			box(r, Vector3(0.7, 0.9, 0.5), Vector3(-1.5 + i * 1.5, 0.45, w * 0.38), mat(Color(0.3, 0.25, 0.2), 0.3, 0.8))
		sph(r, 0.1, Vector3(1.4, 1.0, w * 0.38), glow(Color(0.4, 1.0, 0.3), 6.0))
		out["height"] = 3.0
		return
	box(r, Vector3(w, 1.2, w), Vector3(0, 0.6, 0), wl)
	sph(r, 1.9, Vector3(0, 1.2, 0), pc, Vector3(1, 0.8, 1), true)
	box(r, Vector3(w * 1.0, 0.25, 0.3), Vector3(0, 1.0, w * 0.5), glow(Color(0.4, 0.9, 1.0), 2.5))
	for sx in [-1, 1]:
		cyl(r, 0.04, 0.04, 3.0, Vector3(sx * w * 0.38, 2.7, -w * 0.38), steel(), Vector3.ZERO, 6)
		sph(r, 0.1, Vector3(sx * w * 0.38, 4.2, -w * 0.38), glow(Color(1, 0.2, 0.15), 8.0))
	var sp = node(r, Vector3(0, 2.7, 0))
	cyl(sp, 0.9, 0.2, 0.2, Vector3(0, 0.3, 0.2), steel(), Vector3(0.8, 0, 0))
	out["spin"] = sp
	out["height"] = 3.8

static func _super(r: Node3D, w: float, wl: Material, pc: Material, faction: String, out: Dictionary) -> void:
	match faction:
		"west":
			box(r, Vector3(w, 1.4, w), Vector3(0, 0.7, 0), wl)
			for i in 4:
				var a = TAU * i / 4.0 + PI / 4
				box(r, Vector3(0.6, 4.5, 0.6), Vector3(cos(a) * w * 0.38, 2.6, sin(a) * w * 0.38), pc, Vector3(0, -a, 0.25 * (1 if i % 2 == 0 else -1)))
			var sp = node(r, Vector3(0, 4.0, 0))
			sph(sp, 1.0, Vector3.ZERO, glow(Color(0.3, 0.8, 1.0), 6.0))
			cyl(sp, 2.2, 2.2, 0.12, Vector3.ZERO, glow(Color(0.3, 0.8, 1.0), 2.0), Vector3(PI / 2, 0, 0), 28)
			cyl(sp, 1.8, 1.8, 0.12, Vector3.ZERO, glow(Color(0.3, 0.8, 1.0), 2.0), Vector3(0, 0, PI / 2), 28)
			out["spin"] = sp
			out["height"] = 6.0
		"red":
			box(r, Vector3(w, 1.0, w), Vector3(0, 0.5, 0), concrete())
			cyl(r, 2.6, 2.8, 1.2, Vector3(0, 1.4, 0), wl, Vector3.ZERO, 20)
			for sx in [-1, 1]:
				box(r, Vector3(2.5, 0.25, 5.0), Vector3(sx * 1.4, 2.1, 0), pc, Vector3(0, 0, sx * 0.25))
			for i in 4:
				var a = TAU * i / 4.0
				box(r, Vector3(0.8, 0.12, 0.8), Vector3(cos(a) * (w * 0.42), 1.06, sin(a) * (w * 0.42)), mat(Color(0.95, 0.8, 0.1), 0.0, 0.6))
			sph(r, 0.25, Vector3(0, 2.5, w * 0.35), glow(Color(1.0, 0.2, 0.1), 6.0))
			out["height"] = 3.0
		_:
			box(r, Vector3(w, 0.8, w), Vector3(0, 0.4, 0), wl)
			var rail = node(r, Vector3(0, 0.8, 0))
			rail.rotation.x = -1.2
			box(rail, Vector3(1.0, 0.3, 6.0), Vector3(0, 0, 2.5), steel())
			for i in 3:
				var rr = node(rail, Vector3(-1.2 + i * 1.2, 0.6, 2.5))
				cyl(rr, 0.35, 0.35, 4.0, Vector3.ZERO, mat(Color(0.65, 0.68, 0.6), 0.5, 0.4), Vector3(PI / 2, 0, 0))
				cyl(rr, 0.0, 0.35, 0.8, Vector3(0, 0, 2.4), glow(Color(0.4, 1.0, 0.2), 3.0), Vector3(PI / 2, 0, 0))
			_tarp(r, w * 0.6, w * 0.3, 1.8, pc)
			out["height"] = 6.0
