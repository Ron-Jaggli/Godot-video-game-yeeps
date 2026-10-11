@tool
class_name MapBlock
extends StaticBody3D
## Level-building block: a box or cylinder with matching collision. Drop one
## in a map, set size/shape/surface in the inspector, and move it around;
## the mesh and collider are rebuilt to match.

enum Shape { BOX, CYLINDER }

@export var size := Vector3(1, 1, 1):
	set(value):
		size = value
		_rebuild()
@export var shape := Shape.BOX:
	set(value):
		shape = value
		_rebuild()
@export var surface := MapMaterials.Surface.STONE:
	set(value):
		surface = value
		_rebuild()

var _mesh: MeshInstance3D
var _collider: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_collider = CollisionShape3D.new()
		add_child(_mesh)
		add_child(_collider)
	if shape == Shape.BOX:
		var box := BoxMesh.new()
		box.size = size
		_mesh.mesh = box
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		_collider.shape = box_shape
	else:
		# Cylinders use size.x as the diameter and size.y as the height.
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 16
		_mesh.mesh = cylinder
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = size.x * 0.5
		cylinder_shape.height = size.y
		_collider.shape = cylinder_shape
	_mesh.material_override = MapMaterials.get_material(surface)
