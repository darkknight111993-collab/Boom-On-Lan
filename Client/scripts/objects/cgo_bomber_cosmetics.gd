class_name CGOBomberCosmetics
extends RefCounted

## 13-slot character cosmetic manager and 90-state -> 44-frame AvatarDeco resolver.
## Ported from CA.exe (0x58E281, 0x58E2DA, 0x58E4E0, 0x58EE0D, 0x8BE9E1, 0x970BBC,
## CGOTAvatar::ComposeFrames 0x5C9741 -> sub_8D9F9C 0x8D9F9C -> sub_8D5463 0x8D5463).

const MAX_SLOTS: int = 13

# .rdata 0xC37AE0..0xC37AF7: Lobby/Shop Display & HUD Portrait frame mappings
const DISPLAY_LAYER: int = 2
const DISPLAY_START_FRAME: int = 0
const PORTRAIT_LAYER: int = 2
const PORTRAIT_START_FRAMES: Array[int] = [41, 43]

# .rdata 0xC37AF8[90]: layer index per CGOBomberBase state (0 = _0, 2 = _1, -1 = hidden)
const STATE_LAYER: Array[int] = [
	2, -1, -1, 2, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 2, 2, 2, 2,
	0, 0, 0, 0, 2, -1, 2, 0, 0, 0,
	0, 0, 0, 0, 0, 2, 2, 2, 2, 0,
	0, 0, 0, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, 0, 0, 0, 0,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
]

# .rdata 0xC37C60[90]: start frame index (0..43) in the 44-frame AvatarDeco sheet (-1 = hidden)
const STATE_START_FRAME: Array[int] = [
	0, -1, -1, 3, 40, 36, 32, 28, 40, 36,
	32, 28, 15, 10, 5, 0, 25, 25, 25, 25,
	15, 10, 5, 0, 15, -1, 3, 20, 20, 20,
	20, 20, 20, 20, 20, 7, 7, 7, 7, 24,
	24, 24, 24, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, 15, 10, 5, 0,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
]

var slots: Array[String] = []
var char_deco: String = ""
var id_deco: String = ""

func _init() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = ""

static func slot_to_part_code(slot_idx: int) -> int:
	# Exact CA.exe sub_58E281 (0x58E281)
	if slot_idx >= 0 and slot_idx <= 9:
		return 10 * slot_idx
	match slot_idx:
		10:
			return 21
		11:
			return 41
		12:
			return 22
	return 0

static func format_avatar_deco_path(char_id: int, slot_idx: int, deco_id: int) -> String:
	# Exact CA.exe sub_58E2DA -> sub_58E4E0 ("AvatarDeco/A%02d_%2d_%04d")
	return "AvatarDeco/A%02d_%2d_%04d" % [char_id, slot_to_part_code(slot_idx), deco_id]

static func is_char_compatible(equip_char_id: int, char_id: int) -> bool:
	# Exact CA.exe sub_970BBC (0x970BBC)
	if equip_char_id == char_id:
		return true
	if char_id == 12 and equip_char_id == 6:
		return true
	if char_id == 14 and equip_char_id == 5:
		return true
	if char_id == 15 and equip_char_id == 8:
		return true
	return false

static func get_conflicting_slots(slot_idx: int) -> Array[int]:
	# Exact CA.exe sub_8BE9E1 (0x8BE9E1), called by sub_58EE0D @ 0x58ef08
	match slot_idx:
		2, 3:
			return [10, 12]
		4, 6:
			return [11, 12]
		10:
			return [2, 3, 12]
		11:
			return [4, 6, 12]
		12:
			return [2, 3, 4, 6, 10, 11]
	return []

static func resolve_avatar_deco_frame(state_idx: int, base_frame_idx: int) -> Dictionary:
	# Exact CA.exe CGOTAvatar::ComposeFrames (0x5C9741) -> sub_8D5463 (0x8D5463)
	if state_idx < 0 or state_idx >= STATE_LAYER.size():
		return {}
	var layer: int = STATE_LAYER[state_idx]
	var start: int = STATE_START_FRAME[state_idx]
	if layer < 0 or start < 0:
		return {}
	return {
		"sheet_idx": 0 if layer == 0 else 1,
		"frame_idx": start + maxi(base_frame_idx, 0),
	}

func equip_slot(slot_idx: int, sprite_base: String) -> Array[int]:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return []
	var cleared: Array[int] = []
	for conflict_idx: int in get_conflicting_slots(slot_idx):
		if slots[conflict_idx] != "":
			slots[conflict_idx] = ""
			cleared.append(conflict_idx)
	slots[slot_idx] = sprite_base
	return cleared

func clear_slot(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < MAX_SLOTS:
		slots[slot_idx] = ""

func clear_all() -> void:
	for i in range(MAX_SLOTS):
		slots[i] = ""
	char_deco = ""
	id_deco = ""

func has_any_avatar_deco() -> bool:
	for s: String in slots:
		if s != "":
			return true
	return false

func get_active_slots() -> Array[String]:
	var active: Array[String] = []
	for s: String in slots:
		if s != "":
			active.append(s)
	return active
