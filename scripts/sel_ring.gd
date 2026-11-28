class_name SelRing
## Auswahlmarkierung am Boden: flacher, dünner Ring mit weichem Rand und zarter Innenfläche.
## Er wird mit Tiefentest gezeichnet (Bäume und Fahrzeugaufbauten verdecken ihn), aber im Blickraum ein Stück zur
## Kamera gezogen, damit er an Hängen nicht im Gelände versinkt. square = eckig (Gebäude), sonst rund.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 col : source_color = vec4(0.35, 1.0, 0.45, 1.0);
uniform float bias = 0.6;
void vertex() {
	// zur Kamera ziehen: Ring bleibt auf unebenem Boden sichtbar, ohne durch Aufbauten zu scheinen
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz += normalize(-v.xyz) * bias;
	POSITION = PROJECTION_MATRIX * v;
}
void fragment() {
	// UV.x: 0 = Innenkante der Fläche, 1 = Außenkante; UV.y: 1 auf dem Ring, 0 in der Fläche
	float edge = smoothstep(0.0, 0.35, UV.x) * (1.0 - smoothstep(0.65, 1.0, UV.x));
	float a = mix(0.07, edge * 0.95, UV.y);
	ALBEDO = col.rgb;
	ALPHA = a * col.a;
}
"""

static var _shader: Shader

static func make(radius: float, color: Color, square := false, radius_z := -1.0) -> MeshInstance3D:
	# radius_z > 0: ovaler Ring (Halbmesser quer = radius, längs = radius_z), z. B. eng um einen langen Rumpf
	var rz := radius_z if radius_z > 0.0 else radius
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var width := clampf(radius * 0.1, 0.12, 0.6)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := 4 if square else 48
	var corner := 1.0 / cos(PI / 4.0) if square else 1.0
	for i in n + 1:
		var a := TAU * float(i) / float(n) + (PI / 4.0 if square else 0.0)
		var d := Vector3(cos(a), 0, sin(a)) * corner
		var ri := Vector3(d.x * (radius - width * 0.5), 0, d.z * (rz - width * 0.5))
		var ro := Vector3(d.x * (radius + width * 0.5), 0, d.z * (rz + width * 0.5))
		# vier Ringe von innen nach außen: Flächenrand, Ring innen, Ring außen
		verts.append(ri * 0.55)
		uvs.append(Vector2(0.0, 0.0))
		verts.append(ri)
		uvs.append(Vector2(0.0, 0.0))
		verts.append(ri)
		uvs.append(Vector2(0.0, 1.0))
		verts.append(ro)
		uvs.append(Vector2(1.0, 1.0))
		if i > 0:
			var b := (i - 1) * 4
			var c := i * 4
			for k in [0, 2]:
				idx.append_array([b + k, c + k, c + k + 1, b + k, c + k + 1, b + k + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("col", color)
	m.set_shader_parameter("bias", clampf(radius * 0.35, 0.4, 1.6))
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.08
	mi.visible = false
	return mi
