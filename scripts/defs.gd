extends Node
## Alle Spielwerte: Fraktionen, Einheiten, Gebäude, Generalsfähigkeiten.

# Schadensfaktor je Waffentyp gegen Panzerungsklasse.
const DMG_MOD := {
	"bullet":    {"inf": 1.0, "light": 0.55, "heavy": 0.2, "air": 0.5, "bldg": 0.12},
	"gatling":   {"inf": 1.3, "light": 0.85, "heavy": 0.5, "air": 1.8, "bldg": 0.12},
	"flak":      {"inf": 0.7, "light": 0.4, "heavy": 0.12, "air": 2.2, "bldg": 0.06},
	"shell":     {"inf": 0.45, "light": 1.0, "heavy": 1.0, "air": 0.0, "bldg": 0.75},
	"rocket":    {"inf": 0.35, "light": 1.0, "heavy": 1.25, "air": 1.3, "bldg": 0.7},
	"flame":     {"inf": 1.6, "light": 0.8, "heavy": 0.35, "air": 0.0, "bldg": 0.9},
	"toxin":     {"inf": 1.9, "light": 0.35, "heavy": 0.12, "air": 0.0, "bldg": 0.1},
	"laser":     {"inf": 1.0, "light": 1.0, "heavy": 1.05, "air": 0.9, "bldg": 0.7},
	"artillery": {"inf": 0.9, "light": 0.85, "heavy": 0.75, "air": 0.0, "bldg": 1.4},
	"demolition": {"inf": 1.2, "light": 1.3, "heavy": 1.0, "air": 0.0, "bldg": 1.8},
	"bomb": {"inf": 1.0, "light": 1.15, "heavy": 1.0, "air": 0.0, "bldg": 1.6},
}

const ROLE_NAMES := {
	"hq": "Hauptquartier", "power": "Kraftwerk", "supply": "Nachschub", "barracks": "Kaserne",
	"factory": "Fabrik", "airfield": "Flugfeld", "dock": "Werft", "defense": "Abwehr", "tech": "Forschung", "super": "Superwaffe",
}

const RANK_NAMES := ["Rekrut", "Veteran", "Elite", "Held"]

var factions = {}
var units = {}
var buildings = {}

func _init() -> void:
	_factions()
	_west()
	_red()
	_shadow()
	_faction_traits()
	_resource_costs()

func W(type: String, dmg: float, rng: float, rof: float, extra := {}) -> Dictionary:
	var w = {"type": type, "dmg": dmg, "range": rng, "rof": rof, "splash": 0.0, "air": false,
		"ground": true, "burst": 1, "min_range": 0.0}
	w.merge(extra, true)
	return w

func U(id: String, d: Dictionary) -> void:
	d["id"] = id
	d["faction"] = id.split("_")[0]
	d.merge({"sight": 18.0, "armor": "light", "speed": 6.0, "flying": false, "role": "combat",
		"scale": 1.0, "weapon": null, "prereq": [], "desc": "", "horde": false, "cargo": 0,
		"shield": 0.0, "stealth": false, "pair": false, "salvage": false, "built_at": "",
		"fixed_wing": false, "turn": 1.3, "naval": false}, false)
	units[id] = d

func B(id: String, d: Dictionary) -> void:
	d["id"] = id
	d["faction"] = id.split("_")[0]
	d["role"] = id.split("_", true, 1)[1]
	d.merge({"sight": 18.0, "power": 0, "produces": [], "prereq": [], "weapon": null,
		"desc": "", "size": 3, "aura": 0.0}, false)
	buildings[id] = d

