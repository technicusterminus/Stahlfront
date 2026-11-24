extends Node
## Einstieg: baut Welt, Licht, Gelände, Kamera, Oberfläche und startet Gefechte.
## Testschalter (nach "--"): --autostart --demo --faction=red --enemies=2 --difficulty=2
##   --seed=N --speed=N --quit=SEK --shot=PFAD --shotdelay=SEK --camat=X,Z --revealall --rain=0..1

const AIScript = preload("res://scripts/ai.gd")
const CameraScript = preload("res://scripts/camera_rts.gd")
const ControllerScript = preload("res://scripts/controller.gd")
const HUDScript = preload("res://scripts/hud.gd")
const TerrainScript = preload("res://scripts/terrain.gd")
const PowersScript = preload("res://scripts/powers.gd")

const Maps = preload("res://scripts/maps.gd")

var args = {}
var map_spec = {}
var starts_all: Array = []
var world: Node3D
var sun: DirectionalLight3D

## Fokus geht verloren (Klick aus dem Fenster, Alt+Tab) oder kommt zurück: Godot sieht dann das Loslassen der Maustaste
## nicht. Das Bedienelement, auf dem die Taste gedrückt wurde (z. B. die Übersichtskarte), behielt so den Mausfokus und
## schluckte jeden weiteren Klick – die Einheiten ließen sich nicht mehr steuern. Hier werden alle Zustände zurückgesetzt
## und ein künstliches Loslassen geschickt, damit kein Element den Mausfokus festhält.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		reset_input(true)
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		reset_input(false)

## force: nach Fokuswechsel gilt jede gedrückte Taste als veraltet. Sonst (Maus kommt zurück ins Fenster) nur zurücksetzen,
## wenn keine Taste gedrückt ist, damit ein echter Auswahlrahmen über den Rand hinaus erhalten bleibt.
func reset_input(force: bool) -> void:
	if not force and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)):
		return
	if Game.ctrl != null:
		Game.ctrl.dragging = false
		Game.ctrl.box_active = false
		Game.ctrl._mouse_seen = false
	if Game.cam != null:
		Game.cam._drag = false
	if Game.hud != null and Game.hud.minimap != null:
		Game.hud.minimap._drag = false
	if not is_inside_tree():
		return
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	for b in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if not force and Input.is_mouse_button_pressed(b):
			continue
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		ev.pressed = false
		ev.position = mp
		ev.global_position = mp
		Input.parse_input_event(ev)
	vp.gui_release_focus()

func _ready() -> void:
	_parse_args()
	if args.has("iconbake"):
		add_child(load("res://scripts/icon_bake.gd").new())
		return
	Game.reset_match()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	_environment()
	map_spec = Maps.clean(_spec_from_args())
	_build_world(map_spec)
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
		# Missionen: Testaufruf --mission=<id>, sonst die nächste Mission nach einem Szenenwechsel
		if Game.pending_mission != "":
			var pm: String = Game.pending_mission
			Game.pending_mission = ""
			hud.call_deferred("start_mission", pm)
		elif args.has("mission"):
			Game.mission_faction = String(args.get("faction", "west"))
			hud.call_deferred("start_mission", String(args["mission"]))
		elif Game.pending_menu:
			Game.pending_menu = false
			hud.call_deferred("_open_campaign_menu")
		if args.has("campaignmenu"):
			hud.call_deferred("_open_campaign_menu")
			_delayed_png(3.0, "ui_campaign.png")
		if args.has("mapdialog"):
			hud.call_deferred("_open_map_dialog", Label.new())
			_delayed_png(3.0, "ui_map.png")
		if args.has("menupick"):
			hud._cfg["map"] = Maps.preset(int(args["menupick"]))
			hud._cfg["hour"] = float(args.get("hour", "9"))
			hud.call_deferred("_start", false)
			_delayed_png(14.0, "menupick.png")
	if args.has("uitest"):
		_ui_test()
	if args.has("shot"):
		_take_shot(args["shot"], float(args.get("shotdelay", "6")))
	if args.has("quit"):
		_quit_after(float(args["quit"]))

