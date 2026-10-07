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
@export var color_index := 0:
	set(value):
		color_index = value
		_restyle()
@export var hat_index := 0:
	set(value):
		hat_index = value
		_restyle()

var anticheat: AntiCheat # server only

var _avatar: Avatar # clients only
var _filter_added := false

@onready var input: PlayerInput = $Input


func _enter_tree() -> void:
	# Node name is the peer id; it is already set when spawned on clients.
	$Input.set_multiplayer_authority(str(name).to_int())
	if multiplayer.is_server() and not _filter_added:
		_filter_added = true
		# Before ServerSync enters the tree, or its first update goes to every peer.
		# It must stay publicly visible: Godot ANDs filters with the public/per-peer
		# flags, so the room filter alone decides who sees us.
		$ServerSync.add_visibility_filter(_is_visible_to)


func _ready() -> void:
	if multiplayer.is_server():
		set_process(false)
	else:
		set_physics_process(false)
		_avatar = Avatar.new()
		_avatar.set_display_name(display_name)
		add_child(_avatar)
		_restyle()
		# Our own avatar stays hidden: the local rig already draws our hands lag-free.
		_avatar.visible = peer_id != multiplayer.get_unique_id()
		print("[room %s] %s joined (color %d, %s)" % [get_parent().get_parent().name, display_name,
				color_index, AvatarStyle.HATS[AvatarStyle.clean_hat(hat_index)]])


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
	_avatar.set_pose(head_transform, left_hand_transform, right_hand_transform)


func _restyle() -> void:
	if _avatar:
		_avatar.set_style(color_index, hat_index)
