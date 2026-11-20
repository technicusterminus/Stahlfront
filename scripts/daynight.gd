extends Node
## Tag- und Nachtwechsel: Sonnenbahn, Mond, Himmelsfarben, Nebel und Belichtung.
## Die Uhrzeit läuft mit der Spielzeit (Dauer eines vollen Tages in Minuten einstellbar, 0 = Stillstand).
## Nachts sinkt die Sichtweite aller Einheiten und Gebäude.

# Stützstellen: Stunde, Himmel oben, Horizont, Bodenhorizont, Licht, Lichtstärke, Umgebungslicht, Nebelfarbe, Belichtung
const KEYS := [
	{"h": 0.0,  "top": Color(0.015, 0.03, 0.09), "hor": Color(0.04, 0.06, 0.13), "gnd": Color(0.02, 0.03, 0.06), "sun": Color(0.55, 0.66, 1.0), "e": 0.45, "amb": 0.38, "fog": Color(0.07, 0.1, 0.18), "exp": 1.35},
	{"h": 4.5,  "top": Color(0.02, 0.04, 0.11), "hor": Color(0.06, 0.08, 0.16), "gnd": Color(0.03, 0.04, 0.07), "sun": Color(0.55, 0.66, 1.0), "e": 0.42, "amb": 0.38, "fog": Color(0.08, 0.1, 0.18), "exp": 1.35},
	{"h": 5.8,  "top": Color(0.18, 0.25, 0.45), "hor": Color(0.95, 0.55, 0.38), "gnd": Color(0.3, 0.22, 0.2), "sun": Color(1.0, 0.6, 0.38), "e": 0.7, "amb": 0.5, "fog": Color(0.7, 0.5, 0.45), "exp": 1.15},
	{"h": 7.5,  "top": Color(0.26, 0.42, 0.7), "hor": Color(0.82, 0.74, 0.66), "gnd": Color(0.55, 0.52, 0.48), "sun": Color(1.0, 0.86, 0.7), "e": 1.3, "amb": 0.7, "fog": Color(0.68, 0.7, 0.74), "exp": 1.05},
	{"h": 12.0, "top": Color(0.24, 0.43, 0.75), "hor": Color(0.7, 0.74, 0.78), "gnd": Color(0.6, 0.6, 0.58), "sun": Color(1.0, 0.95, 0.88), "e": 1.6, "amb": 0.78, "fog": Color(0.62, 0.68, 0.76), "exp": 1.05},
	{"h": 16.5, "top": Color(0.26, 0.42, 0.7), "hor": Color(0.78, 0.72, 0.64), "gnd": Color(0.55, 0.52, 0.48), "sun": Color(1.0, 0.88, 0.68), "e": 1.35, "amb": 0.72, "fog": Color(0.68, 0.68, 0.7), "exp": 1.05},
	{"h": 18.8, "top": Color(0.2, 0.22, 0.42), "hor": Color(1.0, 0.5, 0.25), "gnd": Color(0.32, 0.2, 0.16), "sun": Color(1.0, 0.5, 0.25), "e": 0.8, "amb": 0.5, "fog": Color(0.75, 0.45, 0.35), "exp": 1.15},
	{"h": 20.3, "top": Color(0.06, 0.08, 0.2), "hor": Color(0.3, 0.2, 0.3), "gnd": Color(0.08, 0.07, 0.1), "sun": Color(0.7, 0.5, 0.6), "e": 0.28, "amb": 0.34, "fog": Color(0.2, 0.15, 0.25), "exp": 1.3},
	{"h": 22.0, "top": Color(0.02, 0.035, 0.1), "hor": Color(0.05, 0.07, 0.14), "gnd": Color(0.02, 0.03, 0.06), "sun": Color(0.55, 0.66, 1.0), "e": 0.45, "amb": 0.38, "fog": Color(0.07, 0.1, 0.18), "exp": 1.35},
	{"h": 24.0, "top": Color(0.015, 0.03, 0.09), "hor": Color(0.04, 0.06, 0.13), "gnd": Color(0.02, 0.03, 0.06), "sun": Color(0.55, 0.66, 1.0), "e": 0.45, "amb": 0.38, "fog": Color(0.07, 0.1, 0.18), "exp": 1.35},
]

var env: Environment
var psm: ProceduralSkyMaterial
var sun: DirectionalLight3D
var start_hour = 9.0
var cycle_minutes = 0.0
var hour = 9.0

