class_name BanList
extends RefCounted
## Device bans kept by the server in user://bans.cfg (device ID -> unix expiry).
## Survives server restarts; expired entries are dropped when checked.

const PATH := "user://bans.cfg"

var _file := ConfigFile.new()


func _init() -> void:
	_file.load(PATH)


func ban(device_id: String, hours: int) -> void:
	_file.set_value("bans", device_id, int(Time.get_unix_time_from_system()) + hours * 3600)
	_file.save(PATH)


## Seconds left on the ban, or 0.
func remaining(device_id: String) -> int:
	var until: int = _file.get_value("bans", device_id, 0)
	var left := until - int(Time.get_unix_time_from_system())
	if until != 0 and left <= 0:
		_file.erase_section_key("bans", device_id)
		_file.save(PATH)
	return maxi(left, 0)
