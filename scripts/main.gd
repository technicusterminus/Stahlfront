extends Node
## Einstieg: baut Welt, Licht, Gelände, Kamera, Oberfläche und startet Gefechte.
## Testschalter (nach "--"): --autostart --demo --faction=red --enemies=2 --difficulty=2
##   --seed=N --speed=N --quit=SEK --shot=PFAD --shotdelay=SEK --camat=X,Z

const AIScript = preload("res://scripts/ai.gd")
const CameraScript = preload("res://scripts/camera_rts.gd")
const ControllerScript = preload("res://scripts/controller.gd")
const HUDScript = preload("res://scripts/hud.gd")
const TerrainScript = preload("res://scripts/terrain.gd")
const PowersScript = preload("res://scripts/powers.gd")

const STARTS := [Vector2(-82, 82), Vector2(82, -82), Vector2(82, 82), Vector2(-82, -82)]
const MID_DEPOTS := [Vector2(0, 28), Vector2(0, -78), Vector2(0, 78), Vector2(-78, 0), Vector2(78, 0)]

var args = {}
var world: Node3D
var sun: DirectionalLight3D

func _ready() -> void:
	_parse_args()
	Game.reset_match()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	_environment()
	var base_depots = []
	var res_sites = []   # [Vector2, Art, Menge]
	for s in STARTS:
		var dd: Vector2 = s * 0.72
		base_depots.append(dd)
		var perp = Vector2(-dd.y, dd.x).normalized()
		res_sites.append([dd + perp * 21.0, "wood", 20000.0])
		res_sites.append([dd - perp * 21.0, "iron", 20000.0])
		res_sites.append([dd * 1.18, "oil", 16000.0])
	for g in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		res_sites.append([g, "gold", 9000.0])
	var res_pts = res_sites.map(func(r): return r[0])
	var seed_val = int(args.get("seed", str(randi() % 100000)))
	var terrain = TerrainScript.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	Game.terrain = terrain
	terrain.generate(seed_val, STARTS, base_depots + MID_DEPOTS + res_pts)
	Game.init_grid()
	Game.units_root = Node3D.new()
	Game.units_root.name = "Units"
	world.add_child(Game.units_root)
	Game.fx_root = Node3D.new()
	Game.fx_root.name = "FX"
	world.add_child(Game.fx_root)
	for d in base_depots:
		Game.spawn_depot(Vector3(d.x, 0, d.y), 45000.0)
	for i in MID_DEPOTS.size():
		var d: Vector2 = MID_DEPOTS[i]
		Game.spawn_depot(Vector3(d.x, 0, d.y), 80000.0 if i == 0 else 50000.0)
	for rs in res_sites:
		Game.spawn_depot(Vector3(rs[0].x, 0, rs[0].y), rs[2], rs[1])
	var animals = load("res://scripts/animals.gd").new()
	animals.name = "Animals"
	world.add_child(animals)
	animals.setup(seed_val, STARTS)
	var cam = CameraScript.new()
	cam.name = "Camera"
	world.add_child(cam)
	Game.cam = cam
	Game.powers = PowersScript.new()
	add_child(Game.powers)
	var ctrl = ControllerScript.new()
	ctrl.name = "Controller"
	add_child(ctrl)
	Game.ctrl = ctrl
	var hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)
	Game.hud = hud
	hud.start_requested.connect(start_match)
	if args.has("speed"):
		Engine.time_scale = float(args["speed"])
	if args.has("autostart") or args.has("demo"):
		start_match({"faction": args.get("faction", "west"), "enemies": int(args.get("enemies", "1")),
			"difficulty": int(args.get("difficulty", "1")), "spectate": args.has("demo")})
	else:
		cam.orbit = true
		cam.look_at_pos(Vector3.ZERO)
		Game.spectator = true
		Game.update_fog()
		hud.show_menu()
	if args.has("uitest"):
		_ui_test()
	if args.has("shot"):
		_take_shot(args["shot"], float(args.get("shotdelay", "6")))
	if args.has("quit"):
		_quit_after(float(args["quit"]))