func _spec_from_args() -> Dictionary:
	var sp = Maps.default_spec()
	if args.has("map"):
		sp = Maps.preset(int(args["map"]))
	for k in ["size", "water", "islands", "resources", "hills", "forest", "seed"]:
		if args.has(k):
			sp[k] = float(args[k]) if k != "seed" else int(args[k])
	if not args.has("seed") and not args.has("map") and not args.has("autostart") and not args.has("demo"):
		sp["seed"] = randi() % 100000
	return sp

## Baut Gelände, Vorkommen, Tiere und Raster für die Karte; ersetzt eine vorhandene Karte.
func _build_world(sp: Dictionary) -> void:
	for n in ["Terrain", "Units", "FX", "Animals", "Folk"]:
		var old = world.get_node_or_null(n)
		if old != null:
			world.remove_child(old)
			old.queue_free()
	Game.reset_match()
	map_spec = sp
	Game.map_spec = sp
	Game.setup_world(int(sp["size"]))
	var lay = Maps.layout(sp)
	starts_all = lay["starts"]
	var pts = lay["depots"].map(func(r): return r[0])
	var terrain = TerrainScript.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	Game.terrain = terrain
	terrain.generate(sp, starts_all, pts)
	Game.sites = load("res://scripts/settlement.gd").build(world, terrain, sp, starts_all)
	Game.init_grid()
	Game.units_root = Node3D.new()
	Game.units_root.name = "Units"
	world.add_child(Game.units_root)
	Game.fx_root = Node3D.new()
	Game.fx_root.name = "FX"
	world.add_child(Game.fx_root)
	for rs in lay["depots"]:
		Game.spawn_depot(Vector3(rs[0].x, 0, rs[0].y), rs[2], rs[1])
	var animals = load("res://scripts/animals.gd").new()
	animals.name = "Animals"
	world.add_child(animals)
	animals.setup(int(sp["seed"]), starts_all)
	var folk = load("res://scripts/villagers.gd").new()
	folk.name = "Folk"
	world.add_child(folk)
	folk.setup(sp, starts_all)
	if args.has("mapimg"):
		var img: Image = terrain.minimap_image(320)
		for dp in Game.depots:
			var px = int((dp.position.x + Game.HALF) / (Game.HALF * 2.0) * 320.0)
			var pz = int((dp.position.z + Game.HALF) / (Game.HALF * 2.0) * 320.0)
			var col = Defs.RES_COLORS[dp.kind]
			for ox in range(-2, 3):
				for oz in range(-2, 3):
					img.set_pixel(clampi(px + ox, 0, 319), clampi(pz + oz, 0, 319), col)
		for s in starts_all:
			var sx = int((s.x + Game.HALF) / (Game.HALF * 2.0) * 320.0)
			var sz = int((s.y + Game.HALF) / (Game.HALF * 2.0) * 320.0)
			for ox in range(-4, 5):
				for oz in range(-4, 5):
					img.set_pixel(clampi(sx + ox, 0, 319), clampi(sz + oz, 0, 319), Color(1, 1, 1))
		img.save_png(ProjectSettings.globalize_path("res://shots/%s" % args["mapimg"]))

var _bc_t = 0.0

func _process(delta: float) -> void:
	_auto_quality(delta)
	if args.has("selecthq") and Game.running and not _hq_sel:
		_hq_t += delta
	if args.has("selecthq") and Game.running and not _hq_sel and _hq_t > 2.0:
		# Testschalter: eigenes Hauptquartier auswählen (Bild der Befehlsleiste)
		var pool: Array = Game.units if String(args["selecthq"]) == "dozer" else Game.buildings
		var role: String = "dozer" if String(args["selecthq"]) == "dozer" else "hq"
		for b in pool:
			if b.owner_id == Game.human and b.def["role"] == role:
				Game.ctrl.set_selection([b])
				Game.cam.look_at_pos(b.position)
				break
		_hq_sel = true
	if args.has("speedtest") and Game.running:
		_speed_test(delta)
	if args.has("autosell") and Game.running and not _sold:
		_sell_t += delta
		if _sell_t > float(args["autosell"]):
			for o in Game.buildings:
				if o.owner_id == Game.human and o.alive:
					_sold = true
					print("AUTOSELL ", o.def["name"], " ", o.position, " n=", Game.buildings.size())
					Game.cam.look_at_pos(o.position)
					Game.cam.dist_target = 30.0
					o.sell()
					break
	if args.has("battlecam") and Game.running:
		_bc_t -= delta
		if _bc_t <= 0.0 and Game.last_combat_pos != Vector3.ZERO:
			_bc_t = 3.0
			Game.cam.look_at_pos(Game.last_combat_pos)
			Game.cam.dist_target = 48.0

