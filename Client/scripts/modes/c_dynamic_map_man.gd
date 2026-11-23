class_name CDynamicMapMan
extends RefCounted

## Pure headless-testable map catalog & mode-filter manager.
## Mirrors CA.exe CDynamicMapMan (RTTI 0xE3E3B8, dword_E60930):
##   - sub_6E0D2C (BuildFilteredList)
##   - sub_6DEE48 (IsMapSelectable, all 11 mode_filter cases 0..10)
##   - sub_6DD516 (IsMapAllowedForGameType, group_id +41 rules)
##   - sub_6DF780 (GetDefaultMapIndex, MonBeginnerRandom/MonEasyRandom)
##   - sub_6E077C (ParseDynMapInfo player-limit byte +108 decode)
##   - sub_68B85D (MapSelect_PlayerLimitOver)

const GAME_MODES_PATH := "res://data/game_modes.json"
const MAP_GROUP_PATH := "res://data/map_group.json"
const CLobbyFlowClass = preload("res://scripts/modes/c_lobby_flow.gd")

# Exact CA.exe sub_6DC035 (this + 120) mode_filter enum (0x6DEE48)
const MODE_FILTER_DEFAULT: int = 0
const MODE_FILTER_PRACTICE_SOLO: int = 1
const MODE_FILTER_SPECIAL_PVP: int = 2
const MODE_FILTER_MONSTER: int = 3
const MODE_FILTER_MONSTER_FILTERED: int = 4  # forces component_id = 0 in sub_6DEE48
const MODE_FILTER_AI_BATTLE: int = 5         # forces component_id = 0 in sub_6DEE48
const MODE_FILTER_CAPTAIN_ZZOLMAN: int = 6   # group_id 0xF1 (241) or category_type 12
const MODE_FILTER_TIMEBOMB_SNOWBALL: int = 7 # group_id 0xEF (239) or category_type 13
const MODE_FILTER_IAM_BOSS: int = 8          # group_id 0x89 (137) or category_type 24
const MODE_FILTER_AI_BATTLE_NO_TEAM: int = 9 # delegates to case 5 with a3 = 0
const MODE_FILTER_SPECIAL_HIDDEN: int = 10   # group_id 0x92 (146) or category_type 29

# Backward-compatible aliases for offline channel_strategy/map_group.json
const MODE_FILTER_LADDER: int = MODE_FILTER_SPECIAL_PVP
const MODE_FILTER_PRACTICE: int = MODE_FILTER_PRACTICE_SOLO

# Maps detailed CLobbyFlow mode keys (component_id_to_mode_key) -> game_modes.json pool keys
const MODE_KEY_ALIASES: Dictionary = {
	"survival": "gametype",
	"hedgehog": "gametype",
	"captain": "gametype",
	"timebomb": "gametype",
	"monster": "monster2",
	"stage_clear": "monster2",
	"mon_season2": "monster2",
	"ai_battle": "battle",
	"super_fighter": "superf2",
	"super_fighter2": "superf2",
	"super_fighter_var": "superf2",
	"hidden_catch_comp": "hidden_catch",
	"hidden_catch_single": "hidden_catch",
}

const MODE_NAME_VN_OVERRIDES: Dictionary = {
	"kart": "Đua Xe Kart",
	"bula": "Bula",
	"survival": "Sinh Tồn",
	"hedgehog": "Chế độ Nhím",
	"captain": "Thủ Lĩnh",
	"timebomb": "Bom Hẹn Giờ",
	"monster": "Săn Quái",
	"stage_clear": "Săn Quái",
	"mon_season2": "Săn Boss 2",
	"ai_battle": "Đấu Máy",
	"super_fighter": "Super Fighter",
	"super_fighter2": "Super Fighter 2",
	"super_fighter_var": "Super Fighter",
	"iam_boss": "Tôi là Boss",
	"hidden_catch": "Tìm Điểm Khác",
	"hidden_catch_comp": "Tìm Điểm Khác (Thi Đấu)",
	"hidden_catch_single": "Tìm Điểm Khác (Đơn)",
}

var modes: Array = []
var _modes_by_id: Dictionary = {}
var map_groups: Dictionary = {} # group_name -> Array[String]
var _map_meta: Dictionary = {} # map_code -> {group_id, category_type, max_players, ai_restrict, is_random, disabled}

