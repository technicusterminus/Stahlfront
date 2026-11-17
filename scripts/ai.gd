extends Node
## Computergegner: Basisbau, Wirtschaft, Produktion, Angriffswellen, Fähigkeiten, Superwaffe.

var pid = 0
var faction = ""
var order_list: Array = []
var think_t = 1.0
var wave = 0
var next_attack = 0.0
var attackers: Array = []
var rng = RandomNumberGenerator.new()
var hq_pos = Vector3.ZERO

func setup(p: int) -> void:
	pid = p
	faction = Game.faction_of(p)
	rng.randomize()
	var base = ["supply", "power", "barracks", "power", "factory", "defense", "power", "airfield", "tech", "power", "defense", "supply", "power", "super", "defense", "power", "defense"]
	for r in base:
		var id: String = faction + "_" + r
		if Defs.buildings.has(id):
			order_list.append(r)
	if Game.difficulty == 0:
		order_list.erase("super")
	next_attack = [420.0, 300.0, 220.0][Game.difficulty]
	hq_pos = Game.players[p]["start"]

func _physics_process(delta: float) -> void:
	if not Game.running or Game.game_over:
		return
	var p: Dictionary = Game.players[pid]
	if not p["alive"]:
		return
	think_t -= delta
	if think_t > 0.0:
		return
	think_t = 1.0 + rng.randf() * 0.3
	var hq = _first_building("hq")
	if hq != null:
		hq_pos = hq.position
	_economy()
	_construction()
	_production()
	_military()
	_powers()
	_superweapon()

# ---------------------------------------------------------------- Hilfen

func _mine_units() -> Array:
	return Game.units.filter(func(u): return u.owner_id == pid and u.alive)

func _mine_buildings() -> Array:
	return Game.buildings.filter(func(b): return b.owner_id == pid and b.alive)

func _first_building(role: String):
	for b in Game.buildings:
		if b.owner_id == pid and b.alive and b.complete and b.def["role"] == role:
			return b
	return null

func _count_role(role: String, include_incomplete := true) -> int:
	var n = 0
	for b in Game.buildings:
		if b.owner_id == pid and b.alive and b.def["role"] == role and (include_incomplete or b.complete):
			n += 1
	return n

func _credits() -> float:
	return Game.players[pid]["credits"]

# ---------------------------------------------------------------- Wirtschaft

func _economy() -> void:
	var harv = 0
	for u in _mine_units():
		if u.def["role"] == "harvester":
			harv += 1
			if u.order == "idle":
				u.cmd_harvest()
	var supplies = _count_role("supply", false)
	var want: int = min(supplies * (2 if Game.difficulty < 2 else 3), 6)
	if harv < want:
		var s = _first_building("supply")
		if s != null and s.queue.is_empty():
			s.queue_unit(Defs.harv_of(faction))

# ---------------------------------------------------------------- Bauen

func _next_role() -> String:
	var p: Dictionary = Game.players[pid]
	if Defs.factions[faction]["uses_power"] and p["power_use"] > p["power_prod"] - 1 and _count_role("power") <= _count_role("power", false):
		if _count_role("barracks") > 0 or p["power_use"] > p["power_prod"]:
			return "power"
	var have = {}
	for r in order_list:
		have[r] = have.get(r, 0) + 1
		if _count_role(r) < have[r]:
			return r
	return ""

func _construction() -> void:
	var dozers: Array = _mine_units().filter(func(u): return u.def["role"] == "dozer")
	if dozers.size() < (1 if Game.difficulty == 0 else 2):
		var hq = _first_building("hq")
		if hq != null and hq.queue.is_empty() and _credits() >= Defs.units[Defs.dozer_of(faction)]["cost"]:
			hq.queue_unit(Defs.dozer_of(faction))
	if dozers.is_empty():
		return
	# Unfertige oder beschädigte Gebäude betreuen
	for b in _mine_buildings():
		if not b.complete or b.hp < b.max_hp * 0.6:
			var busy = false
			for d in dozers:
				if d.order == "build" and d.build_target == b:
					busy = true
			if not busy:
				for d in dozers:
					if d.order != "build":
						d.cmd_build(b)
						break
	var idle: Array = dozers.filter(func(u): return u.order != "build")
	if idle.is_empty():
		return
	var role = _next_role()
	if role == "":
		return
	var id: String = faction + "_" + role
	var d: Dictionary = Defs.buildings[id]
	if Game.missing_prereq(d, pid) != "":
		return
	if _credits() < d["cost"]:
		return
	var site = _find_site(id, role)
	if site == null:
		return
	Game.players[pid]["credits"] -= d["cost"]
	var b = Game.spawn_building(id, pid, site, false)
	idle[0].cmd_build(b)