func _factions() -> void:
	factions["west"] = {
		"name": "Westbund", "color": Color(0.22, 0.45, 0.95), "uses_power": true,
		"desc": "Hightech-Armee. Teuer, aber präzise: Laserwaffen, Kampfhubschrauber, starke Panzerung.",
		"perks": [
			"Energieschilde: Fahrzeuge und Hubschrauber tragen einen Schild, der sich nach 4 s ohne Treffer auflädt.",
			"Fliegende Baudrohnen: bauen über jedes Gelände hinweg, nur von Flugabwehr zu treffen.",
			"Spähdrohne: billiger fliegender Aufklärer mit riesiger Sichtweite.",
		],
		"powers": [
			{"id": "reveal", "name": "Aufklärungsdrohne", "desc": "Deckt ein großes Gebiet 40 Sekunden lang auf.", "cooldown": 90.0, "radius": 34.0},
			{"id": "airstrike", "name": "Präzisionsluftschlag", "desc": "Drei Bomber treffen das Zielgebiet.", "cooldown": 180.0, "radius": 10.0, "value": 420.0},
			{"id": "paradrop", "name": "Fallschirmjäger", "desc": "Sechs Soldaten landen am Zielort.", "cooldown": 150.0, "unit": "west_inf", "count": 6},
		],
		"super": {"name": "Orbitalkanone", "type": "laser", "radius": 15.0, "dmg": 3200.0, "charge": 300.0},
	}
	factions["red"] = {
		"name": "Rote Allianz", "color": Color(0.88, 0.16, 0.12), "uses_power": true,
		"desc": "Masse statt Klasse. Billige Infanterie, schwere Panzer, Flammenwerfer, Atomwaffe.",
		"perks": [
			"Massenaushebung: Die Kaserne bildet Infanterie immer paarweise aus.",
			"Hordenbonus: +33 % Feuerrate ab vier Kameraden in der Nähe.",
			"Volksarmee: Einheiten werden 50 % schneller befördert.",
			"Propaganda: Das Propagandazentrum heilt Einheiten im Umkreis und erhöht ihre Feuerrate.",
		],
		"powers": [
			{"id": "barrage", "name": "Artilleriesperrfeuer", "desc": "20 Granaten schlagen im Zielgebiet ein.", "cooldown": 150.0, "radius": 13.0, "value": 160.0},
			{"id": "cash", "name": "Staatsreserve", "desc": "Sofort 2000 Credits aus der Staatskasse.", "cooldown": 240.0, "value": 2000.0},
			{"id": "paradrop", "name": "Volksmiliz", "desc": "Acht Grenadiere erscheinen am Zielort.", "cooldown": 150.0, "unit": "red_inf", "count": 8},
		],
		"super": {"name": "Atomsilo", "type": "nuke", "radius": 20.0, "dmg": 3600.0, "charge": 320.0},
	}
	factions["shadow"] = {
		"name": "Schattenfront", "color": Color(0.85, 0.62, 0.15), "uses_power": false,
		"desc": "Guerilla ohne Stromnetz. Schnelle Buggys, Gift und Hinterhalte.",
		"perks": [
			"Tarnung: Infanterie wird unsichtbar, wenn sie 2 s stillsteht – bis sie schießt oder Feinde ganz nah sind.",
			"Schrottbergung: Fahrzeuge rüsten sich mit Wrackteilen auf (bis Stufe 3: mehr Schaden und Panzerung).",
			"Kopfgeld: 20 % des Werts jedes Abschusses als Credits.",
			"Kein Strom nötig, Fahrzeuge reparieren sich selbst. Neuer Sprengwagen.",
		],
		"powers": [
			{"id": "toxin_cloud", "name": "Giftnebel", "desc": "Eine Giftwolke vergiftet das Gebiet 15 Sekunden lang.", "cooldown": 150.0, "radius": 11.0, "value": 40.0},
			{"id": "heal_all", "name": "Feldreparatur", "desc": "Alle eigenen Einheiten werden voll repariert.", "cooldown": 200.0},
			{"id": "paradrop", "name": "Hinterhalt", "desc": "Acht Rebellen tauchen am Zielort auf.", "cooldown": 150.0, "unit": "shadow_inf", "count": 8},
		],
		"super": {"name": "Giftraketen-Silo", "type": "toxin_salvo", "radius": 18.0, "dmg": 2600.0, "charge": 280.0},
	}