func _init(modes_path: String = GAME_MODES_PATH, groups_path: String = MAP_GROUP_PATH) -> void:
	load_files(modes_path, groups_path)

func load_files(modes_path: String = GAME_MODES_PATH, groups_path: String = MAP_GROUP_PATH) -> bool:
	modes.clear()
	_modes_by_id.clear()
	map_groups.clear()
	_map_meta.clear()
	var ok: bool = false
	if FileAccess.file_exists(modes_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(modes_path))
		if parsed is Dictionary:
			var pd := parsed as Dictionary
			modes = pd.get("modes", [])
			for m: Dictionary in modes:
				var mid: String = str(m.get("id", ""))
				if mid != "":
					_modes_by_id[mid] = m
			var raw_meta: Variant = pd.get("map_meta", {})
			if raw_meta is Dictionary:
				for mk: String in raw_meta:
					if raw_meta[mk] is Dictionary:
						_map_meta[mk] = (raw_meta[mk] as Dictionary).duplicate(true)
			ok = true
	if FileAccess.file_exists(groups_path):
		var gp: Variant = JSON.parse_string(FileAccess.get_file_as_string(groups_path))
		if gp is Array:
			for g: Dictionary in gp:
				var gname: String = str(g.get("name", ""))
				if gname != "":
					var mlist: Array[String] = []
					for mc in g.get("maps", []):
						mlist.append(str(mc))
					map_groups[gname] = mlist
	return ok

func get_game_modes() -> Array:
	return modes

func resolve_mode_key(mode_id: String) -> String:
	var k: String = mode_id.to_lower()
	if _modes_by_id.has(k):
		return k
	return str(MODE_KEY_ALIASES.get(k, k))

func get_mode_info(mode_id: String) -> Dictionary:
	return _modes_by_id.get(resolve_mode_key(mode_id), {})

func get_mode_name_vn(mode_id: String) -> String:
	var k: String = mode_id.to_lower()
	if MODE_NAME_VN_OVERRIDES.has(k):
		return str(MODE_NAME_VN_OVERRIDES[k])
	var info: Dictionary = get_mode_info(k)
	return str(info.get("name_vn", "Đại Chiến"))

func get_map_group(group_name: String) -> Array[String]:
	var out: Array[String] = []
	for mc in map_groups.get(group_name, []):
		out.append(str(mc))
	return out

func register_map_meta(map_code: String, meta: Dictionary) -> void:
	_map_meta[map_code] = meta.duplicate(true)

func get_map_meta(map_code: String) -> Dictionary:
	return _map_meta.get(map_code, {})

static func decode_player_limit_byte(raw_v27: int) -> Dictionary:
	# Exact CA.exe sub_6E077C (0x6E077C): if (v27 / 10 == 1) { v27 %= 10; v33 = 1; }
	var v: int = raw_v27 & 0xFF
	if int(v / 10) == 1:
		return {"max_players": v % 10, "tier_flag": true}
	return {"max_players": v, "tier_flag": false}

static func is_map_allowed_for_game_type(group_id: int, component_id: int, super21_enabled: bool = true) -> bool:
	# Exact CA.exe sub_6DD516 (0x6DD516) byte +41 (group_id) rules
	if group_id == 109:
		return component_id == 18 or component_id == 21 or component_id == 25
	if group_id == 112:
		if component_id == 21 or component_id == 25:
			return true
		if component_id == 18:
			return super21_enabled
		return false
	if group_id == 238 and (component_id == 10 or component_id == 11 or component_id == 12 or component_id == 13):
		return false
	if group_id == 137:
		return component_id == 27
	if component_id == 27:
		return false
	if (component_id == 15 or component_id == 16) and (group_id == 120 or group_id == 106 or group_id == 238):
		return false
	return true

