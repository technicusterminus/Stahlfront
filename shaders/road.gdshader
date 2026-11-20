shader_type spatial;
// Strasse als Band: Asphalt mit Mittel- und Randlinien, Gehwege, Bordstein; je nach Verfall Risse, Flicken, Gras.
render_mode depth_draw_opaque, cull_disabled;

global uniform float world_size;
global uniform float wetness;

uniform sampler2D asphalt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D walk_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float ruin = 0.5;
uniform float seed = 1.0;
uniform float lane = 0.5;   // Anteil Fahrbahn an der Breite

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

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = UV.x * 2.0 - 1.0;   // -1 .. 1
	float along = UV.y;                // Meter
	float ax = abs(across);
	float wob = noise(wpos.xz * 0.45 + seed) - 0.5;
	vec3 asp = texture(asphalt_tex, wpos.xz * 0.12).rgb * 1.5;
	vec3 wk = texture(walk_tex, wpos.xz * 0.2).rgb * 1.3;
	vec3 dirt = mix(vec3(0.24, 0.19, 0.12), vec3(0.34, 0.28, 0.18), noise(wpos.xz * 1.3));
	vec3 grassc = mix(vec3(0.16, 0.22, 0.07), vec3(0.3, 0.34, 0.12), noise(wpos.xz * 0.8 + 3.0));
	vec3 col;
	float rr = 0.9;
	float alpha = 1.0;
	float sand = smoothstep(0.55, 0.85, noise(wpos.xz * 0.28 + seed * 4.0));
	if (ax < lane + wob * 0.06) {
		col = asp;
		float dash = step(0.5, fract(along / 6.0)) * step(ax, 0.025);
		float edge = step(abs(ax - lane * 0.86), 0.015);
		float wear = noise(wpos.xz * 0.9 + seed);
		col = mix(col, vec3(0.78, 0.74, 0.5) * 0.7, (dash + edge) * (1.0 - ruin * 0.8 * smoothstep(0.3, 0.7, wear)));
		float crack = smoothstep(0.025, 0.0, abs(noise(wpos.xz * 1.6 + seed * 2.0) - 0.5)) * (0.4 + ruin);
		col *= 1.0 - crack * 0.65;
		float patch_ = smoothstep(0.6, 0.64, noise(wpos.xz * 0.35 + seed * 5.0)) * ruin;
		col = mix(col, col * 0.5, patch_);
		// Erde und Gras kommen von den Raendern und aus den Rissen
		float edge_in = smoothstep(lane * 0.3, lane, ax + wob * 0.2);
		float over = clamp(ruin * (0.25 + 0.85 * edge_in) * smoothstep(0.38, 0.62, noise(wpos.xz * 0.5 + seed * 7.0) + wob * 0.4), 0.0, 1.0);
		col = mix(col, mix(dirt, grassc, 0.65), over * 0.9);
		col = mix(col, vec3(0.45, 0.4, 0.3), sand * ruin * 0.4);
		rr = mix(0.85, 1.0, ruin);
	} else if (ax < lane + 0.05 + wob * 0.05) {
		col = wk * 1.1;   // Bordstein
		col = mix(col, grassc, ruin * 0.4);
	} else if (ax < lane + 0.28 + wob * 0.12) {
		col = wk * 0.85;
		float gap = step(0.97, fract(along / 1.6));
		col *= 1.0 - gap * 0.35;
		float weeds = smoothstep(0.35, 0.65, noise(wpos.xz * 0.9 + seed * 3.0)) * ruin;
		col = mix(col, mix(dirt, grassc, 0.7), clamp(weeds * 1.1 + 0.15 * ruin, 0.0, 1.0));
	} else {
		// Saum: Erde, Gras und Schutt gehen in den Boden ueber
		col = mix(dirt, grassc, smoothstep(0.3, 0.7, noise(wpos.xz * 0.6 + 9.0)));
		alpha = 1.0 - smoothstep(lane + 0.34 + wob * 0.12, 1.0, ax + wob * 0.2);
	}
	// Strasse bricht stellenweise ganz weg
	alpha *= 1.0 - smoothstep(0.7, 0.78, noise(wpos.xz * 0.22 + seed * 6.0)) * ruin * 0.9;
	float vis = fog_at(wpos.xz / world_size + 0.5);
	col *= 1.0 - 0.35 * wetness;
	rr = mix(rr, 0.12, wetness * (ax < lane ? 1.0 : 0.5));
	ALBEDO = col * vis;
	ALPHA = alpha;
	ROUGHNESS = rr;
	SPECULAR = 0.3 * vis;
}
