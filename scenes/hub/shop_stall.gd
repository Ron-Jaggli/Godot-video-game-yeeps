@tool
class_name ShopStall
extends Node3D
## One stall in the hub: a plinth with the item floating above it and a shop
## panel behind. Face the stall's +Z toward where players stand. Every block
## (and later every gadget) gets its own stall.

@export var block_type := 0:
	set(value):
		block_type = value
		_rebuild()

var _parts: Array[Node] = []
var _display: MeshInstance3D


func _ready() -> void:
	add_to_group("no_merge")
	_rebuild()
	set_process(not Engine.is_editor_hint())
	# The shop UI is client-only; servers and the editor just get the plinth.
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var panel := WorldPanel.new(ShopPanel.new(block_type))
		panel.position = Vector3(0, 2.0, -0.45)
		add_child(panel)


func _process(delta: float) -> void:
	_display.rotate_y(delta * 0.6)


func _rebuild() -> void:
	if not is_inside_tree() or not Economy.is_valid_block(block_type):
		return
	for part in _parts:
		part.free()
	_parts.clear()

	var plinth := MapBlock.new()
	plinth.size = Vector3(0.9, 1.0, 0.9)
	plinth.surface = MapMaterials.Surface.DARK_STONE
	plinth.position.y = 0.5
	add_child(plinth)
	_parts.append(plinth)

	# A shrunken copy of the block, like the one you hold when building.
	_display = MeshInstance3D.new()
	_display.mesh = BlockShapes.make_mesh(block_type, 0)
	_display.material_override = BlockShapes.material(block_type)
	var size := BlockShapes.size_m(block_type, 0)
	_display.scale = Vector3.ONE * (0.45 / maxf(size.x, maxf(size.y, size.z)))
	_display.position.y = 1.35
	add_child(_display)
	_parts.append(_display)
