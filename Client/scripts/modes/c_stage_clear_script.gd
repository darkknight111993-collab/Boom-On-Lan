class_name CStageClearScript
extends RefCounted

## StageClear / Monster Arena XML script parser.
## Ported from CA.exe sub_49C43B (StageClearScriptParser), sub_49908A (Action IDs),
## sub_497A42 (Trigger IDs), and sub_C0789B (48-entry NpcType registry).

const GRID_W := 15
const GRID_H := 13

# Verified NpcType string -> integer ID registry (sub_C0789B @ 0xC0789B)
const NPC_TYPE_IDS: Dictionary = {
	"bossmon1": 4,
	"basicmon": 5,
	"icemon": 6,
	"eggmon": 7,
	"pudadakmon": 8,
	"bossmon2": 9,
	"smallrobot": 13,
	"bossrobot": 13,
	"bombmissile": 15,
	"wrigglemon": 17,
	"starfishmon": 20,
	"bossturtle": 21,
	"bluemon": 23,
	"bossgolem": 24,
	"bossgolem2": 25,
	"rollinggolem": 26,
	"minigolem": 27,
	"pebblegolem": 29,
	"zzolman": 30,
	"largegourd": 32,
	"largepoopoo": 33,
	"lodumanimon": 35,
	"mon2ndkuo": 36,
	"mon2ndocto": 37,
	"mon2ndpenguin": 38,
	"mon2ndseal": 39,
	"mon2ndmummy": 40,
	"mon2ndsphinx": 41,
	"mon2ndking": 42,
	"mon2ndpirate": 43,
	"mon2ndsandking": 44,
	"bouncemon": 45,
	"sharkmon": 46,
	"goldenbonusmon": 47,
	"snowbear": 48,
	"pebblesnow": 50,
}

# Verified Trigger ID table (sub_497A42 @ 0x497A42)
const TRIGGER_IDS: Dictionary = {
	"default": 0,
	"selflocked": 1,
	"locked": 2,
	"bomberlocked": 3,
	"selfdie": 4,
	"die": 5,
	"bomberdie": 6,
	"bosslocked": 7,
	"bossdamaged": 8,
	"bossanger": 9,
	"monhpchanged": 10,
	"failaction": 11,
	"selfreleased": 12,
	"released": 13,
	"bomberreleased": 14,
	"selfdamaged": 15,
	"damaged": 16,
	"bomberdamaged": 17,
	"firstmondie": 18,
	"lastmonleft": 19,
	"createdefault": 20,
	"combine": 21,
	"transform": 22,
	"bossin": 23,
	"approach": 24,
	"appear": 25,
	"classalldie": 26,
	"puzzlebox": 27,
	"itemmeetthecondition": 28,
}

# Verified Action ID table (sub_49908A @ 0x49908A)
const ACTION_IDS: Dictionary = {
	"none": 0,
	"move": 1,
	"wait": 4,
	"turn": 6,
	"setstate": 7,
	"attack": 8,
	"pattern": 9,
	"createobj": 10,
	"playanim": 11,
	"orderscript": 12,
	"settriggeroption": 13,
	"destroystaticbox": 14,
	"changebgm": 15,
	"ai": 16,
}

var options: Dictionary = {}
var objects: Array[Dictionary] = []

static func parse_life_attr(life_str: String) -> Dictionary:
	var result := {
		"max_hp": 1,
		"anger_hp": 0,
		"show_gagebar": false,
	}
	if life_str.strip_edges().is_empty():
		return result
	for part in life_str.split(",", false):
		var kv := part.split("=", false)
		if kv.size() < 2:
			continue
		var k := kv[0].strip_edges().to_lower()
		var v := kv[1].strip_edges()
		match k:
			"max":
				result["max_hp"] = maxi(1, int(v))
			"anger":
				result["anger_hp"] = maxi(0, int(v))
			"gagebar":
				result["show_gagebar"] = _parse_bool_attr(v, false)
	return result

