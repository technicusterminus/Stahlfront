shader_type canvas_item;
// Nachbearbeitung über dem 3D-Bild (unter der Oberfläche): Schärfen, Farbgebung für Schatten und Lichter,
// weiche Vignette und feines Filmkorn für einen modernen, filmischen Eindruck.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sharpen : hint_range(0.0, 1.0) = 0.38;
uniform float vignette : hint_range(0.0, 1.0) = 0.32;
uniform float grain : hint_range(0.0, 0.1) = 0.011;
uniform vec3 shadow_tint = vec3(0.90, 0.97, 1.07);
uniform vec3 highlight_tint = vec3(1.07, 1.0, 0.91);
uniform float saturation : hint_range(0.5, 1.5) = 1.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 n = textureLod(screen_tex, uv + vec2(px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv - vec2(px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv + vec2(0.0, px.y), 0.0).rgb
		+ textureLod(screen_tex, uv - vec2(0.0, px.y), 0.0).rgb;
	c += (c - n * 0.25) * sharpen;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.12, 0.8, l));
	c = mix(vec3(l), c, saturation);
	vec2 d = uv - vec2(0.5);
	float v = smoothstep(0.95, 0.25, length(d * vec2(1.0, 0.9)) * (1.0 + vignette));
	c *= mix(1.0 - vignette * 0.6, 1.0, v);
	c += (hash(uv * vec2(1920.0, 1080.0) + vec2(TIME)) - 0.5) * grain;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