var _sold := false
var _hq_sel := false
var _hq_t := 0.0
var _env: Environment
var _lowfps_t := 0.0
var _fx_step := 0

## Automatische Absenkung: liegt die Bildrate 6 s lang unter 40, fallen zuerst die Bildschirmspiegelungen, dann das
## indirekte Licht weg (je etwa 3 ms auf großen Karten). --fullfx schaltet das ab.
func _auto_quality(delta: float) -> void:
	if _env == null or args.has("fullfx") or _fx_step >= 2 or not Game.running:
		return
	if Engine.get_frames_per_second() < 40:
		_lowfps_t += delta
	else:
		_lowfps_t = max(0.0, _lowfps_t - delta * 0.5)
	if _lowfps_t > 6.0:
		_lowfps_t = 0.0
		if _fx_step == 0 and _env.ssr_enabled:
			_env.ssr_enabled = false
			print("GRAFIK: Spiegelungen aus (Bildrate)")
		elif _env.ssil_enabled:
			_env.ssil_enabled = false
			print("GRAFIK: indirektes Licht aus (Bildrate)")
		_fx_step += 1
var _st_unit = null
var _st_t := 0.0
var _st_from := Vector3.ZERO

## Testschalter --speedtest: ein Panzer fährt 50 m geradeaus; gemessen werden Zeit und Regen/Straße am Start.
func _speed_test(delta: float) -> void:
	if _st_unit == null:
		var st: Vector3 = Game.players[0]["start"]
		var dir := (Vector3.ZERO - st).normalized()
		_st_from = st + dir * 24.0
		_st_from.y = Game.terrain.ground_y(_st_from.x, _st_from.z)
		_st_unit = Game.spawn_unit(Game.players[0]["faction"] + "_tank", 0, _st_from)
		var goal := _st_from + dir * 50.0
		_st_unit.cmd_move(goal)
		_st_t = 0.0
		print("SPEEDTEST start rain=%.2f strasse=%s" % [Game.rain, str(Game.on_road(_st_from))])
		return
	if _st_t < 0.0:
		return
	_st_t += delta
	if is_instance_valid(_st_unit) and _st_unit.path.is_empty() and _st_t > 0.5:
		print("SPEEDTEST %.1f m in %.2f s, rain=%.2f" % [Game.flat_dist(_st_unit.position, _st_from), _st_t, Game.rain])
		_st_t = -1.0
var _sell_t := 0.0

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
	env.ssao_enabled = not args.has("nossao")
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssil_enabled = not args.has("nossil")
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.68, 0.76)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.4
	env.volumetric_fog_enabled = not args.has("novolfog")
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.9)
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_anisotropy = 0.5
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	# Spiegelungen auf Wasser und glatten Flächen
	env.ssr_enabled = not args.has("nossr")
	env.ssr_max_steps = 40
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssao_power = 1.6
	env.ssao_horizon = 0.06
	for gl in [3, 4]:
		env.set_glow_level(gl, 0.8)
	var we = WorldEnvironment.new()
	we.environment = env
	_env = env
	world.add_child(we)
	# Nachbearbeitung (Schärfen, Farbgebung, Vignette, Filmkorn) unter der Oberfläche
	if not args.has("nopost"):
		var post_layer = CanvasLayer.new()
		post_layer.layer = 5
		var rect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pm = ShaderMaterial.new()
		pm.shader = load("res://shaders/post.gdshader")
		rect.material = pm
		post_layer.add_child(rect)
		add_child(post_layer)
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
	var dn = load("res://scripts/daynight.gd").new()
	dn.name = "DayNight"
	add_child(dn)
	dn.start_hour = float(args.get("hour", "9"))
	dn.cycle_minutes = float(args.get("daycycle", "0"))
	dn.setup(env, psm, sun)
	Game.daynight = dn
	var wx = load("res://scripts/weather.gd").new()
	wx.name = "Weather"
	add_child(wx)

