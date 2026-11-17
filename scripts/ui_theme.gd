extends RefCounted
## Fraktionsoberflächen. Alle Texturen entstehen im Code:
##   Westbund      – Milchglas mit leuchtendem Cyan-Rand, abgerundete Ecken, moderne Schrift
##   Rote Allianz  – gebürstetes Metall mit Nieten, abgeschrägte Ecken, Messing und Rot, kräftige Schrift
##   Schattenfront – Holzbretter mit Nägeln, Leinenflicken mit Nähten, handschriftlicher Stil

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

# ---------------------------------------------------------------- Westbund

static func _west_panel() -> Image:
	var W = 112
	var H = 112
	var g = 8.0
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var d = _sd_rr(x + 0.5, y + 0.5, g, g, W - g, H - g, 20.0)
			var c = Color(0, 0, 0, 0)
			if d < 0.0:
				var t = clamp((y - g) / (H - 2 * g), 0.0, 1.0)
				c = Color(0.11, 0.2, 0.3).lerp(Color(0.03, 0.07, 0.12), t)
				c.a = 0.9
				if t < 0.3:
					c = c.lightened((0.3 - t) * 0.22)
				if d > -1.4:
					c = Color(0.45, 0.9, 1.0, 0.95)
				elif d > -2.6:
					c = c.lerp(Color(0.3, 0.75, 1.0, 0.9), 0.55)
				elif d > -5.0:
					c = c.lerp(Color(0.3, 0.7, 0.95, 0.9), 0.12)
			elif d < g:
				c = Color(0.3, 0.8, 1.0, pow(1.0 - d / g, 2.2) * 0.4)
			img.set_pixel(x, y, c)
	return img

static func _west_button(state: String) -> Image:
	var W = 72
	var H = 44
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var top = Color(0.17, 0.28, 0.4, 0.9)
	var bot = Color(0.07, 0.14, 0.22, 0.92)
	var edge = Color(0.35, 0.78, 1.0, 0.5)
	match state:
		"hover":
			top = Color(0.22, 0.4, 0.55, 0.95)
			bot = Color(0.1, 0.22, 0.34, 0.95)
			edge = Color(0.55, 0.95, 1.0, 1.0)
		"pressed":
			top = Color(0.1, 0.32, 0.45, 0.98)
			bot = Color(0.06, 0.2, 0.3, 0.98)
			edge = Color(0.7, 1.0, 1.0, 1.0)
		"disabled":
			top = Color(0.1, 0.12, 0.14, 0.7)
			bot = Color(0.07, 0.08, 0.1, 0.7)
			edge = Color(0.25, 0.3, 0.35, 0.5)
	for y in H:
		for x in W:
			var d = _sd_rr(x + 0.5, y + 0.5, 2.0, 2.0, W - 2.0, H - 2.0, 11.0)
			if d >= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t = clamp(float(y) / H, 0.0, 1.0)
			var c = top.lerp(bot, t)
			if t < 0.45:
				c = c.lightened((0.45 - t) * 0.15)
			if d > -1.5:
				c = edge
			elif d > -3.0:
				c = c.lerp(edge, 0.12)
			img.set_pixel(x, y, c)
	return img

# ---------------------------------------------------------------- Rote Allianz

static func _red_panel() -> Image:
	var W = 112
	var H = 112
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var nz = _noise(5, 0.04)
	for y in H:
		for x in W:
			var d = _chamfer(x, y, W, H, 2.0, 18.0)
			if d < 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var v = 0.16 + nz.get_noise_2d(x * 0.25, y * 3.5) * 0.05 + (1.0 - float(y) / H) * 0.03
			var c = Color(v, v * 0.97, v * 0.94, 0.96)
			if d < 3.0:
				c = Color(0.5, 0.08, 0.06, 1.0)
			elif d < 4.2:
				c = Color(0.62, 0.55, 0.45, 1.0)
			elif d < 5.2:
				c = Color(0.07, 0.06, 0.06, 1.0)
			img.set_pixel(x, y, c)
	for p in [Vector2(14, 14), Vector2(W - 15, 14), Vector2(14, H - 15), Vector2(W - 15, H - 15)]:
		_rivet(img, p.x, p.y, 3.4, Color(0.8, 0.62, 0.3))
	return img

static func _red_button(state: String) -> Image:
	var W = 72
	var H = 44
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var nz = _noise(9, 0.05)
	var base = Color(0.23, 0.22, 0.21)
	var edge = Color(0.06, 0.05, 0.05)
	var hi = Color(0.55, 0.5, 0.42)
	match state:
		"hover":
			base = Color(0.36, 0.2, 0.18)
			edge = Color(0.55, 0.08, 0.06)
			hi = Color(0.85, 0.7, 0.4)
		"pressed":
			base = Color(0.13, 0.12, 0.12)
			edge = Color(0.45, 0.07, 0.05)
			hi = Color(0.5, 0.2, 0.15)
		"disabled":
			base = Color(0.16, 0.16, 0.16)
			edge = Color(0.05, 0.05, 0.05)
			hi = Color(0.3, 0.3, 0.3)
	for y in H:
		for x in W:
			var d = _chamfer(x, y, W, H, 1.0, 9.0)
			if d < 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var v = 1.0 + nz.get_noise_2d(x * 0.3, y * 4.0) * 0.12 - (float(y) / H) * 0.15
			var c = Color(base.r * v, base.g * v, base.b * v, 0.97)
			if d < 2.2:
				c = edge
			elif d < 3.2:
				c = hi
			img.set_pixel(x, y, c)
	for p in [Vector2(8, 8), Vector2(W - 9, 8), Vector2(8, H - 9), Vector2(W - 9, H - 9)]:
		_rivet(img, p.x, p.y, 1.9, Color(0.78, 0.6, 0.28) if state != "disabled" else Color(0.35, 0.33, 0.3))
	return img

