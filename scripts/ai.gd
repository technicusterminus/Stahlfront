extends Node
## Computergegner: Basisbau, Wirtschaft, Produktion, Angriffswellen, Fähigkeiten, Superwaffe.

var pid = 0
var faction = ""
var order_list: Array = []
var think_t = 1.0
var wave = 0
## Offensive Generalsfähigkeiten der KI warten auf Leicht und Mittel die Aufbauphase des Menschen ab (Sekunden ab Gefechtsbeginn).
## Grundlage: Nachschubzentrum 15 s Bauzeit + erster Lkw 8 s + Lesen der Hinweise und Platzieren ca. 45 s + erste Fahrt zum Depot ca. 40 s
## + Puffer = 180 s. Auf Schwer (Stufe 2) gilt keine Sperre. Aufklärung und wirtschaftliche Fähigkeiten sind nie gesperrt.
const OFFENSIVE_POWER_GRACE_S := 180.0
const NON_OFFENSIVE_POWERS := ["cash", "heal_all", "reveal"]
var _t_start := 0.0
var next_attack = 0.0
var attackers: Array = []
var raiders: Array = []      # Plänkler auf Beutezug (Kradräuber, Sandviper)
var next_raid = 0.0
var rng = RandomNumberGenerator.new()
var hq_pos = Vector3.ZERO
var target_pid = -1

func setup(p: int) -> void:
	pid = p
	_t_start = Game.time
	faction = Game.faction_of(p)
	rng.randomize()
	var base = ["supply", "power", "barracks", "power", "factory", "defense", "power", "airfield", "dock", "tech", "power", "defense", "supply", "power", "super", "defense", "power", "defense"]
	for r in base:
		var id: String = faction + "_" + r
		if Defs.buildings.has(id):
			order_list.append(r)
	if Game.difficulty == 0:
		order_list.erase("super")
	next_attack = [420.0, 300.0, 220.0][Game.difficulty]
	next_raid = [360.0, 260.0, 180.0][Game.difficulty]
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
	_raids()
	_naval()
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
			var kind = _harvest_kind(harv)
			harv += 1
			if u.order == "idle":
				u.cmd_harvest(null, kind)
			elif u.cargo == 0.0 and u.h_state == "to_depot" and u.h_kind != kind:
				u.cmd_harvest(null, kind)
	var supplies = _count_role("supply", false)
	var want: int = min(supplies * (3 if Game.difficulty < 2 else 4), 8)
	if harv < want:
		var s = _first_building("supply")
		if s != null and s.queue.is_empty():
			s.queue_unit(Defs.harv_of(faction))

## Welcher Rohstoff als Nächstes geholt wird: reihum, aber nie einer, von dem schon reichlich da ist.
func _harvest_kind(i: int) -> String:
	var cycle = ["supply", "iron", "supply", "wood", "supply", "oil", "supply", "supply", "gold"]
	var p: Dictionary = Game.players[pid]
	for k in cycle.size():
		var kind: String = cycle[(i + k) % cycle.size()]
		var stock: float = p["credits"] if kind == "supply" else p["res"][kind]
		var cap: float = 9000.0 if kind == "supply" else (200.0 if kind == "gold" else 450.0)
		if stock < cap:
			return kind
	return "supply"

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
	if Game.afford_why(pid, d) != "":
		return
	var site = _find_site(id, role)
	if site == null:
		if role == "dock":
			dock_fail += 1
			if dock_fail >= 5:
				order_list.erase("dock")   # kein Platz am Wasser: Werft aus der Bauordnung nehmen
		return
	Game.pay(pid, d)
	var b = Game.spawn_building(id, pid, site, false)
	idle[0].cmd_build(b)

func _find_site(id: String, role: String):
	var d: Dictionary = Defs.buildings[id]
	var center = hq_pos
	if role == "dock":
		var st: Vector3 = Game.players[pid]["start"]
		var bc: Vector2 = Game.terrain.bay_center(Vector2(st.x, st.z))
		var bay = Vector3(bc.x, 0, bc.y)
		for ring in range(5, 24):
			for k in 14:
				var a = rng.randf() * TAU
				var p = bay + Vector3(cos(a), 0, sin(a)) * (ring * 1.0)
				var c = Game.world_to_cell(p)
				if Game.can_place(id, c, pid) == "":
					return c
		return null
	if role == "supply":
		var best = null
		var bd = 1e9
		for dp in Game.depots:
			if dp.supply <= 0 or dp.kind != "supply":
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
			if ud["carrier"] and _credits() < 5000.0:
				continue   # der Träger frisst Wirtschaft: nur mit gut gefüllter Kasse
			if ud["naval"]:
				# Flotte begrenzen: teure Schiffe zählen doppelt, höchstens sechs Schiffe
				if _fleet().size() >= 6:
					continue
				wgt = 1.2 if ud["cost"] < 1000 else 0.8
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
			if ud["raider"]:
				# Plänkler: eine Rotte genügt, sonst fehlt der Armee die Wucht
				if _mine_units().filter(func(u): return u.def["raider"]).size() >= 6:
					continue
				wgt = 2.0
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
	return _mine_units().filter(func(u): return u.def["role"] == "combat" and not u.naval)

func _fleet() -> Array:
	return _mine_units().filter(func(u): return u.naval and u.def["role"] == "combat")

## Gegner für die nächste Welle: der stärkste (mit etwas Zufall), damit nicht der
## geografisch nächste Spieler von allen zugleich überrannt wird.
func _repick_target() -> void:
	var best = -1
	var bs = -1.0
	for q in Game.players:
		if q["id"] != pid and q["alive"]:
			var s = float(Game.player_strength(q["id"])) * rng.randf_range(0.7, 1.3)
			if s > bs:
				bs = s
				best = q["id"]
	target_pid = best