static func parse_pass_type(pass_str: String) -> Dictionary:
	var result := {
		"pass_box": false,
		"pass_static": false,
		"pass_bomb": false,
	}
	if pass_str.strip_edges().is_empty():
		return result
	for part in pass_str.split(",", false):
		var kv := part.split("=", false)
		if kv.size() < 2:
			continue
		var k := kv[0].strip_edges().to_lower()
		var flag := int(kv[1].strip_edges()) != 0
		match k:
			"box":
				result["pass_box"] = flag
			"static":
				result["pass_static"] = flag
			"bomb":
				result["pass_bomb"] = flag
	return result

static func parse_duration_range(dur_str: String) -> Vector2i:
	# Matches sub_774989: sscanf(str, "%u~%u", &min_ms, &max_ms); if 1 value, max = min.
	var s := dur_str.strip_edges()
	if s.is_empty():
		return Vector2i(0, 0)
	if s.contains("~"):
		var parts := s.split("~", false)
		var lo := maxi(0, int(parts[0].strip_edges()))
		var hi := lo
		if parts.size() >= 2:
			hi = maxi(lo, int(parts[1].strip_edges()))
		return Vector2i(lo, hi)
	var v := maxi(0, int(s))
	return Vector2i(v, v)

static func parse_size_attr(size_str: String) -> Vector2i:
	var s := size_str.strip_edges().to_lower()
	if s.is_empty():
		return Vector2i(40, 40)
	var sep := "x" if s.contains("x") else ","
	var parts := s.split(sep, false)
	if parts.size() >= 2:
		return Vector2i(maxi(1, int(parts[0].strip_edges())), maxi(1, int(parts[1].strip_edges())))
	return Vector2i(40, 40)

static func parse_pos_attr(pos_str: String) -> Vector2i:
	var parts := pos_str.strip_edges().split(",", false)
	if parts.size() >= 2:
		return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return Vector2i(7, 6)

static func parse_fire_pos(fire_str: String) -> Dictionary:
	var out := {"left": -1, "top": -1, "right": 1, "bottom": 1}
	if fire_str.strip_edges().is_empty():
		return out
	for part in fire_str.split(",", false):
		var kv := part.split("=", false)
		if kv.size() < 2:
			continue
		var k := kv[0].strip_edges().to_lower()
		if out.has(k):
			out[k] = int(kv[1].strip_edges())
	return out

static func _parse_bool_attr(val: String, default_val: bool = true) -> bool:
	var s := val.strip_edges().to_lower()
	if s.is_empty():
		return default_val
	return s == "1" or s == "true" or s == "yes"

static func get_npc_type_id(npc_type: String) -> int:
	return int(NPC_TYPE_IDS.get(npc_type.strip_edges().to_lower(), 5))

