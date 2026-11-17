shader_type spatial;

uniform vec3 tint : source_color = vec3(0.1, 0.3, 0.1);
uniform float rough = 0.9;
uniform float glow = 0.0;
uniform sampler2D fog_tex : filter_linear, repeat_disable;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float vis = fog_at(wpos.xz / 240.0 + 0.5);
	ALBEDO = tint * COLOR.rgb * vis;
	ROUGHNESS = rough;
	SPECULAR = 0.3 * vis;
	EMISSION = tint * glow * vis;
}
