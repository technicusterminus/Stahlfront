shader_type spatial;
global uniform float world_size;
render_mode specular_schlick_ggx;
// Wasser: Tiefenfarbe, Lichtbrechung, Uferschaum, Wellen, Fresnel, Nebel des Krieges.

uniform sampler2D n1 : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.1, 0.36, 0.34);
uniform vec3 deep : source_color = vec3(0.015, 0.06, 0.1);

varying vec3 wpos;

float fog_at(vec2 uv) {
	vec2 a = texture(fog_tex, uv).rg;
	return mix(mix(0.0, 0.38, a.g), 1.0, smoothstep(0.15, 0.85, a.r));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.35 + TIME * 1.3) * 0.035 + sin(wpos.z * 0.28 + TIME * 1.05) * 0.035;
}

void fragment() {
	float vis = fog_at(wpos.xz / world_size + 0.5);
	vec3 a = texture(n1, wpos.xz * 0.05 + TIME * vec2(0.012, 0.007)).rgb;
	vec3 b = texture(n1, wpos.xz * 0.11 - TIME * vec2(0.009, 0.014)).rgb;
	vec3 nm = mix(a, b, 0.5);

	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float depth_diff = max(VERTEX.z - v.z, 0.0);
	float t = clamp(depth_diff / 2.5, 0.0, 1.0);

	vec2 off = (nm.xy - 0.5) * 0.04 * t;
	vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
	vec3 water = mix(shallow, deep, t);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	float fn = texture(foam_noise, wpos.xz * 0.25 + TIME * 0.03).r;
	float foam = (1.0 - smoothstep(0.0, 0.5, depth_diff)) * smoothstep(0.35, 0.65, fn + 0.25 * sin(TIME * 2.0 + wpos.x));

	ALBEDO = mix(water, vec3(0.9, 0.93, 0.92), foam) * vis;
	EMISSION = behind * (1.0 - t) * 0.55 * (1.0 - foam) * vis;
	ROUGHNESS = mix(0.04, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.6, 0.2, foam) * vis;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.6 + fres * 0.4;
}
