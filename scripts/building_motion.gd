extends Node3D
## Kleine Arbeitsabläufe an den Außenseiten. Alle Bewegungen sind rein visuell.

const M = preload("res://scripts/models.gd")

var _role := ""
var _time := 0.0
var _running := 0.0
var _pivot: Node3D
var _hoist: Node3D
var _secondary: Node3D
var _points: Array[MeshInstance3D] = []
var _cloth: Array[Node3D] = []
var _lamp_off: Material
var _lamp_on: Material
var _latest_lamp := -2

func setup(d: Dictionary, color: Color, dock_side: float) -> void:
	_role = d["role"]
	var half := float(d["size"])
	position = Vector3(-half + minf(half * 0.26, 1.15), 0.06, dock_side * (half + 0.30))
	if _role == "factory":
		position.z += 0.72  # Außerhalb des Vordachs.
	rotation.y = PI if dock_side < 0.0 else 0.0
	var base := M.mat(Color(0.16, 0.17, 0.17), 0.12, 0.74)
	var steel := M.mat(Color(0.28, 0.30, 0.30), 0.58, 0.52)
	var accent := M.mat(color.lerp(Color(0.22, 0.22, 0.19), 0.31), 0.14, 0.63)
	var carry := M.mat(Color(0.45, 0.36, 0.23), 0.0, 0.86)
	_lamp_off = M.mat(Color(0.32, 0.37, 0.34), 0.0, 0.43)
	_lamp_on = M.mat(Color(0.52, 0.92, 0.75), 0.0, 0.36, 1.65)
	match _role:
		"factory", "dock":
			_hoist = load("res://scripts/building_hoist.gd").new()
			add_child(_hoist)
			_hoist.setup(base, steel, M.hard("industrial", accent.albedo_color), carry)
		"supply":
			for x in [-0.28, 0.28]:
				M.box(self, Vector3(0.07, 0.08, 1.32), Vector3(x, 0.06, 0.04), steel)
			_pivot = _at(self, Vector3(0, 0.14, 0))
			M.box(_pivot, Vector3(0.48, 0.09, 0.41), Vector3.ZERO, accent)
			_secondary = _at(_pivot, Vector3(0, 0.14, 0))
			for side in [-1.0, 1.0]:
				M.box(_pivot, Vector3(0.07, 0.26, 0.10), Vector3(side * 0.20, 0.12, -0.13), steel)
				M.box(_secondary, Vector3(0.062, 0.05, 0.39), Vector3(side * 0.13, -0.075, 0), steel)
			M.box(_secondary, Vector3(0.35, 0.25, 0.32), Vector3(0, 0.085, 0), carry)
			M.box(_secondary, Vector3(0.36, 0.044, 0.33), Vector3(0, 0.16, 0), accent)
		"power", "super":
			M.box(self, Vector3(0.89, 0.35, 0.62), Vector3(0, 0.20, 0), base)
			_pivot = _at(self, Vector3(0, 0.43, 0))
			M.cyl(self, 0.36, 0.37, 0.09, Vector3(0, 0.385, 0), steel, Vector3.ZERO, 18)
			M.cyl(_pivot, 0.105, 0.12, 0.06, Vector3.ZERO, accent, Vector3.ZERO, 12)
			for i in 5:
				var blade := _at(_pivot, Vector3.ZERO)
				blade.rotation.y = TAU * i / 5.0
				M.box(blade, Vector3(0.115, 0.026, 0.24), Vector3(0, 0, 0.19), base, Vector3(0, -0.32, 0.19))
			_secondary = _at(self, Vector3(0.33, 0.45, 0.24))
			M.box(_secondary, Vector3(0.09, 0.028, 0.15), Vector3.ZERO, _lamp_on)
		"airfield":
			M.cyl(self, 0.027, 0.055, 1.39, Vector3(0, 0.73, 0), steel, Vector3.ZERO, 10)
			_pivot = _at(self, Vector3(0, 1.43, 0))
			var tip := _pivot
			for i in 4:
				var section := _at(tip, Vector3(0, 0, 0.15 if i > 0 else 0.0))
				M.cyl(section, 0.115 - 0.013 * i, 0.126 - 0.013 * i, 0.166, Vector3(0, 0, 0.077), accent if i % 2 == 0 else carry, Vector3(PI / 2, 0, 0), 10)
				_cloth.append(section)
				tip = section
			for i in 4:
				_points.append(M.box(self, Vector3(0.11, 0.049, 0.11), Vector3(0.23 + i * 0.22, 0.075, 0), _lamp_off))
		"hq", "defense", "tech", "barracks":
			M.box(self, Vector3(0.52, 0.12, 0.48), Vector3(0, 0.07, 0), base)
			M.cyl(self, 0.06, 0.11, 0.85, Vector3(0, 0.49, 0), steel, Vector3.ZERO, 10)
			_pivot = _at(self, Vector3(0, 0.94, 0))
			_secondary = _at(_pivot, Vector3.ZERO)
			var head_size := Vector3(0.49, 0.14, 0.23) if _role in ["hq", "tech"] else Vector3(0.23, 0.19, 0.28)
			M.box(_secondary, head_size, Vector3(0, 0, 0.02), accent)
			M.box(_secondary, Vector3(head_size.x * 0.66, 0.075, 0.021), Vector3(0, 0, head_size.z * 0.53 + 0.02), base)
			_points.append(M.box(_secondary, Vector3(0.046, 0.04, 0.023), Vector3(0, 0.015, head_size.z * 0.61 + 0.025), _lamp_off))

func _at(parent: Node3D, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = point
	parent.add_child(node)
	return node

func advance(delta: float, has_power: bool, active: bool) -> void:
	_running = move_toward(_running, 1.0 if has_power else 0.0, delta * 0.63)
	if _hoist != null:
		_hoist.advance(delta, _running, active)
		return
	if _pivot == null:
		return
	_time += delta * _running
	var t := _time + fposmod(position.x * 0.73 + global_position.z * 0.18, TAU)
	match _role:
		"supply":
			var cycle := fposmod(t, 5.8)
			var roll: float = smoothstep(0.8, 2.0, cycle) - smoothstep(3.25, 4.63, cycle)
			var hold: float = smoothstep(0.25, 0.92, cycle) - smoothstep(2.27, 2.89, cycle)
			_pivot.position.z = (roll - 0.50) * 0.78
			_secondary.position.y = 0.095 + hold * 0.24
			_secondary.rotation.x = sin(t * 4.0) * 0.016 * hold
		"power", "super":
			_pivot.rotation.y += delta * _running * (2.3 if _role == "power" or active else 0.82)
			_secondary.visible = has_power and (not active or fposmod(t, 0.75) < 0.4)
		"airfield":
			_pivot.rotation.y = sin(Game.time * 0.63) * 0.63 - 0.25
			for i in _cloth.size():
				_cloth[i].rotation.x = sin(Game.time * 4.2 - i * 0.67) * 0.14 + 0.13 * i
			_set_lamps(int(t * 4.5) % _points.size() if active and has_power else -1)
		_:
			_pivot.rotation.y = sin(t * (1.28 if active else 0.61)) * (0.84 if active else 0.43)
			_secondary.rotation.x = sin(t * 1.37 + 0.6) * 0.13
			_set_lamps(0 if has_power and fposmod(t, 2.4) > 2.13 else -1)

func _set_lamps(index: int) -> void:
	if index == _latest_lamp:
		return
	_latest_lamp = index
	for i in _points.size():
		_points[i].material_override = _lamp_on if i == index else _lamp_off
