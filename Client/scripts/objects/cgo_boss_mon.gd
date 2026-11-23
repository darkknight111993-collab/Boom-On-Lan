class_name CGOBossMon
extends "res://scripts/objects/cgo_npc_basic_mon.gd"

## Script-driven Monster & Boss runtime (CGONpcBasicMon / CGONpcBossMon / BM00..BM08).
## Drives <StageClearScript> ActionLists with CPatternHandler AI, multi-HP anger phase,
## HP gagebar rendering, multi-tile hitbox, and CNpcCollideStrategy overrides.

signal boss_angered(mon: CGOBossMon)
signal boss_damaged(mon: CGOBossMon, hp_left: int)
signal create_object_requested(obj_class: int, spawn_cell: Vector2i)
signal attack_requested(mon: CGOBossMon, attack_info: Dictionary)
signal order_script_requested(target_class: int, action_list_name: String)

const CStageClearScriptClass = preload("res://scripts/modes/c_stage_clear_script.gd")
const CPatternHandlerClass = preload("res://scripts/objects/c_pattern_handler.gd")

var instance_id: int = 0
var npc_type: String = "BasicMon"
var npc_type_id: int = 5
var obj_class: int = 0
var is_boss: bool = false
var anger_hp: int = 0
var is_angry: bool = false
var show_gagebar: bool = false
var collision_size: Vector2i = Vector2i(40, 40)
var fire_pos: Dictionary = {"left": -1, "top": -1, "right": 1, "bottom": 1}
var pass_box: bool = false
var pass_static: bool = false
var pass_bomb: bool = false
var script_state: int = 0 # Used by CNpcCollideStrategy overrides

var triggers: Dictionary = {}
var action_lists: Dictionary = {}
var current_list_name: String = ""
var current_action_idx: int = 0
var action_timer: float = 0.0
var hit_invuln_timer: float = 0.0
var hit_flash_timer: float = 0.0

# Active pattern state
var active_pattern_func: String = "free"
var active_pattern_event: String = "none"
var active_user_dist: int = 6
var active_defense_rect: Rect2i = Rect2i(0, 0, 15, 13)
var _prev_open_count: int = -1
var _last_decision_cell: Vector2i = Vector2i(-1, -1)
var _is_waiting: bool = false

# Optional HP bar UI
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null

func setup_from_script(obj_def: Dictionary, p_instance_id: int = 0, p_cols: int = 15, p_rows: int = 13) -> void:
	instance_id = p_instance_id
	grid_cols = maxi(1, p_cols)
	grid_rows = maxi(1, p_rows)
	active_defense_rect = Rect2i(0, 0, grid_cols, grid_rows)
	var info: Dictionary = obj_def.get("init_info", {})
	npc_type = String(info.get("type", "BasicMon"))
	npc_type_id = int(info.get("npc_type_id", CStageClearScriptClass.get_npc_type_id(npc_type)))
	obj_class = int(info.get("obj_class", 0))
	is_boss = bool(info.get("is_boss", false))
	anger_hp = int(info.get("anger_hp", 0))
	is_angry = false
	show_gagebar = bool(info.get("show_gagebar", false))
	collision_size = info.get("collision_size", Vector2i(40, 40))
	fire_pos = (info.get("fire_pos", {"left": -1, "top": -1, "right": 1, "bottom": 1}) as Dictionary).duplicate()
	pass_box = bool(info.get("pass_box", false))
	pass_static = bool(info.get("pass_static", false))
	pass_bomb = bool(info.get("pass_bomb", false))
	triggers = (obj_def.get("triggers", {}) as Dictionary).duplicate(true)
	action_lists = (obj_def.get("action_lists", {}) as Dictionary).duplicate(true)

	var prefix: String = String(info.get("sprite_prefix", "SM01"))
	var pos: Vector2i = info.get("pos", Vector2i(7, 6))
	var init_hp: int = maxi(1, int(info.get("max_hp", 1)))
	var init_speed: float = 68.0 if is_boss else 84.0
	setup(prefix, clampi(pos.x, 0, grid_cols - 1), clampi(pos.y, 0, grid_rows - 1), init_speed, "Item/Bomb", init_hp)
	mon_name = npc_type
	_build_hp_bar()
	_update_hp_bar()

	if triggers.has("default"):
		start_action_list(String(triggers["default"]))

