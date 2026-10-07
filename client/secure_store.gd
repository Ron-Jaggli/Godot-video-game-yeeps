class_name SecureStore
extends RefCounted
## Obfuscated, tamper-evident local saves.
##
## File names are derived from the device ID, contents are XOR-masked with a
## keystream from the device ID, and an HMAC seal detects any edit. This stops
## casual editing (hex editors, swapping files between devices); someone who
## decompiles the game can still find the salt and forge a save. The server is
## the only place a balance can't be faked, if that's ever needed.

enum Status { OK, MISSING, TAMPERED }

## Changing the salt makes every existing save unreadable (= tampered). Don't.
const _SALT := "h0llow-m4rrow-7eeth-r3lics"
const _MAGIC_TEXT := "HLW1"
const _ID_PATH := "user://.ix"


## Random per-install ID, created on first launch. Stands in for a platform
## account until Meta login is wired up. `variant` gives extra local profiles
## (several test clients on one PC) their own ID.
static func device_id(variant := "") -> String:
	var mask := _keystream(_SALT.to_utf8_buffer(), 32)
	var id_path := _ID_PATH + variant.sha256_text().substr(0, 8) if not variant.is_empty() else _ID_PATH
	var file := FileAccess.open(id_path, FileAccess.READ)
	if file:
		var id := _xor(file.get_buffer(32), mask).get_string_from_ascii()
		if id.length() == 32 and id.is_valid_hex_number():
			return id
	var new_id := Crypto.new().generate_random_bytes(16).hex_encode()
	FileAccess.open(id_path, FileAccess.WRITE).store_buffer(_xor(new_id.to_ascii_buffer(), mask))
	return new_id


static func save(slot: String, owner_id: String, data: Dictionary) -> Error:
	var path := _path(slot, owner_id)
	var nonce := Crypto.new().generate_random_bytes(16)
	var plain := var_to_bytes(data)
	var body := _MAGIC_TEXT.to_ascii_buffer() + nonce + _u32(plain.size()) + _xor(plain, _keystream(_key("mask", owner_id) + nonce, plain.size()))
	var sealed := body + Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key("seal", owner_id), body)

	# Write to a temp file, keep the previous save as a backup, then swap in.
	var tmp := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if tmp == null:
		return FileAccess.get_open_error()
	tmp.store_buffer(sealed)
	tmp.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(path + ".tmp", path)


## Returns {status: Status, data: Dictionary}. A broken main file with a good
## backup counts as a crash mid-save, not tampering, and the backup is used.
static func load(slot: String, owner_id: String) -> Dictionary:
	var path := _path(slot, owner_id)
	var main := _read(path, owner_id)
	if main.status == Status.OK:
		return main
	var backup := _read(path + ".bak", owner_id)
	if backup.status == Status.OK:
		return backup
	if main.status == Status.MISSING and backup.status == Status.MISSING:
		return {status = Status.MISSING, data = {}}
	return {status = Status.TAMPERED, data = {}}


static func _read(path: String, owner_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {status = Status.MISSING, data = {}}
	var raw := FileAccess.get_file_as_bytes(path)
	var tampered := {status = Status.TAMPERED, data = {}}
	if raw.size() < 4 + 16 + 4 + 32 or raw.slice(0, 4) != _MAGIC_TEXT.to_ascii_buffer():
		return tampered
	var body := raw.slice(0, raw.size() - 32)
	var seal := raw.slice(raw.size() - 32)
	if Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key("seal", owner_id), body) != seal:
		return tampered
	var nonce := body.slice(4, 20)
	var length := body.decode_u32(20)
	var masked := body.slice(24)
	if masked.size() != length:
		return tampered
	var data: Variant = bytes_to_var(_xor(masked, _keystream(_key("mask", owner_id) + nonce, length)))
	if not data is Dictionary:
		return tampered
	return {status = Status.OK, data = data}


static func _path(slot: String, owner_id: String) -> String:
	return "user://%s.bin" % (_SALT + slot + owner_id).sha256_text().substr(0, 20)


static func _key(purpose: String, owner_id: String) -> PackedByteArray:
	return (_SALT + purpose + owner_id).sha256_buffer()


static func _keystream(seed: PackedByteArray, length: int) -> PackedByteArray:
	var stream := PackedByteArray()
	var counter := 0
	while stream.size() < length:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(seed + _u32(counter))
		stream.append_array(ctx.finish())
		counter += 1
	return stream.slice(0, length)


static func _xor(data: PackedByteArray, mask: PackedByteArray) -> PackedByteArray:
	var out := data.duplicate()
	for i in out.size():
		out[i] = out[i] ^ mask[i % mask.size()]
	return out


static func _u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes
