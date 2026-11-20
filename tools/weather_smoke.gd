extends SceneTree
## godot --headless --script res://tools/weather_smoke.gd -- --mission=c4 --missionauto

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["OK" if ok else "FEHLER", label])
	if not ok:
		failures += 1

func _run() -> void:
	var game := root.get_node("Game")
	var audio := root.get_node("Audio")
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 8:
		await process_frame
	if game.mission == null or game.mission.m["id"] != "c4":
		_check(false, "c4 mit --missionauto starten")
		quit(1)
		return
	var weather := scene.get_node("Weather")
	_check(is_equal_approx(game.rain, 0.72), "c4 beginnt mit Regen")
	var bridge: Vector3 = game.sites["sudbrucke"]
	var deck: Vector2i = game.world_to_cell(bridge)
	var grass: Vector3 = game.players[0]["start"] + Vector3(0, 0, 9)
	_check(game.on_road(bridge), "Brückenfahrbahn wird als befestigt erkannt")
	_check(not game.on_road(grass), "Bodenprobe liegt abseits befestigter Wege")
	_check(is_equal_approx(game.ground_speed_mult(bridge), 1.0), "Regen bremst auf der Fahrbahn nicht")
	_check(is_equal_approx(game.ground_speed_mult(grass), 0.712), "Regen 0,72 bremst abseits der Fahrbahn um 28,8 %")
	_check(is_equal_approx(game.astar.get_point_weight_scale(deck), 0.55), "Nasse Karte bevorzugt Straße bei der Wegsuche")
	_check(weather.parts.emitting, "Regen-Partikelsystem aktiv")
	var wav := weather.snd.stream as AudioStreamWAV
	_check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end > 0,
		"Regenschleife geladen und mit gültiger Länge konfiguriert")
	_check(weather.snd.playing, "Regenschleife gestartet")
	audio.toggle()
	await process_frame
	await process_frame
	_check(not weather.snd.playing, "F8-Schalter hält Regenschleife an")
	game.set_rain(1.0)
	game.rain = 1.0
	_check(is_equal_approx(game.ground_speed_mult(grass), 0.6), "Maximalregen reduziert Tempo um 40 %")
	game.set_rain(0.0)
	game.rain = 0.0
	_check(is_equal_approx(game.astar.get_point_weight_scale(deck), 1.0), "Trockene Brücke nutzt Standardgewicht")
	quit(0 if failures == 0 else 1)
