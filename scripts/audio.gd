extends Node
## Ton: Einheitenstimmen (Auswahl, Marsch, Angriff, Bau, Nachschub) und Gebäudegeräusche.
## Stimmen liegen unter res://audio/voice/<fraktion>/<art>_<n>.wav, Geräusche unter res://audio/sfx/<name>.wav.
## Fehlende Dateien werden still übersprungen; mit Taste F8 lässt sich der Ton ein- und ausschalten.

var enabled := true
var voice_db := 0.0
var sfx_db := -3.0
var _pool: Array = []
var _cache := {}
var _index := {}
var _last_voice := -10.0
var _last_pick := {}
var _last_sfx := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	var path = "res://audio/voice/index.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_index = parsed

func _stream(path: String):
	if _cache.has(path):
		return _cache[path]
	var s = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[path] = s
	return s

func _play(stream, db: float, pitch := 1.0) -> void:
	if stream == null or not enabled:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return

## Geräusch abspielen; gleiche Geräusche höchstens alle 0,12 s.
func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - float(_last_sfx.get(name, -10.0)) < 0.12:
		return
	_last_sfx[name] = now
	_play(_stream("res://audio/sfx/%s.wav" % name), sfx_db + db, pitch)

## Klick auf ein eigenes Gebäude: Klang je Rolle, leicht verstimmt je Fraktion.
func building_click(b) -> void:
	if b == null or not is_instance_valid(b):
		return
	var role: String = b.def["role"]
	var fac: String = b.def["faction"]
	var pitch = {"west": 1.04, "red": 0.92, "shadow": 0.98}.get(fac, 1.0)
	var name = "building_" + role
	if _stream("res://audio/sfx/%s.wav" % name) == null:
		name = "ui_click"
	sfx(name, 0.0, pitch)

## Einheitenstimme: art = select | move | attack | build | harvest; Luft- und Seeeinheiten bekommen eigene Marschzeilen.
func voice(u, kind: String) -> void:
	if u == null or not is_instance_valid(u) or not enabled:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_voice < 1.1:
		return
	var fac: String = u.def["faction"]
	var k = kind
	if kind == "move":
		if u.flying:
			k = "air_move"
		elif u.naval:
			k = "naval_move"
	var count := int(_index.get(fac, {}).get(k, 0))
	if count <= 0:
		return
	var key = fac + k
	var i = randi() % count
	if count > 1 and i == int(_last_pick.get(key, -1)):
		i = (i + 1) % count
	_last_pick[key] = i
	_last_voice = now
	_play(_stream("res://audio/voice/%s/%s_%d.wav" % [fac, k, i]), voice_db)

func toggle() -> void:
	enabled = not enabled
	Game.notify("Ton %s." % ("an" if enabled else "aus"), Color(0.7, 0.9, 1.0))
