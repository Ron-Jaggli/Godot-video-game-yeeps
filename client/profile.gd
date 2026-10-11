extends Node
## Autoload "Profile": the local player's permanent data (Teeth, Relics, owned
## items, quest progress) saved with SecureStore, plus this room's rentals.
## Only used on clients; the dedicated server never loads it.

signal changed
signal quest_completed(quest: Dictionary)

const SLOT := "profile"
const BAN_SLOT := "standing"

var device_id := ""
var teeth := 0
var relics := 0
var owned_blocks: Array[int] = []
var rented_blocks: Array[int] = [] # this room only; never saved
## The save failed its seal. Kept (and saved) until the server has been told,
## so deleting the local ban file doesn't dodge the server-side ban.
var tamper_pending := false
var banned_until := 0 # unix seconds

var _relics_week := 0
var _relics_earned_this_week := 0
var _quests := {} # quest id -> {key: int, progress: int, done: bool}
var _loaded := false


func load_profile(variant := "") -> void:
	if _loaded:
		return
	_loaded = true
	device_id = SecureStore.device_id(variant)

	var standing := SecureStore.load(BAN_SLOT, device_id)
	if standing.status == SecureStore.Status.OK:
		banned_until = int(standing.data.get("until", 0))

	var result := SecureStore.load(SLOT, device_id)
	match result.status:
		SecureStore.Status.OK:
			_apply(result.data)
		SecureStore.Status.MISSING:
			_apply({})
			_save()
		SecureStore.Status.TAMPERED:
			_punish_tampering()


func is_banned() -> bool:
	return banned_until > int(Time.get_unix_time_from_system())


## Banned and nothing left to report: don't even try to connect.
func blocked_from_playing() -> bool:
	return is_banned() and not tamper_pending


func mark_tamper_reported() -> void:
	if tamper_pending:
		tamper_pending = false
		_save()


func can_use_block(type_id: int) -> bool:
	return type_id in owned_blocks or type_id in rented_blocks


## Own a block type for good, paid in Relics.
func buy_block(type_id: int) -> bool:
	var price: int = Economy.block(type_id).get("relics", -1)
	if price < 0 or type_id in owned_blocks or relics < price:
		return false
	relics -= price
	owned_blocks.append(type_id)
	rented_blocks.erase(type_id)
	_save()
	Network.unlock_block(type_id, true)
	changed.emit()
	return true


## Use a block type in the current room only, paid in Teeth.
func rent_block(type_id: int) -> bool:
	var price: int = Economy.block(type_id).get("teeth", -1)
	if price < 0 or can_use_block(type_id) or teeth < price:
		return false
	teeth -= price
	rented_blocks.append(type_id)
	_save()
	Network.unlock_block(type_id, false)
	changed.emit()
	return true


func clear_rentals() -> void:
	rented_blocks.clear()
	changed.emit()


## Counts a stat toward every quest that tracks it and pays out finished ones.
func record(stat: String, amount := 1) -> void:
	var now := int(Time.get_unix_time_from_system())
	var dirty := false
	for quest in Quests.ALL:
		if quest.stat != stat:
			continue
		var state := quest_state(quest)
		if state.done:
			continue
		state.progress = mini(state.progress + amount, quest.target)
		dirty = true
		if state.progress >= quest.target:
			state.done = true
			teeth += quest.teeth
			_grant_relics(quest.relics, now)
			quest_completed.emit(quest)
	if dirty:
		_save()
		changed.emit()


## Progress for a quest in its current day/week (old progress rolls over).
func quest_state(quest: Dictionary) -> Dictionary:
	var key := Quests.period_key(quest.period, int(Time.get_unix_time_from_system()))
	var state: Dictionary = _quests.get(quest.id, {})
	if state.get("key", -1) != key:
		state = {key = key, progress = 0, done = false}
		_quests[quest.id] = state
	return state


func relics_left_this_week() -> int:
	_roll_week(int(Time.get_unix_time_from_system()))
	return maxi(Economy.RELICS_WEEKLY_CAP - _relics_earned_this_week, 0)


func _grant_relics(amount: int, now: int) -> void:
	_roll_week(now)
	var granted := mini(amount, relics_left_this_week())
	relics += granted
	_relics_earned_this_week += granted


func _roll_week(now: int) -> void:
	var week := Quests.week_key(now)
	if week != _relics_week:
		_relics_week = week
		_relics_earned_this_week = 0


## An edited save wipes the profile and bans this device for a while. The
## server is told on connect and enforces the same ban.
func _punish_tampering() -> void:
	_apply({})
	tamper_pending = true
	_save()
	banned_until = int(Time.get_unix_time_from_system()) + Economy.TAMPER_BAN_HOURS * 3600
	SecureStore.save(BAN_SLOT, device_id, {until = banned_until})


func _apply(data: Dictionary) -> void:
	teeth = int(data.get("teeth", 0))
	relics = int(data.get("relics", 0))
	owned_blocks.assign(data.get("owned_blocks", []))
	for starter in Economy.starter_blocks():
		if starter not in owned_blocks:
			owned_blocks.append(starter)
	_relics_week = int(data.get("relics_week", 0))
	_relics_earned_this_week = int(data.get("relics_earned", 0))
	_quests = data.get("quests", {})
	tamper_pending = bool(data.get("tamper_pending", false))


func _save() -> void:
	SecureStore.save(SLOT, device_id, {
		teeth = teeth,
		relics = relics,
		owned_blocks = owned_blocks,
		relics_week = _relics_week,
		relics_earned = _relics_earned_this_week,
		quests = _quests,
		tamper_pending = tamper_pending,
	})
