class_name Protocol
extends RefCounted
## Enums sent over the wire. Append only; reordering breaks old clients.

enum JoinError {
	NONE,
	NOT_REGISTERED,
	ALREADY_IN_ROOM,
	BAD_CODE,
	ROOM_NOT_FOUND,
	ROOM_FULL,
}

enum KickReason {
	VERSION_MISMATCH,
	HELLO_TIMEOUT,
	CHEATING,
	SERVER_SHUTDOWN,
	BANNED,
}

## Where a client says it teleported to, so the anticheat expects the jump.
enum Teleport {
	SPAWN,
	HUB,
}


static func join_error_text(err: int) -> String:
	match err:
		JoinError.NOT_REGISTERED: return "Not registered with server"
		JoinError.ALREADY_IN_ROOM: return "Already in a room"
		JoinError.BAD_CODE: return "Invalid room code"
		JoinError.ROOM_NOT_FOUND: return "Room not found"
		JoinError.ROOM_FULL: return "Room is full"
	return "Unknown error"


static func kick_reason_text(reason: int) -> String:
	match reason:
		KickReason.VERSION_MISMATCH: return "Game version mismatch, please update"
		KickReason.HELLO_TIMEOUT: return "Handshake timed out"
		KickReason.CHEATING: return "Kicked by anticheat"
		KickReason.SERVER_SHUTDOWN: return "Server shutting down"
		KickReason.BANNED: return "This device is banned for a while (save file was edited)"
	return "Kicked"
