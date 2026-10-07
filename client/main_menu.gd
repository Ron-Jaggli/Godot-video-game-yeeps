class_name MainMenu
extends Control
## Placeholder flat-screen menu for connecting and picking a room.
## Will be replaced by an in-world VR menu later.

var _address: LineEdit
var _name: LineEdit
var _code: LineEdit
var _status: Label
var _pending_action: Callable


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 320
	center.add_child(box)

	_address = _add_field(box, "Server", "%s:%d" % [GameConfig.DEFAULT_ADDRESS, GameConfig.DEFAULT_PORT])
	_name = _add_field(box, "Name", GameConfig.DEFAULT_NAME)
	_name.max_length = GameConfig.MAX_NAME_LENGTH
	_code = _add_field(box, "Room code", "")
	_code.max_length = GameConfig.ROOM_CODE_LENGTH

	_add_button(box, "Quick Play", func() -> void: _run(Network.quick_play))
	_add_button(box, "Join Code", func() -> void: _run(Network.join_room.bind(_code.text)))
	_add_button(box, "Create Private Room", func() -> void: _run(Network.create_room.bind(false)))
	_status = Label.new()
	box.add_child(_status)

	Network.connected.connect(_on_connected)
	Network.connection_failed.connect(func() -> void: _set_status("Could not connect"))
	Network.disconnected.connect(func() -> void:
		visible = true
		_set_status("Disconnected"))
	Network.joined_room.connect(func(code: String) -> void:
		visible = false
		_set_status("In room " + code))
	Network.join_failed.connect(func(err: int) -> void:
		_set_status(Protocol.join_error_text(err)))
	Network.kicked.connect(func(reason: int) -> void:
		_set_status(Protocol.kick_reason_text(reason)))


## Connects first if needed, then runs the room action.
func _run(action: Callable) -> void:
	if Network.is_connected_to_server():
		action.call()
		return
	_pending_action = action
	var host := _address.text.strip_edges()
	var port := GameConfig.DEFAULT_PORT
	if host.contains(":"):
		port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	_set_status("Connecting...")
	if Network.connect_to_server(host, port, _name.text) != OK:
		_set_status("Could not connect")


func _on_connected() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
		_pending_action = Callable()


func _set_status(text: String) -> void:
	_status.text = text


func _add_field(parent: Control, label: String, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = label
	edit.text = value
	parent.add_child(edit)
	return edit


func _add_button(parent: Control, label: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(on_pressed)
	parent.add_child(button)
