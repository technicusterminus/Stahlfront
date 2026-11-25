extends RefCounted
## Partikel- und Lichteffekte. Alles wird in Game.fx_root eingehaengt.

static var _c = {}

static func _soft_tex() -> Texture2D:
	if _c.has("tex"):
		return _c["tex"]
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.7))
	g.add_point(0.6, Color(1, 1, 1, 0.22))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_c["tex"] = t
	return t

## Unregelmäßige Wolke (Rauch, Feuerball): Rauschen mit weichem Rand, damit sich überlappende Partikel zu einer Masse verbinden.
static func _puff_tex() -> Texture2D:
	if _c.has("puff"):
		return _c["puff"]
	var n = FastNoiseLite.new()
	n.seed = 7
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.045
	n.fractal_octaves = 4
	var res = 96
	var img = Image.create(res, res, false, Image.FORMAT_RGBA8)
	for y in res:
		for x in res:
			var dx = (x + 0.5) / res * 2.0 - 1.0
			var dy = (y + 0.5) / res * 2.0 - 1.0
			var r = sqrt(dx * dx + dy * dy)
			var nz = n.get_noise_2d(x, y) * 0.5 + 0.5
			var a = clamp((1.0 - r) * 1.5 + (nz - 0.5) * 1.1, 0.0, 1.0)
			a = smoothstep(0.0, 1.0, a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t = ImageTexture.create_from_image(img)
	_c["puff"] = t
	return t

## Rauch, Staub, Dampf: fotorealistische Rauchballen aus models/fx/smoke_atlas.png (2×2, zufällige Variante je Teilchen),
## weiche Kante, wo sie Boden oder Gebäude schneiden. Fehlt der Bogen, bleibt die alte gezeichnete Wolke.
static func _atlas(name: String) -> Texture2D:
	var key := "atlas_" + name
	if OS.get_cmdline_user_args().has("--noatlas"):
		return null
	if not _c.has(key):
		var path := "res://models/fx/%s_atlas.png" % name
		_c[key] = load(path) if ResourceLoader.exists(path) else null
	return _c[key]

static func _puffquad(additive := false, lit := false) -> QuadMesh:
	var key = "puffquad2_%s_%s" % [additive, lit]
	if _c.has(key):
		return _c[key]
	var m = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	var at := _atlas("smoke")
	if at != null:
		m.albedo_texture = at
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
	else:
		m.albedo_texture = _puff_tex()
	m.proximity_fade_enabled = not OS.get_cmdline_user_args().has("--noprox")
	m.proximity_fade_distance = 1.2
	m.disable_receive_shadows = true
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	_c[key] = q
	return q

## Brandfleck: dunkler Kern (Krater), ausgefranster Rand und Rußstrahlen, die von der Mitte weglaufen.
## Feuerball: fotorealistische Flammen aus models/fx/fire_atlas.png; die Teilchenfarbe tönt nur und blendet aus.
static func _firequad() -> QuadMesh:
	if _c.has("firequad"):
		return _c["firequad"]
	var m = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	var at := _atlas("fire")
	if at != null:
		m.albedo_texture = at
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
	else:
		m.albedo_texture = _puff_tex()
	m.proximity_fade_enabled = not OS.get_cmdline_user_args().has("--noprox")
	m.proximity_fade_distance = 0.8
	m.disable_receive_shadows = true
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	_c["firequad"] = q
	return q

static func _scorch_tex() -> Texture2D:
	if _c.has("scorch"):
		return _c["scorch"]
	var res := 192
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 41
	n.frequency = 0.035
	n.fractal_octaves = 4
	var spokes := FastNoiseLite.new()
	spokes.seed = 77
	spokes.frequency = 2.2
	for y in res:
		for x in res:
			var dx := (x + 0.5) / res * 2.0 - 1.0
			var dy := (y + 0.5) / res * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var rim := n.get_noise_2d(x, y) * 0.22
			var ray := maxf(spokes.get_noise_1d(ang * 3.0), 0.0) * 0.55   # Strahlen
			var a := clampf(1.0 - smoothstep(0.25 + rim, 0.62 + rim + ray, r), 0.0, 1.0)
			var core := 1.0 - smoothstep(0.0, 0.28, r)
			var c := Color(0.05, 0.04, 0.03).lerp(Color(0.015, 0.012, 0.01), core)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a * (0.75 + 0.2 * core)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_c["scorch"] = t
	return t

## Flammenform: gewölbter Körper mit Spitze, gezackten Rändern und Farbe in der Textur
## (gelb-weißer Kern, oranger Rand). Alpha = Form.
static func _flame_tex() -> Texture2D:
	if _c.has("flametex"):
		return _c["flametex"]
	var W = 128
	var H = 192
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var n1 = FastNoiseLite.new()
	n1.seed = 11
	n1.frequency = 0.02
	var n2 = FastNoiseLite.new()
	n2.seed = 29
	n2.frequency = 0.09
	n2.fractal_octaves = 3
	for y in H:
		var v = 1.0 - float(y) / (H - 1)             # 0 unten, 1 oben
		var sway = n1.get_noise_2d(v * 140.0, 5.0) * 0.32 * v
		var hw = 0.78 * pow(max(0.0, sin(PI * pow(v, 0.55))), 0.85)   # Breite: Bauch unten, Spitze oben
		for x in W:
			var u = (float(x) / (W - 1) - 0.5) * 2.0
			var du = u - sway
			var rim = n2.get_noise_2d(float(x) * 1.2, float(y) * 0.9) * (0.22 + 0.18 * v)
			var d = abs(du) - hw + rim
			var a = clamp(-d / 0.1, 0.0, 1.0)
			a *= clamp(1.0 - pow(v, 2.5) * 0.35, 0.0, 1.0)
			var core = clamp(1.0 - abs(du) / max(hw, 0.08), 0.0, 1.0) * (1.0 - v * 0.6)
			core = pow(core, 1.3)
			var col = Color(0.95, 0.36, 0.05).lerp(Color(1.0, 0.8, 0.32), core)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	_c["flametex"] = t
	return t
static func _flame_quad() -> QuadMesh:
	if _c.has("flamequad"):
		return _c["flamequad"]
	var m = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = _flame_tex()
	m.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	m.disable_receive_shadows = true
	var q = QuadMesh.new()
	q.size = Vector2(1, 1.6)
	q.center_offset = Vector3(0, 0.55, 0)    # Fuß der Flamme am Emitterpunkt
	q.material = m
	_c["flamequad"] = q
	return q

static func _quad(additive: bool, lit := false) -> QuadMesh:
	var key = "quad_%s_%s" % [additive, lit]
	if _c.has(key):
		return _c[key]
	var m = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = _soft_tex()
	m.disable_receive_shadows = true
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = m
	_c[key] = q
	return q

static func _ramp(cols: Array) -> GradientTexture1D:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var pc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / max(cols.size() - 1, 1))
		pc.append(cols[i])
	g.offsets = offs
	g.colors = pc
	var t = GradientTexture1D.new()
	t.gradient = g
	return t

