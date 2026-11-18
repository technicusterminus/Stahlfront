extends Node3D
## RTS-Kamera: Pfeiltasten/Bildschirmrand verschieben, Mausrad zoomen, Q/E drehen, mittlere Maustaste ziehen.

var cam: Camera3D
var yaw = 0.0
var pitch = deg_to_rad(-55.0)
var dist = 60.0
var dist_target = 60.0
var orbit = false
var _shake = 0.0
var _drag = false
var _ground_y = 3.0
var edge_scroll = true

const MIN_D := 22.0
const MAX_D := 110.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 700.0
	add_child(cam)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply()

func shake(amount: float, at: Vector3) -> void:
	var d = Vector2(at.x - position.x, at.z - position.z).length()
	var f: float = clamp(1.0 - d / 90.0, 0.0, 1.0)
	_shake = min(2.5, max(_shake, amount * f))

func look_at_pos(p: Vector3) -> void:
	position.x = p.x
	position.z = p.z

func _unhandled_input(event: InputEvent) -> void:
	if orbit:
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist_target = max(MIN_D, dist_target * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist_target = min(MAX_D, dist_target * 1.13)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		var mm = event as InputEventMouseMotion
		if Input.is_key_pressed(KEY_ALT):
			yaw -= mm.relative.x * 0.006
		else:
			var k = dist / 600.0
			_pan(Vector2(-mm.relative.x, mm.relative.y) * k)

## v.x = nach rechts, v.y = nach vorne (Blickrichtung).
func _pan(v: Vector2) -> void:
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	position += right * v.x + fwd * v.y

func _process(delta: float) -> void:
	var rd: float = min(delta, 0.05)
	if orbit:
		yaw += rd * 0.05
		dist_target = 95.0
	else:
		var v = Vector2.ZERO
		if not get_tree().paused:
			if Input.is_key_pressed(KEY_LEFT):
				v.x -= 1
			if Input.is_key_pressed(KEY_RIGHT):
				v.x += 1
			if Input.is_key_pressed(KEY_UP):
				v.y -= 1
			if Input.is_key_pressed(KEY_DOWN):
				v.y += 1
			if Input.is_key_pressed(KEY_Q):
				yaw += rd * 1.6
			if Input.is_key_pressed(KEY_E):
				yaw -= rd * 1.6
			if edge_scroll and DisplayServer.window_is_focused():
				var mp = get_viewport().get_mouse_position()
				var vs = get_viewport().get_visible_rect().size
				if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
					if mp.x < 4:
						v.x -= 1
					elif mp.x > vs.x - 5:
						v.x += 1
					if mp.y < 4:
						v.y -= 1
					elif mp.y > vs.y - 5:
						v.y += 1
		if v != Vector2.ZERO:
			_pan(Vector2(v.x, -v.y).normalized() * rd * (25.0 + dist * 0.9))
	position.x = clamp(position.x, -Game.HALF + 12.0, Game.HALF - 12.0)
	position.z = clamp(position.z, -Game.HALF + 12.0, Game.HALF - 12.0)
	if Game.terrain != null:
		_ground_y = lerp(_ground_y, max(Game.terrain.ground_y(position.x, position.z), 0.0), min(1.0, rd * 3.0))
	position.y = _ground_y
	dist = lerp(dist, dist_target, min(1.0, rd * 10.0))
	_shake = max(0.0, _shake - rd * 2.5)
	_apply()

func _apply() -> void:
	var p = pitch + (dist - MIN_D) / (MAX_D - MIN_D) * deg_to_rad(-8.0)
	var b = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, p)
	var off = Vector3.ZERO
	if _shake > 0.0:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.5
	cam.transform = Transform3D(b, b * Vector3(0, 0, dist) + off)
