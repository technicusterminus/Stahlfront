extends Node3D
## Wildtiere: grasende Hirschherden, die vor Einheiten und Gefechten fliehen,
## und Vogelschwärme, die über den Wäldern kreisen und bei Lärm auffliegen.

const Models = preload("res://scripts/models.gd")

var rng = RandomNumberGenerator.new()
var herds: Array = []
var flocks: Array = []
var schools: Array = []   # Fischschwaerme unter der Wasserflaeche
var swimmers: Array = []  # Enten und Schwaene auf dem Wasser

func setup(seed_val: int, avoid: Array) -> void:
	rng.seed = seed_val + 77
	var bio: Dictionary = load("res://scripts/biome.gd").of(Game.terrain)
	var fauna: Dictionary = bio.get("fauna", {"deer": 7})
	var birds: Dictionary = bio.get("birds", {"crow": 4})
	for kind in fauna:
		var made := 0
		var tries := 0
		while made < int(fauna[kind]) and tries < 400:
			tries += 1
			var p = Vector3(rng.randf_range(-Game.HALF * 0.8, Game.HALF * 0.8), 0, rng.randf_range(-Game.HALF * 0.8, Game.HALF * 0.8))
			if not _ok(p) or _near_any(p, avoid, 45.0):
				continue
			if kind == "goat" and Game.terrain.height_at(p.x, p.z) < 2.5 and tries < 300:
				continue
			var h = {"center": p, "target": p, "speed": 1.4, "flee_t": 0.0, "wait": rng.randf_range(2, 8), "check": 0.0, "deer": [], "kind": kind}
			var n_head: int = rng.randi_range(3, 6) if kind != "boar" else rng.randi_range(2, 5)
			for i in n_head:
				var d = _make_beast(kind, rng.randf() < 0.3)
				add_child(d["node"])
				d["off"] = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				d["pos"] = p + d["off"]
				d["node"].position = d["pos"]
				h["deer"].append(d)
			herds.append(h)
			made += 1
	for kind in birds:
		for f in int(birds[kind]):
			var c = Vector3(rng.randf_range(-Game.HALF * 0.67, Game.HALF * 0.67), 0, rng.randf_range(-Game.HALF * 0.67, Game.HALF * 0.67))
			var eagle: bool = kind == "eagle"
			var fl = {"anchor": c, "angle": rng.randf() * TAU, "h": rng.randf_range(18, 26) + (14.0 if eagle else 0.0), "r": rng.randf_range(10, 20) * (1.8 if eagle else 1.0), "check": 0.0, "birds": [], "kind": kind}
			var n_birds: int = 2 if eagle else (6 if kind == "gull" or kind == "duck" else 9)
			for i in n_birds:
				var b = _make_bird(kind)
				add_child(b["node"])
				b["off"] = Vector3(rng.randf_range(-4, 4), rng.randf_range(-1.5, 1.5), rng.randf_range(-4, 4))
				b["phase"] = rng.randf() * TAU
				fl["birds"].append(b)
			flocks.append(fl)

	_setup_water(bio)

func _near_any(p: Vector3, pts: Array, r: float) -> bool:
	for q in pts:
		if Vector2(p.x - q.x, p.z - q.y).length() < r:
			return true
	return false

func _ok(p: Vector3) -> bool:
	return Game.is_free(Game.world_to_cell(p)) and Game.terrain.height_at(p.x, p.z) > Game.terrain.WATER_Y + 0.4

# ---------------------------------------------------------------- Wassertiere

func _water_spot(min_depth: float) -> Vector3:
	for i in 300:
		var p := Vector3(rng.randf_range(-Game.HALF * 0.85, Game.HALF * 0.85), 0, rng.randf_range(-Game.HALF * 0.85, Game.HALF * 0.85))
		if Game.terrain.height_at(p.x, p.z) < Game.terrain.WATER_Y - min_depth:
			return p
	return Vector3.INF

func _setup_water(bio: Dictionary) -> void:
	var wf: Dictionary = bio.get("water", {"fish": 5, "ducks": 2})
	for i in int(wf.get("fish", 0)):
		var c := _water_spot(1.4)
		if c == Vector3.INF:
			break
		var sc := {"anchor": c, "angle": rng.randf() * TAU, "r": rng.randf_range(3.0, 7.0), "speed": rng.randf_range(0.35, 0.6), "fish": [], "jump_t": rng.randf_range(4.0, 12.0), "jump": null}
		for k in rng.randi_range(5, 9):
			var f := _make_fish(rng.randf_range(0.7, 1.4))
			add_child(f["node"])
			f["off"] = Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-0.5, -0.1), rng.randf_range(-2.0, 2.0))
			f["phase"] = rng.randf() * TAU
			sc["fish"].append(f)
		schools.append(sc)
	for i in int(wf.get("ducks", 0)):
		var c := _water_spot(0.5)
		if c == Vector3.INF:
			break
		var g := {"center": c, "target": c, "wait": rng.randf_range(2, 8), "check": 0.0, "flee": 0.0, "birds": []}
		for k in rng.randi_range(3, 6):
			var d := _make_duck()
			add_child(d["node"])
			d["off"] = Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			d["pos"] = c + d["off"]
			d["heading"] = rng.randf() * TAU
			g["birds"].append(d)
		swimmers.append(g)

