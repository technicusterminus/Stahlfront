extends CanvasLayer
## Benutzeroberfläche: Kopfleiste, Kommandoleiste, Minikarte, Meldungen, Menüs.

const MinimapScript = preload("res://scripts/minimap.gd")
const UITheme = preload("res://scripts/ui_theme.gd")
const EmblemScript = preload("res://scripts/emblem.gd")

signal start_requested(cfg: Dictionary)

var root: Control
var overlay: Control
var top: PanelContainer
var bottom: PanelContainer
var lbl_faction: Label
var lbl_credits: Label
var res_box: HBoxContainer
var res_lbls = {}
var lbl_power: Label
var power_bar: ProgressBar
var btn_rank: Button
var lbl_super: Label
var lbl_time: Label
var minimap
var info_title: Label
var info_sub: Label
var info_hp: ProgressBar
var info_hp_lbl: Label
var info_status: Label
var queue_box: HBoxContainer
var prod_bar: ProgressBar
var grid: GridContainer
var msg_box: VBoxContainer
var powers_panel: PanelContainer
var powers_list: VBoxContainer
var pause_panel: Control
var help_panel: PanelContainer
var menu_layer: Control
var end_layer: Control
var thm: Theme
var ui = {}
var cur_faction = "west"
var emblem
var btn_help: Button
var btn_menu: Button
var accent = Color(0.35, 0.65, 1.0)

var _sig = ""
var _btns: Array = []
var _refresh_t = 0.0
var _sell_armed = 0.0
var _surrender_armed = false
var _cfg = {"faction": "west", "enemies": 1, "difficulty": 1, "spectate": false}

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = thm
	add_child(root)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	_build_top()
	_build_bottom()
	_build_messages()
	_build_powers()
	_build_help()
	_build_pause()
	Game.message.connect(add_message)
	Game.match_ended.connect(_on_match_end)
	set_game_ui(false)

# ---------------------------------------------------------------- Theme

func _sb(bg: Color, border := Color(0, 0, 0, 0), radius := 6, bw := 1, margin := 8.0) -> StyleBoxFlat:
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

func _make_theme() -> void:
	apply_faction("west")

## Wechselt die gesamte Oberfläche (Texturen, Schrift, Wortschatz, Emblem, Kartenrahmen).
func apply_faction(fid: String) -> void:
	cur_faction = fid
	ui = UITheme.vocab(fid)
	thm = UITheme.build(fid)
	if root != null:
		root.theme = thm
	if emblem != null:
		emblem.set_faction(fid, Defs.factions[fid]["color"])
	if btn_help != null:
		btn_help.text = ui["help"]
		btn_menu.text = ui["menu"]
	if minimap != null:
		minimap.frame_style = fid

func _label(text: String, size := 14, col := Color(0, 0, 0, 0)) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if col.a > 0.0:
		l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, cb: Callable, min_size := Vector2(0, 0)) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if cb.is_valid():
		b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b

# ---------------------------------------------------------------- Aufbau

func _build_top() -> void:
	top = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 6
	root.add_child(top)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	top.add_child(h)
	emblem = EmblemScript.new()
	h.add_child(emblem)
	lbl_faction = _label("STAHLFRONT", 17, Color(1, 1, 1))
	h.add_child(lbl_faction)
	lbl_credits = _label("Credits 0", 16, Color(1.0, 0.86, 0.4))
	lbl_credits.tooltip_text = "Credits: Sammler holen Nachschub aus Depots und liefern ihn am Nachschubzentrum ab."
	lbl_credits.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(lbl_credits)
	res_box = HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 12)
	h.add_child(res_box)
	for k in Defs.RES_KINDS:
		var rl = _label("", 14, Defs.RES_COLORS[k].lightened(0.35))
		rl.mouse_filter = Control.MOUSE_FILTER_PASS
		rl.tooltip_text = _res_tip(k)
		res_box.add_child(rl)
		res_lbls[k] = rl
	var pv = HBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	h.add_child(pv)
	lbl_power = _label("Strom 0/0", 15)
	lbl_power.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl_power.tooltip_text = "Strom: Erzeugung / Verbrauch. Bei Mangel halbiert sich die Produktion, Abwehr und Superwaffe fallen aus."
	pv.add_child(lbl_power)
	power_bar = ProgressBar.new()
	power_bar.custom_minimum_size = Vector2(110, 10)
	power_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_bar.show_percentage = false
	pv.add_child(power_bar)
	btn_rank = _button("General Rang 1", toggle_powers)
	btn_rank.tooltip_text = "Generalsfähigkeiten (Taste G). Beförderungen durch Abschüsse bringen Punkte."
	h.add_child(btn_rank)
	lbl_super = _label("", 15, Color(0.7, 0.9, 1.0))
	h.add_child(lbl_super)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	lbl_time = _label("00:00", 15, Color(0.7, 0.78, 0.85))
	h.add_child(lbl_time)
	btn_help = _button("Hilfe (F1)", toggle_help)
	h.add_child(btn_help)
	btn_menu = _button("Menü (Esc)", toggle_pause)
	h.add_child(btn_menu)