func start_match(cfg: Dictionary) -> void:
	if cfg.has("map"):
		var want: Dictionary = Maps.clean(cfg["map"])
		if want != map_spec:
			_build_world(want)
	if cfg.has("hour"):
		Game.daynight.configure(float(cfg["hour"]), float(cfg.get("daycycle", 0.0)))
	if args.has("hour") and args.has("mission"):
		Game.daynight.configure(float(args["hour"]), 0.0)
	Game.rain = 0.0
	Game.rain_target = 0.0
	var rain_cfg: float = float(args.get("rain", cfg.get("rain", 0.0) if cfg.has("mission") else 0.0))
	if rain_cfg > 0.0:
		Game.rain = rain_cfg
		Game.rain_target = rain_cfg
	Game.spectator = cfg["spectate"]
	Game.difficulty = cfg["difficulty"]
	Game.human = 0
	var facs = ["west", "red", "shadow"]
	var mine: String = cfg["faction"]
	var n_enemies: int = clampi(cfg["enemies"], 1, 3)
	Game.fog_vis.fill(0)
	Game.fog_exp.fill(0)
	var starts_used = [starts_all[0], starts_all[1]] if n_enemies == 1 else starts_all.slice(0, n_enemies + 1)
	for i in starts_used.size():
		var s: Vector2 = starts_used[i]
		var f: String = mine if i == 0 else facs[(facs.find(mine) + i) % 3]
		var ef: Array = cfg.get("enemy_factions", [])
		if i > 0 and i - 1 < ef.size():
			f = String(ef[i - 1])
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
	var hbay: Vector2 = Game.terrain.bay_center(Vector2(st.x, st.z))
	Game.explore(Vector3(hbay.x, 0, hbay.y), 18.0)
	Game.mission = null
	var runner = null
	if cfg.has("mission"):
		runner = load("res://scripts/mission_runner.gd").new()
		add_child(runner)
		runner.setup(load("res://scripts/missions.gd").by_id(String(cfg["mission"])), self)
	Game.running = true
	if Game.rain_target > 0.0:
		Game.set_rain(Game.rain_target)
	if args.has("revealall"):
		Game.explore(Vector3(0, 0, 0), 400.0)
	Game.update_fog()
	Game.hud.on_match_started()
	if runner != null:
		runner.begin()
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
			var bcv: Vector2 = Game.terrain.bay_center(Vector2(s0.x, s0.z))
			var bay = Vector3(bcv.x, 0, bcv.y)
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
		var bc0: Vector2 = Game.terrain.bay_center(Vector2(b0.x, b0.z))
		cam.look_at_pos(Vector3(bc0.x, 0, bc0.y))
		cam.dist_target = float(args.get("camdist", "40"))
	if args.has("audiotest"):
		# Prüft, ob alle Stimmen und Geräusche geladen werden können, und spielt je eine Probe ab
		var missing := 0
		var total := 0
		for f in ["west", "red", "shadow"]:
			for kind in ["select", "move", "attack", "air_move", "naval_move", "build", "harvest"]:
				var cnt := int(Audio._index.get(f, {}).get(kind, 0))
				if cnt == 0:
					missing += 1
				for i in cnt:
					total += 1
					if Audio._stream("res://audio/voice/%s/%s_%d.wav" % [f, kind, i]) == null:
						missing += 1
		for nm in ["ui_click", "place", "ready", "building_hq", "building_power", "building_supply", "building_barracks", "building_factory", "building_airfield", "building_dock", "building_defense", "building_tech", "building_super"]:
			total += 1
			if Audio._stream("res://audio/sfx/%s.wav" % nm) == null:
				missing += 1
		print("AUDIOTEST geladen=%d fehlend=%d" % [total - missing, missing])
		await _wait(1.0)
		var played := 0
		for u in Game.units:
			if u.alive and not u.flying and not u.naval:
				Audio._last_voice = -10.0
				Audio.voice(u, "select")
				Audio._last_voice = -10.0
				Audio.voice(u, "move")
				break
		for b in Game.buildings:
			if b.alive and b.def["role"] == "hq":
				Audio.building_click(b)
				break
		for pl in Audio._pool:
			if pl.playing:
				played += 1
		print("AUDIOTEST laufende Spieler=%d" % played)
	if args.has("depotreal"):
		# Kamera auf das nächste echte Vorkommen dieser Art (wood, iron, oil, gold, supply)
		var want: String = String(args["depotreal"])
		var best = null
		var bdist = 1e9
		for dp in Game.depots:
			if dp.kind == want and Game.flat_dist(dp.position, Game.players[0]["start"]) < bdist:
				bdist = Game.flat_dist(dp.position, Game.players[0]["start"])
				best = dp
		if best != null:
			Game.spawn_unit("west_inf", 0, best.position + Vector3(0, 0, 7.0))
			Game.explore(best.position, 24.0)
			cam.look_at_pos(best.position + Vector3(0, 0, 1.5))
			cam.dist_target = float(args.get("camdist", "20"))
	if args.has("depotshow"):
		# Alle fünf Vorkommen nebeneinander vor der Kamera (Test der Rohstoffoptik)
		var dbase: Vector3 = Game.players[0]["start"] + Vector3(10, 0, -30)
		var kinds = ["wood", "iron", "oil", "gold", "supply"]
		for di in kinds.size():
			Game.spawn_depot(dbase + Vector3(di * 9.5, 0, 0), 40000.0, kinds[di])
			Game.spawn_unit("west_inf", 0, dbase + Vector3(di * 9.5, 0, 6.5))   # Sichtweite gegen den Nebel des Krieges
		Game.explore(dbase + Vector3(19, 0, 0), 40.0)
		var focus: int = int(args.get("depotfocus", "-1"))
		if focus >= 0:
			cam.look_at_pos(dbase + Vector3(focus * 9.5, 0, 1.5))
			cam.dist_target = float(args.get("camdist", "20"))
		else:
			cam.look_at_pos(dbase + Vector3(19, 0, 0))
			cam.dist_target = float(args.get("camdist", "36"))
	if args.has("workershow"):
		# Nahaufnahme der Arbeiterfiguren: stehend und in Schrittstellung, je Fraktion
		var D = load("res://scripts/arch_detail.gd")
		var o0: Vector3 = Game.players[0]["start"] + Vector3(0, 0, 10)
		var gy: float = Game.terrain.ground_y(o0.x, o0.z)
		var fi = 0
		for fc in ["west", "red", "shadow"]:
			for pose in 2:
				var wk = D.worker(fc)
				wk.position = Vector3(o0.x + fi * 0.9 - 2.2, gy, o0.z)
				wk.rotation.y = 1.2
				Game.fx_root.add_child(wk)
				if pose == 1 and wk.has_meta("ap"):
					var wap: AnimationPlayer = wk.get_meta("ap")
					wap.play("Walk")
				fi += 1
		cam.look_at_pos(Vector3(o0.x, gy + 1.4, o0.z))
		cam.dist_target = float(args.get("camdist", "4.5"))
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
	if args.has("defensetest"):
		_defense_test()
	if args.has("boomtest"):
		_boom_test()
	if args.has("rotortest"):
		_rotor_test()
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

