@tool
class_name QuestBoard
extends Node3D
## A wooden board showing daily and weekly quests. Face its +Z toward players.

func _ready() -> void:
	add_to_group("no_merge")
	var frame := MapBlock.new()
	frame.size = Vector3(2.4, 1.9, 0.12)
	frame.surface = MapMaterials.Surface.WOOD
	frame.position = Vector3(0, 1.9, -0.08)
	add_child(frame)
	for side in [-1.0, 1.0]:
		var post := MapBlock.new()
		post.size = Vector3(0.14, 2.9, 0.14)
		post.surface = MapMaterials.Surface.WOOD
		post.position = Vector3(1.25 * side, 1.45, -0.08)
		add_child(post)
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var panel := WorldPanel.new(QuestPanel.new(), Vector2i(1000, 760))
		panel.scale = Vector3.ONE * 1.3
		panel.position = Vector3(0, 1.9, 0.0)
		add_child(panel)
