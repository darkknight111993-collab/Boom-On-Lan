class_name CUserInventoryMan
extends RefCounted

## Account inventory, currency balance, cosmetic equip, and 6-slot match loadout manager.
## Ported from CA.exe CUserInventoryMan (0xe48740, 0x8BA9DF) & CUserItemMan (0xe487fc, 0x8C07AC).

const CGOItemBoxClass = preload("res://scripts/objects/cgo_item_box.gd")

const PERSONAL_SLOT_COUNT: int = 6
const DEFAULT_BOMB_SKIN: String = "Bomb/Bomb00"
const DEFAULT_CHARACTER: String = "Character/C00"

# Default consumable metadata for personal_loadout -> CGOItemBox population
const CONSUMABLE_META := {
	"Item/ItemNiddle": {"item_type": 23, "trap_type": 0, "sprite": "Item/Niddle"},
	"Item/ItemOxygen": {"item_type": 22, "trap_type": 0, "sprite": "Item/Oxygen"},
	"Item/ItemDart": {"item_type": 21, "trap_type": 0, "sprite": "Item/Dart"},
	"Banana3": {"item_type": 11, "trap_type": 3, "sprite": "Item/Banana00"},
	"Item/ItemBond": {"item_type": 11, "trap_type": 1, "sprite": "Item/Bond"},
	"Item/ItemTrap": {"item_type": 11, "trap_type": 2, "sprite": "Item/Trap"},
	"Pin": {"item_type": 11, "trap_type": 4, "sprite": "Item/Pushpin"},
}

var lucci: int = 10000
var cash: int = 1000
var owned_items: Dictionary = {} # item_id -> {"count": int, "equipped": bool, "item_code": String, "slot_type": String, "sprite": String, "item_type": int, "trap_type": int}
var equipped_cosmetics: Dictionary = {
	"hat": "",
	"cloth": "",
	"face": "",
	"char_deco": "",
	"id_deco": "",
	"bomb_skin": DEFAULT_BOMB_SKIN,
	"mount": "",
	"character": DEFAULT_CHARACTER,
}
var personal_loadout: Array[String] = [
	"Item/ItemNiddle",
	"Item/ItemOxygen",
	"Item/ItemDart",
	"Banana3",
	"Item/ItemBond",
	"Item/ItemTrap",
]

func can_afford(entry: Dictionary) -> bool:
	var price: int = maxi(0, int(entry.get("price", 0)))
	var currency: String = str(entry.get("currency", "lucci")).to_lower()
	if currency == "cash":
		return cash >= price
	return lucci >= price

func purchase_item(entry: Dictionary) -> Dictionary:
	var item_id: String = str(entry.get("id", ""))
	if item_id == "":
		return {"ok": false, "reason": "invalid_item", "lucci": lucci, "cash": cash}
	var price: int = maxi(0, int(entry.get("price", 0)))
	var currency: String = str(entry.get("currency", "lucci")).to_lower()
	if not can_afford(entry):
		return {"ok": false, "reason": "insufficient_funds", "lucci": lucci, "cash": cash}
	if currency == "cash":
		cash -= price
	else:
		lucci -= price

	var charges: int = maxi(1, int(entry.get("charges", 1)))
	var prev: Dictionary = owned_items.get(item_id, {})
	var new_count: int = int(prev.get("count", 0)) + charges
	owned_items[item_id] = {
		"count": new_count,
		"equipped": bool(prev.get("equipped", false)),
		"item_code": str(entry.get("item_code", "")),
		"slot_type": str(entry.get("slot_type", "")),
		"sprite": str(entry.get("sprite", "")),
		"item_type": int(entry.get("item_type", 0)),
		"trap_type": int(entry.get("trap_type", 0)),
	}
	return {"ok": true, "reason": "", "lucci": lucci, "cash": cash, "count": new_count}

func is_owned(item_id: String) -> bool:
	return owned_items.has(item_id) and int((owned_items[item_id] as Dictionary).get("count", 0)) > 0

