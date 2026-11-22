extends Node3D
## Neutrale Völker: Dorfbewohner und Milizen. Reine Atmosphäre, kein Eingriff ins Gefecht.
## Jedes Dorf gehört einem Volk (Talvolk, Bergvolk, Uferleute) mit eigener Tracht. Die Leute laufen um die Feuerstelle,
## die Miliz zieht mit Speer und Laterne ihre Runde. Nähern sich Bewaffnete, ducken sich die Bewohner ins Haus
## (sie verschwinden), die Miliz stellt sich dem Fremden in den Weg und hält Abstand.

const PEOPLES := {
	"tal": {"name": "Talvolk", "cloth": Color(0.62, 0.5, 0.34), "hat": Color(0.45, 0.36, 0.22), "sash": Color(0.7, 0.62, 0.25)},
	"berg": {"name": "Bergvolk", "cloth": Color(0.55, 0.2, 0.18), "hat": Color(0.2, 0.18, 0.17), "sash": Color(0.85, 0.8, 0.7)},
	"ufer": {"name": "Uferleute", "cloth": Color(0.22, 0.42, 0.45), "hat": Color(0.75, 0.7, 0.55), "sash": Color(0.9, 0.55, 0.25)},
}
const SKIN := [Color(0.86, 0.68, 0.55), Color(0.72, 0.52, 0.38), Color(0.55, 0.38, 0.28)]

var rng := RandomNumberGenerator.new()
var folk: Array = []
var _check := 0.0
var _test_reveal := OS.get_cmdline_user_args().has("--revealall")
var _flat_cache := {}

func setup(sp: Dictionary, starts: Array) -> void:
	rng.seed = int(sp["seed"]) * 13 + 5
	var Settle = load("res://scripts/settlement.gd")
	for s in sp.get("sites", []):
		var kind := String(s["kind"])
		if kind != "village" and kind != "camp":
			continue
		var c: Vector2 = Settle.resolve(s["at"], starts)
		var y: float = Game.terrain.height_at(c.x, c.y)
		if y < Game.terrain.WATER_Y + 0.5:
			continue
		var r: float = float(s.get("r", 12.0))
		var ruin: float = float(s.get("ruin", 0.0))
		var key: String = ["tal", "berg", "ufer"][int(s.get("seed", 1)) % 3]
		var pop: int = int(round(r * 0.45 * (1.0 - ruin))) if kind == "village" else 3
		var mil: int = 2 if kind == "village" else 3
		for i in pop:
			folk.append(_make(key, c, r, false, i))
		for i in mil:
			folk.append(_make(key, c, r, true, i))

