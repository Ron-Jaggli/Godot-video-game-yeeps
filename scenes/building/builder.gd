class_name Builder
extends Node3D
## Local building controls and the wrist display. Lives on the client next to
## the XR rig; main.gd points `room` at the current room (null in the lobby).
##
## VR:      grip = take the selected block out (or grab one of your placed
##          blocks), release grip = place. Tilt your hand to lay a block down.
##          B / Y = next / previous block type, A / X = drop the held block.
## Desktop: Q = next block, E = take / place (or pick up the block you look at),
##          R = turn the held block, X = drop it.

const HELD_SCALE := 0.22
const GRAB_RADIUS := 0.2 ## how close (m) a hand must be to one of your blocks to grab it
const DESKTOP_REACH := 1.6 ## where the desktop "hand" holds blocks, in front of the camera
const GOOD_COLOR := Color(0.45, 0.9, 0.5, 0.35)
const BAD_COLOR := Color(0.95, 0.25, 0.2, 0.35)

var room: Room:
	set(value):
		room = value
		_held = [-1, -1]
		_occupied_dirty = true
		if room:
			room.blocks.child_entered_tree.connect(_on_block_added)
			room.blocks.child_exiting_tree.connect(func(_b: Node) -> void: _occupied_dirty = true)
var selected := 0

var _rig: XRPlayer
var _held: Array[int] = [-1, -1] ## block type in each hand, -1 = empty
var _desktop_axis := 0
var _held_meshes: Array[MeshInstance3D] = []
var _ghosts: Array[MeshInstance3D] = []
var _good_material := _ghost_material(GOOD_COLOR)
var _bad_material := _ghost_material(BAD_COLOR)
var _buttons_was := {}
var _occupied := {}
var _occupied_dirty := true
var _hud: Label3D


func _init(rig: XRPlayer) -> void:
	name = "Builder"
	_rig = rig


func _ready() -> void:
	for i in 2:
		var held := MeshInstance3D.new()
		held.top_level = true
		held.visible = false
		add_child(held)
		_held_meshes.append(held)
		var ghost := MeshInstance3D.new()
		ghost.top_level = true
		ghost.visible = false
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		_ghosts.append(ghost)
	_hud = Label3D.new()
	_hud.top_level = true
	_hud.pixel_size = 0.0011
	_hud.font_size = 32
	_hud.outline_size = 8
	_hud.no_depth_test = true
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_hud)
	Network.marrow_changed.connect(func(_m: int) -> void: _refresh_hud())
	Profile.changed.connect(_refresh_hud)
	_refresh_hud()


func _physics_process(_delta: float) -> void:
	var active := room != null and is_instance_valid(room)
	_hud.visible = active
	if not active:
		for i in 2:
			_held_meshes[i].visible = false
			_ghosts[i].visible = false
		return
	if _rig.is_vr:
		_vr_input()
	for i in 2:
		_update_visuals(i)
	_hud.global_transform = _hud_anchor()


# --- Input --------------------------------------------------------------------

func _vr_input() -> void:
	for i in 2:
		var grip := _pressed(i, "grip_click")
		if grip == 1:
			_grab(i)
		elif grip == -1:
			_release(i)
		if _pressed(i, "ax_button") == 1:
			_held[i] = -1
	if _pressed(1, "by_button") == 1:
		_cycle(1)
	if _pressed(0, "by_button") == 1:
		_cycle(-1)


func _unhandled_input(event: InputEvent) -> void:
	if _rig.is_vr or room == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_Q:
			_cycle(1)
		KEY_R:
			_desktop_axis = (_desktop_axis + 1) % 3
		KEY_X:
			_held[1] = -1
		KEY_E:
			if _held[1] >= 0:
				_release(1)
			else:
				_grab(1)


## 1 on press, -1 on release, 0 otherwise.
func _pressed(hand: int, action: String) -> int:
	var key := "%d%s" % [hand, action]
	var now := _rig.hand_button(hand, action)
	var was: bool = _buttons_was.get(key, false)
	_buttons_was[key] = now
	return 1 if now and not was else (-1 if was and not now else 0)


func _cycle(step: int) -> void:
	var usable: Array[int] = []
	for type_id in Economy.BLOCKS.size():
		if Profile.can_use_block(type_id):
			usable.append(type_id)
	if usable.is_empty():
		return
	var index := usable.find(selected)
	selected = usable[posmod(index + step, usable.size())]
	_refresh_hud()


# --- Grab and place ----------------------------------------------------------------

func _grab(hand: int) -> void:
	if _held[hand] >= 0:
		return
	var mine := _own_block_near(hand)
	if mine:
		_held[hand] = mine.type_id
		Network.remove_block(mine.name)
	elif Profile.can_use_block(selected):
		_held[hand] = selected


func _release(hand: int) -> void:
	if _held[hand] < 0:
		return
	var spot := _placement(hand)
	if spot.valid:
		Network.place_block(_held[hand], spot.cell, spot.axis)
	_held[hand] = -1


