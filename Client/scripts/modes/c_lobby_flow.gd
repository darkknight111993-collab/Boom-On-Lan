class_name CLobbyFlow
extends RefCounted

## Pure offline/LAN lobby flow controller backed by res://data/mock_lobby_flow.json.
## Mirrors CA.exe CLobbyStrategy (0x6B5F29) room-creation routing and channel mode
## filtering (0x6277FC, 0x8EAB5C, 0x8EAE1D, 0x51C4EB) for headless-testable parity.

const MOCK_PATH := "res://data/mock_lobby_flow.json"
const CHANNELS_PATH := "res://data/channels.json"
const CComponentClass = preload("res://scripts/modes/c_component.gd")

const MODE_KEY_TO_COMPONENT_ID: Dictionary = {
	"normal": CComponentClass.MODE_DEFAULT,
	"kart": CComponentClass.MODE_KART,
	"bula": CComponentClass.MODE_BULA,
	"survival": CComponentClass.MODE_SURVIVAL,
	"hedgehog": CComponentClass.MODE_HEDGEHOG,
	"captain": CComponentClass.MODE_CAPTAIN,
	"gametype": CComponentClass.MODE_CAPTAIN,
	"timebomb": CComponentClass.MODE_TIMEBOMB,
	"monster": CComponentClass.MODE_STAGE_CLEAR,
	"stage_clear": CComponentClass.MODE_STAGE_CLEAR,
	"mon_season2": CComponentClass.MODE_MON_SEASON2,
	"monster2": CComponentClass.MODE_MON_SEASON2,
	"tutorial": CComponentClass.MODE_TUTORIAL,
	"ai_battle": CComponentClass.MODE_AI_BATTLE,
	"battle": CComponentClass.MODE_AI_BATTLE,
	"rpg": CComponentClass.MODE_RPG,
	"super_fighter": CComponentClass.MODE_SUPER_FIGHTER,
	"super_fighter2": CComponentClass.MODE_SUPER_FIGHTER2,
	"superf2": CComponentClass.MODE_SUPER_FIGHTER2,
	"super_fighter_var": 25,
	"zzolman": CComponentClass.MODE_ZZOLMAN,
	"snowball": CComponentClass.MODE_SNOWBALL,
	"iam_boss": CComponentClass.MODE_IAM_BOSS,
	"hidden_catch": 28,
	"hidden_catch_comp": 29,
	"hidden_catch_single": 31,
}

# Fixed UI priority order from sub_6277FC
const MODE_PRIORITY: Dictionary = {
	100: 0,
	27: 1,
	0: 10,
	20: 20,
	19: 21,
	18: 22,
	21: 23,
	25: 24,
	14: 100,
	16: 101,
	10: 1000,
	11: 1001,
	12: 1002,
	13: 1003,
}

var data: Dictionary = {}
var channels_data: Dictionary = {}
var _next_room_id: int = 200

func _init(path: String = MOCK_PATH, channels_path: String = CHANNELS_PATH) -> void:
	load_file(path, channels_path)

func load_file(path: String = MOCK_PATH, channels_path: String = CHANNELS_PATH) -> bool:
	if FileAccess.file_exists(channels_path):
		var cp: Variant = JSON.parse_string(FileAccess.get_file_as_string(channels_path))
		if cp is Dictionary:
			channels_data = cp.duplicate(true)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	data = parsed.duplicate(true)
	for r: Dictionary in data.get("rooms", []):
		_next_room_id = maxi(_next_room_id, int(r.get("room_id", 0)) + 1)
	return true

static func mode_key_to_component_id(mode_key: String) -> int:
	return int(MODE_KEY_TO_COMPONENT_ID.get(mode_key.to_lower(), CComponentClass.MODE_DEFAULT))

static func component_id_to_mode_key(comp_id: int) -> String:
	for k: String in MODE_KEY_TO_COMPONENT_ID:
		if int(MODE_KEY_TO_COMPONENT_ID[k]) == comp_id:
			return k
	return "normal"

func get_accounts() -> Array:
	return data.get("accounts", [])