static func _curve(pts: Array) -> CurveTexture:
	var c = Curve.new()
	for p in pts:
		c.add_point(p)
	var t = CurveTexture.new()
	t.curve = c
	return t

static func _pm(key: String, cfg: Dictionary) -> ParticleProcessMaterial:
	if _c.has(key):
		return _c[key]
	var m = ParticleProcessMaterial.new()
	m.set_meta("key", key)
	m.direction = cfg.get("dir", Vector3.UP)
	m.spread = cfg.get("spread", 180.0)
	m.initial_velocity_min = cfg.get("vmin", 1.0)
	m.initial_velocity_max = cfg.get("vmax", 3.0)
	m.gravity = cfg.get("grav", Vector3.ZERO)
	m.scale_min = cfg.get("smin", 1.0)
	m.scale_max = cfg.get("smax", 2.0)
	m.damping_min = cfg.get("damp", 0.0)
	m.damping_max = cfg.get("damp", 0.0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = cfg.get("erad", 0.3)
	m.anim_offset_min = 0.0
	m.anim_offset_max = 1.0
	m.anim_speed_min = 0.0
	m.anim_speed_max = 0.0
	if cfg.has("ramp"):
		m.color_ramp = _ramp(cfg["ramp"])
	if cfg.has("curve"):
		m.scale_curve = _curve(cfg["curve"])
	if cfg.get("fixed_angle", false):
		m.angle_min = -6.0
		m.angle_max = 6.0
	else:
		m.angle_min = 0.0
		m.angle_max = 360.0
	if cfg.has("turb"):
		m.turbulence_enabled = true
		m.turbulence_noise_strength = cfg["turb"]
		m.turbulence_noise_scale = cfg.get("turb_scale", 2.5)
		m.turbulence_noise_speed = Vector3(0, -cfg.get("turb_speed", 1.2), 0)
		m.turbulence_influence_min = 0.04
		m.turbulence_influence_max = 0.14
	if cfg.has("spin"):
		# Wolken drehen sich langsam beim Aufquellen, statt starr in der Luft zu stehen
		m.angular_velocity_min = -float(cfg["spin"])
		m.angular_velocity_max = float(cfg["spin"])
	if cfg.get("flat_emit", false):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_c[key] = m
	return m

static func _emit(pos: Vector3, pm: ParticleProcessMaterial, quad: QuadMesh, amount: int, life: float, one_shot := true, explos := 0.9, extent := 10.0) -> GPUParticles3D:
	var _off := String(Engine.get_meta("fxoff", ""))
	if _off != "":
		for k in _off.split(","):
			if k != "" and String(pm.get_meta("key", "")).begins_with(k):
				return null
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = quad
	p.amount = max(amount, 1)
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = explos if one_shot else 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-extent, -extent, -extent), Vector3(extent, extent, extent) * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(p)
	p.global_position = pos
	p.emitting = true
	if one_shot:
		var tw = p.create_tween()
		tw.tween_interval(life + 0.3)
		tw.tween_callback(p.queue_free)
	return p

