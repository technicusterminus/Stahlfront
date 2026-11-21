extends Node3D
## Gebäude: Bau, Produktion, Abwehrwaffe, Superwaffe.

const Models = preload("res://scripts/models.gd")
const FX = preload("res://scripts/fx.gd")
const Weapons = preload("res://scripts/weapons.gd")

var is_unit = false
var is_building = true
var is_depot = false
var flying = false
var def: Dictionary
var owner_id = 0
var hp = 100.0
var max_hp = 100.0
var alive = true
var complete = false
var progress = 0.0
var cells: Array = []
var center_cell = Vector2i.ZERO
var radius = 3.0
var half = 3.0
var height = 4.0
var selected = false
var rank = 0

var queue: Array = []
var prod_t = 0.0
var rally = Vector3.ZERO
var has_rally = false

var weapon = null
var cd = 0.0
var scan_t = 0.0
var target = null
var burst_left = 0
var burst_t = 0.0
var burst_target = null

var super_t = 0.0
var super_ready = false
var _income_t = 0.0
var _dmg_fx = 0
var last_hit_t = -99.0

var model: Dictionary
var body: Node3D
var turret: Node3D
var spin: Node3D
var ring: MeshInstance3D
var muzzle_local = Vector3.ZERO
var _dust_t = 0.0
var scaffold: Node3D
var _service_state := -1
var _service_open_until := 0.0

func setup(d: Dictionary, pid: int, center: Vector2i, c: Array) -> void:
	def = d
	owner_id = pid
	center_cell = center
	cells = c
	max_hp = d["hp"]
	hp = max_hp * 0.1
	weapon = d["weapon"]
	half = float(d["size"])
	radius = half * 0.92
	model = Models.build_building(d, Game.players[pid]["color"])
	body = model["root"]
	add_child(body)
	turret = model["turret"]
	spin = model["spin"]
	muzzle_local = model["muzzle"]
	height = model["height"]
	body.scale = Vector3(1, 0.05, 1)
	scaffold = Models.build_construction(d, Game.players[pid]["color"], float(d["size"]) * 2.0 - 0.4, max(height, 3.0))
	add_child(scaffold)
	_make_ring()

func _make_ring() -> void:
	ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = half * 1.25
	tm.outer_radius = half * 1.32
	tm.rings = 4
	tm.ring_segments = 3
	ring.mesh = tm
	ring.rotation.y = PI / 4
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.35, 1.0, 0.45) if owner_id == Game.human else Color(1.0, 0.35, 0.3)
	m.no_depth_test = true
	ring.material_override = m
	ring.position.y = 0.4
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func set_selected(v: bool) -> void:
	selected = v
	ring.visible = v

func aim_point() -> Vector3:
	return position + Vector3(0, height * 0.5, 0)

func powered() -> bool:
	return Game.has_power(owner_id)

# ---------------------------------------------------------------- Bau

func construct(delta: float) -> void:
	if complete:
		return
	var step: float = delta / float(def["time"]) * Game.income_mult(owner_id)
	progress = min(1.0, progress + step)
	hp = min(max_hp, hp + max_hp * 0.9 * step)
	body.scale = Vector3(1, lerp(0.05, 1.0, progress), 1)
	if scaffold != null and scaffold.has_node("Orbit"):
		var orb: Node3D = scaffold.get_node("Orbit")
		orb.rotation.y += delta * 1.4
		if _dust_t <= 0.1:
			for dr in orb.get_children():
				FX.weld((dr as Node3D).global_position - Vector3(0, 0.6, 0))
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = 1.2
		FX.dust(position + Vector3(randf_range(-half, half), 0.5, randf_range(-half, half)), 1.0)
	if progress >= 1.0:
		finish(false)

func finish(instant: bool) -> void:
	complete = true
	progress = 1.0
	if instant:
		hp = max_hp
	body.scale = Vector3.ONE
	if scaffold != null:
		scaffold.queue_free()
		scaffold = null
	for sp in model["smoke"]:
		FX.smoke_column(body, sp, def["faction"] == "red")
	Game.recalc_power(owner_id)
	if def["role"] == "super":
		super_t = Defs.factions[def["faction"]]["super"]["charge"]
		if owner_id != Game.human and not Game.spectator:
			Game.notify("Warnung: Ein Gegner hat eine Superwaffe errichtet (%s)." % def["name"], Color(1, 0.4, 0.3))
	if not instant:
		Game.players[owner_id]["built"] += 1
		Game.notify_player(owner_id, "%s ist fertig." % def["name"], Color(0.6, 1.0, 0.7))
		if def["role"] == "supply":
			var u = Game.spawn_unit(Defs.harv_of(def["faction"]), owner_id, _exit_point())
			u.cmd_harvest()
		if def["role"] == "power" and owner_id == Game.human:
			Game.notify_player(owner_id, "Stromnetz: %d / %d" % [Game.players[owner_id]["power_prod"], Game.players[owner_id]["power_use"]])

