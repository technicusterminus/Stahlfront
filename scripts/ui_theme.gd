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

## Fassung einer Tafel oder eines Knopfes. Aufbau von außen nach innen:
##   Schlagschatten (liegt außerhalb der Fläche, per expand_margin über den Rand hinaus) -> Rahmen der Fraktion ->
##   schwarze Nut -> ruhige, dunkle Fläche (Materialbild stark abgedämpft, Abnutzung nur zu den Kanten hin).
## kind: "panel", "button" oder "primary" (Hauptaktion, gefüllt in Fraktionsfarbe).
const SHADOW_PAD := {"panel": 10, "button": 5, "primary": 6}

static func _premium(fid: String, W: int, H: int, state: String, kind: String) -> Image:
	var is_button := kind != "panel"
	var pad := float(SHADOW_PAD[kind])
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var m: Image = _mat(fid)
	var mw := m.get_width()
	var mh := m.get_height()
	var r := 4.0
	var rim_w := 1.5
	var rim := Color("22d3ee")
	var base := Color(0.05, 0.07, 0.1)
	var tint := Color(1, 1, 1)
	var alpha := 0.96
	if fid == "west":
		r = 3.0 if is_button else 4.0
		rim_w = 1.5
	elif fid == "red":
		r = 6.0 if is_button else 12.0
		rim_w = 3.0 if is_button else 4.0
		rim = Color("d97706")
		base = Color(0.1, 0.095, 0.09)
	else:
		r = 5.0 if is_button else 8.0
		rim_w = 2.0
		rim = Color("b07a3a")
		base = Color(0.11, 0.075, 0.05)
		tint = Color(0.9, 0.78, 0.66)
	var calm := 0.62
	var light := 1.0
	var fill_top := Color(0, 0, 0, 0)
	var fill_bot := Color(0, 0, 0, 0)
	if kind == "primary":
		calm = 0.82
		if fid == "west":
			fill_top = Color("0e7490")
			fill_bot = Color("075985")
			rim = Color("38bdf8")
		elif fid == "red":
			fill_top = Color("b91c1c")
			fill_bot = Color("7f1d1d")
			rim = Color("f59e0b")
		else:
			fill_top = Color("b45309")
			fill_bot = Color("78350f")
			rim = Color("fbbf24")
	if is_button:
		match state:
			"hover":
				light = 1.35
				rim = rim.lightened(0.35)
			"pressed":
				light = 0.9
				rim = rim.lightened(0.6)
			"disabled":
				light = 0.6
				rim = Color(0.32, 0.33, 0.35)
				alpha *= 0.85
	var thread := Color("d6b88a") if state != "disabled" else Color(0.42, 0.39, 0.35)
	var st_d := rim_w + 4.5 if is_button else rim_w + 7.0
	for y in H:
		for x in W:
			var e := _edge(fid, x - pad, y - pad, W - 2.0 * pad, H - 2.0 * pad, r)
			if e <= -0.5:
				# Schlagschatten, leicht nach unten versetzt
				var es := _edge(fid, x - pad, y - pad - 2.0, W - 2.0 * pad, H - 2.0 * pad, r)
				var sh := _ss(-pad, 0.0, es) * 0.6
				img.set_pixel(x, y, Color(0, 0, 0, sh * (0.7 if state == "disabled" else 1.0)))
				continue
			var cov := _ss(-0.5, 0.8, e)
			var vy := clampf((float(y) - pad) / (float(H) - 2.0 * pad), 0.0, 1.0)
			var mc: Color = m.get_pixel(x % mw, y % mh)
			# Fläche: Material stark abgedämpft, zur Kante hin kommt die Struktur durch
			var edge_show := 1.0 - _ss(rim_w + 2.0, rim_w + 26.0, e)
			var c := Color(mc.r * tint.r, mc.g * tint.g, mc.b * tint.b).lerp(base, calm * (1.0 - edge_show * 0.45))
			if kind == "primary":
				c = fill_top.lerp(fill_bot, vy).lerp(c, 0.18)
			c = Color(c.r * light, c.g * light, c.b * light)
			c = c * (1.06 - vy * 0.14)
			if state == "pressed":
				c = c.darkened(0.3 * (1.0 - _ss(rim_w + 1.0, rim_w + 9.0, e)))
			# schwarze Nut direkt innerhalb des Rahmens
			var groove := 1.0 - _ss(0.0, 0.9, abs(e - (rim_w + 1.0)))
			c = c.lerp(Color(0, 0, 0), groove * 0.75)
			# Rahmen der Fraktion
			var on_rim := 1.0 - _ss(rim_w - 0.4, rim_w + 0.4, e)
			if on_rim > 0.0:
				var rc := rim
				if fid == "red":
					rc = Color("fde68a").lerp(rim, clampf(vy * 1.6, 0.0, 1.0)).darkened(0.35 * vy)
					if e < 1.0:
						rc = rc.darkened(0.5)
				elif fid == "shadow":
					rc = rim.darkened(0.25 + 0.2 * vy)
				else:
					rc = rim
				c = c.lerp(rc, on_rim)
			if fid == "west" and not is_button:
				c = c.lerp(rim, (1.0 - _ss(rim_w, rim_w + 10.0, e)) * 0.08)
			if fid == "red" and kind == "panel":
				c = c.lerp(Color(0.72, 0.13, 0.1), (1.0 - _ss(0.0, 0.8, abs(e - (rim_w + 5.0)))) * 0.85)
			if fid == "shadow":
				var on_line := 1.0 - _ss(0.0, 0.8, abs(e - st_d))
				var horiz: bool = (y - pad) < st_d + 3 or (y - pad) > (H - 2.0 * pad) - st_d - 4
				var dash: bool = (int(x / 6.0) % 2 == 0) if horiz else (int(y / 6.0) % 2 == 0)
				if on_line > 0.0 and dash:
					c = c.lerp(thread, on_line * 0.9)
				var hole := 1.0 - _ss(0.0, 0.8, abs(e - (st_d + 1.3)))
				if hole > 0.0 and dash:
					c = c.darkened(hole * 0.5)
			c.a = alpha * cov
			img.set_pixel(x, y, c)
	if kind == "panel":
		_panel_ornaments(img, fid, W, H, pad)
	return img

