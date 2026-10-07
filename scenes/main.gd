extends Node
## Entry point for both builds.
##
##   Dedicated server:  godot --headless -- --server [--port=7777]
##   Client (menu):     godot
##   Headless client:   godot --headless -- --connect [--address=IP] [--port=7777]
##                        [--name=Bob] [--join=CODE | --create-private] [--bot]
## Exports with the "dedicated_server" feature tag always boot as server.

@onready var rooms: Node3D = $Rooms


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
	Network.join_failed.connect(func(err: int) -> void:
		print("join failed: ", Protocol.join_error_text(err)))
	Network.kicked.connect(func(reason: int) -> void:
		print("kicked: ", Protocol.kick_reason_text(reason)))

	if not args.has("connect"):
		add_child(MainMenu.new())
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
		args.get("address", GameConfig.DEFAULT_ADDRESS),
		int(args.get("port", GameConfig.DEFAULT_PORT)),
		args.get("name", GameConfig.DEFAULT_NAME))


## "--key=value" -> {key: value}, "--flag" -> {flag: true}
func _parse_user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	return args
