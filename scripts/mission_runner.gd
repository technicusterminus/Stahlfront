extends Node
## Führt eine Mission aus scripts/missions.gd aus: Einsatzbesprechung, Ziele, Funksprüche, Ereignisse, Sieg und Niederlage.
## Die Oberfläche (Zielliste, Funkfenster, Besprechung, Abschluss) liegt auf einer eigenen Ebene über der Spieloberfläche.

const Missions = preload("res://scripts/missions.gd")
const FX = preload("res://scripts/fx.gd")

var m: Dictionary = {}
var main = null
var started := false
var finished := false
var t0 := 0.0
var kills0 := 0
var flags := {}
var done := {}
var fired := {}
var tags := {}
var tag_total := {}
var _check_t := 0.0
var _mark_t := 0.0
var _objs: Array = []
var _layer: CanvasLayer
var _obj_box: VBoxContainer
var _obj_labels := {}
var _radio_panel: PanelContainer
var _radio_who: Label
var _radio_text: Label
var _radio_queue: Array = []
var _radio_left := 0.0
var _briefing: Control = null
# Filmsequenzen (Intro, Outro): Zeitleiste aus Aktionen mit "t", Letterbox, Kamerafahrt, Titel
var _cine := false
var _cine_steps: Array = []
var _cine_t := 0.0
var _cine_i := 0
var _cine_cb: Callable = Callable()
var _cine_final: Dictionary = {}
var _cine_tweens: Array = []
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _skip_hint: Label
var _title_box: VBoxContainer
var _title_a: Label
var _title_b: Label
var _banner_l: Label
var _flash: ColorRect
var _cam_edge := true
var _cine_end_pending := false

func setup(mission: Dictionary, main_node) -> void:
	m = mission
	main = main_node
	Game.mission = self
	name = "MissionRunner"
	var pl: Dictionary = Game.players[0]
	pl["credits"] = float(m.get("credits", 5000))
	for k in m.get("res", {}):
		pl["res"][k] = float(m["res"][k])
	var uses_power: bool = Defs.factions[pl["faction"]]["uses_power"]
	for o in m["objectives"]:
		if o.get("if_power", false) and not uses_power:
			continue
		_objs.append(o)
	if m.get("ai", "off") == "off":
		_set_ai(false)
	_build_ui()
	for a in m.get("setup", []):
		_do(a)

func begin() -> void:
	# Die Einstiegshilfe der Skirmish-Oberfläche ist hier überflüssig, die Missionsziele übernehmen sie.
	Game.hud._opening_complete = true
	Game.hud.opening_hint.hide()
	t0 = Game.time
	print("MISSION %s: Start (%s)" % [m["id"], m["title"]])
	kills0 = int(Game.players[0]["kills"])
	print("MISSION %s: Start %s Gegner %s Abstand %d" % [m["id"], str(Game.players[0]["start"]), str(Game.players[1]["start"]), int(Game.flat_dist(Game.players[0]["start"], Game.players[1]["start"]))])
	if main.args.has("missioncheck"):
		# Prüft, dass alle Bedingungen auswertbar sind (auch spätere), und gibt die Werte aus
		for o in _objs:
			print("CHECK %s Ziel %s = %s" % [m["id"], o["id"], str(_cond(o["c"]))])
		var roles := {}
		for b in Game.buildings:
			if b.owner_id == 0:
				roles[b.def["role"]] = int(roles.get(b.def["role"], 0)) + 1
		print("CHECK %s Gebaeude %s | eigene Einheiten %d | Gegner Einheiten %d | Tags %s" % [m["id"], str(roles), _mine(func(u): return true).size(), Game.units.filter(func(u): return u.owner_id == 1).size(), str(tag_total)])
		for l in m.get("lose", []):
			print("CHECK %s Niederlage = %s" % [m["id"], str(_cond(l["c"]))])
		for ev in m.get("events", []):
			print("CHECK %s Ereignis = %s" % [m["id"], str(_cond(ev["when"]))])
	if main.args.has("missionauto"):
		if main.args.has("cine"):
			_play_cine(m.get("intro", []), _begin_play)
		else:
			started = true
			_refresh_objectives()
		return
	_show_briefing()

# ---------------------------------------------------------------- Hilfen

func _faction(side: String) -> String:
	return Game.players[0 if side == "me" else 1]["faction"]

func _def_id(side: String, key: String) -> String:
	return key if Defs.units.has(key) else _faction(side) + "_" + key

func _anchor(a: String) -> Vector3:
	var p0: Vector3 = Game.players[0]["start"]
	var p1: Vector3 = Game.players[1]["start"]
	match a:
		"en":
			return p1
		"mid":
			return (p0 + p1) * 0.5
	return p0

