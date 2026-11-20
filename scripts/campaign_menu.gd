extends RefCounted
## Kampagnenmenü: Tutorials (immer offen) und die Westbund-Kampagne (Kapitel schalten nacheinander frei).

const Missions = preload("res://scripts/missions.gd")

const CAMPAIGN_TITLES := {
	"west": "Das Licht über Lysa (Westbund)",
	"red": "Der lange Marsch nach Aurelia (Rote Allianz)",
	"shadow": "Wer am Feuer sitzt (Schattenfront)",
}

static func open(hud) -> void:
	var layer = hud._dim_layer()
	layer.color = Color(0.02, 0.04, 0.08, 0.97)
	var p = hud._center_panel(layer, 760)
	var v: VBoxContainer = p.get_child(0)
	v.add_child(hud._label("KAMPAGNE UND TUTORIAL", 30, Color(1, 1, 1)))
	var fac: String = hud._cfg["faction"]
	var fname: String = Defs.factions[fac]["name"]
	Game.mission_faction = fac
	v.add_child(hud._label("Tutorials spielst du mit deiner Fraktion aus dem Hauptmenü: %s. Jede Fraktion erzählt dieselbe Geschichte aus ihrer Sicht." % fname, 14, Color(0.7, 0.8, 0.9)))
	v.add_child(HSeparator.new())
	v.add_child(hud._label("Tutorial", 18, Color(0.55, 0.85, 1.0)))
	for id in Missions.ids("tutorial"):
		v.add_child(_row(hud, layer, id))
	v.add_child(HSeparator.new())
	for fk in ["west", "red", "shadow"]:
		var ids: Array = Missions.campaign_ids(fk)
		if ids.is_empty():
			continue
		v.add_child(hud._label("Kampagne: %s" % CAMPAIGN_TITLES[fk], 18, Color(0.55, 0.85, 1.0)))
		for id in ids:
			v.add_child(_row(hud, layer, id))
	v.add_child(HSeparator.new())
	v.add_child(hud._button("Zurück", func(): layer.queue_free(), Vector2(140, 40)))

static func _row(hud, layer: Control, id: String) -> Control:
	var m: Dictionary = Missions.by_id(id)
	var open_: bool = Missions.unlocked(id)
	var done: bool = Missions.is_done(id)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var mark = ("✔  " if done else ("    " if open_ else "🔒 "))
	var b = hud._button(mark + String(m["title"]), func():
		layer.queue_free()
		hud.start_mission(id), Vector2(430, 40))
	b.disabled = not open_
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(b)
	var first: String = String(m["brief"]).split("\n")[0]
	if first.length() > 92:
		first = first.substr(0, 90) + "…"
	var l = hud._label(first, 12, Color(0.62, 0.7, 0.78))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	row.add_child(l)
	return row