func _build_bottom() -> void:
	bottom = PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -236
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_bottom = -6
	root.add_child(bottom)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bottom.add_child(h)
	minimap = MinimapScript.new()
	h.add_child(minimap)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	h.add_child(info)
	info_title = _label("", 20, Color(1, 1, 1))
	info.add_child(info_title)
	info_sub = _label("", 13, Color(0.65, 0.75, 0.85))
	info.add_child(info_sub)
	var hpbox = HBoxContainer.new()
	info.add_child(hpbox)
	info_hp = ProgressBar.new()
	info_hp.custom_minimum_size = Vector2(240, 12)
	info_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_hp.show_percentage = false
	hpbox.add_child(info_hp)
	info_hp_lbl = _label("", 13)
	hpbox.add_child(info_hp_lbl)
	info_status = _label("", 14, Color(0.85, 0.9, 0.95))
	info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_status.custom_minimum_size = Vector2(300, 0)
	info.add_child(info_status)
	prod_bar = ProgressBar.new()
	prod_bar.custom_minimum_size = Vector2(240, 8)
	prod_bar.show_percentage = false
	var fill = _sb(Color(0.35, 0.65, 1.0), Color(0, 0, 0, 0), 3, 0, 0.0)
	prod_bar.add_theme_stylebox_override("fill", fill)
	info.add_child(prod_bar)
	queue_box = HBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 4)
	info.add_child(queue_box)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	h.add_child(grid)

func _build_messages() -> void:
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(16, 64)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_theme_constant_override("separation", 3)
	root.add_child(msg_box)

func _build_powers() -> void:
	powers_panel = PanelContainer.new()
	powers_panel.position = Vector2(300, 60)
	powers_panel.custom_minimum_size = Vector2(520, 0)
	powers_panel.visible = false
	root.add_child(powers_panel)
	powers_list = VBoxContainer.new()
	powers_list.add_theme_constant_override("separation", 8)
	powers_panel.add_child(powers_list)

func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.set_anchors_preset(Control.PRESET_CENTER)
	help_panel.visible = false
	root.add_child(help_panel)
	var v = VBoxContainer.new()
	help_panel.add_child(v)
	v.add_child(_label("Steuerung", 22, Color(1, 1, 1)))
	var txt = """Linksklick – auswählen · Ziehen – Rahmenauswahl · Shift – zur Auswahl hinzufügen
Doppelklick / Strg+Klick – alle gleichen Typs auf dem Bildschirm
Rechtsklick – bewegen, angreifen, Nachschub sammeln (auf Depot), bauen/reparieren (Bauarbeiter auf Gebäude)
Rechtsklick mit Fabrik ausgewählt – Sammelpunkt setzen
A – Angriffsbewegung · S – Stopp · Strg+A – alle Kampfeinheiten
Strg+1…9 – Gruppe speichern · 1…9 – Gruppe wählen (2× = Kamera hin)
Pfeiltasten / Bildschirmrand / mittlere Maustaste – Kamera · Mausrad – Zoom · Q/E – drehen
Leertaste – zur letzten Meldung · H – Hauptquartier · G – Generalsfähigkeiten · Esc – abbrechen / Menü

Tipps: Bauarbeiter auswählen und unten ein Gebäude wählen. Ohne Nachschubzentrum kein Einkommen.
Abschüsse befördern dich zum General – jeder Rang bringt einen Punkt für Fähigkeiten."""
	var l = _label(txt, 14)
	v.add_child(l)
	v.add_child(_button("Schließen", toggle_help))
	help_panel.offset_left = -440
	help_panel.offset_right = 440
	help_panel.offset_top = -190
	help_panel.offset_bottom = 190

func _build_pause() -> void:
	pause_panel = _dim_layer()
	pause_panel.visible = false
	var p = _center_panel(pause_panel, 360)
	var v: VBoxContainer = p.get_child(0)
	v.add_child(_label("Pause", 26, Color(1, 1, 1)))
	v.add_child(_button("Weiterspielen", toggle_pause, Vector2(0, 40)))
	v.add_child(_button("Steuerung anzeigen", _help_from_pause, Vector2(0, 40)))
	var sur = _button("Aufgeben", Callable(), Vector2(0, 40))
	sur.pressed.connect(func():
		if _surrender_armed:
			_surrender_armed = false
			toggle_pause()
			for b in Game.buildings.duplicate():
				if b.owner_id == Game.human:
					b._remove(true)
			for u in Game.units.duplicate():
				if u.owner_id == Game.human:
					u.die(-1, null)
		else:
			_surrender_armed = true
			sur.text = "Wirklich aufgeben? Nochmal klicken"
	)
	pause_panel.set_meta("sur", sur)
	v.add_child(sur)
	v.add_child(_button("Neues Gefecht", _new_game, Vector2(0, 40)))
	v.add_child(_button("Spiel beenden", _quit, Vector2(0, 40)))