static func _bucket(size: float) -> int:
	return clampi(int(round(size * 2.0)), 1, 20)

static func _seen(pos: Vector3) -> bool:
	return Game.is_visible_cell(pos)

# ---------------------------------------------------------------- Explosionen

static func explosion(pos: Vector3, size := 1.0, toxic := false) -> void:
	if not _seen(pos) and size < 3.0:
		return
	var b = _bucket(size)
	var s = b / 2.0
	# Feuerball: große, sich überlappende Wolken, die kaum auseinanderfliegen, nach oben aufsteigen und dabei dunkler werden
	var fire_cols = [Color(1.4, 1.3, 1.1, 0.0), Color(1.4, 1.25, 1.05, 1.0), Color(1.1, 0.95, 0.85, 0.95), Color(0.55, 0.42, 0.38, 0.8), Color(0.18, 0.15, 0.14, 0.5), Color(0.1, 0.09, 0.08, 0)]
	if toxic:
		fire_cols = [Color(0.85, 1, 0.6, 0.0), Color(0.6, 1, 0.3, 0.95), Color(0.3, 0.85, 0.12, 0.9), Color(0.12, 0.45, 0.06, 0.7), Color(0.05, 0.18, 0.04, 0.35), Color(0.02, 0.08, 0.02, 0)]
	var fire = _pm("fire6_%d%s" % [b, toxic], {"dir": Vector3.UP, "spread": 40.0, "vmin": 0.3 * s, "vmax": 1.7 * s, "smin": 3.4 * s, "smax": 5.4 * s, "spin": 40.0,
		"damp": 1.6 * s, "erad": 0.45 * s, "grav": Vector3(0, 1.8, 0), "ramp": fire_cols, "turb": 1.8, "turb_scale": 1.6, "turb_speed": 0.7,
		"curve": [Vector2(0, 0.35), Vector2(0.3, 0.9), Vector2(1, 1.2)]})
	_emit(pos + Vector3(0, 0.55 * s, 0), fire, _puffquad(false) if toxic else _firequad(), int(9 + 5 * s), 1.0 + 0.18 * s, true, 0.85, 6.0 * s + 4.0)
	# greller Kern: kurzer additiver Blitz
	var core = _pm("core4_%d%s" % [b, toxic], {"vmin": 0.0, "vmax": 0.4 * s, "smin": 0.7 * s, "smax": 1.1 * s, "erad": 0.12 * s,
		"ramp": [Color(1, 0.85, 0.55, 0.7), Color(1, 0.5, 0.15, 0.25), Color(1, 0.3, 0.05, 0)] if not toxic else [Color(0.9, 1, 0.7, 0.9), Color(0.5, 1, 0.3, 0.35), Color(0.2, 0.6, 0.05, 0)]})
	_emit(pos + Vector3(0, 0.5 * s, 0), core, _puffquad(true), 2, 0.14, true, 1.0, 4.0 * s + 3.0)
	# Rauchpilz: dunkel, dick, steigt langsam und breitet sich aus
	var smoke = _pm("smoke5_%d%s" % [b, toxic], {"dir": Vector3.UP, "spread": 28.0, "vmin": 0.5 * s, "vmax": 1.7 * s, "smin": 3.2 * s, "smax": 5.6 * s, "spin": 22.0, "damp": 0.8,
		"erad": 0.8 * s, "grav": Vector3(0, 1.0, 0), "turb": 1.5, "turb_scale": 1.3, "turb_speed": 0.45,
		"ramp": [Color(0.3, 0.27, 0.24, 0.0), Color(0.32, 0.29, 0.26, 0.92), Color(0.46, 0.45, 0.44, 0.7), Color(0.6, 0.6, 0.6, 0)] if not toxic
			else [Color(0.2, 0.4, 0.1, 0), Color(0.18, 0.42, 0.1, 0.75), Color(0.25, 0.5, 0.15, 0.45), Color(0.3, 0.5, 0.2, 0)],
		"curve": [Vector2(0, 0.45), Vector2(1, 1.6)]})
	_emit(pos + Vector3(0, 0.9 * s, 0), smoke, _puffquad(false, true), int(6 + 3 * s), 3.6 + 0.5 * s, true, 0.6, 10.0 * s + 6.0)
	# Trümmer: dunkle Brocken in Bögen
	var debris = _pm("debris3_%d" % b, {"dir": Vector3.UP, "spread": 60.0, "vmin": 3.0 * s, "vmax": 7.0 * s, "smin": 0.16, "smax": 0.36, "grav": Vector3(0, -15, 0),
		"ramp": [Color(0.22, 0.17, 0.12, 1), Color(0.12, 0.09, 0.07, 1), Color(0.08, 0.07, 0.06, 0)]})
	_emit(pos + Vector3(0, 0.4, 0), debris, _quad(false), int(5 + 3 * s), 1.2, true, 1.0, 9.0 * s + 4.0)
	# Staubwolke am Boden (Druckwelle)
	var dust = _pm("dust4_%d%s" % [b, toxic], {"dir": Vector3.UP, "spread": 88.0, "vmin": 2.5 * s, "vmax": 5.5 * s, "smin": 1.6 * s, "smax": 2.8 * s, "damp": 3.5 * s,
		"grav": Vector3(0, -1.2, 0), "erad": 0.5 * s, "curve": [Vector2(0, 0.5), Vector2(1, 1.4)],
		"ramp": [Color(0.42, 0.36, 0.27, 0.0), Color(0.45, 0.38, 0.28, 0.4), Color(0.5, 0.45, 0.36, 0)] if not toxic else [Color(0.4, 0.6, 0.3, 0.0), Color(0.4, 0.65, 0.3, 0.45), Color(0.4, 0.55, 0.3, 0)]})
	_emit(pos + Vector3(0, 0.3, 0), dust, _puffquad(false, true), int(6 + 3 * s), 1.8 + 0.2 * s, true, 1.0, 8.0 * s + 4.0)
	# Funkenregen: grelle, schnelle Splitter, die im Bogen fallen
	# (Helligkeit bewusst unter der Bloom-Schwelle: sonst blähen sich die Funken zu großen Leuchtkugeln auf)
	var sparks = _pm("sparks6_%d%s" % [b, toxic], {"dir": Vector3.UP, "spread": 75.0, "vmin": 5.0 * s, "vmax": 12.0 * s, "smin": 0.07, "smax": 0.13,
		"grav": Vector3(0, -13, 0), "damp": 0.6, "erad": 0.2 * s,
		"ramp": [Color(0.9, 0.7, 0.4, 0.55), Color(0.85, 0.45, 0.12, 0.45), Color(0.6, 0.2, 0.04, 0)] if not toxic else [Color(0.6, 0.9, 0.4, 0.55), Color(0.4, 0.8, 0.2, 0.45), Color(0.2, 0.5, 0.1, 0)]})
	_emit(pos + Vector3(0, 0.4 * s, 0), sparks, _quad(true), int(10 + 6 * s), 0.8, true, 1.0, 12.0 * s + 4.0)
	# Glutreste: glimmen am Boden nach und steigen langsam auf
	var embers = _pm("embers7_%d" % b, {"dir": Vector3.UP, "spread": 50.0, "vmin": 0.2, "vmax": 1.0 * s, "smin": 0.06, "smax": 0.11, "erad": 1.0 * s,
		"grav": Vector3(0.25, 0.5, 0), "turb": 0.8, "turb_scale": 1.0, "turb_speed": 0.4,
		"ramp": [Color(0.8, 0.4, 0.1, 0), Color(0.75, 0.35, 0.08, 0.4), Color(0.6, 0.18, 0.04, 0.25), Color(0.4, 0.08, 0.02, 0)]})
	_emit(pos + Vector3(0, 0.2, 0), embers, _quad(true), int(6 + 5 * s), 2.2 + 0.3 * s, true, 0.4, 6.0 * s + 4.0)
	# Erdklumpen: größere, dunkle Brocken mit kräftigem Wurf
	if not toxic:
		var clods = _pm("clods5_%d" % b, {"dir": Vector3.UP, "spread": 45.0, "vmin": 4.0 * s, "vmax": 8.5 * s, "smin": 0.18, "smax": 0.34, "grav": Vector3(0, -16, 0),
			"ramp": [Color(0.16, 0.12, 0.08, 1), Color(0.12, 0.09, 0.06, 1), Color(0.1, 0.08, 0.05, 0)]})
		_emit(pos + Vector3(0, 0.3, 0), clods, _quad(false), int(5 + 3 * s), 1.3, true, 1.0, 10.0 * s + 4.0)
	# Druckwelle: heller Ring, der sich flach über den Boden ausbreitet
	if size >= 0.8:
		shockwave(pos, Color(1.0, 0.88, 0.7) if not toxic else Color(0.7, 1.0, 0.5), 2.0 + 2.4 * s, 0.38 + 0.05 * s)
	# Nachrauch: bleibt stehen und zieht mit dem Wind ab, bei großen Explosionen deutlich länger
	if size >= 1.5:
		var after = _pm("after7_%d%s" % [b, toxic], {"dir": Vector3.UP, "spread": 20.0, "vmin": 0.3, "vmax": 0.9 * s, "smin": 2.8 * s, "smax": 4.6 * s, "spin": 14.0, "damp": 0.3,
			"erad": 0.6 * s, "grav": Vector3(0.6, 0.55, 0.2), "turb": 1.2, "turb_scale": 1.6, "turb_speed": 0.3,
			"ramp": [Color(0.22, 0.2, 0.19, 0), Color(0.25, 0.24, 0.23, 0.55), Color(0.34, 0.34, 0.34, 0.3), Color(0.4, 0.4, 0.4, 0)] if not toxic
				else [Color(0.2, 0.4, 0.1, 0), Color(0.25, 0.5, 0.15, 0.45), Color(0.3, 0.5, 0.2, 0)],
			"curve": [Vector2(0, 0.6), Vector2(1, 1.8)]})
		_emit(pos + Vector3(0, 1.2 * s, 0), after, _puffquad(false, true), int(5 + 2 * s), 7.0 + 1.2 * s, true, 0.15, 16.0 * s + 8.0)
	_flash(pos + Vector3(0, 1.0 + s * 0.5, 0), Color(0.6, 1.0, 0.3) if toxic else Color(1.0, 0.6, 0.25), 3.5 + 3.5 * s, 5.0 + s, 0.22 + 0.06 * s)
	if size >= 0.7:
		scorch(pos, 1.6 * s + 1.0)
	if Game.cam != null:
		Game.cam.shake(clamp(size * 0.12, 0.0, 1.5), pos)