## Where the held block would land, and whether the server is likely to accept it.
func _placement(hand: int) -> Dictionary:
	var type_id := _held[hand]
	var grip := _hand_transform(hand)
	var axis := BlockShapes.axis_from_basis(grip.basis) if _rig.is_vr else _desktop_axis
	var cell := BlockShapes.cell_for_center(room.to_local(grip.origin), type_id, axis)
	cell.y = maxi(cell.y, 0)
	var valid: bool = Network.marrow >= Economy.BLOCKS[type_id].marrow
	var e := Economy.BUILD_HALF_EXTENT_CELLS
	var size := BlockShapes.size_cells(type_id, axis)
	if cell.x < -e or cell.z < -e or cell.x + size.x > e or cell.z + size.z > e \
			or cell.y + size.y > Economy.BUILD_MAX_HEIGHT_CELLS:
		valid = false
	if valid:
		var taken := _occupied_cells()
		for c in BlockShapes.cells(cell, type_id, axis):
			if taken.has(c):
				valid = false
				break
	return {cell = cell, axis = axis, valid = valid}


func _own_block_near(hand: int) -> PlacedBlock:
	var me := multiplayer.get_unique_id()
	if not _rig.is_vr:
		# Desktop: the block in the middle of the screen.
		var eye := _rig.head_transform
		var query := PhysicsRayQueryParameters3D.create(eye.origin, eye.origin - eye.basis.z * 3.0, GameConfig.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var block := hit.get("collider") as PlacedBlock
		return block if block and block.owner_peer == me else null
	var point := room.to_local(_hand_transform(hand).origin)
	for block: PlacedBlock in room.blocks.get_children():
		if block.owner_peer != me or block.is_queued_for_deletion():
			continue
		var half := BlockShapes.size_m(block.type_id, block.axis) * 0.5
		var offset := (point - block.position).abs() - half
		if offset.x < GRAB_RADIUS and offset.y < GRAB_RADIUS and offset.z < GRAB_RADIUS:
			return block
	return null


func _occupied_cells() -> Dictionary:
	if _occupied_dirty:
		_occupied.clear()
		for block: PlacedBlock in room.blocks.get_children():
			if not block.is_queued_for_deletion():
				for c in block.occupied_cells():
					_occupied[c] = true
		_occupied_dirty = false
	return _occupied


func _on_block_added(block: Node) -> void:
	_occupied_dirty = true
	if (block as PlacedBlock).owner_peer == multiplayer.get_unique_id():
		Profile.record(Quests.STAT_BLOCKS_PLACED)


# --- Visuals --------------------------------------------------------------------------

func _update_visuals(hand: int) -> void:
	var type_id := _held[hand]
	var held := _held_meshes[hand]
	var ghost := _ghosts[hand]
	held.visible = type_id >= 0
	ghost.visible = type_id >= 0
	if type_id < 0:
		return
	var spot := _placement(hand)
	if held.get_meta("type", -1) != type_id:
		held.mesh = BlockShapes.make_mesh(type_id, 0)
		held.material_override = BlockShapes.material(type_id)
		held.set_meta("type", type_id)
	var grip := _hand_transform(hand)
	if not _rig.is_vr:
		grip.basis = Basis.looking_at(Vector3(-grip.basis.z.x, 0, -grip.basis.z.z).normalized())
		grip.basis *= _desktop_axis_basis()
	held.global_transform = Transform3D(grip.basis.orthonormalized().scaled(Vector3.ONE * HELD_SCALE), grip.origin)

	var ghost_key := "%d/%d" % [type_id, spot.axis]
	if ghost.get_meta("key", "") != ghost_key:
		ghost.mesh = BlockShapes.make_mesh(type_id, spot.axis)
		ghost.set_meta("key", ghost_key)
	ghost.material_override = _good_material if spot.valid else _bad_material
	ghost.global_transform = room.global_transform * Transform3D(Basis(), BlockShapes.center(spot.cell, type_id, spot.axis))


func _desktop_axis_basis() -> Basis:
	match _desktop_axis:
		1: return Basis(Vector3.FORWARD, PI * 0.5)
		2: return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis()


func _hand_transform(hand: int) -> Transform3D:
	if _rig.is_vr:
		return _rig.left_hand_transform if hand == 0 else _rig.right_hand_transform
	return _rig.head_transform * Transform3D(Basis(), Vector3(0, -0.2, -DESKTOP_REACH))


func _hud_anchor() -> Transform3D:
	if _rig.is_vr:
		# Floating over the back of the left wrist, facing the head.
		var wrist := _rig.left_hand_transform.origin + Vector3.UP * 0.12
		return Transform3D(Basis.looking_at(wrist - _rig.head_transform.origin), wrist)
	return _rig.head_transform * Transform3D(Basis(), Vector3(-0.42, -0.22, -0.7))


func _refresh_hud() -> void:
	if _hud == null:
		return
	var block := Economy.block(selected)
	_hud.text = "Marrow %d / %d\nTeeth %d   Relics %d\n%s  (%d Marrow)" % [
		Network.marrow, Economy.MARROW_MAX, Profile.teeth, Profile.relics, block.name, block.marrow]


static func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material