func get_servers() -> Array:
	return data.get("servers", [])

func get_channel_tabs(include_hidden: bool = false) -> Array:
	var tabs: Array = channels_data.get("tabs", [])
	if include_hidden or tabs.is_empty():
		return tabs
	var vis: int = int(channels_data.get("visible_tabs", tabs.size()))
	return tabs.slice(0, clampi(vis, 0, tabs.size()))

func get_tab(tab_id: String) -> Dictionary:
	for t: Dictionary in channels_data.get("tabs", []):
		if str(t.get("id", "")) == tab_id:
			return t
	return {}

func get_tab_channels_page(tab_id: String, page: int = 1) -> Dictionary:
	# 8 channels/page (sub_854E09), max 5 pages (sub_858AB4)
	var per_page: int = maxi(1, int(channels_data.get("channels_per_page", 8)))
	var max_pages: int = maxi(1, int(channels_data.get("max_pages", 5)))
	var tab: Dictionary = get_tab(tab_id)
	var all_chs: Array = tab.get("channels", [])
	var total_pages: int = clampi(maxi(1, int(ceili(float(all_chs.size()) / float(per_page)))), 1, max_pages)
	var cur_page: int = clampi(page, 1, total_pages)
	var start_i: int = (cur_page - 1) * per_page
	var end_i: int = mini(all_chs.size(), start_i + per_page)
	return {
		"channels": all_chs.slice(start_i, end_i),
		"page": cur_page,
		"total_pages": total_pages,
		"per_page": per_page,
	}

static func calc_population_bars(population: int, max_population: int) -> int:
	# Exact CA.exe formula (sub_854E1D @ 0x8550A7..0x8550C8)
	if max_population <= 0 or population <= 0:
		return 0
	if population >= max_population:
		return 6
	return mini(6, int(6 * population / max_population) + 1)

static func has_new_badge(ch: Dictionary) -> bool:
	# Exact CA.exe sub_8DAAB7 (0x8DAAB7): channel_type in {72, 73, 74}
	var ctype: int = int(ch.get("channel_type", 0))
	return ctype == 72 or ctype == 73 or ctype == 74 or str(ch.get("badge", "")).to_upper() == "NEW"

static func is_ladder_grade_channel(channel_type: int) -> bool:
	# Exact CA.exe sub_66F4B4 (0x66F4B4)
	return (channel_type >= 50 and channel_type <= 65) or channel_type == 70

static func get_bar_frame_offset(can_enter: bool) -> int:
	# Exact CA.exe sub_854E1D (0x854FBC..0x854FC7): 0..5 enterable, 6..11 locked/full
	return 0 if can_enter else 6

static func can_enter_channel(ch: Dictionary, user_level: int, user_grade: int = 1) -> Dictionary:
	# Mirrors CA.exe sub_854E1D + sub_66F4E4 + sub_66F70C
	var pop: int = int(ch.get("population", 0))
	var max_pop: int = int(ch.get("max_population", 200))
	if max_pop > 0 and pop >= max_pop:
		return {"ok": false, "reason": "Kênh đã đầy."}
	var min_lv: int = int(ch.get("min_level", 1))
	var max_lv: int = int(ch.get("max_level", 999))
	if user_level < min_lv:
		return {"ok": false, "reason": "Yêu cầu cấp %d trở lên." % min_lv}
	if max_lv > 0 and user_level > max_lv:
		return {"ok": false, "reason": "Chỉ dành cho người chơi cấp %d trở xuống." % max_lv}
	var ctype: int = int(ch.get("channel_type", 0))
	var min_g: int = int(ch.get("min_grade", 0))
	var max_g: int = int(ch.get("max_grade", 0))
	if is_ladder_grade_channel(ctype):
		if min_g > 0 and user_grade < min_g:
			return {"ok": false, "reason": "Yêu cầu cấp bậc (grade) %d trở lên." % min_g}
		if max_g > 0 and user_grade > max_g:
			return {"ok": false, "reason": "Chỉ dành cho User dưới grade %d." % max_g}
	elif ctype == 72 and max_g > 0 and user_grade > max_g:
		return {"ok": false, "reason": "Đây là kênh siêu cấp chỉ dành cho User dưới grade %d." % max_g}
	return {"ok": true, "reason": ""}