## Treffer: kurzer Blitz und Funkenspritzer (Farbe der Waffe), dazu Staubfahne und dunkle Splitter.
static func impact(pos: Vector3, col := Color(1, 0.8, 0.4)) -> void:
	if not _seen(pos):
		return
	var sp = _pm("impact_sp2%s" % col.to_html(), {"dir": Vector3.UP, "spread": 85.0, "vmin": 3.0, "vmax": 7.5, "smin": 0.03, "smax": 0.06,
		"grav": Vector3(0, -12, 0), "damp": 0.8, "ramp": [Color(0.9, 0.85, 0.75, 0.6), Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.5), Color(col.r * 0.5, col.g * 0.35, col.b * 0.2, 0)]})
	_emit(pos, sp, _quad(true), 6, 0.35, true, 1.0, 5.0)
	var fl = _pm("impact_fl%s" % col.to_html(), {"vmin": 0.0, "vmax": 0.2, "smin": 0.45, "smax": 0.7, "erad": 0.02,
		"ramp": [Color(1, 0.98, 0.9, 0.95), Color(col.r, col.g, col.b, 0)]})
	_emit(pos, fl, _quad(true), 1, 0.07, true, 1.0, 2.0)
	var puff = _pm("impact2", {"dir": Vector3.UP, "spread": 60.0, "vmin": 0.3, "vmax": 1.2, "smin": 0.35, "smax": 0.7, "damp": 1.5, "grav": Vector3(0, 0.6, 0),
		"ramp": [Color(0.55, 0.48, 0.4, 0.0), Color(0.5, 0.44, 0.38, 0.55), Color(0.4, 0.38, 0.36, 0)], "curve": [Vector2(0, 0.5), Vector2(1, 1.4)]})
	_emit(pos, puff, _quad(false, true), 3, 0.55)
	var chip = _pm("impact2c", {"dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "smin": 0.06, "smax": 0.12, "grav": Vector3(0, -14, 0),
		"ramp": [Color(0.2, 0.17, 0.14, 1), Color(0.1, 0.08, 0.07, 0)]})
	_emit(pos, chip, _quad(false), 3, 0.4)

