extends Node
## Globaler Spielzustand: Spieler, Objekte, Raster, Wegfindung, Schaden, Nebel des Krieges.

signal message(text: String, col: Color)
signal match_ended(won: bool)

const CELL := 2.0
const GRID := 120
const HALF := 120.0
const BUCKET := 8.0

var UnitScript: GDScript
var BuildingScript: GDScript
var DepotScript: GDScript

var world: Node3D
var terrain
var cam
var hud
var ctrl
var powers
var units_root: Node3D
var fx_root: Node3D

var players: Array = []
var units: Array = []
var buildings: Array = []
var depots: Array = []
var human = 0
var spectator = false
var running = false
var game_over = false
var time = 0.0
var difficulty = 1
var last_alert_pos = Vector3.ZERO
var _alert_t = -99.0

var astar: AStarGrid2D
var buckets = {}

var fog_vis = PackedByteArray()
var fog_exp = PackedByteArray()
var fog_img: Image
var fog_tex: ImageTexture
var reveals: Array = []
var occ_img: Image
var occ_tex: ImageTexture

## Belegung durch Gebäude/Depots (lässt Gras darunter verschwinden).
func set_occ(cells: Array, on: bool) -> void:
	for c in cells:
		if in_grid(c):
			occ_img.set_pixel(c.x, c.y, Color(1, 0, 0) if on else Color(0, 0, 0))
	occ_tex.update(occ_img)
var _fog_t = 0.0
var _vic_t = 0.0
var _fog_mats = {}

const PLAYER_COLORS := [Color(0.22, 0.5, 1.0), Color(0.95, 0.2, 0.15), Color(0.95, 0.75, 0.15), Color(0.3, 0.85, 0.4)]

func _ready() -> void:
	UnitScript = load("res://scripts/unit.gd")
	BuildingScript = load("res://scripts/building.gd")
	DepotScript = load("res://scripts/depot.gd")
	fog_vis.resize(GRID * GRID)
	fog_exp.resize(GRID * GRID)
	fog_img = Image.create(GRID, GRID, false, Image.FORMAT_RG8)
	fog_img.fill(Color(0, 0, 0))
	fog_tex = ImageTexture.create_from_image(fog_img)
	occ_img = Image.create(GRID, GRID, false, Image.FORMAT_R8)
	occ_img.fill(Color(0, 0, 0))
	occ_tex = ImageTexture.create_from_image(occ_img)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func fog_material(tint: Color, rough: float, glow := 0.0) -> ShaderMaterial:
	var key = "%s_%s_%s" % [tint.to_html(), rough, glow]
	if _fog_mats.has(key):
		return _fog_mats[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/fogged.gdshader")
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("fog_tex", fog_tex)
	_fog_mats[key] = m
	return m

# ---------------------------------------------------------------- Raster

func init_grid() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID, GRID)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for z in GRID:
		for x in GRID:
			if terrain.blocked[z * GRID + x] == 1:
				astar.set_point_solid(Vector2i(x, z), true)

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x + HALF) / CELL)), 0, GRID - 1), clampi(int(floor((p.z + HALF) / CELL)), 0, GRID - 1))

func cell_center(c: Vector2i) -> Vector3:
	var x = c.x * CELL - HALF + CELL * 0.5
	var z = c.y * CELL - HALF + CELL * 0.5
	return Vector3(x, terrain.ground_y(x, z), z)

func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID

func is_free(c: Vector2i) -> bool:
	return in_grid(c) and not astar.is_point_solid(c)

func nearest_free(c: Vector2i, max_r := 14) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, max_r + 1):
		var best = Vector2i(-1, -1)
		var bd = 1e9
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dz) != r:
					continue
				var n = c + Vector2i(dx, dz)
				if is_free(n):
					var d = float(dx * dx + dz * dz)
					if d < bd:
						bd = d
						best = n
		if best.x >= 0:
			return best
	return c

func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var d = b - a
	var steps: int = max(abs(d.x), abs(d.y)) * 2
	if steps == 0:
		return true
	for i in range(1, steps):
		var t = float(i) / steps
		var p = Vector2(a) + Vector2(d) * t
		var c = Vector2i(int(round(p.x)), int(round(p.y)))
		if not is_free(c):
			return false
		# Ecken pruefen, damit Diagonalen nicht durch Waende schlüpfen
		var c2 = Vector2i(int(floor(p.x + 0.5)), int(floor(p.y)))
		var c3 = Vector2i(int(floor(p.x)), int(floor(p.y + 0.5)))
		if not is_free(c2) or not is_free(c3):
			return false
	return true

