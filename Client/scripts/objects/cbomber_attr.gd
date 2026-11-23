class_name CBomberAttr
extends Resource

## Character attribute table & entry resource (CA.exe CBomberAttr, RTTI .?AVCBomberAttr@@ @ 0xe5471c).
## Loaded from Attr/BomberAttr (Client/data/bomber_attr.json), up to 43 entries (0x9710C1).
## Field order verified in sub_97124A (0x971472..0x97150d):
##   stats[0]: category
##   stats[1]: speed_init   | stats[2]: speed_max
##   stats[3]: bomb_init    | stats[4]: bomb_max (hard-capped <= 10 @ 0x9714c5)
##   stats[5]: power_init   | stats[6]: power_max
##   stats[7..9]: extra ints (unused by client gameplay)

const DATA_PATH := "res://data/bomber_attr.json"
const MAX_SLOTS := 43
const BOMB_MAX_CAP := 10
const TICK_MS := 30.0 # 30ms per tick in CA engine

@export var char_id: int = 0
@export var char_name: String = "Character/C00"
@export var short_name: String = "C00"
@export var prepare_path: String = "Prepare/C00"
@export var display_path: String = "Character/C00_Display"
@export var portrait_path: String = "Character/C00_Portrait"
@export var emotion_path: String = "Character/C00_Emotion"
@export var category: int = 0
@export var speed_init: int = 5
@export var speed_max: int = 7
@export var bomb_init: int = 1
@export var bomb_max: int = 10
@export var power_init: int = 1
@export var power_max: int = 7
@export var extra_fields: Array[int] = [10, 100, 9]

static var _data: Dictionary = {}
static var _by_name: Dictionary = {}
static var _by_id: Dictionary = {}
static var _loaded: bool = false

static func from_dict(entry: Dictionary, idx: int = 0) -> CBomberAttr:
	# From sub_97124A (CBomberAttr::Load)
	var res: CBomberAttr = new()
	res.char_id = idx
	res.char_name = str(entry.get("name", "Character/C00"))
	var slash_pos: int = res.char_name.find("/")
	res.short_name = res.char_name.substr(slash_pos + 1) if slash_pos >= 0 else res.char_name
	res.prepare_path = "Prepare/" + res.short_name
	res.display_path = res.char_name + "_Display"
	res.portrait_path = res.char_name + "_Portrait"
	res.emotion_path = res.char_name + "_Emotion"

	var s: Array = entry.get("stats", [])
	if s.size() >= 7:
		res.category = int(s[0])
		res.speed_init = int(s[1])
		res.speed_max = int(s[2])
		res.bomb_init = int(s[3])
		res.bomb_max = mini(int(s[4]), BOMB_MAX_CAP) # 0x9714c5: cap bomb_max <= 10
		res.power_init = int(s[5])
		res.power_max = int(s[6])
	if s.size() >= 10:
		res.extra_fields = [int(s[7]), int(s[8]), int(s[9])]
	return res

func to_stats_dict() -> Dictionary:
	return {
		"category": category,
		"speed_start": speed_init,
		"speed_max": speed_max,
		"bomb_start": bomb_init,
		"bomb_max": bomb_max,
		"power_start": power_init,
		"power_max": power_max,
		"kick_cap": extra_fields[0] if extra_fields.size() > 0 else 10,
		"special": extra_fields[1] if extra_fields.size() > 1 else 100,
		"extra": extra_fields[2] if extra_fields.size() > 2 else 9,
	}

static func load_data(file_path: String = DATA_PATH) -> void:
	if _loaded and not _by_name.is_empty():
		return
	if not FileAccess.file_exists(file_path):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not (raw is Array):
		return
	_data.clear()
	_by_name.clear()
	_by_id.clear()
	var idx: int = 0
	for item in raw:
		if not (item is Dictionary):
			continue
		var res: CBomberAttr = from_dict(item, idx)
		_by_id[idx] = res
		_by_name[res.char_name] = res
		_by_name[res.short_name] = res
		_data[res.char_name] = res.to_stats_dict()
		idx += 1
	_loaded = true

static func get_count() -> int:
	load_data()
	return _by_id.size()

static func get_attr(key: Variant) -> CBomberAttr:
	load_data()
	if key is int or (key is float and int(key) == key):
		return _by_id.get(int(key), _by_name.get("Character/C00", null))
	var k: String = str(key)
	if _by_name.has(k):
		return _by_name[k]
	if not k.begins_with("Character/") and _by_name.has("Character/" + k):
		return _by_name["Character/" + k]
	return _by_name.get("Character/C00", null)

static func get_stats(char_code: String) -> Dictionary:
	load_data()
	var attr: CBomberAttr = get_attr(char_code)
	if attr != null:
		return attr.to_stats_dict()
	return {
		"category": 0,
		"speed_start": 5,
		"speed_max": 7,
		"bomb_start": 1,
		"bomb_max": 10,
		"power_start": 1,
		"power_max": 7,
		"kick_cap": 10,
		"special": 100,
		"extra": 9,
	}

## Converts original integer speed (1..10) into Godot world pixels per second.
## Classic Crazy Arcade calibration: 18.0 px/s per speed unit (~90 px/s at speed 5).
static func speed_to_pixels_per_sec(speed_val: int) -> float:
	return float(speed_val) * 18.0
