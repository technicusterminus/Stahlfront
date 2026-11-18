extends Node3D
## Bewegliche Einheit: Infanterie, Fahrzeug oder Hubschrauber.

const Models = preload("res://scripts/models.gd")
const FX = preload("res://scripts/fx.gd")
const Weapons = preload("res://scripts/weapons.gd")

var is_unit = true
var is_building = false
var is_depot = false
var def: Dictionary
var owner_id = 0
var hp = 100.0
var max_hp = 100.0
var alive = true
var selected = false
var radius = 0.8
var flying = false
var weapon = null
var is_vehicle = true

var order = "idle"
var target = null
var dest = Vector3.ZERO
var path: Array = []
var guard_pos = Vector3.ZERO
var heading = 0.0
var speed_now = 0.0
var want = Vector3.ZERO
var tilt_n = Vector3.UP

var cd = 0.0
var scan_t = 0.0
var repath_t = 0.0
var burst_left = 0
var burst_t = 0.0
var burst_target = null
var burst_pos = Vector3.ZERO
var xp = 0.0
var rank = 0
var last_hit_t = -99.0
var stuck_t = 0.0
var horde = false
var _horde_t = 0.0
var _resume = false

var cargo = 0.0
var h_state = ""
var h_depot = null
var h_timer = 0.0
var h_home = null
var _home_t = 0.0
var build_target = null
var _weld_t = 0.0

var model: Dictionary
var body: Node3D
var turret: Node3D
var ring: MeshInstance3D
var muzzle_local = Vector3.ZERO
var _anim_t = 0.0
var _fly_cur = 0.0

# Fraktionsbesonderheiten
var _dust_t = 0.0
var _turret_rest = null
var _recoil_tw: Tween
var _flash_t = 0.0
var fixed_wing = false    # Flächenflieger: kann nicht schweben
var _bank = 0.0
var shield = 0.0          # Westbund: Energieschild
var max_shield = 0.0
var _shield_fx_t = 0.0
var stealthed = false     # Schattenfront: Tarnung
var _still_t = 0.0
var _last_fire_t = -99.0
var salvage = 0           # Schattenfront: Schrottbergung (0..3)
var aura = false          # Rote Allianz: Propaganda in Reichweite
var _aura_t = 0.0
var _stealth_shown = false

func setup(d: Dictionary, pid: int) -> void:
	def = d
	owner_id = pid
	max_hp = d["hp"]
	hp = max_hp
	flying = d["flying"]
	weapon = d["weapon"]
	is_vehicle = d["armor"] != "inf"
	var col: Color = Game.players[pid]["color"]
	model = Models.build_unit(d["model"], col, d["faction"])
	body = model["root"]
	body.scale = Vector3.ONE * float(d["scale"])
	add_child(body)
	turret = model["turret"]
	muzzle_local = model["muzzle"]
	radius = (1.6 if is_vehicle else 0.55) * float(d["scale"])
	if flying:
		radius = 2.0 if d["role"] != "combat" or weapon != null else 1.4
	fixed_wing = d["fixed_wing"]
	max_shield = d["shield"]
	shield = max_shield
	_make_ring()
	_anim_t = randf() * 10.0

func _make_ring() -> void:
	ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = radius * 1.0
	tm.outer_radius = radius * 1.14
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.35, 1.0, 0.45) if owner_id == Game.human else Color(1.0, 0.35, 0.3)
	m.no_depth_test = true
	m.render_priority = 1
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.15
	ring.visible = false
	add_child(ring)

func place_at(p: Vector3) -> void:
	position = Vector3(p.x, Game.terrain.ground_y(p.x, p.z), p.z)
	guard_pos = position
	dest = position

func set_selected(v: bool) -> void:
	selected = v
	if ring:
		ring.visible = v

func aim_point() -> Vector3:
	return position + Vector3(0, body.position.y + float(model["height"]) * 0.45 * float(def["scale"]), 0)