func _pos(spec: Array) -> Vector3:
	var p = _anchor(String(spec[0])) + Vector3(float(spec[1]), 0, float(spec[2]))
	p.y = Game.terrain.ground_y(p.x, p.z)
	return p

func _set_ai(on: bool) -> void:
	for p in Game.players:
		if p["ai"]:
			var node = main.get_node_or_null("AI_%d" % p["id"])
			if node != null:
				node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _mine(filter: Callable) -> Array:
	return Game.units.filter(func(u): return u.owner_id == 0 and u.alive and filter.call(u))

# ---------------------------------------------------------------- Bedingungen

func _cond(c: Dictionary) -> bool:
	match String(c["t"]):
		"build":
			var n = 0
			for b in Game.buildings:
				if b.owner_id == 0 and b.alive and b.complete and b.def["role"] == c["role"]:
					n += 1
			return n >= int(c.get("n", 1))
		"units":
			var id: String = _def_id("me", c["key"])
			return _mine(func(u): return u.def["id"] == id).size() >= int(c.get("n", 1))
		"count":
			var role: String = c.get("role", "combat")
			return _mine(func(u): return u.def["role"] == role and (not c.has("flying") or u.flying == c["flying"]) and (not c.has("naval") or u.naval == c["naval"])).size() >= int(c.get("n", 1))
		"selected":
			var us = Game.ctrl.selected_units()
			if c.get("role", "any") != "any":
				us = us.filter(func(u): return u.def["role"] == c["role"])
			return us.size() >= int(c.get("n", 1))
		"reach":
			var at: Vector3 = _pos(c["at"])
			var r: float = float(c.get("r", 8.0))
			var who: String = String(c.get("who", "any"))
			for u in _mine(func(u): return true):
				if who == "dozer" and u.def["role"] != "dozer":
					continue
				if who.begins_with("tag:") and not tags.get(who.substr(4), []).has(u):
					continue
				if Game.flat_dist(u.position, at) <= r:
					return true
			return false
		"kills":
			return int(Game.players[0]["kills"]) - kills0 >= int(c["n"])
		"credits":
			return float(Game.players[0]["credits"]) >= float(c["n"])
		"res":
			return float(Game.players[0]["res"][c["k"]]) >= float(c["n"])
		"time":
			return Game.time - t0 >= float(c["s"])
		"group":
			return Game.ctrl.groups.has(int(c["g"])) and not Game.ctrl.groups[int(c["g"])].is_empty()
		"ui":
			return Game.hud.powers_panel.visible
		"flag":
			return flags.has(c["f"])
		"tag_hurt":
			for u in _alive(c["tag"]):
				if u.hp < u.max_hp * float(c.get("frac", 0.99)):
					return true
			return false
		"since":
			return flags.has(c["f"]) and Game.time - float(flags[c["f"]]) >= float(c["s"])
		"not":
			return not _cond(c["c"])
		"all":
			for x in c["c"]:
				if not _cond(x):
					return false
			return true
		"any":
			for x in c["c"]:
				if _cond(x):
					return true
			return false
		"tag_alive":
			return _alive(c["tag"]).size() >= int(c.get("n", 1))
		"tag_dead":
			return int(tag_total.get(c["tag"], 0)) - _alive(c["tag"]).size() >= int(c["n"])
		"tag_reach":
			var at2: Vector3 = _pos(c["at"])
			var n2 = 0
			for u in _alive(c["tag"]):
				if Game.flat_dist(u.position, at2) <= float(c.get("r", 10.0)):
					n2 += 1
			return n2 >= int(c.get("n", 1))
	return false

func _alive(tag: String) -> Array:
	return tags.get(tag, []).filter(func(u): return is_instance_valid(u) and u.alive)

# ---------------------------------------------------------------- Aktionen

