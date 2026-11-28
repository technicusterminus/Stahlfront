extends Node
## Gefechtstest: zwei Gruppen treten auf freiem Feld gegeneinander an, ohne KI und fern aller Gebäude.
## Aufruf:  godot --path . -- --autostart --duel="shadow_bike*6/west_inf*14,west_dunebuggy*4/red_inf*16" [--speed=4]
## Eine Paarung ist "A/B", jede Seite "kennung*anzahl", mehrere Truppenarten mit "+" (west_inf*6+west_at*2).
## Jede Paarung läuft, bis eine Seite ausgelöscht ist (höchstens 120 s Spielzeit). Ausgabe je Paarung:
##   DUEL <A> gegen <B>: Sieger, Dauer, Überlebende samt Rest-Trefferpunkten, verlorener Wert je Seite,
##   Wirkungsgrad (zerstörter durch verlorenen Wert) und die Bildrate während des Gefechts.
## Danach eine Übersicht, dann beendet sich das Spiel.
## --duelcam=<abstand>: Kamera folgt der Seite A in diesem Abstand, --duelyaw=<grad> dreht sie.
## --duelselect: Seite A ist ausgewählt (zeigt die Auswahlkreise auf den Bildern).
## --duelshot=<name>: Bildschirmfotos nach 1,5 / 4 / 7 s jeder Paarung als shots/<name>_<paarung>_<s>.png.

const MAX_T := 120.0
var matchups: Array = []
var idx := -1
var side_a: Array = []
var side_b: Array = []
var all_a: Array = []
var all_b: Array = []
var total_a := 0.0     # Wert beim Start (tote Einheiten sind danach freigegeben)
var total_b := 0.0
var t := 0.0
var fps_sum := 0.0
var fps_n := 0
var fps_min := 1e9
var spot := Vector3.ZERO
var lines: Array = []
var state := "wait"
var wait_t := 1.5
var cam_dist := 0.0
var cam_yaw := 0.0
var shot_name := ""
var shots_left: Array = []
var select_a := false

