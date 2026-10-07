class_name Room
extends Node3D
## One game instance (lobby/map) with up to MAX_PLAYERS_PER_ROOM players.
## The server owns it; it is only replicated to its members, so players in
## other rooms never receive its nodes or traffic.

signal emptied

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BLOCK_SCENE := preload("res://scenes/building/placed_block.tscn")

@export var room_code := ""

# Server-only state.
var is_public := true
var anticheat: AntiCheat
var _members: Array[int] = []
var _occupied := {} # Vector3i cell -> block node name
var _block_counts := {} # peer_id -> number of blocks they have placed
var _next_block_id := 0

@onready var players: Node3D = $Players
@onready var blocks: Node3D = $Blocks
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
	_remove_blocks_of(peer_id)
	if _members.is_empty():
		emptied.emit()


## Server: places a block if it's in bounds, free, within reach of one of the
## player's hands and under the block limits. Marrow is checked by the caller.
func place_block(peer_id: int, type_id: int, cell: Vector3i, axis: int) -> bool:
	var e := Economy.BUILD_HALF_EXTENT_CELLS
	var size := BlockShapes.size_cells(type_id, axis)
	if cell.x < -e or cell.z < -e or cell.y < 0 or cell.x + size.x > e or cell.z + size.z > e \
			or cell.y + size.y > Economy.BUILD_MAX_HEIGHT_CELLS:
		return false
	if _block_counts.get(peer_id, 0) >= Economy.MAX_BLOCKS_PER_PLAYER or blocks.get_child_count() >= Economy.MAX_BLOCKS_PER_ROOM:
		return false
	if not _within_reach(peer_id, BlockShapes.center(cell, type_id, axis)):
		return false
	var footprint := BlockShapes.cells(cell, type_id, axis)
	for c in footprint:
		if _occupied.has(c):
			return false

	var block: PlacedBlock = BLOCK_SCENE.instantiate()
	block.name = "B%d" % _next_block_id
	_next_block_id += 1
	block.type_id = type_id
	block.cell = cell
	block.axis = axis
	block.owner_peer = peer_id
	blocks.add_child(block, true)
	for c in footprint:
		_occupied[c] = block.name
	_block_counts[peer_id] = _block_counts.get(peer_id, 0) + 1
	return true


## Server: picks up one of the player's own blocks. Returns the Marrow refund,
## or 0 if they can't take it.
func remove_block(peer_id: int, block_name: String) -> int:
	var block := blocks.get_node_or_null(block_name) as PlacedBlock
	if block == null or block.owner_peer != peer_id or block.is_queued_for_deletion():
		return 0
	if not _within_reach(peer_id, block.position):
		return 0
	_free_block(block)
	return Economy.BLOCKS[block.type_id].marrow


func _remove_blocks_of(peer_id: int) -> void:
	for block: PlacedBlock in blocks.get_children():
		if block.owner_peer == peer_id and not block.is_queued_for_deletion():
			_free_block(block)


func _free_block(block: PlacedBlock) -> void:
	for c in block.occupied_cells():
		_occupied.erase(c)
	_block_counts[block.owner_peer] = _block_counts.get(block.owner_peer, 1) - 1
	block.queue_free()


## Reach is measured from the server's validated hand positions, so a client
## can't build across the map.
func _within_reach(peer_id: int, point: Vector3) -> bool:
	var player := players.get_node_or_null(str(peer_id)) as Player
	if player == null:
		return false
	# Big blocks are reached at their surface, not their centre.
	var slack := Economy.CELL.length()
	for hand in [player.left_hand_transform.origin, player.right_hand_transform.origin]:
		if hand.distance_to(point) <= Economy.BUILD_REACH + slack:
			return true
	return false


func set_member_style(peer_id: int, color_index: int, hat_index: int) -> void:
	var player := players.get_node_or_null(str(peer_id)) as Player
	if player:
		player.color_index = color_index
		player.hat_index = hat_index


func spawn_transform(peer_id: int) -> Transform3D:
	return ($Map as GameMap).spawn_transform(peer_id)


## Spawn positions in world space (rooms sit at the origin), for the anticheat.
func spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for marker: Node3D in $Map/SpawnPoints.get_children():
		points.append(marker.global_position)
	return points


func hub_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for marker: Node3D in $Hub/SpawnPoints.get_children():
		points.append(marker.global_position)
	return points


func hub_spawn_transform(peer_id: int) -> Transform3D:
	return ($Hub as GameMap).spawn_transform(peer_id)


func kill_height() -> float:
	return ($Map as GameMap).kill_height


func has_member(peer_id: int) -> bool:
	return peer_id in _members


func member_count() -> int:
	return _members.size()


func is_full() -> bool:
	return _members.size() >= GameConfig.MAX_PLAYERS_PER_ROOM
