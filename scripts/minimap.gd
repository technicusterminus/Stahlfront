extends Control
## Minikarte: Gelände, Nebel, Objekte, Kamerasicht. Linksklick bewegt Kamera, Rechtsklick gibt Befehl.

var terrain_tex: ImageTexture
var fog_img: Image
var fog_tex: ImageTexture
var _t = 0.0
var _drag = false
var frame_style = "west"

func _ready() -> void:
	custom_minimum_size = Vector2(212, 212)
	mouse_filter = Control.MOUSE_FILTER_STOP
	fog_img = Image.create(Game.GRID, Game.GRID, false, Image.FORMAT_RGBA8)
	fog_tex = ImageTexture.create_from_image(fog_img)

func set_terrain(img: Image) -> void:
	terrain_tex = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.3
		_update_fog()
	queue_redraw()

func _update_fog() -> void:
	var data = PackedByteArray()
	data.resize(Game.GRID * Game.GRID * 4)
	for i in Game.GRID * Game.GRID:
		var a = 0
		if Game.fog_vis[i] == 0:
			a = 120 if Game.fog_exp[i] == 1 else 235
		data[i * 4] = 4
		data[i * 4 + 1] = 6
		data[i * 4 + 2] = 8
		data[i * 4 + 3] = a
	fog_img.set_data(Game.GRID, Game.GRID, false, Image.FORMAT_RGBA8, data)
	if fog_tex.get_width() == Game.GRID and fog_tex.get_height() == Game.GRID:
		fog_tex.update(fog_img)
	else:
		fog_tex.set_image(fog_img)

func w2m(p: Vector3) -> Vector2:
	return Vector2((p.x + Game.HALF) / (Game.HALF * 2.0) * size.x, (p.z + Game.HALF) / (Game.HALF * 2.0) * size.y)

func m2w(m: Vector2) -> Vector3:
	var x = m.x / size.x * Game.HALF * 2.0 - Game.HALF
	var z = m.y / size.y * Game.HALF * 2.0 - Game.HALF
	return Vector3(x, Game.terrain.ground_y(x, z), z)

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	if terrain_tex:
		draw_texture_rect(terrain_tex, r, false)
	for dp in Game.depots:
		if Game.is_explored(dp.position) and dp.supply > 0:
			draw_rect(Rect2(w2m(dp.position) - Vector2(3, 3), Vector2(6, 6)), Defs.RES_COLORS[dp.kind].lightened(0.2))
	for b in Game.buildings:
		if not b.alive or not b.visible:
			continue
		var c: Color = Game.players[b.owner_id]["color"]
		var s: float = b.half * 2.0 / (Game.HALF * 2.0) * size.x + 2.0
		draw_rect(Rect2(w2m(b.position) - Vector2(s, s) * 0.5, Vector2(s, s)), c.lightened(0.15))
	draw_texture_rect(fog_tex, r, false)
	for u in Game.units:
		if not u.alive or not u.visible:
			continue
		var c: Color = Game.players[u.owner_id]["color"]
		var p = w2m(u.position)
		if u.selected:
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1, 1, 1))
		else:
			draw_rect(Rect2(p - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), c.lightened(0.3))
	# Kamerasicht
	var cam: Camera3D = Game.cam.cam
	var vs = get_viewport().get_visible_rect().size
	var pts: Array = []
	for sc in [Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y - 236), Vector2(0, vs.y - 236)]:
		var o = cam.project_ray_origin(sc)
		var n = cam.project_ray_normal(sc)
		if n.y >= -0.01:
			n.y = -0.01
		var t = (Game.cam.position.y - o.y) / n.y
		var gp = o + n * t
		pts.append(w2m(gp))
	for i in 4:
		draw_line(pts[i], pts[(i + 1) % 4], Color(1, 1, 1, 0.8), 1.5)
	# Alarm
	if Game.time - Game._alert_t < 4.0 and int(Game.time * 4) % 2 == 0:
		draw_arc(w2m(Game.last_alert_pos), 9.0, 0, TAU, 20, Color(1, 0.3, 0.2), 2.0)
	_frame(r)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				if Game.ctrl.mode == "attackmove" or Game.ctrl.mode == "power" or Game.ctrl.mode == "super":
					var g = m2w(mb.position)
					if Game.ctrl.mode == "attackmove":
						Game.ctrl.command_at(g, null, true)
					elif Game.ctrl.mode == "power":
						Game.powers.use(Game.human, Game.ctrl.power_data, g)
					else:
						Game.powers.fire_super(Game.ctrl.super_bld, g)
					Game.ctrl.cancel_mode()
					_drag = false
				else:
					Game.cam.look_at_pos(m2w(mb.position))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if Game.ctrl.mode != "":
				Game.ctrl.cancel_mode()
			elif not Game.spectator:
				Game.ctrl.command_at(m2w(mb.position), null, false)
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		Game.cam.look_at_pos(m2w((event as InputEventMouseMotion).position))
		accept_event()

## Kartenrahmen im Stil der Fraktion.
func _frame(r: Rect2) -> void:
	match frame_style:
		"red":
			draw_rect(r, Color(0.8, 0.62, 0.3), false, 3.5)
			draw_rect(r.grow(-3.0), Color(0.4, 0.07, 0.05), false, 1.5)
			for p in [r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), r.end - Vector2(6, 6)]:
				draw_circle(p, 3.0, Color(0.85, 0.66, 0.32))
		"shadow":
			draw_rect(r, Color(0.16, 0.1, 0.05), false, 6.0)
			draw_rect(r.grow(-3.0), Color(0.45, 0.3, 0.15), false, 1.5)
			for p in [r.position + Vector2(5, 5), Vector2(r.end.x - 5, r.position.y + 5), Vector2(r.position.x + 5, r.end.y - 5), r.end - Vector2(5, 5)]:
				draw_circle(p, 2.4, Color(0.3, 0.29, 0.28))
		_:
			draw_rect(r, Color(0.3, 0.7, 0.95, 0.45), false, 1.5)
			var l = 18.0
			var c = Color(0.55, 0.95, 1.0)
			for corner in [[r.position, 1, 1], [Vector2(r.end.x, r.position.y), -1, 1], [Vector2(r.position.x, r.end.y), 1, -1], [r.end, -1, -1]]:
				var p: Vector2 = corner[0]
				draw_line(p, p + Vector2(l * corner[1], 0), c, 2.5)
				draw_line(p, p + Vector2(0, l * corner[2]), c, 2.5)
