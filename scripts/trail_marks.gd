extends MultiMeshInstance3D
## Ketten- und Reifenspuren im Gelände, die nach einiger Zeit verblassen (wie in C&C Generäle).
## Ein einziger MultiMesh-Ringpuffer für die ganze Karte: jede Spur ist ein flaches Viereck auf dem Boden, gedreht in
## Fahrtrichtung und an die Geländeneigung angelehnt. Das Verblassen rechnet der Shader aus der Entstehungszeit.

const CAP := 4000
const SEG := 0.7          # Länge eines Abdrucks in Metern

static var inst = null
var _next := 0
var _mat: ShaderMaterial

static func get_or_make() -> Node:
	if inst != null and is_instance_valid(inst):
		return inst
	if Game.fx_root == null:
		return null
	inst = load("res://scripts/trail_marks.gd").new()
	Game.fx_root.add_child(inst)
	return inst

func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, SEG + 0.06)
	q.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = CAP
	mm.visible_instance_count = CAP
	for i in CAP:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.001, 1, 0.001)), Vector3(0, -50, 0)))
		mm.set_instance_custom_data(i, Color(-999.0, 0, 0, 0))
	multimesh = mm
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/trail_mark.gdshader")
	_mat.set_shader_parameter("fog_tex", Game.fog_tex)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 400, 4000))

func _process(_delta: float) -> void:
	_mat.set_shader_parameter("now", Game.time)

## Ein Abdruck: Mitte p, Fahrtrichtung heading (Bogenmaß), Breite w, Art (true = Kette).
func add(p: Vector3, heading: float, w: float, tracked: bool) -> void:
	var t = Game.terrain
	if t == null:
		return
	var y: float = t.height_at(p.x, p.z)
	if y < t.WATER_Y + 0.15:
		return   # keine Spuren im Wasser
	var n: Vector3 = t.normal_at(p.x, p.z)
	var fwd := Vector3(sin(heading), 0, cos(heading))
	fwd = (fwd - n * fwd.dot(n)).normalized()
	var right := n.cross(fwd).normalized()
	var b := Basis(right * w, n, fwd)
	var strength := 1.0
	if Game.on_road(p):
		strength = 0.45   # auf befestigtem Weg kaum sichtbar
	elif Game.rain > 0.3:
		strength = 1.35   # Matsch
	multimesh.set_instance_transform(_next, Transform3D(b, Vector3(p.x, y + 0.06, p.z)))
	multimesh.set_instance_custom_data(_next, Color(Game.time, 1.0 if tracked else 0.0, strength, 0))
	_next = (_next + 1) % CAP
