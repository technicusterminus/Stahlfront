extends Node
## Symbole für das Befehlsraster aus den echten Spielmodellen rendern.
## Aufruf:  godot --path . -- --iconbake            (alle)
##          godot --path . -- --iconbake=west_dunebuggy,shadow_bike   (nur diese Kennungen)
## Für jede Einheit und jedes Gebäude: Modell in einer eigenen 3D-Welt aufstellen, schräg von vorn oben beleuchten,
## mit durchsichtigem Hintergrund aufnehmen und als models/icons/<id>.png (128 px) speichern. Danach einmal importieren.

const Models = preload("res://scripts/models.gd")
const SIZE := 128

var vp: SubViewport
var cam: Camera3D
var stage: Node3D
var jobs: Array = []

func _ready() -> void:
	Game.setup_world(64)
	Game.spectator = true
	Game.update_fog()
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE * 2, SIZE * 2)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.6
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.7
	rim.light_color = Color(0.7, 0.85, 1.0)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	stage = Node3D.new()
	vp.add_child(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models/icons"))
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--iconbake="):
			only = a.trim_prefix("--iconbake=").split(",", false)
	for id in Defs.units:
		if only.is_empty() or only.has(id):
			jobs.append(["unit", id])
	for id in Defs.buildings:
		if only.is_empty() or only.has(id):
			jobs.append(["bldg", id])
	_run()

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if not vi.visible:
			continue
		var a: AABB = vi.global_transform * vi.get_aabb()
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	return box

func _run() -> void:
	for j in jobs:
		for c in stage.get_children():
			c.queue_free()
		await get_tree().process_frame
		var d: Dictionary = Defs.units[j[1]] if j[0] == "unit" else Defs.buildings[j[1]]
		var fac: String = String(d.get("faction", "west"))
		var col: Color = Defs.factions[fac]["color"] if Defs.factions.has(fac) else Color(0.6, 0.6, 0.6)
		var model: Dictionary = Models.build_unit(d["model"], col, fac) if j[0] == "unit" else Models.build_building(d, col)
		if model.is_empty():
			continue
		var root: Node3D = model["root"]
		stage.add_child(root)
		await get_tree().process_frame
		var box := _aabb(root)
		var center := box.get_center()
		var radius: float = max(box.size.length() * 0.5, 0.5)
		var dir := Vector3(0.62, 0.55, 0.88).normalized()
		cam.position = center + dir * radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
		cam.look_at(center, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://models/icons/%s.png" % j[1]))
		print("SYMBOL ", j[1])
	print("SYMBOLE FERTIG ", jobs.size())
	get_tree().quit()
