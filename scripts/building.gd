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
	Game.players[owner_id]["credits"] += refund
	for qid in queue:
		Game.players[owner_id]["credits"] += Defs.units[qid]["cost"]
	queue.clear()
	Game.notify_player(owner_id, "%s %s: +%d Credits" % [def["name"], "abgebrochen" if not complete else "verkauft", int(refund)], Color(0.9, 0.9, 0.6))
	FX.dust(position + Vector3(0, 1, 0), float(def["size"]) * 0.8)
	_remove(false)

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
	if Game.players[owner_id]["credits"] < ud["cost"]:
		return "Nicht genug Credits"
	if queue.size() >= 9:
		return "Warteschlange ist voll"
	return ""

func queue_unit(uid: String) -> String:
	var why = can_queue(uid)
	if why != "":
		return why
	Game.players[owner_id]["credits"] -= Defs.units[uid]["cost"]
	queue.append(uid)
	return ""

func cancel_unit(idx: int) -> void:
	if idx < 0 or idx >= queue.size():
		return
	Game.players[owner_id]["credits"] += Defs.units[queue[idx]]["cost"]
	queue.remove_at(idx)
	if idx == 0:
		prod_t = 0.0

func _exit_point() -> Vector3:
	var p = position + Vector3(0, 0, half + 1.6)
	var c = Game.nearest_free(Game.world_to_cell(p))
	return Game.cell_center(c)

func _spawn(uid: String) -> void:
	_spawn_one(uid, Vector3.ZERO)
	# Rote Allianz: Massenaushebung – Infanterie kommt paarweise
	if Defs.units[uid]["pair"]:
		_spawn_one(uid, Vector3(1.6, 0, 0.8))

func _spawn_one(uid: String, offset: Vector3) -> void:
	var ud: Dictionary = Defs.units[uid]
	var pos = (_exit_point() if not ud["flying"] else position) + offset
	var u = Game.spawn_unit(uid, owner_id, pos)
	u.heading = 0.0
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
	var pw = powered()
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
