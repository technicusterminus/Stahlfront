extends RefCounted
## Fraktionsoberflächen. Alle Texturen entstehen im Code:
##   Westbund      – Rauchglas über gebürstetem Titan, feine Cyan-Leuchtkante, Eckmarken, moderne Schrift
##   Rote Allianz  – Stahlplatte mit Messingfassung und Nieten, abgeschrägte Ecken, rote Zierlinie, kräftige Schrift
##   Schattenfront – geöltes Leder mit Fadennaht und Bronzebeschlägen, Serifenschrift

static var _cache = {}

const VOCAB = {
	"west": {"credits": "Mittel", "power": "Energie", "rank": "Kommando-Stufe %d", "point": ["Punkt", "Punkte"],
		"powers": "Befehlsprotokolle", "menu": "Menü (Esc)", "help": "Hilfe (F1)", "time": "Einsatzzeit"},
	"red": {"credits": "Volkskasse", "power": "Strom", "rank": "Marschallsrang %d", "point": ["Orden", "Orden"],
		"powers": "Parteibefehle", "menu": "Pause (Esc)", "help": "Anleitung (F1)", "time": "Frontzeit"},
	"shadow": {"credits": "Beute", "power": "Kraft", "rank": "Ansehen %d", "point": ["Gefallen", "Gefallen"],
		"powers": "Tricks der Runde", "menu": "Rast (Esc)", "help": "Rat (F1)", "time": "Zeit am Feuer"},
}

static func vocab(fid: String) -> Dictionary:
	return VOCAB.get(fid, VOCAB["west"])

# ---------------------------------------------------------------- Bildhilfen

## Vorzeichenbehaftete Entfernung zu einem abgerundeten Rechteck (negativ = innen).
static func _sd_rr(px: float, py: float, x0: float, y0: float, x1: float, y1: float, r: float) -> float:
	var cx = (x0 + x1) * 0.5
	var cy = (y0 + y1) * 0.5
	var qx = abs(px - cx) - (x1 - x0) * 0.5 + r
	var qy = abs(py - cy) - (y1 - y0) * 0.5 + r
	return Vector2(max(qx, 0.0), max(qy, 0.0)).length() + min(max(qx, qy), 0.0) - r

## Abstand zur Kontur eines Rechtecks mit abgeschrägten Ecken (>= 0 innen).
static func _chamfer(x: float, y: float, w: float, h: float, inset: float, c: float) -> float:
	var e = min(min(x - inset, w - 1.0 - inset - x), min(y - inset, h - 1.0 - inset - y))
	var s = 0.7071
	var tl = ((x - inset) + (y - inset) - c) * s
	var tr = ((w - 1.0 - inset - x) + (y - inset) - c) * s
	var bl = ((x - inset) + (h - 1.0 - inset - y) - c) * s
	var br = ((w - 1.0 - inset - x) + (h - 1.0 - inset - y) - c) * s
	return min(min(e, tl), min(tr, min(bl, br)))

static func _noise(seed_val: int, freq: float) -> FastNoiseLite:
	var n = FastNoiseLite.new()
	n.seed = seed_val
	n.frequency = freq
	n.fractal_octaves = 3
	return n

static func _rivet(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(int(cy - r - 2), int(cy + r + 3)):
		for x in range(int(cx - r - 2), int(cx + r + 3)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d = Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r:
				var hl = clamp(1.0 - Vector2(x + 0.5 - cx + r * 0.35, y + 0.5 - cy + r * 0.35).length() / r, 0.0, 1.0)
				img.set_pixel(x, y, col.lightened(hl * 0.45).darkened((d / r) * 0.25))
			elif d <= r + 1.6:
				var o = img.get_pixel(x, y)
				img.set_pixel(x, y, o.darkened(0.45))

# ---------------------------------------------------------------- Hochwertige Fassung (Materialbild + gezeichneter Rahmen)
## Oberfläche aus models/ui/<fraktion>_material.png (Bildmodell, kachelbar), Rahmen, Nähte, Nieten und Beschläge im Code.
## Größer aufgelöst als früher (256 px Tafel, 220×72 Knopf) und mit weichen Kanten, damit nichts verwaschen wirkt.

static var _mats := {}

static func _mat(fid: String) -> Image:
	if not _mats.has(fid):
		var path := "res://models/ui/%s_material.png" % fid
		var img: Image = null
		if ResourceLoader.exists(path):
			img = (load(path) as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()
		if img == null:
			img = Image.create(8, 8, false, Image.FORMAT_RGB8)
			img.fill(Color(0.12, 0.12, 0.13))
		_mats[fid] = img
	return _mats[fid]

static func _ss(e0: float, e1: float, x: float) -> float:
	var t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Grundform je Fraktion: Abstand zur Kante (>0 innen). West rund, Rot abgeschrägt, Schatten weich gerundet.
static func _edge(fid: String, x: float, y: float, w: float, h: float, r: float) -> float:
	if fid == "red":
		return _chamfer(x, y, w, h, 1.0, r)
	return -_sd_rr(x + 0.5, y + 0.5, 1.0, 1.0, w - 1.0, h - 1.0, r)

static func _premium(fid: String, W: int, H: int, state: String, is_button: bool) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var m: Image = _mat(fid)
	var mw := m.get_width()
	var mh := m.get_height()
	var r := 14.0 if fid == "west" else (16.0 if fid == "red" else 12.0)
	if is_button:
		r = 9.0 if fid == "west" else (10.0 if fid == "red" else 8.0)
	var rim := Color(0.45, 0.88, 1.0)
	var tint := Color(1.0, 1.0, 1.0)
	var alpha := 0.92
	var light := 1.0
	if fid == "red":
		rim = Color(0.86, 0.66, 0.32)
		tint = Color(1.05, 0.98, 0.95)
		alpha = 0.96
	elif fid == "shadow":
		rim = Color(0.72, 0.52, 0.28)
		tint = Color(1.12, 1.0, 0.9)
		alpha = 0.96
	if is_button:
		match state:
			"hover":
				light = 1.4
				rim = rim.lightened(0.3)
			"pressed":
				light = 0.72
			"disabled":
				light = 0.65
				rim = Color(0.36, 0.36, 0.37)
				alpha *= 0.85
	var thread := Color(0.86, 0.74, 0.52) if state != "disabled" else Color(0.45, 0.42, 0.38)
	var st_d := 5.5 if is_button else 9.0
	for y in H:
		var vy := float(y) / float(H)
		for x in W:
			var e := _edge(fid, x, y, W, H, r)
			if e <= -0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var cov := _ss(-0.5, 0.8, e)
			var mc: Color = m.get_pixel(x % mw, y % mh)
			var c := Color(mc.r * tint.r * light, mc.g * tint.g * light, mc.b * tint.b * light)
			# sanfte Wölbung: oben heller, unten dunkler, Rand abgedunkelt
			c = Color(c.r * (1.08 - vy * 0.22), c.g * (1.08 - vy * 0.22), c.b * (1.08 - vy * 0.22))
			c = c.darkened(0.35 * (1.0 - _ss(2.0, 14.0, e)))
			if state == "pressed":
				c = c.darkened(0.25 * (1.0 - _ss(2.0, 8.0, e)))
			if fid == "west":
				var k := 1.0 - _ss(0.0, 2.2, abs(e - 1.6))
				c = c.lerp(rim, k * 0.95)
				c = c.lerp(rim, (1.0 - _ss(2.0, 9.0, e)) * 0.12)
			elif fid == "red":
				var band := 1.0 - _ss(4.0, 5.5, e)
				if band > 0.0:
					var brass := rim.lightened(0.25 * (1.0 - vy)).darkened(0.25 * vy)
					if e < 1.6:
						brass = brass.darkened(0.45)
					c = c.lerp(brass, band)
				if not is_button:
					c = c.lerp(Color(0.75, 0.14, 0.1), (1.0 - _ss(0.0, 0.9, abs(e - 7.0))) * 0.9)
			else:
				c = c.darkened(0.5 * (1.0 - _ss(0.0, 3.0, e)))
				var on_line := 1.0 - _ss(0.0, 0.85, abs(e - st_d))
				var horiz: bool = y < st_d + 3 or y > H - st_d - 4
				var dash: bool = (int(x / 5.0) % 2 == 0) if horiz else (int(y / 5.0) % 2 == 0)
				if on_line > 0.0 and dash:
					c = c.lerp(thread, on_line * 0.85)
				c = c.lightened((1.0 - _ss(0.0, 0.8, abs(e - (st_d - 2.2)))) * 0.08)
			c.a = alpha * cov
			img.set_pixel(x, y, c)
	if not is_button:
		var inset := 13.0
		var pts := [Vector2(inset, inset), Vector2(W - inset - 1, inset), Vector2(inset, H - inset - 1), Vector2(W - inset - 1, H - inset - 1)]
		if fid == "red":
			for p in pts:
				_rivet(img, p.x, p.y, 3.2, Color(0.62, 0.5, 0.3))
		elif fid == "shadow":
			for p in pts:
				_rivet(img, p.x, p.y, 3.0, Color(0.58, 0.42, 0.22))
		else:
			for p in pts:
				var sx := 1 if p.x < W * 0.5 else -1
				var sy := 1 if p.y < H * 0.5 else -1
				for i in range(0, 9):
					for q in [Vector2(p.x - 6 * sx + i * sx, p.y - 6 * sy), Vector2(p.x - 6 * sx, p.y - 6 * sy + i * sy)]:
						if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H:
							var o := img.get_pixel(int(q.x), int(q.y))
							img.set_pixel(int(q.x), int(q.y), o.lerp(Color(0.6, 0.95, 1.0, o.a), 0.8))
	return img

static func _premium_panel(fid: String) -> Image:
	return _premium(fid, 256, 256, "normal", false)

static func _premium_button(fid: String, state: String) -> Image:
	return _premium(fid, 220, 72, state, true)

# ---------------------------------------------------------------- Zusammenbau

static func _tex(key: String, img_fn: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(img_fn.call())
	return _cache[key]

static func _sbt(tex: Texture2D, margin: float, content: float) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content
	s.content_margin_right = content
	s.content_margin_top = content * 0.7
	s.content_margin_bottom = content * 0.7
	# Mitte kacheln statt strecken: sonst zieht sich die Oberfläche auf breiten Leisten zu Streifen
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s

static func _flat(bg: Color, border: Color, radius := 4, bw := 1, margin := 8.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s

static func font(fid: String) -> Font:
	var f = SystemFont.new()
	match fid:
		"red":
			f.font_names = PackedStringArray(["Bahnschrift", "Arial Black", "Arial"])
			f.font_weight = 700
			f.font_stretch = 85
		"shadow":
			f.font_names = PackedStringArray(["Constantia", "Palatino Linotype", "Georgia"])
			f.font_weight = 600
		_:
			f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
			f.font_weight = 400
	return f

static func build(fid: String) -> Theme:
	var t = Theme.new()
	t.default_font = font(fid)
	var states = ["normal", "hover", "pressed", "disabled"]
	var text_col = Color(0.88, 0.95, 1.0)
	var btn_col = Color(0.92, 0.97, 1.0)
	var btn_hover = Color(1, 1, 1)
	var btn_dis = Color(0.62, 0.68, 0.74)
	var size = 14
	var bsize = 13
	var panel: StyleBox
	var tip: StyleBox
	var tip_col = Color(0.92, 0.95, 1.0)
	match fid:
		"red":
			text_col = Color(0.96, 0.9, 0.78)
			btn_col = Color(0.96, 0.9, 0.78)
			btn_hover = Color(1.0, 0.95, 0.7)
			btn_dis = Color(0.66, 0.62, 0.54)
			panel = _sbt(_tex("red_panel2", _premium_panel.bind("red")), 28, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("red_btn2_" + s, _premium_button.bind("red", s)), 14, 10))
			tip = _flat(Color(0.1, 0.09, 0.09, 0.97), Color(0.75, 0.58, 0.28), 2, 2, 10.0)
		"shadow":
			text_col = Color(0.95, 0.88, 0.74)
			btn_col = Color(0.94, 0.86, 0.7)
			btn_hover = Color(1.0, 0.95, 0.82)
			btn_dis = Color(0.55, 0.5, 0.44)
			size = 15
			bsize = 14
			panel = _sbt(_tex("shadow_panel2", _premium_panel.bind("shadow")), 26, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("shadow_btn2_" + s, _premium_button.bind("shadow", s)), 12, 10))
			tip = _flat(Color(0.13, 0.09, 0.06, 0.97), Color(0.72, 0.52, 0.28), 6, 1, 10.0)
			tip_col = Color(0.95, 0.88, 0.74)
		_:
			panel = _sbt(_tex("west_panel2", _premium_panel.bind("west")), 24, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("west_btn2_" + s, _premium_button.bind("west", s)), 12, 10))
			tip = _flat(Color(0.04, 0.09, 0.14, 0.97), Color(0.4, 0.85, 1.0), 10, 1, 10.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for s in states:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", btn_col)
	t.set_color("font_hover_color", "Button", btn_hover)
	t.set_color("font_pressed_color", "Button", btn_hover)
	t.set_color("font_disabled_color", "Button", btn_dis)
	t.set_color("font_color", "OptionButton", btn_col)
	t.set_color("font_hover_color", "OptionButton", btn_hover)
	t.set_font_size("font_size", "Button", bsize)
	t.set_font_size("font_size", "OptionButton", bsize)
	t.set_color("font_color", "Label", text_col)
	t.set_font_size("font_size", "Label", size)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", tip_col)
	t.set_font_size("font_size", "TooltipLabel", 13)
	match fid:
		"red":
			t.set_stylebox("background", "ProgressBar", _flat(Color(0.07, 0.06, 0.06), Color(0.55, 0.45, 0.3), 0, 1, 0.0))
			t.set_stylebox("fill", "ProgressBar", _flat(Color(0.8, 0.2, 0.15), Color(0, 0, 0, 0), 0, 0, 0.0))
		"shadow":
			t.set_stylebox("background", "ProgressBar", _flat(Color(0.07, 0.05, 0.035), Color(0.45, 0.32, 0.18), 4, 1, 0.0))
			t.set_stylebox("fill", "ProgressBar", _flat(Color(0.86, 0.6, 0.22), Color(1.0, 0.82, 0.5, 0.6), 4, 1, 0.0))
		_:
			t.set_stylebox("background", "ProgressBar", _flat(Color(0.04, 0.09, 0.14), Color(0.3, 0.6, 0.8, 0.5), 6, 1, 0.0))
			t.set_stylebox("fill", "ProgressBar", _flat(Color(0.3, 0.8, 1.0), Color(0, 0, 0, 0), 6, 0, 0.0))
	t.set_color("font_color", "ProgressBar", Color(1, 1, 1, 0))
	return t
