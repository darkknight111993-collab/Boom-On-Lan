extends Node

const CLobbyFlowClass = preload("res://scripts/modes/c_lobby_flow.gd")
const CDynamicMapManClass = preload("res://scripts/modes/c_dynamic_map_man.gd")
const CShopItemManClass = preload("res://scripts/modes/c_shop_item_man.gd")
const CUserInventoryManClass = preload("res://scripts/modes/c_user_inventory_man.gd")

var user_id := ""
var username := ""
var nickname := ""
var is_2p := false
var user2_id := ""
var nickname2 := ""
var selected_server_id := "srv_hn"
var selected_channel_id := "ch_td_01"
var active_room_id := 101
var lobby_filter_component_id := -1
var room_title := "Càng Xấu Càng Tốt"
var room_password := ""
var selected_map := "Camp08"
var selected_char := "Character/C00"
var selected_char_slot := 0
var game_mode := "normal" # Default mode 1: ĐẠI CHIẾN
var selected_component_id := 0 # CComponent::MODE_* (sub_73D4B0)
var _lobby_flow: CLobbyFlowClass = null
var _map_man: CDynamicMapManClass = null
var _shop_man: CShopItemManClass = null
var _inventory_man: CUserInventoryManClass = null
var shop_return_scene := "lobby"

func get_lobby_flow() -> CLobbyFlowClass:
	if _lobby_flow == null:
		_lobby_flow = CLobbyFlowClass.new()
	return _lobby_flow

func get_map_man() -> CDynamicMapManClass:
	if _map_man == null:
		_map_man = CDynamicMapManClass.new()
	return _map_man

func get_shop_man() -> CShopItemManClass:
	if _shop_man == null:
		_shop_man = CShopItemManClass.new()
	return _shop_man

func get_inventory_man() -> CUserInventoryManClass:
	if _inventory_man == null:
		_inventory_man = CUserInventoryManClass.new()
		_inventory_man.lucci = lucci
		_inventory_man.cash = cash
		_inventory_man.equipped_cosmetics["character"] = selected_char
		_inventory_man.equipped_cosmetics["bomb_skin"] = equipped_bomb_skin
		_inventory_man.equipped_cosmetics["hat"] = equipped_hat
		_inventory_man.equipped_cosmetics["cloth"] = equipped_cloth
		_inventory_man.equipped_cosmetics["face"] = equipped_face
		_inventory_man.equipped_cosmetics["char_deco"] = equipped_char_deco
		_inventory_man.equipped_cosmetics["id_deco"] = equipped_id_deco
		_inventory_man.equipped_cosmetics["mount"] = equipped_mount
	return _inventory_man

func sync_from_inventory() -> void:
	var inv := get_inventory_man()
	lucci = inv.lucci
	cash = inv.cash
	selected_char = str(inv.equipped_cosmetics.get("character", selected_char))
	equipped_bomb_skin = str(inv.equipped_cosmetics.get("bomb_skin", "Bomb/Bomb00"))
	equipped_hat = str(inv.equipped_cosmetics.get("hat", ""))
	equipped_cloth = str(inv.equipped_cosmetics.get("cloth", ""))
	equipped_face = str(inv.equipped_cosmetics.get("face", ""))
	equipped_char_deco = str(inv.equipped_cosmetics.get("char_deco", ""))
	equipped_id_deco = str(inv.equipped_cosmetics.get("id_deco", ""))
	equipped_mount = str(inv.equipped_cosmetics.get("mount", ""))

func apply_room_to_session(room: Dictionary) -> void:
	if room.is_empty():
		return
	active_room_id = int(room.get("room_id", active_room_id))
	room_title = str(room.get("title", room_title))
	room_password = str(room.get("password", ""))
	selected_component_id = int(room.get("component_id", 0))
	game_mode = str(room.get("mode_id", CLobbyFlowClass.component_id_to_mode_key(selected_component_id)))
	selected_map = str(room.get("map_code", selected_map))

