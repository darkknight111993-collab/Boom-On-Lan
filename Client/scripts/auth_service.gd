extends Node
# User Authentication & Database Service (GAME_PLAN.md §3)
# Persists accounts, stats (level, exp, lucci, cash, wins, losses), inventory and equipped items.

const DB_PATH_USER := "user://bnb_lan.json"
const DB_PATH_MOCK := "res://data/mock_lobby_flow.json"
const DB_PATH_DEFAULT := "res://data/database.json"

var _db: Dictionary = {
	"users": [],
	"inventory": [],
	"equipped": []
}

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	if FileAccess.file_exists(DB_PATH_USER):
		var raw_u := FileAccess.get_file_as_string(DB_PATH_USER)
		var parsed_u = JSON.parse_string(raw_u)
		if parsed_u is Dictionary and parsed_u.has("users"):
			_db = parsed_u
			return
	if FileAccess.file_exists(DB_PATH_MOCK):
		var raw_m := FileAccess.get_file_as_string(DB_PATH_MOCK)
		var parsed_m = JSON.parse_string(raw_m)
		if parsed_m is Dictionary and parsed_m.has("accounts"):
			_db = {"users": parsed_m["accounts"].duplicate(true), "inventory": [], "equipped": []}
			return
	if FileAccess.file_exists(DB_PATH_DEFAULT):
		var raw := FileAccess.get_file_as_string(DB_PATH_DEFAULT)
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary and parsed.has("users"):
			_db = parsed
			return
	
	# Default fallback
	_db = {
		"users": [
			{
				"id": 1,
				"username": "player1",
				"password_hash": "admin",
				"nickname": "BazziPro",
				"level": 15,
				"exp": 4250,
				"lucci": 50000,
				"cash": 10000,
				"wins": 32,
				"losses": 14,
				"draws": 5,
				"selected_char": "Character/C00"
			}
		],
		"inventory": [],
		"equipped": []
	}
	_save_database()

func _save_database() -> void:
	var file := FileAccess.open(DB_PATH_USER, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_db, "  "))
		file.close()

func login(user_id: String, password: String, player_slot: int = 1) -> Dictionary:
	var u_name := user_id.strip_edges()
	if u_name == "":
		u_name = "Guest" if player_slot == 1 else "Guest2"

	var users: Array = _db.get("users", [])
	var found_user: Dictionary = {}
	for u: Dictionary in users:
		if str(u.get("username", "")).nocasecmp_to(u_name) == 0 or str(u.get("nickname", "")).nocasecmp_to(u_name) == 0:
			found_user = u
			break

	if found_user.is_empty():
		# Auto-register new player for offline/LAN play
		var new_id := users.size() + 1
		found_user = {
			"id": new_id,
			"username": u_name,
			"password_hash": password,
			"nickname": u_name,
			"level": 99,
			"exp": 0,
			"lucci": 50000,
			"cash": 10000,
			"wins": 0,
			"losses": 0,
			"draws": 0,
			"selected_char": "Character/C00"
		}
		_db["users"].append(found_user)
		_save_database()

	var uid_str := str(found_user.get("id", str(player_slot)))
	var nick_str := str(found_user.get("nickname", u_name))

	# Sync to Session per player slot
	if player_slot == 1:
		Session.user_id = uid_str
		Session.username = str(found_user.get("username", u_name))
		Session.nickname = nick_str
		Session.level = int(found_user.get("level", 1))
		Session.exp = int(found_user.get("exp", 0))
		Session.lucci = int(found_user.get("lucci", 50000))
		Session.cash = int(found_user.get("cash", 10000))
		Session.wins = int(found_user.get("wins", 0))
		Session.losses = int(found_user.get("losses", 0))
		Session.draws = int(found_user.get("draws", 0))
		if found_user.has("selected_char"):
			Session.selected_char = str(found_user.selected_char)
		var inv := Session.get_inventory_man()
		inv.lucci = Session.lucci
		inv.cash = Session.cash
		if found_user.has("inventory_data") and found_user["inventory_data"] is Dictionary:
			inv.from_dict(found_user["inventory_data"] as Dictionary)
		Session.sync_from_inventory()
	else:
		Session.user2_id = uid_str
		Session.nickname2 = nick_str

	return {
		"ok": true,
		"user_id": uid_str,
		"nickname": nick_str
	}

func register_user(u_name: String, password: String, nick := "") -> Dictionary:
	var clean_u := u_name.strip_edges()
	var clean_nick := nick.strip_edges() if nick != "" else clean_u
	for u: Dictionary in _db.get("users", []):
		if str(u.get("username", "")).nocasecmp_to(clean_u) == 0:
			return {"ok": false, "error": "Tên tài khoản đã tồn tại."}

	var new_user := {
		"id": _db["users"].size() + 1,
		"username": clean_u,
		"password_hash": password,
		"nickname": clean_nick,
		"level": 1,
		"exp": 0,
		"lucci": 50000,
		"cash": 10000,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"selected_char": "Character/C00"
	}
	_db["users"].append(new_user)
	_save_database()
	return {"ok": true, "user": new_user}

func record_match_result(uid: String, result: String) -> void:
	for u: Dictionary in _db.get("users", []):
		if str(u.get("id", "")) == uid or str(u.get("username", "")) == uid or str(u.get("nickname", "")) == uid:
			if result == "win":
				u["wins"] = int(u.get("wins", 0)) + 1
				u["exp"] = int(u.get("exp", 0)) + 250
				u["lucci"] = int(u.get("lucci", 0)) + 500
			elif result == "loss":
				u["losses"] = int(u.get("losses", 0)) + 1
				u["exp"] = int(u.get("exp", 0)) + 60
				u["lucci"] = int(u.get("lucci", 0)) + 100
			else:
				u["draws"] = int(u.get("draws", 0)) + 1
				u["exp"] = int(u.get("exp", 0)) + 100
				u["lucci"] = int(u.get("lucci", 0)) + 200

			var cur_exp: int = int(u["exp"])
			u["level"] = 1 + int(cur_exp / 500)

			# Sync back to Session if active
			if str(u.get("id", "")) == Session.user_id:
				Session.level = int(u["level"])
				Session.exp = int(u["exp"])
				Session.lucci = int(u["lucci"])
				Session.wins = int(u["wins"])
				Session.losses = int(u["losses"])
				Session.draws = int(u["draws"])

			_save_database()
			return

func save_active_inventory() -> void:
	if Session.user_id == "":
		return
	var inv := Session.get_inventory_man()
	for u: Dictionary in _db.get("users", []):
		if str(u.get("id", "")) == Session.user_id or str(u.get("username", "")) == Session.username:
			u["lucci"] = inv.lucci
			u["cash"] = inv.cash
			u["selected_char"] = str(inv.equipped_cosmetics.get("character", Session.selected_char))
			u["inventory_data"] = inv.to_dict()
			_save_database()
			return