static func is_map_selectable(record: Dictionary, component_id: int, mode_filter: int = MODE_FILTER_DEFAULT, show_all: bool = true, super21_enabled: bool = true) -> bool:
	# Exact CA.exe sub_6DEE48 (0x6DEE48) switch (mode_filter 0..10) + sub_6DD516
	if bool(record.get("disabled", false)):
		return false
	if not show_all and bool(record.get("extended_only", false)):
		return false
	var cat: int = int(record.get("category_type", 0))
	var grp: int = int(record.get("group_id", 0))
	var is_monster: bool = (cat == 6) or bool(record.get("is_monster_group", false))
	var is_case6: bool = (grp == 0xF1) or (cat == 12)
	var is_case7: bool = (grp == 0xEF) or (cat == 13)
	var is_case8: bool = (grp == 0x89) or (cat == 24)
	var is_case10: bool = (grp == 0x92) or (cat == 29)
	var is_random: bool = bool(record.get("is_random", false))
	var ai_restrict: bool = bool(record.get("ai_restrict", false))
	var eff_comp: int = component_id
	match mode_filter:
		MODE_FILTER_MONSTER:
			if not is_monster and not is_random:
				return false
		MODE_FILTER_MONSTER_FILTERED:
			if not is_monster or is_random:
				return false
			eff_comp = 0
		MODE_FILTER_AI_BATTLE, MODE_FILTER_AI_BATTLE_NO_TEAM:
			if is_monster or is_case6 or is_case7 or is_random:
				return false
			if not is_map_allowed_for_game_type(grp, 16, super21_enabled):
				return false
			if ai_restrict and cat != 3:
				return false
			if mode_filter == MODE_FILTER_AI_BATTLE:
				eff_comp = 0
		MODE_FILTER_CAPTAIN_ZZOLMAN:
			if not is_case6 and not is_random:
				return false
		MODE_FILTER_TIMEBOMB_SNOWBALL:
			if not is_case7 and not is_random:
				return false
		MODE_FILTER_IAM_BOSS:
			if not is_case8 and not is_random:
				return false
		MODE_FILTER_SPECIAL_HIDDEN:
			if not is_case10 and not is_random:
				return false
		_:
			# Cases 0 (default), 1 (practice/solo), 2 (special PvP) via sub_6DCD82
			if is_monster or is_case6 or is_case7:
				return false
			if mode_filter == MODE_FILTER_SPECIAL_PVP and bool(record.get("pvp_restricted", false)):
				return false
			if mode_filter != MODE_FILTER_PRACTICE_SOLO and bool(record.get("solo_only", false)):
				return false
	return is_map_allowed_for_game_type(grp, eff_comp, super21_enabled)

static func vn_sort_key(text: String) -> String:
	var s: String = text.to_lower()
	const GROUPS := [
		["a", "àáạảãâầấậẩẫăằắặẳẵ"],
		["d", "đ"],
		["e", "èéẹẻẽêềếệểễ"],
		["i", "ìíịỉĩ"],
		["o", "òóọỏõôồốộổỗơờớợởỡ"],
		["u", "ùúụủũưừứựửữ"],
		["y", "ỳýỵỷỹ"],
	]
	for g: Array in GROUPS:
		var rep: String = g[0]
		var chars: String = g[1]
		for i in chars.length():
			s = s.replace(chars[i], rep)
	return s

static func sort_maps_by_name(map_list: Array, name_resolver: Callable = Callable()) -> Array[String]:
	var keyed: Array = []
	for mc in map_list:
		var code: String = str(mc)
		var disp: String = str(name_resolver.call(code)) if name_resolver.is_valid() else code
		keyed.append({"code": code, "key": vn_sort_key(disp)})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var c: int = (a["key"] as String).naturalnocasecmp_to(b["key"] as String)
		if c != 0:
			return c < 0
		return (a["code"] as String).naturalnocasecmp_to(b["code"] as String) < 0
	)
	var out: Array[String] = []
	for item: Dictionary in keyed:
		out.append(str(item["code"]))
	return out

static func get_map_theme_prefix(map_code: String) -> String:
	var idx: int = 0
	while idx < map_code.length():
		var c: int = map_code.unicode_at(idx)
		if c >= 48 and c <= 57:
			break
		idx += 1
	return map_code.substr(0, idx) if idx > 0 else map_code