func _dim_layer() -> Control:
	var c = ColorRect.new()
	c.color = Color(0, 0, 0, 0.55)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(c)
	return c

func _center_panel(parent: Control, w: float) -> PanelContainer:
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0)
	cc.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return p

func set_game_ui(on: bool) -> void:
	top.visible = on
	bottom.visible = on
	msg_box.visible = on

func mouse_over_ui() -> bool:
	var mp = root.get_viewport().get_mouse_position()
	for c in [top, bottom, powers_panel, help_panel, pause_panel, menu_layer, end_layer]:
		if c != null and c.visible and c.get_global_rect().has_point(mp):
			return true
	return false

# ---------------------------------------------------------------- Startmenü

func show_menu() -> void:
	menu_layer = _dim_layer()
	menu_layer.color = Color(0, 0, 0, 0.25)
	var p = _center_panel(menu_layer, 640)
	var v: VBoxContainer = p.get_child(0)
	v.add_child(_label("STAHLFRONT", 44, Color(1, 1, 1)))
	v.add_child(_label("Echtzeitstrategie · Drei Fraktionen · Ein Schlachtfeld", 15, Color(0.6, 0.72, 0.85)))
	v.add_child(HSeparator.new())
	v.add_child(_label("Deine Fraktion", 16, Color(0.8, 0.88, 1.0)))
	var fh = HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	v.add_child(fh)
	var fdesc = _label("", 14, Color(0.8, 0.85, 0.9))
	fdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fdesc.custom_minimum_size = Vector2(600, 150)
	var fbtns = {}
	for fid in ["west", "red", "shadow"]:
		var f: Dictionary = Defs.factions[fid]
		var b = Button.new()
		b.text = f["name"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(198, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", f["color"].lightened(0.35))
		fh.add_child(b)
		fbtns[fid] = b
	var pick_faction = func(fid: String):
		_cfg["faction"] = fid
		apply_faction(fid)
		for k in fbtns:
			fbtns[k].button_pressed = k == fid
		var ft: String = Defs.factions[fid]["desc"]
		for pk in Defs.factions[fid].get("perks", []):
			ft += "\n•  " + String(pk)
		fdesc.text = ft
	for fid in fbtns:
		fbtns[fid].pressed.connect(pick_faction.bind(fid))
	pick_faction.call("west")
	v.add_child(fdesc)
	var grid2 = GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 16)
	grid2.add_theme_constant_override("v_separation", 8)
	v.add_child(grid2)
	grid2.add_child(_label("Gegner", 15))
	var ob = OptionButton.new()
	for i in [1, 2, 3]:
		ob.add_item("%d KI-Gegner (jeder gegen jeden)" % i if i > 1 else "1 KI-Gegner")
	ob.focus_mode = Control.FOCUS_NONE
	ob.item_selected.connect(func(i): _cfg["enemies"] = i + 1)
	grid2.add_child(ob)
	grid2.add_child(_label("Schwierigkeit", 15))
	var od = OptionButton.new()
	for t in ["Leicht – KI baut langsamer", "Mittel – fairer Gegner", "Schwer – KI mit Wirtschaftsbonus"]:
		od.add_item(t)
	od.select(1)
	od.focus_mode = Control.FOCUS_NONE
	od.item_selected.connect(func(i): _cfg["difficulty"] = i)
	grid2.add_child(od)
	v.add_child(HSeparator.new())
	var bh = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	v.add_child(bh)
	var start = _button("Gefecht starten", func(): _start(false), Vector2(300, 48))
	start.add_theme_font_size_override("font_size", 18)
	bh.add_child(start)
	bh.add_child(_button("KI gegen KI zuschauen", func(): _start(true), Vector2(190, 48)))
	bh.add_child(_button("Beenden", _quit, Vector2(110, 48)))
	v.add_child(_label("F1 im Spiel zeigt die Steuerung.", 13, Color(0.55, 0.62, 0.7)))

func _start(spectate: bool) -> void:
	_cfg["spectate"] = spectate
	menu_layer.queue_free()
	menu_layer = null
	start_requested.emit(_cfg.duplicate())

func on_match_started() -> void:
	set_game_ui(true)
	var p: Dictionary = Game.players[Game.human]
	accent = p["color"]
	apply_faction(p["faction"] if not Game.spectator else "west")
	lbl_faction.text = p["name"].to_upper() if not Game.spectator else "ZUSCHAUER"
	lbl_faction.add_theme_color_override("font_color", accent.lightened(0.3))
	minimap.set_terrain(Game.terrain.minimap_image(212))
	Game.ctrl.selection_changed.connect(func(): _sig = "")

# ---------------------------------------------------------------- Meldungen

func add_message(text: String, col: Color) -> void:
	var l = _label(text, 15, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	msg_box.add_child(l)
	while msg_box.get_child_count() > 7:
		msg_box.get_child(0).free()
	var tw = l.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

# ---------------------------------------------------------------- Umschalter

func toggle_pause() -> void:
	if end_layer != null or menu_layer != null:
		return
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible
	_surrender_armed = false
	var sur: Button = pause_panel.get_meta("sur")
	sur.text = "Aufgeben"

func toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func toggle_powers() -> void:
	if Game.spectator:
		return
	powers_panel.visible = not powers_panel.visible
	_refresh_powers()

# ---------------------------------------------------------------- Laufende Anzeige

func _process(delta: float) -> void:
	overlay.queue_redraw()
	if not Game.running or Game.players.is_empty():
		return
	var p: Dictionary = Game.players[Game.human]
	lbl_credits.text = "%s %s" % [ui["credits"], _fmt(int(p["credits"]))]
	for k in Defs.RES_KINDS:
		res_lbls[k].text = "%s %d" % [Defs.RES_NAMES[k], int(p["res"][k])]
	var uses_power: bool = Defs.factions[p["faction"]]["uses_power"]
	lbl_power.visible = uses_power
	power_bar.visible = uses_power
	if uses_power:
		lbl_power.text = "%s %d / %d" % [ui["power"], p["power_prod"], p["power_use"]]
		var ok = Game.has_power(Game.human)
		lbl_power.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if ok else Color(1.0, 0.4, 0.35))
		power_bar.max_value = max(1, p["power_prod"])
		power_bar.value = min(p["power_use"], p["power_prod"])
	btn_rank.text = (ui["rank"] % p["rank"]) + " · %d %s" % [p["points"], ui["point"][0 if p["points"] == 1 else 1]]
	var st = ""
	for b in Game.buildings:
		if b.owner_id == Game.human and b.complete and b.def["role"] == "super":
			st = "%s: %s" % [b.def["name"], "BEREIT" if b.super_ready else _clock(b.super_t)]
			break
	lbl_super.text = st
	lbl_time.text = _clock(Game.time)
	_refresh_t -= delta
	var sig = _selection_sig()
	if sig != _sig:
		_sig = sig
		_rebuild_grid()
		_refresh_t = 0.0
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh_grid()
		_update_queue()
		if powers_panel.visible:
			_refresh_powers()
	_update_info()
	_sell_armed = max(0.0, _sell_armed - delta)

func _fmt(n: int) -> String:
	var s = str(abs(n))
	var out = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _clock(t: float) -> String:
	var s = int(max(t, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]

func _selection_sig() -> String:
	var sel: Array = Game.ctrl.selection
	var s = ""
	for o in sel:
		if is_instance_valid(o):
			s += str(o.get_instance_id()) + (("c" if o.complete else "u") if o.is_building else "") + ","
	return s

# ---------------------------------------------------------------- Info

func _update_info() -> void:
	var sel: Array = Game.ctrl.selection
	if sel.is_empty() or not is_instance_valid(sel[0]):
		info_title.text = "Nichts ausgewählt"
		info_sub.text = "Linksklick wählt aus, Ziehen zieht einen Rahmen. F1 zeigt alle Tasten."
		info_hp.visible = false
		info_hp_lbl.text = ""
		info_status.text = _idle_hint()
		prod_bar.visible = false
		return
	var o = sel[0]
	info_hp.visible = not o.is_depot
	if o.is_depot:
		info_title.text = Defs.RES_NAMES[o.kind] + ("depot" if o.kind == "supply" else "vorkommen")
		info_sub.text = "Neutral"
		info_hp_lbl.text = ""
		info_status.text = "Noch %s %s. Sammler mit Rechtsklick hierher schicken." % [_fmt(int(o.supply)), "Credits" if o.kind == "supply" else Defs.RES_NAMES[o.kind]]
		prod_bar.visible = false
		return
	var owner_txt: String = "Eigene Einheit" if o.owner_id == Game.human else "Spieler %d · %s" % [o.owner_id + 1, Game.players[o.owner_id]["name"]]
	if sel.size() > 1:
		var counts = {}
		var hp = 0.0
		var mhp = 0.0
		for u in sel:
			if not is_instance_valid(u):
				continue
			counts[u.def["name"]] = counts.get(u.def["name"], 0) + 1
			hp += u.hp
			mhp += u.max_hp
		info_title.text = "%d Einheiten" % sel.size()
		var parts: Array = []
		for k in counts:
			parts.append("%d× %s" % [counts[k], k])
		info_sub.text = owner_txt
		info_status.text = ", ".join(parts)
		_set_hp(hp, mhp)
		prod_bar.visible = false
		return
	info_title.text = o.def["name"]
	_set_hp(o.hp, o.max_hp)
	prod_bar.visible = false
	if o.is_unit:
		var rk: String = Defs.RANK_NAMES[o.rank]
		info_sub.text = "%s · %s" % [owner_txt, rk]
		var st: String = o.status_text()
		var tt: String = o.trait_text()
		if tt != "":
			st += "\n" + tt
		var w = o.def["weapon"]
		if w != null:
			st += "\nWaffe: %s · Reichweite %d · %s" % [_wname(w["type"]), int(w["range"]), _good_vs(w)]
		if o.owner_id == Game.human:
			st += "\n" + String(o.def["desc"])
		info_status.text = st
	else:
		info_sub.text = owner_txt
		var st = ""
		if not o.complete:
			st = "Im Bau: %d %%. Bauarbeiter mit Rechtsklick auf die Baustelle schicken." % int(o.progress * 100)
			prod_bar.visible = true
			prod_bar.value = o.progress * 100.0
		else:
			st = String(o.def["desc"])
			if o.owner_id == Game.human:
				if not Game.has_power(Game.human) and o.def["power"] < 0:
					st += "\nStrommangel: Produktion halbiert, Abwehr und Superwaffe außer Betrieb. Kraftwerk bauen!"
				if o.def["role"] == "super":
					st += "\n" + ("Feuerbereit – unten auf Abfeuern klicken." if o.super_ready else "Lädt: noch %s" % _clock(o.super_t))
				if not o.def["produces"].is_empty():
					st += "\nRechtsklick ins Gelände setzt den Sammelpunkt."
					if not o.queue.is_empty():
						prod_bar.visible = true
						prod_bar.value = o.prod_progress() * 100.0
		info_status.text = st

func _idle_hint() -> String:
	var r = Game.roles(Game.human)
	if Game.spectator:
		return "Zuschauermodus: Die KI spielt gegen sich selbst. Leertaste springt zum Geschehen."
	if not r.has("supply"):
		return "Erster Schritt: Bauarbeiter auswählen und ein Nachschubzentrum nahe dem Depot bauen."
	var fac: String = Game.players[Game.human]["faction"]
	if Defs.factions[fac]["uses_power"] and not r.has("power"):
		return "Als Nächstes: Kraftwerk bauen – Kaserne und Fabrik brauchen Strom."
	if not r.has("barracks"):
		return "Kaserne bauen, um Infanterie auszubilden."
	if not r.has("factory"):
		return "Fabrik bauen, um Fahrzeuge zu produzieren."
	return "Tipp: H springt zum Hauptquartier, G öffnet die Generalsfähigkeiten."

func _set_hp(hp: float, mhp: float) -> void:
	var f: float = clamp(hp / max(mhp, 1.0), 0.0, 1.0)
	info_hp.value = f * 100.0
	var sb = _sb(_hp_col(f), Color(0, 0, 0, 0), 3, 0, 0.0)
	info_hp.add_theme_stylebox_override("fill", sb)
	info_hp_lbl.text = "%d / %d" % [int(max(hp, 0)), int(mhp)]

func _hp_col(f: float) -> Color:
	if f > 0.6:
		return Color(0.3, 0.85, 0.4)
	if f > 0.3:
		return Color(0.95, 0.8, 0.2)
	return Color(0.95, 0.3, 0.2)

func _wname(t: String) -> String:
	return {"bullet": "MG", "flak": "Flak", "gatling": "Gatling", "shell": "Kanone", "rocket": "Raketen", "flame": "Flammenwerfer",
		"toxin": "Gift", "laser": "Laser", "artillery": "Artillerie", "bomb": "Bomben", "demolition": "Sprengladung"}.get(t, t)

func _good_vs(w: Dictionary) -> String:
	var m: Dictionary = Defs.DMG_MOD[w["type"]]
	var names = {"inf": "Infanterie", "light": "leichte Fahrzeuge", "heavy": "Panzer", "air": "Luft", "bldg": "Gebäude"}
	var best: Array = []
	for k in m:
		if m[k] >= 1.0 and (k != "air" or w["air"]):
			best.append(names[k])
	if best.is_empty():
		return "Allrounder"
	return "stark gegen " + ", ".join(best)

# ---------------------------------------------------------------- Befehlsraster

func _add_cmd(text: String, kind: String, id: String, ref = null) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(128, 62)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.pressed.connect(_on_cmd.bind(kind, id))
	b.gui_input.connect(_on_cmd_input.bind(kind, id))
	grid.add_child(b)
	_btns.append({"btn": b, "kind": kind, "id": id, "ref": ref})
	return b

func _rebuild_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	_btns.clear()
	if Game.spectator:
		return
	var c = Game.ctrl
	var fac: String = Game.players[Game.human]["faction"]
	var dz = c.selected_dozer()
	var b = c.single_building()
	if dz != null:
		for id in Defs.build_list(fac):
			var d: Dictionary = Defs.buildings[id]
			_add_cmd("%s\n%s" % [d["name"], _fmt(d["cost"])], "build", id)
		_add_cmd("Stopp (S)", "stop", "")
	elif b != null:
		if not b.complete:
			_add_cmd("Bau abbrechen\n(volle Erstattung)", "cancel_build", "")
		else:
			for uid in b.def["produces"]:
				var ud: Dictionary = Defs.units[uid]
				_add_cmd("%s\n%s" % [ud["name"], _fmt(ud["cost"])], "train", uid)
			if b.def["role"] == "super":
				_add_cmd("ABFEUERN", "fire_super", "")
			_add_cmd("Verkaufen\n(+50 %)", "sell", "")
	elif not c.selected_units().is_empty():
		_add_cmd("Stopp\n(S)", "stop", "")
		_add_cmd("Angriffs-\nbewegung (A)", "attackmove", "")
		_add_cmd("Alle dieses\nTyps", "same", "")
		var has_h = false
		for u in c.selected_units():
			if u.def["role"] == "harvester":
				has_h = true
		if has_h:
			for k in ["supply", "wood", "iron", "oil", "gold"]:
				_add_cmd("%s\nsammeln" % Defs.RES_NAMES[k], "harvest", k)
	_refresh_grid()

func _res_tip(k: String) -> String:
	match k:
		"wood": return "Holz: wird für fast alle Gebäude gebraucht. Sammler fahren zu Wäldchen (Rechtsklick)."
		"iron": return "Eisen: wird im Nachschubgebäude zu Stahl geschmolzen (2 Eisen + 1 Öl = 1 Stahl)."
		"oil": return "Öl: Brennstoff für Stahlwerk und alle Flugzeuge. Ölquellen liegen am Rand jeder Basis."
		"gold": return "Gold: für Forschung, Superwaffen und die teuersten Einheiten. Adern liegen in der Kartenmitte."
	return "Stahl: für Fabriken, Abwehr und schwere Fahrzeuge. Entsteht automatisch in Nachschubgebäuden."

func _refresh_grid() -> void:
	if Game.spectator or Game.players.is_empty():
		return
	var p: Dictionary = Game.players[Game.human]
	var b = Game.ctrl.single_building()
	for e in _btns:
		var btn: Button = e["btn"]
		if not is_instance_valid(btn):
			continue
		match e["kind"]:
			"build":
				var d: Dictionary = Defs.buildings[e["id"]]
				var why = Game.missing_prereq(d, Game.human)
				if why == "":
					why = Game.afford_why(Game.human, d)
				btn.disabled = why != ""
				var pw = ""
				if d["power"] != 0 and Defs.factions[d["faction"]]["uses_power"]:
					pw = "\nStrom: %+d" % d["power"]
				btn.tooltip_text = "%s – %s Credits%s, %d s\n%s%s%s" % [d["name"], _fmt(d["cost"]), ("  +  " + Defs.res_text(d["res"])) if not d["res"].is_empty() else "", int(d["time"]), d["desc"], pw, ("\n\n" + why) if why != "" else ""]
			"train":
				if b == null:
					continue
				var ud: Dictionary = Defs.units[e["id"]]
				var why2: String = b.can_queue(e["id"])
				var n = b.queue.count(e["id"])
				btn.text = "%s%s\n%s" % [ud["name"], (" ×%d" % n) if n > 0 else "", _fmt(ud["cost"])]
				btn.disabled = why2 != "" and why2 != "Warteschlange ist voll"
				var w = ud["weapon"]
				var wtxt = ""
				if w != null:
					wtxt = "\nWaffe: %s, Reichweite %d – %s" % [_wname(w["type"]), int(w["range"]), _good_vs(w)]
				btn.tooltip_text = "%s – %s Credits%s, %d s\n%s\nLeben %d · Tempo %.1f%s\n\nLinksklick: in Auftrag geben · Rechtsklick: einen stornieren (volle Erstattung)%s" % [
					ud["name"], _fmt(ud["cost"]), ("  +  " + Defs.res_text(ud["res"])) if not ud["res"].is_empty() else "", int(ud["time"]), ud["desc"], ud["hp"], ud["speed"], wtxt, ("\n\n" + why2) if why2 != "" else ""]
			"fire_super":
				btn.disabled = b == null or not b.super_ready or not Game.has_power(Game.human)
				btn.tooltip_text = "Superwaffe abfeuern, danach Ziel anklicken." if not btn.disabled else "Superwaffe lädt noch oder es fehlt Strom."
			"sell":
				btn.text = "Wirklich\nverkaufen?" if _sell_armed > 0.0 else "Verkaufen\n(+50 %)"
				btn.tooltip_text = "Gebäude abreißen und die Hälfte der Kosten zurückerhalten. Zweimal klicken zum Bestätigen."
			"cancel_build":
				btn.tooltip_text = "Baustelle aufgeben. Du bekommst die vollen Kosten zurück."

func _on_cmd(kind: String, id: String) -> void:
	var c = Game.ctrl
	match kind:
		"build":
			c.begin_place(id)
		"train":
			var b = c.single_building()
			if b != null:
				var why: String = b.queue_unit(id)
				if why != "":
					Game.notify(why, Color(1, 0.6, 0.4))
		"stop":
			for u in c.selected_units():
				u.cmd_stop()
		"attackmove":
			c.begin_attackmove()
		"same":
			var us: Array = c.selected_units()
			if not us.is_empty():
				c.select_same_type_on_screen(us[0].def["id"])
		"harvest":
			for u in c.selected_units():
				u.cmd_harvest(null, id)
		"fire_super":
			var b2 = c.single_building()
			if b2 != null:
				c.begin_super(b2)
		"sell":
			if _sell_armed > 0.0:
				var b3 = c.single_building()
				if b3 != null:
					b3.sell()
				_sell_armed = 0.0
			else:
				_sell_armed = 3.0
			_refresh_grid()
		"cancel_build":
			var b4 = c.single_building()
			if b4 != null:
				b4.sell()

func _on_cmd_input(ev: InputEvent, kind: String, id: String) -> void:
	if kind != "train":
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		var b = Game.ctrl.single_building()
		if b != null:
			var i: int = b.queue.rfind(id)
			if i >= 0:
				b.cancel_unit(i)

var _qsig = ""

func _update_queue() -> void:
	var b = Game.ctrl.single_building()
	var qs = ""
	if b != null and b.complete:
		qs = str(b.get_instance_id()) + ":" + ",".join(b.queue)
	if qs == _qsig:
		return
	_qsig = qs
	for c in queue_box.get_children():
		c.queue_free()
	if b == null or not b.complete or b.queue.is_empty():
		return
	for i in b.queue.size():
		var ud: Dictionary = Defs.units[b.queue[i]]
		var nm: String = ud["name"]
		var qb = Button.new()
		qb.text = nm.substr(0, 9)
		qb.tooltip_text = "%s – Klick storniert (volle Erstattung)" % nm
		qb.custom_minimum_size = Vector2(70, 26)
		qb.add_theme_font_size_override("font_size", 11)
		qb.focus_mode = Control.FOCUS_NONE
		qb.pressed.connect(b.cancel_unit.bind(i))
		queue_box.add_child(qb)

# ---------------------------------------------------------------- Generalsfähigkeiten

func _refresh_powers() -> void:
	for c in powers_list.get_children():
		c.queue_free()
	if Game.players.is_empty():
		return
	var p: Dictionary = Game.players[Game.human]
	var f: Dictionary = Defs.factions[p["faction"]]
	powers_list.add_child(_label("%s · Rang %d · %d freie %s" % [ui["powers"], p["rank"], p["points"], ui["point"][1]], 19, Color(1, 0.9, 0.5)))
	var nxt = ""
	if p["rank"] < Game.RANK_XP.size():
		nxt = "Nächster Rang bei %s Erfahrung (aktuell %s)." % [_fmt(int(Game.RANK_XP[p["rank"]])), _fmt(int(p["xp"]))]
	powers_list.add_child(_label(nxt, 13, Color(0.7, 0.78, 0.85)))
	for pw in f["powers"]:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		powers_list.add_child(h)
		var unlocked: bool = p["unlocked"].has(pw["id"])
		var why: String = Game.powers.why_not(Game.human, pw)
		var b = Button.new()
		b.custom_minimum_size = Vector2(190, 44)
		b.focus_mode = Control.FOCUS_NONE
		if not unlocked:
			b.text = "Freischalten: " + String(pw["name"])
			b.disabled = p["points"] <= 0
			b.pressed.connect(func():
				Game.powers.unlock(Game.human, pw)
				_refresh_powers())
		else:
			b.text = pw["name"]
			b.disabled = why != ""
			b.pressed.connect(_use_power.bind(pw))
		h.add_child(b)
		var l = _label("%s\n%s" % [pw["desc"], why if why != "" else "Bereit."], 13, Color(0.82, 0.88, 0.95))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		h.add_child(l)
	var sw: Dictionary = f["super"]
	powers_list.add_child(_label("Superwaffe: %s – erfordert Forschung und Bau des Superwaffen-Gebäudes." % sw["name"], 13, Color(0.6, 0.75, 0.9)))
	powers_list.add_child(_button("Schließen (G)", toggle_powers))

func _use_power(pw: Dictionary) -> void:
	if Game.powers.why_not(Game.human, pw) != "":
		return
	if Game.powers.needs_target(pw):
		powers_panel.visible = false
		Game.ctrl.begin_power(pw)
	else:
		Game.powers.use(Game.human, pw, Vector3.ZERO)
		_refresh_powers()

# ---------------------------------------------------------------- Overlay

func _draw_overlay() -> void:
	if not Game.running or Game.cam == null:
		return
	var cam: Camera3D = Game.cam.cam
	var c = Game.ctrl
	if c.dragging and c.box_active:
		var r: Rect2 = c.box_rect()
		overlay.draw_rect(r, Color(0.4, 1.0, 0.5, 0.1))
		overlay.draw_rect(r, Color(0.4, 1.0, 0.5, 0.8), false, 1.5)
	var vs = overlay.get_viewport_rect().size
	for o in Game.units + Game.buildings:
		if not o.alive or not o.visible:
			continue
		var show: bool = o.selected or o == c.hover or (o.hp < o.max_hp and o.owner_id == Game.human) or (o.is_building and not o.complete)
		if not show:
			continue
		var h: float = (o.height + 1.0) if o.is_building else (o.body.position.y + float(o.model["height"]) * float(o.def["scale"]) + 0.6)
		var wp: Vector3 = o.position + Vector3(0, h, 0)
		if cam.is_position_behind(wp):
			continue
		var sp = cam.unproject_position(wp)
		if sp.x < -50 or sp.y < -50 or sp.x > vs.x + 50 or sp.y > vs.y + 50:
			continue
		var w: float = 34.0 if o.is_unit and not o.is_vehicle else (48.0 if o.is_unit else 70.0)
		var f: float = clamp(o.hp / o.max_hp, 0.0, 1.0)
		overlay.draw_rect(Rect2(sp.x - w / 2 - 1, sp.y - 1, w + 2, 6), Color(0, 0, 0, 0.75))
		overlay.draw_rect(Rect2(sp.x - w / 2, sp.y, w * f, 4), _hp_col(f))
		if o.is_unit and o.max_shield > 0.0:
			overlay.draw_rect(Rect2(sp.x - w / 2 - 1, sp.y - 5, w + 2, 4), Color(0, 0, 0, 0.75))
			overlay.draw_rect(Rect2(sp.x - w / 2, sp.y - 4, w * o.shield / o.max_shield, 2), Color(0.4, 0.85, 1.0))
		if o.is_building and not o.complete:
			overlay.draw_rect(Rect2(sp.x - w / 2, sp.y + 6, w * o.progress, 3), Color(0.4, 0.75, 1.0))
		if o.is_building and o.complete and not o.queue.is_empty() and o.owner_id == Game.human:
			overlay.draw_rect(Rect2(sp.x - w / 2, sp.y + 6, w * o.prod_progress(), 3), Color(0.4, 0.75, 1.0))
		if o.is_unit and o.rank > 0:
			for i in o.rank:
				var x: float = sp.x + w / 2 + 4 + i * 6
				overlay.draw_colored_polygon(PackedVector2Array([Vector2(x, sp.y + 5), Vector2(x + 2.5, sp.y - 1), Vector2(x + 5, sp.y + 5)]), Color(1, 0.85, 0.2))
		if o.is_building and o.selected and o.owner_id == Game.human and o.has_rally:
			var rp = cam.unproject_position(o.rally)
			overlay.draw_dashed_line(cam.unproject_position(o.position), rp, Color(0.4, 0.8, 1.0, 0.6), 1.5, 6.0)
			overlay.draw_circle(rp, 4.0, Color(0.4, 0.8, 1.0))
	# Wegziele ausgewählter Einheiten
	for o in c.selection:
		if is_instance_valid(o) and o.is_unit and o.alive and o.owner_id == Game.human and not o.path.is_empty() and o.order != "harvest":
			var a = cam.unproject_position(o.position)
			var b = cam.unproject_position(o.path[o.path.size() - 1])
			overlay.draw_dashed_line(a, b, Color(0.4, 1.0, 0.5, 0.35) if o.order == "move" else Color(1, 0.45, 0.35, 0.4), 1.2, 5.0)
	if c.hint != "":
		var mp = overlay.get_viewport().get_mouse_position()
		var font = overlay.get_theme_default_font()
		overlay.draw_string_outline(font, mp + Vector2(18, 30), c.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
		overlay.draw_string(font, mp + Vector2(18, 30), c.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.5))

# ---------------------------------------------------------------- Ende

func _on_match_end(won: bool) -> void:
	end_layer = _dim_layer()
	var p = _center_panel(end_layer, 520)
	var v: VBoxContainer = p.get_child(0)
	var title = "SIEG" if won else "NIEDERLAGE"
	if Game.spectator:
		title = "GEFECHT BEENDET"
	v.add_child(_label(title, 40, Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.4, 0.35)))
	v.add_child(_label("Spieldauer %s" % _clock(Game.time), 15, Color(0.7, 0.8, 0.9)))
	var g = GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 18)
	v.add_child(g)
	for t in ["Spieler", "Abschüsse", "Verluste", "Gebäude", "Einnahmen"]:
		g.add_child(_label(t, 13, Color(0.6, 0.7, 0.8)))
	for pl in Game.players:
		g.add_child(_label("%s%s" % [pl["name"], " (Du)" if pl["id"] == Game.human and not Game.spectator else ""], 14, pl["color"].lightened(0.3)))
		g.add_child(_label(str(pl["kills"]), 14))
		g.add_child(_label(str(pl["losses"]), 14))
		g.add_child(_label(str(pl["built"]), 14))
		g.add_child(_label(_fmt(int(pl["income"])), 14))
	var bh = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	v.add_child(bh)
	bh.add_child(_button("Neues Gefecht", _new_game, Vector2(200, 44)))
	bh.add_child(_button("Weiter zuschauen", _close_end, Vector2(170, 44)))
	bh.add_child(_button("Beenden", _quit, Vector2(110, 44)))

func _help_from_pause() -> void:
	toggle_pause()
	toggle_help()

func _new_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _close_end() -> void:
	if end_layer != null:
		end_layer.queue_free()
		end_layer = null

func _quit() -> void:
	get_tree().quit()