func _do(a: Dictionary) -> void:
	match String(a["do"]):
		"radio":
			_radio_queue.append(a)
		"flag":
			flags[a["f"]] = Game.time
		"ai":
			_set_ai(bool(a.get("on", true)))
		"cam":
			Game.cam.look_at_pos(_pos(a["at"]))
		"marker":
			FX.marker(_pos(a["at"]), Color(1.0, 0.85, 0.3))
		"reveal":
			Game.explore(_pos(a["at"]), float(a.get("r", 30.0)))
		"build":
			_spawn_building(a)
		"spawn":
			_spawn_units(a)
		"convoy":
			for u in _alive(a["tag"]):
				u.cmd_move(_pos(a["to"]) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
		"cam_to":
			_cam_to(a)
		"title":
			_title(String(a.get("text", "")), String(a.get("sub", "")), float(a.get("secs", 4.5)))
		"banner":
			_banner(String(a.get("text", "")), float(a.get("secs", 3.2)), a.get("col", Color(1.0, 0.85, 0.4)))
		"shake":
			Game.cam.shake(float(a.get("n", 1.4)), Game.cam.position)
		"flash":
			_flash_screen(a.get("col", Color(1, 1, 1)), float(a.get("secs", 0.7)))
		"sfx":
			Audio.sfx(String(a["name"]), float(a.get("db", 0.0)))
		"hour":
			Game.daynight.configure(float(a["h"]), 0.0)
		"explode":
			var ep: Vector3 = _target_pos(a)
			FX.explosion(ep, float(a.get("size", 2.0)))
			Audio.sfx("explosion", float(a.get("db", 0.0)))
			Game.cam.shake(float(a.get("n", 1.2)), ep)
		"end":
			_cine_end_pending = true
		"heal":
			for u in _alive(a["tag"]):
				u.hp = u.max_hp
		"truce":
			for u in _alive(a["tag"]):
				u.set_meta("truce", true)
		"kill":
			var left: int = int(a.get("n", 1))
			for u in _alive(a["tag"]):
				if left <= 0:
					break
				Game.apply_damage(u, 99999.0, "rocket", 1, null)
				left -= 1
		"win":
			_finish(true, String(a.get("text", "")))
		"lose":
			_finish(false, String(a.get("text", "")))

func _spawn_units(a: Dictionary) -> void:
	var side: String = a.get("side", "me")
	var owner = 0 if side == "me" else 1
	var id: String = _def_id(side, a["def"])
	var base: Vector3 = _pos(a["at"])
	var spread: float = float(a.get("spread", 5.0))
	var made: Array = []
	var naval: bool = Defs.units[id]["naval"]
	for i in int(a.get("n", 1)):
		var p = base + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
		var c = Game.nearest_free(Game.world_to_cell(p), 14, naval)
		var u = Game.spawn_unit(id, owner, Game.cell_center(c))
		u.heading = 0.0
		made.append(u)
		if a.has("speed"):
			u.def = u.def.duplicate()
			u.def["speed"] = float(u.def["speed"]) * float(a["speed"])
		if a.has("hp"):
			u.max_hp = float(u.max_hp) * float(a["hp"])
			u.hp = u.max_hp
		if a.has("dmg") and u.weapon != null:
			u.weapon = u.weapon.duplicate()
			u.weapon["dmg"] = float(u.weapon["dmg"]) * float(a["dmg"])
		if a.get("truce", false):
			u.set_meta("truce", true)
			u.weapon = null
		if a.has("tag"):
			tags[a["tag"]] = tags.get(a["tag"], []) + [u]
			tag_total[a["tag"]] = int(tag_total.get(a["tag"], 0)) + 1
		if a.get("attack", false):
			u.cmd_move(Game.players[0]["start"] + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
		if a.has("attack_tag"):
			var tg = _alive(a["attack_tag"])
			if not tg.is_empty():
				u.cmd_move(tg[randi() % tg.size()].position, true)
	if side == "me":
		Game.explore(base, 20.0)

func _spawn_building(a: Dictionary) -> void:
	var side: String = a.get("side", "me")
	var owner = 0 if side == "me" else 1
	var id: String = _faction(side) + "_" + String(a["role"])
	if not Defs.buildings.has(id):
		return
	var around: Vector3 = _pos(a["near"])
	for ring in range(0, 14):
		for j in 12:
			var ang = TAU * j / 12.0 + ring * 0.37
			var p = around + Vector3(cos(ang), 0, sin(ang)) * ring * 2.2
			var c = Game.world_to_cell(p)
			if Game.can_place(id, c, owner) == "":
				var ok = true
				for fc in Game.footprint(c, int(Defs.buildings[id]["size"]) + 1):
					if not Game.is_free(fc):
						ok = false
						break
				if ok:
					Game.spawn_building(id, owner, c, true)
					Game.recalc_power(owner)
					return

# ---------------------------------------------------------------- Ablauf

## Testspieler (--missionplay): spielt Tutorial 1 und 3 automatisch durch, um die Zielbedingungen zu prüfen.
var _play_step := 0
var _play_t := 0.0
var _dbg_i := -1
func _autoplay() -> void:
	var t = Game.time - t0
	var dz = _mine(func(u): return u.def["role"] == "dozer")
	if m["id"] == "t1":
		if _play_step == 0 and t > 1.0 and not dz.is_empty():
			Game.ctrl.set_selection([dz[0]])
			_play_step = 1
		elif _play_step == 1 and t > 3.0 and not dz.is_empty():
			dz[0].cmd_move(_pos(["me", -14, 10]))
			_play_step = 2
		elif _play_step == 2 and t > 14.0:
			for r in ["supply", "power", "barracks"]:
				_spawn_building({"side": "me", "role": r, "near": ["me", 12, 12]})
			_play_step = 3
		elif _play_step == 3 and t > 18.0:
			for b in Game.buildings:
				if b.owner_id == 0 and b.def["role"] == "barracks":
					for i in 3:
						b.queue_unit(_def_id("me", "inf"))
			_play_step = 4
	elif m["id"] == "c2":
		var wg = _alive("wing")
		var legs = [[1.0, "mid", -34.0, 6.0], [25.0, "mid", 18.0, -30.0], [55.0, "en", -4.0, 4.0], [66.0, "me", 0.0, 10.0]]
		if _play_step < legs.size() and t > float(legs[_play_step][0]):
			print("AUTO c2 Etappe %d t=%d: Flieger %d" % [_play_step, int(t), wg.size()])
			for u in wg:
				u.cmd_move(_pos([legs[_play_step][1], legs[_play_step][2], legs[_play_step][3]]))
			_play_step += 1
	elif m["id"] == "c3":
		if _play_step == 0 and t > 1.0:
			for u in _mine(func(u): return u.def["role"] != "dozer"):
				u.cmd_move(_pos(["mid", 0, 0]) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), u.def["role"] == "combat")
			_play_step = 1
		elif _play_step == 1 and t > 150.0:
			for u in _alive("drone"):
				Game.apply_damage(u, 99999.0, "rocket", 1, null)   # Testhilfe: Drohne gilt als abgeschossen
			_play_step = 2
	elif m["id"] == "c7":
		for u in _alive("elin") + _alive("mira") + _alive("brandt"):
			u.hp = u.max_hp   # Testhilfe: Schutzbefohlene fallen im Autoplay nicht
		if _play_step == 0 and t > 1.0:
			for u in _alive("elin"):
				u.cmd_move(_pos(["mid", 0, 45]))
			_play_step = 1
		elif _play_step == 1 and not done.has("cut") and int(t) % 4 == 0:
			for u in _alive("elin"):
				u.cmd_move(_pos(["mid", 0, 45]))
				if Game.flat_dist(u.position, _pos(["mid", 0, 45])) > 30.0 and int(t) % 8 == 0:
					u.global_position = u.global_position.move_toward(_pos(["mid", 0, 45]), 14.0)   # Testhilfe: Vorankommen sichern
		elif done.has("hold") and int(t * 2.0) % 6 == 0:
			for u in _alive("foe"):
				Game.apply_damage(u, 99999.0, "shell", 0, null)   # Testhilfe: Angriffe gelten als abgewehrt
	elif m["id"] == "c6":
		var army = _alive("army")
		for u in _alive("mira") + _alive("brandt"):
			u.hp = u.max_hp   # Testhilfe: Schutzbefohlene fallen im Autoplay nicht (geprüft wird der Ablauf)
		if _play_step == 0 and t > 1.0:
			for u in army:
				u.cmd_move(_pos(["mid", -30, 45]) + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), true)
			_play_step = 1
		elif _play_step == 1 and done.has("advance"):
			for u in _alive("bombers"):
				Game.apply_damage(u, 99999.0, "bomb", 1, null)   # Testhilfe: Bomber gelten als abgeschossen
			for u in army:
				u.cmd_move(_pos(["mid", 0, 45]) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), true)
			_play_t = t
			_play_step = 2
		elif _play_step == 2 and not done.has("mira") and t - _play_t > 40.0 and int(t) % 4 == 0:
			for u in _alive("city"):
				Game.apply_damage(u, 99999.0, "shell", 0, null)   # Testhilfe: Stadt gilt als geräumt
			for u in _alive("mira") + _alive("brandt"):
				u.cmd_move(_pos(["mid", 0, 45]) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
				if u.global_position.distance_to(_pos(["mid", 0, 45])) > 30.0 and int(t) % 8 == 0:
					u.global_position = u.global_position.move_toward(_pos(["mid", 0, 45]), 14.0)   # Testhilfe: Vorankommen sichern
		elif _play_step == 2 and done.has("mira"):
			_play_step = 3
		elif _play_step == 3 and done.has("hold") and not done.has("disarm") and not _alive("aldane").is_empty() and int(t) % 5 == 0:
			for u in _alive("aldane"):
				Game.apply_damage(u, 0.2, "bullet", 0, null)   # Testhilfe: ein leichter Treffer auf die Waffe
		elif _play_step == 3 and done.has("disarm"):
			_play_step = 4
		elif _play_step == 4 and flags.has("last") and int(t * 2.0) % 6 == 0:
			for u in _alive("guard"):
				Game.apply_damage(u, 99999.0, "shell", 0, null)   # Testhilfe: Angriff gilt als abgewehrt
	elif m["id"] == "c5":
		var esc = _alive("escort")
		if _play_step == 0 and t > 1.0:
			for u in esc:
				u.cmd_move(_pos(["mid", 22, -22]) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
			_play_step = 1
		elif _play_step == 1 and done.has("fetch"):
			for u in _alive("falke") + _alive("pip"):
				u.cmd_move(_pos(["me", 0, 14]) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
			for u in esc:
				u.cmd_move(_pos(["mid", -20, 20]) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
			_play_step = 2
		elif _play_step == 2 and not done.has("home") and int(t * 2.0) % 4 == 0:
			var fk = _alive("falke")
			if not fk.is_empty():
				for u in esc:
					u.cmd_move(fk[0].position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), true)
		elif _play_step == 2 and done.has("home"):
			for u in _mine(func(u): return u.def["role"] == "combat" and not u.flying):
				u.cmd_move(_pos(["me", 0, 6]) + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), true)
			_play_step = 3
	elif m["id"] == "c4":
		var gs = _mine(func(u): return u.def["role"] == "combat" and not u.flying)
		if t > 200.0 and done.has("cross"):
			for cu in _alive("counter"):
				Game.apply_damage(cu, 99999.0, "rocket", 1, null)   # Testhilfe: Gegenangriff gilt als abgewehrt
		var marks = [[1.0, -22.0, 0.0], [45.0, 0.0, 0.0], [90.0, 26.0, 0.0], [140.0, 38.0, 10.0], [200.0, 8.0, -4.0], [260.0, -4.0, -4.0], [320.0, 26.0, 0.0], [380.0, 38.0, 12.0], [440.0, 30.0, 6.0], [520.0, 36.0, 12.0]]
		if _play_step < marks.size() and t > float(marks[_play_step][0]):
			for bu in _alive("bridge"):
				print("  Rest: %s bei %s (Abstand zur Mitte %d), naval=%s" % [bu.def["id"], str(bu.position), int(Game.flat_dist(bu.position, _anchor("mid"))), str(bu.naval)])
			print("AUTO c4 Schritt %d t=%d: Brueckenverteidiger %d, eigene Bodeneinheiten %d, Gegner gesamt %d" % [_play_step, int(t), _alive("bridge").size(), gs.size(), Game.units.filter(func(u): return u.owner_id == 1 and u.alive).size()])
			for u in gs:
				u.cmd_move(_pos(["mid", marks[_play_step][1], marks[_play_step][2]]) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
			_play_step += 1
	elif m["id"] == "t3":
		var us = _mine(func(u): return u.def["role"] == "combat")
		if _play_step == 0 and t > 1.0:
			Game.ctrl.set_selection(us)
			_play_step = 1
		elif _play_step == 1 and t > 2.0:
			Game.ctrl.groups[1] = us
			for u in us:
				u.cmd_move(_pos(["mid", -26, 0]) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), true)
			_play_step = 2
		elif _play_step == 2 and t > 25.0:
			for u in us:
				u.cmd_move(_pos(["mid", 2, 0]) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), true)
			_play_step = 3

func _process(delta: float) -> void:
	if main != null and main.args.has("missiondebug") and int(Game.time * 2.0) != _dbg_i and started and not finished and m["id"] == "c2":
		_dbg_i = int(Game.time * 2.0)
		for u in tags.get("wing", []):
			print("  FLIEGER %s alive=%s hp=%s pos=%s" % [str(u.def["id"]), str(u.alive) if is_instance_valid(u) else "ungueltig", str(int(u.hp)) if is_instance_valid(u) else "-", str(u.position) if is_instance_valid(u) else "-"])
	if main != null and main.args.has("missionplay") and started and not finished:
		_autoplay()
	_radio_tick(delta)
	if _cine:
		_cine_tick(delta)
		return
	if not started or finished or not Game.running:
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.4
	# sichtbare Ziele nacheinander oder gleichzeitig
	var gate_open := true
	for o in _objs:
		if done.has(o["id"]):
			continue
		if m.get("sequential", false) and not gate_open:
			continue
		if _cond(o["c"]):
			done[o["id"]] = true
			print("MISSION %s: Ziel %s erfuellt (t=%d)" % [m["id"], o["id"], int(Game.time - t0)])
			Audio.sfx("ready", -1.0)
			for a in o.get("done", []):
				_do(a)
			_refresh_objectives()
		elif not o.get("optional", false):
			gate_open = false
	_refresh_objectives()
	for i in m.get("events", []).size():
		if fired.has(i):
			continue
		var ev: Dictionary = m["events"][i]
		if _cond(ev["when"]):
			fired[i] = true
			print("MISSION %s: Ereignis %d (t=%d)" % [m["id"], i, int(Game.time - t0)])
			for a in ev["do"]:
				_do(a)
	for l in m.get("lose", []):
		if _cond(l["c"]):
			_finish(false, String(l["text"]))
			return
	_mark_t -= 0.4
	if _mark_t <= 0.0:
		_mark_t = 2.0
		for o in _objs:
			if not done.has(o["id"]) and o.has("mark") and _visible(o):
				FX.marker(_pos(o["mark"]), Color(1.0, 0.85, 0.3))
	var open_required := false
	for o in _objs:
		if not done.has(o["id"]) and not o.get("optional", false):
			open_required = true
	if not open_required:
		_finish(true, "")

func _visible(o: Dictionary) -> bool:
	if not m.get("sequential", false):
		return true
	for p in _objs:
		if p == o:
			return true
		if not done.has(p["id"]) and not p.get("optional", false):
			return false
	return true

func on_match_end(won: bool) -> void:
	# Im Missionsmodus meldet das Spiel nur die eigene Niederlage
	if not finished:
		_finish(false, "Dein Hauptquartier und alle Einheiten sind verloren.")

func _finish(won: bool, text: String) -> void:
	if finished:
		return
	finished = true
	print("MISSION %s: %s %s" % [m["id"], "SIEG" if won else "NIEDERLAGE", text])
	if won:
		Missions.mark_done(m["id"])
	Game.game_over = true
	if won and m.has("outro"):
		_play_cine(m["outro"], func(): _show_end(won, text))
	else:
		_show_end(won, text)
	if main != null and main.args.has("missionchain") and won and String(m.get("next", "")) != "":
		await get_tree().create_timer(1.0).timeout
		_go(String(m["next"]))

# ---------------------------------------------------------------- Oberfläche

func _style(col: Color, border: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _lbl(text: String, size := 15, col := Color(0.88, 0.94, 1.0)) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.04, 0.08, 0.13, 0.82), Color(0.35, 0.7, 1.0, 0.5)))
	pc.position = Vector2(16, 84)
	pc.custom_minimum_size = Vector2(360, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(pc)
	_obj_box = VBoxContainer.new()
	_obj_box.add_theme_constant_override("separation", 5)
	pc.add_child(_obj_box)
	_radio_panel = PanelContainer.new()
	_radio_panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.06, 0.1, 0.9), Color(0.5, 0.85, 1.0, 0.7)))
	_radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_radio_panel.position = Vector2(-330, 78)
	_radio_panel.custom_minimum_size = Vector2(660, 0)
	_radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_panel.visible = false
	_layer.add_child(_radio_panel)
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	_radio_panel.add_child(rv)
	_radio_who = _lbl("", 14)
	rv.add_child(_radio_who)
	_radio_text = _lbl("", 16)
	rv.add_child(_radio_text)
	pc.visible = false
	_obj_box.get_parent().visible = false
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	# Letterbox: Balken oben und unten, über die Ränder (offset) ein- und ausgefahren
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0, 0, 0, 1)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_top)
	_bar_bot = ColorRect.new()
	_bar_bot.color = Color(0, 0, 0, 1)
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.offset_top = 0.0
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_bot)
	_skip_hint = _lbl("Leertaste: Szene überspringen", 13, Color(0.7, 0.78, 0.88))
	_skip_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.offset_right = -24.0
	_skip_hint.offset_bottom = -22.0
	_skip_hint.visible = false
	_layer.add_child(_skip_hint)
	var title_center = CenterContainer.new()
	title_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(title_center)
	_title_box = VBoxContainer.new()
	_title_box.custom_minimum_size = Vector2(900, 0)
	_title_box.modulate.a = 0.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_center.add_child(_title_box)
	_title_a = _lbl("", 56, Color(1, 1, 1))
	_title_a.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title_a)
	_title_b = _lbl("", 21, Color(0.7, 0.85, 1.0))
	_title_b.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title_b)
	var banner_margin = MarginContainer.new()
	banner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_margin.add_theme_constant_override("margin_top", 170)
	banner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(banner_margin)
	_banner_l = _lbl("", 36, Color(1.0, 0.85, 0.4))
	_banner_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_banner_l.modulate.a = 0.0
	banner_margin.add_child(_banner_l)