func repair(delta: float) -> void:
	hp = min(max_hp, hp + max_hp * 0.035 * delta)

## Bau abbrechen (volle Rückerstattung) oder verkaufen (halbe).
func sell() -> void:
	if not alive:
		return
	var refund: float = def["cost"] * (1.0 if not complete else 0.5)
	Game.refund(owner_id, def, 1.0 if not complete else 0.5)
	for qid in queue:
		Game.refund(owner_id, Defs.units[qid])
	queue.clear()
	Game.notify_player(owner_id, "%s %s: +%d Credits" % [def["name"], "abgebrochen" if not complete else "verkauft", int(refund)], Color(0.9, 0.9, 0.6))
	_deconstruct()

## Rückbau: das Gerüst wächst wieder hoch, der Bau sinkt Stück für Stück ein, Funken und Staub – dann ist das Feld frei.
func _deconstruct() -> void:
	alive = false
	set_selected(false)
	Game.set_cells(cells, false)
	Game.set_occ(cells, false)
	Game.remove_object(self)
	Game.recalc_power(owner_id)
	if scaffold == null:
		scaffold = Models.build_construction(def, Game.players[owner_id]["color"], float(def["size"]) * 2.0 - 0.4, max(height, 3.0))
		add_child(scaffold)
	var dur: float = 2.6 + float(def["size"]) * 0.8
	var y0: float = body.scale.y
	var tw := create_tween()
	tw.tween_method(_decon_step.bind(y0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_decon_done)

func _decon_step(t: float, y0: float) -> void:
	body.scale = Vector3(1, max(0.03, lerp(y0, 0.05, t)), 1)
	body.position.y = -0.15 * t
	body.rotation.y = sin(t * PI) * 0.06
	if scaffold != null and scaffold.has_node("Orbit"):
		var orb: Node3D = scaffold.get_node("Orbit")
		orb.rotation.y -= 0.05 + 0.1 * t
		_dust_t -= 0.016
		if _dust_t <= 0.0:
			_dust_t = 0.35
			for dr in orb.get_children():
				FX.weld((dr as Node3D).global_position - Vector3(0, 0.6, 0))
			FX.dust(position + Vector3(randf_range(-half, half), 0.4, randf_range(-half, half)), 1.0 + 0.8 * t)

func _decon_done() -> void:
	FX.dust(position + Vector3(0, 0.6, 0), float(def["size"]) * 1.1)
	queue_free()

func _remove(explode: bool) -> void:
	alive = false
	set_selected(false)
	Game.set_cells(cells, false)
	Game.set_occ(cells, false)
	Game.remove_object(self)
	Game.recalc_power(owner_id)
	if explode:
		FX.explosion(position + Vector3(0, 1.5, 0), float(def["size"]) * 0.75)
		for i in 3:
			var off = Vector3(randf_range(-half, half), 1.0, randf_range(-half, half))
			var tw = get_tree().create_timer(0.25 * (i + 1), false)
			var p = position + off
			tw.timeout.connect(func(): FX.explosion(p, 1.2))
	queue_free()

# ---------------------------------------------------------------- Produktion

func can_queue(uid: String) -> String:
	if not complete:
		return "Gebäude ist noch im Bau"
	var ud: Dictionary = Defs.units[uid]
	var miss = Game.missing_prereq(ud, owner_id)
	if miss != "":
		return miss
	var why = Game.afford_why(owner_id, ud)
	if why != "":
		return why
	if queue.size() >= 9:
		return "Warteschlange ist voll"
	return ""

func queue_unit(uid: String) -> String:
	var why = can_queue(uid)
	if why != "":
		return why
	Game.pay(owner_id, Defs.units[uid])
	queue.append(uid)
	return ""

func cancel_unit(idx: int) -> void:
	if idx < 0 or idx >= queue.size():
		return
	Game.refund(owner_id, Defs.units[queue[idx]])
	queue.remove_at(idx)
	if idx == 0:
		prod_t = 0.0

func _exit_point() -> Vector3:
	var p = position + Vector3(0, 0, half + 1.6)
	var c = Game.nearest_free(Game.world_to_cell(p))
	return Game.cell_center(c)

func _spawn(uid: String) -> void:
	_service_open_until = Game.time + 1.1
	_spawn_one(uid, Vector3.ZERO)
	# Rote Allianz: Massenaushebung – Infanterie kommt paarweise
	if Defs.units[uid]["pair"]:
		_spawn_one(uid, Vector3(1.6, 0, 0.8))

func _spawn_one(uid: String, offset: Vector3) -> void:
	var ud: Dictionary = Defs.units[uid]
	var pos = (_exit_point() if not ud["flying"] else position) + offset
	if ud["naval"]:
		pos = Game.cell_center(Game.nearest_free(Game.world_to_cell(position), 12, true)) + offset
	var u = Game.spawn_unit(uid, owner_id, pos)
	u.heading = 0.0
	if owner_id == Game.human and not Game.spectator:
		Audio.sfx("ready", -2.0)
	if ud["naval"] and OS.get_cmdline_user_args().has("--verbose"):
		print("SHIP vom Stapel: ", uid, " P", owner_id, " t=", int(Game.time))
	if ud["role"] == "harvester":
		u.cmd_harvest()
	elif has_rally:
		u.cmd_move(rally + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), u.weapon != null)
	else:
		u.cmd_move(pos + Vector3(randf_range(-3, 3), 0, 4.0 + randf_range(0, 3)))

