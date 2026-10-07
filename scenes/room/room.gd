class_name Room
extends Node3D
## One game instance (lobby/map) with up to MAX_PLAYERS_PER_ROOM players.
## The server owns it; it is only replicated to its members, so players in
## other rooms never receive its nodes or traffic.

signal emptied

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@export var room_code := ""

# Server-only state.
var is_public := true
var anticheat: AntiCheat
var _members: Array[int] = []

@onready var players: Node3D = $Players
@onready var _sync: MultiplayerSynchronizer = $RoomSync


func add_member(peer_id: int, display_name: String, color_index: int, hat_index: int) -> void:
	_members.append(peer_id)
	_sync.set_visibility_for(peer_id, true)

	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.display_name = display_name
	player.color_index = color_index
	player.hat_index = hat_index
	player.anticheat = anticheat
	players.add_child(player, true)


func remove_member(peer_id: int) -> void:
	_members.erase(peer_id)
	if peer_id in multiplayer.get_peers(): # skip if they already disconnected
		_sync.set_visibility_for(peer_id, false)
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
	if _members.is_empty():
		emptied.emit()


func set_member_style(peer_id: int, color_index: int, hat_index: int) -> void:
	var player := players.get_node_or_null(str(peer_id)) as Player
	if player:
		player.color_index = color_index
		player.hat_index = hat_index


func has_member(peer_id: int) -> bool:
	return peer_id in _members


func member_count() -> int:
	return _members.size()


func is_full() -> bool:
	return _members.size() >= GameConfig.MAX_PLAYERS_PER_ROOM