func _build_hp_bar() -> void:
	if not show_gagebar:
		return
	if _hp_bar_bg == null:
		var bar_w := clampf(float(collision_size.x) * 0.85, 44.0, 108.0)
		var bar_y := -float(maxi(collision_size.y, 48)) - 22.0
		_hp_bar_bg = ColorRect.new()
		_hp_bar_bg.color = Color(0.08, 0.08, 0.12, 0.85)
		_hp_bar_bg.position = Vector2(20.0 - bar_w * 0.5, bar_y)
		_hp_bar_bg.size = Vector2(bar_w, 8.0)
		_hp_bar_bg.z_index = 20
		add_child(_hp_bar_bg)

		_hp_bar_fill = ColorRect.new()
		_hp_bar_fill.color = Color(0.95, 0.25, 0.2, 1.0)
		_hp_bar_fill.position = Vector2(1.0, 1.0)
		_hp_bar_fill.size = Vector2(bar_w - 2.0, 6.0)
		_hp_bar_bg.add_child(_hp_bar_fill)

func _update_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null:
		return
	_hp_bar_bg.visible = alive and show_gagebar
	var ratio := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	_hp_bar_fill.size.x = maxf(0.0, (_hp_bar_bg.size.x - 2.0) * ratio)
	_hp_bar_fill.color = Color(1.0, 0.45, 0.1, 1.0) if is_angry else Color(0.95, 0.22, 0.2, 1.0)

func start_action_list(list_name: String) -> void:
	if not action_lists.has(list_name):
		return
	current_list_name = list_name
	current_action_idx = 0
	action_timer = 0.0
	_is_waiting = false
	_begin_current_action()

func fire_trigger(trigger_name: String) -> bool:
	var key := trigger_name.strip_edges().to_lower()
	if triggers.has(key):
		start_action_list(String(triggers[key]))
		return true
	return false