func muzzle_pos() -> Vector3:
	var n: Node3D = turret if turret != null else body
	return n.global_transform * muzzle_local

## Geschützrückstoß: nur das Rohr (samt Mündungsbremse) fährt zurück und schiebt sich wieder vor.
func _recoil() -> void:
	var br = model.get("barrel")
	if br == null or not visible:
		return
	if _turret_rest == null:
		_turret_rest = br.position
	if _recoil_tw != null and _recoil_tw.is_valid():
		_recoil_tw.kill()
	br.position = _turret_rest
	var depth = 0.38 * float(def["scale"])
	if weapon != null and weapon["type"] == "flak":
		depth = 0.1
	_recoil_tw = create_tween()
	_recoil_tw.tween_property(br, "position", _turret_rest + Vector3(0, 0, -depth), 0.05)
	_recoil_tw.tween_property(br, "position", _turret_rest, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## Aufleuchtende Schildblase bei Treffern (Westbund).
func _shield_flash() -> void:
	if Game.time < _flash_t or not visible:
		return
	_flash_t = Game.time + 0.18
	var s = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = max(radius * 1.35, 1.0)
	sm.height = sm.radius * 1.5
	sm.radial_segments = 20
	sm.rings = 10
	s.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.35, 0.8, 1.0, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = Vector3(0, body.position.y + float(model["height"]) * 0.4 * float(def["scale"]), 0)
	add_child(s)
	var tw = s.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)

func dmg_mult() -> float:
	return 1.0 + 0.2 * rank + 0.15 * salvage

## Ist die Einheit fuer einen Gegner an dieser Position sichtbar/angreifbar?
func detectable_from(p: Vector3) -> bool:
	return not stealthed or Game.flat_dist(position, p) < 7.0

## Kurzbeschreibung der aktiven Fraktionseffekte (fuer die Infoleiste).
func trait_text() -> String:
	var parts: Array = []
	if max_shield > 0.0:
		parts.append("Schild %d/%d" % [int(shield), int(max_shield)])
	if def["stealth"]:
		parts.append("getarnt" if stealthed else "Tarnung bei Stillstand")
	if def["salvage"]:
		parts.append("Schrottpanzerung %d/3" % salvage)
	if def["horde"] and horde:
		parts.append("Hordenbonus aktiv")
	if aura:
		parts.append("Propaganda: Heilung + Feuerrate")
	return " · ".join(parts)

func role() -> String:
	return def["role"]

# ---------------------------------------------------------------- Befehle

func cmd_move(p: Vector3, attack := false) -> void:
	order = "attackmove" if attack and weapon != null else "move"
	dest = p
	guard_pos = p
	target = null
	build_target = null
	stuck_t = 0.0
	_set_path(p)

func cmd_attack(t) -> void:
	if weapon == null or not can_target(t):
		cmd_move(t.position)
		return
	order = "attack"
	target = t
	build_target = null
	path.clear()
	repath_t = 0.0

func cmd_stop() -> void:
	order = "idle"
	target = null
	path.clear()
	guard_pos = position
	build_target = null

func cmd_harvest(dp = null) -> void:
	if role() != "harvester":
		return
	order = "harvest"
	if dp != null:
		h_depot = dp
	h_state = "to_base" if cargo > 0 and dp == null else "to_depot"
	path.clear()

func cmd_build(b) -> void:
	if role() != "dozer":
		return
	order = "build"
	build_target = b
	path.clear()
	repath_t = 0.0

func _set_path(p: Vector3) -> void:
	if flying:
		path = [p]
	else:
		path = Game.find_path(position, p)

func can_target(t) -> bool:
	if weapon == null or t == null or not is_instance_valid(t) or not t.alive or t.is_depot:
		return false
	if not Game.enemies(owner_id, t.owner_id):
		return false
	if t.flying:
		return weapon["air"]
	return weapon["ground"]