static func resolve_monster_sprite_prefix(npc_type: String, image_attr: String) -> String:
	var img := image_attr.strip_edges().replace("\\", "/")
	var img_l := img.to_lower()
	var t_l := npc_type.strip_edges().to_lower()

	var base := img.get_file()
	var base_l := base.to_lower()
	# Season 2 monsters live in Client/Assets/fx/MonsterSeason2/
	if img_l.contains("sancho") or t_l == "mon2ndsancho":
		return "MonsterSeason2/M_Sancho"
	if img_l.contains("monkey") or t_l == "mon2ndmonkey":
		return "MonsterSeason2/M_Monkey"
	if img_l.contains("rkuo") or t_l == "mon2ndrkuo":
		return "MonsterSeason2/M_RKuo"
	if img_l.contains("mkuo") or t_l == "mon2ndmkuo":
		return "MonsterSeason2/M_MKuo"
	if img_l.contains("kuo") or t_l == "mon2ndkuo":
		return "MonsterSeason2/M_Kuo"
	if img_l.contains("riguner") or t_l == "mon2ndriguner":
		return "MonsterSeason2/M_Riguner"
	if img_l.contains("sflower") or img_l.contains("flower") or t_l == "mon2ndsflower":
		return "MonsterSeason2/M_Sflower"
	if base.begins_with("BM08") or t_l == "mon2ndking":
		return "MonsterSeason2/BM08"
	if base.begins_with("BM09") or t_l == "mon2ndsandking":
		return "MonsterSeason2/BM09"

	# Direct prefix already matching Assets/fx/Monster/<prefix>_*
	if base.begins_with("BM0") or base.begins_with("SM0") or base.begins_with("SM1") or base.begins_with("SM2"):
		return base.split("_")[0]
	if base_l.contains("monturtle") or t_l == "bossturtle":
		return "BM00"
	if base_l.contains("monseal") or t_l == "bossmon1":
		return "BM01"
	if t_l == "bossmon2":
		return "BM02"
	if base_l.contains("golem") or t_l.contains("golem"):
		return "BM03" if t_l.begins_with("boss") else "SM05"
	if base_l.contains("robot") or t_l.contains("robot"):
		return "BM04" if t_l.begins_with("boss") else "SM06"
	if base_l.contains("poopoo") or t_l == "largepoopoo":
		return "LargePooPoo"
	if base_l.contains("aqua") or t_l == "sharkmon":
		return "AquaMon00"
	if base_l.contains("ghost") or base_l.contains("c14g"):
		return "C14G"
	if base_l.contains("rabbit"):
		return "rabbit"
	if t_l == "icemon":
		return "SM02"
	if t_l == "eggmon" or t_l == "pudadakmon":
		return "SM03"
	if t_l == "starfishmon":
		return "SM04"
	if t_l == "bluemon":
		return "SM07"
	if t_l == "bouncemon":
		return "SM08"
	if t_l == "snowbear" or t_l == "pebblesnow":
		return "BM05" if t_l == "snowbear" else "SM09"
	if t_l.begins_with("boss") or t_l.begins_with("mon2nd"):
		return "BM00"
	if img_l.contains("mon2"):
		return "SM02"
	if img_l.contains("mon3"):
		return "SM03"
	return "SM01"

func parse_xml(xml_text: String) -> bool:
	options.clear()
	objects.clear()
	if xml_text.strip_edges().is_empty():
		return false

	# Strip XML comments first; some original maps have non-standard lines in comments.
	var re_comment := RegEx.new()
	re_comment.compile("<!--[\\s\\S]*?-->")
	var clean := re_comment.sub(xml_text, "", true)

	# 1. Parse <mapscriptoption .../>
	var re_opt := RegEx.new()
	re_opt.compile("(?is)<mapscriptoption\\b([^>]*)/?>")
	var m_opt := re_opt.search(clean)
	if m_opt != null:
		var attrs := _parse_attrs(m_opt.get_string(1))
		var bonuses: Array[String] = []
		for key in ["clearbonus01", "clearbonus02", "clearbonus03", "clearbonus04"]:
			if attrs.has(key) and not String(attrs[key]).is_empty():
				bonuses.append(String(attrs[key]))
		options = {
			"play_time_ms": int(attrs.get("playtime", "120000")),
			"game_end_wait_ms": int(attrs.get("gameendwaittime", "0")),
			"bgm": String(attrs.get("bgm", "")),
			"clear_bonuses": bonuses,
		}

	# 2. Parse each <ScriptObject>...</ScriptObject>
	var re_obj := RegEx.new()
	re_obj.compile("(?is)<ScriptObject\\b[^>]*>([\\s\\S]*?)</ScriptObject>")
	var re_init := RegEx.new()
	re_init.compile("(?is)<InitInfo\\b([^>]*)/?>")

	for m_obj in re_obj.search_all(clean):
		var body := m_obj.get_string(1)
		var m_init := re_init.search(body)
		if m_init == null:
			continue
		var init_attrs := _parse_attrs(m_init.get_string(1))
		var ta := _parse_triggers_and_actions(body)
		objects.append({
			"init_info": _build_init_info(init_attrs),
			"triggers": ta["triggers"],
			"action_lists": ta["action_lists"],
		})

	# 3. Parse Season 2 <ScriptObjectTemplate monInfo="..." monAction="..."> blocks (0xc1e6bc)
	var re_tpl := RegEx.new()
	re_tpl.compile("(?is)<ScriptObjectTemplate\\b([^>]*)>([\\s\\S]*?)</ScriptObjectTemplate>")
	var re_ovr := RegEx.new()
	re_ovr.compile("(?is)<OverrideInitInfo\\b([^>]*)/?>")
	for m_tpl in re_tpl.search_all(clean):
		var tpl_attrs := _parse_attrs(m_tpl.get_string(1))
		var mon_info := String(tpl_attrs.get("moninfo", ""))
		var mon_action := String(tpl_attrs.get("monaction", ""))
		var ovr_attrs: Dictionary = {}
		var m_ovr := re_ovr.search(m_tpl.get_string(2))
		if m_ovr != null:
			ovr_attrs = _parse_attrs(m_ovr.get_string(1))
		objects.append(_build_template_object(mon_info, mon_action, ovr_attrs))

	return not objects.is_empty()

