class_name MainMenu
extends Control
## Placeholder flat-screen menu for connecting and picking a room.
## Will be replaced by an in-world VR menu later.

signal style_changed(color_index: int, hat_index: int)

var color_index := 0
var hat_index := 0

var _address: LineEdit
var _name: LineEdit
var _code: LineEdit
var _status: Label
var _pending_action: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 320
	center.add_child(box)

	# Remember the last server and name; fall back to the build's defaults.
	var settings := ConfigFile.new()
	settings.load(GameConfig.SETTINGS_PATH)
	_address = _add_field(box, "Server", settings.get_value("menu", "server",
			"%s:%d" % [GameConfig.default_address(), GameConfig.DEFAULT_PORT]))
	_name = _add_field(box, "Name", settings.get_value("menu", "name", GameConfig.DEFAULT_NAME))
	_name.max_length = GameConfig.MAX_NAME_LENGTH
	color_index = AvatarStyle.clean_color(settings.get_value("menu", "color", 0))
	hat_index = AvatarStyle.clean_hat(settings.get_value("menu", "hat", 0))
	_add_style_picker(box)
	_code = _add_field(box, "Room code", "")
	_code.max_length = GameConfig.ROOM_CODE_LENGTH

	_add_button(box, "Quick Play", func() -> void: _run(Network.quick_play))
	_add_button(box, "Join Code", func() -> void: _run(Network.join_room.bind(_code.text)))
	_add_button(box, "Create Private Room", func() -> void: _run(Network.create_room.bind(false)))
	_status = Label.new()
	box.add_child(_status)
	var wallet := Label.new()
	box.add_child(wallet)
	var show_wallet := func() -> void:
		wallet.text = "Teeth %d · Relics %d" % [Profile.teeth, Profile.relics]
	Profile.changed.connect(show_wallet)
	show_wallet.call()
	if Profile.is_banned():
		_set_status(_ban_text())

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
	if Profile.blocked_from_playing():
		_set_status(_ban_text())
		return
	if Network.is_connected_to_server():
		action.call()
		return
	_pending_action = action
	var host := _address.text.strip_edges()
	var port := GameConfig.DEFAULT_PORT
	if host.contains(":"):
		port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	_save_settings()
	_set_status("Connecting...")
	if Network.connect_to_server(host, port, _name.text) != OK:
		_set_status("Could not connect")


func _on_connected() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
		_pending_action = Callable()


func _ban_text() -> String:
	var hours := ceili((Profile.banned_until - Time.get_unix_time_from_system()) / 3600.0)
	return "Your save file was edited. This device is banned for %d more hours." % hours


func _save_settings() -> void:
	var settings := ConfigFile.new()
	settings.load(GameConfig.SETTINGS_PATH)
	settings.set_value("menu", "server", _address.text.strip_edges())
	settings.set_value("menu", "name", _name.text)
	settings.set_value("menu", "color", color_index)
	settings.set_value("menu", "hat", hat_index)
	settings.save(GameConfig.SETTINGS_PATH)


func _add_style_picker(parent: Control) -> void:
	var swatches := HBoxContainer.new()
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(swatches)
	for i in AvatarStyle.COLORS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		var style := StyleBoxFlat.new()
		style.bg_color = AvatarStyle.COLORS[i]
		style.set_corner_radius_all(17)
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func() -> void: _pick_style(i, hat_index))
		swatches.add_child(swatch)

	var hats := HBoxContainer.new()
	parent.add_child(hats)
	var hat_label := Label.new()
	hat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cycle := func(step: int) -> void:
		_pick_style(color_index, posmod(hat_index + step, AvatarStyle.HATS.size()))
	_add_button(hats, "<", cycle.bind(-1))
	hats.add_child(hat_label)
	_add_button(hats, ">", cycle.bind(1))
	style_changed.connect(func(_c: int, hat: int) -> void: hat_label.text = "Hat: " + AvatarStyle.HATS[hat])
	_pick_style.call_deferred(color_index, hat_index) # after listeners connect


func _pick_style(color: int, hat: int) -> void:
	color_index = color
	hat_index = hat
	Network.set_style(color_index, hat_index)
	_save_settings()
	style_changed.emit(color_index, hat_index)


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