func prod_progress() -> float:
	if queue.is_empty():
		return 0.0
	return clamp(prod_t / float(Defs.units[queue[0]]["time"]), 0.0, 1.0)

# ---------------------------------------------------------------- Ablauf

func _physics_process(delta: float) -> void:
	if not alive or not complete or not Game.running:
		return
	if spin:
		spin.rotation.y += delta * 0.8
	if visible and model.has("anims"):
		_play_anims(delta)
	var pw = powered()
	if visible:
		_update_service_signal(delta, pw)
	if not queue.is_empty():
		var speed: float = (1.0 if pw else 0.5) * Game.income_mult(owner_id)
		prod_t += delta * speed
		if prod_t >= float(Defs.units[queue[0]]["time"]):
			var uid: String = queue.pop_front()
			prod_t = 0.0
			_spawn(uid)
	if weapon != null and pw:
		_defend(delta)
	if def["role"] == "super" and not super_ready:
		super_t -= delta * (1.0 if pw else 0.0)
		if super_t <= 0.0:
			super_ready = true
			Game.notify_player(owner_id, "%s ist bereit! Auswählen und Ziel anklicken." % def["name"], Color(1, 0.85, 0.3))
			if owner_id != Game.human and not Game.spectator:
				Game.notify("Warnung: Eine feindliche Superwaffe ist feuerbereit!", Color(1, 0.35, 0.3))
	if def["role"] == "tech" and def["faction"] == "shadow":
		_income_t += delta
		if _income_t >= 10.0:
			_income_t = 0.0
			Game.players[owner_id]["credits"] += 30.0

func _update_service_signal(delta: float, has_power: bool) -> void:
	var signal_data: Dictionary = model["service_signal"]
	var active := not queue.is_empty() or Game.time < _service_open_until
	if def["role"] == "super":
		active = super_ready
	model["work_motion"].advance(delta, has_power, active)
	var new_state := 2 if not has_power else (1 if active else 0)
	if new_state != _service_state:
		_service_state = new_state
		var lamp: MeshInstance3D = signal_data["lamp"]
		lamp.material_override = signal_data["materials"][new_state]
	var arm: Node3D = signal_data.get("arm")
	if arm != null:
		var opening := has_power and (Game.time < _service_open_until or prod_progress() > 0.87)
		arm.rotation.z = move_toward(arm.rotation.z, -1.32 if opening else 0.0, delta * 2.2)