func _begin_current_action() -> void:
	if current_list_name.is_empty() or not action_lists.has(current_list_name):
		return
	var al: Dictionary = action_lists[current_list_name]
	var acts: Array = al.get("actions", [])
	while current_action_idx < acts.size():
		var act: Dictionary = acts[current_action_idx]
		var act_name: String = String(act.get("name", ""))
		match act_name:
			"wait":
				var ms := maxi(100, int(act.get("time", "500")))
				action_timer = float(ms) / 1000.0
				_is_waiting = true
				return
			"setstate":
				if act.has("speed"):
					var spd := float(act.get("speed", "4"))
					move_speed = clampf(spd * 22.0, 32.0, 240.0)
				current_action_idx += 1
			"pattern":
				active_pattern_func = String(act.get("func", "free")).to_lower()
				active_pattern_event = String(act.get("event", "none")).to_lower()
				active_user_dist = int(act.get("userdist", "6"))
				var dur := CStageClearScriptClass.parse_duration_range(String(act.get("duration", "2000")))
				var dur_ms := dur.x if dur.y <= dur.x else randi_range(dur.x, dur.y)
				action_timer = maxf(0.25, float(dur_ms) / 1000.0)
				_is_waiting = false
				return
			"createobj":
				var target_cls := int(act.get("class", "0"))
				if target_cls > 0:
					create_object_requested.emit(target_cls, cell)
				current_action_idx += 1
			"attack":
				var afunc := String(act.get("func", "direction")).to_lower()
				action = "attack"
				if afunc == "roll" or afunc == "directattack":
					var rush_spd := float(act.get("speed", "7"))
					move_speed = clampf(rush_spd * 24.0, 80.0, 260.0)
					var dir_str := String(act.get("direction", "")).to_lower()
					match dir_str:
						"down": dir = 0
						"up": dir = 1
						"left": dir = 2
						"right": dir = 3
					action_timer = 0.8
					_is_waiting = false
				else:
					action_timer = 0.45
					_is_waiting = true
				var attack_info := {
					"func": afunc,
					"power": maxi(1, int(act.get("power", "2"))),
					"pos": String(act.get("pos", act.get("pos00", ""))),
					"direction": String(act.get("direction", "")).to_lower(),
					"dist": maxi(1, int(act.get("dist", "2"))),
					"length": maxi(1, int(act.get("length", "3"))),
					"class": int(act.get("class", "0")),
					"num": maxi(1, int(act.get("num", "1"))),
					"cell": cell,
					"dir": dir,
					"fire_pos": fire_pos,
				}
				attack_requested.emit(self, attack_info)
				return
			"specialattack":
				action = "attack"
				action_timer = 0.35
				_is_waiting = true
				return
			"createmonmissile":
				var ang_deg := float(act.get("angle", "0"))
				attack_requested.emit(self, {
					"func": "createmonmissile",
					"missiletype": int(act.get("missiletype", "5")),
					"power": maxi(1, int(act.get("damage", "1"))),
					"speed": float(act.get("speed", "5")),
					"maxmovelen": float(act.get("maxmovelen", "300")),
					"angle": ang_deg,
					"cell": cell,
					"dir": dir,
					"fire_pos": fire_pos,
				})
				if int(act.get("continuouslyaction", "0")) != 0:
					current_action_idx += 1
				else:
					action_timer = 0.25
					_is_waiting = true
					return
			"orderscript":
				var tgt_cls := int(act.get("class", "0"))
				var tgt_list := String(act.get("actionlist", act.get("list", "")))
				if not tgt_list.is_empty():
					order_script_requested.emit(tgt_cls, tgt_list)
				current_action_idx += 1
			"appear":
				visible = true
				current_action_idx += 1
			"disappear":
				visible = false
				current_action_idx += 1
			"transfer":
				if act.has("pos"):
					var tp := CStageClearScriptClass.parse_pos_attr(String(act.get("pos", "")))
					set_cell(clampi(tp.x, 0, grid_cols - 1), clampi(tp.y, 0, grid_rows - 1))
				current_action_idx += 1
			"suicide":
				die()
				return
			_:
				current_action_idx += 1

	# Finished list: loop or chain to "next"
	var next_list := String(al.get("next", ""))
	if not next_list.is_empty() and action_lists.has(next_list):
		current_list_name = next_list
		current_action_idx = 0
		_is_waiting = false
		action_timer = 0.05