func _west() -> void:
	U("west_dozer", {"name": "Baudrohne", "cost": 800, "time": 8.0, "hp": 260.0, "speed": 9.0, "role": "dozer", "model": "builddrone", "built_at": "hq", "sight": 16.0, "armor": "air", "flying": true, "desc": "Fliegende Baudrohne: baut und repariert über jedes Gelände hinweg."})
	U("west_drone", {"name": "Spähdrohne", "cost": 300, "time": 5.0, "hp": 120.0, "speed": 15.0, "armor": "air", "flying": true, "model": "drone", "built_at": "factory", "sight": 34.0, "desc": "Unbewaffneter Aufklärer mit riesiger Sichtweite."})
	U("west_harv", {"name": "Logistik-Lkw", "cost": 600, "time": 8.0, "hp": 380.0, "speed": 7.5, "role": "harvester", "model": "truck", "built_at": "supply", "cargo": 300, "desc": "Holt Nachschub aus Depots."})
	U("west_inf", {"name": "Marinesoldat", "cost": 150, "time": 4.0, "hp": 120.0, "speed": 4.6, "armor": "inf", "model": "inf", "built_at": "barracks",
		"weapon": W("bullet", 10.0, 14.0, 0.5), "desc": "Gut gegen Infanterie."})
	U("west_at", {"name": "Panzerjäger", "cost": 300, "time": 6.0, "hp": 110.0, "speed": 4.3, "armor": "inf", "model": "inf_at", "built_at": "barracks",
		"weapon": W("rocket", 42.0, 17.0, 2.2, {"air": true}), "desc": "Raketen gegen Fahrzeuge und Luft."})
	U("west_tank", {"name": "Falke-Kampfpanzer", "cost": 850, "time": 10.0, "hp": 610.0, "speed": 6.6, "armor": "heavy", "model": "tank", "built_at": "factory",
		"weapon": W("shell", 62.0, 18.0, 2.0, {"splash": 1.5}), "prereq": [], "desc": "Rückgrat der Panzertruppe."})
	U("west_aa", {"name": "Hornet-Flakwagen", "cost": 700, "time": 8.0, "hp": 300.0, "speed": 8.8, "model": "aa", "built_at": "factory",
		"weapon": W("flak", 14.0, 22.0, 0.25, {"air": true}), "desc": "Zerlegt Luftziele und Infanterie."})
	U("west_arty", {"name": "Lanzen-Raketenwerfer", "cost": 1200, "time": 14.0, "hp": 260.0, "speed": 5.6, "model": "rocketlauncher", "built_at": "factory",
		"weapon": W("artillery", 55.0, 44.0, 6.0, {"splash": 5.0, "burst": 4, "min_range": 9.0}), "prereq": ["tech"], "desc": "Weitreichende Raketenartillerie."})
	U("west_laser", {"name": "Bastion-Laserpanzer", "cost": 1500, "time": 16.0, "hp": 830.0, "speed": 5.6, "armor": "heavy", "model": "laser_tank", "built_at": "factory", "scale": 1.15,
		"weapon": W("laser", 78.0, 20.0, 1.6, {"air": true}), "prereq": ["tech"], "desc": "Laser trifft alles, auch Luftziele."})
	U("west_heli", {"name": "Sperber-Kampfheli", "cost": 1500, "time": 14.0, "hp": 380.0, "speed": 13.0, "armor": "air", "flying": true, "model": "heli", "built_at": "airfield", "sight": 22.0,
		"weapon": W("rocket", 34.0, 18.0, 1.1, {"burst": 2}), "desc": "Schneller Jäger für Bodenziele."})

	U("west_jet", {"name": "Lanze-Jäger", "cost": 1300, "time": 13.0, "hp": 300.0, "speed": 17.0, "armor": "air", "flying": true, "model": "jet", "built_at": "airfield", "sight": 24.0,
		"fixed_wing": true, "turn": 1.5, "weapon": W("rocket", 32.0, 24.0, 1.8, {"air": true, "burst": 2}), "desc": "Schneller Jagdflieger mit Lenkraketen gegen Luft- und Bodenziele. Kann nicht schweben und fliegt Angriffsschleifen."})
	U("west_bomber", {"name": "Aegis-Tarnkappenbomber", "cost": 2400, "time": 20.0, "hp": 520.0, "speed": 12.0, "armor": "air", "flying": true, "model": "bomber", "built_at": "airfield", "sight": 22.0, "scale": 1.0,
		"fixed_wing": true, "turn": 0.8, "prereq": ["tech"], "weapon": W("bomb", 140.0, 7.0, 4.5, {"splash": 5.0, "burst": 4}), "desc": "Fliegender Flügel mit Bombenschacht. Verheerend gegen Bodenziele und Gebäude, bekämpft keine Luftziele."})
	U("west_corvette", {"name": "Sentinel-Korvette", "cost": 900, "time": 10.0, "hp": 520.0, "speed": 9.5, "armor": "light", "model": "corvette", "naval": true, "built_at": "dock", "sight": 26.0,
		"weapon": W("rocket", 30.0, 24.0, 1.3, {"air": true, "burst": 2}), "desc": "Schnelles Raketenschiff mit Schildgenerator. Jagt Boote und Flugzeuge, kann auch Küstenziele beschießen."})
	U("west_cruiser", {"name": "Aegis-Kreuzer", "cost": 1800, "time": 18.0, "hp": 1100.0, "speed": 6.0, "armor": "heavy", "model": "cruiser", "naval": true, "built_at": "dock", "sight": 28.0, "scale": 1.15,
		"weapon": W("artillery", 62.0, 52.0, 4.5, {"splash": 4.0, "burst": 2, "min_range": 12.0}), "prereq": ["tech"], "desc": "Lenkwaffenkreuzer mit Senkrechtstartern. Beschießt Basen weit vom Wasser aus."})
	B("west_dock", {"name": "Marinewerft", "cost": 1300, "time": 18.0, "hp": 1500.0, "size": 4, "power": -2, "produces": ["west_corvette", "west_cruiser"], "prereq": ["factory"], "desc": "Muss am Ufer stehen. Baut Kriegsschiffe."})
	B("west_hq", {"name": "Kommandozentrale", "cost": 2500, "time": 40.0, "hp": 3200.0, "size": 5, "power": 5, "produces": ["west_dozer"], "sight": 24.0, "desc": "Herz der Basis. Baut Baudrohnen."})
	B("west_power", {"name": "Fusionsreaktor", "cost": 800, "time": 12.0, "hp": 900.0, "power": 10, "desc": "Liefert 10 Strom."})
	B("west_supply", {"name": "Nachschubzentrum", "cost": 1500, "time": 15.0, "hp": 1500.0, "power": -1, "produces": ["west_harv"], "desc": "Lager für Nachschub. Liefert einen Lkw mit."})
	B("west_barracks", {"name": "Kaserne", "cost": 500, "time": 10.0, "hp": 1100.0, "power": -1, "produces": ["west_inf", "west_at"], "prereq": ["power"], "desc": "Bildet Infanterie aus."})
	B("west_factory", {"name": "Waffenfabrik", "cost": 2000, "time": 20.0, "hp": 2000.0, "size": 5, "power": -2, "produces": ["west_drone", "west_tank", "west_aa", "west_arty", "west_laser"], "prereq": ["supply", "barracks"], "desc": "Produziert Fahrzeuge."})
	B("west_airfield", {"name": "Flugfeld", "cost": 1000, "time": 16.0, "hp": 1500.0, "size": 5, "power": -2, "produces": ["west_heli", "west_jet", "west_bomber"], "prereq": ["factory"], "desc": "Startplatz für Kampfhubschrauber."})
	B("west_defense", {"name": "Patriot-Batterie", "cost": 1000, "time": 12.0, "hp": 1300.0, "power": -2, "prereq": ["barracks"], "sight": 26.0,
		"weapon": W("rocket", 46.0, 26.0, 1.4, {"air": true, "burst": 2}), "desc": "Raketenabwehr gegen Boden- und Luftziele. Braucht Strom."})
	B("west_tech", {"name": "Forschungszentrum", "cost": 2000, "time": 25.0, "hp": 1500.0, "power": -3, "prereq": ["factory"], "desc": "Schaltet Artillerie, Laserpanzer und Superwaffe frei."})
	B("west_super", {"name": "Orbitalkanone", "cost": 5000, "time": 60.0, "hp": 3000.0, "size": 5, "power": -6, "prereq": ["tech"], "desc": "Superwaffe: Laserstrahl aus dem Orbit."})