func _mat(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if _flat_cache.has(k):
		return _flat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	_flat_cache[k] = m
	return m

func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _make(key: String, c: Vector2, r: float, militia: bool, idx: int) -> Dictionary:
	var pe: Dictionary = PEOPLES[key]
	var n := Node3D.new()
	add_child(n)
	var scale_f := rng.randf_range(0.92, 1.08)
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 1.15
	var cloth: Color = pe["cloth"].darkened(0.25) if militia else pe["cloth"].lerp(Color(0.6, 0.55, 0.5), rng.randf_range(0.0, 0.35))
	var rig := Node3D.new()
	n.add_child(rig)
	_part(rig, body, cloth, Vector3(0, 0.78, 0))
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	_part(rig, head, SKIN[rng.randi() % 3], Vector3(0, 1.5, 0))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.215
	belt.bottom_radius = 0.215
	belt.height = 0.07
	_part(rig, belt, pe["sash"], Vector3(0, 0.82, 0))
	var hat := CylinderMesh.new()
	hat.top_radius = 0.03 if not militia else 0.12
	hat.bottom_radius = 0.26 if not militia else 0.17
	hat.height = 0.16 if not militia else 0.2
	_part(rig, hat, pe["hat"], Vector3(0, 1.66, 0))
	var light: OmniLight3D = null
	if militia:
		var spear := CylinderMesh.new()
		spear.top_radius = 0.015
		spear.bottom_radius = 0.02
		spear.height = 2.2
		_part(rig, spear, Color(0.38, 0.3, 0.2), Vector3(0.3, 1.1, 0.05))
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.04
		tip.height = 0.2
		_part(rig, tip, Color(0.75, 0.78, 0.8), Vector3(0.3, 2.25, 0.05))
		var shield := CylinderMesh.new()
		shield.top_radius = 0.26
		shield.bottom_radius = 0.26
		shield.height = 0.05
		var sh := _part(rig, shield, pe["sash"], Vector3(-0.28, 0.95, 0.05))
		sh.rotation.z = PI / 2.0
		if idx == 0:
			var lamp := SphereMesh.new()
			lamp.radius = 0.07
			lamp.height = 0.14
			var lm := _part(rig, lamp, Color(1.0, 0.75, 0.35), Vector3(-0.36, 1.35, 0.15))
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(1.0, 0.75, 0.35)
			lmat.emission_enabled = true
			lmat.emission = Color(1.0, 0.65, 0.25)
			lmat.emission_energy_multiplier = 2.0
			lm.material_override = lmat
			light = OmniLight3D.new()
			light.light_color = Color(1.0, 0.7, 0.35)
			light.omni_range = 5.0
			light.light_energy = 0.8
			light.position = Vector3(-0.36, 1.35, 0.15)
			rig.add_child(light)
	rig.scale = Vector3.ONE * scale_f
	var f := {"node": n, "rig": rig, "center": c, "r": r, "militia": militia, "pos": Vector2.ZERO, "target": Vector2.ZERO,
		"wait": rng.randf_range(0.5, 6.0), "speed": rng.randf_range(0.8, 1.1) * (0.75 if militia else 1.0), "hide": 0.0,
		"phase": rng.randf() * TAU, "ring": rng.randf() * TAU}
	f["pos"] = _spot(f)
	f["target"] = f["pos"]
	n.position = _world(f["pos"])
	return f

func _spot(f: Dictionary) -> Vector2:
	var c: Vector2 = f["center"]
	var rr: float = float(f["r"])
	if f["militia"]:
		f["ring"] = float(f["ring"]) + rng.randf_range(0.5, 1.2)
		return c + Vector2(cos(f["ring"]), sin(f["ring"])) * rr * 0.4
	var a := rng.randf() * TAU
	var d := rr * rng.randf_range(0.06, 0.34)
	return c + Vector2(cos(a), sin(a)) * d

func _world(p: Vector2) -> Vector3:
	return Vector3(p.x, Game.terrain.height_at(p.x, p.y), p.y)

func _process(delta: float) -> void:
	if not Game.running:
		return
	_check -= delta
	if _check < -50.0: _check = 0.0
	var armed_near := _check <= 0.0
	if armed_near:
		_check = 0.5
	for f in folk:
		var n: Node3D = f["node"]
		if armed_near:
			f["alert"] = _threat(f)
		var alert: Vector3 = f.get("alert", Vector3.INF)
		var scared: bool = alert != Vector3.INF
		if f["militia"]:
			f["hide"] = 0.0
		elif scared:
			f["hide"] = 14.0
		else:
			f["hide"] = max(0.0, float(f["hide"]) - delta)
		var hidden: bool = float(f["hide"]) > 0.0
		n.visible = not hidden and (Game.is_visible_cell(n.position) or _test_reveal)
		if hidden:
			continue
		var p: Vector2 = f["pos"]
		var moving := false
		if f["militia"] and scared:
			# dem Fremden zugewandt stehen bleiben
			var to := Vector2(alert.x, alert.z) - p
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.y), delta * 4.0)
		elif p.distance_to(f["target"]) > 0.25:
			var dir: Vector2 = (f["target"] - p).normalized()
			p += dir * float(f["speed"]) * delta
			f["pos"] = p
			n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.y), delta * 6.0)
			moving = true
		else:
			f["wait"] = float(f["wait"]) - delta
			if float(f["wait"]) <= 0.0:
				f["wait"] = rng.randf_range(2.0, 9.0) if not f["militia"] else rng.randf_range(0.5, 2.5)
				f["target"] = _spot(f)
		f["phase"] = float(f["phase"]) + delta * (8.0 if moving else 1.2)
		var rig: Node3D = f["rig"]
		rig.position.y = abs(sin(f["phase"])) * 0.06 if moving else sin(f["phase"]) * 0.01
		rig.rotation.z = sin(f["phase"]) * 0.05 if moving else 0.0
		n.position = _world(f["pos"])

## Nächste bewaffnete Einheit (egal welcher Seite) in Dorfnähe; Vector3.INF wenn keine.
func _threat(f: Dictionary) -> Vector3:
	var c: Vector2 = f["center"]
	var rad: float = float(f["r"]) + 6.0
	var best := Vector3.INF
	var bd := rad
	for u in Game.units:
		if not u.alive or u.def.get("weapon") == null:
			continue
		var d := Vector2(u.position.x - c.x, u.position.z - c.y).length()
		if d < bd:
			bd = d
			best = u.position
	return best