func find_path(from: Vector3, to: Vector3) -> Array:
	var a = nearest_free(world_to_cell(from))
	var b = nearest_free(world_to_cell(to))
	var ids: Array = astar.get_id_path(a, b, true)
	var out: Array = []
	if ids.is_empty():
		return [to]
	# Sichtlinien-Glaettung
	var anchor: Vector2i = ids[0]
	var i = 1
	while i < ids.size():
		var j = i
		while j + 1 < ids.size() and line_clear(anchor, ids[j + 1]):
			j += 1
		anchor = ids[j]
		out.append(cell_center(anchor))
		i = j + 1
	var goal_c = world_to_cell(to)
	if goal_c == b and not out.is_empty():
		out[out.size() - 1] = to
	elif out.is_empty():
		out.append(cell_center(b))
	return out

func footprint(center: Vector2i, size: int) -> Array:
	var out: Array = []
	var h = size / 2
	for z in range(center.y - h, center.y - h + size):
		for x in range(center.x - h, center.x - h + size):
			out.append(Vector2i(x, z))
	return out

func footprint_center(center: Vector2i, size: int) -> Vector3:
	var cells = footprint(center, size)
	var a: Vector3 = cell_center(cells[0])
	var b: Vector3 = cell_center(cells[cells.size() - 1])
	var p = (a + b) * 0.5
	p.y = 0.0
	return p

func set_cells(cells: Array, solid: bool) -> void:
	for c in cells:
		if in_grid(c):
			if not solid and terrain.blocked[c.y * GRID + c.x] == 1:
				continue
			astar.set_point_solid(c, solid)

func can_place(def_id: String, center: Vector2i, pid: int) -> String:
	var d: Dictionary = Defs.buildings[def_id]
	var cells = footprint(center, d["size"])
	var mn = 999.0
	var mx = -999.0
	for c in cells:
		if not in_grid(c):
			return "Außerhalb der Karte"
		if astar.is_point_solid(c):
			return "Platz ist belegt oder unwegsam"
		if pid == human and not spectator and fog_exp[c.y * GRID + c.x] == 0:
			return "Gebiet ist noch unerforscht"
		var p = cell_center(c)
		mn = min(mn, p.y)
		mx = max(mx, p.y)
	if mx - mn > 2.6:
		return "Gelände ist zu steil"
	for dp in depots:
		if dp.position.distance_to(footprint_center(center, d["size"])) < 5.0 + d["size"]:
			return "Zu nah am Nachschubdepot"
	return ""

# ---------------------------------------------------------------- Spieler

func reset_match() -> void:
	for u in units.duplicate():
		if is_instance_valid(u):
			u.queue_free()
	for b in buildings.duplicate():
		if is_instance_valid(b):
			b.queue_free()
	units.clear()
	buildings.clear()
	players.clear()
	reveals.clear()
	game_over = false
	running = false
	time = 0.0
	fog_vis.fill(0)
	fog_exp.fill(0)

func add_player(faction: String, is_ai: bool, start: Vector3) -> Dictionary:
	# Fraktionsfarbe, solange sie frei ist; sonst eine freie Ersatzfarbe
	var col: Color = Defs.factions[faction]["color"]
	var used: Array = players.map(func(q): return q["color"])
	if used.has(col):
		for c in PLAYER_COLORS:
			var clash = false
			for u in used:
				if (u as Color).is_equal_approx(c) or Vector3(u.r - c.r, u.g - c.g, u.b - c.b).length() < 0.35:
					clash = true
			if not clash:
				col = c
				break
	var p = {
		"id": players.size(), "faction": faction, "color": col,
		"name": Defs.factions[faction]["name"],
		"credits": 5000.0, "ai": is_ai, "alive": true, "xp": 0.0, "rank": 1, "points": 1,
		"unlocked": {}, "ready_at": {}, "start": start, "power_prod": 0, "power_use": 0,
		"kills": 0, "losses": 0, "built": 0, "income": 0.0,
	}
	players.append(p)
	return p