func setup(e: Environment, p: ProceduralSkyMaterial, s: DirectionalLight3D) -> void:
	env = e
	psm = p
	sun = s
	hour = start_hour
	apply(start_hour)

func configure(start: float, minutes: float) -> void:
	start_hour = fposmod(start, 24.0)
	cycle_minutes = minutes
	hour = start_hour
	apply(hour)

func _process(_delta: float) -> void:
	if env == null:
		return
	if cycle_minutes > 0.0 and Game.running:
		hour = fposmod(start_hour + Game.time / (cycle_minutes * 60.0) * 24.0, 24.0)
	else:
		hour = start_hour if not Game.running else hour
	apply(hour)

## 0 = voller Tag, 1 = tiefe Nacht.
func night_amount(h: float) -> float:
	if h >= 7.0 and h <= 17.5:
		return 0.0
	if h >= 5.8 and h < 7.0:
		return (7.0 - h) / 1.2 * 0.6
	if h > 17.5 and h <= 19.0:
		return (h - 17.5) / 1.5 * 0.5
	if h > 19.0 and h < 21.5:
		return 0.5 + (h - 19.0) / 2.5 * 0.5
	if h >= 21.5 or h < 4.5:
		return 1.0
	return 1.0 - (h - 4.5) / 1.3 * 0.4

func clock_text(h: float) -> String:
	var hh = int(h)
	var mm = int((h - hh) * 60.0)
	var phase = "Nacht"
	if h >= 5.0 and h < 7.5:
		phase = "Morgen"
	elif h >= 7.5 and h < 17.5:
		phase = "Tag"
	elif h >= 17.5 and h < 20.5:
		phase = "Abend"
	return "%02d:%02d %s" % [hh, mm, phase]

func apply(h: float) -> void:
	var a: Dictionary = KEYS[0]
	var b: Dictionary = KEYS[1]
	for i in KEYS.size() - 1:
		if h >= KEYS[i]["h"] and h <= KEYS[i + 1]["h"]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t = 0.0 if b["h"] == a["h"] else (h - a["h"]) / (b["h"] - a["h"])
	t = smoothstep(0.0, 1.0, t)
	psm.sky_top_color = a["top"].lerp(b["top"], t)
	psm.sky_horizon_color = a["hor"].lerp(b["hor"], t)
	psm.ground_horizon_color = a["hor"].lerp(b["hor"], t).lerp(a["gnd"].lerp(b["gnd"], t), 0.5)
	psm.ground_bottom_color = a["gnd"].lerp(b["gnd"], t)
	sun.light_color = a["sun"].lerp(b["sun"], t)
	sun.light_energy = lerp(float(a["e"]), float(b["e"]), t)
	env.ambient_light_energy = lerp(float(a["amb"]), float(b["amb"]), t)
	env.fog_light_color = a["fog"].lerp(b["fog"], t)
	env.tonemap_exposure = lerp(float(a["exp"]), float(b["exp"]), t)
	env.volumetric_fog_albedo = a["fog"].lerp(b["fog"], t).lightened(0.2)
	# Sonne tagsüber auf Bogen, nachts Mond auf der Gegenseite
	if h >= 5.5 and h <= 19.0:
		var k = clamp((h - 5.5) / 13.5, 0.0, 1.0)
		var elev = max(sin(k * PI), 0.05) * 58.0
		sun.rotation = Vector3(deg_to_rad(-elev), deg_to_rad(38.0 + (k - 0.5) * 80.0), 0.0)
	else:
		sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(38.0 + 180.0), 0.0)
	var rn: float = Game.rain
	if rn > 0.01:
		var grey := Color(0.36, 0.39, 0.43)
		psm.sky_top_color = psm.sky_top_color.lerp(grey * 0.8, rn * 0.75)
		psm.sky_horizon_color = psm.sky_horizon_color.lerp(grey, rn * 0.8)
		psm.ground_horizon_color = psm.ground_horizon_color.lerp(grey, rn * 0.6)
		sun.light_energy *= 1.0 - 0.55 * rn
		env.ambient_light_energy *= 1.0 - 0.1 * rn
		env.fog_light_color = env.fog_light_color.lerp(grey, rn * 0.7)
		env.fog_density = 0.0016 + 0.0042 * rn
		env.volumetric_fog_density = 0.006 + 0.01 * rn
	else:
		env.fog_density = 0.0016
		env.volumetric_fog_density = 0.006
	Game.sight_mult = (1.0 - 0.28 * night_amount(h)) * (1.0 - 0.18 * rn)
	Game.hour = h