func setup(spec: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--duelcam="):
			cam_dist = float(a.trim_prefix("--duelcam="))
		elif a.begins_with("--duelyaw="):
			cam_yaw = deg_to_rad(float(a.trim_prefix("--duelyaw=")))
		elif a == "--duelselect":
			select_a = true
		elif a.begins_with("--duelshot="):
			shot_name = a.trim_prefix("--duelshot=")
	for m in spec.split(",", false):
		var halves: PackedStringArray = m.split("/")
		if halves.size() == 2:
			matchups.append([_parse(halves[0]), _parse(halves[1])])

func _parse(s: String) -> Array:
	var out: Array = []
	for part in s.split("+", false):
		var kv: PackedStringArray = part.split("*")
		var id := kv[0].strip_edges()
		if not Defs.units.has(id):
			push_error("DUEL unbekannte Einheit " + id)
			continue
		out.append([id, int(kv[1]) if kv.size() > 1 else 1])
	return out

func _process(delta: float) -> void:
	if not Game.running:
		return
	match state:
		"wait":
			wait_t -= delta
			if wait_t <= 0.0:
				_start_next()
		"fight":
			t += delta
			var fps := Engine.get_frames_per_second()
			fps_sum += fps
			fps_n += 1
			if t > 2.0:
				fps_min = minf(fps_min, fps)
			side_a = side_a.filter(func(u): return is_instance_valid(u) and u.alive)
			side_b = side_b.filter(func(u): return is_instance_valid(u) and u.alive)
			if cam_dist > 0.0 and not side_a.is_empty():
				var c := Vector3.ZERO
				for u in side_a:
					c += u.position / float(side_a.size())
				Game.cam.look_at_pos(c)
				Game.cam.dist_target = cam_dist
				Game.cam.yaw = cam_yaw
			# wer nichts mehr zu tun hat, rückt auf den Rest der Gegenseite vor
			for pair in [[side_a, side_b], [side_b, side_a]]:
				if pair[1].is_empty():
					continue
				for u in pair[0]:
					if u.order == "idle" and u.target == null:
						u.cmd_move(pair[1][0].position, true)
			if not shots_left.is_empty() and t >= float(shots_left[0]):
				var at: float = shots_left.pop_front()
				_shot("res://shots/%s_%d_%02d.png" % [shot_name, idx, int(at * 10.0)])
			if side_a.is_empty() or side_b.is_empty() or t > MAX_T:
				_finish()

func _start_next() -> void:
	idx += 1
	if idx >= matchups.size():
		print("=== DUEL ÜBERSICHT ===")
		for l in lines:
			print(l)
		print("DUEL FERTIG")
		get_tree().quit()
		return
	if idx == 0:
		# keine KI, damit niemand die Testtruppen umlenkt
		for n in get_parent().get_children():
			if String(n.name).begins_with("AI_"):
				n.queue_free()
		spot = _find_spot()
		Game.explore(spot, 80.0)
		Game.cam.look_at_pos(spot)
		Game.cam.dist_target = 70.0
	var m: Array = matchups[idx]
	all_a = _spawn(m[0], 0, spot + Vector3(-32, 0, 0), PI * 0.5)
	all_b = _spawn(m[1], 1, spot + Vector3(32, 0, 0), -PI * 0.5)
	side_a = all_a.duplicate()
	side_b = all_b.duplicate()
	total_a = _value(all_a)
	total_b = _value(all_b)
	if select_a:
		Game.ctrl.set_selection(all_a)
	for u in side_a:
		u.cmd_move(spot + Vector3(32, 0, 0), true)
	for u in side_b:
		u.cmd_move(spot + Vector3(-32, 0, 0), true)
	t = 0.0
	fps_sum = 0.0
	fps_n = 0
	fps_min = 1e9
	shots_left = [1.5, 4.0, 7.0] if shot_name != "" else []
	state = "fight"

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("DUEL Bild ", path)

func _spawn(group: Array, pid: int, center: Vector3, heading: float) -> Array:
	var out: Array = []
	var total := 0
	for g in group:
		total += int(g[1])
	var per_row := 5
	var k := 0
	for g in group:
		var vehicle: bool = Defs.units[g[0]]["armor"] != "inf"
		var gap := 5.0 if vehicle else 2.6
		for i in int(g[1]):
			var row := k / per_row
			var col := k % per_row
			var off := Vector3(signf(center.x - spot.x) * row * gap, 0, (col - (per_row - 1) * 0.5) * gap)
			var p := center + off
			p = Game.cell_center(Game.nearest_free(Game.world_to_cell(p), 10))
			var u = Game.spawn_unit(String(g[0]), pid, p)
			u.heading = heading
			out.append(u)
			k += 1
	return out

func _value(units: Array) -> float:
	var v := 0.0
	for u in units:
		v += float(u.def["cost"])
	return v

func _desc(group: Array) -> String:
	var parts: Array = []
	for g in group:
		parts.append("%dx %s" % [int(g[1]), g[0]])
	return " + ".join(parts)

func _finish() -> void:
	state = "wait"
	wait_t = 2.0
	var m: Array = matchups[idx]
	var lost_a := total_a - _value(side_a)
	var lost_b := total_b - _value(side_b)
	var hp_a := 0.0
	var hp_b := 0.0
	var max_a := 0.0
	var max_b := 0.0
	for u in side_a:
		hp_a += u.hp
	for u in side_b:
		hp_b += u.hp
	for g in m[0]:
		max_a += float(Defs.units[g[0]]["hp"]) * int(g[1])
	for g in m[1]:
		max_b += float(Defs.units[g[0]]["hp"]) * int(g[1])
	var winner := "A" if side_b.is_empty() and not side_a.is_empty() else ("B" if side_a.is_empty() and not side_b.is_empty() else "keiner")
	if t > MAX_T:
		winner = "Zeit (A %.0f%% / B %.0f%% Rest)" % [hp_a / maxf(max_a, 1.0) * 100.0, hp_b / maxf(max_b, 1.0) * 100.0]
	var eff_a := "%.2f" % (lost_b / lost_a) if lost_a >= 1.0 else ("keine Verluste" if lost_b >= 1.0 else "-")
	var line := "DUEL %s (%d) gegen %s (%d): Sieger %s nach %.1f s | A übrig %d/%d (TP %.0f%%) verloren %d | B übrig %d/%d (TP %.0f%%) verloren %d | Wirkungsgrad A %s | FPS Schnitt %.0f, min %.0f, Einheiten %d" % [
		_desc(m[0]), int(total_a), _desc(m[1]), int(total_b), winner, t,
		side_a.size(), all_a.size(), hp_a / maxf(max_a, 1.0) * 100.0, int(lost_a),
		side_b.size(), all_b.size(), hp_b / maxf(max_b, 1.0) * 100.0, int(lost_b),
		eff_a, fps_sum / maxf(fps_n, 1.0), fps_min if fps_min < 1e8 else 0.0, Game.units.size()]
	print(line)
	lines.append(line)
	# Überlebende ohne Wrack entfernen, damit die nächste Paarung frei beginnt
	for u in side_a + side_b:
		if is_instance_valid(u):
			Game.remove_object(u)
			u.alive = false
			u.queue_free()
	side_a.clear()
	side_b.clear()

## Freie, flache Fläche nahe der Kartenmitte, weit weg von Gebäuden.
func _find_spot() -> Vector3:
	var best := Vector3.ZERO
	var best_s := -1e9
	var r: float = Game.HALF * 0.75
	for i in 120:
		var a := float(i) * 2.39996
		var rr := r * sqrt(float(i) / 120.0)
		var c := Vector3(cos(a) * rr, 0, sin(a) * rr)
		var s := _openness(c)
		if s > best_s:
			best_s = s
			best = c
	best.y = Game.terrain.ground_y(best.x, best.z)
	print("DUEL Feld bei %s, Güte %.2f" % [str(Vector2(best.x, best.z).round()), best_s])
	return best

func _openness(c: Vector3) -> float:
	var free := 0
	var n := 0
	var h0: float = Game.terrain.ground_y(c.x, c.z)
	var rough := 0.0
	for x in range(-48, 49, 6):
		for z in range(-18, 19, 6):
			n += 1
			var p := c + Vector3(x, 0, z)
			if Game.is_free(Game.world_to_cell(p)):
				free += 1
			rough += absf(Game.terrain.ground_y(p.x, p.z) - h0)
	var s := float(free) / float(n) - rough / float(n) * 0.05
	for b in Game.buildings:
		# Basen und Abwehrstellungen meiden (neutrale Häuser stören nicht)
		if (b.owner_id == 0 or b.owner_id == 1 or b.weapon != null) and Game.flat_dist(b.position, c) < 75.0:
			s -= 0.5
	for dp in Game.depots:
		if is_instance_valid(dp) and Game.flat_dist(dp.position, c) < 30.0:
			s -= 0.1
	return s