func status_text() -> String:
	match order:
		"move":
			return "Bewegt sich"
		"attackmove":
			return "Angriffsbewegung" if target == null else "Im Gefecht"
		"attack":
			return "Greift an"
		"harvest":
			match h_state:
				"loading":
					return "Lädt Nachschub"
				"to_base":
					return "Bringt Nachschub zur Basis (%d)" % int(cargo)
				_:
					return "Fährt zum Depot"
		"build":
			if build_target != null and is_instance_valid(build_target):
				return ("Baut " if not build_target.complete else "Repariert ") + String(build_target.def["name"])
			return "Baut"
	if target != null:
		return "Im Gefecht"
	return "Bereit"

# ---------------------------------------------------------------- Simulation

func _physics_process(delta: float) -> void:
	if not alive or not Game.running:
		return
	cd -= delta
	scan_t -= delta
	repath_t -= delta
	want = Vector3.ZERO
	_regen(delta)
	_do_burst(delta)
	match order:
		"idle":
			_do_idle(delta)
		"move":
			if _follow(delta):
				order = "idle"
				guard_pos = position
		"attackmove":
			_do_attackmove(delta)
		"attack":
			_do_attack(delta)
		"harvest":
			_do_harvest(delta)
		"build":
			_do_build(delta)
	_integrate(delta)
	_animate(delta)

func _regen(delta: float) -> void:
	# Westbund: Schild laedt nach 4 s ohne Treffer
	if max_shield > 0.0 and shield < max_shield and Game.time - last_hit_t > 4.0:
		shield = min(max_shield, shield + max_shield * 0.12 * delta)
	# Schattenfront: Tarnung bei Stillstand
	if def["stealth"]:
		if speed_now > 0.3 or Game.time - _last_fire_t < 3.0:
			_still_t = 0.0
		else:
			_still_t += delta
		_set_stealth(_still_t > 2.0)
	# Rote Allianz: Propaganda-Aura
	if Game.time > _aura_t:
		_aura_t = Game.time + 1.0
		aura = false
		for b in Game.buildings:
			if b.owner_id == owner_id and b.alive and b.complete and b.def["aura"] > 0.0 and Game.has_power(owner_id) \
					and Game.flat_dist(b.position, position) < b.def["aura"]:
				aura = true
				break
	if hp >= max_hp:
		return
	var rate = 0.0
	if rank >= 2:
		rate = 0.01
	if def["faction"] == "shadow" and is_vehicle:
		rate = max(rate, 0.008)
	if aura:
		rate = max(rate, 0.02)
	if rate > 0.0 and (Game.time - last_hit_t > 6.0 or aura):
		hp = min(max_hp, hp + max_hp * rate * delta)

func _set_stealth(v: bool) -> void:
	if v == stealthed:
		return
	stealthed = v
	# Eigene getarnte Einheiten halbdurchsichtig zeigen
	var tr = 0.55 if v else 0.0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = tr

func _follow(delta: float) -> bool:
	if fixed_wing:
		return _fixed_follow(delta)
	if path.is_empty():
		return true
	var p: Vector3 = path[0]
	var d = Game.flat_dist(position, p)
	var last = path.size() == 1
	if d < (1.0 if last else 2.2):
		path.pop_front()
		if path.is_empty():
			return true
		p = path[0]
		last = path.size() == 1
		d = Game.flat_dist(position, p)
	var dir = Vector3(p.x - position.x, 0, p.z - position.z).normalized()
	var spd: float = def["speed"]
	if last and d < 3.0:
		spd *= max(d / 3.0, 0.35)
	want = dir * spd
	# Feststecken erkennen
	if speed_now < 0.4:
		stuck_t += delta
		if stuck_t > 1.4:
			stuck_t = 0.0
			var goal: Vector3 = path[path.size() - 1]
			if Game.flat_dist(position, goal) < 5.0 + radius * 2.0:
				path.clear()
				return true
			_set_path(goal)
	else:
		stuck_t = max(stuck_t - delta, 0.0)
	return false