func get_channel(channel_id: String) -> Dictionary:
	for tab: Dictionary in channels_data.get("tabs", []):
		for ch: Dictionary in tab.get("channels", []):
			if str(ch.get("id", "")) == channel_id:
				return ch
	for srv: Dictionary in get_servers():
		for ch: Dictionary in srv.get("channels", []):
			if str(ch.get("id", "")) == channel_id:
				return ch
	return {}

func get_lobby_users(channel_id: String) -> Array:
	var out: Array = []
	for u: Dictionary in data.get("lobby_users", []):
		if str(u.get("channel_id", "")) == channel_id:
			out.append(u)
	return out

func get_channel_creatable_modes(channel_id: String) -> Array[int]:
	# From sub_6277FC / sub_8EAB5C / sub_8EAE1D / sub_51C4EB
	var ch: Dictionary = get_channel(channel_id)
	if ch.is_empty():
		return [0]
	var strat: String = str(ch.get("lobby_strategy", "normal"))
	if strat == "hidden_catch":
		return [28, 29]
	var combined: Array[int] = []
	for cid in ch.get("allowed_component_ids", []):
		var v: int = int(cid)
		if not combined.has(v):
			combined.append(v)
	for cid in ch.get("special_component_ids", []):
		var v: int = int(cid)
		if not combined.has(v):
			combined.append(v)
	combined.sort_custom(func(a: int, b: int) -> bool:
		return int(MODE_PRIORITY.get(a, 500 + a)) < int(MODE_PRIORITY.get(b, 500 + b))
	)
	return combined

func resolve_create_room_action(channel_id: String) -> Dictionary:
	# From CLobbyStrategy factory (0x6B5F29) & Slot 10 OnClickCreateRoom
	var ch: Dictionary = get_channel(channel_id)
	var strat: String = str(ch.get("lobby_strategy", "normal"))
	match strat:
		"stage_clear":
			return {"strategy": strat, "dialog": "create_room_stage_clear", "auto_create": false, "disabled": false, "fixed_component_id": CComponentClass.MODE_STAGE_CLEAR}
		"ladder":
			return {"strategy": strat, "dialog": "create_room_ladder", "auto_create": false, "disabled": false, "fixed_component_id": CComponentClass.MODE_DEFAULT}
		"rpg":
			return {"strategy": strat, "dialog": "", "auto_create": true, "disabled": false, "title": "RPG Room", "fixed_component_id": CComponentClass.MODE_RPG}
		"tournament":
			return {"strategy": strat, "dialog": "", "auto_create": true, "disabled": false, "title": "TournamentRoom", "fixed_component_id": CComponentClass.MODE_DEFAULT}
		"winning":
			return {"strategy": strat, "dialog": "", "auto_create": false, "disabled": true}
		_:
			return {"strategy": strat, "dialog": "create_room", "auto_create": false, "disabled": false, "fixed_component_id": -1}

func get_rooms(channel_id: String, filter_component_id: int = -1) -> Array:
	var out: Array = []
	for r: Dictionary in data.get("rooms", []):
		if str(r.get("channel_id", "")) != channel_id:
			continue
		if filter_component_id >= 0 and int(r.get("component_id", 0)) != filter_component_id:
			continue
		out.append(r)
	return out

func get_room(room_id: int) -> Dictionary:
	for r: Dictionary in data.get("rooms", []):
		if int(r.get("room_id", -1)) == room_id:
			return r
	return {}

func get_occupied_count(room: Dictionary) -> int:
	var count: int = 0
	for s: Dictionary in room.get("slots", []):
		if str(s.get("state", "")) == "occupied":
			count += 1
	return count