# ---------------------------------------------------------------- Schattenfront

static func _shadow_panel() -> Image:
	var W = 112
	var H = 112
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var grain = _noise(21, 0.02)
	var rough = _noise(33, 0.09)
	for y in H:
		var plank = int(y / 28)
		var pv = (float(plank % 3) - 1.0) * 0.035
		var seam = y % 28
		for x in W:
			var e = min(min(x, W - 1 - x), min(y, H - 1 - y)) + rough.get_noise_2d(x, y) * 5.0 - 1.5
			if e < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var gn = grain.get_noise_2d(x * 1.6 + plank * 41.0, y * 14.0) * 0.5 + 0.5
			var c = Color(0.3, 0.2, 0.11).lerp(Color(0.44, 0.3, 0.17), gn)
			c = Color(c.r + pv, c.g + pv * 0.8, c.b + pv * 0.6, 0.97)
			if seam < 2 or seam > 26:
				c = c.darkened(0.45)
			if e < 4.0:
				c = Color(0.1, 0.065, 0.035, 1.0)
			elif e < 5.0:
				c = c.lightened(0.12)
			img.set_pixel(x, y, c)
	for p in [Vector2(13, 13), Vector2(W - 14, 13), Vector2(13, H - 14), Vector2(W - 14, H - 14)]:
		_rivet(img, p.x, p.y, 2.8, Color(0.28, 0.27, 0.26))
	return img

static func _shadow_button(state: String) -> Image:
	var W = 72
	var H = 44
	var img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rough = _noise(41, 0.1)
	var weave = _noise(43, 0.5)
	var base = Color(0.63, 0.52, 0.36)
	var stitch = Color(0.33, 0.23, 0.14)
	match state:
		"hover":
			base = Color(0.76, 0.63, 0.43)
		"pressed":
			base = Color(0.5, 0.4, 0.27)
			stitch = Color(0.25, 0.17, 0.1)
		"disabled":
			base = Color(0.24, 0.21, 0.18)
			stitch = Color(0.42, 0.36, 0.28)
	for y in H:
		for x in W:
			var e = min(min(x, W - 1 - x), min(y, H - 1 - y)) + rough.get_noise_2d(x, y) * 3.2 - 1.0
			if e < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var wv = weave.get_noise_2d(x * 1.3, y * 1.3) * 0.5
			var chk = 0.045 if ((x / 2 + y / 2) % 2 == 0) else -0.02
			var c = Color(base.r + wv * 0.14 + chk, base.g + wv * 0.12 + chk, base.b + wv * 0.1 + chk, 1.0)
			if e < 2.0:
				c = c.darkened(0.55)
			elif abs(e - 6.0) < 0.8 and ((x + y) / 3) % 2 == 0:
				c = stitch
			img.set_pixel(x, y, c)
	return img

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
			f.font_names = PackedStringArray(["Segoe Print", "Ink Free", "Bradley Hand ITC", "Comic Sans MS"])
			f.font_weight = 400
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
			panel = _sbt(_tex("red_panel", _red_panel), 34, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("red_btn_" + s, _red_button.bind(s)), 14, 10))
			tip = _flat(Color(0.1, 0.09, 0.09, 0.97), Color(0.75, 0.58, 0.28), 2, 2, 10.0)
		"shadow":
			text_col = Color(0.97, 0.9, 0.74)
			btn_col = Color(0.14, 0.08, 0.04)
			btn_hover = Color(0.05, 0.02, 0.0)
			btn_dis = Color(0.76, 0.7, 0.58)
			size = 14
			bsize = 13
			panel = _sbt(_tex("shadow_panel", _shadow_panel), 32, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("shadow_btn_" + s, _shadow_button.bind(s)), 14, 10))
			tip = _flat(Color(0.82, 0.72, 0.52, 0.98), Color(0.25, 0.16, 0.08), 3, 2, 10.0)
			tip_col = Color(0.14, 0.08, 0.04)
		_:
			panel = _sbt(_tex("west_panel", _west_panel), 34, 18)
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("west_btn_" + s, _west_button.bind(s)), 16, 10))
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
			t.set_stylebox("background", "ProgressBar", _flat(Color(0.12, 0.08, 0.05), Color(0.28, 0.18, 0.1), 3, 1, 0.0))
			t.set_stylebox("fill", "ProgressBar", _flat(Color(0.8, 0.55, 0.15), Color(0, 0, 0, 0), 3, 0, 0.0))
		_:
			t.set_stylebox("background", "ProgressBar", _flat(Color(0.04, 0.09, 0.14), Color(0.3, 0.6, 0.8, 0.5), 6, 1, 0.0))
			t.set_stylebox("fill", "ProgressBar", _flat(Color(0.3, 0.8, 1.0), Color(0, 0, 0, 0), 6, 0, 0.0))
	t.set_color("font_color", "ProgressBar", Color(1, 1, 1, 0))
	return t
