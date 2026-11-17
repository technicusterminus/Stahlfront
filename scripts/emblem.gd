extends Control
## Fraktionswappen für die Kopfleiste (vektorgezeichnet).

var faction = "west"
var tint = Color.WHITE

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_faction(f: String, col: Color) -> void:
	faction = f
	tint = col
	queue_redraw()

func _draw() -> void:
	var c = size * 0.5
	var r = min(size.x, size.y) * 0.5 - 2.0
	match faction:
		"red":
			# Rote Scheibe mit Zahnkranz und goldenem Stern
			for i in 12:
				var a = TAU * i / 12.0
				draw_circle(c + Vector2(cos(a), sin(a)) * (r - 1.0), 2.6, Color(0.75, 0.6, 0.3))
			draw_circle(c, r - 3.0, Color(0.55, 0.07, 0.05))
			draw_arc(c, r - 3.0, 0, TAU, 40, Color(0.85, 0.7, 0.35), 1.8)
			var pts = PackedVector2Array()
			for i in 10:
				var a = -PI / 2 + i * TAU / 10.0
				var rr = (r - 8.0) if i % 2 == 0 else (r - 8.0) * 0.42
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
		"shadow":
			# Holzscheibe mit Flamme
			draw_circle(c, r, Color(0.2, 0.12, 0.06))
			draw_arc(c, r - 1.0, 0, TAU, 36, Color(0.55, 0.38, 0.2), 2.0)
			var flame = PackedVector2Array([c + Vector2(0, r * 0.55), c + Vector2(-r * 0.42, r * 0.1), c + Vector2(-r * 0.2, -r * 0.15), c + Vector2(-r * 0.05, -r * 0.7),
				c + Vector2(r * 0.18, -r * 0.2), c + Vector2(r * 0.42, r * 0.12)])
			draw_colored_polygon(flame, Color(0.95, 0.5, 0.1))
			var core = PackedVector2Array([c + Vector2(0, r * 0.45), c + Vector2(-r * 0.2, r * 0.12), c + Vector2(0, -r * 0.25), c + Vector2(r * 0.2, r * 0.12)])
			draw_colored_polygon(core, Color(1.0, 0.85, 0.4))
			draw_line(c + Vector2(-r * 0.5, r * 0.6), c + Vector2(r * 0.5, r * 0.45), Color(0.4, 0.26, 0.13), 3.0)
			draw_line(c + Vector2(-r * 0.5, r * 0.45), c + Vector2(r * 0.5, r * 0.6), Color(0.4, 0.26, 0.13), 3.0)
		_:
			# Leuchtender Ring mit Winkelzeichen
			draw_circle(c, r, Color(0.04, 0.1, 0.16, 0.9))
			draw_arc(c, r - 1.0, 0, TAU, 44, Color(0.4, 0.88, 1.0), 2.2)
			draw_arc(c, r - 5.0, PI * 0.15, PI * 0.85, 20, Color(0.4, 0.88, 1.0, 0.6), 1.5)
			var ch = PackedVector2Array([c + Vector2(-r * 0.5, r * 0.25), c + Vector2(0, -r * 0.4), c + Vector2(r * 0.5, r * 0.25), c + Vector2(r * 0.5, r * 0.45), c + Vector2(0, -r * 0.1), c + Vector2(-r * 0.5, r * 0.45)])
			draw_colored_polygon(ch, Color(0.55, 0.95, 1.0))