func _refresh_objectives() -> void:
	var panel: Control = _obj_box.get_parent()
	panel.visible = started and not finished and not _cine
	var i = 0
	for c in _obj_box.get_children():
		c.queue_free()
	_obj_labels.clear()
	_obj_box.add_child(_lbl(m["title"].to_upper(), 12, Color(0.55, 0.78, 1.0)))
	for o in _objs:
		if not _visible(o):
			continue
		var ok: bool = done.has(o["id"])
		var opt: bool = o.get("optional", false)
		var col = Color(0.55, 0.95, 0.65) if ok else (Color(0.65, 0.7, 0.78) if opt else Color(1, 1, 1))
		var txt = ("☑  " if ok else "☐  ") + String(o["text"])
		if o["id"] == "hold" or (o["c"]["t"] == "time" and not ok):
			var left = max(0.0, float(o["c"]["s"]) - (Game.time - t0))
			txt += "  (%d:%02d)" % [int(left) / 60, int(left) % 60]
		var l = _lbl(txt, 14, col)
		l.custom_minimum_size = Vector2(330, 0)
		_obj_box.add_child(l)

func _radio_tick(delta: float) -> void:
	if _radio_left > 0.0:
		_radio_left -= delta
		if _radio_left <= 0.0:
			_radio_panel.visible = false
	if _radio_left <= 0.0 and not _radio_queue.is_empty() and (started or _cine):
		var r: Dictionary = _radio_queue.pop_front()
		_radio_who.text = String(r["who"]).to_upper() + "  ·  Funk"
		_radio_who.add_theme_color_override("font_color", r["col"])
		_radio_text.text = String(r["text"])
		var secs: float = float(r["secs"])
		_radio_left = secs if secs > 0.0 else clamp(3.0 + String(r["text"]).length() / 16.0, 4.0, 11.0)
		var spoken: float = Audio.line(String(r["text"]))
		if spoken > 0.0:
			_radio_left = spoken + 0.9
			print("MISSION %s: gesprochen %.1f s | %s" % [m["id"], spoken, String(r["text"]).substr(0, 50)])
		_radio_panel.visible = true
		Audio.sfx("ui_click", 0.0, 1.3)

