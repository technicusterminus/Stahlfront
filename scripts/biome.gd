extends RefCounted
## Biome: Landschaftsprägung einer Karte (Bodenfarben, Gras, Baumart, Schneegrenze, Tierwelt).
## Auswahl über den Kartenschlüssel "biome"; "" ist die gemäßigte Standardlandschaft.
##
## Felder:
##   grass_a/grass_b  Bodenfarben im Gelände-Shader (dunkel/hell); null = Standard
##   blade            Grasfarbe der Halme, blade_amt wie stark sie die Zonenfarbe überlagert
##   grass_dens       Faktor für die Dichte des Grases
##   conifer          Anteil Nadelbäume (0..1); -1 = nach Höhe und Rauschen wie bisher
##   trees            Faktor für die Baumdichte
##   leaf             Laubfarbe der Laubbäume, leaf_amt Stärke; dead = Anteil kahler Bäume
##   snow_y           Höhe, ab der Schnee liegt (999 = nie)
##   rocks            Faktor für die Felsmenge
##   fauna            Tierherden: Art -> Anzahl; birds: Vogelschwärme: Art -> Anzahl

const TABLE := {
	"": {},
	"alpine": {
		"grass_a": Color(0.09, 0.15, 0.08), "grass_b": Color(0.20, 0.27, 0.15),
		"blade": Color(0.42, 0.58, 0.40), "blade_amt": 0.45, "grass_dens": 0.8,
		"conifer": 0.95, "trees": 0.8, "leaf": Color(0.45, 0.5, 0.2), "leaf_amt": 0.5, "dead": 0.0,
		"snow_y": 6.5, "rocks": 1.6,
		"fauna": {"goat": 5, "deer": 2}, "birds": {"eagle": 2, "crow": 1},
	},
	"steppe": {
		"grass_a": Color(0.30, 0.27, 0.12), "grass_b": Color(0.55, 0.47, 0.24),
		"blade": Color(0.92, 0.80, 0.44), "blade_amt": 0.7, "grass_dens": 1.15,
		"conifer": 0.15, "trees": 0.25, "leaf": Color(0.55, 0.5, 0.2), "leaf_amt": 0.5, "dead": 0.15,
		"snow_y": 999.0, "rocks": 0.7,
		"fauna": {"deer": 5, "boar": 2}, "birds": {"eagle": 1, "crow": 2},
	},
	"boreal": {
		"grass_a": Color(0.05, 0.10, 0.06), "grass_b": Color(0.13, 0.19, 0.10),
		"blade": Color(0.30, 0.46, 0.30), "blade_amt": 0.5, "grass_dens": 0.9,
		"conifer": 1.0, "trees": 1.5, "leaf": Color(0.3, 0.4, 0.2), "leaf_amt": 0.4, "dead": 0.0,
		"snow_y": 999.0, "rocks": 1.0,
		"fauna": {"deer": 5, "boar": 3}, "birds": {"crow": 3, "eagle": 1},
	},
	"marsh": {
		"grass_a": Color(0.11, 0.15, 0.07), "grass_b": Color(0.24, 0.27, 0.12),
		"blade": Color(0.5, 0.58, 0.28), "blade_amt": 0.5, "grass_dens": 1.1,
		"conifer": 0.1, "trees": 0.6, "leaf": Color(0.35, 0.42, 0.15), "leaf_amt": 0.5, "dead": 0.25,
		"snow_y": 999.0, "rocks": 0.5,
		"fauna": {"boar": 4, "deer": 3}, "birds": {"duck": 4, "crow": 1},
	},
	"coast": {
		"grass_a": Color(0.13, 0.19, 0.07), "grass_b": Color(0.28, 0.34, 0.12),
		"blade": Color(0.55, 0.75, 0.38), "blade_amt": 0.35, "grass_dens": 0.9,
		"conifer": 0.1, "trees": 0.6, "leaf": Color(0.3, 0.5, 0.18), "leaf_amt": 0.4, "dead": 0.0,
		"snow_y": 999.0, "rocks": 0.8,
		"fauna": {"deer": 3}, "birds": {"gull": 5, "duck": 2},
	},
	"ashland": {
		"grass_a": Color(0.13, 0.12, 0.11), "grass_b": Color(0.28, 0.26, 0.23),
		"blade": Color(0.5, 0.47, 0.38), "blade_amt": 0.75, "grass_dens": 0.55,
		"conifer": 0.3, "trees": 0.45, "leaf": Color(0.35, 0.3, 0.2), "leaf_amt": 0.7, "dead": 0.7,
		"snow_y": 999.0, "rocks": 1.4,
		"fauna": {"boar": 3}, "birds": {"crow": 5},
	},
	"highland": {
		"grass_a": Color(0.15, 0.12, 0.13), "grass_b": Color(0.30, 0.23, 0.26),
		"blade": Color(0.55, 0.42, 0.5), "blade_amt": 0.45, "grass_dens": 0.85,
		"conifer": 0.6, "trees": 0.55, "leaf": Color(0.4, 0.38, 0.2), "leaf_amt": 0.4, "dead": 0.1,
		"snow_y": 11.0, "rocks": 1.8,
		"fauna": {"goat": 6, "deer": 2}, "birds": {"eagle": 2, "crow": 2},
	},
}

static func get_biome(name: String) -> Dictionary:
	return TABLE.get(name, {})

static func of(t) -> Dictionary:
	return get_biome(String(t.spec.get("biome", "")))