func _scan_range() -> float:
	return max(weapon["range"], def["sight"] * 0.9)

func _scan() -> void:
	if scan_t > 0.0:
		return
	scan_t = 0.35 + randf() * 0.15
	var t = Game.find_target(owner_id, position, _scan_range(), weapon["air"], weapon["ground"], weapon["min_range"])
	if t != null:
		target = t

func _valid_target() -> bool:
	return target != null and is_instance_valid(target) and target.alive and can_target(target)

func _do_idle(delta: float) -> void:
	if weapon == null:
		return
	if _valid_target():
		if Game.flat_dist(position, guard_pos) > def["sight"] * 1.6 and not flying:
			target = null
			_set_path(guard_pos)
		else:
			_engage(target, delta)
			return
	else:
		target = null
		_scan()
	if target == null and not path.is_empty():
		_follow(delta)

func _do_attackmove(delta: float) -> void:
	if _valid_target():
		_engage(target, delta)
		_resume = true
		return
	target = null
	_scan()
	if target != null:
		return
	if _resume:
		_resume = false
		_set_path(dest)
	if _follow(delta):
		order = "idle"
		guard_pos = position

func _do_attack(delta: float) -> void:
	if not _valid_target():
		target = null
		order = "idle"
		guard_pos = position
		path.clear()
		return
	_engage(target, delta)

func _engage(t, delta: float) -> void:
	if fixed_wing:
		var dd = Game.flat_dist(position, t.position)
		var ang = atan2(t.position.x - position.x, t.position.z - position.z)
		var df = abs(wrapf(heading - ang, -PI, PI))
		var bomber = weapon["type"] == "bomb"
		if cd <= 0.0 and burst_left == 0 and dd <= weapon["range"] and df < (0.7 if bomber else 0.32):
			_fire(t)
		return
	var d = Game.flat_dist(position, t.position) - t.radius
	if d > weapon["range"]:
		if repath_t <= 0.0 or path.is_empty():
			repath_t = 1.0
			_set_path(t.position)
		_follow(delta)
	else:
		path.clear()
		if weapon["type"] == "demolition":
			_detonate()
			return
		if _aim(t.position, delta) and cd <= 0.0 and burst_left == 0 and d >= weapon["min_range"] - 1.0:
			_fire(t)

## Sprengwagen: Explosion an Ort und Stelle.
func _detonate() -> void:
	if not alive:
		return
	var p = position + Vector3(0, 1.0, 0)
	FX.explosion(p, 4.0)
	FX.ring(position, Color(1.0, 0.6, 0.25), weapon["splash"] * 1.4, 0.7)
	Game.damage_area(position, weapon["splash"], weapon["dmg"] * dmg_mult(), "demolition", owner_id, self)
	die(-1, null)

func _aim(p: Vector3, delta: float) -> bool:
	var a = atan2(p.x - position.x, p.z - position.z)
	if turret != null:
		var local = wrapf(a - heading, -PI, PI)
		turret.rotation.y = rotate_toward(turret.rotation.y, local, 4.5 * delta)
		return abs(wrapf(turret.rotation.y - local, -PI, PI)) < 0.12
	var turn = 6.0 if not is_vehicle or flying else 2.6
	heading = rotate_toward(heading, a, turn * delta)
	return abs(wrapf(heading - a, -PI, PI)) < 0.15

func _horde_bonus() -> bool:
	if not def["horde"]:
		return false
	if Game.time > _horde_t:
		_horde_t = Game.time + 1.0
		var n = 0
		for o in Game.units_near(position, 7.0):
			if o != self and o.owner_id == owner_id and o.def["horde"]:
				n += 1
		horde = n >= 4
	return horde

