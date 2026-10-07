class_name AntiCheat
extends RefCounted
## Server-side sanity checks on client-reported poses. This is the open-source
## baseline; a stricter closed implementation can replace it as long as it
## keeps this API (validate_pose / expect_respawn / reset / forget /
## strike_limit_reached).

signal strike_limit_reached(peer_id: int)

var _strikes := {} # peer_id -> float
var _last_head := {} # peer_id -> Vector3
var _last_time := {} # peer_id -> msec of last accepted pose
var _respawns := {} # peer_id -> {until: msec, points: Array[Vector3]}

const RESPAWN_WINDOW_MSEC := 1000
const RESPAWN_RADIUS := 3.0 # head must land this close (horizontally) to a spawn point


## Returns false if the pose should be rejected (server keeps the old one).
func validate_pose(peer_id: int, head: Transform3D, left: Transform3D,
		right: Transform3D) -> bool:
	var now := Time.get_ticks_msec()
	var ok := _is_sane(head, left, right)

	if ok and _respawns.has(peer_id):
		var respawn: Dictionary = _respawns[peer_id]
		if _near_any(head.origin, respawn.points):
			# Landed at a spawn point: start tracking from here.
			_respawns.erase(peer_id)
			_last_head[peer_id] = head.origin
			_last_time[peer_id] = now
			return true
		if now < respawn.until:
			return false # still seeing poses from before the respawn; no strike
		_respawns.erase(peer_id) # never showed up at a spawn: normal checks resume

	if ok and _last_head.has(peer_id):
		var dt := maxf((now - _last_time[peer_id]) / 1000.0, 0.001)
		var speed := head.origin.distance_to(_last_head[peer_id]) / dt
		ok = speed <= GameConfig.MAX_HEAD_SPEED

	if ok:
		_last_head[peer_id] = head.origin
		_last_time[peer_id] = now
		_decay(peer_id)
	else:
		_add_strike(peer_id)
	return ok


## The client says it respawned. Its next pose is accepted only if it's at
## one of these spawn points, so the notice can't be used to teleport elsewhere.
func expect_respawn(peer_id: int, spawn_points: Array[Vector3]) -> void:
	_respawns[peer_id] = {until = Time.get_ticks_msec() + RESPAWN_WINDOW_MSEC, points = spawn_points}


## Call after the server legitimately teleports a player (spawn, respawn...).
func reset(peer_id: int) -> void:
	_last_head.erase(peer_id)
	_last_time.erase(peer_id)


func forget(peer_id: int) -> void:
	reset(peer_id)
	_strikes.erase(peer_id)
	_respawns.erase(peer_id)


func _near_any(head: Vector3, points: Array[Vector3]) -> bool:
	for point in points:
		var offset := head - point
		if Vector2(offset.x, offset.z).length() <= RESPAWN_RADIUS and offset.y > -0.5 and offset.y < 3.0:
			return true
	return false


func _is_sane(head: Transform3D, left: Transform3D, right: Transform3D) -> bool:
	for t in [head, left, right]:
		if not t.origin.is_finite() or not t.basis.is_finite():
			return false
	return head.origin.distance_to(left.origin) <= GameConfig.MAX_HAND_REACH \
			and head.origin.distance_to(right.origin) <= GameConfig.MAX_HAND_REACH


func _add_strike(peer_id: int) -> void:
	var strikes: float = _strikes.get(peer_id, 0.0) + 1.0
	_strikes[peer_id] = strikes
	if strikes >= GameConfig.STRIKES_BEFORE_KICK:
		_strikes[peer_id] = 0.0
		strike_limit_reached.emit(peer_id)


func _decay(peer_id: int) -> void:
	if _strikes.has(peer_id):
		var per_tick := GameConfig.STRIKE_DECAY_PER_SEC / Engine.physics_ticks_per_second
		_strikes[peer_id] = maxf(0.0, _strikes[peer_id] - per_tick)