func _find_site(id: String, role: String):
	var d: Dictionary = Defs.buildings[id]
	var center = hq_pos
	if role == "supply":
		var best = null
		var bd = 1e9
		for dp in Game.depots:
			if dp.supply <= 0:
				continue
			var dd = Game.flat_dist(dp.position, hq_pos)
			if dd < bd and (dd < 45.0 or _count_role("supply") > 0):
				# Zweites Zentrum: anderes Depot
				var taken = false
				for b in _mine_buildings():
					if b.def["role"] == "supply" and Game.flat_dist(b.position, dp.position) < 16.0:
						taken = true
				if not taken:
					bd = dd
					best = dp
		if best != null:
			center = best.position.lerp(hq_pos, 0.25)
	var toward = (Vector3.ZERO - hq_pos).normalized()
	for ring in range(4, 22):
		var r = ring * 2.2 if role != "supply" else 6.0 + ring * 1.2
		for k in 10:
			var a = rng.randf() * TAU
			var p = center + Vector3(cos(a), 0, sin(a)) * r
			if role == "defense":
				p = center + toward * (14.0 + ring * 1.5) + Vector3(cos(a), 0, sin(a)) * 6.0
			var c = Game.world_to_cell(p)
			if Game.can_place(id, c, pid) != "":
				continue
			# Freiraum für Wege lassen
			var ok = true
			for fc in Game.footprint(c, int(d["size"]) + 2):
				if not Game.is_free(fc):
					ok = false
					break
			if ok:
				return c
	return null

# ---------------------------------------------------------------- Produktion

func _production() -> void:
	var next = _next_role()
	var reserve = 0.0
	if next != "":
		reserve = float(Defs.buildings[faction + "_" + next]["cost"]) * 0.6
	var enemy_air = false
	for u in Game.units:
		if u.flying and Game.enemies(pid, u.owner_id):
			enemy_air = true
			break
	for b in _mine_buildings():
		if not b.complete or b.def["role"] in ["hq", "supply"]:
			continue
		if b.def["produces"].is_empty() or b.queue.size() >= 2:
			continue
		var options: Array = []
		for uid in b.def["produces"]:
			var ud: Dictionary = Defs.units[uid]
			if Game.missing_prereq(ud, pid) != "":
				continue
			var wgt = 3.0
			var w = ud["weapon"]
			if w == null:
				# Unbewaffnete Aufklaerer: hoechstens zwei
				var have = _mine_units().filter(func(u): return u.def["id"] == uid).size()
				if have >= 2:
					continue
				wgt = 0.4
			elif w["type"] == "demolition":
				wgt = 1.0
			if w != null and w["type"] == "flak":
				wgt = 3.0 if enemy_air else 0.6
			if w != null and w["type"] == "artillery":
				wgt = 1.2
			if ud["cost"] >= 1500:
				wgt = 1.5
			options.append([uid, wgt])
		if options.is_empty():
			continue
		var total = 0.0
		for o in options:
			total += o[1]
		var roll = rng.randf() * total
		var pick: String = options[0][0]
		for o in options:
			roll -= o[1]
			if roll <= 0.0:
				pick = o[0]
				break
		if _credits() - float(Defs.units[pick]["cost"]) >= reserve:
			b.queue_unit(pick)

# ---------------------------------------------------------------- Militär

func _army() -> Array:
	return _mine_units().filter(func(u): return u.def["role"] == "combat")