static func muzzle(pos: Vector3, col := Color(1, 0.75, 0.35), size := 1.0) -> void:
	if not _seen(pos):
		return
	var pm = _pm("muzzle%d" % _bucket(size), {"vmin": 0.0, "vmax": 0.6, "smin": 0.5 * size, "smax": 1.0 * size, "erad": 0.05,
		"ramp": [Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 0)]})
	_emit(pos, pm, _quad(true), 3, 0.09, true, 1.0)
	# Pulverdampf: graue Wolke, die aus der Mündung quillt und verweht
	var gas = _pm("muzzle_gas%d" % _bucket(size), {"dir": Vector3.UP, "spread": 50.0, "vmin": 0.3, "vmax": 1.2 * size, "smin": 0.5 * size, "smax": 1.0 * size,
		"damp": 2.0, "grav": Vector3(0.3, 0.5, 0), "erad": 0.08 * size, "curve": [Vector2(0, 0.5), Vector2(1, 1.6)],
		"ramp": [Color(0.6, 0.58, 0.55, 0), Color(0.55, 0.53, 0.5, 0.45), Color(0.6, 0.6, 0.6, 0)]})
	_emit(pos, gas, _puffquad(false, true), int(3 + 2 * size), 1.1 + 0.3 * size, true, 0.9, 4.0 * size + 2.0)
	if size >= 1.0:
		_flash(pos, col, 3.0, 4.0, 0.08)
	if size >= 1.6:
		dust(Vector3(pos.x, Game.terrain.height_at(pos.x, pos.z) if Game.terrain != null else pos.y - 2.0, pos.z), 0.8 * size)

