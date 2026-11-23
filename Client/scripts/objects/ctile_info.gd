class_name CTileInfo
extends Resource

## Tile attribute resource & loader (CA.exe CMapObjToTileInfo, RTTI .?AVCMapObjToTileInfo@@ @ 0xe54e08).
## Parses 52-byte tagged-union raw blobs from TileInfo/TileInfoList (Client/data/tile_info.json, 0x97818D -> 0x977FFB).

const DATA_PATH := "res://data/tile_info.json"
const TILE_INFO_BYTES := 52
const DEFAULT_BOX_HP := 1
const INDESTRUCTIBLE_HP := 255

@export var tile_name: String = ""
@export var tile_type: int = 0 # 0=Ground, 1=Static, 2=Box, 3=Passable, 4=Deco
@export var width: int = 1
@export var height: int = 1

# type == 0 (Ground)
@export var is_conveyor: bool = false # b[12] > 0 (TileConv/Conv*: 2 px/tick @ 0x5C02AA -> 0x5BFA43)
@export var conveyor_speed_px_per_tick: int = 0 # b[12]: pixels per 30ms tick (2 px/tick = 66.67 px/s)
@export var conveyor_in_mask: int = 0 # b[16]: 1=Left, 2=Up, 4=Right, 8=Down
@export var conveyor_out_dir: int = -1 # b[20]: 0=Left, 1=Up, 2=Right, 3=Down, 255=-1
@export var is_special_ground: bool = false # b[24] == 1 (IslandA*)

# type == 1 (Static)
@export var custom_static_id: int = 0 # b[16..19] (sub_5C15DF -> sub_7453F6)

# type == 2 (Box: CGOTileFixedBox / CGOTileMoveAbleBox)
@export var hp: int = 1 # b[4] (0 -> 1 @ 0x5BF3C0; >= 255 indestructible @ 0x5BF6F9)
@export var is_movable: bool = false # b[8] != 0 -> CGOTileMoveAbleBox
@export var spike_dir_mask: int = 0 # b[12] (v9[68], PinBlock01..05 / Urchins00: 1,2,4,8,16)
@export var explode_on_break: bool = false # b[13] != 0 (v9[69], ExplodeBlock01 -> sub_7322B5 @ 0x5BF5BD)

# type == 3 (Passable: CGOTilePassable)
@export var player_passable_dirs: Array[bool] = [true, true, true, true] # b[4..7] (sub_5C0E98)
@export var bomb_passable_dirs: Array[bool] = [true, true, true, true] # b[8..11] (sub_5C1030)
@export var passable_dirs: Array[bool] = [true, true, true, true] # b[12..15] flame passable (sub_5C10E1)
@export var item_visible_inside: bool = false # b[16] != 0 (ca.exe.c:666537)
@export var bomb_visible_inside: bool = false # b[17] != 0 (ca.exe.c:333307)
@export var detonate_bomb_on_touch: bool = false # b[18] != 0 (PinTile01 spike pit)
@export var conceals_bomber: bool = false # b[19] == 0 (sub_59F04D)
@export var draw_under_player: bool = false # b[20] != 0 (ca.exe.c:661370)
@export var indestructible_by_flame: bool = false # b[24] != 0 (sub_70F346 @ 0x70f47c)

@export var blocks_movement: bool = false
@export var blocks_flame: bool = false

static var _by_name: Dictionary = {}
static var _loaded: bool = false

static func _hex_byte(raw_hex: String, byte_idx: int) -> int:
	var pos: int = byte_idx * 2
	if raw_hex.length() < pos + 2:
		return 0
	return raw_hex.substr(pos, 2).hex_to_int()

static func _hex_u32_le(raw_hex: String, byte_idx: int) -> int:
	return _hex_byte(raw_hex, byte_idx) \
		| (_hex_byte(raw_hex, byte_idx + 1) << 8) \
		| (_hex_byte(raw_hex, byte_idx + 2) << 16) \
		| (_hex_byte(raw_hex, byte_idx + 3) << 24)

