shader_type spatial;
// Gebaeudefassade: Wandtextur (objektbezogen dreiseitig), Fensterraster mit Rahmen und Gesims,
// Ruinenschaeden (ausgebrochene Fenster, Russ, Verwitterung), nachts erleuchtete Fenster, Nebel des Krieges.

global uniform float world_size;
global uniform float night;
global uniform float wetness;

uniform sampler2D wall_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 glass_col : source_color = vec3(0.10, 0.18, 0.24);
uniform float tex_scale = 0.3;
uniform float half_h = 2.0;
uniform float floor_h = 3.0;
uniform float win_w = 2.0;
uniform float win_fill = 0.55;   // Anteil Fensterflaeche je Feld (Glasfassade ~0.9)
uniform float ruin = 0.0;
uniform float seed = 1.0;
uniform float lit_share = 0.35;
uniform bool windows = true;
uniform bool facade = false;       // fertige Fassadentextur (Hochhaus) statt Fensterraster
uniform vec2 tile_m = vec2(30.0, 30.0);   // Meter je Texturwiederholung (Breite, Hoehe)
uniform float cols = 16.0;         // Fensterspalten je Kachel (fuer nachts erleuchtete Fenster)
uniform sampler2D top_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform bool has_top = false;
uniform bool round_s = false;
uniform float rough = 0.9;
uniform float metal = 0.0;

varying vec3 lp;
varying vec3 ln;
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
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 w = pow(abs(ln), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-5);
	vec3 col = texture(wall_tex, lp.zy * tex_scale).rgb * w.x
		+ texture(wall_tex, lp.xz * tex_scale).rgb * w.y
		+ texture(wall_tex, lp.xy * tex_scale).rgb * w.z;
	col *= tint;
	float emit = 0.0;
	float rr = rough;
	float mm = metal;
	bool side = abs(ln.y) < 0.5;
	float v = lp.y + half_h;   // Hoehe ueber der Sockelkante
	if (side && facade) {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		if (ln.x + ln.z < 0.0) u = -u;
		if (round_s) u = atan(lp.z, lp.x) * length(lp.xz);
		vec2 uv = vec2(u / tile_m.x, 1.0 - v / tile_m.y);
		col = texture(wall_tex, uv).rgb * tint;
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		float glassy = smoothstep(0.30, 0.14, lum) + smoothstep(0.02, 0.12, col.b - col.r) * 0.6;
		rr = mix(rough, 0.18, clamp(glassy, 0.0, 1.0));
		mm = mix(metal, 0.35, clamp(glassy, 0.0, 1.0));
		col *= mix(0.6, 1.0, smoothstep(0.0, 3.0, v));
		float gridv = hash(floor(vec2(uv.x * cols, uv.y * cols * 1.2)) + seed);
		if (lum < 0.2 && gridv < lit_share) {
			emit = night * (0.6 + 0.8 * gridv * 3.0);
			col = mix(col, vec3(1.0, 0.82, 0.5) * 0.3, night);
		}
	} else if (side) {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		// Verschmutzung: unten dunkler, Regenfahnen
		col *= mix(0.62, 1.0, smoothstep(0.0, 2.2, v));
		float streak = hash(vec2(floor(u * 3.0), seed));
		col *= 1.0 - 0.25 * streak * smoothstep(half_h * 2.0, 0.0, v) * ruin;
		if (windows && v > 0.9 && v < half_h * 2.0 - 0.7) {
			vec2 cell = vec2(u / win_w, (v - 0.9) / floor_h);
			vec2 id = floor(cell);
			vec2 f = fract(cell);
			float mx = (1.0 - win_fill) * 0.5;
			float my = 0.2 + (1.0 - win_fill) * 0.2;
			vec2 lo = vec2(mx, my);
			vec2 hi = vec2(1.0 - mx, 1.0 - my);
			float inside = step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
			float h1 = hash(id + seed);
			float h2 = hash(id * 1.7 + seed * 3.1);
			if (inside > 0.5) {
				float frame = step(f.x, lo.x + 0.07) + step(hi.x - 0.07, f.x) + step(f.y, lo.y + 0.06) + step(hi.y - 0.06, f.y);
				float mullion = step(abs(f.x - 0.5), 0.025);
				bool broken = h1 < ruin * 0.55;
				if (frame > 0.5 || mullion > 0.5) {
					col = tint * 0.35;
				} else if (broken) {
					col = vec3(0.025, 0.022, 0.02);
					rr = 1.0;
				} else {
					float sky = smoothstep(0.0, 1.0, f.y) * 0.5;
					col = glass_col * (0.7 + sky + 0.5 * h2);
					rr = 0.12;
					mm = 0.35;
					if (h2 < lit_share) {
						emit = night * (0.5 + 0.8 * h1);
						col = mix(col, vec3(1.0, 0.82, 0.5) * 0.3, night);
					}
				}
			} else {
				// Sims unter dem Fenster
				col *= 1.0 - 0.18 * step(lo.y - 0.05, f.y) * step(f.y, lo.y);
			}
		}
		// Gesims oben
		col *= 1.0 - 0.25 * smoothstep(half_h * 2.0 - 0.45, half_h * 2.0 - 0.1, v) * 0.0;
	} else if (ln.y > 0.5) {
		if (has_top) {
			col = texture(top_tex, lp.xz * 0.08).rgb * tint;
		}
		col *= 0.85;
	}
	// Bewuchs: Efeu waechst von unten an den Waenden hoch, Moos auf Daechern
	if (side) {
		float uu = abs(ln.x) > 0.5 ? lp.z : lp.x;
		float hgt = clamp(v / (half_h * 2.0), 0.0, 1.0);
		float ivy = smoothstep(0.42, 0.7, noise(vec2(uu * 0.7, v * 0.35) + seed * 3.0) + (0.5 - hgt) * 0.55) * ruin;
		vec3 leaf = vec3(0.1, 0.19, 0.06) * (0.7 + 0.8 * noise(vec2(uu * 5.0, v * 5.0)));
		col = mix(col, leaf, clamp(ivy, 0.0, 1.0) * 0.85);
		rr = mix(rr, 0.95, clamp(ivy, 0.0, 1.0));
		mm = mix(mm, 0.0, clamp(ivy, 0.0, 1.0));
		emit *= 1.0 - clamp(ivy, 0.0, 1.0);
	} else if (ln.y > 0.5) {
		float moss = smoothstep(0.45, 0.7, noise(lp.xz * 0.5 + seed)) * ruin;
		col = mix(col, vec3(0.14, 0.22, 0.08), moss * 0.8);
	}
	float vis = fog_at(wpos.xz / world_size + 0.5);
	col *= 1.0 - 0.22 * wetness;
	rr = mix(rr, rr * 0.6, wetness);
	ALBEDO = col * vis;
	ROUGHNESS = rr;
	METALLIC = mm;
	SPECULAR = 0.4 * vis;
	EMISSION = vec3(1.0, 0.8, 0.45) * emit * vis;
}
