class_name AntiCheat
extends RefCounted
## Server-side sanity checks on client-reported poses. This is the open-source
## baseline; a stricter closed implementation can replace it as long as it
## keeps this API (validate_pose / reset / forget / strike_limit_reached).

signal strike_limit_reached(peer_id: int)

var _strikes := {} # peer_id -> float
var _last_head := {} # peer_id -> Vector3
var _last_time := {} # peer_id -> msec of last accepted pose


## Returns false if the pose should be rejected (server keeps the old one).
func validate_pose(peer_id: int, head: Transform3D, left: Transform3D,
		right: Transform3D) -> bool:
	var now := Time.get_ticks_msec()
	var ok := _is_sane(head, left, right)

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


## Call after the server legitimately teleports a player (spawn, respawn...).
func reset(peer_id: int) -> void:
	_last_head.erase(peer_id)
	_last_time.erase(peer_id)


func forget(peer_id: int) -> void:
	reset(peer_id)
	_strikes.erase(peer_id)


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
