class_name CGOItemBox
extends RefCounted

## Per-bomber 24-slot active item box (CA.exe RTTI .?AVCGOItemBox@@ @ 0xe30044, CGOBomber::this[655]).
## Manages active/consumable items (Needle family, Oxygen, Dart, Shield, Potion, Banana, Bond, Mine, Pushpin),
## two-tier active slot selection (context_slot this[334] -> manual_slot this[335], 0x5B836B),
## and 24-entry manual selection history ring (0x5B84CB).

const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")

const MAX_SLOTS := 24 # 0..23 (0x5B70E6 / 0x5B75BD / 0x5B8396)
const HISTORY_RING_SIZE := 24 # (tail + 1) % 24 (0x5B84CB)

# Needle variants scanned by CGOBomber::TrySelectNeedle (0x59B51B)
const NEEDLE_ITEM_NAMES: Array[String] = [
	"Item/ItemNiddle",
	"Item/ItemSJNeedle1",
	"Item/ItemSJNeedle2",
	"Item/ItemSJNeedle3",
	"Item/ItemSJNeedle4",
	"Item/ItemSJNeedle5",
	"Item/ItemSJNeedle6",
	"Item/ItemSJNeedle7",
	"Item/ItemCokeNeedle",
	"Item/ItemNeedleG",
	"Item/ItemNeedleC",
	"Item/ItemNeedleSP",
	"Item/ItemNeedleE",
	"Item/ItemNeedleL",
	"Item/ItemNeedleF",
	"Item/ItemNiddleplus",
	"Item/WinningNeedle",
	"Item/WinningNeedleC",
	"Item/ItemNeedle_Bazzi",
	"Item/ItemNeedle_Marid",
	"Item/ItemNeedle_Uni",
]

var enabled: bool = true # this[345] (0x5B7BA3)
var slots: Array[Dictionary] = [] # 24 slots: {name, sprite, item_type, param, count}
var context_slot: int = -1 # this[334] (+1336, 0x5B7F91)
var manual_slot: int = -1 # this[335] (+1340, 0x5B877C)
var history_ring: Array[int] = [] # Circular recent manual slot indices (0x5B84CB)

func _init() -> void:
	clear()

func clear() -> void:
	slots.clear()
	for _i in range(MAX_SLOTS):
		slots.append({})
	context_slot = -1
	manual_slot = -1
	history_ring.clear()

func get_slot(slot_idx: int) -> Dictionary:
	# From sub_5B70E6
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return {}
	return slots[slot_idx]

func get_slot_count(slot_idx: int) -> int:
	# From sub_5B75BD
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return 0
	return int(slots[slot_idx].get("count", 0))

func is_slot_valid(slot_idx: int) -> bool:
	# From sub_5B7BA3
	if not enabled or slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return false
	return get_slot_count(slot_idx) > 0

func is_excluded_from_cycle(slot_idx: int) -> bool:
	# From sub_5B7582: item_type == 12 (mount upgrade) or 24 (Scanner)
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return false
	var t: int = int(slots[slot_idx].get("item_type", 0))
	return t == 12 or t == 24

func find_item_slot(item_name: String) -> int:
	# From sub_5B8396: scan 0..23 for matching active item name
	for i in range(MAX_SLOTS):
		if get_slot_count(i) > 0 and str(slots[i].get("name", "")) == item_name:
			return i
	return -1

func find_slot_by_type(item_type: int, param: int = -1) -> int:
	for i in range(MAX_SLOTS):
		if get_slot_count(i) <= 0:
			continue
		if int(slots[i].get("item_type", 0)) != item_type:
			continue
		if param >= 0 and int(slots[i].get("param", -1)) != param:
			continue
		return i
	return -1

