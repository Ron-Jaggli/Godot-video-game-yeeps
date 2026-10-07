@tool
class_name DeadTree
extends StaticBody3D
## Leafless tree generated from a seed: a tapered, slightly leaning trunk with
## climbable branches. Every segment has a collider so hands can grab it.
## Change the seed in the inspector for a different tree.

@export var tree_seed := 1:
	set(value):
		tree_seed = value
		_rebuild()
@export var height := 6.0:
	set(value):
		height = value
		_rebuild()
@export_range(0, 8) var branch_count := 5:
	set(value):
		branch_count = value
		_rebuild()

const TRUNK_RADIUS := 0.35

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
	rng.seed = tree_seed
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12)).normalized()
	var top := lean * height
	_segment(Vector3.ZERO, top, TRUNK_RADIUS, TRUNK_RADIUS * 0.35)

	for i in branch_count:
		var t := rng.randf_range(0.35, 0.9)
		var start := top * t
		var angle := rng.randf() * TAU
		var out := Vector3(cos(angle), rng.randf_range(0.25, 0.9), sin(angle)).normalized()
		var length := rng.randf_range(1.2, 2.6) * (1.2 - t * 0.5)
		var end := start + out * length
		var radius := TRUNK_RADIUS * (1.0 - t) * 0.7 + 0.05
		_segment(start, end, radius, radius * 0.4)
		# A crooked twig off the end of longer branches.
		if length > 1.6:
			var twig := (out + Vector3(rng.randf_range(-0.8, 0.8), 0.6, rng.randf_range(-0.8, 0.8))).normalized()
			_segment(end, end + twig * length * 0.45, radius * 0.4, 0.02)


func _segment(a: Vector3, b: Vector3, bottom_radius: float, top_radius: float) -> void:
	var span := b - a
	var length := span.length()
	var y := span / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var transform_ := Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)

	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = transform_
	instance.material_override = MapMaterials.get_material(MapMaterials.Surface.WOOD)
	add_child(instance)
	_parts.append(instance)

	var shape := CylinderShape3D.new()
	shape.radius = maxf((bottom_radius + top_radius) * 0.5, 0.04)
	shape.height = length
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = transform_
	add_child(collider)
	_parts.append(collider)