func _show_briefing() -> void:
	get_tree().paused = true
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	_briefing = dim
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.05, 0.09, 0.15, 0.97), Color(0.4, 0.75, 1.0, 0.8)))
	p.custom_minimum_size = Vector2(700, 0)
	cc.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_lbl("EINSATZBESPRECHUNG", 12, Color(0.55, 0.78, 1.0)))
	v.add_child(_lbl(m["title"], 30, Color(1, 1, 1)))
	var t = _lbl(m["brief"], 16)
	t.custom_minimum_size = Vector2(660, 0)
	v.add_child(t)
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Ziele", 13, Color(0.55, 0.78, 1.0)))
	for o in _objs:
		v.add_child(_lbl(("•  " if not o.get("optional", false) else "○  ") + String(o["text"]), 14, Color(0.8, 0.88, 0.98) if not o.get("optional", false) else Color(0.62, 0.68, 0.75)))
	var b = Button.new()
	b.text = "Mission starten"
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(_start_mission)
	v.add_child(b)

func _start_mission() -> void:
	if _briefing != null:
		_briefing.queue_free()
		_briefing = null
	get_tree().paused = false
	_play_cine(m.get("intro", []), _begin_play)

func _begin_play() -> void:
	started = true
	t0 = Game.time
	kills0 = int(Game.players[0]["kills"])
	Audio.sfx("place")
	_refresh_objectives()