## Leben im Gebäude: Lüfter, Blinklichter, Fahnen, Arbeiter, Kräne, Pressen.
func _play_anims(delta: float) -> void:
	var t = Game.time
	for a in model["anims"]:
		match a["t"]:
			"spin":
				a["n"].rotation.y += delta * a["s"]
			"spin_z":
				a["n"].rotation.z += delta * a["s"]
			"blink":
				a["n"].visible = fmod(t + a["o"], a["p"]) < a["p"] * 0.5
			"wave":
				var i = 0
				for s in a["segs"]:
					s.rotation.y = sin(t * 3.0 + a["o"] + i * 0.9) * (0.15 + i * 0.08) + (0.6 if i == 0 else 0.0)
					i += 1
			"walk":
				var n: Node3D = a["n"]
				var pts: Array = a["pts"]
				var target: Vector3 = pts[a["i"]]
				var d = target - n.position
				d.y = 0
				var step = a["s"] * delta
				if d.length() <= step:
					n.position = Vector3(target.x, n.position.y, target.z)
					a["i"] = (a["i"] + 1) % pts.size()
				else:
					n.position += d.normalized() * step
					n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), min(1.0, 6.0 * delta))
				if not a.get("vehicle", false):
					if not a.has("p"):
						var pn = {}
						for nm in ["LegL", "LegR", "ShinL", "ShinR", "ArmL", "ArmR", "ForeL", "ForeR"]:
							pn[nm] = n.find_child(nm, true, false)
						a["p"] = pn
					if n.has_meta("ap"):
						var apn: AnimationPlayer = n.get_meta("ap")
						if apn.current_animation != "Walk":
							apn.play("Walk")
						apn.speed_scale = clamp(a["s"] * 0.9, 0.6, 2.0)
					var pp: Dictionary = a["p"]
					var ph = t * a["s"] * 6.0
					var sw = sin(ph) * 0.6
					if pp["LegL"]:
						pp["LegL"].rotation.x = 0.1 + sw
						pp["LegR"].rotation.x = 0.1 - sw
					if pp["ShinL"]:
						# Knie beugt beim Vorschwingen des Beins (Standbein bleibt fast gestreckt)
						pp["ShinL"].rotation.x = 0.2 + max(-cos(ph), 0.0) * 1.1
						pp["ShinR"].rotation.x = 0.2 + max(cos(ph), 0.0) * 1.1
					if pp["ArmL"]:
						pp["ArmL"].rotation.x = -sw * 0.8
						pp["ArmR"].rotation.x = sw * 0.8
						pp["ForeL"].rotation.x = -0.35 - abs(sw) * 0.4
						pp["ForeR"].rotation.x = -0.35 - abs(sw) * 0.4
			"slide":
				var k = 0.5 + 0.5 * sin(t * a["s"])
				a["n"].position = (a["a"] as Vector3).lerp(a["b"], k)
			"bob":
				a["n"].position = a["base"] + Vector3(0, sin(t * a["s"]) * a["amp"], 0)
				a["n"].rotation.y += delta * 0.3
			"swing":
				a["n"].rotation.z = sin(t * a["s"]) * a["amp"]
			"sweep":
				a["n"].rotation.y = sin(t * a["s"]) * a["amp"]
			"weld":
				if fmod(t, a["p"]) < delta:
					FX.weld((a["n"] as Node3D).global_position)

func _defend(delta: float) -> void:
	cd -= delta
	scan_t -= delta
	if burst_left > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			burst_t = 0.18
			burst_left -= 1
			var t = burst_target
			if t != null and is_instance_valid(t) and t.alive:
				var mp: Vector3 = (turret.global_transform * muzzle_local) if turret else position + Vector3(0, height, 0)
				Weapons.fire(self, owner_id, weapon, mp, t, t.aim_point(), 1.0)
	var valid: bool = target != null and is_instance_valid(target) and target.alive and Game.flat_dist(position, target.position) - target.radius <= weapon["range"] + 1.0
	if not valid:
		target = null
		if scan_t <= 0.0:
			scan_t = 0.4
			target = Game.find_target(owner_id, position, weapon["range"], weapon["air"], weapon["ground"])
		return
	var a = atan2(target.position.x - position.x, target.position.z - position.z)
	var aimed = true
	if turret:
		turret.rotation.y = rotate_toward(turret.rotation.y, a, 3.5 * delta)
		aimed = abs(wrapf(turret.rotation.y - a, -PI, PI)) < 0.15
	if aimed and cd <= 0.0 and burst_left == 0:
		cd = weapon["rof"]
		burst_left = weapon["burst"]
		burst_t = 0.0
		burst_target = target

# ---------------------------------------------------------------- Schaden

func take_damage(amount: float, attacker_pid: int, attacker) -> void:
	if not alive:
		return
	hp -= amount
	last_hit_t = Game.time
	Game.on_damaged(self, attacker_pid)
	var frac = hp / max_hp
	if complete and frac < 0.5 and _dmg_fx == 0:
		_dmg_fx = 1
		FX.fire_burn(body, Vector3(randf_range(-half, half) * 0.5, height * 0.6, randf_range(-half, half) * 0.5))
	elif complete and frac < 0.25 and _dmg_fx == 1:
		_dmg_fx = 2
		FX.fire_burn(body, Vector3(randf_range(-half, half) * 0.5, height * 0.4, randf_range(-half, half) * 0.5))
		FX.smoke_column(body, Vector3(0, height, 0), true)
	if hp <= 0.0:
		Game.on_killed(self, attacker_pid, attacker)
		_remove(true)
