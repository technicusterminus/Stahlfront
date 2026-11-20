shader_type spatial;
global uniform float world_size;
global uniform float night;
global uniform float wetness;
render_mode specular_schlick_ggx;
// Wasser: Tiefenabsorption, Lichtbrechung, Fresnel-Spiegelung (Himmel + Bildschirmreflexion), Kaustik am Grund,
// Uferschaum aus Bildtextur, Wellenkämme, Regenringe, Sonnenglitzern, Nebel des Krieges.

uniform sampler2D n_ripple : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_swell : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D caus_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.10, 0.38, 0.36);
uniform vec3 deep : source_color = vec3(0.012, 0.05, 0.09);

varying vec3 wpos;
varying float crest;

float fog_at(vec2 uv) {
	vec2 a = texture(fog_tex, uv).rg;
	return mix(mix(0.0, 0.38, a.g), 1.0, smoothstep(0.15, 0.85, a.r));
}

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

// Regentropfen: wachsende Ringe in einem Zellraster
vec2 rain_rings(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	vec2 g = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(g);
	float ph = fract(t * (0.6 + 0.5 * h) + h * 7.0);
	vec2 c = (vec2(hash21(g + 3.1), hash21(g + 7.7)) - 0.5) * 0.6;
	vec2 d = f - c;
	float r = length(d);
	float ring = smoothstep(0.05, 0.0, abs(r - ph * 0.45)) * (1.0 - ph);
	acc += normalize(d + 1e-4) * ring;
	return acc;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(wpos.x * 0.22 + TIME * 0.9) * 0.11;
	float w2 = sin(wpos.z * 0.17 + TIME * 0.75 + wpos.x * 0.05) * 0.10;
	float w3 = sin((wpos.x + wpos.z) * 0.41 + TIME * 1.6) * 0.045;
	crest = w1 + w2 + w3;
	VERTEX.y += crest;
}

void fragment() {
	float vis = fog_at(wpos.xz / world_size + 0.5);
	// Normalen: grosse Duenung, zwei Kräuselschichten in verschiedene Richtungen
	vec3 s = texture(n_swell, wpos.xz * 0.017 + TIME * vec2(0.010, 0.004)).rgb;
	vec3 a = texture(n_ripple, wpos.xz * 0.06 + TIME * vec2(0.014, 0.008)).rgb;
	vec3 b = texture(n_ripple, wpos.xz * 0.13 - TIME * vec2(0.011, 0.016) + 0.37).rgb;
	vec3 nm = normalize(vec3((s.xy - 0.5) * 1.1 + (a.xy - 0.5) * 0.9 + (b.xy - 0.5) * 0.6, 1.0));
	vec2 rr = vec2(0.0);
	if (wetness > 0.05) {
		rr = rain_rings(wpos.xz * 1.6, TIME) + rain_rings(wpos.xz * 2.7 + 11.0, TIME * 1.1);
		nm.xy += rr * 0.55 * wetness;
		nm = normalize(nm);
	}
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.3;

	// Tiefe unter der Wasserflaeche
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float depth_diff = max(VERTEX.z - v.z, 0.0);
	float absorb = 1.0 - exp(-depth_diff * 0.55);
	float t = clamp(depth_diff / 3.0, 0.0, 1.0);

	// Brechung des Untergrunds, mit Verzerrung durch die Wellen
	vec2 off = nm.xy * 0.05 * (1.0 - t * 0.6);
	vec3 behind = texture(screen_tex, clamp(SCREEN_UV + off, vec2(0.002), vec2(0.998))).rgb;
	vec3 water = mix(shallow, deep, absorb);

	// Fresnel (Schlick, F0 = 0.02): Spiegelung steigt zum Horizont
	float cosv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cosv, 5.0);

	// Kaustik: helle Netzlinien auf dem flachen Grund, tagsüber
	vec3 c1 = texture(caus_tex, wpos.xz * 0.09 + TIME * vec2(0.02, 0.013)).rgb;
	vec3 c2 = texture(caus_tex, wpos.xz * 0.075 - TIME * vec2(0.017, 0.021) + 0.5).rgb;
	float caustic = pow(min(c1.g, c2.g), 2.0) * 2.6;
	caustic *= smoothstep(0.04, 0.35, depth_diff) * exp(-depth_diff * 0.7) * (1.0 - night * 0.92);

	// Schaum: Uferlinie pulsiert, Wellenkaemme, Schaumtextur
	float ft = texture(foam_tex, wpos.xz * 0.21 + vec2(TIME * 0.025, -TIME * 0.018)).r;
	float ft2 = texture(foam_tex, wpos.xz * 0.37 - vec2(TIME * 0.02, TIME * 0.03)).r;
	float shore_w = 0.5 + 0.3 * sin(TIME * 0.9 + wpos.x * 0.4 + wpos.z * 0.3);
	float shore = 1.0 - smoothstep(0.0, shore_w, depth_diff);
	float foam = shore * smoothstep(0.25, 0.7, ft * 0.7 + ft2 * 0.5);
	foam += smoothstep(0.14, 0.24, crest) * smoothstep(0.5, 0.8, ft2) * 0.5;
	foam = clamp(foam, 0.0, 1.0);

	vec3 col = water + vec3(0.05, 0.12, 0.11) * caustic;
	ALBEDO = mix(col, vec3(0.92, 0.95, 0.94), foam) * vis;
	// Durchblick (Brechung) nur dort, wo nicht gespiegelt wird; Spiegelung kommt aus Himmel/SSR ueber SPECULAR
	EMISSION = (behind * (1.0 - fres) * (1.0 - t * 0.75) * 0.6 + vec3(0.7, 0.95, 0.9) * caustic * 0.12) * (1.0 - foam) * vis;
	ROUGHNESS = mix(0.03, 0.55, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.95, 0.2, foam) * vis;
}