static func _px_over(img: Image, x: int, y: int, col: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var o := img.get_pixel(x, y)
	if o.a < 0.3:
		return
	img.set_pixel(x, y, Color(o.r, o.g, o.b, o.a).lerp(Color(col.r, col.g, col.b, o.a), a))

## Eckmarken (Westbund), Nietenreihen (Rot), dreieckige Bronzekappen (Schatten).
static func _panel_ornaments(img: Image, fid: String, W: int, H: int, pad: float) -> void:
	var x0 := int(pad)
	var y0 := int(pad)
	var x1 := W - int(pad) - 1
	var y1 := H - int(pad) - 1
	if fid == "west":
		var col := Color("67e8f9")
		for corner in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
			for i in 16:
				for t in 3:
					_px_over(img, corner[0] + (i + 1) * corner[2], corner[1] + (t + 1) * corner[3], col, 0.95)
					_px_over(img, corner[0] + (t + 1) * corner[2], corner[1] + (i + 1) * corner[3], col, 0.95)
	elif fid == "red":
		var y_top := y0 + 9
		var y_bot := y1 - 9
		var xs := [x0 + 14, x1 - 14, (x0 + x1) / 2]
		for x in xs:
			_rivet(img, x, y_top, 4.2, Color(0.66, 0.52, 0.3))
			_rivet(img, x, y_bot, 4.2, Color(0.66, 0.52, 0.3))
	else:
		var cap := 14
		for corner in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
			for i in cap:
				for j in cap - i:
					var edge_px: bool = j == cap - i - 1 or i == 0 or j == 0
					var col := Color("f59e0b") if edge_px else Color("92400e").lerp(Color("b45309"), float(j) / cap)
					_px_over(img, corner[0] + (i + 1) * corner[2], corner[1] + (j + 1) * corner[3], col, 0.95)

static func _premium_panel(fid: String) -> Image:
	return _premium(fid, 256 + 2 * SHADOW_PAD["panel"], 256 + 2 * SHADOW_PAD["panel"], "normal", "panel")

static func _premium_button(fid: String, state: String) -> Image:
	return _premium(fid, 220 + 2 * SHADOW_PAD["button"], 72 + 2 * SHADOW_PAD["button"], state, "button")

static func _primary_button(fid: String, state: String) -> Image:
	return _premium(fid, 260 + 2 * SHADOW_PAD["primary"], 72 + 2 * SHADOW_PAD["primary"], state, "primary")

# ---------------------------------------------------------------- Zusammenbau

static func _tex(key: String, img_fn: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(img_fn.call())
	return _cache[key]

static func _sbt(tex: Texture2D, margin: float, content: float, shadow := 0.0) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margin + shadow
	s.texture_margin_right = margin + shadow
	s.texture_margin_top = margin + shadow
	s.texture_margin_bottom = margin + shadow
	# der Schatten liegt außerhalb der eigentlichen Fläche
	s.expand_margin_left = shadow
	s.expand_margin_right = shadow
	s.expand_margin_top = shadow
	s.expand_margin_bottom = shadow
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
			f.font_weight = 600
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
			panel = _sbt(_tex("red_panel3", _premium_panel.bind("red")), 28, 18, SHADOW_PAD["panel"])
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("red_btn3_" + s, _premium_button.bind("red", s)), 14, 10, SHADOW_PAD["button"]))
				t.set_stylebox(s, "PrimaryButton", _sbt(_tex("red_pri_" + s, _primary_button.bind("red", s)), 16, 12, SHADOW_PAD["primary"]))
			tip = _flat(Color(0.1, 0.09, 0.09, 0.97), Color(0.75, 0.58, 0.28), 2, 2, 10.0)
		"shadow":
			text_col = Color(0.95, 0.88, 0.74)
			btn_col = Color(0.94, 0.86, 0.7)
			btn_hover = Color(1.0, 0.95, 0.82)
			btn_dis = Color(0.55, 0.5, 0.44)
			size = 15
			bsize = 14
			panel = _sbt(_tex("shadow_panel3", _premium_panel.bind("shadow")), 26, 18, SHADOW_PAD["panel"])
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("shadow_btn3_" + s, _premium_button.bind("shadow", s)), 12, 10, SHADOW_PAD["button"]))
				t.set_stylebox(s, "PrimaryButton", _sbt(_tex("shadow_pri_" + s, _primary_button.bind("shadow", s)), 16, 12, SHADOW_PAD["primary"]))
			tip = _flat(Color(0.13, 0.09, 0.06, 0.97), Color(0.72, 0.52, 0.28), 6, 1, 10.0)
			tip_col = Color(0.95, 0.88, 0.74)
		_:
			panel = _sbt(_tex("west_panel3", _premium_panel.bind("west")), 24, 18, SHADOW_PAD["panel"])
			for s in states:
				t.set_stylebox(s, "Button", _sbt(_tex("west_btn3_" + s, _premium_button.bind("west", s)), 12, 10, SHADOW_PAD["button"]))
				t.set_stylebox(s, "PrimaryButton", _sbt(_tex("west_pri_" + s, _primary_button.bind("west", s)), 16, 12, SHADOW_PAD["primary"]))
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
	# Lesbarkeit auf Material und Gelände: Schatten unter jeder Schrift
	for typ in ["Label", "Button", "OptionButton"]:
		t.set_color("font_shadow_color", typ, Color(0, 0, 0, 0.8))
		t.set_constant("shadow_offset_x", typ, 1)
		t.set_constant("shadow_offset_y", typ, 1)
	# Hauptaktion (z. B. "Gefecht starten"): gefüllt in Fraktionsfarbe, größer, kräftiger
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("focus", "PrimaryButton", StyleBoxEmpty.new())
	t.set_color("font_color", "PrimaryButton", Color(1, 0.98, 0.92))
	t.set_color("font_hover_color", "PrimaryButton", Color(1, 1, 1))
	t.set_color("font_pressed_color", "PrimaryButton", Color(1, 1, 1))
	t.set_font_size("font_size", "PrimaryButton", 19)
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

## Füllung für Lebens- und Fortschrittsbalken: senkrechter Verlauf mit feinen Zellstrichen (alle 20 px).
static func bar_fill(top: Color, mid: Color, bot: Color) -> StyleBoxTexture:
	var key := "bar_%s_%s_%s" % [top.to_html(), mid.to_html(), bot.to_html()]
	if not _cache.has(key):
		var img := Image.create(20, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			var v := float(y) / 15.0
			var c := top.lerp(mid, v * 2.0) if v < 0.5 else mid.lerp(bot, (v - 0.5) * 2.0)
			if y == 1:
				c = c.lightened(0.25)
			for x in 20:
				img.set_pixel(x, y, c.darkened(0.45) if x == 19 else c)
		_cache[key] = ImageTexture.create_from_image(img)
	var s := StyleBoxTexture.new()
	s.texture = _cache[key]
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

static func bar_back() -> StyleBoxFlat:
	return _flat(Color("090d12"), Color("334155"), 2, 1, 0.0)
