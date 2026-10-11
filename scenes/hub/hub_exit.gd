@tool
class_name HubExit
extends Node3D
## A crumbling arch with a pale veil. Walking (or flinging) into the veil
## takes you back up to the map.

signal entered

const VEIL_SIZE := Vector2(1.8, 2.6)


func _ready() -> void:
	add_to_group("no_merge")
	for side in [-1.0, 1.0]:
		var pillar := MapBlock.new()
		pillar.size = Vector3(0.6, 3.2, 0.6)
		pillar.position = Vector3(1.2 * side, 1.6, 0)
		add_child(pillar)
	var lintel := MapBlock.new()
	lintel.size = Vector3(3.0, 0.5, 0.7)
	lintel.position = Vector3(0, 3.45, 0)
	add_child(lintel)

	var veil_material := StandardMaterial3D.new()
	veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = VEIL_SIZE
	var veil := MeshInstance3D.new()
	veil.mesh = quad
	veil.material_override = veil_material
	veil.position.y = VEIL_SIZE.y * 0.5
	add_child(veil)

	var sign_label := Label3D.new()
	sign_label.text = "Back to the surface"
	sign_label.pixel_size = 0.004
	sign_label.position = Vector3(0, 3.95, 0.4)
	add_child(sign_label)

	if Engine.is_editor_hint():
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = GameConfig.LAYER_LOCAL_PLAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(VEIL_SIZE.x, VEIL_SIZE.y, 0.5)
	shape.shape = box
	shape.position.y = VEIL_SIZE.y * 0.5
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(_body: Node) -> void: entered.emit())
