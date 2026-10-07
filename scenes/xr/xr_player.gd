class_name XRPlayer
extends CharacterBody3D
## Local player rig with Gorilla Tag style arm locomotion: hands can't pass
## through world geometry, so pushing or dragging a hand against a surface moves
## the body instead, and the body keeps that momentum when the hand lets go.
##
## Without a headset it falls back to a desktop debug mode (WASD + mouse look,
## click to capture the mouse, Esc to release).
## PlayerInput reads the world-space poses below via the "local_xr_rig" group.

signal menu_requested

const HAND_RADIUS := 0.07
const BODY_RADIUS := 0.2
const MAX_ARM_STRETCH := 0.6 # a stuck hand snaps back once the controller is this far away
const RELEASE_DISTANCE := 0.01 # how far the controller must pull off a surface to let go
const CONTACT_MARGIN := 0.01
const FLING_MULTIPLIER := 1.1
const VELOCITY_HISTORY := 5
const GROUND_DAMPING := 8.0
const SNAP_TURN := deg_to_rad(30.0)
const POINTER_LENGTH := 3.0
const DESKTOP_SPEED := 3.0
const DESKTOP_JUMP := 4.5
const MOUSE_SENSITIVITY := 0.003
# Where the hands float relative to the camera in desktop mode.
const DESKTOP_HAND_OFFSETS: Array[Vector3] = [Vector3(-0.25, -0.3, -0.4), Vector3(0.25, -0.3, -0.4)]

var head_transform := Transform3D.IDENTITY
var left_hand_transform := Transform3D.IDENTITY
var right_hand_transform := Transform3D.IDENTITY
var is_vr := false

var _hand_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO] # physical hands, world space
var _hand_normal: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO] # surface each hand rests on
var _velocity_history: Array[Vector3] = []
var _was_pushing := false
var _snap_ready := true
var _trigger_was_pressed := false
var _menu_was_pressed := false
var _hand_shape := SphereShape3D.new()
var _laser: MeshInstance3D

@onready var _origin: XROrigin3D = $XROrigin3D
@onready var _camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var _controllers: Array[XRController3D] = [$XROrigin3D/LeftController, $XROrigin3D/RightController]
@onready var _hand_meshes: Array[Node3D] = [$LeftHand, $RightHand]
@onready var _capsule: CapsuleShape3D = $CollisionShape3D.shape
@onready var _body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("local_xr_rig")
	_hand_shape.radius = HAND_RADIUS
	var xr := XRServer.find_interface("OpenXR")
	is_vr = xr != null and xr.is_initialized()
	if is_vr:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_laser = _make_laser()
	else:
		_camera.position.y = 1.6
	reset_hands()