func _resolve_attr(item_name: String, count: int, item_type: int, param: int, sprite: String) -> Dictionary:
	var info: Dictionary = CItemAttrClass.get_item_info(item_name)
	var fields: Array = info.get("fields", [])
	var r_count: int = count if count >= 0 else (int(fields[1]) if fields.size() > 1 and int(fields[1]) > 0 else 1)
	var r_type: int = item_type if item_type >= 0 else (int(fields[2]) if fields.size() > 2 else 0)
	var r_param: int = param if param >= 0 else (int(fields[3]) if fields.size() > 3 else 0)
	var r_sprite: String = sprite if sprite != "" else str(info.get("name2", item_name))
	return {"name": item_name, "sprite": r_sprite, "item_type": r_type, "param": r_param, "count": r_count}

func add_item(item_name: String, count: int = -1, item_type: int = -1, param: int = -1, sprite: String = "") -> int:
	var meta: Dictionary = _resolve_attr(item_name, count, item_type, param, sprite)
	var add_n: int = int(meta.count)
	if add_n <= 0:
		return -1
	# Merge into existing slot with same name, or same ground-trap type (e.g. Banana1/2/3/8)
	var idx: int = find_item_slot(item_name)
	if idx < 0 and int(meta.item_type) == 11:
		idx = find_slot_by_type(11, int(meta.param))
	if idx < 0:
		for i in range(MAX_SLOTS):
			if slots[i].is_empty() or int(slots[i].get("count", 0)) <= 0:
				idx = i
				break
	if idx < 0:
		return -1
	if slots[idx].is_empty() or int(slots[idx].get("count", 0)) <= 0:
		slots[idx] = meta
	else:
		slots[idx]["count"] = int(slots[idx].get("count", 0)) + add_n
	if not is_excluded_from_cycle(idx):
		select_manual_slot(idx)
	return idx

func set_item_count(item_name: String, count: int, item_type: int = -1, param: int = -1, sprite: String = "") -> void:
	var clamped: int = maxi(0, count)
	var idx: int = find_item_slot(item_name)
	if idx < 0 and item_type == 11 and param >= 0:
		idx = find_slot_by_type(11, param)
	if clamped <= 0:
		if idx >= 0:
			slots[idx] = {}
			if context_slot == idx:
				context_slot = -1
			if manual_slot == idx:
				manual_slot = -1
		return
	if idx >= 0:
		slots[idx]["count"] = clamped
	else:
		add_item(item_name, clamped, item_type, param, sprite)

func get_item_count(item_name: String) -> int:
	var total: int = 0
	for i in range(MAX_SLOTS):
		if str(slots[i].get("name", "")) == item_name:
			total += int(slots[i].get("count", 0))
	return total

func get_count_by_type(item_type: int, param: int = -1) -> int:
	var total: int = 0
	for i in range(MAX_SLOTS):
		var c: int = int(slots[i].get("count", 0))
		if c <= 0 or int(slots[i].get("item_type", 0)) != item_type:
			continue
		if param >= 0 and int(slots[i].get("param", -1)) != param:
			continue
		total += c
	return total

func get_needle_total_count() -> int:
	var total: int = 0
	for i in range(MAX_SLOTS):
		var c: int = int(slots[i].get("count", 0))
		if c <= 0:
			continue
		var t: int = int(slots[i].get("item_type", 0))
		if t == 23 or t == 46 or str(slots[i].get("name", "")) in NEEDLE_ITEM_NAMES:
			total += c
	return total

func select_slot(slot_idx: int) -> bool:
	# From sub_5B7F91: sets context_slot (this[334])
	if is_slot_valid(slot_idx):
		context_slot = slot_idx
		return true
	context_slot = -1
	return false

func select_manual_slot(slot_idx: int) -> bool:
	# From sub_5B877C & sub_5B84CB: clears context_slot, sets manual_slot (this[335]), records in history_ring
	context_slot = -1
	if not is_slot_valid(slot_idx):
		manual_slot = -1
		return false
	manual_slot = slot_idx
	if history_ring.is_empty() or history_ring[history_ring.size() - 1] != slot_idx:
		history_ring.append(slot_idx)
		if history_ring.size() > HISTORY_RING_SIZE:
			history_ring.remove_at(0)
	return true

func select_item_by_name(item_name: String) -> bool:
	# From sub_5B872A
	var idx: int = find_item_slot(item_name)
	if idx < 0:
		return false
	return select_slot(idx)