static func get_themes_for_maps(map_list: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for mc: String in map_list:
		var pref: String = get_map_theme_prefix(mc)
		var low: String = pref.to_lower()
		if low != "" and not seen.has(low):
			seen[low] = true
			out.append(pref)
	out.sort()
	return out

func get_maps_for_mode(mode_id: String, show_all: bool = false) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var info: Dictionary = get_mode_info(mode_id)
	for mc in info.get("maps", []):
		var s: String = str(mc)
		if not seen.has(s):
			seen[s] = true
			out.append(s)
	if show_all:
		for mc in info.get("extended_maps", []):
			var s: String = str(mc)
			if not seen.has(s):
				seen[s] = true
				out.append(s)
	return out

func get_maps(component_id: int, channel_strategy: String = "normal", mode_filter: int = MODE_FILTER_DEFAULT, show_all: bool = false, theme_prefix: String = "") -> Array[String]:
	# Offline map_group.json overrides for Ladder & Practice channels
	var list: Array[String] = []
	if channel_strategy == "ladder":
		list = get_map_group("LadderMapGroup")
	elif mode_filter == MODE_FILTER_PRACTICE_SOLO:
		list = get_map_group("PraticeMapGroup")
	if list.is_empty():
		var mode_key: String = CLobbyFlowClass.component_id_to_mode_key(component_id)
		list = get_maps_for_mode(mode_key, show_all)
		if list.is_empty() and mode_key != "normal":
			list = get_maps_for_mode("normal", show_all)
	var pref_low: String = theme_prefix.strip_edges().to_lower()
	if pref_low != "":
		var themed: Array[String] = []
		for mc: String in list:
			if get_map_theme_prefix(mc).to_lower() == pref_low:
				themed.append(mc)
		list = themed
	if _map_meta.is_empty():
		return list
	var filtered: Array[String] = []
	for mc: String in list:
		var rec: Dictionary = _map_meta.get(mc, {})
		if rec.is_empty() or is_map_selectable(rec, component_id, mode_filter, show_all):
			filtered.append(mc)
	return filtered

func get_default_map(component_id: int, channel_strategy: String = "normal", mode_filter: int = MODE_FILTER_DEFAULT, is_easy_monster: bool = false) -> String:
	if channel_strategy == "ladder":
		var ladder_maps: Array[String] = get_map_group("LadderMapGroup")
		if not ladder_maps.is_empty():
			return ladder_maps[0]
	if mode_filter == MODE_FILTER_PRACTICE_SOLO:
		var prac_maps: Array[String] = get_map_group("PraticeMapGroup")
		if not prac_maps.is_empty():
			return prac_maps[0]
	var list: Array[String] = get_maps(component_id, channel_strategy, mode_filter)
	# Mirrors sub_6DF780 (0x6DF780): Case 3 (Monster) prefers MonEasyRandom / MonBeginnerRandom
	if mode_filter == MODE_FILTER_MONSTER or channel_strategy == "stage_clear":
		var pref: String = "MonEasyRandom" if is_easy_monster else "MonBeginnerRandom"
		if list.has(pref):
			return pref
	var mode_key: String = CLobbyFlowClass.component_id_to_mode_key(component_id)
	var info: Dictionary = get_mode_info(mode_key)
	var def_map: String = str(info.get("default_map", ""))
	if def_map != "":
		return def_map
	return list[0] if not list.is_empty() else "Camp08"

func set_map_max_players(map_code: String, max_players: int) -> void:
	var meta: Dictionary = _map_meta.get(map_code, {})
	meta["max_players"] = maxi(1, max_players)
	_map_meta[map_code] = meta

func get_map_max_players(map_code: String) -> int:
	var meta: Dictionary = _map_meta.get(map_code, {})
	if meta.has("max_players"):
		return int(meta["max_players"])
	# Derive per-map capacity from extracted Assets/fx/Map/<map_code>/map.json spawns[]
	var map_path := "res://Assets/fx/Map/%s/map.json" % map_code
	if FileAccess.file_exists(map_path):
		var mp: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path))
		if mp is Dictionary:
			var spawns: Variant = (mp as Dictionary).get("spawns", [])
			if spawns is Array and not (spawns as Array).is_empty():
				var cap: int = clampi((spawns as Array).size(), 1, 8)
				meta["max_players"] = cap
				_map_meta[map_code] = meta
				return cap
	return 8

func check_player_limit(map_code: String, player_count: int) -> Dictionary:
	# Mirrors sub_68B85D (MapSelect_PlayerLimitOver)
	var limit: int = get_map_max_players(map_code)
	if player_count > limit:
		return {
			"ok": false,
			"max_players": limit,
			"error": "Bản đồ này chỉ hỗ trợ tối đa %d người chơi." % limit,
		}
	return {"ok": true, "max_players": limit, "error": ""}
