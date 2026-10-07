class_name PlayerInput
extends Node
## Pose reported by the owning client. Replicated client -> server only; the
## server never trusts it directly (see Player._physics_process).
##
## The future XR rig should add itself to the "local_xr_rig" group and expose
## head_transform / left_hand_transform / right_hand_transform.

@export var head_transform := Transform3D.IDENTITY
@export var left_hand_transform := Transform3D.IDENTITY
@export var right_hand_transform := Transform3D.IDENTITY

var _bot_time := 0.0


func _ready() -> void:
	if not is_multiplayer_authority() or multiplayer.is_server():
		set_process(false)
		return
	# Only the server needs our input; other clients get the validated pose.
	$InputSync.set_visibility_for(1, true)


func _process(delta: float) -> void:
	var rig := get_tree().get_first_node_in_group("local_xr_rig")
	if rig:
		head_transform = rig.head_transform
		left_hand_transform = rig.left_hand_transform
		right_hand_transform = rig.right_hand_transform
	elif Network.bot_mode:
		_bot_time += delta
		var pos := Vector3(cos(_bot_time), 1.6, sin(_bot_time)) * Vector3(2, 1, 2)
		head_transform = Transform3D(Basis(), pos)
		left_hand_transform = Transform3D(Basis(), pos + Vector3(-0.3, -0.4, 0))
		right_hand_transform = Transform3D(Basis(), pos + Vector3(0.3, -0.4, 0))
