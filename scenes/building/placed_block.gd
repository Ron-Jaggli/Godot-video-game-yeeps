class_name PlacedBlock
extends StaticBody3D
## A block someone built. The server creates it and replicates it to the
## players in that room; everyone can climb on it, only its owner can pick it up.

@export var type_id := 0
@export var cell := Vector3i.ZERO
@export var axis := 0
@export var owner_peer := 0

var _filter_added := false


func _enter_tree() -> void:
	# Before Sync enters the tree, so its first update only goes to the room.
	if multiplayer.is_server() and not _filter_added:
		_filter_added = true
		$Sync.add_visibility_filter(_is_visible_to)


func _ready() -> void:
	position = BlockShapes.center(cell, type_id, axis)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BlockShapes.make_mesh(type_id, axis)
	mesh.material_override = BlockShapes.material(type_id)
	add_child(mesh)
	var box := BoxShape3D.new()
	box.size = BlockShapes.size_m(type_id, axis)
	var shape := CollisionShape3D.new()
	shape.shape = box
	add_child(shape)


func occupied_cells() -> Array[Vector3i]:
	return BlockShapes.cells(cell, type_id, axis)


func _is_visible_to(peer: int) -> bool:
	var room := get_parent().get_parent() as Room if get_parent() else null
	return room != null and room.has_member(peer)
