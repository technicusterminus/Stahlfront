extends Node
## Spielereingaben: Auswahl, Befehle, Bauplatzierung, Zielmodi, Kontrollgruppen.

const FX = preload("res://scripts/fx.gd")
const Models = preload("res://scripts/models.gd")

signal selection_changed

var selection: Array = []
var groups = {}
var mode = ""            # "", "place", "attackmove", "power", "super"
var place_id = ""
var place_ok = ""
var place_center = Vector2i.ZERO
var ghost: Node3D
var power_data = null
var super_bld = null
var hover = null
var hover_ground = null
var drag_start = Vector2.ZERO
var dragging = false
var box_active = false
var _press_t = 0.0
var _last_click_t = -1.0
var _last_click_obj = null
var _last_group_t = {}
var hint = ""

func cam() -> Camera3D:
	return Game.cam.cam

func ground_at(mp: Vector2):
	var c = cam()
	return Game.terrain.raycast(c.project_ray_origin(mp), c.project_ray_normal(mp))

func pick(mp: Vector2):
	var c = cam()
	var best = null
	var bd = 1e9
	for u in Game.units:
		if not u.alive or not u.visible:
			continue
		var ap: Vector3 = u.aim_point()
		if c.is_position_behind(ap):
			continue
		var sp = c.unproject_position(ap)
		var sp2 = c.unproject_position(ap + c.global_basis.x * u.radius)
		var rpx: float = max(13.0, sp.distance_to(sp2) * 1.25)
		var d = sp.distance_to(mp)
		if d < rpx and d < bd:
			bd = d
			best = u
	if best != null:
		return best
	var o = c.project_ray_origin(mp)
	var n = c.project_ray_normal(mp)
	for b in Game.buildings + Game.depots:
		if not b.alive or not b.visible:
			continue
		var h: float = b.height if b.is_building else 2.5
		var hx: float = b.half if b.is_building else 2.6
		for frac in [0.0, 0.5, 0.95]:
			var y: float = b.position.y + h * frac
			if abs(n.y) < 0.001:
				continue
			var t = (y - o.y) / n.y
			if t <= 0.0:
				continue
			var p = o + n * t
			if abs(p.x - b.position.x) <= hx and abs(p.z - b.position.z) <= hx:
				return b
	return null

func own(o) -> bool:
	return o != null and is_instance_valid(o) and not o.is_depot and o.owner_id == Game.human and not Game.spectator

# ---------------------------------------------------------------- Auswahl

func set_selection(arr: Array) -> void:
	for o in selection:
		if is_instance_valid(o):
			o.set_selected(false)
	selection = []
	for o in arr:
		if is_instance_valid(o) and o.alive:
			selection.append(o)
			if not o.is_depot:
				o.set_selected(true)
	selection_changed.emit()
	_select_sound()

func _select_sound() -> void:
	if Game.spectator or selection.is_empty():
		return
	var us = selected_units()
	if not us.is_empty():
		Audio.voice(us[randi() % us.size()], "select")
	else:
		var b = single_building()
		if b != null:
			Audio.building_click(b)

## Einheitenstimme für einen Befehl: eine zufällige der betroffenen Einheiten spricht.
func _say(us: Array, kind: String) -> void:
	if not us.is_empty():
		Audio.voice(us[randi() % us.size()], kind)

func clean_selection() -> void:
	var changed = false
	for o in selection.duplicate():
		if not is_instance_valid(o) or not o.alive or (not own(o) and not o.visible):
			selection.erase(o)
			changed = true
	if changed:
		selection_changed.emit()

func selected_units() -> Array:
	return selection.filter(func(o): return own(o) and o.is_unit)

func selected_dozer():
	for o in selection:
		if own(o) and o.is_unit and o.def["role"] == "dozer":
			return o
	return null

func single_building():
	if selection.size() == 1 and own(selection[0]) and selection[0].is_building:
		return selection[0]
	return null

# ---------------------------------------------------------------- Ablauf

## Letzte bekannte Mausposition aus den Eingabeereignissen. Sie gilt auch für eingespeiste Ereignisse (Tests, Fernsteuerung),
## wenn das Fenster keinen Fokus hat und die echte Maus nicht bewegt wird.
var _mouse := Vector2.ZERO
var _mouse_seen := false