func _show_end(won: bool, text: String) -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.05, 0.09, 0.15, 0.97), Color(0.4, 1.0, 0.6, 0.8) if won else Color(1.0, 0.45, 0.4, 0.8)))
	p.custom_minimum_size = Vector2(560, 0)
	cc.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_lbl("AUFTRAG ERFÜLLT" if won else "AUFTRAG GESCHEITERT", 34, Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.45, 0.4)))
	v.add_child(_lbl(m["title"], 18, Color(0.8, 0.88, 0.98)))
	if text != "":
		v.add_child(_lbl(text, 15))
	v.add_child(_lbl("Dauer %d:%02d · Abschüsse %d · Verluste %d" % [int(Game.time - t0) / 60, int(Game.time - t0) % 60, int(Game.players[0]["kills"]) - kills0, int(Game.players[0]["losses"])], 14, Color(0.7, 0.8, 0.9)))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var nxt: String = String(m.get("next", ""))
	if won and nxt != "":
		row.add_child(_btn("Nächste Mission", func(): _go(nxt), true))
	row.add_child(_btn("Wiederholen", func(): _go(m["id"])))
	row.add_child(_btn("Kampagnenmenü", func(): _go("")))
	get_tree().paused = false

# ---------------------------------------------------------------- Filmsequenzen und Effekte