func step_script_ai(delta: float, is_cell_blocked: Callable, players: Array = [], monsters: Array = []) -> void:
	if hit_invuln_timer > 0.0:
		hit_invuln_timer = maxf(0.0, hit_invuln_timer - delta)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		if sp_visual != null:
			sp_visual.modulate = Color(1.0, 0.5, 0.5, 1.0) if hit_flash_timer > 0.0 else Color.WHITE

	if not alive:
		step_ai(delta, is_cell_blocked)
		_update_hp_bar()
		return

	if not current_list_name.is_empty():
		action_timer -= delta
		if action_timer <= 0.0:
			action = "walk"
			current_action_idx += 1
			_begin_current_action()

	if _is_waiting:
		anim_tick += 1
		if anim_tick >= 3:
			anim_tick = 0
			anim_frame += 1
		_update_visuals()
		_update_hp_bar()
		return

	# Decide direction at tile center using exact CPatternHandler algorithms
	var anchor_curr := get_cell_anchor(cell.x, cell.y)
	var step := move_speed * delta
	var near_center := absf(position.x - anchor_curr.x) <= step + 2.0 and absf(position.y - anchor_curr.y) <= step + 2.0
	if near_center and cell != _last_decision_cell:
		_last_decision_cell = cell
		var pat_dir := CPatternHandlerClass.from_bomber_dir(dir)
		var chosen := -1
		match active_pattern_event:
			"chase":
				chosen = CPatternHandlerClass.step_chase(cell, position, pat_dir, players, active_user_dist, is_cell_blocked, grid_cols, grid_rows)
			"avoid":
				chosen = CPatternHandlerClass.step_avoid(cell, pat_dir, players, is_cell_blocked, grid_cols, grid_rows)
			"defense":
				chosen = CPatternHandlerClass.step_defense(cell, pat_dir, active_defense_rect, is_cell_blocked, null, grid_cols, grid_rows)
			"monchase":
				chosen = CPatternHandlerClass.step_mon_chase(instance_id, cell, position, pat_dir, monsters, active_user_dist, is_cell_blocked, grid_cols, grid_rows)
		if chosen < 0:
			if active_pattern_func == "line":
				chosen = CPatternHandlerClass.step_line(cell, pat_dir, is_cell_blocked, null, grid_cols, grid_rows)
			else:
				var res := CPatternHandlerClass.step_free(cell, pat_dir, _prev_open_count, is_cell_blocked, null, grid_cols, grid_rows)
				chosen = int(res["dir"])
				_prev_open_count = int(res["open_count"])
		dir = CPatternHandlerClass.to_bomber_dir(chosen)

	step_ai(delta, is_cell_blocked)
	_update_hp_bar()

func _resolve_sprite_path(act: String, d_name: String) -> String:
	var d_low := d_name.to_lower()
	var key := "%s#%s#%s" % [monster_id, act, d_low]
	if _sprite_path_cache.has(key):
		return _sprite_path_cache[key]

	var base := monster_id if monster_id.contains("/") else ("Monster/%s" % monster_id)
	var is_right := d_low == "right"
	var lr := "Right" if is_right else "Left"
	var r_suf := "Right" if is_right else ""
	var candidates: Array[String] = []
	if act == "die":
		candidates = [
			"%s_Die" % base,
			"%s_Die_%s" % [base, lr],
			"%s_Die%s" % [base, r_suf],
			"%s_CDie%s" % [base, lr],
			"%s_die" % base,
			"%s_Dead" % base,
		]
	elif act == "attack":
		candidates = [
			"%s_attack_%s" % [base, d_low],
			"%s_Attack_%s" % [base, lr],
			"%s_Attack%s" % [base, r_suf],
			"%s_Attack%s" % [base, lr],
			"%s_Attack_%s" % [base, d_name],
			"%s_Walk_%s" % [base, lr],
			"%s_Walk%s" % [base, r_suf],
			"%s_walking_%s" % [base, d_low],
			"%s_Walking_%s" % [base, d_name],
		]
	elif act == "anger":
		candidates = [
			"%s_anger" % base,
			"%s_walking_%s" % [base, d_low],
		]
	else:
		candidates = [
			"%s_Walk_%s" % [base, lr],
			"%s_Walk%s" % [base, r_suf],
			"%s_Stop%s" % [base, r_suf],
			"%s_Walking%s" % [base, lr],
			"%s_walking_%s" % [base, d_low],
			"%s_Walking_%s" % [base, d_name],
			"%s_Walking%s" % [base, d_name],
			"%s_%s" % [base, d_name],
			"%s-Walking_%s" % [base, d_name],
		]

	var sdb: Object = _get_sprite_db()
	var selected := candidates[0]
	if sdb != null:
		for c in candidates:
			var dir_path: String = sdb.resolve_sprite_dir(c)
			if FileAccess.file_exists(dir_path.path_join("sprite.json")):
				selected = c
				break
	_sprite_path_cache[key] = selected
	return selected

