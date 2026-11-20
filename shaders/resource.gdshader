shader_type spatial;
// Rohstoffvorkommen: Farbtextur (dreiseitig projiziert oder über die Mesh-UV), Nebel des Krieges,
// leuchtende Goldadern aus den hellen, gelben Bereichen der Textur.

global uniform float world_size;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform bool use_uv = false;
uniform float tex_scale = 0.4;
uniform vec3 tint : source_color = vec3(1.0);
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float vein_glow = 0.0;
uniform vec3 vein_col : source_color = vec3(1.0, 0.78, 0.28);

varying vec3 wpos;
varying vec3 wnrm;

float fog_at(vec2 uv) {
	vec2 px = vec2(2.0 / world_size);
	vec2 a = texture(fog_tex, uv).rg * 0.36
		+ (texture(fog_tex, uv + vec2(px.x, 0.0)).rg + texture(fog_tex, uv - vec2(px.x, 0.0)).rg
		+ texture(fog_tex, uv + vec2(0.0, px.y)).rg + texture(fog_tex, uv - vec2(0.0, px.y)).rg) * 0.11
		+ (texture(fog_tex, uv + px).rg + texture(fog_tex, uv - px).rg
		+ texture(fog_tex, uv + vec2(px.x, -px.y)).rg + texture(fog_tex, uv + vec2(-px.x, px.y)).rg) * 0.05;
	return mix(mix(0.0, 0.38, a.g), 1.0, smoothstep(0.15, 0.85, a.r));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col;
	if (use_uv) {
		col = texture(albedo_tex, UV).rgb;
	} else {
		vec3 w = pow(abs(wnrm), vec3(4.0));
		w /= (w.x + w.y + w.z + 1e-5);
		col = texture(albedo_tex, wpos.zy * tex_scale).rgb * w.x
			+ texture(albedo_tex, wpos.xz * tex_scale).rgb * w.y
			+ texture(albedo_tex, wpos.xy * tex_scale).rgb * w.z;
	}
	float vis = fog_at(wpos.xz / world_size + 0.5);
	float gold = smoothstep(0.5, 0.8, col.r) * smoothstep(0.28, 0.5, col.r - col.b);
	ALBEDO = col * tint * vis;
	ROUGHNESS = mix(rough, 0.28, gold * step(0.001, vein_glow));
	METALLIC = max(metal, gold * 0.85 * step(0.001, vein_glow));
	SPECULAR = 0.4 * vis;
	EMISSION = vein_col * gold * vein_glow * vis;
}
