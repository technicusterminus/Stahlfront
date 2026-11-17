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

static func _scorch_tex() -> Texture2D:
	if _c.has("scorch"):
		return _c["scorch"]
	var g = Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.02, 0.9))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	g.add_point(0.55, Color(0.05, 0.04, 0.03, 0.6))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_c["scorch"] = t
	return t

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
	if cfg.has("ramp"):
		m.color_ramp = _ramp(cfg["ramp"])
	if cfg.has("curve"):
		m.scale_curve = _curve(cfg["curve"])
	m.angle_min = 0.0
	m.angle_max = 360.0
	_c[key] = m
	return m

static func _emit(pos: Vector3, pm: ParticleProcessMaterial, quad: QuadMesh, amount: int, life: float, one_shot := true, explos := 0.9, extent := 10.0) -> GPUParticles3D:
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
	var fire_cols = [Color(1, 0.95, 0.7, 1), Color(1, 0.55, 0.12, 0.9), Color(0.6, 0.12, 0.03, 0.5), Color(0.1, 0.05, 0.02, 0)]
	if toxic:
		fire_cols = [Color(0.85, 1, 0.6, 1), Color(0.35, 0.9, 0.15, 0.9), Color(0.1, 0.4, 0.05, 0.5), Color(0.02, 0.1, 0.02, 0)]
	var fire = _pm("fire%d%s" % [b, toxic], {"vmin": 1.5 * s, "vmax": 5.0 * s, "smin": 1.2 * s, "smax": 2.6 * s, "damp": 4.0 * s,
		"erad": 0.4 * s, "grav": Vector3(0, 2.0, 0), "ramp": fire_cols, "curve": [Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 0.7)]})
	_emit(pos + Vector3(0, 0.5 * s, 0), fire, _quad(true), int(14 + 8 * s), 0.7 + 0.12 * s, true, 0.95, 6.0 * s + 4.0)
	var smoke = _pm("smoke%d%s" % [b, toxic], {"vmin": 0.6 * s, "vmax": 2.2 * s, "smin": 1.8 * s, "smax": 3.6 * s, "damp": 1.0,
		"erad": 0.6 * s, "grav": Vector3(0, 1.4, 0),
		"ramp": [Color(0.1, 0.09, 0.08, 0.0), Color(0.07, 0.065, 0.06, 0.7), Color(0.12, 0.12, 0.12, 0.35), Color(0.16, 0.16, 0.16, 0)] if not toxic
			else [Color(0.2, 0.4, 0.1, 0), Color(0.2, 0.45, 0.1, 0.6), Color(0.25, 0.5, 0.15, 0.3), Color(0.3, 0.5, 0.2, 0)],
		"curve": [Vector2(0, 0.5), Vector2(1, 1.4)]})
	_emit(pos + Vector3(0, 0.6 * s, 0), smoke, _quad(false, true), int(8 + 5 * s), 2.6 + 0.4 * s, true, 0.8, 8.0 * s + 6.0)
	var sparks = _pm("spark%d" % b, {"vmin": 6.0 * s, "vmax": 14.0 * s, "smin": 0.12, "smax": 0.25, "grav": Vector3(0, -14, 0),
		"dir": Vector3.UP, "spread": 70.0, "ramp": [Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.1, 1), Color(1, 0.3, 0.05, 0)]})
	_emit(pos + Vector3(0, 0.3, 0), sparks, _quad(true), int(10 + 6 * s), 0.9, true, 1.0, 8.0 * s + 4.0)
	_flash(pos + Vector3(0, 1.0 + s * 0.5, 0), Color(0.6, 1.0, 0.3) if toxic else Color(1.0, 0.6, 0.25), 4.0 + 4.0 * s, 5.0 + s, 0.25 + 0.08 * s)
	if size >= 1.0:
		scorch(pos, 1.6 * s + 1.0)
	if Game.cam != null:
		Game.cam.shake(clamp(size * 0.12, 0.0, 1.5), pos)

static func impact(pos: Vector3, col := Color(1, 0.8, 0.4)) -> void:
	if not _seen(pos):
		return
	var pm = _pm("impact", {"vmin": 2.0, "vmax": 6.0, "smin": 0.08, "smax": 0.18, "grav": Vector3(0, -12, 0), "spread": 80.0,
		"ramp": [Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.1, 0)]})
	_emit(pos, pm, _quad(true), 6, 0.35)


static func muzzle(pos: Vector3, col := Color(1, 0.75, 0.35), size := 1.0) -> void:
	if not _seen(pos):
		return
	var pm = _pm("muzzle%d" % _bucket(size), {"vmin": 0.0, "vmax": 0.6, "smin": 0.5 * size, "smax": 1.0 * size, "erad": 0.05,
		"ramp": [Color(1, 0.95, 0.8, 1), Color(1, 0.6, 0.2, 0)]})
	_emit(pos, pm, _quad(true), 3, 0.09, true, 1.0)
	if size >= 1.0:
		_flash(pos, col, 3.0, 4.0, 0.08)

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

static func smoke_column(parent: Node3D, local_pos: Vector3, dark := false) -> GPUParticles3D:
	var pm = _pm("chimney%s" % dark, {"vmin": 0.8, "vmax": 1.6, "smin": 1.0, "smax": 2.0, "dir": Vector3.UP, "spread": 12.0,
		"grav": Vector3(0.5, 0.6, 0.2), "erad": 0.3,
		"ramp": [Color(0.5, 0.5, 0.5, 0.0), Color(0.55, 0.55, 0.55, 0.4), Color(0.6, 0.6, 0.6, 0)] if not dark
			else [Color(0.1, 0.1, 0.1, 0.0), Color(0.08, 0.08, 0.08, 0.6), Color(0.15, 0.15, 0.15, 0)],
		"curve": [Vector2(0, 0.5), Vector2(1, 2.2)]})
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _quad(false, true)
	p.amount = 14
	p.lifetime = 4.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 16, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = local_pos
	p.emitting = true
	return p

static func fire_burn(parent: Node3D, local_pos: Vector3) -> GPUParticles3D:
	var pm = _pm("burn", {"vmin": 0.6, "vmax": 1.8, "smin": 0.8, "smax": 1.6, "dir": Vector3.UP, "spread": 20.0,
		"grav": Vector3(0, 1.5, 0), "erad": 0.6,
		"ramp": [Color(1, 0.9, 0.5, 0.0), Color(1, 0.5, 0.1, 0.9), Color(0.3, 0.1, 0.05, 0.3), Color(0.1, 0.1, 0.1, 0)]})
	var p = GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _quad(true)
	p.amount = 18
	p.lifetime = 1.1
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = local_pos
	p.emitting = true
	return p

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
