class_name Economy
extends RefCounted
## Every tunable number in the economy lives here: currencies, prices, the
## weekly Relic cap and the block catalog. Change values freely; only append
## to BLOCKS (indices are sent over the wire and stored in saves).
##
##   Marrow  building currency. Server-side, resets every session, refills fast.
##   Teeth   trade currency. Permanent (saved on the device). Rents an item for
##           the room you're in.
##   Relics  owning currency. Permanent (saved on the device), earned from quests,
##           capped per week. Buys an item for good.

# --- Marrow (per session, tracked by the server) -------------------------------
const MARROW_START := 60
const MARROW_MAX := 120
const MARROW_REGEN_PER_SEC := 4.0

# --- Relics ---------------------------------------------------------------------
## The most Relics anyone can earn per week (resets Monday 00:00 UTC). Raise or
## lower this each week depending on how much you want to hand out.
const RELICS_WEEKLY_CAP := 200

# --- Tamper ban ------------------------------------------------------------------
const TAMPER_BAN_HOURS := 72

# --- Building grid -----------------------------------------------------------------
## One grid cell: about one player wide and deep, and half a player tall.
const CELL := Vector3(0.6, 0.9, 0.6)
## How far from your hand (metres) the server lets you place or pick up a block.
const BUILD_REACH := 2.5
const MAX_BLOCKS_PER_PLAYER := 150
const MAX_BLOCKS_PER_ROOM := 400
## Blocks can only go inside the map walls (cells from the room origin).
const BUILD_HALF_EXTENT_CELLS := 35
const BUILD_MAX_HEIGHT_CELLS := 30

# --- Block catalog ------------------------------------------------------------------
## size: cells as (width, height, depth) when standing upright.
## marrow: cost to place one. teeth: rent for the current room. relics: own forever
## (0 = everyone owns it from the start).
const BLOCKS: Array[Dictionary] = [
	{name = "Slab", size = Vector3i(1, 1, 1), marrow = 4, teeth = 0, relics = 0, surface = MapMaterials.Surface.DARK_STONE},
	{name = "Post", size = Vector3i(1, 2, 1), marrow = 6, teeth = 10, relics = 40, surface = MapMaterials.Surface.WOOD},
	{name = "Coffer", size = Vector3i(2, 2, 2), marrow = 16, teeth = 25, relics = 90, surface = MapMaterials.Surface.STONE},
	{name = "Beam", size = Vector3i(1, 4, 1), marrow = 10, teeth = 15, relics = 60, surface = MapMaterials.Surface.BONE},
]

## Gadgets go here once they're designed; each gets its own stall in the hub.
const GADGETS: Array[Dictionary] = []


static func block(type_id: int) -> Dictionary:
	return BLOCKS[type_id] if is_valid_block(type_id) else {}


static func is_valid_block(type_id: int) -> bool:
	return type_id >= 0 and type_id < BLOCKS.size()


## Block size in cells for an orientation: 0 = upright, 1 = lying along X,
## 2 = lying along Z.
static func oriented_size(type_id: int, axis: int) -> Vector3i:
	var s: Vector3i = BLOCKS[type_id].size
	match axis:
		1: return Vector3i(s.y, s.x, s.z)
		2: return Vector3i(s.x, s.z, s.y)
	return s


## Items everyone owns without paying (relics price 0).
static func starter_blocks() -> Array[int]:
	var owned: Array[int] = []
	for i in BLOCKS.size():
		if BLOCKS[i].relics == 0:
			owned.append(i)
	return owned
