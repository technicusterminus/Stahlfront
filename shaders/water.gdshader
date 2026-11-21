shader_type spatial;
global uniform float world_size;
global uniform float night;
global uniform float wetness;
render_mode specular_schlick_ggx;
// Wasser: Tiefenabsorption, Lichtbrechung, Fresnel-Spiegelung (Himmel + Bildschirmreflexion), Kaustik am Grund,
// Uferschaum aus Bildtextur, Wellenkämme, Regenringe, Sonnenglitzern, Nebel des Krieges.

uniform sampler2D n_ripple : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_swell : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D caus_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.14, 0.50, 0.46);
uniform vec3 deep : source_color = vec3(0.012, 0.05, 0.09);

varying vec3 wpos;
varying float crest;

float fog_at(vec2 uv) {
	vec2 a = texture(fog_tex, uv).rg;
	return mix(mix(0.0, 0.38, a.g), 1.0, smoothstep(0.15, 0.85, a.r));
}

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

// Regentropfen: wachsende Ringe in einem Zellraster
vec2 rain_rings(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	vec2 g = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(g);
	float ph = fract(t * (0.6 + 0.5 * h) + h * 7.0);
	vec2 c = (vec2(hash21(g + 3.1), hash21(g + 7.7)) - 0.5) * 0.6;
	vec2 d = f - c;
	float r = length(d);
	float ring = smoothstep(0.05, 0.0, abs(r - ph * 0.45)) * (1.0 - ph);
	acc += normalize(d + 1e-4) * ring;
	return acc;
}

varying vec2 wgrad;

void gerstner(vec2 p, float t, out vec3 disp, out vec2 grad, out float jacobian) {
	const vec2 D[4] = vec2[4](vec2(0.94, 0.34), vec2(-0.45, 0.89), vec2(0.62, -0.78), vec2(-0.88, -0.47));
	const float K[4] = float[4](0.286, 0.449, 0.785, 1.257);
	const float A[4] = float[4](0.15, 0.10, 0.06, 0.035);
	const float Q[4] = float[4](0.45, 0.40, 0.35, 0.30); // Steilheit (Summe < 1 verhindert Loops)
	disp = vec3(0.0);
	grad = vec2(0.0);
	float j = 1.0;
	for (int i = 0; i < 4; i++) {
		float ph = dot(D[i], p) * K[i] + t * sqrt(9.8 * K[i]) * 0.7;
		float s = sin(ph), c = cos(ph);
		float qa = Q[i] / K[i];
		disp.xz -= D[i] * (qa * c); // Horizontale Einschnürung zum Kamm
		disp.y += A[i] * s;
		grad += D[i] * (A[i] * K[i] * c);
		j -= Q[i] * s; // Stauchung am Kamm fuer Schaum
	}
	jacobian = clamp(1.0 - j, 0.0, 1.0);
}

void vertex() {
	vec3 base_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 disp;
	vec2 gr;
	float jac;
	gerstner(base_wpos.xz, TIME, disp, gr, jac);
	wgrad = gr;
	crest = jac;
	VERTEX += disp;
	wpos = base_wpos + disp;
}