func mouse_pos() -> Vector2:
	return _mouse if _mouse_seen else get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = (event as InputEventMouse).position
		_mouse_seen = true

func _process(_delta: float) -> void:
	if not Game.running or Game.cam == null:
		return
	clean_selection()
	var mp = mouse_pos()
	var over_ui: bool = Game.hud != null and Game.hud.mouse_over_ui(mp)
	hover = null if over_ui else pick(mp)
	hover_ground = null if over_ui else ground_at(mp)
	hint = ""
	_update_ghost()
	_update_cursor()

func _update_cursor() -> void:
	var shape = Input.CURSOR_ARROW
	match mode:
		"place":
			shape = Input.CURSOR_DRAG
			if place_ok != "":
				hint = place_ok
		"attackmove":
			shape = Input.CURSOR_CROSS
			hint = "Angriffsbewegung: Ziel anklicken (Rechtsklick bricht ab)"
		"power", "super":
			shape = Input.CURSOR_CROSS
			hint = "Ziel anklicken (Rechtsklick oder Esc bricht ab)"
		_:
			if hover != null and not own(hover) and not hover.is_depot and not selected_units().is_empty():
				shape = Input.CURSOR_CROSS
			elif hover != null:
				shape = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(shape)

# ---------------------------------------------------------------- Platzierung

func begin_place(def_id: String) -> void:
	cancel_mode()
	var p: Dictionary = Game.players[Game.human]
	var d: Dictionary = Defs.buildings[def_id]
	var why = Game.afford_why(Game.human, d)
	if why != "":
		Game.notify("%s: %s." % [d["name"], why], Color(1, 0.6, 0.4))
		return
	mode = "place"
	place_id = def_id
	var m = Models.build_building(d, p["color"])
	ghost = m["root"]
	var gm = StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.3, 1.0, 0.4, 0.4)
	_ghostify(ghost, gm)
	ghost.set_meta("mat", gm)
	Game.fx_root.add_child(ghost)

func _ghostify(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		if c is GPUParticles3D or c is OmniLight3D:
			c.free()
		else:
			_ghostify(c, m)

func _update_ghost() -> void:
	if mode != "place" or ghost == null:
		return
	if hover_ground == null:
		ghost.visible = false
		return
	ghost.visible = true
	place_center = Game.world_to_cell(hover_ground)
	var d: Dictionary = Defs.buildings[place_id]
	var p = Game.footprint_center(place_center, d["size"])
	p.y = Game.terrain.height_at(p.x, p.z)
	ghost.global_position = p
	place_ok = Game.can_place(place_id, place_center, Game.human)
	if place_ok == "":
		place_ok = Game.afford_why(Game.human, d)
	var gm: StandardMaterial3D = ghost.get_meta("mat")
	gm.albedo_color = Color(0.3, 1.0, 0.4, 0.4) if place_ok == "" else Color(1.0, 0.25, 0.2, 0.45)

func _try_place(keep: bool) -> void:
	if place_ok != "" or hover_ground == null:
		Game.notify(place_ok if place_ok != "" else "Kein Bauplatz unter dem Mauszeiger.", Color(1, 0.6, 0.4))
		return
	var d: Dictionary = Defs.buildings[place_id]
	var p: Dictionary = Game.players[Game.human]
	Game.pay(Game.human, d)
	var b = Game.spawn_building(place_id, Game.human, place_center, false)
	var dozers = selection.filter(func(o): return own(o) and o.is_unit and o.def["role"] == "dozer")
	for dz in dozers:
		dz.cmd_build(b)
	FX.marker(b.position, Color(0.4, 1, 0.5))
	Audio.sfx("place")
	_say(dozers, "build")
	Game.notify("Bau von %s begonnen. Rechtsklick auf die Baustelle mit Bauarbeitern setzt fort; Abbrechen erstattet alles." % d["name"], Color(0.7, 0.9, 1.0))
	if not keep:
		cancel_mode()

func cancel_mode() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	mode = ""
	place_id = ""
	power_data = null
	super_bld = null

func begin_power(pw: Dictionary) -> void:
	cancel_mode()
	mode = "power"
	power_data = pw

func begin_super(b) -> void:
	cancel_mode()
	mode = "super"
	super_bld = b

func begin_attackmove() -> void:
	if selected_units().is_empty():
		return
	cancel_mode()
	mode = "attackmove"

# ---------------------------------------------------------------- Eingabe

func _unhandled_input(event: InputEvent) -> void:
	if not Game.running:
		return
	if event is InputEventMouseButton:
		_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and dragging:
		var mp = (event as InputEventMouseMotion).position
		box_active = mp.distance_to(drag_start) > 7.0
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)