static func from_dict(t_name: String, entry: Dictionary) -> CTileInfo:
	var res: CTileInfo = new()
	res.tile_name = t_name
	res.tile_type = int(entry.get("type", 0))
	res.width = int(entry.get("width", 1))
	res.height = int(entry.get("height", 1))
	var raw_hex: String = str(entry.get("raw", ""))

	match res.tile_type:
		0: # Ground (normal / conveyor / island)
			res.blocks_movement = false
			res.blocks_flame = false
			res.conveyor_speed_px_per_tick = _hex_byte(raw_hex, 12)
			res.is_conveyor = res.conveyor_speed_px_per_tick > 0
			res.conveyor_in_mask = _hex_byte(raw_hex, 16)
			var out_d: int = _hex_byte(raw_hex, 20)
			res.conveyor_out_dir = out_d if out_d < 4 else -1
			res.is_special_ground = _hex_byte(raw_hex, 24) != 0
		1: # Static wall/obstacle
			res.blocks_movement = true
			res.blocks_flame = true
			res.custom_static_id = _hex_u32_le(raw_hex, 16)
		2: # Breakable / Movable Box
			res.blocks_movement = true
			res.blocks_flame = true
			var raw_hp: int = _hex_byte(raw_hex, 4)
			res.hp = raw_hp if raw_hp > 0 else DEFAULT_BOX_HP # 0x5BF3C0 @ 0x5bf46f
			res.is_movable = _hex_byte(raw_hex, 8) != 0
			res.spike_dir_mask = _hex_byte(raw_hex, 12) # v9[68]
			res.explode_on_break = _hex_byte(raw_hex, 13) != 0 # v9[69]
		3: # Passable bush / tent / water / pin tile
			res.player_passable_dirs = [
				_hex_byte(raw_hex, 4) != 0,
				_hex_byte(raw_hex, 5) != 0,
				_hex_byte(raw_hex, 6) != 0,
				_hex_byte(raw_hex, 7) != 0,
			]
			res.bomb_passable_dirs = [
				_hex_byte(raw_hex, 8) != 0,
				_hex_byte(raw_hex, 9) != 0,
				_hex_byte(raw_hex, 10) != 0,
				_hex_byte(raw_hex, 11) != 0,
			]
			res.passable_dirs = [
				_hex_byte(raw_hex, 12) != 0,
				_hex_byte(raw_hex, 13) != 0,
				_hex_byte(raw_hex, 14) != 0,
				_hex_byte(raw_hex, 15) != 0,
			]
			res.item_visible_inside = _hex_byte(raw_hex, 16) != 0
			res.bomb_visible_inside = _hex_byte(raw_hex, 17) != 0
			res.detonate_bomb_on_touch = _hex_byte(raw_hex, 18) != 0
			res.conceals_bomber = _hex_byte(raw_hex, 19) == 0 # sub_59F04D
			res.draw_under_player = _hex_byte(raw_hex, 20) != 0
			res.indestructible_by_flame = _hex_byte(raw_hex, 24) != 0 # sub_70F346
			res.blocks_movement = not (res.player_passable_dirs[0] or res.player_passable_dirs[1] or res.player_passable_dirs[2] or res.player_passable_dirs[3])
			res.blocks_flame = not (res.passable_dirs[0] or res.passable_dirs[1] or res.passable_dirs[2] or res.passable_dirs[3])
		_: # Deco (4)
			res.blocks_movement = false
			res.blocks_flame = false
	return res

static func load_data(file_path: String = DATA_PATH) -> void:
	if _loaded and not _by_name.is_empty():
		return
	if not FileAccess.file_exists(file_path):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not (raw is Dictionary):
		return
	_by_name.clear()
	for k in raw.keys():
		var entry: Variant = raw[k]
		if entry is Dictionary:
			_by_name[str(k)] = from_dict(str(k), entry)
	_loaded = true

static func get_count() -> int:
	load_data()
	return _by_name.size()

static func has_spike_for_dir(mask: int, dir_idx: int) -> bool:
	# From sub_7299A8 (CPlayMap::HasSpikeForDir):
	# dir -1=omni(0x10), 0=Left->Right face(0x04), 1=Up->Down face(0x08), 2=Right->Left face(0x01), 3=Down->Up face(0x02)
	match dir_idx:
		-1: return (mask & 0x10) != 0
		0: return (mask & 0x04) != 0
		1: return (mask & 0x08) != 0
		2: return (mask & 0x01) != 0
		3: return (mask & 0x02) != 0
		_: return false

static func get_info(t_name: String) -> CTileInfo:
	load_data()
	return _by_name.get(t_name, null)
