@tool
class_name Gravestone
extends StaticBody3D
## A headstone with a rounded top, randomly sized and tilted from its seed so
## rows of them look old and sunken rather than copy-pasted.

@export var stone_seed := 1:
	set(value):
		stone_seed = value
		_rebuild()

var _parts: Array[Node] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for part in _parts:
		part.free()
	_parts.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var width := rng.randf_range(0.5, 0.8)
	var height := rng.randf_range(0.7, 1.2)
	var depth := 0.16
	var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.12, 0.12)))
	var surface := MapMaterials.Surface.MOSSY_STONE if rng.randf() < 0.4 else MapMaterials.Surface.STONE

	var slab := BoxMesh.new()
	slab.size = Vector3(width, height - width * 0.5, depth)
	_add_mesh(slab, Transform3D(tilt, tilt * Vector3(0, slab.size.y * 0.5, 0)), surface)

	# Rounded top: a cylinder lying along Z, half sunk into the slab.
	var cap := CylinderMesh.new()
	cap.top_radius = width * 0.5
	cap.bottom_radius = width * 0.5
	cap.height = depth
	cap.radial_segments = 16
	cap.rings = 1
	var cap_basis := tilt * Basis(Vector3.RIGHT, PI * 0.5)
	_add_mesh(cap, Transform3D(cap_basis, tilt * Vector3(0, slab.size.y, 0)), surface)

	var box := BoxShape3D.new()
	box.size = Vector3(width, height, depth)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.transform = Transform3D(tilt, tilt * Vector3(0, height * 0.5, 0))
	add_child(collider)
	_parts.append(collider)


func _add_mesh(mesh: Mesh, transform_: Transform3D, surface: MapMaterials.Surface) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = transform_
	instance.material_override = MapMaterials.get_material(surface)
	add_child(instance)
	_parts.append(instance)