func get_active_slot() -> int:
	# From sub_5B836B: valid context_slot else manual_slot, else first valid slot
	if is_slot_valid(context_slot):
		return context_slot
	context_slot = -1
	if is_slot_valid(manual_slot):
		return manual_slot
	for i in range(MAX_SLOTS):
		if is_slot_valid(i) and not is_excluded_from_cycle(i):
			manual_slot = i
			return i
	return -1

func try_select_needle() -> bool:
	# From sub_59B51B: scans all Needle variants
	for n_name in NEEDLE_ITEM_NAMES:
		if select_item_by_name(n_name):
			return true
	return false

func on_trapped_in_bubble() -> bool:
	# From sub_59E53F: Needle family -> Item/ItemOxygen
	if try_select_needle():
		return true
	return select_item_by_name("Item/ItemOxygen")

func on_match_start() -> bool:
	# From sub_5A517F: Item/ItemScanner -> Item/ItemDart
	if select_item_by_name("Item/ItemScanner"):
		return true
	return select_item_by_name("Item/ItemDart")

func consume_slot(slot_idx: int) -> Dictionary:
	# From sub_5B87B1: decrements slot charge & clears context_slot
	if not is_slot_valid(slot_idx):
		return {}
	var consumed: Dictionary = slots[slot_idx].duplicate()
	var rem: int = int(slots[slot_idx].get("count", 0)) - 1
	if rem <= 0:
		slots[slot_idx] = {}
		if manual_slot == slot_idx:
			manual_slot = -1
	else:
		slots[slot_idx]["count"] = rem
	context_slot = -1
	return consumed

func consume_selected() -> Dictionary:
	var idx: int = get_active_slot()
	if idx < 0:
		return {}
	return consume_slot(idx)

func consume_by_type(item_type: int, param: int = -1) -> Dictionary:
	var idx: int = find_slot_by_type(item_type, param)
	if idx < 0:
		return {}
	return consume_slot(idx)

func consume_needle() -> Dictionary:
	for n_name in NEEDLE_ITEM_NAMES:
		var idx: int = find_item_slot(n_name)
		if idx >= 0:
			return consume_slot(idx)
	return {}

func peek_ground_trap() -> int:
	# Prefers active slot if it is a ground trap (type 11), else Banana(3) -> Bond(1) -> Mine(2) -> Pushpin(4)
	var active: int = get_active_slot()
	if active >= 0 and int(slots[active].get("item_type", 0)) == 11:
		return int(slots[active].get("param", 0))
	for t_param in [3, 1, 2, 4]:
		if find_slot_by_type(11, t_param) >= 0:
			return t_param
	return 0

func get_quick_hud_info(in_bubble: bool) -> Dictionary:
	# Projects active slot onto Game/ItemBox01 (1P L-Ctrl / 2P Ctrl-R)
	if in_bubble:
		var n_cnt: int = get_needle_total_count()
		if n_cnt > 0:
			return {"sprite": "Item/Niddle", "count": n_cnt}
		var o_cnt: int = get_count_by_type(22)
		if o_cnt > 0:
			return {"sprite": "Item/Oxygen", "count": o_cnt}
	var active: int = get_active_slot()
	if active >= 0:
		var s: Dictionary = slots[active]
		return {"sprite": str(s.get("sprite", "")), "count": int(s.get("count", 0))}
	return {}

func get_personal_bar_slots() -> Array[Dictionary]:
	# 6 personal HUD slots (keys 1..6 on Game/GameStageItem)
	return [
		{"kind": "needle", "sprite": "Item/Niddle", "count": get_needle_total_count()},
		{"kind": "oxygen", "sprite": "Item/Oxygen", "count": get_count_by_type(22)},
		{"kind": "dart", "sprite": "Item/Dart", "count": get_count_by_type(21)},
		{"kind": "banana", "sprite": "Item/Banana00", "count": get_count_by_type(11, 3)},
		{"kind": "bond", "sprite": "Item/Bond", "count": get_count_by_type(11, 1)},
		{"kind": "mine", "sprite": "Item/Trap", "count": get_count_by_type(11, 2)},
	]
