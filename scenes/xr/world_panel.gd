class_name WorldPanel
extends Node3D
## Shows a 2D Control on a quad in the world so it can be used in VR. The
## XRPlayer laser pointer feeds it mouse events. Hides itself (and stops
## catching the laser) whenever the hosted Control is hidden.

const PIXELS_PER_METRE := 600.0

var _content: Control
var _size_px: Vector2i
var _quad_size: Vector2
var _viewport: SubViewport
var _body: StaticBody3D


func _init(content: Control, size_px := Vector2i(600, 450)) -> void:
	_content = content
	_size_px = size_px
	_quad_size = Vector2(size_px) / PIXELS_PER_METRE


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = _size_px
	_viewport.transparent_bg = true
	add_child(_viewport)
	_viewport.add_child(_content)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _viewport.get_texture()
	var quad := QuadMesh.new()
	quad.size = _quad_size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = Vector3(_quad_size.x, _quad_size.y, 0.01)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body = StaticBody3D.new()
	_body.collision_mask = 0
	_body.set_meta("world_panel", self)
	_body.add_child(collision)
	add_child(_body)


func _process(_delta: float) -> void:
	visible = _content.visible
	_body.collision_layer = GameConfig.LAYER_UI if visible else 0


func pointer_event(world_pos: Vector3, press_changed: bool, pressed: bool) -> void:
	var local := to_local(world_pos)
	var pos := Vector2(local.x / _quad_size.x + 0.5, 0.5 - local.y / _quad_size.y) * Vector2(_size_px)

	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_viewport.push_input(motion)

	if press_changed:
		var click := InputEventMouseButton.new()
		click.position = pos
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		_viewport.push_input(click)
