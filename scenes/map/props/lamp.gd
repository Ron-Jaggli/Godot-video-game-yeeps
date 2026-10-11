@tool
class_name Lamp
extends StaticBody3D
## Iron lamp post with a guttering lantern. The light flickers in-game only;
## shadows are off because they're expensive on Quest.

@export var height := 2.6:
	set(value):
		height = value
		_rebuild()
@export var light_color := Color(1.0, 0.62, 0.3):
	set(value):
		light_color = value
		_rebuild()

const BASE_ENERGY := 1.6

var _parts: Array[Node] = []
var _light: OmniLight3D
var _flicker_time := 0.0
var _flicker := FastNoiseLite.new()


func _ready() -> void:
	_rebuild()
	_flicker.frequency = 2.0
	_flicker.seed = hash(global_position) if is_inside_tree() else 0
	# No flicker in the editor or on headless (server) runs.
	set_process(not Engine.is_editor_hint() and DisplayServer.get_name() != "headless")


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for part in _parts:
		part.free()
	_parts.clear()

	var iron := MapMaterials.get_material(MapMaterials.Surface.IRON)
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.08
	post.height = height
	post.radial_segments = 8
	_add(_mesh(post, Vector3(0, height * 0.5, 0), iron))

	var cage := BoxMesh.new()
	cage.size = Vector3(0.26, 0.34, 0.26)
	_add(_mesh(cage, Vector3(0, height + 0.17, 0), iron))

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = light_color
	var flame := BoxMesh.new()
	flame.size = Vector3(0.2, 0.26, 0.2)
	_add(_mesh(flame, Vector3(0, height + 0.17, 0), glow))

	_light = OmniLight3D.new()
	_light.position = Vector3(0, height + 0.17, 0)
	_light.light_color = light_color
	_light.light_energy = BASE_ENERGY
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_add(_light)

	var shape := CylinderShape3D.new()
	shape.radius = 0.08
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = height * 0.5
	_add(collider)


func _process(delta: float) -> void:
	_flicker_time += delta
	_light.light_energy = BASE_ENERGY * (0.85 + 0.25 * _flicker.get_noise_1d(_flicker_time * 10.0))


func _mesh(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	return instance


func _add(node: Node) -> void:
	add_child(node)
	_parts.append(node)