func _fire(t) -> void:
	burst_left = weapon["burst"]
	burst_t = 0.0
	burst_target = t
	burst_pos = t.aim_point() if not t.is_building else t.position + Vector3(0, 1.5, 0)
	if weapon["type"] == "artillery":
		burst_pos = t.position
	cd = weapon["rof"] * (0.75 if _horde_bonus() else 1.0) * (0.85 if aura else 1.0)
	_last_fire_t = Game.time
	_set_stealth(false)
	_still_t = 0.0

func _do_burst(delta: float) -> void:
	if burst_left <= 0:
		return
	burst_t -= delta
	if burst_t > 0.0:
		return
	burst_t = 0.16
	burst_left -= 1
	var t = burst_target
	var tp = burst_pos
	if t != null and is_instance_valid(t) and t.alive and weapon["type"] != "artillery":
		tp = t.aim_point() if not t.is_building else t.position + Vector3(0, 1.5, 0)
	elif weapon["type"] == "artillery":
		tp = burst_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	Weapons.fire(self, owner_id, weapon, muzzle_pos(), t, tp, dmg_mult())
	_recoil()

# ---------------------------------------------------------------- Sammeln

func _nearest_depot():
	var best = null
	var bd = 1e9
	for dp in Game.depots:
		if dp.supply <= 0.0:
			continue
		var d = Game.flat_dist(position, dp.position)
		# Nicht ins Feindgebiet: Depots nahe feindlicher Abwehr meiden waere schoen, hier zaehlt Distanz
		if d < bd:
			bd = d
			best = dp
	return best

func _nearest_home():
	var best = null
	var bd = 1e9
	for b in Game.buildings:
		if b.owner_id == owner_id and b.alive and b.complete and b.def["role"] == "supply":
			var d = Game.flat_dist(position, b.position)
			if d < bd:
				bd = d
				best = b
	return best

func _do_harvest(delta: float) -> void:
	match h_state:
		"to_depot":
			if h_depot == null or not is_instance_valid(h_depot) or h_depot.supply <= 0.0:
				h_depot = _nearest_depot()
				path.clear()
				if h_depot == null:
					order = "idle"
					Game.notify_player(owner_id, "Alle Nachschubdepots sind leer.", Color(1, 0.8, 0.4))
					return
			if Game.flat_dist(position, h_depot.position) < 4.6:
				h_state = "loading"
				h_timer = 2.4
				path.clear()
			else:
				if path.is_empty():
					_set_path(h_depot.position)
				_follow(delta)
		"loading":
			h_timer -= delta
			if h_timer <= 0.0:
				cargo = h_depot.take(def["cargo"]) if is_instance_valid(h_depot) else 0.0
				h_state = "to_base" if cargo > 0.0 else "to_depot"
				path.clear()
		"to_base":
			if h_home == null or not is_instance_valid(h_home) or not h_home.alive:
				if Game.time < _home_t:
					return
				_home_t = Game.time + 2.0
				h_home = _nearest_home()
				path.clear()
				if h_home == null:
					return
			if Game.flat_dist(position, h_home.position) < h_home.radius + 3.2:
				var gain = cargo * Game.income_mult(owner_id)
				Game.players[owner_id]["credits"] += gain
				Game.players[owner_id]["income"] += gain
				if owner_id == Game.human:
					FX.sparkle(position + Vector3(0, 2, 0), Color(1, 0.85, 0.3))
				cargo = 0.0
				h_state = "to_depot"
				path.clear()
			else:
				if path.is_empty():
					_set_path(h_home.position)
				_follow(delta)
		_:
			h_state = "to_depot"

# ---------------------------------------------------------------- Bauen