func _make_fish(sc: float) -> Dictionary:
	var n := Node3D.new()
	var col := Color(0.12, 0.16, 0.17).lerp(Color(0.3, 0.32, 0.28), rng.randf())
	var m := Models.mat(col, 0.0, 0.6)
	Models.box(n, Vector3(0.16, 0.14, 0.62), Vector3.ZERO, m)
	Models.box(n, Vector3(0.1, 0.1, 0.22), Vector3(0, 0, 0.36), m)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0, -0.32)
	n.add_child(tail)
	Models.box(tail, Vector3(0.03, 0.26, 0.2), Vector3(0, 0, -0.1), m)
	n.scale = Vector3.ONE * sc
	return {"node": n, "tail": tail}

func _make_duck() -> Dictionary:
	var n := Node3D.new()
	var body := Models.mat(Color(0.38, 0.3, 0.2), 0.0, 0.9)
	var head := Models.mat(Color(0.1, 0.32, 0.22), 0.0, 0.8)
	var beak := Models.mat(Color(0.85, 0.62, 0.15), 0.0, 0.8)
	Models.box(n, Vector3(0.3, 0.2, 0.5), Vector3(0, 0.1, 0), body)
	Models.box(n, Vector3(0.14, 0.16, 0.16), Vector3(0, 0.3, 0.26), head)
	Models.box(n, Vector3(0.08, 0.04, 0.12), Vector3(0, 0.28, 0.4), beak)
	Models.box(n, Vector3(0.2, 0.1, 0.18), Vector3(0, 0.16, -0.3), body, Vector3(0.4, 0, 0))
	n.scale = Vector3.ONE * 1.4
	return {"node": n}

func _update_water(delta: float) -> void:
	var wy: float = Game.terrain.WATER_Y
	for sc in schools:
		sc["angle"] += delta * sc["speed"]
		var a: float = sc["angle"]
		var center: Vector3 = sc["anchor"] + Vector3(cos(a), 0, sin(a)) * sc["r"]
		var tgt := Vector3(-sin(a), 0, cos(a))
		var vis_any := false
		for f in sc["fish"]:
			var n: Node3D = f["node"]
			var pos: Vector3 = center + f["off"]
			pos.y = wy + f["off"].y
			n.position = pos + Vector3(sin(Game.time * 0.7 + f["phase"]) * 0.3, 0, cos(Game.time * 0.6 + f["phase"]) * 0.3)
			n.rotation.y = atan2(tgt.x, tgt.z) + sin(Game.time * 3.0 + f["phase"]) * 0.12
			f["tail"].rotation.y = sin(Game.time * 9.0 + f["phase"]) * 0.5
			n.visible = Game.is_visible_cell(n.position)
		# gelegentlicher Sprung eines Fisches
		sc["jump_t"] -= delta
		if sc["jump_t"] <= 0.0 and sc["jump"] == null:
			sc["jump"] = {"f": sc["fish"][rng.randi() % sc["fish"].size()], "t": 0.0}
			sc["jump_t"] = rng.randf_range(7.0, 16.0)
		if sc["jump"] != null:
			var j: Dictionary = sc["jump"]
			j["t"] += delta / 0.9
			var nn: Node3D = j["f"]["node"]
			var k: float = j["t"]
			if k >= 1.0:
				sc["jump"] = null
			else:
				nn.position.y = wy + sin(k * PI) * 1.1 - 0.1
				nn.rotation.x = cos(k * PI) * 0.9
	for g in swimmers:
		g["check"] -= delta
		if g["check"] <= 0.0:
			g["check"] = 0.6
			var dp = _danger(g["center"], 18.0)
			if dp != Vector3.INF:
				var away: Vector3 = g["center"] - dp
				away.y = 0
				var tgt2: Vector3 = g["center"] + away.normalized() * 24.0
				if Game.terrain.height_at(tgt2.x, tgt2.z) < wy - 0.3:
					g["target"] = tgt2
					g["flee"] = 3.0
		g["flee"] -= delta
		g["wait"] -= delta
		if g["wait"] <= 0.0 and g["flee"] <= 0.0:
			g["wait"] = rng.randf_range(5, 12)
			var t2: Vector3 = g["center"] + Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
			if Game.terrain.height_at(t2.x, t2.z) < wy - 0.3:
				g["target"] = t2
		var to: Vector3 = g["target"] - g["center"]
		to.y = 0
		var sp: float = 2.6 if g["flee"] > 0.0 else 0.5
		if to.length() > 0.6:
			var np: Vector3 = g["center"] + to.normalized() * sp * delta
			if Game.terrain.height_at(np.x, np.z) < wy - 0.25:
				g["center"] = np
		for d in g["birds"]:
			var goal: Vector3 = g["center"] + d["off"]
			var dv: Vector3 = goal - d["pos"]
			dv.y = 0
			if dv.length() > 0.5:
				d["pos"] += dv.normalized() * minf(sp * 1.2 * delta, dv.length())
				d["heading"] = lerp_angle(d["heading"], atan2(dv.x, dv.z), minf(1.0, 4.0 * delta))
			var n2: Node3D = d["node"]
			n2.position = Vector3(d["pos"].x, wy + sin(Game.time * 1.6 + d["pos"].x) * 0.04 - 0.02, d["pos"].z)
			n2.rotation.y = d["heading"]
			n2.rotation.z = sin(Game.time * 1.3 + d["pos"].z) * 0.04
			n2.visible = Game.is_visible_cell(n2.position)

