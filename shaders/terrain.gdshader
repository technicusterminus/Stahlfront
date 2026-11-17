shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_n : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 240.0;

varying vec3 wpos;
float fog_at(vec2 uv) {
	vec2 px = vec2(1.0 / 120.0);
	vec2 a = texture(fog_tex, uv).rg * 0.36
		+ (texture(fog_tex, uv + vec2(px.x, 0.0)).rg + texture(fog_tex, uv - vec2(px.x, 0.0)).rg
		+ texture(fog_tex, uv + vec2(0.0, px.y)).rg + texture(fog_tex, uv - vec2(0.0, px.y)).rg) * 0.11
		+ (texture(fog_tex, uv + px).rg + texture(fog_tex, uv - px).rg
		+ texture(fog_tex, uv + vec2(px.x, -px.y)).rg + texture(fog_tex, uv + vec2(-px.x, px.y)).rg) * 0.05;
	return mix(mix(0.0, 0.38, a.g), 1.0, smoothstep(0.15, 0.85, a.r));
}
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.018).r;
	float n2 = texture(noise_tex, wpos.xz * 0.13 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos.xz * 0.6).r;
	vec3 grass = mix(vec3(0.10, 0.17, 0.05), vec3(0.24, 0.30, 0.10), n2);
	vec3 dirt = mix(vec3(0.22, 0.17, 0.11), vec3(0.40, 0.33, 0.22), n2);
	vec3 rock = mix(vec3(0.15, 0.14, 0.13), vec3(0.27, 0.26, 0.24), n2 * 0.7 + n3 * 0.3);
	vec3 sand = vec3(0.50, 0.44, 0.30);
	float slope = 1.0 - wnrm.y;
	vec3 col = mix(grass, dirt, smoothstep(0.42, 0.62, n1 * 0.7 + n2 * 0.3));
	col = mix(col, rock, smoothstep(0.07, 0.2, slope));
	col = mix(sand, col, smoothstep(-1.0, 0.1, wpos.y));
	col *= 0.93 + 0.14 * n3;
	float vis = fog_at(wpos.xz / 240.0 + 0.5);
	ALBEDO = col * vis;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25 * vis;
	NORMAL_MAP = texture(noise_n, wpos.xz * 0.11).rgb;
	NORMAL_MAP_DEPTH = 0.45;
}