func _do_build(delta: float) -> void:
	var b = build_target
	if b == null or not is_instance_valid(b) or not b.alive or (b.complete and b.hp >= b.max_hp):
		build_target = null
		order = "idle"
		guard_pos = position
		path.clear()
		return
	var d = Game.flat_dist(position, b.position) - b.radius
	if d > 2.4:
		if path.is_empty() or repath_t <= 0.0:
			repath_t = 2.5
			_set_path(b.position)
		_follow(delta)
	else:
		path.clear()
		_aim(b.position, delta)
		if b.complete:
			b.repair(delta)
		else:
			b.construct(delta)
		_weld_t -= delta
		if _weld_t <= 0.0:
			_weld_t = 0.35
			var wp = position.lerp(b.position, 0.5) + Vector3(randf_range(-1, 1), 1.2 + randf() * 1.5, randf_range(-1, 1))
			FX.weld(wp)

# ---------------------------------------------------------------- Bewegung

## Flächenflieger: Ziel, Wegpunkt oder Wachpunkt anfliegen; Wendekreis statt Schweben.
func _fixed_follow(_delta: float) -> bool:
	if path.is_empty():
		return true
	if Game.flat_dist(position, path[0]) < 9.0:
		path.pop_front()
		return path.is_empty()
	return false

func _fly_fixed(delta: float) -> void:
	var goal = guard_pos
	if _valid_target():
		goal = target.position
	elif not path.is_empty():
		goal = path[0]
	if abs(position.x) > 104.0 or abs(position.z) > 104.0:
		goal = Vector3.ZERO
	var a = atan2(goal.x - position.x, goal.z - position.z)
	var diff = wrapf(a - heading, -PI, PI)
	var tr = float(def["turn"])
	heading += clamp(diff, -tr * delta, tr * delta)
	_bank = lerp(_bank, clamp(diff * 1.2, -1.0, 1.0), min(1.0, 4.0 * delta))
	var fwd = Vector3(sin(heading), 0, cos(heading))
	var np = position + fwd * float(def["speed"]) * delta
	np.x = clamp(np.x, -112.0, 112.0)
	np.z = clamp(np.z, -112.0, 112.0)
	np.y = Game.terrain.ground_y(np.x, np.z)
	speed_now = float(def["speed"])
	position = np

func _integrate(delta: float) -> void:
	if fixed_wing:
		_fly_fixed(delta)
		return
	var sep = Vector3.ZERO
	for o in Game.units_near(position, radius + 2.6):
		if o == self or o.flying != flying:
			continue
		var dv = Vector3(position.x - o.position.x, 0, position.z - o.position.z)
		var dist = dv.length()
		var minsep: float = (radius + o.radius) * (0.85 if not flying else 1.2)
		if dist < minsep:
			if dist < 0.01:
				dv = Vector3(randf() - 0.5, 0, randf() - 0.5)
				dist = 0.01
			sep += dv / dist * (minsep - dist)
	var v: Vector3
	if is_vehicle and not flying:
		if want.length() > 0.1:
			var th = atan2(want.x, want.z)
			var diff = wrapf(th - heading, -PI, PI)
			var turn = 3.2 if def["scale"] < 1.3 else 2.0
			heading += clamp(diff, -turn * delta, turn * delta)
			var fwd = Vector3(sin(heading), 0, cos(heading))
			var f: float = clamp(cos(diff), 0.0, 1.0) if abs(diff) < 1.3 else 0.0
			v = fwd * want.length() * f
		else:
			v = Vector3.ZERO
		v += sep * 3.0
	else:
		if want.length() > 0.1:
			heading = lerp_angle(heading, atan2(want.x, want.z), min(1.0, (5.0 if flying else 12.0) * delta))
		v = want + sep * 3.0
	var np = position + v * delta
	if not flying:
		var cur_c = Game.world_to_cell(position)
		if not Game.is_free(cur_c):
			var fc = Game.nearest_free(cur_c)
			var tgt = Game.cell_center(fc)
			np = position + Vector3(tgt.x - position.x, 0, tgt.z - position.z).normalized() * 6.0 * delta
		elif not Game.is_free(Game.world_to_cell(np)):
			var npx = Vector3(np.x, position.y, position.z)
			var npz = Vector3(position.x, position.y, np.z)
			if Game.is_free(Game.world_to_cell(npx)):
				np = npx
			elif Game.is_free(Game.world_to_cell(npz)):
				np = npz
			else:
				np = position
	np.x = clamp(np.x, -112.0, 112.0)
	np.z = clamp(np.z, -112.0, 112.0)
	np.y = Game.terrain.ground_y(np.x, np.z)
	speed_now = Game.flat_dist(np, position) / max(delta, 0.0001)
	position = np