func box_rect() -> Rect2:
	var mp = mouse_pos()
	return Rect2(drag_start, mp - drag_start).abs()

func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			match mode:
				"place":
					_try_place(mb.shift_pressed)
					return
				"attackmove":
					if hover_ground != null:
						command_at(hover_ground, hover, true)
					cancel_mode()
					return
				"power":
					if hover_ground != null:
						Game.powers.use(Game.human, power_data, hover_ground)
						FX.marker(hover_ground, Color(1, 0.85, 0.3))
					cancel_mode()
					return
				"super":
					if hover_ground != null:
						Game.powers.fire_super(super_bld, hover_ground)
					cancel_mode()
					return
			dragging = true
			box_active = false
			drag_start = mb.position
		else:
			if not dragging:
				return
			dragging = false
			if box_active:
				_box_select(mb.shift_pressed)
			else:
				_click_select(mb.shift_pressed, mb.ctrl_pressed)
			box_active = false
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if mode != "":
			cancel_mode()
			return
		if hover_ground != null or hover != null:
			command_at(hover_ground if hover_ground != null else hover.position, hover, false)

func _click_select(shift: bool, ctrl: bool) -> void:
	var o = hover
	var now = Time.get_ticks_msec() / 1000.0
	var dbl = o != null and o == _last_click_obj and now - _last_click_t < 0.35
	_last_click_t = now
	_last_click_obj = o
	if o == null:
		if not shift:
			set_selection([])
		return
	if dbl or ctrl:
		if own(o) and o.is_unit:
			select_same_type_on_screen(o.def["id"])
			return
	if shift and own(o):
		var arr = selection.duplicate()
		if arr.has(o):
			arr.erase(o)
		else:
			arr = arr.filter(func(x): return own(x))
			arr.append(o)
		set_selection(arr)
	else:
		set_selection([o])

func select_same_type_on_screen(def_id: String) -> void:
	var vs = get_viewport().get_visible_rect()
	var arr: Array = []
	for u in Game.units:
		if own(u) and u.def["id"] == def_id:
			var ap: Vector3 = u.aim_point()
			if not cam().is_position_behind(ap) and vs.has_point(cam().unproject_position(ap)):
				arr.append(u)
	set_selection(arr)

func _box_select(shift: bool) -> void:
	var r = box_rect()
	var arr: Array = selection.duplicate() if shift else []
	arr = arr.filter(func(x): return own(x) and x.is_unit)
	var found: Array = []
	for u in Game.units:
		if not own(u):
			continue
		var ap: Vector3 = u.aim_point()
		if cam().is_position_behind(ap):
			continue
		if r.has_point(cam().unproject_position(ap)):
			found.append(u)
	# Kampfeinheiten bevorzugen, wenn gemischt mit Sammlern
	var combat = found.filter(func(u): return u.def["role"] == "combat")
	if not combat.is_empty() and combat.size() != found.size():
		found = combat
	for u in found:
		if not arr.has(u):
			arr.append(u)
	set_selection(arr)

# ---------------------------------------------------------------- Befehle