static func _build_init_info(init_attrs: Dictionary) -> Dictionary:
	var life := parse_life_attr(String(init_attrs.get("life", "")))
	var pass_info := parse_pass_type(String(init_attrs.get("passtype", "")))
	var npc_type := String(init_attrs.get("type", "BasicMon"))
	var image_attr := String(init_attrs.get("image", ""))
	var is_boss_flag := _parse_bool_attr(String(init_attrs.get("boss", "0")), false) or npc_type.to_lower().begins_with("boss") or int(life["max_hp"]) > 1
	return {
		"type": npc_type,
		"npc_type_id": get_npc_type_id(npc_type),
		"image": image_attr,
		"sprite_prefix": resolve_monster_sprite_prefix(npc_type, image_attr),
		"pos": parse_pos_attr(String(init_attrs.get("pos", "7,6"))),
		"from_start": _parse_bool_attr(String(init_attrs.get("fromstart", "1")), true),
		"obj_class": int(init_attrs.get("class", "0")),
		"is_boss": is_boss_flag,
		"max_hp": int(life["max_hp"]),
		"anger_hp": int(life["anger_hp"]),
		"show_gagebar": bool(life["show_gagebar"]),
		"collision_size": parse_size_attr(String(init_attrs.get("collisionsize", "40x40"))),
		"fire_pos": parse_fire_pos(String(init_attrs.get("firepos", ""))),
		"pass_box": bool(pass_info["pass_box"]),
		"pass_static": bool(pass_info["pass_static"]),
		"pass_bomb": bool(pass_info["pass_bomb"]),
		"lucci": String(init_attrs.get("lucci", "")),
		"raw_attrs": init_attrs,
	}

static func _parse_triggers_and_actions(xml_body: String) -> Dictionary:
	var re_comment := RegEx.new()
	re_comment.compile("<!--[\\s\\S]*?-->")
	var body := re_comment.sub(xml_body, "", true)

	var re_trig := RegEx.new()
	re_trig.compile("(?is)<Trigger\\b([^>]*)/?>")
	var re_alist := RegEx.new()
	re_alist.compile("(?is)<ActionList\\b([^>]*)>([\\s\\S]*?)</ActionList>")
	var re_act := RegEx.new()
	re_act.compile("(?is)<Action\\b([^>]*)/?>")

	var triggers: Dictionary = {}
	for m_t in re_trig.search_all(body):
		var ta := _parse_attrs(m_t.get_string(1))
		var t_type := String(ta.get("type", "")).to_lower()
		var t_list := String(ta.get("actionlist", ""))
		if not t_type.is_empty() and not t_list.is_empty():
			triggers[t_type] = t_list

	var action_lists: Dictionary = {}
	for m_al in re_alist.search_all(body):
		var ala := _parse_attrs(m_al.get_string(1))
		var al_name := String(ala.get("name", ""))
		if al_name.is_empty():
			continue
		var actions: Array[Dictionary] = []
		for m_a in re_act.search_all(m_al.get_string(2)):
			var aa := _parse_attrs(m_a.get_string(1))
			var act_name := String(aa.get("name", "")).to_lower()
			if act_name.is_empty():
				continue
			aa["name"] = act_name
			aa["action_id"] = int(ACTION_IDS.get(act_name, 0))
			actions.append(aa)
		action_lists[al_name] = {
			"name": al_name,
			"next": String(ala.get("next", "")),
			"actions": actions,
		}
	return {"triggers": triggers, "action_lists": action_lists}

