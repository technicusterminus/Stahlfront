extends Node3D
## Falke-Laufwerk. Drei Meshes werden für alle Kettenglieder und Räder instanziert.

const LINKS_PER_SIDE := 68
const RADIUS := 0.294
const STRAIGHT := 3.9
const HALF_ARC := PI * RADIUS
const LOOP_LENGTH := 2.0 * (STRAIGHT + HALF_ARC)
const LINK_PITCH := LOOP_LENGTH / LINKS_PER_SIDE

var _tracks: MultiMesh
var _road_wheels: MultiMesh
var _guide_wheels: MultiMesh
var _track_phase := 0.0
var _wheel_phase := 0.0
var _tick := 0.0

func setup(model_root: Node3D) -> void:
	_tracks = _instances(model_root.find_child("TrackPrototype", true, false), 2 * LINKS_PER_SIDE)
	_road_wheels = _instances(model_root.find_child("RoadWheelPrototype", true, false), 14)
	_guide_wheels = _instances(model_root.find_child("GuideWheelPrototype", true, false), 4)
	_update_meshes()

func _instances(prototype: MeshInstance3D, count: int) -> MultiMesh:
	var geometry := MultiMesh.new()
	geometry.transform_format = MultiMesh.TRANSFORM_3D
	geometry.mesh = prototype.mesh
	geometry.custom_aabb = AABB(Vector3(-1.65, 0.0, -2.4), Vector3(3.3, 0.95, 4.8))
	geometry.instance_count = count
	var view := MultiMeshInstance3D.new()
	view.multimesh = geometry
	add_child(view)
	prototype.hide()
	return geometry

func advance(delta: float, metres: float, near_camera: bool) -> void:
	_track_phase = fposmod(_track_phase - metres, LINK_PITCH)
	_wheel_phase = fposmod(_wheel_phase + metres / 0.278, TAU)
	_tick += delta
	if near_camera and _tick >= 1.0 / 30.0:
		_tick = 0.0
		_update_meshes()

func _update_meshes() -> void:
	for side in 2:
		var x := -1.306 if side == 0 else 1.306
		var wheel_basis := Basis(Vector3.RIGHT, _wheel_phase)
		if side == 0:
			wheel_basis *= Basis(Vector3.UP, PI)
		for wheel in 7:
			_road_wheels.set_instance_transform(side * 7 + wheel, Transform3D(wheel_basis, Vector3(x, 0.33, 1.86 - wheel * 0.62)))
		for wheel in 2:
			_guide_wheels.set_instance_transform(side * 2 + wheel, Transform3D(wheel_basis, Vector3(x, 0.408, 1.95 - wheel * 3.9)))
		for link in LINKS_PER_SIDE:
			var s := _track_phase + link * LINK_PITCH
			var z := 1.95 - s
			var height := RADIUS
			var angle := 0.0
			if s >= 2.0 * STRAIGHT + HALF_ARC:
				var arc := (s - 2.0 * STRAIGHT - HALF_ARC) / RADIUS
				z = 1.95 + RADIUS * sin(arc)
				height = -RADIUS * cos(arc)
				angle = -PI - arc
			elif s >= STRAIGHT + HALF_ARC:
				z = -1.95 + s - STRAIGHT - HALF_ARC
				height = -RADIUS
				angle = -PI
			elif s >= STRAIGHT:
				var arc := (s - STRAIGHT) / RADIUS
				z = -1.95 - RADIUS * sin(arc)
				height = RADIUS * cos(arc)
				angle = -arc
			var piece := Transform3D(Basis(Vector3.RIGHT, angle), Vector3(x, 0.375 + height, z))
			_tracks.set_instance_transform(side * LINKS_PER_SIDE + link, piece)