func _red() -> void:
	U("red_dozer", {"name": "Bautraktor", "cost": 800, "time": 8.0, "hp": 320.0, "speed": 6.5, "role": "dozer", "model": "dozer", "built_at": "hq", "sight": 14.0, "desc": "Errichtet und repariert Gebäude."})
	U("red_harv", {"name": "Nachschub-Lkw", "cost": 600, "time": 8.0, "hp": 420.0, "speed": 7.0, "role": "harvester", "model": "truck", "built_at": "supply", "cargo": 300, "desc": "Holt Nachschub aus Depots."})
	U("red_inf", {"name": "Volksgrenadier", "cost": 170, "time": 4.0, "hp": 110.0, "speed": 4.5, "armor": "inf", "model": "inf", "built_at": "barracks", "horde": true,
		"weapon": W("bullet", 8.0, 13.0, 0.55), "desc": "Kommt immer zu zweit. Hordenbonus ab vier Kameraden in der Nähe."})
	U("red_at", {"name": "Panzerfaust-Trupp", "cost": 480, "time": 7.0, "hp": 120.0, "speed": 4.3, "armor": "inf", "model": "inf_at", "built_at": "barracks", "horde": true,
		"weapon": W("rocket", 38.0, 16.0, 2.3, {"air": true}), "desc": "Raketen gegen Fahrzeuge und Luft."})
	U("red_tank", {"name": "Bär-Kampfpanzer", "cost": 800, "time": 10.0, "hp": 600.0, "speed": 6.0, "armor": "heavy", "model": "tank", "built_at": "factory",
		"weapon": W("shell", 56.0, 17.0, 2.0, {"splash": 1.5}), "desc": "Robuster Standardpanzer."})
	U("red_flame", {"name": "Drache-Flammpanzer", "cost": 800, "time": 10.0, "hp": 460.0, "speed": 6.2, "armor": "heavy", "model": "flame_tank", "built_at": "factory",
		"weapon": W("flame", 24.0, 10.0, 0.4, {"splash": 3.0}), "desc": "Verbrennt Infanterie und Gebäude."})
	U("red_aa", {"name": "Gatling-Flakpanzer", "cost": 850, "time": 9.0, "hp": 420.0, "speed": 6.4, "armor": "heavy", "model": "aa", "built_at": "factory",
		"weapon": W("flak", 12.0, 20.0, 0.18, {"air": true}), "desc": "Durchlöchert Luftziele und Infanterie."})
	U("red_arty", {"name": "Sturm-Haubitze", "cost": 1100, "time": 14.0, "hp": 290.0, "speed": 5.2, "model": "artillery", "built_at": "factory",
		"weapon": W("artillery", 85.0, 46.0, 5.0, {"splash": 5.0, "min_range": 10.0}), "prereq": ["tech"], "desc": "Schwere Artillerie mit großer Reichweite."})
	U("red_heavy", {"name": "Koloss-Panzer", "cost": 2000, "time": 20.0, "hp": 1500.0, "speed": 4.3, "armor": "heavy", "model": "heavy_tank", "built_at": "factory", "scale": 1.5,
		"weapon": W("shell", 90.0, 19.0, 2.2, {"splash": 2.0, "burst": 2}), "prereq": ["tech"], "desc": "Rollende Festung mit Doppelkanone."})
	U("red_heli", {"name": "Taifun-Kampfheli", "cost": 1400, "time": 14.0, "hp": 430.0, "speed": 11.5, "armor": "air", "flying": true, "model": "heli", "built_at": "airfield", "sight": 22.0,
		"weapon": W("bullet", 16.0, 16.0, 0.2), "desc": "Gatling-Hubschrauber gegen Infanterie und leichte Ziele."})

	U("red_jet", {"name": "Sturm-Abfangjäger", "cost": 1200, "time": 12.0, "hp": 340.0, "speed": 16.0, "armor": "air", "flying": true, "model": "jet", "built_at": "airfield", "sight": 22.0,
		"fixed_wing": true, "turn": 1.4, "weapon": W("bullet", 14.0, 20.0, 0.2, {"air": true}), "desc": "Robuster Abfangjäger mit Bordkanonen gegen Luft und Boden. Kann nicht schweben."})
	U("red_bomber", {"name": "Bär-Bomber", "cost": 2500, "time": 22.0, "hp": 700.0, "speed": 9.5, "armor": "air", "flying": true, "model": "bomber", "built_at": "airfield", "sight": 22.0, "scale": 1.15,
		"fixed_wing": true, "turn": 0.6, "prereq": ["tech"], "weapon": W("bomb", 170.0, 7.0, 5.0, {"splash": 5.5, "burst": 5}), "desc": "Schwerer viermotoriger Bomber mit Teppichabwurf. Langsam, zäh und vernichtend."})
	U("red_gunboat", {"name": "Sturm-Kanonenboot", "cost": 700, "time": 9.0, "hp": 450.0, "speed": 9.0, "armor": "light", "model": "gunboat", "naval": true, "built_at": "dock", "sight": 24.0,
		"weapon": W("shell", 42.0, 21.0, 1.6, {"splash": 1.2}), "desc": "Gepanzertes Kanonenboot. Billig, robust, gut gegen Küstenfahrzeuge."})
	U("red_speedboat", {"name": "Raketen-Schnellboot", "cost": 600, "time": 7.0, "hp": 230.0, "speed": 14.5, "armor": "light", "model": "speedboat", "naval": true, "built_at": "dock", "sight": 24.0,
		"weapon": W("rocket", 38.0, 22.0, 1.7, {"splash": 1.4, "burst": 2}), "desc": "Flaches Schnellboot mit Torpedorohren und Raketenpaar. Sehr schnell, aber zerbrechlich: jagt Schiffe und Küstenfahrzeuge."})
	U("red_battleship", {"name": "Oktober-Schlachtkreuzer", "cost": 2200, "time": 22.0, "hp": 1900.0, "speed": 5.0, "armor": "heavy", "model": "battleship", "naval": true, "built_at": "dock", "sight": 28.0, "scale": 1.3,
		"weapon": W("artillery", 95.0, 56.0, 4.5, {"splash": 5.5, "burst": 2, "min_range": 14.0}), "prereq": ["tech"], "desc": "Schwimmende Festung mit Doppelgeschützen. Zerlegt Gebäude aus großer Distanz."})
	B("red_dock", {"name": "Schiffswerft", "cost": 1300, "time": 18.0, "hp": 1700.0, "size": 4, "power": -2, "produces": ["red_gunboat", "red_speedboat", "red_battleship"], "prereq": ["factory"], "desc": "Muss am Ufer stehen. Baut Kriegsschiffe."})
	B("red_hq", {"name": "Hauptquartier", "cost": 2500, "time": 40.0, "hp": 3600.0, "size": 5, "power": 5, "produces": ["red_dozer"], "sight": 24.0, "desc": "Herz der Basis. Baut Bautraktoren."})
	B("red_power", {"name": "Kohlekraftwerk", "cost": 800, "time": 12.0, "hp": 1000.0, "power": 10, "desc": "Liefert 10 Strom."})
	B("red_supply", {"name": "Versorgungsdepot", "cost": 1500, "time": 15.0, "hp": 1600.0, "power": -1, "produces": ["red_harv"], "desc": "Lager für Nachschub. Liefert einen Lkw mit."})
	B("red_barracks", {"name": "Kaserne", "cost": 500, "time": 10.0, "hp": 1200.0, "power": -1, "produces": ["red_inf", "red_at"], "prereq": ["power"], "desc": "Bildet Infanterie aus."})
	B("red_factory", {"name": "Panzerwerk", "cost": 2000, "time": 20.0, "hp": 2200.0, "size": 5, "power": -2, "produces": ["red_tank", "red_flame", "red_aa", "red_arty", "red_heavy"], "prereq": ["supply", "barracks"], "desc": "Produziert Fahrzeuge."})
	B("red_airfield", {"name": "Hubschrauberbasis", "cost": 1000, "time": 16.0, "hp": 1500.0, "size": 5, "power": -2, "produces": ["red_heli", "red_jet", "red_bomber"], "prereq": ["factory"], "desc": "Startplatz für Kampfhubschrauber."})
	B("red_defense", {"name": "Gatling-Bunker", "cost": 1000, "time": 12.0, "hp": 1600.0, "power": -2, "prereq": ["barracks"], "sight": 24.0,
		"weapon": W("gatling", 12.0, 22.0, 0.15, {"air": true}), "desc": "Gatling gegen Infanterie, Luftziele und leichte Fahrzeuge, auch gegen Panzer wirksam. Braucht Strom."})
	B("red_tech", {"name": "Propagandazentrum", "cost": 2000, "time": 25.0, "hp": 1600.0, "power": -3, "prereq": ["factory"], "aura": 28.0, "desc": "Propaganda-Aura: heilt eigene Einheiten im Umkreis und erhöht ihre Feuerrate. Schaltet Haubitze, Koloss und Superwaffe frei."})
	B("red_super", {"name": "Atomsilo", "cost": 5000, "time": 60.0, "hp": 3200.0, "size": 5, "power": -6, "prereq": ["tech"], "desc": "Superwaffe: Atomrakete."})

