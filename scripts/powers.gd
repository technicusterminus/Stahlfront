extends Node
## Generalsfähigkeiten und Superwaffen (als Knoten, damit Timer pausieren).

const FX = preload("res://scripts/fx.gd")
const Models = preload("res://scripts/models.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func needs_target(pw: Dictionary) -> bool:
	return not (pw["id"] in ["cash", "heal_all"])

func ready_in(pid: int, pw: Dictionary) -> float:
	var p: Dictionary = Game.players[pid]
	return max(0.0, float(p["ready_at"].get(pw["id"], 0.0)) - Game.time)

func why_not(pid: int, pw: Dictionary) -> String:
	var p: Dictionary = Game.players[pid]
	if not p["unlocked"].has(pw["id"]):
		if p["points"] <= 0:
			return "Kein Generalspunkt frei. Punkte gibt es bei Beförderungen durch Abschüsse."
		return "Noch gesperrt. Ein Klick schaltet frei (kostet 1 Punkt)."
	var r = ready_in(pid, pw)
	if r > 0.0:
		return "Lädt noch %d s" % int(ceil(r))
	return ""

func unlock(pid: int, pw: Dictionary) -> bool:
	var p: Dictionary = Game.players[pid]
	if p["unlocked"].has(pw["id"]) or p["points"] <= 0:
		return false
	p["points"] -= 1
	p["unlocked"][pw["id"]] = true
	return true

func _later(t: float, cb: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(cb)

func use(pid: int, pw: Dictionary, pos: Vector3) -> void:
	var p: Dictionary = Game.players[pid]
	p["ready_at"][pw["id"]] = Game.time + float(pw["cooldown"])
	var col: Color = p["color"]
	match pw["id"]:
		"reveal":
			Game.reveals.append({"pos": pos, "radius": pw["radius"], "until": Game.time + 40.0, "pid": pid})
			FX.ring(pos, Color(0.4, 0.8, 1.0), pw["radius"], 1.5)
		"cash":
			p["credits"] += pw["value"]
			Game.notify_player(pid, "+%d Credits aus der Staatsreserve." % int(pw["value"]), Color(1, 0.85, 0.3))
		"heal_all":
			for u in Game.units:
				if u.owner_id == pid and u.alive:
					u.hp = u.max_hp
					FX.sparkle(u.position + Vector3(0, 1.5, 0))
		"airstrike":
			for k in 3:
				var side = Vector3(-1, 0, 1).normalized() * (k - 1) * 4.0
				_fly_plane(col, pos + side, 0.6 * k, _airstrike_drop.bind(pid, pw))
		"paradrop":
			_fly_plane(col, pos, 0.0, _paradrop.bind(pid, pw))
		"barrage":
			for i in 20:
				_later(0.5 + i * 0.3, _barrage_shell.bind(pid, pw, pos))
		"toxin_cloud":
			FX.toxin_cloud(pos, pw["radius"], 15.0)
			for i in 15:
				_later(1.0 + i, _area.bind(pos, float(pw["radius"]), float(pw["value"]), "toxin", pid))

func _area(pos: Vector3, r: float, dmg: float, wt: String, pid: int) -> void:
	Game.damage_area(pos, r, dmg, wt, pid, null, wt == "laser")

func _boom(pos: Vector3, size: float, toxic: bool, r: float, dmg: float, wt: String, pid: int) -> void:
	var gp = Vector3(pos.x, Game.terrain.ground_y(pos.x, pos.z), pos.z)
	FX.explosion(gp, size, toxic)
	Game.damage_area(gp, r, dmg, wt, pid, null, wt == "laser")

func _airstrike_drop(at: Vector3, pid: int, pw: Dictionary) -> void:
	for i in 4:
		var bp = at + Vector3(1, 0, 1).normalized() * (i - 1.5) * 3.0
		_later(0.01 + i * 0.12, _boom.bind(bp, 1.6, false, 4.5, float(pw["value"]) / 4.0, "artillery", pid))

func _paradrop(at: Vector3, pid: int, pw: Dictionary) -> void:
	var n: int = pw["count"]
	for i in n:
		var a = TAU * i / float(n)
		var sp = at + Vector3(cos(a), 0, sin(a)) * 3.0
		var c = Game.nearest_free(Game.world_to_cell(sp))
		var u = Game.spawn_unit(pw["unit"], pid, Game.cell_center(c))
		FX.dust(u.position, 0.6)
		u.cmd_move(u.position, true)

func _barrage_shell(pid: int, pw: Dictionary, pos: Vector3) -> void:
	var off = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * float(pw["radius"])
	_boom(Vector3(pos.x + off.x, 0, pos.z + off.y), 1.3, false, 3.5, float(pw["value"]), "artillery", pid)

func _fly_plane(col: Color, at: Vector3, delay: float, on_over: Callable) -> void:
	_later(max(delay, 0.01), _spawn_plane.bind(col, at, on_over))

func _spawn_plane(col: Color, at: Vector3, on_over: Callable) -> void:
	var plane = Models.build_plane(col)
	Game.fx_root.add_child(plane)
	var dir = Vector3(1, 0, 1).normalized()
	var h: float = Game.terrain.ground_y(at.x, at.z) + 24.0
	var a = Vector3(at.x, h, at.z) - dir * 140.0
	var b = Vector3(at.x, h, at.z) + dir * 140.0
	plane.global_position = a
	plane.look_at(b, Vector3.UP)
	plane.rotate_object_local(Vector3.UP, PI)
	var tw = plane.create_tween()
	tw.tween_property(plane, "global_position", b, 3.2)
	tw.tween_callback(plane.queue_free)
	_later(1.6, on_over.bind(at))

# ---------------------------------------------------------------- Superwaffen

func fire_super(b, pos: Vector3) -> void:
	if b == null or not is_instance_valid(b) or not b.alive or not b.super_ready:
		return
	var pid: int = b.owner_id
	var sw: Dictionary = Defs.factions[b.def["faction"]]["super"]
	b.super_ready = false
	b.super_t = sw["charge"]
	if pid != Game.human and not Game.spectator:
		Game.notify("Achtung: %s wurde abgefeuert! (Leertaste springt hin)" % sw["name"], Color(1, 0.3, 0.25))
		Game.last_alert_pos = pos
	match sw["type"]:
		"laser":
			FX.orbital(pos, 3.0)
			for i in 6:
				var off = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
				_later(0.4 + i * 0.5, _laser_tick.bind(pos, off, sw, pid))
		"nuke":
			_missile(b.position + Vector3(0, 2, 0), pos, 4.0, false, _nuke_hit.bind(pos, sw, pid))
		"toxin_salvo":
			for i in 6:
				var off = Vector2.from_angle(TAU * i / 6.0 + randf()) * float(sw["radius"]) * randf_range(0.2, 0.65)
				var tp = Vector3(pos.x + off.x, 0, pos.z + off.y)
				tp.y = Game.terrain.ground_y(tp.x, tp.z)
				_missile(b.position + Vector3(randf_range(-2, 2), 3, randf_range(-2, 2)), tp, 3.5 + i * 0.2, true, _toxin_hit.bind(tp, sw, pid))

func _laser_tick(pos: Vector3, off: Vector3, sw: Dictionary, pid: int) -> void:
	FX.explosion(pos + off, 2.5)
	Game.damage_area(pos, sw["radius"], float(sw["dmg"]) / 6.0, "laser", pid, null, true)

func _nuke_hit(pos: Vector3, sw: Dictionary, pid: int) -> void:
	FX.nuke(pos)
	Game.damage_area(pos, sw["radius"], float(sw["dmg"]) * 0.7, "artillery", pid, null, true)
	FX.toxin_cloud(pos, float(sw["radius"]) * 0.7, 10.0)
	for i in 10:
		_later(1.0 + i, _area.bind(pos, float(sw["radius"]) * 0.8, float(sw["dmg"]) * 0.03, "toxin", pid))

func _toxin_hit(tp: Vector3, sw: Dictionary, pid: int) -> void:
	FX.explosion(tp, 3.0, true)
	FX.toxin_cloud(tp, 6.0, 8.0)
	Game.damage_area(tp, 7.0, float(sw["dmg"]) / 6.0, "artillery", pid)

func _missile(from: Vector3, to: Vector3, dur: float, toxic: bool, on_hit: Callable) -> void:
	var m = Node3D.new()
	Game.fx_root.add_child(m)
	var body = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.45
	cm.height = 4.0
	body.mesh = cm
	body.material_override = Models.mat(Color(0.75, 0.75, 0.72), 0.6, 0.4)
	m.add_child(body)
	FX.trail(m, toxic)
	m.global_position = from
	var peak = (from + to) * 0.5 + Vector3(0, 70, 0)
	var tw = m.create_tween()
	tw.tween_method(_missile_step.bind(m, body, from, peak, to), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(on_hit)
	tw.tween_callback(m.queue_free)

func _missile_step(k: float, m: Node3D, body: MeshInstance3D, from: Vector3, peak: Vector3, to: Vector3) -> void:
	var a = from.lerp(peak, k)
	var b = peak.lerp(to, k)
	var p = a.lerp(b, k)
	var dir = p - m.global_position
	m.global_position = p
	if dir.length() > 0.01:
		body.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