static func _load_template_xml(rel_path: String) -> String:
	var clean_rel := rel_path.strip_edges().replace("\\", "/")
	if clean_rel.is_empty():
		return ""
	var full_path := "res://Assets/fx/%s/data.xml" % clean_rel
	if not FileAccess.file_exists(full_path):
		return ""
	var f := FileAccess.open(full_path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

static func _build_template_object(mon_info: String, mon_action: String, ovr: Dictionary) -> Dictionary:
	# 1. Load real MonInfo data.xml and merge <OverrideInitInfo> on top
	var info_xml := _load_template_xml(mon_info)
	var init_info: Dictionary = {}
	if not info_xml.is_empty():
		var re_init := RegEx.new()
		re_init.compile("(?is)<InitInfo\\b([^>]*)/?>")
		var m_init := re_init.search(info_xml)
		if m_init != null:
			var merged_attrs := _parse_attrs(m_init.get_string(1))
			for k in ovr.keys():
				merged_attrs[k] = ovr[k]
			init_info = _build_init_info(merged_attrs)
			init_info["template_info"] = mon_info
			init_info["template_action"] = mon_action

	# Fallback if MonInfo data.xml was not found
	if init_info.is_empty():
		var info_l := mon_info.to_lower()
		var npc_type := "BasicMon"
		var is_boss := info_l.contains("boss") or info_l.contains("king") or info_l.contains("sphinx")
		if info_l.contains("golem"):
			npc_type = "BossGolem" if is_boss else "MiniGolem"
		elif info_l.contains("ice"):
			npc_type = "IceMon"
		elif info_l.contains("kuo"):
			npc_type = "Mon2ndKuo"
		var fallback_attrs := ovr.duplicate()
		fallback_attrs["type"] = npc_type
		fallback_attrs["image"] = mon_info
		if is_boss and not fallback_attrs.has("boss"):
			fallback_attrs["boss"] = "true"
		init_info = _build_init_info(fallback_attrs)
		init_info["template_info"] = mon_info
		init_info["template_action"] = mon_action

	# 2. Load real MonAction data.xml for TriggerTable + ActionLists
	var action_xml := _load_template_xml(mon_action)
	if not action_xml.is_empty():
		var ta := _parse_triggers_and_actions(action_xml)
		if not (ta["action_lists"] as Dictionary).is_empty():
			return {
				"init_info": init_info,
				"triggers": ta["triggers"],
				"action_lists": ta["action_lists"],
			}

	# Fallback ActionList if MonAction data.xml was not found
	var act_l := mon_action.to_lower()
	var pat_func := "line" if act_l.contains("roll") else "free"
	var pat_event := "chase" if act_l.contains("rush") else "none"
	var actions: Array[Dictionary] = [{
		"name": "pattern",
		"action_id": 9,
		"func": pat_func,
		"event": pat_event,
		"duration": "3000",
		"userdist": "6",
	}]
	return {
		"init_info": init_info,
		"triggers": {"default": "1"},
		"action_lists": {"1": {"name": "1", "next": "1", "actions": actions}},
	}

func get_start_objects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obj in objects:
		var info: Dictionary = obj.get("init_info", {})
		if bool(info.get("from_start", false)):
			out.append(obj)
	return out

func get_objects_by_class(obj_class: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obj in objects:
		var info: Dictionary = obj.get("init_info", {})
		if int(info.get("obj_class", -1)) == obj_class:
			out.append(obj)
	return out

static func _parse_attrs(attr_text: String) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.new()
	re.compile("([A-Za-z0-9_]+)\\s*=\\s*\"([^\"]*)\"")
	for m in re.search_all(attr_text):
		out[m.get_string(1).to_lower()] = m.get_string(2)
	return out
