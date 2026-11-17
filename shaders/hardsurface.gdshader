shader_type spatial;
// Hard-Surface-Material fuer Einheiten und Gebaeude: triplanar im Objektraum,
// Tarnmuster, Blechfugen, Nieten, Rost, Schmutz, Koernung, Mikro-Normalen.

uniform sampler2D camo : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D grime : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_n : hint_normal, repeat_enable, filter_linear_mipmap;
uniform bool use_camo = true;
uniform vec3 base_col : source_color = vec3(0.5);
uniform float camo_scale = 0.12;
uniform float panel_scale = 1.2;
uniform float panel_width = 0.03;
uniform float rivet = 0.0;
uniform float rust = 0.2;
uniform vec3 rust_col : source_color = vec3(0.32, 0.16, 0.07);
uniform float dirt = 0.4;
uniform float grain = 0.18;
uniform float metallic_v = 0.4;
uniform float rough_v = 0.5;
uniform float normal_depth = 0.8;
uniform float detail_scale = 1.6;

varying vec3 opos;
varying vec3 onrm;

vec3 triw(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z + 1e-5);
}
vec4 tri_c(vec3 p, vec3 n, float s) {
	vec3 w = triw(n);
	return texture(camo, p.zy * s) * w.x + texture(camo, p.xz * s) * w.y + texture(camo, p.xy * s) * w.z;
}
vec4 tri_g(vec3 p, vec3 n, float s) {
	vec3 w = triw(n);
	return texture(grime, p.zy * s) * w.x + texture(grime, p.xz * s) * w.y + texture(grime, p.xy * s) * w.z;
}
vec4 tri_n(vec3 p, vec3 n, float s) {
	vec3 w = triw(n);
	return texture(detail_n, p.zy * s) * w.x + texture(detail_n, p.xz * s) * w.y + texture(detail_n, p.xy * s) * w.z;
}

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(onrm);
	vec3 an = abs(n);
	vec3 col = use_camo ? tri_c(opos, n, camo_scale).rgb : base_col;

	float g = tri_g(opos, n, 0.35).r;           // grobe Flecken
	float g2 = tri_g(opos * 3.7, n, 1.0).r;     // Koernung
	float g3 = tri_g(opos * vec3(9.0, 1.2, 9.0), n, 1.0).r; // Schlieren nach unten

	// Blechfugen: Linien entlang der beiden Achsen quer zur Flaechennormale
	vec3 c = abs(fract(opos * panel_scale + 0.5) - 0.5) / panel_scale;
	float lx = smoothstep(panel_width, panel_width * 0.35, c.x) * (1.0 - an.x);
	float ly = smoothstep(panel_width, panel_width * 0.35, c.y) * (1.0 - an.y);
	float lz = smoothstep(panel_width, panel_width * 0.35, c.z) * (1.0 - an.z);
	float line = clamp(max(lx, max(ly, lz)), 0.0, 1.0);
	float near_line = clamp(max(smoothstep(panel_width * 5.0, panel_width * 2.0, c.x) * (1.0 - an.x),
		max(smoothstep(panel_width * 5.0, panel_width * 2.0, c.y) * (1.0 - an.y),
			smoothstep(panel_width * 5.0, panel_width * 2.0, c.z) * (1.0 - an.z))), 0.0, 1.0);

	// Nieten entlang der Fugen
	vec3 q = fract(opos * panel_scale * 7.0) - 0.5;
	q -= dot(q, n) * n;
	float rv = rivet * near_line * (1.0 - line) * smoothstep(0.2, 0.12, length(q));

	// Rost: fleckig, entlang der Fugen und als Laufspuren
	float rmask = smoothstep(1.0 - rust, 1.0, g * 0.7 + g2 * 0.3 + near_line * 0.25 + (g3 - 0.5) * 0.3);
	rmask *= clamp(rust * 3.0, 0.0, 1.0);
	// Schmutz: unten mehr, fleckig
	float low = clamp((1.0 - opos.y) / 1.2, 0.0, 1.0);
	float dmask = clamp(low * dirt * (0.6 + g) + (g3 - 0.6) * dirt * 0.8, 0.0, 0.9);

	col *= 1.0 + (g2 - 0.5) * grain * 2.0;
	col = mix(col, rust_col * (0.7 + 0.6 * g2), rmask);
	col = mix(col, vec3(0.15, 0.12, 0.085) * (0.8 + 0.4 * g), dmask);
	col *= 1.0 - line * 0.6;
	col = mix(col, col * 1.35 + 0.04, rv);

	ALBEDO = col;
	METALLIC = metallic_v * (1.0 - rmask) * (1.0 - dmask * 0.7);
	ROUGHNESS = clamp(rough_v + (g2 - 0.5) * 0.25 + rmask * 0.35 + dmask * 0.3 + line * 0.15 - rv * 0.2, 0.05, 1.0);
	NORMAL_MAP = tri_n(opos, n, detail_scale).rgb;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 + rmask * 1.5);
	AO = 1.0 - line * 0.7;
	AO_LIGHT_AFFECT = 0.4;
}