func _target_player() -> int:
	if target_pid < 0 or not Game.players[target_pid]["alive"]:
		_repick_target()
	return target_pid

func _enemy_target():
	var best = null
	var bd = 1e9
	var tp = _target_player()
	for b in Game.buildings:
		if b.alive and Game.enemies(pid, b.owner_id) and (tp < 0 or b.owner_id == tp):
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
	var home: Array = army.filter(func(u): return not attackers.has(u) and not raiders.has(u))
	var need: int = [5, 7, 9][Game.difficulty] + min(wave * 2, 14)
	if Game.time >= next_attack and home.size() >= need:
		_repick_target()
		var t = _enemy_target()
		if t != null:
			wave += 1
			next_attack = Game.time + [150.0, 110.0, 80.0][Game.difficulty]
			for u in home:
				attackers.append(u)
				u.cmd_move(t.position, true)
	# Angreifer, die nichts mehr zu tun haben, zum nächsten Ziel schicken
	var tp2 = _target_player()
	for u in attackers:
		if u.order == "idle" and u.target == null:
			var best = null
			var bd = 1e9
			for b in Game.buildings:
				if b.alive and Game.enemies(pid, b.owner_id) and (tp2 < 0 or b.owner_id == tp2):
					var d = Game.flat_dist(b.position, u.position)
					if d < bd:
						bd = d
						best = b
			if best == null:
				for b in Game.buildings:
					if b.alive and Game.enemies(pid, b.owner_id):
						var d2 = Game.flat_dist(b.position, u.position)
						if d2 < bd:
							bd = d2
							best = b
			if best != null:
				u.cmd_move(best.position, true)
	# Sammelpunkt vor der Basis
	for u in home:
		if u.order == "idle" and Game.flat_dist(u.position, hq_pos) > 50.0 and u.target == null:
			u.cmd_move(hq_pos + (Vector3.ZERO - hq_pos).normalized() * 22.0, true)

## Plänkler (Kradräuber, Sandviper): ziehen in kleinen Rotten los und jagen Nachschub-Lkw und Bautrupps
## abseits der gegnerischen Abwehr. Angeschlagene kehren zur Reparatur heim, ohne Beute schließen sie sich der Armee an.
func _raids() -> void:
	raiders = raiders.filter(func(u): return is_instance_valid(u) and u.alive)
	for u in raiders.duplicate():
		if u.hp < u.max_hp * 0.35:
			raiders.erase(u)
			u.cmd_move(hq_pos + (Vector3.ZERO - hq_pos).normalized() * 16.0)
		elif u.order == "idle" and u.target == null:
			var nxt = _raid_target(u.position)
			if nxt != null:
				u.cmd_attack(nxt)
			else:
				raiders.erase(u)
	if Game.time < next_raid:
		return
	var ready: Array = _army().filter(func(u): return u.def["raider"] and not raiders.has(u) and not attackers.has(u) and u.hp > u.max_hp * 0.7)
	if ready.size() < 2:
		return
	var center := Vector3.ZERO
	for u in ready:
		center += u.position / float(ready.size())
	var t = _raid_target(center)
	if t == null:
		return
	next_raid = Game.time + [110.0, 80.0, 55.0][Game.difficulty]
	for u in ready.slice(0, 5):
		raiders.append(u)
		u.cmd_attack(t)

## Beute für Plänkler: gegnerische Nachschubfahrzeuge und Bautrupps am Boden, nah und möglichst fern von Abwehrstellungen.
func _raid_target(from: Vector3):
	var best = null
	var bs := 1e9
	for u in Game.units:
		if not u.alive or u.flying or u.naval or not Game.enemies(pid, u.owner_id):
			continue
		if u.def["role"] != "harvester" and u.def["role"] != "dozer":
			continue
		var s: float = Game.flat_dist(u.position, from)
		for b in Game.buildings:
			if b.alive and b.weapon != null and Game.enemies(pid, b.owner_id) and Game.flat_dist(b.position, u.position) < 26.0:
				s += 120.0
		if s < bs:
			bs = s
			best = u
	return best

## Flotte: sammelt sich in der Heimatbucht und greift ab drei Schiffen die Bucht oder Küste des Gegners an.
var next_fleet = 240.0
var dock_fail = 0

func _naval() -> void:
	var ships = _fleet()
	if ships.size() < 3 or Game.time < next_fleet:
		return
	var t = _enemy_target()
	if t == null:
		return
	next_fleet = Game.time + [140.0, 100.0, 70.0][Game.difficulty]
	var tp = t.owner_id
	var goal: Vector3 = t.position
	for b in Game.buildings:
		if b.alive and b.owner_id == tp and b.def["role"] == "dock":
			goal = b.position
	for u in ships:
		u.cmd_move(goal, true)

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
		if _power_locked_by_grace(pw):
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
					if OS.get_cmdline_user_args().has("--verbose"):
						print("KI-FAEHIGKEIT P%d %s bei t=%d s auf (%d, %d)" % [pid, pw["id"], int(Game.time), int(tgt.x), int(tgt.z)])
					Game.powers.use(pid, pw, tgt)

## Offensive Fähigkeiten sind auf Leicht und Mittel in der Aufbauphase gesperrt.
func _power_locked_by_grace(pw: Dictionary) -> bool:
	if Game.difficulty >= 2 or NON_OFFENSIVE_POWERS.has(pw["id"]):
		return false
	# Die Sperre schützt nur den Einstieg eines menschlichen Spielers; KI gegen KI (Zuschauermodus, Balance-Messungen) bleibt unverändert.
	if Game.spectator or not Game.enemies(pid, Game.human):
		return false
	return Game.time - _t_start < OFFENSIVE_POWER_GRACE_S

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