## Klick in Viewport-Koordinaten. Die echte Maus wird in Fensterpixeln gesetzt (Skalierung des Fensters berücksichtigt),
## die Ereignisse tragen Viewport-Koordinaten; der Controller liest die Position aus den Ereignissen, nicht vom Fokus abhängig.
func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	if not args.has("nowarp"):
		DisplayServer.window_move_to_foreground()
		Input.warp_mouse(get_viewport().get_screen_transform() * pos)
	var mm = InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
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
	if args.has("nowarp"):
		# Echte Maus bleibt unbewegt und liegt über der unteren Leiste (wie bei fehlendem Fensterfokus)
		Input.warp_mouse(Vector2(300, get_viewport().get_visible_rect().size.y - 40))
	await _wait(1.5)
	var cam = Game.cam
	var dozer = null
	for u in Game.units:
		if u.owner_id == 0 and u.def["role"] == "dozer":
			dozer = u
	# 1) Bauarbeiter per Klick auswaehlen
	cam.look_at_pos(dozer.position)
	await _wait(0.8)
	for attempt in 3:
		await _click(cam.cam.unproject_position(dozer.aim_point()))
		await _wait(0.3)
		if Game.ctrl.selection.has(dozer):
			break
		cam.look_at_pos(dozer.position)
		await _wait(0.6)
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
	if not args.has("nowarp"):
		Input.warp_mouse(get_viewport().get_screen_transform() * sp)
	var mm2 = InputEventMouseMotion.new()
	mm2.position = sp
	mm2.global_position = sp
	Input.parse_input_event(mm2)
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
func _delayed_png(t: float, file: String) -> void:
	await _wait(t)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s" % file))