func _animate(delta: float) -> void:
	_anim_t += delta
	# Staubfahne hinter fahrenden Bodenfahrzeugen
	if is_vehicle and not flying and speed_now > 1.2 and visible:
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.32
			FX.dust(position - Vector3(sin(heading), 0, cos(heading)) * 1.8 + Vector3(0, 0.15, 0), 0.4)
	var fwd = Vector3(sin(heading), 0, cos(heading))
	if is_vehicle and not flying:
		var n: Vector3 = Game.terrain.normal_at(position.x, position.z)
		tilt_n = tilt_n.lerp(n, min(1.0, 6.0 * delta)).normalized()
		var f = (fwd - tilt_n * fwd.dot(tilt_n)).normalized()
		transform.basis = Basis(tilt_n.cross(f).normalized(), tilt_n, f)
	else:
		transform.basis = Basis(Vector3.UP, heading)
	if flying:
		var target_h = (13.0 if fixed_wing else (9.0 if weapon != null else 6.0)) + sin(_anim_t * 1.3) * 0.3
		_fly_cur = lerp(_fly_cur, target_h, min(1.0, 1.5 * delta))
		body.position.y = _fly_cur
		body.rotation.x = clamp(speed_now / def["speed"], 0.0, 1.0) * (0.0 if fixed_wing else 0.18)
		if fixed_wing:
			body.rotation.z = -_bank * 0.7
			var prop = model.get("prop")
			if prop:
				prop.rotation.z += 45.0 * delta
		var rot: Node3D = model["rotor"]
		if rot:
			rot.rotation.y += 28.0 * delta
		var tr = model.get("tail_rotor")
		if tr:
			tr.rotation.x += 30.0 * delta
	elif not is_vehicle:
		var ap = model.get("anim")
		if ap != null:
			# Animierter Soldat: Gehen, Schießen oder Stehen
			var want_anim = "Idle"
			if speed_now > 0.4:
				want_anim = "Walk"
			elif Game.time - _last_fire_t < 0.5 and ap.has_animation("Shoot"):
				want_anim = "Shoot"
			if ap.current_animation != want_anim:
				ap.play(want_anim, 0.15)
			if want_anim == "Walk":
				ap.speed_scale = clamp(speed_now / 4.0, 0.6, 1.6)
			else:
				ap.speed_scale = 1.0
			if want_anim == "Shoot" and Game.time - _last_fire_t < 0.05:
				ap.seek(0.0, true)
		elif speed_now > 0.4:
			body.position.y = abs(sin(_anim_t * 9.0)) * 0.1
		else:
			body.position.y = 0.0

# ---------------------------------------------------------------- Schaden

func take_damage(amount: float, attacker_pid: int, attacker) -> void:
	if not alive:
		return
	if shield > 0.0:
		var absorbed = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_shield_flash()
		if Game.time > _shield_fx_t:
			_shield_fx_t = Game.time + 0.4
			FX.sparkle(aim_point(), Color(0.4, 0.85, 1.0))
	hp -= amount
	last_hit_t = Game.time
	Game.on_damaged(self, attacker_pid)
	if weapon != null and (order == "idle" or (order == "attackmove" and target == null)) and attacker != null and is_instance_valid(attacker) and can_target(attacker):
		target = attacker
	if hp <= 0.0:
		die(attacker_pid, attacker)