# ---------------------------------------------------------------- Modelle

func _make_beast(kind: String, big: bool) -> Dictionary:
	if kind == "deer":
		return _make_deer(big)
	var d: Dictionary = _make_deer(false, kind)
	return d

func _make_deer(stag: bool, kind := "deer") -> Dictionary:
	var n = Node3D.new()
	var fur = Models.mat(Color(0.42, 0.27, 0.15), 0.0, 0.9)
	var belly = Models.mat(Color(0.75, 0.62, 0.48), 0.0, 0.9)
	if kind == "goat":
		fur = Models.mat(Color(0.78, 0.76, 0.7), 0.0, 0.95)
		belly = Models.mat(Color(0.9, 0.88, 0.82), 0.0, 0.95)
		stag = false
	elif kind == "boar":
		fur = Models.mat(Color(0.2, 0.16, 0.13), 0.0, 0.95)
		belly = Models.mat(Color(0.3, 0.24, 0.19), 0.0, 0.95)
		stag = false
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
	if kind == "goat":
		for sx in [-1, 1]:
			Models.box(neck, Vector3(0.04, 0.34, 0.04), Vector3(sx * 0.09, 0.78, 0.14), Models.mat(Color(0.3, 0.26, 0.2), 0.0, 0.9), Vector3(-0.9, 0, sx * 0.2))
		Models.box(neck, Vector3(0.07, 0.22, 0.07), Vector3(0, 0.38, 0.4), belly, Vector3(0.2, 0, 0))
		n.scale = Vector3.ONE * 0.72
	elif kind == "boar":
		for sx in [-1, 1]:
			Models.box(neck, Vector3(0.03, 0.03, 0.14), Vector3(sx * 0.07, 0.5, 0.56), Models.mat(Color(0.9, 0.88, 0.8), 0.0, 0.9))
		n.scale = Vector3(0.95, 0.72, 1.0)
	else:
		n.scale = Vector3.ONE * (1.15 if stag else 1.0)
	return {"node": n, "legs": legs, "neck": neck, "pos": Vector3.ZERO, "heading": rng.randf() * TAU, "walk": rng.randf() * 10.0, "graze": rng.randf() * 10.0}

func _make_bird(kind := "crow") -> Dictionary:
	var n = Node3D.new()
	var col := {"crow": Color(0.12, 0.11, 0.1), "gull": Color(0.92, 0.93, 0.94), "eagle": Color(0.3, 0.2, 0.12), "duck": Color(0.35, 0.28, 0.2)}
	var m = Models.mat(col.get(kind, Color(0.12, 0.11, 0.1)), 0.0, 0.8)
	Models.box(n, Vector3(0.14, 0.12, 0.45), Vector3.ZERO, m)
	Models.box(n, Vector3(0.1, 0.1, 0.12), Vector3(0, 0.03, 0.25), m)
	var wl = Node3D.new()
	var wr = Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	Models.box(wl, Vector3(0.55, 0.02, 0.22), Vector3(-0.3, 0, 0), m)
	Models.box(wr, Vector3(0.55, 0.02, 0.22), Vector3(0.3, 0, 0), m)
	n.scale = Vector3.ONE * (3.4 if kind == "eagle" else (1.3 if kind == "duck" else 1.6))
	return {"node": n, "wl": wl, "wr": wr}

# ---------------------------------------------------------------- Verhalten

func _physics_process(delta: float) -> void:
	if Game.terrain == null:
		return
	for h in herds:
		_update_herd(h, delta)
	for fl in flocks:
		_update_flock(fl, delta)
	_update_water(delta)

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
			tgt.x = clamp(tgt.x, -Game.HALF + 20.0, Game.HALF - 20.0)
			tgt.z = clamp(tgt.z, -Game.HALF + 20.0, Game.HALF - 20.0)
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
			fl["anchor"].x = clamp(fl["anchor"].x, -Game.HALF + 20.0, Game.HALF - 20.0)
			fl["anchor"].z = clamp(fl["anchor"].z, -Game.HALF + 20.0, Game.HALF - 20.0)
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