# Equipped Avatar & Skins (charte & emote)
var equipped_bomb_skin := "Bomb/Bomb00" # e.g. "charte/BombDeco/Bomb001"
var equipped_mount := "" # e.g. "Ship/Tank", "Ship/Octopus0", "Ship/Turtle0"
var equipped_hat := "" # e.g. "charte/AvatarDeco/A02_10_0001_0"
var equipped_cloth := ""
var equipped_face := ""
var equipped_char_deco := ""
var equipped_id_deco := "emote/IDDeco/IDDeco_C001"
var equipped_fanfare := "emote/Fanfare/Fanfare000"
var team_color_idx := 0 # 0: Đỏ (Red - Basic00)

# 2P & 8-slot room cosmetic configurations (slot_idx 0..7 -> {hat, cloth, face, char_deco, id_deco, bomb_skin})
var user2_equipped_bomb_skin := "Bomb/Bomb00"
var user2_team_color_idx := 5 # 5: Xanh dương (Blue - Basic05)
var room_slot_cosmetics: Array[Dictionary] = [{}, {}, {}, {}, {}, {}, {}, {}]
var room_slot_locked: Array[bool] = [false, false, false, false, false, false, false, false]

func toggle_room_slot_state(slot_idx: int) -> String:
	# Cycles slot 2..7: empty -> locked -> bot -> empty
	if slot_idx < 2 or slot_idx >= 8:
		return "fixed"
	if room_slot_locked[slot_idx]:
		room_slot_locked[slot_idx] = false
		var chars := ["Character/C00", "Character/C01", "Character/C02", "Character/C06", "Character/C03", "Character/C05"]
		room_slot_cosmetics[slot_idx] = {
			"char": chars[slot_idx % chars.size()],
			"nick": "Bot %d" % (slot_idx + 1),
			"team_color_idx": slot_idx % 8,
			"ready": true,
			"is_bot": true,
		}
		return "bot"
	if not room_slot_cosmetics[slot_idx].is_empty():
		room_slot_cosmetics[slot_idx] = {}
		return "empty"
	room_slot_locked[slot_idx] = true
	return "locked"

func get_room_slot_cosmetics(slot_idx: int) -> Dictionary:
	if slot_idx == 0:
		return {
			"hat": equipped_hat,
			"cloth": equipped_cloth,
			"face": equipped_face,
			"char_deco": equipped_char_deco,
			"id_deco": equipped_id_deco,
			"bomb_skin": equipped_bomb_skin,
		}
	if slot_idx >= 1 and slot_idx < room_slot_cosmetics.size():
		return room_slot_cosmetics[slot_idx]
	return {}

func set_room_slot_cosmetics(slot_idx: int, eq: Dictionary) -> void:
	if slot_idx == 0:
		equipped_hat = str(eq.get("hat", equipped_hat))
		equipped_cloth = str(eq.get("cloth", equipped_cloth))
		equipped_face = str(eq.get("face", equipped_face))
		equipped_char_deco = str(eq.get("char_deco", equipped_char_deco))
		equipped_id_deco = str(eq.get("id_deco", equipped_id_deco))
		equipped_bomb_skin = str(eq.get("bomb_skin", equipped_bomb_skin))
	elif slot_idx >= 1 and slot_idx < room_slot_cosmetics.size():
		room_slot_cosmetics[slot_idx] = eq.duplicate(true)

# Exact 8 team colors corresponding 1:1 with Prepare/PRE_SelTeam-Basic00..07
const TEAM_COLORS := [
	Color(0.92, 0.00, 0.00), # 0: Đỏ (Red - Basic00 #ea0000)
	Color(1.00, 0.70, 0.04), # 1: Vàng (Yellow - Basic01 #ffb30a)
	Color(1.00, 0.48, 0.00), # 2: Cam (Orange - Basic02 #ff7b00)
	Color(0.40, 0.72, 0.02), # 3: Xanh lá (Green - Basic03 #66b805)
	Color(0.00, 0.71, 0.75), # 4: Lam nhạt / Xanh ngọc (Cyan - Basic04 #00b5be)
	Color(0.00, 0.36, 0.89), # 5: Xanh dương (Blue - Basic05 #005be4)
	Color(0.40, 0.08, 0.87), # 6: Tím than (Indigo - Basic06 #6514dd)
	Color(0.89, 0.00, 0.55), # 7: Hồng / Tím hồng (Pink - Basic07 #e4008c)
]