static func _flash(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	Game.fx_root.add_child(l)
	l.global_position = pos
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

static func scorch(pos: Vector3, size: float) -> void:
	var d = Decal.new()
	d.texture_albedo = _scorch_tex()
	d.size = Vector3(size, 4.0, size)
	d.cull_mask = 1
	Game.fx_root.add_child(d)
	d.global_position = pos
	d.rotation.y = randf() * TAU
	var tw = d.create_tween()
	tw.tween_interval(25.0)
	tw.tween_property(d, "modulate:a", 0.0, 5.0)
	tw.tween_callback(d.queue_free)

# ---------------------------------------------------------------- Linien

static func _line_mat(col: Color, e: float) -> StandardMaterial3D:
	var key = "line%s%s" % [col.to_html(), e]
	if _c.has(key):
		return _c[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r * e, col.g * e, col.b * e, 1.0)
	m.disable_receive_shadows = true
	_c[key] = m
	return m

static func beam(from: Vector3, to: Vector3, col: Color, width := 0.08, dur := 0.07, e := 3.0) -> void:
	if not _seen(from) and not _seen(to):
		return
	var ln = from.distance_to(to)
	if ln < 0.05:
		return
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(width, width, ln)
	mi.mesh = bm
	mi.material_override = _line_mat(col, e)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(mi)
	mi.global_position = (from + to) * 0.5
	var up = Vector3.UP if abs((to - from).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.look_at(to, up)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), dur)
	tw.tween_callback(mi.queue_free)

static func tracer(from: Vector3, to: Vector3, col := Color(1.0, 0.8, 0.4)) -> void:
	beam(from, to, col, 0.06, 0.06, 2.5)

# ---------------------------------------------------------------- Dauerhafte Emitter

static func smoke_column(parent: Node3D, local_pos: Vector3, dark := false, lit := true) -> GPUParticles3D:
	var pm = _pm("chimney2%s%s" % [dark, lit], {"vmin": 0.8, "vmax": 1.6, "smin": 1.0, "smax": 2.0, "dir": Vector3.UP, "spread": 12.0, "spin": 18.0,
		"grav": Vector3(0.5, 0.6, 0.2), "erad": 0.3,
		"ramp": [Color(0.5, 0.5, 0.5, 0.0), Color(0.55, 0.55, 0.55, 0.4), Color(0.6, 0.6, 0.6, 0)] if not dark
			else [Color(0.12, 0.11, 0.1, 0.0), Color(0.1, 0.09, 0.08, 0.35), Color(0.16, 0.15, 0.14, 0.2), Color(0.2, 0.2, 0.2, 0)],
		"curve": [Vector2(0, 0.5), Vector2(1, 2.2)]})
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _quad(false, lit)
	p.amount = 14
	p.lifetime = 4.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 16, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = local_pos
	p.emitting = true
	return p

## Dauerfeuer: züngelnde Flammen, Funkenflug, Rauchfahne und flackerndes Licht.
## size 1.0 = Lagerfeuer, 2.0+ = brennendes Gebäude.
static func flame(parent: Node3D, local_pos: Vector3, size := 1.0, with_light := true) -> GPUParticles3D:
	var s = clampf(size, 0.5, 4.0)
	var key = int(round(s * 2.0))
	# Flammen (aufsteigend, verjüngt, Farbverlauf weiß-gelb → orange → rot → klar)
	var pm = _pm("flame%d" % key, {"vmin": 1.0 * s, "vmax": 2.2 * s, "smin": 1.3 * s, "smax": 2.0 * s, "dir": Vector3.UP, "spread": 12.0,
		"grav": Vector3(0, 0.6, 0), "erad": 0.5 * s, "fixed_angle": true, "turb": 1.4, "turb_scale": 2.2, "turb_speed": 1.6,
		"ramp": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.92), Color(1.0, 0.82, 0.7, 0.8), Color(0.85, 0.45, 0.35, 0.45), Color(0.3, 0.1, 0.1, 0.0)],
		"curve": [Vector2(0, 0.55), Vector2(0.25, 1.0), Vector2(0.7, 0.75), Vector2(1, 0.25)]})
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _flame_quad()
	p.amount = int(7 + 3 * s)
	p.lifetime = 0.95
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -1, -4) * s, Vector3(8, 8, 8) * s)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = local_pos
	p.emitting = true
	# Funken
	var ep = _pm("embers%d" % key, {"vmin": 1.2 * s, "vmax": 3.2 * s, "smin": 0.05, "smax": 0.11, "dir": Vector3.UP, "spread": 28.0,
		"grav": Vector3(0.25, 0.9, 0.1), "erad": 0.3 * s, "turb": 2.0, "turb_scale": 3.0,
		"ramp": [Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.7, 0.2, 1.0), Color(1.0, 0.35, 0.05, 0.8), Color(0.4, 0.1, 0.03, 0.0)]})
	var e = GPUParticles3D.new()
	e.process_material = ep
	e.draw_pass_1 = _quad(true)
	e.amount = int(8 + 6 * s)
	e.lifetime = 2.2
	e.local_coords = false
	e.visibility_aabb = AABB(Vector3(-5, -1, -5) * s, Vector3(10, 12, 10) * s)
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(e)
	e.position = local_pos + Vector3(0, 0.3 * s, 0)
	e.emitting = true
	# Rauch darüber
	smoke_column(parent, local_pos + Vector3(0, 1.6 * s, 0), true, false)
	# Flackerndes Licht
	if with_light:
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.omni_range = 5.0 + 2.5 * s
		l.light_energy = 2.0 * s
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.0
		parent.add_child(l)
		l.position = local_pos + Vector3(0, 0.7 * s, 0)
		var tw = l.create_tween().set_loops()
		for k in 6:
			tw.tween_property(l, "light_energy", randf_range(1.2, 2.8) * s, randf_range(0.06, 0.16))
	return p

