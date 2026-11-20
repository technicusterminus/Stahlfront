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
			flags[a["f"]] = true
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
	if main != null and main.args.has("missionplay") and started and not finished:
		_autoplay()
	_radio_tick(delta)
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

func _refresh_objectives() -> void:
	var panel: Control = _obj_box.get_parent()
	panel.visible = started and not finished
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
	if _radio_left <= 0.0 and not _radio_queue.is_empty() and started:
		var r: Dictionary = _radio_queue.pop_front()
		_radio_who.text = String(r["who"]).to_upper() + "  ·  Funk"
		_radio_who.add_theme_color_override("font_color", r["col"])
		_radio_text.text = String(r["text"])
		var secs: float = float(r["secs"])
		_radio_left = secs if secs > 0.0 else clamp(3.0 + String(r["text"]).length() / 16.0, 4.0, 11.0)
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
	started = true
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
