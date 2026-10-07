class_name GameConfig
extends RefCounted
## Constants shared by client and server.
## Bump PROTOCOL_VERSION whenever an RPC signature or replicated property changes,
## so old clients get a clean "please update" kick instead of silent desyncs.

const PROTOCOL_VERSION := 1

const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 256

const MAX_PLAYERS_PER_ROOM := 10
const ROOM_CODE_LENGTH := 6
# No 0/O/1/I so codes are easy to read out loud.
const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

const MAX_NAME_LENGTH := 16
const DEFAULT_NAME := "Yeep"

const SERVER_TICK_RATE := 30
const HELLO_TIMEOUT_SEC := 10.0

# Anticheat thresholds. Generous on purpose: arm locomotion flings are fast.
const MAX_HEAD_SPEED := 25.0 # metres per second
const MAX_HAND_REACH := 1.5 # metres from head
const STRIKES_BEFORE_KICK := 20.0
const STRIKE_DECAY_PER_SEC := 1.0
