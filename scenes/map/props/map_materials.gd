@tool
class_name MapMaterials
extends RefCounted
## Shared surface materials for map props. Triplanar noise gives stone and
## earth some grit without needing UVs or texture files, and sharing one
## material per surface keeps draw-call state changes down on Quest.

enum Surface { STONE, DARK_STONE, MOSSY_STONE, EARTH, WOOD, IRON, BONE }

const COLORS := {
	Surface.STONE: Color(0.42, 0.41, 0.44),
	Surface.DARK_STONE: Color(0.24, 0.23, 0.26),
	Surface.MOSSY_STONE: Color(0.30, 0.36, 0.28),
	Surface.EARTH: Color(0.17, 0.15, 0.14),
	Surface.WOOD: Color(0.20, 0.16, 0.13),
	Surface.IRON: Color(0.12, 0.12, 0.13),
	Surface.BONE: Color(0.70, 0.67, 0.60),
}

static var _cache := {}
static var _noise: NoiseTexture2D


static func get_material(surface: Surface) -> StandardMaterial3D:
	if _cache.has(surface):
		return _cache[surface]
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[surface]
	material.roughness = 0.95 if surface != Surface.IRON else 0.55
	material.metallic = 0.6 if surface == Surface.IRON else 0.0
	if surface != Surface.IRON:
		material.albedo_texture = _grit()
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * (0.6 if surface == Surface.EARTH else 0.35)
	_cache[surface] = material
	return material


static func _grit() -> NoiseTexture2D:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = noise
		# Map noise to a narrow bright band so it multiplies the base colour subtly.
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.7, 0.7, 0.7))
		ramp.set_color(1, Color(1.15, 1.15, 1.15))
		_noise.color_ramp = ramp
	return _noise