func command_at(g: Vector3, obj, attack: bool) -> void:
	var us = selected_units()
	if us.is_empty():
		var b = single_building()
		if b != null and not b.def["produces"].is_empty():
			b.rally = g
			b.has_rally = true
			FX.marker(g, Color(0.4, 0.8, 1.0))
			Game.notify("Sammelpunkt gesetzt.", Color(0.7, 0.9, 1.0))
		return
	if obj != null and is_instance_valid(obj) and not obj.is_depot and Game.enemies(Game.human, obj.owner_id):
		for u in us:
			if u.can_target(obj):
				u.cmd_attack(obj)
			else:
				u.cmd_move(obj.position)
		FX.marker(obj.position, Color(1, 0.3, 0.25))
		_say(us, "attack")
		return
	if obj != null and is_instance_valid(obj) and obj.is_depot:
		var others: Array = []
		for u in us:
			if u.def["role"] == "harvester":
				u.cmd_harvest(obj)
			else:
				others.append(u)
		FX.marker(obj.position, Color(1, 0.85, 0.3))
		_say(us, "harvest")
		if not others.is_empty():
			_formation_move(others, obj.position + Vector3(0, 0, 6), false)
		return
	if obj != null and own(obj) and obj.is_building:
		var rest: Array = []
		for u in us:
			if u.def["role"] == "dozer" and (not obj.complete or obj.hp < obj.max_hp):
				u.cmd_build(obj)
			elif u.def["role"] == "harvester" and obj.def["role"] == "supply":
				u.h_home = obj
				u.cmd_harvest()
			else:
				rest.append(u)
		FX.marker(obj.position, Color(0.4, 1, 0.5))
		_say(us, "build" if rest.size() < us.size() else "move")
		if not rest.is_empty():
			_formation_move(rest, g, attack)
		return
	_formation_move(us, g, attack)
	FX.marker(g, Color(1, 0.4, 0.3) if attack else Color(0.4, 1, 0.5))
	_say(us, "attack" if attack else "move")

func _formation_move(us: Array, g: Vector3, attack: bool) -> void:
	var n = us.size()
	if n == 1:
		us[0].cmd_move(g, attack)
		return
	var centroid = Vector3.ZERO
	for u in us:
		centroid += u.position
	centroid /= n
	var dir = Vector3(g.x - centroid.x, 0, g.z - centroid.z)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var right = Vector3(dir.z, 0, -dir.x)
	var cols = int(ceil(sqrt(n * 1.5)))
	# Abstand nach der größten Einheit der Gruppe: Soldaten eng, Panzer mit Luft dazwischen
	var biggest := 0.0
	for u in us:
		biggest = maxf(biggest, float(u.radius))
	var spacing := maxf(2.6, biggest * 2.0 + 1.6)
	# Sortieren: Einheiten links/rechts passend zu ihrem Platz
	us.sort_custom(func(a, b): return (a.position - centroid).dot(right) < (b.position - centroid).dot(right))
	for i in n:
		var row = i / cols
		var col = i % cols
		var off = right * (col - (cols - 1) * 0.5) * spacing - dir * row * spacing
		us[i].cmd_move(g + off, attack)

# ---------------------------------------------------------------- Tasten

func _key(k: InputEventKey) -> void:
	var code = k.keycode
	if code == KEY_ESCAPE:
		if mode != "":
			cancel_mode()
		elif Game.hud != null:
			Game.hud.toggle_pause()
		return
	if code == KEY_F8:
		Audio.toggle()
		return
	if Game.spectator and code != KEY_SPACE and code != KEY_F1:
		return
	if code >= KEY_0 and code <= KEY_9:
		var gi = int(code - KEY_0)
		if k.ctrl_pressed:
			groups[gi] = selection.filter(func(o): return own(o) and o.is_unit)
			Game.notify("Gruppe %d gespeichert (%d Einheiten)." % [gi, groups[gi].size()], Color(0.7, 0.9, 1.0))
		elif groups.has(gi):
			var arr: Array = groups[gi].filter(func(o): return is_instance_valid(o) and o.alive)
			groups[gi] = arr
			if k.shift_pressed:
				for o in selection:
					if not arr.has(o) and own(o):
						arr.append(o)
			set_selection(arr)
			var now = Time.get_ticks_msec() / 1000.0
			if now - float(_last_group_t.get(gi, -9.0)) < 0.4 and not arr.is_empty():
				Game.cam.look_at_pos(arr[0].position)
			_last_group_t[gi] = now
		return
	match code:
		KEY_S:
			for u in selected_units():
				u.cmd_stop()
		KEY_A:
			if k.ctrl_pressed:
				var arr: Array = Game.units.filter(func(u): return own(u) and u.def["role"] == "combat")
				set_selection(arr)
			else:
				begin_attackmove()
		KEY_SPACE:
			Game.cam.look_at_pos(Game.last_alert_pos)
		KEY_H:
			for b in Game.buildings:
				if b.owner_id == Game.human and b.def["role"] == "hq":
					Game.cam.look_at_pos(b.position)
					set_selection([b])
					break
		KEY_F1:
			if Game.hud != null:
				Game.hud.toggle_help()
		KEY_G:
			if Game.hud != null:
				Game.hud.toggle_powers()
