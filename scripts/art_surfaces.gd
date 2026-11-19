extends RefCounted
## Gemeinsam genutzte Detailtexturen aus dem OpenRouter-Oberflächenlauf.

const PROFILES := {
	"metal": Vector2(1.75, 0.29),
	"concrete": Vector2(0.89, 0.30),
	"fabric": Vector2(4.25, 0.24),
	"timber": Vector2(1.18, 0.30),
}

const FABRIC_COLORS := {
	"west": Color(0.24, 0.28, 0.32),
	"red": Color(0.27, 0.29, 0.20),
	"shadow": Color(0.43, 0.37, 0.28),
}

static var _enabled := not OS.get_cmdline_user_args().has("--plain-surfaces")
static var _textures: Dictionary = {}

static func active() -> bool:
	return _enabled

static func _texture_for(kind: String, channel: String) -> Texture2D:
	if not _enabled:
		return null
	var path := "res://models/surfaces/%s_%s.png" % [kind, channel]
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

static func apply_shader(material: ShaderMaterial, kind: String) -> void:
	var data := _texture_for(kind, "data")
	if data == null:
		return
	var profile: Vector2 = PROFILES[kind]
	material.set_shader_parameter("art_surface", data)
	material.set_shader_parameter("art_scale", profile.x)
	material.set_shader_parameter("art_amount", profile.y)

static func apply_standard(material: BaseMaterial3D, kind: String) -> void:
	if material.detail_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	if material.ao_on_uv2 or material.emission_on_uv2:
		return
	var overlay := _texture_for(kind, "overlay")
	var relief := _texture_for(kind, "normal")
	if overlay == null or relief == null:
		return
	var profile: Vector2 = PROFILES[kind]
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	material.detail_albedo = overlay
	material.detail_normal = relief
	material.uv2_triplanar = true
	material.uv2_scale = Vector3.ONE * profile.x
	material.uv2_triplanar_sharpness = 3.0
