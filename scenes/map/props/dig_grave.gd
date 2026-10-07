@tool
class_name DigGrave
extends Node3D
## A fresh grave you can dig out with your hands: scoop down into the mound
## a few times and it caves in, leaving a hole. Jump in to reach the hub.
## Every map should have one. Purely local: each player digs their own.
## Desktop debug: stand next to it and press F to dig.

signal dug ## the mound has been dug away
signal entered ## the local player dropped into the hole

const STROKES_NEEDED := 6
const STROKE_DEPTH := 0.2 ## metres a hand must sweep down through the earth per stroke
const RADIUS := 0.8
const MOUND_HEIGHT := 0.45
const REFILL_SECONDS := 20.0

var _mound: MeshInstance3D
var _hole: MeshInstance3D
var _area: Area3D
var _strokes := 0
var _open := false
var _prev_hand_y: Array[float] = [INF, INF]
var _sweep: Array[float] = [0.0, 0.0]


func _ready() -> void:
	add_to_group("no_merge") # the mound shrinks and vanishes as you dig
	var headstone := Gravestone.new()
	headstone.stone_seed = 7
	headstone.position = Vector3(0, 0, -RADIUS - 0.1)
	add_child(headstone)

	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = RADIUS
	mound_mesh.height = MOUND_HEIGHT * 2.0
	mound_mesh.is_hemisphere = true
	_mound = MeshInstance3D.new()
	_mound.mesh = mound_mesh
	_mound.scale = Vector3(1.0, 1.0, 1.4)
	_mound.material_override = MapMaterials.get_material(MapMaterials.Surface.EARTH)
	add_child(_mound)

	var pit := CylinderMesh.new()
	pit.top_radius = RADIUS * 0.8
	pit.bottom_radius = RADIUS * 0.8
	pit.height = 0.04
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	_hole = MeshInstance3D.new()
	_hole.mesh = pit
	_hole.scale = Vector3(1.0, 1.0, 1.4)
	_hole.position.y = 0.03
	_hole.material_override = black
	_hole.visible = false
	add_child(_hole)

	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = GameConfig.LAYER_LOCAL_PLAYER
	_area.monitoring = false
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS * 0.8
	cylinder.height = 1.2
	shape.shape = cylinder
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(func(_body: Node) -> void:
		if _open:
			entered.emit())


func _physics_process(_delta: float) -> void:
	if _open:
		return
	var rig := get_tree().get_first_node_in_group("local_xr_rig") as XRPlayer
	if rig == null or not rig.is_vr:
		return
	var hands := [rig.left_hand_transform.origin, rig.right_hand_transform.origin]
	for i in 2:
		var local := to_local(hands[i])
		var in_earth := Vector2(local.x, local.z / 1.4).length() < RADIUS and local.y < MOUND_HEIGHT + 0.1 and local.y > -0.2
		if not in_earth:
			_sweep[i] = 0.0
		elif _prev_hand_y[i] != INF:
			var drop := _prev_hand_y[i] - local.y
			_sweep[i] = _sweep[i] + drop if drop > 0.0 else 0.0
			if _sweep[i] >= STROKE_DEPTH:
				_sweep[i] = 0.0
				_dig()
		_prev_hand_y[i] = local.y if in_earth else INF


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		var rig := get_tree().get_first_node_in_group("local_xr_rig") as XRPlayer
		if rig and not rig.is_vr and rig.global_position.distance_to(global_position) < 2.0:
			_dig()


func _dig() -> void:
	_strokes += 1
	_mound.scale.y = 1.0 - float(_strokes) / STROKES_NEEDED
	if _strokes < STROKES_NEEDED:
		return
	_open = true
	_mound.visible = false
	_hole.visible = true
	_area.monitoring = true
	dug.emit()
	get_tree().create_timer(REFILL_SECONDS).timeout.connect(_refill)


func _refill() -> void:
	_open = false
	_strokes = 0
	_mound.scale.y = 1.0
	_mound.visible = true
	_hole.visible = false
	_area.monitoring = false