func equip_item(entry: Dictionary) -> bool:
	var slot_type: String = str(entry.get("slot_type", ""))
	var item_code: String = str(entry.get("item_code", ""))
	if slot_type == "" or item_code == "":
		return false
	if slot_type == "consumable":
		if not personal_loadout.has(item_code):
			if personal_loadout.size() < PERSONAL_SLOT_COUNT:
				personal_loadout.append(item_code)
			else:
				personal_loadout[PERSONAL_SLOT_COUNT - 1] = item_code
		return true
	if not equipped_cosmetics.has(slot_type):
		return false
	# Clear previous equipped flag for same slot_type
	for k: String in owned_items.keys():
		var rec: Dictionary = owned_items[k]
		if str(rec.get("slot_type", "")) == slot_type:
			rec["equipped"] = false
	equipped_cosmetics[slot_type] = item_code
	var item_id: String = str(entry.get("id", ""))
	if item_id != "" and owned_items.has(item_id):
		(owned_items[item_id] as Dictionary)["equipped"] = true
	return true

func unequip_slot(slot_type: String) -> void:
	if not equipped_cosmetics.has(slot_type):
		return
	for k: String in owned_items.keys():
		var rec: Dictionary = owned_items[k]
		if str(rec.get("slot_type", "")) == slot_type:
			rec["equipped"] = false
	match slot_type:
		"bomb_skin":
			equipped_cosmetics["bomb_skin"] = DEFAULT_BOMB_SKIN
		"character":
			equipped_cosmetics["character"] = DEFAULT_CHARACTER
		_:
			equipped_cosmetics[slot_type] = ""

func get_owned_consumable_count(item_code: String) -> int:
	var total: int = 0
	for k: String in owned_items.keys():
		var rec: Dictionary = owned_items[k]
		if str(rec.get("item_code", "")) == item_code:
			total += int(rec.get("count", 0))
	return total

func apply_to_bomber_item_box(item_box: CGOItemBoxClass) -> void:
	if item_box == null:
		return
	for code: String in personal_loadout:
		var count: int = get_owned_consumable_count(code)
		if count <= 0:
			continue
		var meta: Dictionary = CONSUMABLE_META.get(code, {})
		var itype: int = int(meta.get("item_type", 0))
		var ttype: int = int(meta.get("trap_type", 0))
		var spr: String = str(meta.get("sprite", ""))
		# Fallback to metadata saved on owned_items record if not in CONSUMABLE_META
		if itype == 0:
			for k: String in owned_items.keys():
				var rec: Dictionary = owned_items[k]
				if str(rec.get("item_code", "")) == code:
					itype = int(rec.get("item_type", 0))
					ttype = int(rec.get("trap_type", 0))
					if spr == "":
						spr = str(rec.get("sprite", ""))
					break
		item_box.add_item(code, count, itype, ttype, spr)
	item_box.on_match_start()

func to_dict() -> Dictionary:
	return {
		"lucci": lucci,
		"cash": cash,
		"owned_items": owned_items.duplicate(true),
		"equipped_cosmetics": equipped_cosmetics.duplicate(true),
		"personal_loadout": personal_loadout.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	lucci = int(d.get("lucci", lucci))
	cash = int(d.get("cash", cash))
	var raw_owned: Variant = d.get("owned_items", null)
	if raw_owned is Dictionary:
		owned_items = (raw_owned as Dictionary).duplicate(true)
	var raw_eq: Variant = d.get("equipped_cosmetics", null)
	if raw_eq is Dictionary:
		for k: String in equipped_cosmetics.keys():
			if (raw_eq as Dictionary).has(k):
				equipped_cosmetics[k] = str((raw_eq as Dictionary)[k])
	var raw_lo: Variant = d.get("personal_loadout", null)
	if raw_lo is Array:
		personal_loadout.clear()
		for s: Variant in (raw_lo as Array):
			personal_loadout.append(str(s))
