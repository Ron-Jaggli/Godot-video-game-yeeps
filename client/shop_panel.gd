class_name ShopPanel
extends PanelContainer
## Stall UI for one block type: own it for good with Relics, or rent it for
## the current room with Teeth. Shown on a WorldPanel in the hub.

var _type_id: int
var _status: Label
var _own: Button
var _rent: Button
var _balances: Label


func _init(type_id: int) -> void:
	_type_id = type_id


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", dark_panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var block := Economy.block(_type_id)
	var size: Vector3i = block.size
	box.add_child(_label(block.name, 40))
	box.add_child(_label("%d × %d × %d  ·  %d Marrow to place" % [size.x, size.y, size.z, block.marrow], 22))
	_status = _label("", 24)
	box.add_child(_status)
	_own = _button("Own forever — %d Relics" % block.relics, func() -> void:
		_feedback(Profile.buy_block(_type_id), "Not enough Relics"))
	box.add_child(_own)
	_rent = _button("Rent for this room — %d Teeth" % block.teeth, func() -> void:
		_feedback(Profile.rent_block(_type_id), "Not enough Teeth"))
	box.add_child(_rent)
	_balances = _label("", 20)
	box.add_child(_balances)

	Profile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var owned := _type_id in Profile.owned_blocks
	var rented := _type_id in Profile.rented_blocks
	_status.text = "Owned" if owned else ("Rented for this room" if rented else "Not owned")
	_own.visible = not owned
	_rent.visible = not owned and not rented
	_balances.text = "You have %d Teeth · %d Relics" % [Profile.teeth, Profile.relics]


func _feedback(ok: bool, failure: String) -> void:
	if not ok:
		_status.text = failure


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 26)
	button.custom_minimum_size.y = 64
	button.pressed.connect(on_pressed)
	return button


static func dark_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.08, 0.94)
	style.border_color = Color(0.45, 0.12, 0.1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	return style