var _bc_t = 0.0

func _process(delta: float) -> void:
	if args.has("battlecam") and Game.running:
		_bc_t -= delta
		if _bc_t <= 0.0 and Game.last_combat_pos != Vector3.ZERO:
			_bc_t = 3.0
			Game.cam.look_at_pos(Game.last_combat_pos)
			Game.cam.dist_target = 48.0

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var kv = s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"

func _environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var psm = ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.26, 0.42, 0.68)
	psm.sky_horizon_color = Color(0.7, 0.72, 0.74)
	psm.ground_horizon_color = Color(0.6, 0.6, 0.58)
	psm.ground_bottom_color = Color(0.2, 0.2, 0.18)
	psm.sun_angle_max = 20.0
	psm.sun_curve = 0.1
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.68, 0.76)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.9)
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_anisotropy = 0.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we = WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.5
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.light_volumetric_fog_energy = 1.2
	world.add_child(sun)

func start_match(cfg: Dictionary) -> void:
	Game.spectator = cfg["spectate"]
	Game.difficulty = cfg["difficulty"]
	Game.human = 0
	var facs = ["west", "red", "shadow"]
	var mine: String = cfg["faction"]
	var n_enemies: int = clampi(cfg["enemies"], 1, 3)
	Game.fog_vis.fill(0)
	Game.fog_exp.fill(0)
	var starts_used = [STARTS[0], STARTS[1]] if n_enemies == 1 else STARTS.slice(0, n_enemies + 1)
	for i in starts_used.size():
		var s: Vector2 = starts_used[i]
		var f: String = mine if i == 0 else facs[(facs.find(mine) + i) % 3]
		if Game.spectator and i > 0 and i == 1 and f == mine:
			f = facs[(facs.find(mine) + 1) % 3]
		var p = Game.add_player(f, i != 0 or Game.spectator, Vector3(s.x, 0, s.y))
		var hq_id: String = f + "_hq"
		var c = Game.world_to_cell(Vector3(s.x, 0, s.y))
		var hq = Game.spawn_building(hq_id, p["id"], c, true)
		var exit: Vector3 = hq.position + Vector3(0, 0, 8)
		var dz = Game.spawn_unit(Defs.dozer_of(f), p["id"], Game.cell_center(Game.nearest_free(Game.world_to_cell(exit))))
		dz.heading = 0.0
		if f == "shadow":
			var dz2 = Game.spawn_unit(Defs.dozer_of(f), p["id"], Game.cell_center(Game.nearest_free(Game.world_to_cell(exit + Vector3(3, 0, 0)))))
			dz2.heading = 0.0
		Game.recalc_power(p["id"])
	for p in Game.players:
		if p["ai"]:
			var ai = AIScript.new()
			ai.name = "AI_%d" % p["id"]
			add_child(ai)
			ai.setup(p["id"])
	var cam = Game.cam
	cam.orbit = false
	var st: Vector3 = Game.players[0]["start"]
	cam.look_at_pos(st + Vector3(0, 0, 14))
	cam.yaw = 0.0
	cam.dist_target = 62.0
	if args.has("camat"):
		var xz: PackedStringArray = String(args["camat"]).split(",")
		cam.look_at_pos(Vector3(float(xz[0]), 0, float(xz[1])))
	Game.last_alert_pos = st
	Game.explore(st, 48.0)
	Game.running = true
	Game.update_fog()
	Game.hud.on_match_started()
	if args.has("showcase"):
		# Testaufstellung: Einheiten beider Seiten nebeneinander vor der eigenen Basis
		var uid: String = args["showcase"]
		var base: Vector3 = st + Vector3(0, 0, 18)
		var i = 0
		for pl in [0, 1]:
			for k in 3:
				var fac: String = Game.players[pl]["faction"]
				var id = fac + "_" + uid if Defs.units.has(fac + "_" + uid) else "west_" + uid
				var u = Game.spawn_unit(id, pl, base + Vector3(-9 + i * 6.0, 0, pl * 9.0))
				u.heading = randf_range(-0.6, 0.6) + (PI if pl == 1 else 0.0)
				i += 1
		cam.look_at_pos(base + Vector3(0, 0, 4))
		cam.dist_target = float(args.get("camdist", "34"))
		Game.explore(base, 30.0)
	if args.has("seashow"):
		# Testaufstellung: Werft und alle Schiffe in der Heimatbucht jedes Spielers
		for pl in Game.players.size():
			var s0: Vector3 = Game.players[pl]["start"]
			var bay = Vector3(s0.x * 0.6, 0, s0.z * 0.6)
			Game.explore(bay, 30.0)
			var fac1: String = Game.players[pl]["faction"]
			var did: String = fac1 + "_dock"
			var done = false
			for ring in range(5, 24):
				for j in 16:
					var a1 = TAU * j / 16.0 + ring * 0.3
					var p1 = bay + Vector3(cos(a1), 0, sin(a1)) * ring
					var c1 = Game.world_to_cell(p1)
					if Game.can_place(did, c1, pl) == "":
						Game.spawn_building(did, pl, c1, true)
						done = true
						break
				if done:
					break
			print("SEASHOW Werft ", fac1, " gebaut=", done)
			var sids = Defs.units.keys().filter(func(k): return Defs.units[k]["faction"] == fac1 and Defs.units[k]["naval"])
			for si in sids.size():
				Game.spawn_unit(sids[si], pl, bay + Vector3(-3 + si * 6.0, 0, 0))
		var b0: Vector3 = Game.players[0]["start"]
		cam.look_at_pos(Vector3(b0.x * 0.6, 0, b0.z * 0.6))
		cam.dist_target = float(args.get("camdist", "40"))
	if args.has("basecam"):
		# Testbasis: alle Gebäudetypen fertig, das letzte als Baustelle
		var fac0: String = Game.players[0]["faction"]
		var ids: Array = Defs.build_list(fac0).filter(func(i): return not i.ends_with("_hq"))
		var hqp: Vector3 = Game.players[0]["start"]
		var k = 0
		for id in ids:
			var placed = false
			for ring in range(5, 30):
				for j in 12:
					var a = TAU * j / 12.0 + ring * 0.37
					var p = hqp + Vector3(cos(a), 0, sin(a)) * ring * 2.2
					var c = Game.world_to_cell(p)
					var ok = Game.can_place(id, c, 0) == ""
					if ok:
						for fc in Game.footprint(c, int(Defs.buildings[id]["size"]) + 2):
							if not Game.is_free(fc):
								ok = false
								break
					if ok:
						var b = Game.spawn_building(id, 0, c, k < ids.size() - 1)
						if k == ids.size() - 1:
							b.construct(Defs.buildings[id]["time"] * 0.45)
						placed = true
						break
				if placed:
					break
			k += 1
		Game.explore(hqp, 70.0)
		Game.recalc_power(0)
		cam.look_at_pos(hqp + Vector3(0, 0, 6))
		cam.dist_target = float(args.get("camdist", "70"))
	if args.has("firetest"):
		var fp: Vector3 = Game.players[0]["start"] + Vector3(14, 0, 14)
		var holder = Node3D.new()
		holder.position = Vector3(fp.x, Game.terrain.ground_y(fp.x, fp.z), fp.z)
		Game.fx_root.add_child(holder)
		load("res://scripts/fx.gd").flame(holder, Vector3.ZERO, float(args["firetest"]))
		var fimg: Image = load("res://scripts/fx.gd")._flame_tex().get_image()
		fimg.decompress()
		var big = Image.create(96, 160, false, Image.FORMAT_RGBA8)
		big.fill(Color(0.1, 0.1, 0.15))
		big.blend_rect(fimg, Rect2i(0, 0, 96, 160), Vector2i(0, 0))
		big.save_png("res://shots/flame_tex.png")
		Game.explore(fp, 20.0)
		cam.look_at_pos(fp)
		cam.dist_target = 14.0
	if args.has("recoiltest"):
		_recoil_test()
	if args.has("animalcam"):
		var an = world.get_node("Animals")
		if not an.herds.is_empty():
			cam.look_at_pos(an.herds[0]["center"])
			cam.dist_target = 26.0
	if args.has("selectdozer"):
		for u in Game.units:
			if u.owner_id == 0 and u.def["role"] == "dozer":
				Game.ctrl.set_selection([u])
				break
	if not Game.spectator:
		Game.notify("Willkommen, General. Wähle den Bauarbeiter und errichte ein Nachschubzentrum am Depot.", Color(0.8, 0.9, 1.0))

