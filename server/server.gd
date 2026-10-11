class_name Server
extends Node
## Dedicated server. Tracks connected clients and routes their requests to rooms.
## Only created when the game boots with --server.


class ClientInfo:
	var display_name := ""
	var color_index := 0
	var hat_index := 0
	var room: Room
	var device_id := "" # set by identify; required before joining a room
	## Block types this player may place. Ownership and rentals are kept on the
	## device (by design for now), so this is the client's word.
	var usable_blocks: Array[int] = []
	var owned_blocks: Array[int] = [] # usable_blocks minus this room's rentals
	var marrow := 0.0
	var marrow_sent := -1


const MARROW_SEND_INTERVAL := 0.25

var room_manager: RoomManager
var anticheat := AntiCheat.new()
var bans := BanList.new()
var _marrow_timer := 0.0

var _clients := {} # peer_id -> ClientInfo (only after a valid hello)


func _init(rooms_root: Node) -> void:
	name = "Server"
	room_manager = RoomManager.new(rooms_root, anticheat)


func _ready() -> void:
	Engine.physics_ticks_per_second = GameConfig.SERVER_TICK_RATE
	add_child(room_manager)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	anticheat.strike_limit_reached.connect(func(peer_id: int) -> void:
		log_msg("anticheat kicked peer %d" % peer_id)
		Network.kick(peer_id, Protocol.KickReason.CHEATING)
	)


func _on_peer_connected(peer_id: int) -> void:
	log_msg("peer %d connected" % peer_id)
	get_tree().create_timer(GameConfig.HELLO_TIMEOUT_SEC).timeout.connect(func() -> void:
		if peer_id in multiplayer.get_peers() and not _clients.has(peer_id):
			Network.kick(peer_id, Protocol.KickReason.HELLO_TIMEOUT)
	)


func _on_peer_disconnected(peer_id: int) -> void:
	log_msg("peer %d disconnected" % peer_id)
	handle_leave_room(peer_id)
	_clients.erase(peer_id)
	anticheat.forget(peer_id)


func handle_hello(peer_id: int, version: int, display_name: String) -> void:
	if version != GameConfig.PROTOCOL_VERSION:
		Network.kick(peer_id, Protocol.KickReason.VERSION_MISMATCH)
		return
	var info := ClientInfo.new()
	info.display_name = _sanitize_name(display_name)
	_clients[peer_id] = info
	log_msg("peer %d registered as '%s'" % [peer_id, info.display_name])


func handle_identify(peer_id: int, device_id: String, tampered: bool, usable: PackedInt32Array) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or not info.device_id.is_empty():
		return
	if device_id.length() != 32 or not device_id.is_valid_hex_number():
		Network.kick(peer_id, Protocol.KickReason.CHEATING)
		return
	if tampered:
		log_msg("device %s reported an edited save; banning %d h" % [device_id, Economy.TAMPER_BAN_HOURS])
		bans.ban(device_id, Economy.TAMPER_BAN_HOURS)
	if bans.remaining(device_id) > 0:
		Network.kick(peer_id, Protocol.KickReason.BANNED)
		return
	info.device_id = device_id
	for type_id in usable:
		if Economy.is_valid_block(type_id) and type_id not in info.owned_blocks:
			info.owned_blocks.append(type_id)
	for starter in Economy.starter_blocks():
		if starter not in info.owned_blocks:
			info.owned_blocks.append(starter)
	info.usable_blocks = info.owned_blocks.duplicate()
	info.marrow = Economy.MARROW_START


func handle_teleported(peer_id: int, destination: int) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or info.room == null:
		return
	var points := info.room.hub_points() if destination == Protocol.Teleport.HUB else info.room.spawn_points()
	anticheat.expect_respawn(peer_id, points)


## A purchase or rental on the client. Rentals last until the player leaves the room.
func handle_unlock_block(peer_id: int, type_id: int, owned: bool) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or not Economy.is_valid_block(type_id):
		return
	if type_id not in info.usable_blocks:
		info.usable_blocks.append(type_id)
	if owned and type_id not in info.owned_blocks:
		info.owned_blocks.append(type_id)