## Einkommens- und Produktionsfaktor (KI-Schwierigkeit).
func income_mult(pid: int) -> float:
	if players[pid]["ai"] and not spectator:
		return [0.75, 1.0, 1.3][difficulty]
	return 1.0

func faction_of(pid: int) -> String:
	return players[pid]["faction"]

func recalc_power(pid: int) -> void:
	var prod = 0
	var use = 0
	for b in buildings:
		if b.owner_id == pid and b.alive and b.complete:
			var pw: int = b.def["power"]
			if pw > 0:
				prod += pw
			else:
				use -= pw
	players[pid]["power_prod"] = prod
	players[pid]["power_use"] = use

func has_power(pid: int) -> bool:
	var p: Dictionary = players[pid]
	if not Defs.factions[p["faction"]]["uses_power"]:
		return true
	return p["power_prod"] >= p["power_use"]

func roles(pid: int) -> Dictionary:
	var r = {}
	for b in buildings:
		if b.owner_id == pid and b.alive and b.complete:
			r[b.def["role"]] = r.get(b.def["role"], 0) + 1
	return r

func missing_prereq(def: Dictionary, pid: int) -> String:
	var r = roles(pid)
	var miss: Array = []
	for pre in def["prereq"]:
		if not r.has(pre):
			var bid: String = faction_of(pid) + "_" + pre
			miss.append(Defs.buildings[bid]["name"] if Defs.buildings.has(bid) else pre)
	if miss.is_empty():
		return ""
	return "Benötigt: " + ", ".join(miss)

func enemies(a: int, b: int) -> bool:
	return a != b and a >= 0 and b >= 0

# ---------------------------------------------------------------- Objekte

func spawn_unit(def_id: String, pid: int, pos: Vector3):
	var u = UnitScript.new()
	u.setup(Defs.units[def_id], pid)
	units_root.add_child(u)
	u.place_at(pos)
	units.append(u)
	return u

func spawn_building(def_id: String, pid: int, center: Vector2i, complete: bool):
	var b = BuildingScript.new()
	var d: Dictionary = Defs.buildings[def_id]
	b.setup(d, pid, center, footprint(center, d["size"]))
	units_root.add_child(b)
	b.position = footprint_center(center, d["size"])
	b.position.y = terrain.height_at(b.position.x, b.position.z)
	buildings.append(b)
	set_cells(b.cells, true)
	set_occ(b.cells, true)
	if complete:
		b.finish(true)
	return b

func spawn_depot(pos: Vector3, amount: float):
	var dp = DepotScript.new()
	dp.supply = amount
	dp.max_supply = amount
	units_root.add_child(dp)
	dp.position = Vector3(pos.x, terrain.height_at(pos.x, pos.z), pos.z)
	dp.build()
	depots.append(dp)
	var c = world_to_cell(dp.position)
	set_cells(footprint(c, 2), true)
	set_occ(footprint(c, 3), true)
	return dp

func remove_object(o) -> void:
	units.erase(o)
	buildings.erase(o)

# ---------------------------------------------------------------- Raeumliche Suche

func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	buckets.clear()
	for u in units:
		var k = Vector2i(int(floor(u.position.x / BUCKET)), int(floor(u.position.z / BUCKET)))
		if buckets.has(k):
			buckets[k].append(u)
		else:
			buckets[k] = [u]
	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_t = 0.2
		update_fog()
	_vic_t -= delta
	if _vic_t <= 0.0:
		_vic_t = 2.0
		check_victory()