# ---------------------------------------------------------------- Bedientest (nur mit --uitest)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	Input.warp_mouse(pos)
	var mm = InputEventMouseMotion.new()
	mm.position = pos
	Input.parse_input_event(mm)
	await _wait(0.15)
	for pressed in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.05)

func _check(ok: bool, what: String) -> void:
	print(("UITEST OK   " if ok else "UITEST FAIL ") + what)

func _ui_test() -> void:
	await _wait(1.5)
	var cam = Game.cam
	var dozer = null
	for u in Game.units:
		if u.owner_id == 0 and u.def["role"] == "dozer":
			dozer = u
	# 1) Bauarbeiter per Klick auswaehlen
	cam.look_at_pos(dozer.position)
	await _wait(0.8)
	await _click(cam.cam.unproject_position(dozer.aim_point()))
	await _wait(0.3)
	_check(Game.ctrl.selection.has(dozer), "Bauarbeiter per Linksklick ausgewaehlt")
	# 2) Nachschubzentrum platzieren
	var fac: String = Game.players[0]["faction"]
	var sid: String = fac + "_supply"
	var depot = null
	var bd = 1e9
	for dp in Game.depots.filter(func(x): return x.kind == "supply"):
		var d = Game.flat_dist(dp.position, dozer.position)
		if d < bd:
			bd = d
			depot = dp
	var site = null
	for r in range(6, 12):
		for k in 16:
			var a = TAU * k / 16.0
			var p = depot.position + Vector3(cos(a), 0, sin(a)) * r * 1.2
			if Game.can_place(sid, Game.world_to_cell(p), 0) == "":
				site = p
				break
		if site != null:
			break
	_check(site != null, "freier Bauplatz am Depot gefunden")
	cam.look_at_pos(site)
	await _wait(0.8)
	Game.hud._on_cmd("build", sid)
	await _wait(0.2)
	_check(Game.ctrl.mode == "place", "Platzierungsmodus aktiv")
	var sp = cam.cam.unproject_position(Vector3(site.x, Game.terrain.height_at(site.x, site.z), site.z))
	Input.warp_mouse(sp)
	await _wait(0.4)
	var credits_before: float = Game.players[0]["credits"]
	await _click(sp)
	await _wait(0.4)
	var site_b = null
	for b in Game.buildings:
		if b.owner_id == 0 and b.def["id"] == sid:
			site_b = b
	_check(site_b != null, "Baustelle angelegt")
	_check(Game.players[0]["credits"] == credits_before - Defs.buildings[sid]["cost"], "Kosten abgebucht")
	_check(dozer.order == "build", "Bauarbeiter hat Bauauftrag")
	Engine.time_scale = 6.0
	await _wait(5.0)
	Engine.time_scale = 1.0
	_check(site_b != null and site_b.complete, "Nachschubzentrum fertig gebaut")
	var harv = Game.units.filter(func(u): return u.owner_id == 0 and u.def["role"] == "harvester")
	_check(harv.size() == 1, "Gratis-Sammler erhalten")
	# 3) Kaserne/Kraftwerk ueberspringen: Einheiten direkt erzeugen und per Rahmen + Rechtsklick bewegen
	var squad: Array = []
	for i in 5:
		squad.append(Game.spawn_unit(fac + "_inf", 0, site + Vector3(4 + i * 1.5, 0, 6)))
	cam.look_at_pos(site + Vector3(7, 0, 6))
	await _wait(0.8)
	var a2 = cam.cam.unproject_position(site + Vector3(1, 0, 3))
	var b2 = cam.cam.unproject_position(site + Vector3(13, 0, 9))
	Input.warp_mouse(a2)
	var ev = InputEventMouseButton.new()
	ev.position = a2
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.1)
	var mm = InputEventMouseMotion.new()
	mm.position = b2
	Input.warp_mouse(b2)
	Input.parse_input_event(mm)
	await _wait(0.1)
	var ev2 = InputEventMouseButton.new()
	ev2.position = b2
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await _wait(0.3)
	var sel_ok = true
	for s in squad:
		if not Game.ctrl.selection.has(s):
			sel_ok = false
	_check(sel_ok, "Rahmenauswahl erfasst alle 5 Soldaten (%d gewaehlt)" % Game.ctrl.selection.size())
	var goal = site + Vector3(-10, 0, 14)
	await _click(cam.cam.unproject_position(goal), MOUSE_BUTTON_RIGHT)
	await _wait(0.3)
	_check(squad.all(func(s): return s.order == "move"), "Rechtsklick gibt Marschbefehl")
	await _wait(6.0)
	var arrived = squad.filter(func(s): return Game.flat_dist(s.position, goal) < 7.0).size()
	_check(arrived >= 4, "Soldaten am Ziel angekommen (%d/5)" % arrived)
	# 4) Strg+1 und Taste 1
	var k = InputEventKey.new()
	k.keycode = KEY_1
	k.ctrl_pressed = true
	k.pressed = true
	Input.parse_input_event(k)
	await _wait(0.1)
	Game.ctrl.set_selection([])
	var k2 = InputEventKey.new()
	k2.keycode = KEY_1
	k2.pressed = true
	Input.parse_input_event(k2)
	await _wait(0.2)
	_check(Game.ctrl.selection.size() == 5, "Kontrollgruppe 1 gespeichert und abgerufen")
	for o in Game.units + Game.buildings:
		if o.owner_id == 0 and o.hp < o.max_hp - 0.5:
			print("UITEST INFO beschaedigt: %s hp=%.1f/%.1f" % [o.def["name"], o.hp, o.max_hp])
	print("UITEST ENDE")

