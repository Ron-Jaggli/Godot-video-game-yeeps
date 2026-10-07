extends Node
## Entry point for both builds.
##
##   Dedicated server:  godot --headless -- --server [--port=7777]
##   Client (menu):     godot
##   Scripted client:   godot -- --connect [--address=IP] [--port=7777]
##                        [--name=Bob] [--join=CODE | --create-private] [--bot]
##                        [--color=0-7] [--hat=0-4]
##                      (--bot = no rig, fake moving pose; add --headless for load tests)
## Exports with the "dedicated_server" feature tag always boot as server.

const XR_PLAYER_SCENE := preload("res://scenes/xr/xr_player.tscn")

@onready var rooms: Node3D = $Rooms

# Client only.
var _rig: XRPlayer
var _menu: MainMenu
var _lobby: Node3D # local space shown before joining; disabled while in a room
var _preview: Avatar # shows your chosen style in the lobby


func _ready() -> void:
	var args := _parse_user_args()
	if args.has("server") or OS.has_feature("dedicated_server"):
		_start_server(args)
	else:
		_start_client(args)


func _start_server(args: Dictionary) -> void:
	var port := int(args.get("port", GameConfig.DEFAULT_PORT))
	var err := Network.start_server(port)
	if err != OK:
		push_error("Failed to start server on port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	var server := Server.new(rooms)
	Network.server = server
	add_child(server)
	Server.log_msg("server listening on port %d (protocol v%d)" % [port, GameConfig.PROTOCOL_VERSION])


func _start_client(args: Dictionary) -> void:
	Network.bot_mode = args.has("bot")
	Network.set_style(int(args.get("color", 0)), int(args.get("hat", 0)))
	Network.join_failed.connect(func(err: int) -> void:
		print("join failed: ", Protocol.join_error_text(err)))
	Network.kicked.connect(func(reason: int) -> void:
		print("kicked: ", Protocol.kick_reason_text(reason)))

	if not Network.bot_mode:
		_setup_local_player(not args.has("connect"))
	if not args.has("connect"):
		return

	# Scripted client, for headless testing and bots.
	Network.connected.connect(func() -> void:
		if args.has("join"):
			Network.join_room(args["join"])
		elif args.has("create-private"):
			Network.create_room(false)
		else:
			Network.quick_play()
	)
	Network.joined_room.connect(func(code: String) -> void: print("joined room ", code))
	Network.connection_failed.connect(func() -> void: get_tree().quit(1))
	Network.disconnected.connect(func() -> void: get_tree().quit())
	Network.connect_to_server(
		args.get("address", GameConfig.default_address()),
		int(args.get("port", GameConfig.DEFAULT_PORT)),
		args.get("name", GameConfig.DEFAULT_NAME))


func _setup_local_player(with_menu: bool) -> void:
	_lobby = _make_lobby()
	add_child(_lobby)
	_rig = XR_PLAYER_SCENE.instantiate()
	add_child(_rig)
	_rig.menu_requested.connect(func() -> void:
		if rooms.get_child_count() > 0:
			Network.leave_room())

	_preview = Avatar.new()
	_preview.smooth = false
	_preview.set_display_name("You")
	_lobby.add_child(_preview)
	_apply_style(Network.color_index, Network.hat_index)

	if with_menu:
		_menu = MainMenu.new()
		_menu.style_changed.connect(_apply_style)
		if _rig.is_vr:
			var panel := WorldPanel.new(_menu)
			panel.position = Vector3(0, 1.4, -1.2)
			_lobby.add_child(panel)
		else:
			add_child(_menu)

	rooms.child_entered_tree.connect(func(room: Node) -> void: _enter_room.call_deferred(room))
	rooms.child_exiting_tree.connect(func(_room: Node) -> void: _exit_room.call_deferred())


func _apply_style(color_index: int, hat_index: int) -> void:
	_preview.set_style(color_index, hat_index)
	_rig.set_hand_color(AvatarStyle.color(color_index).darkened(0.35))


## Lobby preview: stands to the right of the menu, facing you, waving.
func _process(_delta: float) -> void:
	if _preview == null or not _lobby.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var base := Vector3(1.0, 1.35, -1.9)
	var facing := Basis.looking_at(Vector3(-base.x, 0.0, -base.z)) # toward the lobby centre
	var head := Transform3D(facing.rotated(Vector3.UP, sin(t * 0.7) * 0.15), base + Vector3.UP * sin(t * 1.3) * 0.02)
	var left := Transform3D(facing, base + facing * Vector3(-0.3, -0.55, -0.1))
	var right := Transform3D(facing, base + facing * Vector3(0.32 + sin(t * 5.0) * 0.08, 0.2, -0.12))
	_preview.set_pose(head, left, right)


func _enter_room(room: Room) -> void:
	_set_lobby_active(false)
	_rig.teleport(room.get_node("SpawnPoint").global_transform)


func _exit_room() -> void:
	_set_lobby_active(true)
	_rig.teleport(Transform3D.IDENTITY)
	if _menu:
		_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Disabled nodes drop out of physics too, so the lobby floor can't overlap the room's.
func _set_lobby_active(active: bool) -> void:
	_lobby.visible = active
	_lobby.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _make_lobby() -> Node3D:
	var size := Vector3(6, 1, 6)
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var ground := StaticBody3D.new()
	ground.position.y = -0.5
	ground.add_child(mesh)
	ground.add_child(collision)
	var lobby := Node3D.new()
	lobby.name = "Lobby"
	lobby.add_child(ground)
	return lobby


## "--key=value" -> {key: value}, "--flag" -> {flag: true}
func _parse_user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	return args