func get_team_color(idx: int) -> Color:
	return TEAM_COLORS[posmod(idx, TEAM_COLORS.size())]

# Player Profile Stats (GAME_PLAN.md §3.1)
var level := 99
var grade := 1
var exp := 4250
var lucci := 50000
var cash := 10000
var wins := 32
var losses := 14
var draws := 5

var _locale := {}

func _ensure_locale() -> void:
	if _locale.is_empty() and FileAccess.file_exists("res://data/vn_locale.json"):
		_locale = JSON.parse_string(FileAccess.get_file_as_string("res://data/vn_locale.json"))

func get_winrate() -> float:
	var total := wins + losses + draws
	return (float(wins) / float(total) * 100.0) if total > 0 else 0.0

func get_profile_stats_text() -> String:
	return "Cấp %d   %.1f%%" % [level, get_winrate()]

func get_map_name_vn(map_code: String) -> String:
	_ensure_locale()
	var m: Variant = _locale.get("maps", {}).get(map_code, null)
	return str(m.name_vn) if m is Dictionary and m.has("name_vn") else map_code

func get_map_desc_vn(map_code: String) -> String:
	_ensure_locale()
	var m: Variant = _locale.get("maps", {}).get(map_code, null)
	return str(m.desc_vn) if m is Dictionary and m.has("desc_vn") else ""

func get_char_slots() -> Array:
	_ensure_locale()
	return _locale.get("prepare_char_slots", [])

func get_item_info_vn(item_code: String) -> Dictionary:
	_ensure_locale()
	return _locale.get("items", {}).get(item_code, {"name_vn": item_code, "desc_vn": ""})

func roll_random_character() -> String:
	# Original BnB weighted character pool:
	# 10 default characters (C00..C09): weight 10 each (total 100).
	# Rare hidden characters (Lodumani C14, Santa C15): weight 3 each (~2.8% each, total 6).
	var pool := [
		{"char": "Character/C00", "weight": 10}, # Nhanh Nhẩu
		{"char": "Character/C01", "weight": 10}, # Mật Ngọt
		{"char": "Character/C02", "weight": 10}, # Bé Bỏng
		{"char": "Character/C03", "weight": 10}, # Đầu Đinh
		{"char": "Character/C04", "weight": 10}, # Mắt Xanh
		{"char": "Character/C05", "weight": 10}, # Mọt Sách
		{"char": "Character/C06", "weight": 10}, # Khò Khò
		{"char": "Character/C07", "weight": 10}, # Thịt Mỡ
		{"char": "Character/C08", "weight": 10}, # Thiên Sứ
		{"char": "Character/C09", "weight": 10}, # Tí Điệu
		{"char": "Character/C14", "weight": 3},  # Hải Tặc (Lodumani) - rare ~2.8%
		{"char": "Character/C15", "weight": 3},  # Ông Già Noel (Santa) - rare ~2.8%
	]
	var total := 0
	for item in pool:
		total += int(item.weight)
	var roll := randi() % total
	var accum := 0
	for item in pool:
		accum += int(item.weight)
		if roll < accum:
			return str(item.char)
	return "Character/C00"

func get_game_modes() -> Array:
	return get_map_man().get_game_modes()

func get_mode_info(mode_id: String) -> Dictionary:
	return get_map_man().get_mode_info(mode_id)

func get_maps_for_mode(mode_id: String) -> Array:
	return get_map_man().get_maps_for_mode(mode_id)

func get_maps_for_active_room(show_all: bool = false, theme_prefix: String = "") -> Array:
	var ch: Dictionary = get_lobby_flow().get_channel(selected_channel_id)
	var strat: String = str(ch.get("lobby_strategy", "normal"))
	return get_map_man().get_maps(selected_component_id, strat, 0, show_all, theme_prefix)

func get_mode_name_vn(mode_id: String) -> String:
	return get_map_man().get_mode_name_vn(mode_id)

func goto(scene: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
