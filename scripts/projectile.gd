extends Node3D
## Fliegendes Geschoss: Granate, Rakete oder Artilleriegeschoss.

const FX = preload("res://scripts/fx.gd")

var src
var pid = 0
var w: Dictionary
var target = null
var tpos = Vector3.ZERO
var start = Vector3.ZERO
var dmg = 0.0
var t = 0.0
var dur = 1.0
var homing = false
var arc = 0.0
var toxic = false
var trail: GPUParticles3D
var mesh: MeshInstance3D

static var _shell_mesh: Mesh
static var _rocket_mesh: Mesh
static var _shell_mat: Material
static var _rocket_mat: Material

func launch(s, p: int, weapon: Dictionary, from: Vector3, tgt, to: Vector3, damage: float) -> void:
	src = s
	pid = p
	w = weapon
	target = tgt
	tpos = to
	start = from
	dmg = damage
	global_position = from
	toxic = s != null and is_instance_valid(s) and s.def.get("faction", "") == "shadow" and w["type"] == "artillery"
	var dist = from.distance_to(to)
	var speed = 60.0
	match w["type"]:
		"rocket":
			speed = 38.0
			homing = target != null
			arc = dist * 0.08
		"torpedo":
			speed = 20.0
			homing = target != null
			arc = 0.0
		"artillery":
			speed = 32.0
			arc = clamp(dist * 0.35, 6.0, 22.0)
		"bomb":
			speed = 15.0
			arc = 0.0
		_:
			speed = 70.0
	dur = max(dist / speed, 0.05)
	_build_visual()
	if w["type"] == "shell":
		FX.muzzle(from, Color(1, 0.7, 0.3), 1.4)
	elif w["type"] == "artillery":
		FX.muzzle(from, Color(1, 0.7, 0.3), 2.0)
		FX.dust(from - Vector3(0, 1.5, 0), 0.8)
	else:
		FX.muzzle(from, Color(1, 0.7, 0.3), 0.7)

func _build_visual() -> void:
	if _shell_mesh == null:
		var sm = SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		sm.radial_segments = 8
		sm.rings = 4
		_shell_mesh = sm
		var cm = CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.12
		cm.height = 0.9
		cm.radial_segments = 6
		_rocket_mesh = cm
		var m1 = StandardMaterial3D.new()
		m1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m1.albedo_color = Color(4.0, 2.4, 0.9)
		_shell_mat = m1
		var m2 = StandardMaterial3D.new()
		m2.albedo_color = Color(0.7, 0.7, 0.68)
		m2.metallic = 0.6
		m2.roughness = 0.4
		_rocket_mat = m2
	mesh = MeshInstance3D.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if w["type"] == "rocket" or w["type"] == "artillery" or w["type"] == "bomb" or w["type"] == "torpedo":
		mesh.mesh = _rocket_mesh
		mesh.material_override = _rocket_mat
		mesh.rotation.x = PI / 2
		if w["type"] == "artillery":
			mesh.scale = Vector3(2.0, 1.6, 2.0)
		if w["type"] == "bomb":
			mesh.scale = Vector3(1.9, 1.4, 1.9)
			mesh.material_override = _shell_mat if false else _rocket_mat
		else:
			trail = FX.trail(self, toxic)
	else:
		mesh.mesh = _shell_mesh
		mesh.material_override = _shell_mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if not Game.running:
		return
	t += delta
	if homing and target != null and is_instance_valid(target) and target.alive:
		tpos = target.aim_point() if not target.is_building else target.position + Vector3(0, 1.5, 0)
	var k: float = clamp(t / dur, 0.0, 1.0)
	var p = start.lerp(tpos, k)
	p.y += sin(k * PI) * arc
	var prev = global_position
	global_position = p
	if p.distance_to(prev) > 0.01:
		var up = Vector3.UP if abs((p - prev).normalized().y) < 0.98 else Vector3.RIGHT
		look_at(p + (p - prev), up)
	visible = Game.is_visible_cell(p)
	if k >= 1.0:
		_impact()

func _impact() -> void:
	var wt: String = w["type"]
	var splash: float = w["splash"]
	var hit_air: bool = target != null and is_instance_valid(target) and target.flying
	if splash > 0.0:
		Game.damage_area(tpos, splash, dmg, wt, pid, src, hit_air)
	elif target != null and is_instance_valid(target) and target.alive:
		if Game.flat_dist(target.position, tpos) < target.radius + 2.5:
			Game.apply_damage(target, dmg, wt, pid, src)
	match wt:
		"artillery":
			FX.explosion(tpos, 1.6 if not toxic else 2.2, toxic)
			if toxic:
				FX.toxin_cloud(tpos, 5.0, 4.0)
		"bomb":
			FX.explosion(tpos, 1.7)
		"rocket":
			FX.explosion(tpos, 0.6)
		"torpedo":
			FX.explosion(tpos, 1.3)
			FX.ring(tpos + Vector3(0, 0.1, 0), Color(0.8, 0.95, 1.0, 0.8), 4.0, 0.8)
		_:
			FX.explosion(tpos, 0.5)
	if trail != null:
		var gt = trail.global_transform
		remove_child(trail)
		Game.fx_root.add_child(trail)
		trail.global_transform = gt
		trail.emitting = false
		var tw = trail.create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(trail.queue_free)
	queue_free()
