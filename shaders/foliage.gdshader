shader_type spatial;
render_mode cull_disabled;
// Vegetation: Wind, Farbverlauf zur Spitze, Durchscheinen, Nebel des Krieges,
// Platzhalter-Textur (unter Gebaeuden verschwindet das Gras).

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D occ_tex : filter_linear, repeat_disable;
uniform bool use_occ = false;
uniform float wind = 0.12;
uniform float sway_h = 0.7;
uniform vec3 base_col : source_color = vec3(0.6);
uniform vec3 tip_col : source_color = vec3(1.0);
uniform float rough = 0.85;
uniform float translucency = 0.35;

varying float vis;
varying float hf;
varying vec3 icol;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	hf = clamp(VERTEX.y / sway_h, 0.0, 1.0);
	vec2 uv = origin.xz / 240.0 + 0.5;
	vec4 oc = texture(occ_tex, uv);
	float occ = use_occ ? clamp(max(max(oc.r, oc.g), max(oc.b, oc.a)) * 1.6 - 0.3, 0.0, 1.0) : 0.0;
	float ph = TIME * 1.6 + origin.x * 0.13 + origin.z * 0.11;
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + origin.x * 0.02);
	vec2 sw = vec2(sin(ph), cos(ph * 0.8 + 1.3) * 0.6) * wind * gust * hf * hf;
	VERTEX.xz += sw;
	VERTEX.y *= (1.0 - occ);
	vec2 f = texture(fog_tex, uv).rg;
	vis = mix(mix(0.0, 0.38, f.g), 1.0, smoothstep(0.1, 0.9, f.r));
	icol = COLOR.rgb;
}

void fragment() {
	vec3 c = icol * mix(base_col, tip_col, hf);
	ALBEDO = c * vis;
	ROUGHNESS = rough;
	SPECULAR = 0.25 * vis;
	BACKLIGHT = c * translucency * vis;
	AO = mix(0.45, 1.0, hf);
	AO_LIGHT_AFFECT = 0.6;
}