func _enemy_target():
	var best = null
	var bd = 1e9
	for b in Game.buildings:
		if b.alive and Game.enemies(pid, b.owner_id):
			var d = Game.flat_dist(b.position, hq_pos)
			if d < bd:
				bd = d
				best = b
	if best == null:
		for u in Game.units:
			if u.alive and Game.enemies(pid, u.owner_id):
				var d = Game.flat_dist(u.position, hq_pos)
				if d < bd:
					bd = d
					best = u
	return best

func _military() -> void:
	var p: Dictionary = Game.players[pid]
	var army = _army()
	attackers = attackers.filter(func(u): return is_instance_valid(u) and u.alive)
	# Verteidigung
	if Game.time - float(p.get("attacked_at", -99.0)) < 8.0:
		var ap: Vector3 = p["attacked_pos"]
		if Game.flat_dist(ap, hq_pos) < 55.0:
			for u in army:
				if not attackers.has(u) and u.order == "idle" and Game.flat_dist(u.position, ap) < 70.0:
					u.cmd_move(ap, true)
	# Angriffswelle
	var home: Array = army.filter(func(u): return not attackers.has(u))
	var need: int = [5, 7, 9][Game.difficulty] + min(wave * 2, 14)
	if Game.time >= next_attack and home.size() >= need:
		var t = _enemy_target()
		if t != null:
			wave += 1
			next_attack = Game.time + [150.0, 110.0, 80.0][Game.difficulty]
			for u in home:
				attackers.append(u)
				u.cmd_move(t.position, true)
	# Angreifer, die nichts mehr zu tun haben, zum nächsten Ziel schicken
	for u in attackers:
		if u.order == "idle" and u.target == null:
			var best = null
			var bd = 1e9
			for b in Game.buildings:
				if b.alive and Game.enemies(pid, b.owner_id):
					var d = Game.flat_dist(b.position, u.position)
					if d < bd:
						bd = d
						best = b
			if best != null:
				u.cmd_move(best.position, true)
	# Sammelpunkt vor der Basis
	for u in home:
		if u.order == "idle" and Game.flat_dist(u.position, hq_pos) > 50.0 and u.target == null:
			u.cmd_move(hq_pos + (Vector3.ZERO - hq_pos).normalized() * 22.0, true)

# ---------------------------------------------------------------- Fähigkeiten

func _powers() -> void:
	var p: Dictionary = Game.players[pid]
	var f: Dictionary = Defs.factions[faction]
	for pw in f["powers"]:
		if p["points"] > 0 and not p["unlocked"].has(pw["id"]):
			Game.powers.unlock(pid, pw)
	if Game.difficulty == 0 and rng.randf() < 0.5:
		return
	for pw in f["powers"]:
		if Game.powers.why_not(pid, pw) != "":
			continue
		match pw["id"]:
			"cash":
				Game.powers.use(pid, pw, Vector3.ZERO)
			"heal_all":
				var hurt = 0
				for u in _army():
					if u.hp < u.max_hp * 0.5:
						hurt += 1
				if hurt >= 4:
					Game.powers.use(pid, pw, Vector3.ZERO)
			"reveal":
				var t = _enemy_target()
				if t != null:
					Game.powers.use(pid, pw, t.position)
			_:
				var tgt = _cluster_target()
				if tgt != null:
					Game.powers.use(pid, pw, tgt)

## Ziel mit vielen Feinden auf einem Haufen (Einheiten oder Gebäude).
func _cluster_target():
	var best = null
	var bs = 0
	for b in Game.buildings:
		if not b.alive or not Game.enemies(pid, b.owner_id):
			continue
		var n = 1
		for o in Game.buildings:
			if o != b and o.alive and o.owner_id == b.owner_id and Game.flat_dist(o.position, b.position) < 14.0:
				n += 1
		n += Game.units_near(b.position, 12.0).filter(func(u): return Game.enemies(pid, u.owner_id)).size()
		if n > bs:
			bs = n
			best = b.position
	return best if bs >= 3 else null

func _superweapon() -> void:
	for b in _mine_buildings():
		if b.def["role"] == "super" and b.super_ready and Game.has_power(pid):
			var t = _cluster_target()
			if t == null:
				var e = _enemy_target()
				if e != null:
					t = e.position
			if t != null:
				Game.powers.fire_super(b, t)
