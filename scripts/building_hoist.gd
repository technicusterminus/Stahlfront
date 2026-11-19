extends Node3D
## Portalkran mit Greifer, Kette und zwei Übergabestationen.

const M = preload("res://scripts/models.gd")
const CYCLE := 9.6
const STOP := 0.39
const LINE_REST := 1.106
const LINK_PITCH := 0.041
const LINK_COUNT := 32

var _time := 0.0
var _carriage: Node3D
var _swing: Node3D
var _drum: Node3D
var _hook: Node3D
var _jaws: Array[Node3D] = []
var _crate: Node3D
var _rollers: Array[Node3D] = []
var _links: MultiMesh
var _last_links := -1
var _last_line := LINE_REST
var _travel_speed := 0.0
var _pendulum_speed := 0.0
var _roller_spin := 0.0

func setup(base: Material, steel: Material, accent: Material, timber: Material) -> void:
	var rubber := M.mat(Color(0.055, 0.060, 0.058), 0.02, 0.88)
	var brass := M.mat(Color(0.66, 0.49, 0.23), 0.36, 0.57)
	var zinc := M.mat(Color(0.43, 0.45, 0.45), 0.68, 0.4)
	M._bb(Vector3(1.34, 0.085, 1.17), Vector3(0, 0.055, 0), base)
	for x in [-0.66, 0.66]:
		M._bb(Vector3(0.23, 0.048, 0.25), Vector3(x, 0.12, 0), zinc)
		M._bb(Vector3(0.10, 1.58, 0.16), Vector3(x, 0.93, 0), steel)
		for z in [-0.09, 0.09]:
			M._bc(0.022, 0.022, 0.028, Vector3(x - 0.075, 0.154, z), zinc, Vector3.ZERO, 6)
			M._bc(0.022, 0.022, 0.028, Vector3(x + 0.075, 0.154, z), zinc, Vector3.ZERO, 6)
		M._bb(Vector3(0.07, 0.28, 0.044), Vector3(x * 0.83, 1.59, 0.07), zinc, Vector3(0, 0, signf(x) * 0.56))
		M._bb(Vector3(0.034, 0.17, 0.18), Vector3(x * 0.88, 1.66, 0), rubber)
	M._bb(Vector3(1.48, 0.046, 0.18), Vector3(0, 1.74, 0), accent)
	M._bb(Vector3(1.37, 0.106, 0.106), Vector3(0, 1.67, 0), steel)
	M._bb(Vector3(1.40, 0.024, 0.16), Vector3(0, 1.61, 0), zinc)
	for i in 6:
		M._bb(Vector3(0.036, 0.057, 0.008), Vector3(-0.29 + i * 0.11, 1.684, 0.057), brass, Vector3(0, 0, -0.45))
	for x in [-STOP, STOP]:
		M._bb(Vector3(0.42, 0.07, 0.90), Vector3(x, 0.118, 0), accent)
		for side in [-1.0, 1.0]:
			M._bb(Vector3(0.032, 0.047, 0.91), Vector3(x + 0.19 * side, 0.164, 0), zinc)
		var apron_z: float = signf(x) * 0.59
		M._bb(Vector3(0.42, 0.07, 0.30), Vector3(x, 0.118, apron_z), base)
		M._bb(Vector3(0.43, 0.041, 0.24), Vector3(x, 0.386, apron_z), accent)
		for side in [-1.0, 1.0]:
			M._bb(Vector3(0.037, 0.22, 0.24), Vector3(x + 0.20 * side, 0.262, apron_z), steel)
		M._bb(Vector3(0.41, 0.22, 0.035), Vector3(x, 0.26, apron_z + signf(x) * 0.127), base)
	M._flush(self)

	_carriage = _at(self, Vector3(-STOP, 1.56, 0.020))
	M._bb(Vector3(0.25, 0.105, 0.18), Vector3(0, 0.012, 0), base)
	M._bb(Vector3(0.22, 0.074, 0.040), Vector3(0, -0.006, 0.101), accent)
	M._bb(Vector3(0.058, 0.038, 0.017), Vector3(-0.063, 0.021, 0.125), brass)
	for i in 4:
		M._bb(Vector3(0.012, 0.035, 0.038), Vector3(0.015 + i * 0.032, -0.012, 0.113), steel)
	M._flush(_carriage)
	for x in [-0.078, 0.078]:
		var axle := _at(_carriage, Vector3(x, 0.078, 0))
		_rollers.append(axle)
		M.cyl(axle, 0.035, 0.035, 0.035, Vector3(0, 0, 0.075), rubber, Vector3(PI / 2, 0, 0), 12)
		M.cyl(axle, 0.028, 0.028, 0.021, Vector3(0, 0, 0.098), zinc, Vector3(PI / 2, 0, 0), 12)
	_drum = _at(_carriage, Vector3(0, -0.061, 0.026))
	M.cyl(_drum, 0.035, 0.035, 0.102, Vector3.ZERO, base, Vector3(0, 0, PI / 2), 16)
	for x in [-0.058, 0.058]:
		M.cyl(_drum, 0.048, 0.048, 0.012, Vector3(x, 0, 0), zinc, Vector3(0, 0, PI / 2), 16)
	M.box(_drum, Vector3(0.09, 0.009, 0.016), Vector3(0, 0.036, 0), brass)
	_swing = _at(_carriage, Vector3(0, -0.088, 0.025))
	_make_chain(steel)
	_hook = _at(_swing, Vector3(0, -LINE_REST, 0))
	M.box(_hook, Vector3(0.136, 0.033, 0.084), Vector3.ZERO, zinc)
	for x in [-0.057, 0.057]:
		var jaw := _at(_hook, Vector3(x, -0.009, 0))
		_jaws.append(jaw)
		M.box(jaw, Vector3(0.019, 0.072, 0.062), Vector3(0, -0.034, 0), steel)
		M.box(jaw, Vector3(0.047, 0.018, 0.052), Vector3(-signf(x) * 0.012, -0.070, 0), zinc)

	_crate = _at(self, Vector3(-STOP, 0.244, 0))
	M._bb(Vector3(0.30, 0.15, 0.26), Vector3.ZERO, timber)
	for x in [-0.145, 0.145]:
		M._bb(Vector3(0.043, 0.157, 0.285), Vector3(x, 0, 0), timber)
		M._bb(Vector3(0.052, 0.030, 0.30), Vector3(x * 0.82, -0.085, 0), base)
	for z in [-0.108, 0.108]:
		M._bb(Vector3(0.329, 0.025, 0.036), Vector3(0, 0.073, z), zinc)
	for y in [-0.036, 0.011, 0.054]:
		M._bb(Vector3(0.273, 0.013, 0.013), Vector3(0, y, 0.134), timber)
	M._bb(Vector3(0.071, 0.048, 0.009), Vector3(0.054, 0.015, 0.143), brass)
	M._flush(_crate)
	_pose_chain(LINE_REST)