func units_near(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var k0 = Vector2i(int(floor((pos.x - r) / BUCKET)), int(floor((pos.z - r) / BUCKET)))
	var k1 = Vector2i(int(floor((pos.x + r) / BUCKET)), int(floor((pos.z + r) / BUCKET)))
	var r2 = r * r
	for kz in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var arr = buckets.get(Vector2i(kx, kz))
			if arr == null:
				continue
			for u in arr:
				if not is_instance_valid(u) or not u.alive:
					continue
				var dx: float = u.position.x - pos.x
				var dz: float = u.position.z - pos.z
				if dx * dx + dz * dz <= r2:
					out.append(u)
	return out

func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Nächstes feindliches Ziel in Reichweite.
func find_target(pid: int, pos: Vector3, r: float, air: bool, ground: bool, min_r := 0.0):
	var best = null
	var bd = 1e9
	for u in units_near(pos, r + 2.0):
		if not enemies(pid, u.owner_id):
			continue
		if u.flying and not air:
			continue
		if not u.flying and not ground:
			continue
		if u.stealthed and not u.detectable_from(pos):
			continue
		var d = flat_dist(pos, u.position) - u.radius
		if d > r or d < min_r:
			continue
		# Bewaffnete Ziele bevorzugen
		var score = d - (4.0 if u.def["weapon"] != null else 0.0)
		if score < bd:
			bd = score
			best = u
	if ground:
		for b in buildings:
			if not b.alive or not enemies(pid, b.owner_id):
				continue
			var d = flat_dist(pos, b.position) - b.radius
			if d > r or d < min_r:
				continue
			var score = d + (6.0 if b.def["weapon"] == null else -3.0)
			if score < bd:
				bd = score
				best = b
	return best

# ---------------------------------------------------------------- Schaden

func apply_damage(t, dmg: float, wtype: String, attacker_pid: int, attacker = null) -> void:
	if t == null or not is_instance_valid(t) or not t.alive:
		return
	var armor: String = "bldg" if t.is_building else t.def["armor"]
	var mod: float = Defs.DMG_MOD[wtype].get(armor, 1.0)
	if mod <= 0.0:
		return
	t.take_damage(dmg * mod, attacker_pid, attacker)

func damage_area(pos: Vector3, r: float, dmg: float, wtype: String, attacker_pid: int, attacker = null, hit_air := false) -> void:
	for u in units_near(pos, r + 1.5):
		if not enemies(attacker_pid, u.owner_id):
			continue
		if u.flying and not hit_air:
			continue
		var d = flat_dist(pos, u.position)
		var f: float = clamp(1.0 - d / (r + 0.01) * 0.6, 0.4, 1.0)
		apply_damage(u, dmg * f, wtype, attacker_pid, attacker)
	for b in buildings.duplicate():
		if not b.alive or not enemies(attacker_pid, b.owner_id):
			continue
		var d = flat_dist(pos, b.position) - b.radius
		if d <= r:
			apply_damage(b, dmg * clamp(1.0 - max(d, 0.0) / (r + 0.01) * 0.6, 0.4, 1.0), wtype, attacker_pid, attacker)

var last_combat_pos := Vector3.ZERO
var last_combat_t := -99.0

func on_damaged(victim, attacker_pid: int) -> void:
	var p: Dictionary = players[victim.owner_id]
	if attacker_pid >= 0:
		last_combat_pos = victim.position
		last_combat_t = time
	if victim.owner_id == human and not spectator and time - _alert_t > 12.0 and attacker_pid >= 0:
		_alert_t = time
		last_alert_pos = victim.position
		notify("Wir werden angegriffen! (Leertaste springt hin)", Color(1, 0.4, 0.3))
	p["attacked_at"] = time
	p["attacked_pos"] = victim.position

func on_killed(victim, killer_pid: int, killer) -> void:
	var cost: float = victim.def.get("cost", 500)
	players[victim.owner_id]["losses"] += 1
	if killer_pid >= 0 and killer_pid != victim.owner_id:
		players[killer_pid]["kills"] += 1
		add_xp(killer_pid, cost * (1.5 if victim.is_building else 1.0))
		if killer != null and is_instance_valid(killer) and killer.is_unit and killer.alive:
			killer.gain_xp(cost)
			# Schattenfront: Schrottbergung bei zerstoerten Fahrzeugen
			if victim.is_unit and victim.is_vehicle and not victim.flying:
				killer.add_salvage()
		# Schattenfront: Kopfgeld
		if faction_of(killer_pid) == "shadow":
			var bounty = cost * 0.2
			players[killer_pid]["credits"] += bounty
			players[killer_pid]["income"] += bounty
			if killer_pid == human and not spectator and is_visible_cell(victim.position):
				load("res://scripts/fx.gd").sparkle(victim.position + Vector3(0, 2, 0), Color(1, 0.85, 0.3))
	if victim.is_building:
		recalc_power(victim.owner_id)
		if victim.owner_id == human and not spectator:
			notify("%s wurde zerstört." % victim.def["name"], Color(1, 0.45, 0.35))

const RANK_XP := [0.0, 2500.0, 7000.0, 15000.0, 28000.0]

func add_xp(pid: int, amount: float) -> void:
	var p: Dictionary = players[pid]
	p["xp"] += amount
	while p["rank"] < RANK_XP.size() and p["xp"] >= RANK_XP[p["rank"]]:
		p["rank"] += 1
		p["points"] += 1
		if pid == human and not spectator:
			notify("Beförderung! Generalsrang %d – ein neuer Generalspunkt ist verfügbar." % p["rank"], Color(1, 0.85, 0.3))

func notify(text: String, col := Color(0.85, 0.92, 1.0)) -> void:
	message.emit(text, col)

func notify_player(pid: int, text: String, col := Color(0.85, 0.92, 1.0)) -> void:
	if pid == human and not spectator:
		notify(text, col)

# ---------------------------------------------------------------- Nebel des Krieges

func update_fog() -> void:
	if spectator:
		fog_vis.fill(1)
		fog_exp.fill(1)
	else:
		fog_vis.fill(0)
		for u in units:
			if u.owner_id == human and u.alive:
				_mark(u.position, u.def["sight"])
		for b in buildings:
			if b.owner_id == human and b.alive:
				_mark(b.position, b.def["sight"])
		for r in reveals.duplicate():
			if time > r["until"]:
				reveals.erase(r)
			else:
				_mark(r["pos"], r["radius"])
	var data = PackedByteArray()
	data.resize(GRID * GRID * 2)
	for i in GRID * GRID:
		data[i * 2] = 255 if fog_vis[i] == 1 else 0
		data[i * 2 + 1] = 255 if fog_exp[i] == 1 else 0
	fog_img.set_data(GRID, GRID, false, Image.FORMAT_RG8, data)
	fog_tex.update(fog_img)
	# Sichtbarkeit fremder Objekte
	for u in units:
		if u.owner_id != human:
			var vis = spectator or is_visible_cell(u.position)
			if vis and u.stealthed and not spectator:
				vis = false
				for o in units_near(u.position, 7.0):
					if o.owner_id == human:
						vis = true
						break
			u.visible = vis
	for b in buildings:
		if b.owner_id != human:
			var c = world_to_cell(b.position)
			b.visible = spectator or fog_exp[c.y * GRID + c.x] == 1

func _mark(pos: Vector3, sight: float) -> void:
	var c = world_to_cell(pos)
	var r = int(ceil(sight / CELL))
	var r2 = (sight / CELL) * (sight / CELL)
	for dz in range(-r, r + 1):
		var z = c.y + dz
		if z < 0 or z >= GRID:
			continue
		for dx in range(-r, r + 1):
			var x = c.x + dx
			if x < 0 or x >= GRID:
				continue
			if dx * dx + dz * dz <= r2:
				var i = z * GRID + x
				fog_vis[i] = 1
				fog_exp[i] = 1

## Gebiet als erkundet markieren (z. B. Umgebung der Startbasis).
func explore(pos: Vector3, r: float) -> void:
	var c = world_to_cell(pos)
	var rc = int(ceil(r / CELL))
	for dz in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var n = c + Vector2i(dx, dz)
			if in_grid(n) and dx * dx + dz * dz <= rc * rc:
				fog_exp[n.y * GRID + n.x] = 1

func is_visible_cell(pos: Vector3) -> bool:
	if spectator:
		return true
	var c = world_to_cell(pos)
	return fog_vis[c.y * GRID + c.x] == 1

func is_explored(pos: Vector3) -> bool:
	if spectator:
		return true
	var c = world_to_cell(pos)
	return fog_exp[c.y * GRID + c.x] == 1

# ---------------------------------------------------------------- Sieg

func player_strength(pid: int) -> int:
	var n = 0
	for b in buildings:
		if b.owner_id == pid and b.alive:
			n += 1
	for u in units:
		if u.owner_id == pid and u.alive:
			n += 1
	return n

func check_victory() -> void:
	if game_over:
		return
	for p in players:
		if p["alive"] and player_strength(p["id"]) == 0:
			p["alive"] = false
			notify("%s (Spieler %d) wurde besiegt." % [p["name"], p["id"] + 1], Color(1, 0.8, 0.4))
	var alive_ids: Array = []
	for p in players:
		if p["alive"]:
			alive_ids.append(p["id"])
	if not spectator and not players[human]["alive"]:
		game_over = true
		match_ended.emit(false)
	elif alive_ids.size() <= 1:
		game_over = true
		match_ended.emit(spectator or (alive_ids.size() == 1 and alive_ids[0] == human))