## Schattenfront: Wrackteile verbauen (sichtbare Zusatzpanzerung).
func add_salvage() -> void:
	if not def["salvage"] or salvage >= 3:
		return
	salvage += 1
	max_hp *= 1.1
	hp = min(max_hp, hp + max_hp * 0.25)
	var m = Models.mat(Color(0.32, 0.27, 0.22), 0.6, 0.75)
	var s = salvage
	Models.box(body, Vector3(0.7, 0.5, 1.4), Vector3(-1.05 if s % 2 == 1 else 1.05, 1.0, -0.4 + s * 0.3), m, Vector3(0.1 * s, 0.2, 0.15))
	if s == 3:
		Models.box(body, Vector3(1.8, 0.12, 0.6), Vector3(0, 1.0, 2.2), m, Vector3(-0.4, 0, 0))
	FX.weld(aim_point())
	if owner_id == Game.human:
		Game.notify_player(owner_id, "%s hat Wrackteile verbaut (Stufe %d/3)." % [def["name"], salvage], Color(0.95, 0.75, 0.4))

func gain_xp(amount: float) -> void:
	if def["faction"] == "red":
		amount *= 1.5
	xp += amount
	var base: float = max(def["cost"], 100)
	var thresholds = [base * 1.0, base * 3.0, base * 6.0]
	var r = 0
	for th in thresholds:
		if xp >= th:
			r += 1
	if r > rank:
		rank = r
		max_hp *= 1.1
		hp = min(max_hp, hp + max_hp * 0.3)
		if owner_id == Game.human:
			FX.sparkle(position + Vector3(0, 2, 0), Color(1, 0.85, 0.2))
			Game.notify_player(owner_id, "%s ist jetzt %s." % [def["name"], Defs.RANK_NAMES[rank]], Color(1, 0.85, 0.3))

func die(killer_pid: int, killer) -> void:
	if not alive:
		return
	alive = false
	set_selected(false)
	Game.remove_object(self)
	Game.on_killed(self, killer_pid, killer)
	var ap = aim_point()
	if is_vehicle:
		var size: float = (1.3 if not flying else 1.5) * float(def["scale"])
		FX.explosion(ap, size)
		_make_wreck()
	else:
		FX.impact(ap, Color(0.8, 0.2, 0.15))
		_make_corpse()
	queue_free()

func _make_wreck() -> void:
	var wm = StandardMaterial3D.new()
	wm.albedo_color = Color(0.07, 0.065, 0.06)
	wm.roughness = 1.0
	var b = body
	var gt = b.global_transform
	remove_child(b)
	Game.fx_root.add_child(b)
	b.global_transform = gt
	_darken(b, wm)
	var tw = b.create_tween()
	if flying:
		var gy: float = Game.terrain.ground_y(b.global_position.x, b.global_position.z)
		tw.tween_property(b, "global_position:y", gy, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(b, "rotation:z", randf_range(-1.0, 1.0), 1.0)
		tw.tween_callback(func(): FX.explosion(b.global_position, 1.2))
	if Game.is_visible_cell(b.global_position):
		FX.fire_burn(b, Vector3(0, 1.0, 0))
	tw.tween_interval(10.0)
	tw.tween_property(b, "position:y", -2.5, 4.0).as_relative()
	tw.tween_callback(b.queue_free)

func _make_corpse() -> void:
	var b = body
	var gt = b.global_transform
	remove_child(b)
	Game.fx_root.add_child(b)
	b.global_transform = gt
	var tw = b.create_tween()
	var ap = model.get("anim")
	if ap != null and ap.has_animation("Die"):
		ap.speed_scale = 1.0
		ap.play("Die")
		tw.tween_interval(0.8)
	else:
		tw.tween_property(b, "rotation:x", -PI / 2 * 0.95, 0.4).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(b, "position:y", b.position.y + 0.2, 0.4)
	tw.tween_interval(5.0)
	tw.tween_property(b, "position:y", -1.5, 2.0).as_relative()
	tw.tween_callback(b.queue_free)

func _darken(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_darken(c, m)