func _take_shot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)

func _quit_after(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout
	print("=== STATUS nach %.0f s Spielzeit, %d FPS ===" % [Game.time, Engine.get_frames_per_second()])
	for p in Game.players:
		var nu = 0
		var nb = 0
		for u in Game.units:
			if u.owner_id == p["id"]:
				nu += 1
		for b in Game.buildings:
			if b.owner_id == p["id"]:
				nb += 1
		print("P%d %s alive=%s credits=%d units=%d bldgs=%d kills=%d losses=%d income=%d rank=%d ships=%d docks=%d res=%s" % [p["id"], p["faction"], p["alive"], int(p["credits"]), nu, nb, p["kills"], p["losses"], int(p["income"]), p["rank"], Game.units.filter(func(u): return u.owner_id == p["id"] and u.alive and u.naval).size(), Game.buildings.filter(func(b): return b.owner_id == p["id"] and b.alive and b.def["role"] == "dock").size(), str(p["res"].values().map(func(v): return int(v)))])
	get_tree().quit()

## Messung: bewegt sich beim Schuss nur das Rohr, nicht der Turm?
func _recoil_test() -> void:
	await _wait(1.0)
	var st: Vector3 = Game.players[0]["start"] + Vector3(0, 0, 30)
	for id in ["west_tank", "red_tank", "red_arty", "west_aa", "red_heavy"]:
		var u = Game.spawn_unit(id, 0, st + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
		u.visible = true
		await _wait(0.2)
		var br = u.model.get("barrel")
		if br == null:
			print("RECOIL ", id, ": KEIN ROHR-OBJEKT")
			continue
		var tr = u.turret
		var t0 = tr.position
		var b0: Vector3 = br.position
		u._recoil()
		await _wait(0.06)
		var b1: Vector3 = br.position
		var t1 = tr.position
		await _wait(0.5)
		var b2: Vector3 = br.position
		print("RECOIL %s: Rohr %s -> %s -> %s | Turm bewegt: %s" % [id, b0, b1, b2, str(t1.distance_to(t0) > 0.001)])