func _shadow() -> void:
	U("shadow_dozer", {"name": "Arbeiter", "cost": 250, "time": 4.0, "hp": 90.0, "speed": 5.0, "armor": "inf", "role": "dozer", "model": "worker", "built_at": "hq", "sight": 12.0, "desc": "Errichtet und repariert Gebäude."})
	U("shadow_harv", {"name": "Sammler-Pickup", "cost": 500, "time": 7.0, "hp": 300.0, "speed": 8.5, "role": "harvester", "model": "truck", "built_at": "supply", "cargo": 250, "desc": "Holt Nachschub aus Depots."})
	U("shadow_inf", {"name": "Rebell", "cost": 150, "time": 4.0, "hp": 110.0, "speed": 5.0, "armor": "inf", "model": "inf", "built_at": "barracks",
		"weapon": W("bullet", 10.0, 14.0, 0.5), "desc": "Schnelle Infanterie."})
	U("shadow_at", {"name": "RPG-Kämpfer", "cost": 300, "time": 6.0, "hp": 100.0, "speed": 4.8, "armor": "inf", "model": "inf_at", "built_at": "barracks",
		"weapon": W("rocket", 40.0, 16.0, 2.2, {"air": true}), "desc": "Raketen gegen Fahrzeuge und Luft."})
	U("shadow_tech", {"name": "Technical", "cost": 500, "time": 6.0, "hp": 280.0, "speed": 10.5, "model": "technical", "built_at": "factory",
		"weapon": W("bullet", 13.0, 16.0, 0.3), "desc": "Pickup mit MG. Billig und schnell."})
	U("shadow_buggy", {"name": "Raketenbuggy", "cost": 900, "time": 9.0, "hp": 220.0, "speed": 11.5, "model": "buggy", "built_at": "factory",
		"weapon": W("rocket", 30.0, 27.0, 3.0, {"burst": 3, "splash": 1.5}), "desc": "Raketensalven auf große Distanz."})
	U("shadow_tank", {"name": "Skorpion", "cost": 700, "time": 9.0, "hp": 430.0, "speed": 7.2, "armor": "heavy", "model": "scorpion", "built_at": "factory",
		"weapon": W("shell", 46.0, 16.0, 1.8, {"splash": 1.2}), "desc": "Leichter, wendiger Panzer."})
	U("shadow_toxin", {"name": "Toxinlaster", "cost": 700, "time": 8.0, "hp": 320.0, "speed": 7.5, "model": "toxin_truck", "built_at": "factory",
		"weapon": W("toxin", 18.0, 9.0, 0.4, {"splash": 3.5}), "desc": "Gift gegen Infanterie."})
	U("shadow_aa", {"name": "Flak-Pickup", "cost": 600, "time": 7.0, "hp": 260.0, "speed": 10.0, "model": "technical_aa", "built_at": "factory",
		"weapon": W("flak", 12.0, 21.0, 0.22, {"air": true}), "desc": "Mobile Flak."})
	U("shadow_arty", {"name": "Bombardier", "cost": 1300, "time": 15.0, "hp": 300.0, "speed": 5.6, "model": "scud", "built_at": "factory",
		"weapon": W("artillery", 140.0, 50.0, 9.0, {"splash": 7.0, "min_range": 12.0}), "prereq": ["tech"], "desc": "Giftrakete mit riesiger Reichweite."})

	U("shadow_glider", {"name": "Schrott-Gleiter", "cost": 550, "time": 7.0, "hp": 170.0, "speed": 13.0, "armor": "air", "flying": true, "model": "glider", "built_at": "airfield", "sight": 20.0,
		"fixed_wing": true, "turn": 1.9, "weapon": W("bullet", 10.0, 15.0, 0.22, {"air": true}), "desc": "Billiger Ultraleichtflieger mit MG. Wendig, aber zerbrechlich."})
	U("shadow_sprayer", {"name": "Giftsprüher", "cost": 1100, "time": 11.0, "hp": 300.0, "speed": 10.0, "armor": "air", "flying": true, "model": "sprayer", "built_at": "airfield", "sight": 20.0,
		"fixed_wing": true, "turn": 1.2, "weapon": W("toxin", 20.0, 5.5, 0.4, {"splash": 4.0}), "desc": "Doppeldecker, der Gift auf Bodentruppen sprüht. Tödlich gegen Infanterie."})
	U("shadow_skiff", {"name": "Schmuggler-Kutter", "cost": 500, "time": 6.0, "hp": 280.0, "speed": 11.5, "armor": "light", "model": "skiff", "naval": true, "built_at": "dock", "sight": 24.0,
		"weapon": W("bullet", 12.0, 16.0, 0.3, {"air": true}), "desc": "Schneller Kutter mit Bord-MG. Billig, wendig und bei Überfällen kaum zu fassen."})
	U("shadow_jetski", {"name": "Jetski-Räuber", "cost": 250, "time": 4.0, "hp": 110.0, "speed": 16.5, "armor": "light", "model": "jetski", "naval": true, "built_at": "dock", "sight": 22.0,
		"weapon": W("bullet", 8.0, 14.0, 0.25, {"air": true}), "desc": "Geschrotteter Wasserroller mit MG. Winzig, billig und rasend schnell: Schwärme zerlegen Nachschub und Bautrupps am Ufer."})
	U("shadow_frigate", {"name": "Piraten-Fregatte", "cost": 1500, "time": 15.0, "hp": 900.0, "speed": 6.5, "armor": "heavy", "model": "frigate", "naval": true, "built_at": "dock", "sight": 26.0, "scale": 1.1,
		"weapon": W("rocket", 46.0, 30.0, 2.6, {"splash": 2.5, "burst": 4}), "prereq": ["tech"], "desc": "Zusammengeschweißte Raketenfregatte. Feuert Salven auf alles, was sich am Ufer bewegt."})
	B("shadow_dock", {"name": "Schmugglerhafen", "cost": 1200, "time": 16.0, "hp": 1300.0, "size": 4, "produces": ["shadow_skiff", "shadow_jetski", "shadow_frigate"], "prereq": ["factory"], "desc": "Muss am Ufer stehen. Baut Schiffe aus Schrott und Beutegut."})
	B("shadow_hq", {"name": "Versteck", "cost": 2000, "time": 35.0, "hp": 3000.0, "size": 5, "produces": ["shadow_dozer"], "sight": 24.0, "desc": "Herz der Basis. Bildet Arbeiter aus."})
	B("shadow_supply", {"name": "Umschlagplatz", "cost": 1500, "time": 15.0, "hp": 1300.0, "produces": ["shadow_harv"], "desc": "Lager für Nachschub. Liefert einen Pickup mit."})
	B("shadow_barracks", {"name": "Ausbildungslager", "cost": 500, "time": 10.0, "hp": 1000.0, "produces": ["shadow_inf", "shadow_at"], "desc": "Bildet Kämpfer aus."})
	B("shadow_factory", {"name": "Schrottwerkstatt", "cost": 2000, "time": 20.0, "hp": 1800.0, "size": 5, "produces": ["shadow_tech", "shadow_buggy", "shadow_tank", "shadow_toxin", "shadow_bomb", "shadow_aa", "shadow_arty"], "prereq": ["supply", "barracks"], "desc": "Schweißt Fahrzeuge zusammen."})
	B("shadow_airfield", {"name": "Schotterpiste", "cost": 1200, "time": 14.0, "hp": 1100.0, "size": 5, "produces": ["shadow_glider", "shadow_sprayer"], "prereq": ["factory"], "desc": "Provisorische Startbahn für Ultraleichtflieger und Sprühflugzeuge."})
	B("shadow_defense", {"name": "Stinger-Stellung", "cost": 900, "time": 12.0, "hp": 1100.0, "prereq": ["barracks"], "sight": 24.0,
		"weapon": W("rocket", 36.0, 24.0, 1.2, {"air": true, "burst": 2}), "desc": "Raketen gegen Boden- und Luftziele."})
	B("shadow_tech", {"name": "Schwarzmarkt", "cost": 2000, "time": 25.0, "hp": 1400.0, "prereq": ["factory"], "desc": "Schaltet Bombardier und Superwaffe frei. Bringt 30 Credits alle 10 s."})
	B("shadow_super", {"name": "Giftraketen-Silo", "cost": 5000, "time": 60.0, "hp": 2800.0, "size": 5, "prereq": ["tech"], "desc": "Superwaffe: Salve aus Giftraketen."})

