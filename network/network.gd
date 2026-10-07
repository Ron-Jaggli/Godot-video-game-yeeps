extends Node
## Autoload "Network". Owns the ENet peer and every client <-> server RPC.
## It lives at /root/Network on both sides, so RPC node paths always match.
## Server-bound RPCs are thin wrappers that hand off to the Server node.

signal connected
signal connection_failed
signal disconnected
signal joined_room(code: String)
signal join_failed(err: int)
signal kicked(reason: int)
signal marrow_changed(amount: int)

var is_server := false
var server: Server # set on the dedicated server only
## Debug/load-test client: fakes a moving pose when no XR rig is present.
var bot_mode := false

var _connected := false
var _display_name := GameConfig.DEFAULT_NAME
var color_index := 0
var hat_index := 0
## Building currency for this session; the server owns the real value.
var marrow := 0


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Server -----------------------------------------------------------------

func start_server(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameConfig.MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	return OK


func kick(peer_id: int, reason: int) -> void:
	if not is_server:
		return
	_01_client_kicked.rpc_id(peer_id, reason)
	# Give the reliable kick message a moment to go out before dropping them.
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if peer_id in multiplayer.get_peers():
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	)


# --- Client -----------------------------------------------------------------

func connect_to_server(address: String, port: int, display_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_display_name = display_name
	multiplayer.multiplayer_peer = peer
	return OK


func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer = null
	_connected = false


func is_connected_to_server() -> bool:
	return _connected


## Empty code = quick play into any open public room.
func join_room(code: String) -> void:
	_server_join_room.rpc_id(1, code)


func quick_play() -> void:
	join_room("")


func create_room(is_public: bool) -> void:
	_server_create_room.rpc_id(1, is_public)


func leave_room() -> void:
	_server_leave_room.rpc_id(1)


## Tell the server we teleported (respawn, hub), so the anticheat expects the
## jump. It only accepts landing on that destination's spawn points.
func notify_teleported(destination: Protocol.Teleport) -> void:
	_server_teleported.rpc_id(1, destination)


## Lets the server know we may now place this block type. Owned unlocks last
## the whole connection; rentals end when we leave the room.
func unlock_block(type_id: int, owned: bool) -> void:
	if _connected:
		_server_unlock_block.rpc_id(1, type_id, owned)


## Ask to place a block; the server checks Marrow, space and reach.
func place_block(type_id: int, cell: Vector3i, axis: int) -> void:
	_server_place_block.rpc_id(1, type_id, cell, axis)


## Pick one of our placed blocks back up (refunds its Marrow).
func remove_block(block_name: String) -> void:
	_server_remove_block.rpc_id(1, block_name)


## Can be called any time; the server applies it to our avatar if we're in a room.
func set_style(color: int, hat: int) -> void:
	color_index = color
	hat_index = hat
	if _connected:
		_server_set_style.rpc_id(1, color_index, hat_index)


func _on_connected_to_server() -> void:
	_connected = true
	_00_server_hello.rpc_id(1, GameConfig.PROTOCOL_VERSION, _display_name)
	_server_set_style.rpc_id(1, color_index, hat_index)
	var usable := PackedInt32Array(Profile.owned_blocks)
	usable.append_array(PackedInt32Array(Profile.rented_blocks))
	_server_identify.rpc_id(1, Profile.device_id, Profile.tamper_pending, usable)
	Profile.mark_tamper_reported()
	connected.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	_connected = false
	disconnected.emit()


# --- Client -> server RPCs ----------------------------------------------------

## Godot numbers RPCs by sorted name, so the "_00"/"_01" prefixes keep the
## version handshake and its kick at the same IDs in every release; never
## change their names or signatures, so old clients always get a clean
## "please update" kick. Everything else goes in separate RPCs.
@rpc("any_peer", "call_remote", "reliable")
func _00_server_hello(version: int, display_name: String) -> void:
	if is_server:
		server.handle_hello(multiplayer.get_remote_sender_id(), version, display_name)


@rpc("any_peer", "call_remote", "reliable")
func _server_join_room(code: String) -> void:
	if is_server:
		server.handle_join_room(multiplayer.get_remote_sender_id(), code)


@rpc("any_peer", "call_remote", "reliable")
func _server_create_room(is_public: bool) -> void:
	if is_server:
		server.handle_create_room(multiplayer.get_remote_sender_id(), is_public)


@rpc("any_peer", "call_remote", "reliable")
func _server_identify(device_id: String, tampered: bool, usable_blocks: PackedInt32Array) -> void:
	if is_server:
		server.handle_identify(multiplayer.get_remote_sender_id(), device_id, tampered, usable_blocks)


@rpc("any_peer", "call_remote", "reliable")
func _server_teleported(destination: int) -> void:
	if is_server:
		server.handle_teleported(multiplayer.get_remote_sender_id(), destination)


@rpc("any_peer", "call_remote", "reliable")
func _server_unlock_block(type_id: int, owned: bool) -> void:
	if is_server:
		server.handle_unlock_block(multiplayer.get_remote_sender_id(), type_id, owned)


@rpc("any_peer", "call_remote", "reliable")
func _server_place_block(type_id: int, cell: Vector3i, axis: int) -> void:
	if is_server:
		server.handle_place_block(multiplayer.get_remote_sender_id(), type_id, cell, axis)


@rpc("any_peer", "call_remote", "reliable")
func _server_remove_block(block_name: String) -> void:
	if is_server:
		server.handle_remove_block(multiplayer.get_remote_sender_id(), block_name)


@rpc("any_peer", "call_remote", "reliable")
func _server_set_style(color: int, hat: int) -> void:
	if is_server:
		server.handle_set_style(multiplayer.get_remote_sender_id(), color, hat)


@rpc("any_peer", "call_remote", "reliable")
func _server_leave_room() -> void:
	if is_server:
		server.handle_leave_room(multiplayer.get_remote_sender_id())


# --- Server -> client RPCs ----------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _client_join_result(err: int, code: String) -> void:
	if err == Protocol.JoinError.NONE:
		joined_room.emit(code)
	else:
		join_failed.emit(err)


@rpc("authority", "call_remote", "reliable")
func _client_marrow(amount: int) -> void:
	marrow = amount
	marrow_changed.emit(amount)


@rpc("authority", "call_remote", "reliable")
func _01_client_kicked(reason: int) -> void:
	kicked.emit(reason)
