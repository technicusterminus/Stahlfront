extends Node3D
## Wildtiere: grasende Hirschherden, die vor Einheiten und Gefechten fliehen,
## und Vogelschwärme, die über den Wäldern kreisen und bei Lärm auffliegen.

const Models = preload("res://scripts/models.gd")

var rng = RandomNumberGenerator.new()
var herds: Array = []
var flocks: Array = []

func setup(seed_val: int, avoid: Array) -> void:
	rng.seed = seed_val + 77
	var tries = 0
	while herds.size() < 7 and tries < 400:
		tries += 1
		var p = Vector3(rng.randf_range(-95, 95), 0, rng.randf_range(-95, 95))
		if not _ok(p) or _near_any(p, avoid, 45.0):
			continue
		var h = {"center": p, "target": p, "speed": 1.4, "flee_t": 0.0, "wait": rng.randf_range(2, 8), "check": 0.0, "deer": []}
		for i in rng.randi_range(3, 6):
			var d = _make_deer(rng.randf() < 0.3)
			add_child(d["node"])
			d["off"] = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
			d["pos"] = p + d["off"]
			d["node"].position = d["pos"]
			h["deer"].append(d)
		herds.append(h)
	for f in 4:
		var c = Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80))
		var fl = {"anchor": c, "angle": rng.randf() * TAU, "h": rng.randf_range(18, 26), "r": rng.randf_range(10, 20), "check": 0.0, "birds": []}
		for i in 9:
			var b = _make_bird()
			add_child(b["node"])
			b["off"] = Vector3(rng.randf_range(-4, 4), rng.randf_range(-1.5, 1.5), rng.randf_range(-4, 4))
			b["phase"] = rng.randf() * TAU
			fl["birds"].append(b)
		flocks.append(fl)

func _near_any(p: Vector3, pts: Array, r: float) -> bool:
	for q in pts:
		if Vector2(p.x - q.x, p.z - q.y).length() < r:
			return true
	return false

func _ok(p: Vector3) -> bool:
	return Game.is_free(Game.world_to_cell(p)) and Game.terrain.height_at(p.x, p.z) > Game.terrain.WATER_Y + 0.4

# ---------------------------------------------------------------- Modelle

func _make_deer(stag: bool) -> Dictionary:
	var n = Node3D.new()
	var fur = Models.mat(Color(0.42, 0.27, 0.15), 0.0, 0.9)
	var belly = Models.mat(Color(0.75, 0.62, 0.48), 0.0, 0.9)
	var dark = Models.mat(Color(0.12, 0.09, 0.07), 0.0, 0.9)
	Models.box(n, Vector3(0.42, 0.45, 1.05), Vector3(0, 1.0, 0), fur)
	Models.box(n, Vector3(0.36, 0.12, 0.85), Vector3(0, 0.8, 0), belly)
	Models.box(n, Vector3(0.12, 0.12, 0.1), Vector3(0, 1.15, -0.55), Models.mat(Color(0.9, 0.88, 0.82), 0.0, 0.9))
	var neck = Node3D.new()
	neck.position = Vector3(0, 1.15, 0.45)
	n.add_child(neck)
	Models.box(neck, Vector3(0.2, 0.55, 0.22), Vector3(0, 0.25, 0.08), fur, Vector3(0.45, 0, 0))
	Models.box(neck, Vector3(0.2, 0.2, 0.38), Vector3(0, 0.55, 0.28), fur)
	Models.box(neck, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.52, 0.48), dark)
	for sx in [-1, 1]:
		Models.box(neck, Vector3(0.05, 0.16, 0.08), Vector3(sx * 0.12, 0.7, 0.18), fur, Vector3(0, 0, sx * 0.4))
		if stag:
			Models.box(neck, Vector3(0.035, 0.45, 0.035), Vector3(sx * 0.1, 0.9, 0.2), dark, Vector3(-0.3, 0, sx * 0.35))
			Models.box(neck, Vector3(0.03, 0.2, 0.03), Vector3(sx * 0.18, 1.0, 0.32), dark, Vector3(0.6, 0, sx * 0.2))
	var legs: Array = []
	for lz in [0.38, -0.38]:
		for sx in [-0.14, 0.14]:
			var hip = Node3D.new()
			hip.position = Vector3(sx, 0.85, lz)
			n.add_child(hip)
			Models.box(hip, Vector3(0.08, 0.85, 0.09), Vector3(0, -0.42, 0), fur)
			Models.box(hip, Vector3(0.09, 0.08, 0.11), Vector3(0, -0.84, 0.01), dark)
			legs.append(hip)
	n.scale = Vector3.ONE * (1.15 if stag else 1.0)
	return {"node": n, "legs": legs, "neck": neck, "pos": Vector3.ZERO, "heading": rng.randf() * TAU, "walk": rng.randf() * 10.0, "graze": rng.randf() * 10.0}