void fragment() {
	float vis = fog_at(wpos.xz / world_size + 0.5);
	// Normalen: grosse Duenung, zwei Kräuselschichten in verschiedene Richtungen
	vec3 s = texture(n_swell, wpos.xz * 0.017 + TIME * vec2(0.010, 0.004)).rgb;
	vec3 a = texture(n_ripple, wpos.xz * 0.06 + TIME * vec2(0.014, 0.008)).rgb;
	vec3 b = texture(n_ripple, wpos.xz * 0.13 - TIME * vec2(0.011, 0.016) + 0.37).rgb;
	vec3 nm = normalize(vec3((s.xy - 0.5) * 1.1 + (a.xy - 0.5) * 0.9 + (b.xy - 0.5) * 0.6, 1.0));
	nm = normalize(vec3(nm.xy - wgrad * 1.6, nm.z));
	vec2 rr = vec2(0.0);
	if (wetness > 0.05) {
		rr = rain_rings(wpos.xz * 1.6, TIME) + rain_rings(wpos.xz * 2.7 + 11.0, TIME * 1.1);
		nm.xy += rr * 0.55 * wetness;
		nm = normalize(nm);
	}
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.3;

	// 1. Echte vertikale Tiefe in Weltkoordinaten (wichtig fuer RTS-Schraegsicht!)
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 view_p = INV_PROJECTION_MATRIX * ndc;
	view_p.xyz /= view_p.w;
	vec3 floor_wpos = (INV_VIEW_MATRIX * vec4(view_p.xyz, 1.0)).xyz;
	
	float v_depth = max(wpos.y - floor_wpos.y, 0.0); // Echte Tiefe nach unten (in Metern)
	float ray_depth = max(VERTEX.z - view_p.z, 0.0); // Optische Weglaenge durchs Wasser

	// 2. Sichere Brechung (kein Einbluten von Schiffen/Stegen!)
	vec2 off = nm.xy * 0.035 * clamp(v_depth * 0.8, 0.0, 1.0);
	float d_refr = textureLod(depth_tex, clamp(SCREEN_UV + off, vec2(0.002), vec2(0.998)), 0.0).r;
	vec4 vp_refr = INV_PROJECTION_MATRIX * vec4((SCREEN_UV + off) * 2.0 - 1.0, d_refr, 1.0);
	vp_refr.xyz /= vp_refr.w;
	if (VERTEX.z < vp_refr.z) off = vec2(0.0); // Pixel liegt VOR dem Wasser -> Versatz verwerfen
	vec3 behind = textureLod(screen_tex, clamp(SCREEN_UV + off, vec2(0.002), vec2(0.998)), 0.0).rgb;

	// 3. Nass-Saum & weiche Flachwasser-Transparenz (Sandsicht)
	// Dunkelt den unmittelbaren Ufergrund ab (simuliert nassen Sand unter der Wasserkante)
	float wet_shore = 1.0 - smoothstep(0.0, 0.35, v_depth);
	behind *= mix(1.0, 0.58, wet_shore);

	// Sanfte Tiefenabsorption (Bier-Lambert) statt milchigem Opak-Tuerkis
	vec3 transmittance = exp(-vec3(0.42, 0.11, 0.14) * ray_depth * 1.15); // Rot verschwindet zuerst -> Tuerkis!
	float water_opacity = 1.0 - exp(-ray_depth * 0.45);
	vec3 water_tint = mix(shallow, deep, clamp(v_depth / 4.5, 0.0, 1.0));

	// Kaustik auf den sichtbaren Sandgrund projizieren (nutzt floor_wpos statt Wasser-UV!)
	vec3 c1 = texture(caus_tex, floor_wpos.xz * 0.11 + TIME * vec2(0.02, 0.013)).rgb;
	vec3 c2 = texture(caus_tex, floor_wpos.xz * 0.09 - TIME * vec2(0.017, 0.021) + 0.5).rgb;
	float caustic = pow(min(c1.g, c2.g), 1.8) * 2.2;
	caustic *= smoothstep(0.05, 0.4, v_depth) * exp(-v_depth * 0.55) * (1.0 - night * 0.9);
	vec3 refracted_ground = (behind + behind * caustic * vec3(0.8, 1.0, 0.95)) * transmittance;

	// 4. Uferbrandung vs. Objektschaum (Schiffe/Stege)
	float ft = texture(foam_tex, wpos.xz * 0.22 + nm.xy * 0.08 + TIME * 0.015).r;
	float ft2 = texture(foam_tex, wpos.xz * 0.41 - nm.xy * 0.06 - TIME * 0.02).r;
	float foam_noise = ft * 0.65 + ft2 * 0.55;

	// Gefaelle des Grundes erkennt steile Objekte (Schiffswand = hoher Gradient) vs. flachen Strand
	float slope = clamp(length(vec2(dFdx(v_depth), dFdy(v_depth))) * 18.0, 0.0, 1.0);

	// A) Objektschaum (eng, kräftig um Schiffsrümpfe & Brückenpfeiler, leicht wogend)
	float obj_edge = 1.0 - smoothstep(0.02, 0.38, v_depth);
	float ship_foam = obj_edge * mix(0.35, 1.0, slope) * smoothstep(0.28, 0.65, foam_noise + 0.2);

	// B) Auslaufende Strandbrandung (nur an flachem Ufer, organisch aufgebrochen)
	float wave_phase = fract(v_depth * 0.85 - TIME * 0.28 + (ft - 0.5) * 0.35);
	float surf_line = smoothstep(0.0, 0.12, wave_phase) * (1.0 - smoothstep(0.12, 0.65, wave_phase));
	surf_line *= (1.0 - wave_phase); // Sanftes Auslaufen nach hinten
	surf_line *= (1.0 - slope * 0.8) * exp(-v_depth * 0.9) * smoothstep(0.02, 0.18, v_depth);
	float surf_foam = surf_line * smoothstep(0.32, 0.72, foam_noise) * 1.25;

	// C) Gerstner-Wellenkamm-Schaum (nutzt Jacobian-Stauchung aus vertex)
	float crest_foam = smoothstep(0.32, 0.65, crest) * smoothstep(0.45, 0.8, foam_noise) * 0.45;

	float foam = clamp(max(ship_foam, surf_foam) + crest_foam, 0.0, 1.0);

	// 5. Sanftes Licht & RTS-tauglicher Fresnel + weiches Ufer-Fadeout
	float cosv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Angehobener Basis-Fresnel (0.06) + sanfterer Exponent (3.5) fuer bessere Spiegelung von schraeg oben
	float fres = clamp(0.06 + 0.80 * pow(1.0 - cosv, 3.5), 0.0, 1.0);
	float edge_fade = smoothstep(0.0, 0.08, v_depth); // Verhindert harte Schnittkante am Strand

	vec3 surface_col = mix(refracted_ground, water_tint, water_opacity * 0.65 + fres * 0.35);
	vec3 final_col = mix(surface_col, vec3(0.90, 0.93, 0.94), foam);
	final_col = mix(behind, final_col, edge_fade); // Butterweiche Wasserkante

	// Saubere PBR-Trennung: Untergrund in ALBEDO (erhaelt korrekte Schatten!), sanfteres Glitzern
	ALBEDO = final_col * vis;
	EMISSION = vec3(0.0); // Kein unbeleuchtetes Ueberstrahlen im Schatten mehr!
	// Etwas hoehere Basis-Roughness (0.09) eliminiert das harte Pixel-Flimmern aus Bild 2
	ROUGHNESS = mix(0.09, 0.65, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.65, 0.15, foam) * edge_fade * vis;
}
