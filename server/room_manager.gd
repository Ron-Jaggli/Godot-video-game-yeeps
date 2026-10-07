class_name RoomManager
extends Node
## Creates, finds, and cleans up rooms. Rooms are added under the main scene's
## Rooms node, where the RoomSpawner replicates them to their members only.

const ROOM_SCENE := preload("res://scenes/room/room.tscn")

var _rooms_root: Node
var _anticheat: AntiCheat
var _rooms := {} # code -> Room
var _rng := RandomNumberGenerator.new()


func _init(rooms_root: Node, anticheat: AntiCheat) -> void:
	name = "RoomManager"
	_rooms_root = rooms_root
	_anticheat = anticheat


func create_room(is_public: bool) -> Room:
	var code := _generate_code()
	var room: Room = ROOM_SCENE.instantiate()
	room.name = code
	room.room_code = code
	room.is_public = is_public
	room.anticheat = _anticheat
	room.emptied.connect(_on_room_emptied.bind(room))
	_rooms_root.add_child(room, true)
	_rooms[code] = room
	Server.log_msg("created %s room %s" % ["public" if is_public else "private", code])
	return room


func get_room(code: String) -> Room:
	return _rooms.get(code)


## Fullest public room that still has space, so quick play fills lobbies up.
func find_open_public_room() -> Room:
	var best: Room
	for room: Room in _rooms.values():
		if room.is_public and not room.is_full():
			if best == null or room.member_count() > best.member_count():
				best = room
	return best


static func is_valid_code(code: String) -> bool:
	if code.length() != GameConfig.ROOM_CODE_LENGTH:
		return false
	for c in code:
		if not GameConfig.ROOM_CODE_ALPHABET.contains(c):
			return false
	return true


func _generate_code() -> String:
	var alphabet := GameConfig.ROOM_CODE_ALPHABET
	while true:
		var code := ""
		for i in GameConfig.ROOM_CODE_LENGTH:
			code += alphabet[_rng.randi_range(0, alphabet.length() - 1)]
		if not _rooms.has(code):
			return code
	return ""


func _on_room_emptied(room: Room) -> void:
	Server.log_msg("room %s empty, closing" % room.room_code)
	_rooms.erase(room.room_code)
	room.queue_free()