func handle_place_block(peer_id: int, type_id: int, cell: Vector3i, axis: int) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or info.room == null or not Economy.is_valid_block(type_id):
		return
	if type_id not in info.usable_blocks or axis < 0 or axis > 2:
		return
	var price: int = Economy.BLOCKS[type_id].marrow
	if info.marrow < price:
		return
	if info.room.place_block(peer_id, type_id, cell, axis):
		info.marrow -= price


func handle_remove_block(peer_id: int, block_name: String) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or info.room == null:
		return
	var refund := info.room.remove_block(peer_id, block_name)
	if refund > 0:
		info.marrow = minf(info.marrow + refund, Economy.MARROW_MAX)


## Marrow refills over time, and each player hears about their own balance.
func _physics_process(delta: float) -> void:
	_marrow_timer += delta
	var send := _marrow_timer >= MARROW_SEND_INTERVAL
	if send:
		_marrow_timer = 0.0
	for peer_id: int in _clients:
		var info: ClientInfo = _clients[peer_id]
		if info.device_id.is_empty():
			continue
		info.marrow = minf(info.marrow + Economy.MARROW_REGEN_PER_SEC * delta, Economy.MARROW_MAX)
		if send and int(info.marrow) != info.marrow_sent:
			info.marrow_sent = int(info.marrow)
			Network._client_marrow.rpc_id(peer_id, info.marrow_sent)


func handle_set_style(peer_id: int, color: int, hat: int) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null:
		return
	info.color_index = AvatarStyle.clean_color(color)
	info.hat_index = AvatarStyle.clean_hat(hat)
	if info.room:
		info.room.set_member_style(peer_id, info.color_index, info.hat_index)


func handle_join_room(peer_id: int, code: String) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	var err := _check_can_join(info)
	if err != Protocol.JoinError.NONE:
		_reply(peer_id, err)
		return

	var room: Room
	if code.is_empty():
		room = room_manager.find_open_public_room()
		if room == null:
			room = room_manager.create_room(true)
	else:
		code = code.strip_edges().to_upper()
		if not RoomManager.is_valid_code(code):
			_reply(peer_id, Protocol.JoinError.BAD_CODE)
			return
		room = room_manager.get_room(code)
		if room == null:
			_reply(peer_id, Protocol.JoinError.ROOM_NOT_FOUND)
			return
		if room.is_full():
			_reply(peer_id, Protocol.JoinError.ROOM_FULL)
			return

	_put_in_room(peer_id, info, room)


func handle_create_room(peer_id: int, is_public: bool) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	var err := _check_can_join(info)
	if err != Protocol.JoinError.NONE:
		_reply(peer_id, err)
		return
	_put_in_room(peer_id, info, room_manager.create_room(is_public))


func handle_leave_room(peer_id: int) -> void:
	var info: ClientInfo = _clients.get(peer_id)
	if info == null or info.room == null:
		return
	log_msg("'%s' left room %s" % [info.display_name, info.room.room_code])
	info.room.remove_member(peer_id)
	info.room = null
	info.usable_blocks = info.owned_blocks.duplicate() # rentals were for that room only


func _check_can_join(info: ClientInfo) -> int:
	if info == null or info.device_id.is_empty():
		return Protocol.JoinError.NOT_REGISTERED
	if info.room != null:
		return Protocol.JoinError.ALREADY_IN_ROOM
	return Protocol.JoinError.NONE


func _put_in_room(peer_id: int, info: ClientInfo, room: Room) -> void:
	info.room = room
	room.add_member(peer_id, info.display_name, info.color_index, info.hat_index)
	log_msg("'%s' joined room %s (%d/%d)" % [info.display_name, room.room_code,
			room.member_count(), GameConfig.MAX_PLAYERS_PER_ROOM])
	_reply(peer_id, Protocol.JoinError.NONE, room.room_code)


func _reply(peer_id: int, err: int, code := "") -> void:
	Network._client_join_result.rpc_id(peer_id, err, code)


func _sanitize_name(raw: String) -> String:
	var clean := ""
	for c in raw.strip_edges():
		if c.unicode_at(0) >= 32:
			clean += c
	clean = clean.substr(0, GameConfig.MAX_NAME_LENGTH)
	return clean if not clean.is_empty() else GameConfig.DEFAULT_NAME


static func log_msg(text: String) -> void:
	print("[%s] %s" % [Time.get_time_string_from_system(), text])
