class_name QuestZone
extends Node3D
## An invisible box that reports a quest stat when the local player reaches it
## (e.g. the belfry). Place it in a map and size it in the inspector.

signal reached(stat: String)

@export var stat := Quests.STAT_BELFRY
@export var size := Vector3(4, 2, 4)
## Seconds before the same zone counts again, so standing in it doesn't farm.
@export var cooldown := 60.0

var _ready_at := 0.0


func _ready() -> void:
	# Only ever sees the local player's body, so it's inert on the server.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameConfig.LAYER_LOCAL_PLAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(_body: Node) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		if now >= _ready_at:
			_ready_at = now + cooldown
			reached.emit(stat))
