extends Node3D
## Nachschubdepot: Kistenstapel, aus dem Sammler Credits holen.

var is_unit = false
var is_building = false
var is_depot = true
var alive = true
var flying = false
var owner_id = -1
var radius = 2.6
var supply = 40000.0
var max_supply = 40000.0
var def = {"name": "Nachschubdepot", "cost": 0}
var crates: Array = []
var selected = false

func build() -> void:
	var pad = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(5.5, 0.3, 5.5)
	pad.mesh = pm
	pad.material_override = Game.fog_material(Color(0.35, 0.33, 0.3), 0.95)
	pad.position.y = 0.1
	add_child(pad)
	var bm = BoxMesh.new()
	bm.size = Vector3(1.05, 1.05, 1.05)
	var m = Game.fog_material(Color(0.55, 0.42, 0.22), 0.85)
	var m2 = Game.fog_material(Color(0.25, 0.35, 0.2), 0.8)
	for y in 3:
		for z in 4:
			for x in 4:
				if y == 2 and (x == 0 or x == 3 or z == 0 or z == 3):
					continue
				if y == 1 and (x + z) % 3 == 0 and (x == 0 or z == 0):
					continue
				var c = MeshInstance3D.new()
				c.mesh = bm
				c.material_override = m if (x + y + z) % 4 != 0 else m2
				c.position = Vector3(-1.65 + x * 1.1, 0.78 + y * 1.08, -1.65 + z * 1.1)
				c.rotation.y = randf_range(-0.12, 0.12)
				add_child(c)
				crates.append(c)

func take(amount: float) -> float:
	var got: float = min(amount, supply)
	supply -= got
	var keep = int(ceil(crates.size() * supply / max_supply))
	for i in crates.size():
		crates[i].visible = i < keep
	return got

func aim_point() -> Vector3:
	return position + Vector3(0, 1.5, 0)
