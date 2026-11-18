shader_type spatial;
global uniform float world_size;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_n : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 240.0;
uniform sampler2D occ_tex : filter_linear, repeat_disable;

varying vec3 wpos;
float fog_at(vec2 uv) {
	vec2 px = vec2(2.0 / world_size);
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
	float rough = 0.93;

	// Basisboden je Fraktion (aus der Belegungs-Textur, Rand mit Rauschen aufgebrochen)
	vec4 base = texture(occ_tex, wpos.xz / world_size + 0.5);
	float edge = (n2 - 0.5) * 0.35 + (n3 - 0.5) * 0.15;
	float mw = smoothstep(0.38, 0.62, base.r + edge);
	float mr = smoothstep(0.38, 0.62, base.g + edge);
	float ms = smoothstep(0.38, 0.62, base.b + edge);
	// Westbund: helle Betonplatten 2 m mit Fugen
	vec2 tw = abs(fract(wpos.xz / 2.0) - 0.5);
	float jw = smoothstep(0.475, 0.49, max(tw.x, tw.y));
	vec3 cw = vec3(0.56, 0.57, 0.57) * (0.9 + 0.2 * n2) * (1.0 - jw * 0.45);
	cw = mix(cw, vec3(0.3, 0.3, 0.28), smoothstep(0.62, 0.75, n1) * 0.4);
	// Rote Allianz: grobe Platten 4 m, Risse, Ölflecken
	vec2 tr = abs(fract(wpos.xz / 4.0 + 0.5) - 0.5);
	float jr = smoothstep(0.47, 0.49, max(tr.x, tr.y));
	float crack = smoothstep(0.495, 0.5, n3) * smoothstep(0.505, 0.5, n3);
	vec3 cr = vec3(0.4, 0.38, 0.35) * (0.85 + 0.25 * n2) * (1.0 - jr * 0.5) * (1.0 - crack * 0.6);
	cr = mix(cr, vec3(0.08, 0.07, 0.06), smoothstep(0.66, 0.72, n1 * 0.6 + n3 * 0.4) * 0.7);
	// Schattenfront: festgefahrene Erde mit Reifenspuren
	float tracks = smoothstep(0.75, 0.95, sin(wpos.x * 1.7 + n1 * 8.0)) * 0.5 + smoothstep(0.75, 0.95, sin(wpos.z * 1.7 + n2 * 8.0)) * 0.5;
	vec3 cs = mix(vec3(0.4, 0.32, 0.22), vec3(0.5, 0.42, 0.3), n2) * (1.0 - tracks * 0.25) * (0.9 + 0.2 * n3);
	col = mix(col, cw, mw);
	col = mix(col, cr, mr * (1.0 - mw));
	col = mix(col, cs, ms * (1.0 - mw) * (1.0 - mr));
	rough = mix(rough, 0.78, max(mw, mr));

	float vis = fog_at(wpos.xz / world_size + 0.5);
	ALBEDO = col * vis;
	ROUGHNESS = rough;
	SPECULAR = 0.25 * vis;
	NORMAL_MAP = texture(noise_n, wpos.xz * 0.11).rgb;
	NORMAL_MAP_DEPTH = 0.45;
}
