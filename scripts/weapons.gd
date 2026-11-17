extends RefCounted
## Waffenfeuer: Sofortwaffen direkt, Geschosse als Projektil-Knoten.

const FX = preload("res://scripts/fx.gd")
const Projectile = preload("res://scripts/projectile.gd")

static func fire(src, pid: int, w: Dictionary, from: Vector3, target, tpos: Vector3, mult: float) -> void:
	var dmg: float = w["dmg"] * mult
	var tvalid: bool = target != null and is_instance_valid(target) and target.alive
	var wt: String = w["type"]
	match wt:
		"bullet", "flak":
			var hit = tpos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
			FX.muzzle(from, Color(1, 0.8, 0.4), 0.6)
			FX.tracer(from, hit, Color(1.0, 0.72, 0.3) if wt == "bullet" else Color(1.0, 0.5, 0.25))
			if tvalid:
				Game.apply_damage(target, dmg, wt, pid, src)
			FX.impact(hit)
		"laser":
			FX.beam(from, tpos, Color(0.3, 0.9, 1.0), 0.25, 0.2, 5.0)
			FX.muzzle(from, Color(0.4, 0.9, 1.0), 1.0)
			if tvalid:
				Game.apply_damage(target, dmg, wt, pid, src)
			FX.impact(tpos, Color(0.4, 0.9, 1.0))
		"flame":
			FX.flame_jet(from, tpos)
			Game.damage_area(tpos, w["splash"], dmg, "flame", pid, src)
		"toxin":
			FX.toxin_spray(from, tpos)
			Game.damage_area(tpos, w["splash"], dmg, "toxin", pid, src)
		_:
			var p = Projectile.new()
			Game.fx_root.add_child(p)
			p.launch(src, pid, w, from, target if tvalid else null, tpos, dmg)