func check_bomber_collision(bomber: Node) -> void:
	if not alive or bomber == null:
		return
	if CPatternHandlerClass.should_skip_collision(npc_type, script_state, npc_type_id):
		return
	if not bomber.get("alive") or bomber.get("in_bubble"):
		return
	var half_w := maxf(24.0, float(collision_size.x) * 0.45)
	var half_h := maxf(24.0, float(collision_size.y) * 0.45)
	var mon_center := position + Vector2(20.0, -20.0)
	var b_pos: Vector2 = bomber.position + Vector2(20.0, -20.0)
	if absf(mon_center.x - b_pos.x) < half_w and absf(mon_center.y - b_pos.y) < half_h:
		if touch_damage_lethal or CPatternHandlerClass.is_snowbear_charge_state(npc_type, script_state):
			if bomber.has_method("pop_kill"):
				bomber.pop_kill()
		else:
			if bomber.has_method("trap_in_bubble"):
				bomber.trap_in_bubble()

func hit_by_flame(flame_cell: Vector2i) -> bool:
	if not alive or hit_invuln_timer > 0.0:
		return false
	var rx := maxi(0, (collision_size.x / 40) / 2)
	var ry := maxi(0, (collision_size.y / 40) / 2)
	if absi(flame_cell.x - cell.x) <= rx and absi(flame_cell.y - cell.y) <= ry:
		hit_invuln_timer = 0.45 if is_boss else 0.15
		take_damage(1)
		return true
	return false

func compute_attack_cells(attack_info: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var afunc := String(attack_info.get("func", "direction")).to_lower()
	var origin: Vector2i = attack_info.get("cell", cell)
	var fp: Dictionary = attack_info.get("fire_pos", fire_pos)
	match afunc:
		"directiondest", "fallingrock", "fallingrocksnow", "avalanchesnow", "createmonmissile":
			var p_str := String(attack_info.get("pos", ""))
			if not p_str.is_empty():
				var p := CStageClearScriptClass.parse_pos_attr(p_str)
				cells.append(Vector2i(clampi(p.x, 0, grid_cols - 1), clampi(p.y, 0, grid_rows - 1)))
			else:
				cells.append(origin)
		"rectangle":
			var d := maxi(1, int(attack_info.get("dist", 2)))
			for off in [Vector2i(-d, -d), Vector2i(d, -d), Vector2i(-d, d), Vector2i(d, d)]:
				var c: Vector2i = origin + off
				if c.x >= 0 and c.x < grid_cols and c.y >= 0 and c.y < grid_rows:
					cells.append(c)
		"laser":
			var length := maxi(1, int(attack_info.get("length", 3)))
			var dv: Vector2 = MON_DIR_VECTORS[clampi(int(attack_info.get("dir", dir)), 0, 3)]
			var iv := Vector2i(int(dv.x), int(dv.y))
			for step_i in range(1, length + 1):
				var c := origin + iv * step_i
				if c.x >= 0 and c.x < grid_cols and c.y >= 0 and c.y < grid_rows:
					cells.append(c)
		"nuclearbomb":
			cells.append(Vector2i(clampi(origin.x, 0, grid_cols - 1), clampi(origin.y, 0, grid_rows - 1)))
		_:
			# Default / direction / autokick: use fire_pos offsets along facing direction
			var f_dir := clampi(int(attack_info.get("dir", dir)), 0, 3)
			var off_cell := origin
			match f_dir:
				0: off_cell = origin + Vector2i(0, int(fp.get("bottom", 1)))
				1: off_cell = origin + Vector2i(0, int(fp.get("top", -1)))
				2: off_cell = origin + Vector2i(int(fp.get("left", -1)), 0)
				3: off_cell = origin + Vector2i(int(fp.get("right", 1)), 0)
			cells.append(Vector2i(clampi(off_cell.x, 0, grid_cols - 1), clampi(off_cell.y, 0, grid_rows - 1)))
	return cells

func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	hit_flash_timer = 0.2
	boss_damaged.emit(self, hp)
	_update_hp_bar()
	if hp <= 0:
		die()
		return
	if anger_hp > 0 and hp <= anger_hp and not is_angry:
		is_angry = true
		move_speed = minf(240.0, move_speed * 1.25)
		boss_angered.emit(self)
		fire_trigger("bossanger")
		_update_hp_bar()