## Bau-Liste für den Baumeister einer Fraktion.
## Fraktionseigenschaften auf die Einheiten verteilen.
func _faction_traits() -> void:
	U("shadow_bomb", {"name": "Sprengwagen", "cost": 600, "time": 7.0, "hp": 240.0, "speed": 10.0, "model": "bombtruck", "built_at": "factory",
		"weapon": W("demolition", 900.0, 2.5, 1.0, {"splash": 8.0}), "desc": "Fährt ins Ziel und sprengt sich in die Luft. Verheerend gegen Gebäude."})
	for id in units:
		var u: Dictionary = units[id]
		var vehicle: bool = u["armor"] != "inf"
		if u["faction"] == "west" and vehicle and u["role"] == "combat" and u["weapon"] != null:
			u["shield"] = float(u["hp"]) * 0.35
		if u["faction"] == "red" and u["built_at"] == "barracks":
			u["pair"] = true
		if u["faction"] == "shadow" and not vehicle and u["role"] == "combat":
			u["stealth"] = true
		if u["faction"] == "shadow" and vehicle and u["role"] == "combat":
			u["salvage"] = true

## Rohstoffe neben Credits: Holz, Eisen, Öl, Gold; Stahl entsteht im Nachschubgebäude aus Eisen und Öl.
const RES_KINDS := ["wood", "iron", "oil", "gold", "steel"]
const RES_NAMES := {"wood": "Holz", "iron": "Eisen", "oil": "Öl", "gold": "Gold", "steel": "Stahl", "supply": "Nachschub"}
const RES_COLORS := {"wood": Color(0.62, 0.42, 0.22), "iron": Color(0.62, 0.66, 0.72), "oil": Color(0.5, 0.5, 0.64), "gold": Color(1.0, 0.82, 0.25), "steel": Color(0.55, 0.78, 0.95), "supply": Color(1.0, 0.86, 0.4)}
const START_RES := {"wood": 220.0, "iron": 160.0, "oil": 110.0, "gold": 40.0, "steel": 120.0}

