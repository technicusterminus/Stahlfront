shader_type spatial;
// Ketten- und Reifenspuren: dunkle Abdrücke auf dem Boden, die über life Sekunden verblassen.
// INSTANCE_CUSTOM.x = Entstehungszeit (Spielzeit), .y = Art (0 Reifen, 1 Kette), .z = Stärke (Boden: Matsch dunkler).
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

global uniform float world_size;
uniform float now = 0.0;
uniform float life = 22.0;
uniform sampler2D fog_tex : filter_linear, repeat_disable;

varying vec3 wpos;
varying vec3 info;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	float age = now - info.x;
	float fade = clamp(1.0 - age / life, 0.0, 1.0);
	fade *= fade;
	vec2 fuv = wpos.xz / world_size + 0.5;
	vec2 f = texture(fog_tex, fuv).rg;
	float vis = mix(0.0, 0.55, f.g) + 0.45 * f.r;
	// quer zur Fahrtrichtung weiche Ränder, längs: bei Ketten Querrillen (Greifstege)
	float across = 1.0 - smoothstep(0.32, 0.5, abs(UV.x - 0.5));
	float grooves = info.y > 0.5 ? 0.55 + 0.45 * step(0.5, fract(UV.y * 4.0)) : 0.85;
	float a = across * grooves * fade * 0.42 * info.z;
	ALBEDO = vec3(0.12, 0.1, 0.075) * vis;
	ALPHA = a * step(0.05, vis);
}
