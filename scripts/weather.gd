extends Node3D
## Wetter: Regen (Partikel, Geräusch, grauer Himmel, nasser Boden). Spielwirkung: Game.ground_speed_mult
## bremst Bodeneinheiten abseits von Straßen. Die Regenstärke (Game.rain, 0..1) läuft sanft auf Game.rain_target zu.

var parts: GPUParticles3D
var snd: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	parts = GPUParticles3D.new()
	parts.amount = 5200
	parts.lifetime = 0.8
	parts.visibility_aabb = AABB(Vector3(-70, -40, -70), Vector3(140, 60, 140))
	parts.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(48, 0.5, 48)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 38.0
	pm.gravity = Vector3(0, -12, 0)
	parts.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.85, 0.95, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.no_depth_test = false
	q.material = mat
	parts.draw_pass_1 = q
	parts.emitting = false
	add_child(parts)
	snd = AudioStreamPlayer.new()
	var st = load("res://audio/sfx/rain.wav")
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	snd.stream = st
	snd.volume_db = -80.0
	add_child(snd)

func _process(delta: float) -> void:
	var diff: float = Game.rain_target - Game.rain
	Game.rain += clampf(diff, -0.12 * delta, 0.12 * delta)
	var r: float = Game.rain
	RenderingServer.global_shader_parameter_set("wetness", r)
	var on: bool = r > 0.02
	if parts.emitting != on:
		parts.emitting = on
	parts.amount_ratio = clampf(r, 0.05, 1.0)
	if Game.cam != null:
		var c: Vector3 = Game.cam.position
		parts.global_position = Vector3(c.x, c.y + 26.0 + Game.cam.dist * 0.3, c.z)
		(parts.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(30.0 + Game.cam.dist * 0.5, 0.5, 30.0 + Game.cam.dist * 0.5)
	if on and not snd.playing:
		snd.play()
	if not on and snd.playing:
		snd.stop()
	snd.volume_db = lerpf(-40.0, -12.0, clampf(r, 0.0, 1.0)) if on else -80.0