func _make_bird() -> Dictionary:
	var n = Node3D.new()
	var m = Models.mat(Color(0.12, 0.11, 0.1), 0.0, 0.8)
	Models.box(n, Vector3(0.14, 0.12, 0.45), Vector3.ZERO, m)
	Models.box(n, Vector3(0.1, 0.1, 0.12), Vector3(0, 0.03, 0.25), m)
	var wl = Node3D.new()
	var wr = Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	Models.box(wl, Vector3(0.55, 0.02, 0.22), Vector3(-0.3, 0, 0), m)
	Models.box(wr, Vector3(0.55, 0.02, 0.22), Vector3(0.3, 0, 0), m)
	n.scale = Vector3.ONE * 1.6
	return {"node": n, "wl": wl, "wr": wr}

# ---------------------------------------------------------------- Verhalten

func _physics_process(delta: float) -> void:
	if Game.terrain == null:
		return
	for h in herds:
		_update_herd(h, delta)
	for fl in flocks:
		_update_flock(fl, delta)

func _danger(p: Vector3, r: float) -> Vector3:
	# Richtung der Bedrohung (Einheit in der Nähe oder frisches Gefecht), sonst null
	for u in Game.units_near(p, r):
		if not u.flying or u.def["weapon"] != null:
			return u.position
	if Game.time - Game.last_combat_t < 3.0 and Game.flat_dist(Game.last_combat_pos, p) < r * 2.2:
		return Game.last_combat_pos
	return Vector3.INF

func _update_herd(h: Dictionary, delta: float) -> void:
	h["check"] -= delta
	if h["check"] <= 0.0:
		h["check"] = 0.5
		var dp = _danger(h["center"], 16.0)
		if dp != Vector3.INF:
			var away = (h["center"] - dp)
			away.y = 0
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			var tgt = h["center"] + away.normalized() * 35.0
			tgt.x = clamp(tgt.x, -100, 100)
			tgt.z = clamp(tgt.z, -100, 100)
			h["target"] = tgt
			h["speed"] = 9.0
			h["flee_t"] = 4.0
	h["flee_t"] -= delta
	if h["flee_t"] <= 0.0:
		h["speed"] = 1.3
		h["wait"] -= delta
		if h["wait"] <= 0.0:
			h["wait"] = rng.randf_range(6, 14)
			var t = h["center"] + Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
			if _ok(t):
				h["target"] = t
	var c: Vector3 = h["center"]
	var to = h["target"] - c
	to.y = 0
	if to.length() > 1.0:
		var step = to.normalized() * h["speed"] * delta
		if _ok(c + step * 4.0):
			h["center"] = c + step
		else:
			h["target"] = c
	var vis_any = false
	for d in h["deer"]:
		var goal: Vector3 = h["center"] + d["off"]
		var dv = goal - d["pos"]
		dv.y = 0
		var moving = dv.length() > 0.6
		var spd = h["speed"] * 1.15 if moving else 0.0
		if moving and _ok(d["pos"] + dv.normalized() * 1.0):
			d["pos"] += dv.normalized() * min(spd * delta, dv.length())
			d["heading"] = lerp_angle(d["heading"], atan2(dv.x, dv.z), min(1.0, 6.0 * delta))
		var p: Vector3 = d["pos"]
		p.y = Game.terrain.ground_y(p.x, p.z)
		var n: Node3D = d["node"]
		n.position = p
		n.rotation.y = d["heading"]
		d["walk"] += delta * (spd * 2.2 if moving else 0.0)
		var amp = clamp(spd / 6.0, 0.25, 0.6) if moving else 0.0
		for i in 4:
			d["legs"][i].rotation.x = sin(d["walk"] + (PI if i % 2 == 0 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)) * amp
		d["graze"] += delta
		var head_down = not moving and sin(d["graze"] * 0.5) > 0.2
		d["neck"].rotation.x = lerp(d["neck"].rotation.x, 1.0 if head_down else 0.0, min(1.0, 3.0 * delta))
		n.visible = Game.is_visible_cell(p)

func _update_flock(fl: Dictionary, delta: float) -> void:
	fl["check"] -= delta
	if fl["check"] <= 0.0:
		fl["check"] = 0.7
		var dp = _danger(fl["anchor"], 22.0)
		if dp != Vector3.INF:
			var away = fl["anchor"] - dp
			away.y = 0
			if away.length() < 0.1:
				away = Vector3(0, 0, 1)
			fl["anchor"] = fl["anchor"] + away.normalized() * 40.0
			fl["anchor"].x = clamp(fl["anchor"].x, -100, 100)
			fl["anchor"].z = clamp(fl["anchor"].z, -100, 100)
	fl["angle"] += delta * 0.35
	var a: float = fl["angle"]
	var center = fl["anchor"] + Vector3(cos(a), 0, sin(a)) * fl["r"]
	var tangent = Vector3(-sin(a), 0, cos(a))
	var gy = Game.terrain.ground_y(center.x, center.z)
	for b in fl["birds"]:
		var n: Node3D = b["node"]
		var tgt = center + b["off"] + Vector3(0, gy + fl["h"] + sin(Game.time + b["phase"]) * 0.8, 0)
		n.position = n.position.lerp(tgt, min(1.0, 1.5 * delta)) if n.position != Vector3.ZERO else tgt
		n.rotation.y = atan2(tangent.x, tangent.z)
		var flap = sin(Game.time * 9.0 + b["phase"]) * 0.7
		b["wl"].rotation.z = flap
		b["wr"].rotation.z = -flap
		n.visible = Game.is_visible_cell(n.position)