func _play_cine(steps: Array, on_done: Callable) -> void:
	# Tests (--missionauto) überspringen Filme, außer mit --cine
	if steps.is_empty() or (main != null and main.args.has("missionauto") and not main.args.has("cine")):
		on_done.call()
		return
	_cine = true
	_cine_steps = steps
	_cine_t = 0.0
	_cine_i = 0
	_cine_cb = on_done
	_cine_final = {}
	_cam_edge = Game.cam.edge_scroll
	Game.cam.edge_scroll = false
	Game.cam.set_process_unhandled_input(false)
	Game.hud.set_game_ui(false)
	_skip_hint.visible = true
	_refresh_objectives()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", 96.0, 0.8)
	tw.tween_property(_bar_bot, "offset_top", -96.0, 0.8)

func _process_bars() -> void:
	pass

func _cine_tick(delta: float) -> void:
	_process_bars()
	if _cine_end_pending and _radio_queue.is_empty() and _radio_left <= 0.0:
		_cine_end_pending = false
		_end_cine()
		return
	_cine_t += delta
	while _cine_i < _cine_steps.size() and float(_cine_steps[_cine_i]["t"]) <= _cine_t:
		_do(_cine_steps[_cine_i])
		_cine_i += 1
		if not _cine:
			return

func _end_cine() -> void:
	if not _cine:
		return
	_cine = false
	for tw in _cine_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_cine_tweens.clear()
	if _cine_final.has("pos"):
		Game.cam.look_at_pos(_cine_final["pos"])
		Game.cam.yaw = _cine_final["yaw"]
		Game.cam.dist_target = _cine_final["dist"]
		Game.cam.pitch = _cine_final["pitch"]
	_radio_queue.clear()
	_radio_left = 0.0
	_cine_end_pending = false
	Audio.stop_line()
	_radio_panel.visible = false
	_title_box.modulate.a = 0.0
	Game.cam.edge_scroll = _cam_edge
	Game.cam.set_process_unhandled_input(true)
	Game.hud.set_game_ui(true)
	_skip_hint.visible = false
	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(_bar_top, "offset_bottom", 0.0, 0.6)
	tw2.tween_property(_bar_bot, "offset_top", 0.0, 0.6)
	var cb = _cine_cb
	_cine_cb = Callable()
	if cb.is_valid():
		cb.call()