func create_room(channel_id: String, title: String, password: String, component_id: int, map_code: String, host_user: Dictionary, team_arrange: int = 0) -> Dictionary:
	var rooms: Array = data.get("rooms", [])
	var rid: int = _next_room_id
	_next_room_id += 1
	var max_no: int = 0
	for r: Dictionary in rooms:
		if str(r.get("channel_id", "")) == channel_id:
			max_no = maxi(max_no, int(r.get("room_no", 0)))
	var slots: Array = [
		{
			"slot_idx": 0,
			"state": "occupied",
			"user_id": int(host_user.get("id", 1)),
			"nickname": str(host_user.get("nickname", "Player")),
			"level": int(host_user.get("level", 1)),
			"is_host": true,
			"is_ready": true,
			"is_bot": false,
			"char_code": str(host_user.get("selected_char", "Character/C00")),
			"team_color_idx": int(host_user.get("team_color_idx", 0)),
		},
	]
	for idx in range(1, 8):
		slots.append({"slot_idx": idx, "state": "open"})
	var clean_pw: String = password.strip_edges()
	var room: Dictionary = {
		"room_id": rid,
		"room_no": max_no + 1,
		"channel_id": channel_id,
		"title": title if title.strip_edges() != "" else "Phòng %02d" % (max_no + 1),
		"host_user_id": int(host_user.get("id", 1)),
		"status": "waiting",
		"locked": clean_pw != "",
		"password": clean_pw,
		"mode_id": component_id_to_mode_key(component_id),
		"component_id": component_id,
		"team_arrange": team_arrange,
		"map_code": map_code if map_code != "" else "Camp08",
		"max_players": 8,
		"slots": slots,
	}
	rooms.append(room)
	data["rooms"] = rooms
	return room

func can_join_room(room_id: int, password: String = "") -> Dictionary:
	var room: Dictionary = get_room(room_id)
	if room.is_empty():
		return {"ok": false, "need_password": false, "error": "Phòng không tồn tại."}
	if str(room.get("status", "waiting")) != "waiting":
		return {"ok": false, "need_password": false, "error": "Phòng đang thi đấu."}
	if get_occupied_count(room) >= int(room.get("max_players", 8)):
		return {"ok": false, "need_password": false, "error": "Phòng đã đầy."}
	if bool(room.get("locked", false)):
		var expected: String = str(room.get("password", ""))
		if password == "":
			return {"ok": false, "need_password": true, "error": "Vui lòng nhập mật khẩu phòng."}
		if password != expected:
			return {"ok": false, "need_password": true, "error": "Mật khẩu phòng không chính xác."}
	return {"ok": true, "need_password": false, "room": room}

func build_match_start_payload(room: Dictionary) -> Dictionary:
	var players: Array = []
	var teams: Dictionary = {}
	var spawn_idx: int = 0
	for s: Dictionary in room.get("slots", []):
		if str(s.get("state", "")) != "occupied":
			continue
		var t_idx: int = int(s.get("team_color_idx", 0))
		teams[t_idx] = true
		players.append({
			"slot_idx": int(s.get("slot_idx", spawn_idx)),
			"spawn_idx": spawn_idx,
			"user_id": int(s.get("user_id", -1)),
			"nickname": str(s.get("nickname", "Player")),
			"is_bot": bool(s.get("is_bot", false)),
			"char_code": str(s.get("char_code", "Character/C00")),
			"team_color_idx": t_idx,
			"bomb_skin": "Bomb/Bomb00",
			"initial_mount": "",
		})
		spawn_idx += 1
	var map_code: String = str(room.get("map_code", "Camp08"))
	var is_sandbox: bool = map_code.begins_with("Test") or map_code.begins_with("DevTest")
	var ok: bool = is_sandbox or teams.size() >= 2
	return {
		"ok": ok,
		"error": "" if ok else "Phải có ít nhất 2 đội mới có thể bắt đầu trận đấu!",
		"room_id": int(room.get("room_id", -1)),
		"channel_id": str(room.get("channel_id", "")),
		"mode_id": str(room.get("mode_id", "normal")),
		"component_id": int(room.get("component_id", 0)),
		"map_code": map_code,
		"time_limit_sec": 180,
		"players": players,
	}