## Brennender Schaden an Gebäuden und Wracks.
static func fire_burn(parent: Node3D, local_pos: Vector3) -> GPUParticles3D:
	return flame(parent, local_pos, 1.7, true)

static func trail(parent: Node3D, toxic := false) -> GPUParticles3D:
	var pm = _pm("trail%s" % toxic, {"vmin": 0.1, "vmax": 0.4, "smin": 0.4, "smax": 0.8, "grav": Vector3(0, 0.4, 0), "erad": 0.05,
		"ramp": [Color(1, 0.8, 0.4, 0.9), Color(0.5, 0.5, 0.5, 0.45), Color(0.6, 0.6, 0.6, 0)] if not toxic
			else [Color(0.7, 1, 0.4, 0.9), Color(0.3, 0.6, 0.2, 0.45), Color(0.4, 0.6, 0.3, 0)],
		"curve": [Vector2(0, 0.4), Vector2(1, 1.6)]})
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _quad(false, true)
	p.amount = 40
	p.lifetime = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p

static func flame_jet(from: Vector3, to: Vector3) -> void:
	if not _seen(from):
		return
	var dir = (to - from)
	var ln = dir.length()
	var pm = _pm("flame", {"dir": Vector3(0, 0, 1), "spread": 9.0, "vmin": 14.0, "vmax": 18.0, "smin": 0.5, "smax": 1.4,
		"erad": 0.1, "damp": 3.0, "grav": Vector3(0, 2, 0),
		"ramp": [Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.9), Color(0.4, 0.1, 0.02, 0)], "curve": [Vector2(0, 0.3), Vector2(1, 1.8)]})
	var p = _emit(from, pm, _quad(true), 14, clamp(ln / 15.0, 0.25, 0.7), true, 0.4)
	if ln > 0.1:
		p.look_at(to, Vector3.UP)
		p.rotate_object_local(Vector3.UP, PI)

static func toxin_spray(from: Vector3, to: Vector3) -> void:
	if not _seen(from):
		return
	var ln = from.distance_to(to)
	var pm = _pm("toxspray", {"dir": Vector3(0, 0, 1), "spread": 10.0, "vmin": 10.0, "vmax": 13.0, "smin": 0.5, "smax": 1.2,
		"erad": 0.1, "damp": 2.0, "grav": Vector3(0, -3, 0),
		"ramp": [Color(0.7, 1, 0.3, 0.9), Color(0.3, 0.8, 0.1, 0.6), Color(0.2, 0.4, 0.1, 0)], "curve": [Vector2(0, 0.3), Vector2(1, 1.8)]})
	var p = _emit(from, pm, _quad(true), 12, clamp(ln / 11.0, 0.25, 0.8), true, 0.4)
	if ln > 0.1:
		p.look_at(to, Vector3.UP)
		p.rotate_object_local(Vector3.UP, PI)

static func toxin_cloud(pos: Vector3, radius: float, dur: float) -> void:
	var pm = _pm("toxcloud%d" % int(radius), {"vmin": 0.2, "vmax": 0.8, "smin": 2.5, "smax": 5.0, "erad": radius * 0.8,
		"grav": Vector3(0, 0.15, 0),
		"ramp": [Color(0.4, 0.9, 0.2, 0), Color(0.35, 0.8, 0.15, 0.35), Color(0.3, 0.7, 0.1, 0)], "curve": [Vector2(0, 0.6), Vector2(1, 1.3)]})
	var p = _emit(pos + Vector3(0, 0.8, 0), pm, _quad(true), int(radius * 6), 3.0, false, 0.0, radius + 8.0)
	var tw = p.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(3.2)
	tw.tween_callback(p.queue_free)

static func dust(pos: Vector3, size := 1.0) -> void:
	if not _seen(pos):
		return
	var pm = _pm("dust%d" % _bucket(size), {"vmin": 0.5, "vmax": 2.0 * size, "smin": 1.0 * size, "smax": 2.2 * size, "erad": 1.0 * size,
		"grav": Vector3(0, 0.4, 0), "damp": 1.0,
		"ramp": [Color(0.5, 0.45, 0.36, 0), Color(0.5, 0.45, 0.36, 0.2), Color(0.55, 0.5, 0.4, 0)]})
	_emit(pos, pm, _quad(false, true), int(6 * size) + 2, 1.8)

