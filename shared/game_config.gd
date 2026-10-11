class_name GameConfig
extends RefCounted
## Constants shared by client and server.
## Bump PROTOCOL_VERSION whenever an RPC signature or replicated property changes,
## so old clients get a clean "please update" kick instead of silent desyncs.

const PROTOCOL_VERSION := 4

const DEFAULT_PORT := 7777
const SETTINGS_PATH := "user://settings.cfg"
const MAX_CLIENTS := 256

const MAX_PLAYERS_PER_ROOM := 10
const ROOM_CODE_LENGTH := 6
# No 0/O/1/I so codes are easy to read out loud.
const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

const MAX_NAME_LENGTH := 16
const DEFAULT_NAME := "Yeep"

const SERVER_TICK_RATE := 30
const HELLO_TIMEOUT_SEC := 10.0

# Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_LOCAL_PLAYER := 2
const LAYER_UI := 4

# Arm locomotion. Client caps flings below MAX_HEAD_SPEED so legit play never trips anticheat.
const MAX_FLING_SPEED := 20.0

# Anticheat thresholds. Generous on purpose: arm locomotion flings are fast.
const MAX_HEAD_SPEED := 25.0 # metres per second
const MAX_HAND_REACH := 1.5 # metres from head
const STRIKES_BEFORE_KICK := 20.0
const STRIKE_DECAY_PER_SEC := 1.0


## Server baked into this build. Set it in Project Settings (game/network/server_address)
## before exporting for Quest, since the headset can't reach 127.0.0.1 on your PC.
static func default_address() -> String:
	return ProjectSettings.get_setting("game/network/server_address", "127.0.0.1")
