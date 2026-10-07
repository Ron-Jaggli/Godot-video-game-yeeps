class_name Player
extends Node3D
## One per member of a Room. The server owns this node and the replicated pose;
## the owning client only drives the child Input node, which the server
## validates before copying it here.

@export var peer_id := 0
@export var display_name := ""
@export var head_transform := Transform3D.IDENTITY
@export var left_hand_transform := Transform3D.IDENTITY
@export var right_hand_transform := Transform3D.IDENTITY

var anticheat: AntiCheat # server only

@onready var input: PlayerInput = $Input
@onready var _head: Node3D = $Head
@onready var _left_hand: Node3D = $LeftHand
@onready var _right_hand: Node3D = $RightHand


func _enter_tree() -> void:
	# Node name is the peer id; it is already set when spawned on clients.
	$Input.set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	if multiplayer.is_server():
		# ServerSync must stay publicly visible: Godot ANDs filters with the
		# public/per-peer flags, so the room filter alone decides who sees us.
		$ServerSync.add_visibility_filter(_is_visible_to)
		set_process(false)
	else:
		set_physics_process(false)
		if peer_id == multiplayer.get_unique_id():
			# Our own avatar: the local rig already draws our hands lag-free.
			for part in [_head, _left_hand, _right_hand]:
				part.visible = false
		print("[room %s] %s joined" % [get_parent().get_parent().name, display_name])


func _exit_tree() -> void:
	# Not multiplayer.is_server(): after a disconnect there is no peer to ask.
	if not Network.is_server:
		print("[room %s] %s left" % [get_parent().get_parent().name, display_name])


func _is_visible_to(peer: int) -> bool:
	var room := get_parent().get_parent() as Room if get_parent() else null
	return room != null and room.has_member(peer)


func _physics_process(_delta: float) -> void:
	# Server: accept the client's reported pose only if it passes anticheat.
	if anticheat and not anticheat.validate_pose(peer_id, input.head_transform,
			input.left_hand_transform, input.right_hand_transform):
		return
	head_transform = input.head_transform
	left_hand_transform = input.left_hand_transform
	right_hand_transform = input.right_hand_transform


func _process(_delta: float) -> void:
	# Client: drive the avatar from the replicated (server-validated) pose.
	_head.transform = head_transform
	_left_hand.transform = left_hand_transform
	_right_hand.transform = right_hand_transform