func _unhandled_input(event: InputEvent) -> void:
	if _cine and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			_end_cine()

func _target_pos(a: Dictionary) -> Vector3:
	if a.has("tag"):
		var us = _alive(a["tag"])
		if not us.is_empty():
			return us[0].position
		return Game.cam.position
	return _pos(a["at"])

func _cam_to(a: Dictionary) -> void:
	var p: Vector3 = _target_pos(a)
	var secs: float = float(a.get("time", 3.0))
	var yaw: float = deg_to_rad(float(a.get("yaw", rad_to_deg(Game.cam.yaw))))
	var pitch: float = deg_to_rad(float(a.get("pitch", rad_to_deg(Game.cam.pitch))))
	var dist: float = float(a.get("dist", Game.cam.dist_target))
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(Game.cam, "position:x", p.x, secs)
	tw.tween_property(Game.cam, "position:z", p.z, secs)
	tw.tween_property(Game.cam, "yaw", yaw, secs)
	tw.tween_property(Game.cam, "pitch", pitch, secs)
	tw.tween_property(Game.cam, "dist_target", dist, secs)
	_cine_tweens.append(tw)
	_cine_final = {"pos": p, "yaw": yaw, "pitch": pitch, "dist": dist}

func _title(text: String, sub: String, secs: float) -> void:
	_title_a.text = text
	_title_b.text = sub
	var tw = create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.9)
	tw.tween_interval(max(0.5, secs - 1.8))
	tw.tween_property(_title_box, "modulate:a", 0.0, 0.9)
	_cine_tweens.append(tw)
	Audio.sfx("stinger", -2.0)

func _banner(text: String, secs: float, col: Color) -> void:
	_banner_l.text = text
	_banner_l.add_theme_color_override("font_color", col)
	var tw = create_tween()
	tw.tween_property(_banner_l, "modulate:a", 1.0, 0.35)
	tw.tween_interval(max(0.3, secs - 0.9))
	tw.tween_property(_banner_l, "modulate:a", 0.0, 0.55)
	Audio.sfx("stinger", -6.0, 1.4)

func _flash_screen(col: Color, secs: float) -> void:
	_flash.color = Color(col.r, col.g, col.b, 0.85)
	var tw = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, secs)

func _btn(text: String, cb: Callable, big := false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170 if big else 150, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b

func _go(id: String) -> void:
	Game.pending_mission = id
	Game.pending_menu = id == ""
	get_tree().paused = false
	get_tree().reload_current_scene()
