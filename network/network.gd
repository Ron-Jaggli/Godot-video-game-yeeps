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

var is_server := false
var server: Server # set on the dedicated server only
## Debug/load-test client: fakes a moving pose when no XR rig is present.
var bot_mode := false

var _connected := false
var _display_name := GameConfig.DEFAULT_NAME
var color_index := 0
var hat_index := 0


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
	_client_kicked.rpc_id(peer_id, reason)
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


## Tell the server we teleported to a spawn point, so the anticheat doesn't
## flag the jump.
func notify_respawned() -> void:
	_server_respawned.rpc_id(1)


## Can be called any time; the server applies it to our avatar if we're in a room.
func set_style(color: int, hat: int) -> void:
	color_index = color
	hat_index = hat
	if _connected:
		_server_set_style.rpc_id(1, color_index, hat_index)


func _on_connected_to_server() -> void:
	_connected = true
	# Keep _server_hello's signature fixed forever so old clients still get a
	# clean version-mismatch kick; everything else goes in separate RPCs.
	_server_hello.rpc_id(1, GameConfig.PROTOCOL_VERSION, _display_name)
	_server_set_style.rpc_id(1, color_index, hat_index)
	connected.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	_connected = false
	disconnected.emit()


# --- Client -> server RPCs ----------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _server_hello(version: int, display_name: String) -> void:
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
func _server_respawned() -> void:
	if is_server:
		server.handle_respawned(multiplayer.get_remote_sender_id())


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
func _client_kicked(reason: int) -> void:
	kicked.emit(reason)