func teleport(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	_velocity_history.clear()
	_was_pushing = false
	reset_hands()


func reset_hands() -> void:
	for i in 2:
		_hand_pos[i] = _hand_target(i).origin
		_hand_normal[i] = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_fit_body_to_head()
	if is_vr:
		_snap_turn_input()
		_arm_locomotion(delta)
		_update_pointer()
		_menu_button_input()
	else:
		_desktop_move(delta)
	_update_poses()


# --- Arm locomotion -----------------------------------------------------------

func _arm_locomotion(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var push := Vector3.ZERO
	var pushing := 0
	for i in 2:
		var target := _hand_target(i).origin
		if _hand_pos[i].distance_to(target) > MAX_ARM_STRETCH:
			_hand_pos[i] = target
			_hand_normal[i] = Vector3.ZERO
			continue
		# A hand on a surface sticks until the controller pulls away from it,
		# so dragging along the ground moves you (the core GT walk).
		var sticking := _hand_normal[i] != Vector3.ZERO \
				and (target - _hand_pos[i]).dot(_hand_normal[i]) < RELEASE_DISTANCE
		if not sticking:
			var safe := _sweep_hand(space, _hand_pos[i], target)
			_hand_pos[i] = _hand_pos[i].lerp(target, safe)
			_hand_normal[i] = _surface_normal(space, i)
			if safe >= 1.0 and _hand_normal[i] == Vector3.ZERO:
				continue
		# Hand is blocked: move the body so the controller ends up where the hand is.
		push += _hand_pos[i] - target
		pushing += 1

	if pushing > 0:
		velocity = (push / pushing / delta).limit_length(GameConfig.MAX_FLING_SPEED)
		_velocity_history.push_back(velocity)
		if _velocity_history.size() > VELOCITY_HISTORY:
			_velocity_history.pop_front()
		_was_pushing = true
	else:
		if _was_pushing:
			velocity = (_average_velocity() * FLING_MULTIPLIER).limit_length(GameConfig.MAX_FLING_SPEED)
			_velocity_history.clear()
			_was_pushing = false
		velocity += get_gravity() * delta
		if is_on_floor():
			var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, GROUND_DAMPING * delta)
			velocity = Vector3(horizontal.x, velocity.y, horizontal.z)
	move_and_slide()


## Fraction (0..1) of the from->to motion the hand sphere can travel freely.
func _sweep_hand(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> float:
	if from.is_equal_approx(to):
		return 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hand_shape
	query.transform = Transform3D(Basis(), from)
	query.motion = to - from
	query.collision_mask = GameConfig.LAYER_WORLD
	query.exclude = [get_rid()]
	return space.cast_motion(query)[0]


## Pushes a hand that sank into geometry back out (shape casts don't block a
## sphere that already overlaps) and returns the surface normal it rests on,
## or Vector3.ZERO if it isn't touching anything.
func _surface_normal(space: PhysicsDirectSpaceState3D, i: int) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hand_shape
	query.collision_mask = GameConfig.LAYER_WORLD
	query.exclude = [get_rid()]
	query.margin = CONTACT_MARGIN
	var normal := Vector3.ZERO
	for _attempt in 2:
		query.transform = Transform3D(Basis(), _hand_pos[i])
		var contact := space.get_rest_info(query)
		if contact.is_empty():
			break
		normal = contact.normal
		var depth := HAND_RADIUS - _hand_pos[i].distance_to(contact.point)
		if depth <= 0.001:
			break
		_hand_pos[i] += normal * depth
	return normal


func _average_velocity() -> Vector3:
	if _velocity_history.is_empty():
		return velocity
	var sum := Vector3.ZERO
	for v in _velocity_history:
		sum += v
	return sum / _velocity_history.size()


## Keeps the capsule standing under the headset as the player walks around their room.
func _fit_body_to_head() -> void:
	var head := _camera.position
	_capsule.radius = BODY_RADIUS
	_capsule.height = maxf(head.y + BODY_RADIUS, BODY_RADIUS * 2.0)
	_body_shape.position = Vector3(head.x, _capsule.height / 2.0, head.z)


func _snap_turn_input() -> void:
	var x := _controllers[1].get_vector2("primary").x
	if absf(x) < 0.3:
		_snap_ready = true
	elif _snap_ready and absf(x) > 0.7:
		_snap_ready = false
		_rotate_around_head(-signf(x) * SNAP_TURN)


func _rotate_around_head(angle: float) -> void:
	var pivot := _camera.global_position
	global_transform = global_transform.translated(-pivot).rotated(Vector3.UP, angle).translated(pivot)
	for i in 2:
		_hand_pos[i] = pivot + (_hand_pos[i] - pivot).rotated(Vector3.UP, angle)


func _menu_button_input() -> void:
	var pressed := _controllers[0].is_button_pressed("menu_button")
	if pressed and not _menu_was_pressed:
		menu_requested.emit()
	_menu_was_pressed = pressed


# --- Laser pointer for WorldPanels ------------------------------------------------

func _update_pointer() -> void:
	var controller := _controllers[1]
	var from := controller.global_position
	var to := from - controller.global_basis.z * POINTER_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_UI)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var pressed := controller.is_button_pressed("trigger_click")

	var panel: WorldPanel = hit.collider.get_meta("world_panel") if hit and hit.collider.has_meta("world_panel") else null
	_laser.visible = panel != null
	if panel:
		var length := from.distance_to(hit.position)
		_laser.scale.y = length
		_laser.position.z = -length / 2.0
		panel.pointer_event(hit.position, pressed != _trigger_was_pressed, pressed)
	_trigger_was_pressed = pressed


func _make_laser() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.003
	mesh.bottom_radius = 0.003
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.8, 0.1, 0.1)
	mesh.material = material
	var laser := MeshInstance3D.new()
	laser.mesh = mesh
	laser.rotation_degrees.x = -90.0 # cylinder runs along Y; point it down -Z
	laser.visible = false
	_controllers[1].add_child(laser)
	return laser


# --- Desktop fallback -----------------------------------------------------------

func _desktop_move(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var forward := _camera.global_basis.z
	forward.y = 0
	var right := _camera.global_basis.x
	right.y = 0
	var wish := (right.normalized() * input.x + forward.normalized() * input.y).limit_length(1.0)
	velocity.x = wish.x * DESKTOP_SPEED
	velocity.z = wish.z * DESKTOP_SPEED
	velocity += get_gravity() * delta
	if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = DESKTOP_JUMP
	move_and_slide()
	reset_hands()


func _unhandled_input(event: InputEvent) -> void:
	if is_vr:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == KEY_TAB:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			menu_requested.emit()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_origin.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_camera.rotation.x = clampf(_camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)


# --- Shared ---------------------------------------------------------------------

func _hand_target(i: int) -> Transform3D:
	if is_vr:
		return _controllers[i].global_transform
	return _camera.global_transform * Transform3D(Basis(), DESKTOP_HAND_OFFSETS[i])


func _update_poses() -> void:
	head_transform = _camera.global_transform
	var hands: Array[Transform3D] = []
	for i in 2:
		var t := _hand_target(i)
		t.origin = _hand_pos[i]
		_hand_meshes[i].global_transform = t
		hands.append(t)
	left_hand_transform = hands[0]
	right_hand_transform = hands[1]
