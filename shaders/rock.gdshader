shader_type spatial;
// Felsen: Koernung, Flechten, Moos auf der Oberseite, Nebel des Krieges.

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_n : hint_normal, repeat_enable, filter_linear_mipmap;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 icol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icol = COLOR.rgb;
}

float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(noise_tex, p.zy).r * w.x + texture(noise_tex, p.xz).r * w.y + texture(noise_tex, p.xy).r * w.z;
}

void fragment() {
	vec2 f = texture(fog_tex, wpos.xz / 240.0 + 0.5).rg;
	float vis = mix(mix(0.0, 0.38, f.g), 1.0, smoothstep(0.1, 0.9, f.r));
	float g1 = tri(wpos * 0.35, wnrm);
	float g2 = tri(wpos * 2.2, wnrm);
	vec3 col = icol * (0.75 + 0.5 * g1) * (0.85 + 0.3 * g2);
	// Adern und Flechten
	float vein = smoothstep(0.48, 0.5, g1) * smoothstep(0.52, 0.5, g1);
	col = mix(col, col * 0.55, vein);
	float lichen = smoothstep(0.62, 0.7, g2) * 0.6;
	col = mix(col, vec3(0.55, 0.55, 0.42), lichen);
	// Moos oben
	float moss = smoothstep(0.55, 0.85, wnrm.y) * smoothstep(0.35, 0.6, g1);
	col = mix(col, vec3(0.12, 0.2, 0.06) * (0.8 + 0.4 * g2), moss);
	ALBEDO = col * vis;
	ROUGHNESS = 0.9 - moss * 0.05;
	SPECULAR = 0.3 * vis;
	NORMAL_MAP = texture(noise_n, wpos.xz * 0.6 + wpos.y * 0.3).rgb;
	NORMAL_MAP_DEPTH = 1.2;
}