## Ergänzt jede Einheit/jedes Gebäude um Rohstoffkosten nach einfachen Regeln.
func _resource_costs() -> void:
	for id in buildings:
		var b: Dictionary = buildings[id]
		var c: float = b["cost"]
		var r = {}
		if b["role"] != "hq":
			r["wood"] = round(c * 0.02 / 5.0) * 5.0
		if b["role"] in ["factory", "airfield", "dock", "tech", "defense", "super"]:
			r["steel"] = round(c * 0.025 / 5.0) * 5.0
		if b["role"] == "tech":
			r["gold"] = 40.0
		if b["role"] == "super":
			r["gold"] = 200.0
		b["res"] = r
	for id in units:
		var u: Dictionary = units[id]
		var c: float = u["cost"]
		var r = {}
		if u["role"] == "combat":
			if c >= 700:
				r["steel"] = round(c * 0.04 / 5.0) * 5.0
			if u["flying"]:
				r["oil"] = round(c * 0.04 / 5.0) * 5.0
			if c >= 1500:
				r["gold"] = round(c * 0.03 / 5.0) * 5.0
		u["res"] = r

func res_text(r: Dictionary) -> String:
	var parts: Array = []
	for k in RES_KINDS:
		if r.has(k) and r[k] > 0.0:
			parts.append("%d %s" % [int(r[k]), RES_NAMES[k]])
	return ", ".join(parts)

func build_list(faction: String) -> Array:
	var out = []
	for r in ["power", "supply", "barracks", "factory", "airfield", "dock", "defense", "tech", "super", "hq"]:
		var id: String = faction + "_" + r
		if buildings.has(id):
			out.append(id)
	return out

func dozer_of(faction: String) -> String:
	return faction + "_dozer"

func harv_of(faction: String) -> String:
	return faction + "_harv"