static func sparkle(pos: Vector3, col := Color(0.4, 1.0, 0.5)) -> void:
	if not _seen(pos):
		return
	var pm = _pm("sparkle%s" % col.to_html(), {"vmin": 1.0, "vmax": 2.5, "smin": 0.15, "smax": 0.3, "dir": Vector3.UP, "spread": 30.0,
		"grav": Vector3(0, 1, 0), "erad": 1.0, "ramp": [col, Color(col.r, col.g, col.b, 0)]})
	_emit(pos, pm, _quad(true), 14, 1.0)

static func weld(pos: Vector3) -> void:
	if not _seen(pos):
		return
	var pm = _pm("weld", {"vmin": 2.0, "vmax": 5.0, "smin": 0.06, "smax": 0.14, "grav": Vector3(0, -10, 0), "spread": 60.0,
		"ramp": [Color(0.8, 0.9, 1, 1), Color(1, 0.7, 0.3, 0)]})
	_emit(pos, pm, _quad(true), 8, 0.5)

## Druckwelle: dünner, flacher Ring am Boden, der sich schnell ausbreitet und dabei verblasst.
static func shockwave(pos: Vector3, col: Color, radius: float, dur: float) -> void:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.18)
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(0.4, 0.06, 0.4)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.04, radius), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

static func ring(pos: Vector3, col: Color, radius: float, dur: float) -> void:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = _line_mat(col, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.5, 1.0, 0.5)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 2.0, radius), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(mi.queue_free)

## Klick-Markierung am Boden.
static func marker(pos: Vector3, col: Color) -> void:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = _line_mat(col, 1.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.2, 0)
	mi.scale = Vector3(1.6, 1, 1.6)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.3, 1, 0.3), 0.45)
	tw.tween_callback(mi.queue_free)

# ---------------------------------------------------------------- Superwaffen

static func nuke(pos: Vector3) -> void:
	explosion(pos, 6.0)
	ring(pos, Color(1.0, 0.6, 0.3), 26.0, 1.2)
	_flash(pos + Vector3(0, 12, 0), Color(1.0, 0.85, 0.6), 40.0, 90.0, 2.5)
	var stem = _pm("nukestem", {"dir": Vector3.UP, "spread": 8.0, "vmin": 6.0, "vmax": 10.0, "smin": 3.0, "smax": 5.0, "erad": 2.0,
		"damp": 0.6, "ramp": [Color(1, 0.8, 0.4, 1), Color(0.9, 0.35, 0.1, 0.9), Color(0.3, 0.2, 0.15, 0.6), Color(0.3, 0.3, 0.3, 0)],
		"curve": [Vector2(0, 0.6), Vector2(1, 1.6)]})
	var s = _emit(pos, stem, _quad(true), 70, 3.5, false, 0.0, 40.0)
	var cap = _pm("nukecap", {"dir": Vector3.UP, "spread": 180.0, "vmin": 2.0, "vmax": 7.0, "smin": 5.0, "smax": 9.0, "erad": 4.0,
		"damp": 1.5, "grav": Vector3(0, 0.5, 0),
		"ramp": [Color(1, 0.9, 0.6, 1), Color(1, 0.4, 0.1, 0.9), Color(0.35, 0.2, 0.15, 0.7), Color(0.25, 0.25, 0.25, 0)],
		"curve": [Vector2(0, 0.5), Vector2(1, 1.4)]})
	var c = _emit(pos + Vector3(0, 22, 0), cap, _quad(true), 60, 4.0, false, 0.0, 40.0)
	for e in [s, c]:
		var tw: Tween = e.create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func(): e.emitting = false)
		tw.tween_interval(4.5)
		tw.tween_callback(e.queue_free)
	scorch(pos, 30.0)
	if Game.cam != null:
		Game.cam.shake(2.5, pos)

static func orbital(pos: Vector3, dur: float) -> void:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 2.0
	cm.bottom_radius = 2.0
	cm.height = 200.0
	mi.mesh = cm
	mi.material_override = _line_mat(Color(0.4, 0.85, 1.0), 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.fx_root.add_child(mi)
	mi.global_position = pos + Vector3(0, 100, 0)
	mi.scale = Vector3(0.1, 1, 0.1)
	var l = OmniLight3D.new()
	l.light_color = Color(0.5, 0.85, 1.0)
	l.light_energy = 20.0
	l.omni_range = 40.0
	Game.fx_root.add_child(l)
	l.global_position = pos + Vector3(0, 4, 0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.6, 1, 1.6), 0.3)
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3(0.05, 1, 0.05), 0.4)
	tw.tween_callback(mi.queue_free)
	tw.tween_callback(l.queue_free)
	ring(pos, Color(0.4, 0.85, 1.0), 18.0, dur)
	scorch(pos, 22.0)