## Misst, ob sich die Rotoren von Drohnen und Hubschraubern einzeln drehen.
func _rotor_test() -> void:
	await _wait(1.0)
	var st: Vector3 = Game.players[0]["start"] + Vector3(0, 0, 20)
	for id in ["west_drone", "west_dozer", "west_heli", "red_heli"]:
		var u = Game.spawn_unit(id, 0, st)
		await _wait(0.3)
		var rs: Array = u.model.get("rotors", [])
		var a0 = rs.map(func(r): return snappedf(r.rotation.y, 0.01))
		await _wait(0.2)
		var a1 = rs.map(func(r): return snappedf(r.rotation.y, 0.01))
		print("ROTOR %s: %d Rotoren  vorher %s  nachher %s" % [id, rs.size(), str(a0), str(a1)])

## Zeigt drei Explosionsgrößen nebeneinander (für Bildproben mit --shot und --shotdelay).
func _boom_test() -> void:
	var s0: Vector3 = Game.players[0]["start"]
	var toward = Vector3(-s0.x, 0, -s0.z).normalized()
	var st: Vector3 = s0 + toward * 30.0
	Game.explore(st, 40.0)
	Game.update_fog()
	Game.cam.look_at_pos(st)
	Game.cam.dist_target = float(args.get("camdist", "30"))
	await _wait(1.5)
	var side = Vector3(-toward.z, 0, toward.x)
	var sizes = [1.0, 2.5, 4.5]
	for i in 3:
		var p: Vector3 = st + side * ((i - 1) * 9.0)
		p.y = Game.terrain.ground_y(p.x, p.z)
		load("res://scripts/fx.gd").explosion(p, sizes[i], args.has("toxic"))
	var marks = [0.2, 0.5, 1.0, 2.0, 3.5]
	var last = 0.0
	for k in marks.size():
		await _wait(marks[k] - last)
		last = marks[k]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/boom_%d.png" % k))
	print("BOOM fertig")
## Prüft je Fraktion: Abwehrbau drehbar, richtet sich auf ein Ziel aus und beschädigt es.
func _defense_test() -> void:
	await _wait(1.0)
	for pl in Game.players.size():
		var fac: String = Game.players[pl]["faction"]
		var did = fac + "_defense"
		var s0: Vector3 = Game.players[pl]["start"]
		var site = null
		for ring in range(8, 30):
			for j in 16:
				var a = TAU * j / 16.0 + ring * 0.3
				var c = Game.world_to_cell(s0 + Vector3(cos(a), 0, sin(a)) * ring)
				if Game.can_place(did, c, pl) == "":
					site = c
					break
			if site != null:
				break
		if site == null:
			print("DEFENSE ", did, ": KEIN BAUPLATZ")
			continue
		var b = Game.spawn_building(did, pl, site, true)
		var foe_owner = (pl + 1) % Game.players.size()
		var foe_id = ["west_tank", "red_tank", "shadow_tank"][foe_owner]
		var foe = Game.spawn_unit(foe_id, foe_owner, b.position + Vector3(-11, 0, -9))
		foe.visible = true
		var hp0: float = foe.hp
		var rot0: float = b.turret.rotation.y if b.turret else 0.0
		await _wait(7.0)
		var rot1: float = b.turret.rotation.y if b.turret else 0.0
		var foe_ok = is_instance_valid(foe) and foe.alive
		print("DEFENSE %s: Turm vorhanden=%s Drehung=%.2f Ziel-Leben %d -> %d (Gebäude-Leben %d/%d)" % [did, str(b.turret != null), rot1 - rot0, int(hp0), int(foe.hp) if foe_ok else 0, int(b.hp), int(b.max_hp)])
		if foe_ok:
			foe.take_damage(1e7, pl, null)

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