func _at(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	return pivot

func _make_chain(steel: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.013
	mesh.outer_radius = 0.021
	mesh.rings = 12
	mesh.ring_segments = 6
	mesh.material = steel
	_links = MultiMesh.new()
	_links.transform_format = MultiMesh.TRANSFORM_3D
	_links.mesh = mesh
	_links.custom_aabb = AABB(Vector3(-0.05, -1.40, -0.05), Vector3(0.10, 1.45, 0.10))
	_links.instance_count = LINK_COUNT
	var view := MultiMeshInstance3D.new()
	view.multimesh = _links
	_swing.add_child(view)

func _pose_chain(length: float) -> void:
	var count := mini(LINK_COUNT, maxi(1, ceili(length / LINK_PITCH)))
	if count == _last_links:
		return
	_last_links = count
	_links.visible_instance_count = count
	for i in count:
		var basis := Basis(Vector3.UP, (i % 2) * PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0)
		_links.set_instance_transform(i, Transform3D(basis.scaled(Vector3(0.85, 1.13, 1.0)), Vector3(0, -(i + 0.5) * LINK_PITCH, 0)))

func advance(delta: float, drive: float, active: bool) -> void:
	_time = fposmod(_time + delta * drive * (1.0 if active else 0.38), CYCLE)
	var t := _time
	var transport: float = smoothstep(2.58, 4.61, t) - smoothstep(6.89, 8.79, t)
	var lift: float = smoothstep(1.58, 2.63, t) - smoothstep(4.58, 5.66, t)
	var empty_lift: float = 1.0 - smoothstep(0.34, 1.46, t) + smoothstep(6.10, 6.94, t)
	var desired_x := lerpf(-STOP, STOP, transport)
	var speed := (desired_x - _carriage.position.x) / maxf(delta, 0.001)
	_pendulum_speed += (speed - _travel_speed) * 0.075
	_pendulum_speed -= _swing.rotation.z * 24.0 * delta
	_pendulum_speed *= exp(-3.5 * delta)
	_swing.rotation.z = clampf(_swing.rotation.z + _pendulum_speed * delta, -0.106, 0.106)
	_travel_speed = speed
	_roller_spin = fposmod(_roller_spin + (desired_x - _carriage.position.x) / 0.036, TAU)
	_carriage.position.x = desired_x
	for wheel in _rollers:
		wheel.rotation.z = -_roller_spin
	var line := LINE_REST - 0.65 * maxf(lift, empty_lift)
	_drum.rotation.x += (_last_line - line) / 0.036
	_last_line = line
	_pose_chain(line)
	_hook.position.y = -line
	var grip: float = smoothstep(1.44, 1.60, t) - smoothstep(5.76, 5.97, t)
	_jaws[0].rotation.z = lerpf(-0.59, 0.17, grip)
	_jaws[1].rotation.z = -_jaws[0].rotation.z
	if t >= 1.58 and t < 5.85:
		_crate.position = to_local(_hook.global_position) - Vector3(0, 0.12, 0.005)
		_crate.rotation.z = _swing.rotation.z
	elif t < 1.58:
		_crate.position = Vector3(-STOP, 0.244, lerpf(-0.58, 0.04, smoothstep(0.0, 0.54, t)))
		_crate.rotation.z = 0.0
	else:
		_crate.position = Vector3(STOP, 0.244, lerpf(0.04, 0.63, smoothstep(6.17, 7.36, t)))
		_crate.rotation.z = 0.0
	_crate.visible = t >= 0.05 and t < 7.44
