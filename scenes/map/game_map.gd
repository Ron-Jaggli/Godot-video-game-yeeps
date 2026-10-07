class_name GameMap
extends Node3D
## Root of a playable map. Maps provide spawn points (Marker3D children of
## SpawnPoints) and a kill height below which players respawn.

@export var kill_height := -15.0


## Spreads players across spawn points so they don't spawn inside each other.
func spawn_transform(peer_id: int) -> Transform3D:
	var points := $SpawnPoints.get_children()
	if points.is_empty():
		return global_transform
	return (points[peer_id % points.size()] as Node3D).global_transform


func _ready() -> void:
	if DisplayServer.get_name() != "headless": # nothing to draw on a server
		_merge_static_meshes()


## Every prop is its own MeshInstance, which keeps maps easy to edit but costs
## hundreds of draw calls. At runtime, fold them into one mesh per material
## (about a dozen draws for the whole map), which Quest can afford.
func _merge_static_meshes() -> void:
	var tools := {} # Material -> SurfaceTool
	var merged_away: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var material := instance.material_override
		if material == null or instance.mesh == null or not instance.is_visible_in_tree():
			continue
		if not tools.has(material):
			var surface_tool := SurfaceTool.new()
			surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = surface_tool
		var to_map := global_transform.affine_inverse() * instance.global_transform
		tools[material].append_from(instance.mesh, 0, to_map)
		merged_away.append(instance)

	for material: Material in tools:
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = tools[material].commit()
		merged.material_override = material
		add_child(merged)
	for instance in merged_away:
		instance.visible = false
