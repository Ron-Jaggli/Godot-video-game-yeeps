class_name Avatar
extends Node3D
## Procedural blob avatar: a head with glowing eyes, a body hanging under it,
## stretchy noodle arms, mitten hands, a hat and a floating name tag.
## Built from primitives so it ships with no art assets and stays cheap on
## Quest. A real model can replace it by keeping the same API:
## set_style / set_display_name / set_pose.
##
## Poses are in the parent's space (rooms sit at the world origin).

const HEAD_RADIUS := 0.17
const BODY_RADIUS := 0.15
const BODY_HEIGHT := 0.42
const BODY_DROP := 0.34 # body centre below the head
const SHOULDER := Vector3(0.13, 0.1, 0.0) # body-local
const ARM_RADIUS := 0.035
const ARM_REST_LENGTH := 0.45
const HAND_RADIUS := 0.07
const NAME_TAG_HEIGHT := 0.38
const SMOOTHING := 18.0 # higher = snappier interpolation between network updates

## Remote players ease toward each 30 Hz network update instead of snapping.
var smooth := true

static var _materials := {} # shared by all avatars so they batch on Quest

var _head: Node3D
var _body: MeshInstance3D
var _hat: Node3D
var _name_tag: Label3D
var _hands: Array[MeshInstance3D] = []
var _arms: Array[MeshInstance3D] = []
var _target: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _current: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _body_forward := Vector3.FORWARD
var _has_pose := false


func _init() -> void:
	name = "Avatar"
	_body = _mesh_child(self, _capsule(BODY_RADIUS, BODY_HEIGHT))
	_head = Node3D.new()
	add_child(_head)
	var skull := _mesh_child(_head, _sphere(HEAD_RADIUS))
	skull.scale = Vector3(1.0, 0.92, 1.0)
	skull.name = "Skull"
	for side in [-1.0, 1.0]:
		var eye := _mesh_child(_head, _sphere(1.0), _unshaded(Color(0.02, 0.02, 0.03)))
		eye.position = Vector3(0.06 * side, 0.03, -0.145)
		eye.scale = Vector3(0.035, 0.05, 0.02)
		var pupil := _mesh_child(_head, _sphere(0.012), _unshaded(Color(0.9, 0.15, 0.12)))
		pupil.position = Vector3(0.063 * side, 0.04, -0.163)
	for i in 2:
		_arms.append(_mesh_child(self, _cylinder(ARM_RADIUS, ARM_RADIUS, 1.0)))
		_hands.append(_mesh_child(self, _sphere(HAND_RADIUS)))
	_name_tag = Label3D.new()
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.pixel_size = 0.0015
	_name_tag.font_size = 48
	_name_tag.outline_size = 12
	_name_tag.modulate = Color(0.92, 0.9, 0.95)
	add_child(_name_tag)
	set_style(0, 0)


func set_style(color_index: int, hat_index: int) -> void:
	var skin := _material(AvatarStyle.color(color_index))
	var mitts := _material(AvatarStyle.color(color_index).darkened(0.35))
	_head.get_node("Skull").material_override = skin
	_body.material_override = skin
	for i in 2:
		_arms[i].material_override = skin
		_hands[i].material_override = mitts
	if _hat:
		_hat.free()
	_hat = _make_hat(AvatarStyle.clean_hat(hat_index))
	_head.add_child(_hat)


func set_display_name(display_name: String) -> void:
	_name_tag.text = display_name


func set_name_tag_visible(value: bool) -> void:
	_name_tag.visible = value


func set_pose(head: Transform3D, left_hand: Transform3D, right_hand: Transform3D) -> void:
	_target = [head, left_hand, right_hand]
	if not _has_pose or not smooth:
		_current = _target.duplicate()
		_has_pose = true
		_apply()


func _process(delta: float) -> void:
	if not _has_pose or not smooth:
		return
	var weight := 1.0 - exp(-SMOOTHING * delta)
	for i in 3:
		_current[i] = _current[i].interpolate_with(_target[i], weight)
	_apply()


func _apply() -> void:
	var head := _current[0]
	_head.transform = head.orthonormalized()

	# The body hangs under the head and only turns with it (yaw), so looking
	# up or down doesn't tip the whole creature over.
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.01:
		_body_forward = forward.normalized()
	_body.transform = Transform3D(Basis.looking_at(_body_forward), head.origin + Vector3.DOWN * BODY_DROP)

	for i in 2:
		var hand := _current[i + 1].orthonormalized()
		_hands[i].transform = hand
		var shoulder := _body.transform * Vector3(SHOULDER.x * (-1.0 if i == 0 else 1.0), SHOULDER.y, 0.0)
		_stretch_arm(_arms[i], shoulder, hand.origin)

	_name_tag.position = head.origin + Vector3.UP * NAME_TAG_HEIGHT


## Points a unit-height cylinder from a to b; it thins out as it stretches.
func _stretch_arm(arm: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var span := b - a
	var length := span.length()
	if length < 0.001:
		arm.visible = false
		return
	arm.visible = true
	var y := span / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	var thickness := clampf(sqrt(ARM_REST_LENGTH / length), 0.5, 1.3)
	arm.transform = Transform3D(Basis(x * thickness, y * length, z * thickness), (a + b) * 0.5)


func _make_hat(index: int) -> Node3D:
	var hat := Node3D.new()
	hat.name = "Hat"
	var top := HEAD_RADIUS * 0.92
	match AvatarStyle.HATS[index]:
		"Horns":
			var bone := _material(Color(0.88, 0.85, 0.76))
			for side in [-1.0, 1.0]:
				var horn := _mesh_child(hat, _cylinder(0.0, 0.03, 0.13), bone)
				horn.position = Vector3(0.08 * side, top + 0.02, -0.02)
				horn.rotation.z = deg_to_rad(-28.0 * side)
		"Top Hat":
			var black := _material(Color(0.06, 0.06, 0.07))
			var brim := _mesh_child(hat, _cylinder(0.15, 0.15, 0.015), black)
			brim.position.y = top - 0.01
			var crown := _mesh_child(hat, _cylinder(0.09, 0.09, 0.17), black)
			crown.position.y = top + 0.08
			var band := _mesh_child(hat, _cylinder(0.092, 0.092, 0.03), _material(Color(0.5, 0.08, 0.08)))
			band.position.y = top + 0.015
		"Halo":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.085
			ring.outer_radius = 0.105
			var halo := _mesh_child(hat, ring, _unshaded(Color(1.0, 0.85, 0.35)))
			halo.position.y = top + 0.1
		"Antenna":
			var stalk := _mesh_child(hat, _cylinder(0.008, 0.008, 0.16), _material(Color(0.1, 0.1, 0.1)))
			stalk.position.y = top + 0.07
			var bulb := _mesh_child(hat, _sphere(0.03), _unshaded(Color(0.95, 0.2, 0.15)))
			bulb.position.y = top + 0.16
	return hat


# --- Mesh / material helpers -------------------------------------------------

static func _mesh_child(parent: Node3D, mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 6
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_materials[color] = material
	return _materials[color]


static func _unshaded(color: Color) -> StandardMaterial3D:
	var key := "unshaded_%s" % color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[key] = material
	return _materials[key]
