class_name CGOBomberBase
extends "res://scripts/objects/c_game_object.gd"

## Base bomber map entity (CA.exe RTTI .?AVCGOBomberBase@@ @ 0xe225a8, ctor sub_592A2B).
## Holds visibility flag m_bVisible (this[2471] @ +9884) and the 90-state ObjectTable animation player (sub_58DF45).

const OBJECTTABLE_PATH := "res://data/objecttable.json"

# Standard 90-state indices from ObjectTable (Character/C00_A .. B01_A)
const STATE_BLINK := 0
const STATE_DIE := 1
const STATE_FAINT := 2
const STATE_HURRAH := 3
const STATE_RIDE_BASE := 4       # +ot_dir (0=L, 1=U, 2=R, 3=D)
const STATE_STOP_RIDE_BASE := 8  # +ot_dir
const STATE_STOP_BASE := 12      # +ot_dir
const STATE_THROW_BASE := 16     # +ot_dir
const STATE_WALK_BASE := 20      # +ot_dir
const STATE_START := 24
const STATE_LOCKED_IN := 25
const STATE_RELEASE := 26
# Slide / Drill states (27..42, CGOBomber::OnStateTick 0x5A0F75)
const STATE_SLIDE_JUMP_BASE := 27      # +ot_dir (10 px/tick + spin)
const STATE_SLIDE_JUMP_HOLD_BASE := 31 # +ot_dir
const STATE_DRILL_BASE := 35           # +ot_dir (on finish -> Stop)
const STATE_SLIDE_RIDE_BASE := 39      # +ot_dir (10 px/tick on mount)
# Ghost & LockedIn-Move states (43..57, 0x59E9D2 / 0x5A0F75 / 0x59BD5C)
const STATE_GHOST_IN := 43             # GhostInOut 0..7 (on finish -> 51)
const STATE_GHOST_WALK_BASE := 44      # +ot_dir (half speed)
const STATE_GHOST_STOP_BASE := 48      # +ot_dir
const STATE_LOCKED_IN_MOVE_BASE := 52  # +ot_dir (1 px every 2 ticks = 0.5 px/tick)
const STATE_LOCKED_IN_STOP := 56       # stationary inside bubble
const STATE_GHOST_OUT := 57            # GhostInOut 7..0 (on finish -> deactivate)
# Hedgehog mode states (58..75, StaticChar/Hedgehog-*, CGOHedgehogBomber 0x74A11F..0x74A8D9)
const STATE_HEDGEHOG_BLINK := 58
const STATE_HEDGEHOG_DIE := 59
const STATE_HEDGEHOG_FAINT := 60
const STATE_HEDGEHOG_HURRAH := 61
const STATE_HEDGEHOG_CRY := 62
const STATE_HEDGEHOG_WALK_BASE := 63   # +ot_dir (0=L, 1=U, 2=R, 3=D)
const STATE_HEDGEHOG_STOP_BASE := 67   # +ot_dir
const STATE_HEDGEHOG_SLIDE_BASE := 71  # +ot_dir
const STATE_HEDGEHOG_STRUGGLE := 75
# SnowBall / SnowBear states (76..89, CGOSnowBallBomber 0x7CD235 / 0x7CD392, CGOSnowBearBomber 0x443B0C)
const STATE_SNOW_THROW_BASE := 76      # +ot_dir (2f throw, on finish -> Stop)
const STATE_SNOW_HIT := 80
const STATE_SNOW_DYING := 81
const STATE_SNOW_SPIN_BASE := 82       # +ot_dir (can interrupt 52..56 in 0x59BD5C)
const STATE_STATIC_STOP_BASE := 86     # +ot_dir (reserved 1f 0:100 static pose)
const TOTAL_STATES := 90

const BOMBER_DIR_TO_OT_DIR: Array[int] = [3, 1, 0, 2] # CGOBomber dir (0=D,1=U,2=L,3=R) -> ObjectTable dir (0=L,1=U,2=R,3=D)

var m_bVisible: bool = true # Initialized to 1 in sub_5A3F7D (CGOBomber + 9884)
var in_bush: bool = false # Passable-tile concealment state (sub_59F04D)

# ObjectTable 30ms fixed-tick state player (CGameObject::SetState vtable+92 / sub_58DF45)
var ot_states: Array = []
var cur_state_idx: int = -1
var state_step_idx: int = 0
var state_tick_in_step: int = 0
var state_loop: bool = true
var state_finished: bool = false

static var _ot_char_cache: Dictionary = {} # "Character/C00_A" -> Array of state dicts
static var _ot_loaded: bool = false

static func bomber_dir_to_ot_dir(d: int) -> int:
	if d < 0 or d >= BOMBER_DIR_TO_OT_DIR.size():
		return 3
	return BOMBER_DIR_TO_OT_DIR[d]

static func is_locked_in_state(st: int) -> bool:
	return st == STATE_LOCKED_IN or (st >= STATE_LOCKED_IN_MOVE_BASE and st <= STATE_LOCKED_IN_STOP)

static func is_ghost_state(st: int) -> bool:
	return st == STATE_GHOST_IN or (st >= STATE_GHOST_WALK_BASE and st <= STATE_GHOST_STOP_BASE + 3) or st == STATE_GHOST_OUT

static func is_slide_state(st: int) -> bool:
	return (st >= STATE_SLIDE_JUMP_BASE and st <= STATE_SLIDE_JUMP_HOLD_BASE + 3) or (st >= STATE_SLIDE_RIDE_BASE and st <= STATE_SLIDE_RIDE_BASE + 3)

static func is_hedgehog_state(st: int) -> bool:
	return st >= STATE_HEDGEHOG_BLINK and st <= STATE_HEDGEHOG_STRUGGLE

static func is_snowball_state(st: int) -> bool:
	return st >= STATE_SNOW_THROW_BASE and st <= STATE_SNOW_SPIN_BASE + 3

static func can_interrupt_locked_in(next_state: int) -> bool:
	# Exact CA.exe CGOBomber::SetState (0x59BD5C) transition allowlist from states 52..56
	return (
		next_state == STATE_DIE
		or next_state == STATE_HURRAH
		or next_state == STATE_RELEASE
		or next_state == STATE_HEDGEHOG_DIE
		or (next_state >= STATE_LOCKED_IN_MOVE_BASE and next_state <= STATE_LOCKED_IN_STOP)
		or (next_state >= STATE_SNOW_SPIN_BASE and next_state <= STATE_SNOW_SPIN_BASE + 3)
	)

static func get_state_finish_transition(st: int, ghost_rebirth: bool = false) -> int:
	# Exact CA.exe CGOBomber::OnStateTick (0x5A0F75) + CGOSnowBallBomber (0x7CD392) finish transitions
	if st == STATE_DIE:
		return STATE_GHOST_IN if ghost_rebirth else -1
	if st >= STATE_STOP_BASE and st <= STATE_STOP_BASE + 3:
		return STATE_BLINK
	if st >= STATE_THROW_BASE and st <= STATE_THROW_BASE + 3:
		return st - 4
	if st == STATE_START or st == STATE_RELEASE:
		return STATE_STOP_BASE + 3
	if st >= STATE_DRILL_BASE and st <= STATE_DRILL_BASE + 3:
		return st - 23
	if st == STATE_GHOST_IN:
		return STATE_GHOST_STOP_BASE + 3
	if st == STATE_GHOST_OUT:
		return -1
	if st >= STATE_SNOW_THROW_BASE and st <= STATE_SNOW_THROW_BASE + 3:
		return (st - STATE_SNOW_THROW_BASE) + STATE_STOP_BASE
	return st

static func _ensure_ot_loaded() -> void:
	if _ot_loaded:
		return
	_ot_loaded = true
	if not FileAccess.file_exists(OBJECTTABLE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OBJECTTABLE_PATH))
	if not (parsed is Array):
		return
	for entry: Variant in parsed:
		if entry is Dictionary:
			var n: String = str(entry.get("name", ""))
			if n.begins_with("Character/"):
				var st: Variant = entry.get("states", null)
				if st is Array and not st.is_empty():
					_ot_char_cache[n] = st

static func get_char_states(char_code: String) -> Array:
	_ensure_ot_loaded()
	var clean: String = char_code.substr(10) if char_code.begins_with("Character/") else char_code
	for key in ["Character/%s_A" % clean, "Character/%s" % clean, "Character/C00_A"]:
		if _ot_char_cache.has(key):
			return _ot_char_cache[key]
	return []

static func extract_action_from_sprite(sprite_name: String) -> String:
	# "Character/C00-WalkDown_A" -> "WalkDown", "Character/C00-Die" -> "Die"
	var dash: int = sprite_name.find("-")
	var s: String = sprite_name.substr(dash + 1) if dash >= 0 else sprite_name
	if s.ends_with("_A") or s.ends_with("_B") or s.ends_with("_C"):
		s = s.substr(0, s.length() - 2)
	return s

func load_bomber_states(char_code: String) -> void:
	ot_states = get_char_states(char_code)
	cur_state_idx = -1
	state_step_idx = 0
	state_tick_in_step = 0
	state_finished = false

func set_bomber_state(state_idx: int, loop: bool = true, force_restart: bool = false) -> void:
	# From CGameObject::SetState (vtable+92)
	if not force_restart and cur_state_idx == state_idx and state_loop == loop:
		return
	cur_state_idx = state_idx
	state_step_idx = 0
	state_tick_in_step = 0
	state_loop = loop
	state_finished = false

func step_bomber_state_tick() -> bool:
	# From sub_58DF45 (CGameObject::UpdateAnim): advances 1 fixed 30ms tick; returns true when step changes or finishes
	if state_finished or cur_state_idx < 0 or cur_state_idx >= ot_states.size():
		return false
	var st: Dictionary = ot_states[cur_state_idx]
	var frames: Array = st.get("frames", [])
	if frames.is_empty():
		return false
	if state_step_idx >= frames.size():
		state_step_idx = 0
	var dur: int = int(frames[state_step_idx][1])
	if dur < 0:
		return false # Infinite hold (-1)
	if dur == 0:
		dur = 1
	state_tick_in_step += 1
	if state_tick_in_step >= dur:
		state_tick_in_step = 0
		state_step_idx += 1
		if state_step_idx >= frames.size():
			if state_loop:
				state_step_idx = 0
			else:
				state_step_idx = frames.size() - 1
				state_finished = true
		return true
	return false

func get_bomber_state_frame() -> Dictionary:
	if cur_state_idx < 0 or cur_state_idx >= ot_states.size():
		return {}
	var st: Dictionary = ot_states[cur_state_idx]
	var frames: Array = st.get("frames", [])
	if frames.is_empty():
		return {}
	var idx: int = clampi(state_step_idx, 0, frames.size() - 1)
	var sprite_name: String = str(st.get("sprite", ""))
	return {
		"sprite": sprite_name,
		"action": extract_action_from_sprite(sprite_name),
		"frame": int(frames[idx][0]),
	}

func set_bomber_visible(v: bool) -> void:
	# From sub_594E07 (CGOBomber::SetVisible)
	m_bVisible = v

func get_bomber_visible() -> bool:
	# From sub_594E17 (CGOBomber::GetVisible)
	return m_bVisible

func is_bomber_visible(hidden_in_bush: bool = false) -> bool:
	# From sub_59F107 (CGOBomber::IsVisible, vtable[117]): false if concealed in bush (sub_59F04D), else m_bVisible
	if hidden_in_bush or in_bush:
		return false
	return m_bVisible

static func is_passable_info_concealing(info: Dictionary) -> bool:
	# From sub_59F04D: type == 3 (Passable) conceals bomber iff byte +19 in tile_info raw == 0
	if int(info.get("type", -1)) != 3:
		return false
	var raw_hex: String = str(info.get("raw", ""))
	if raw_hex.length() >= 40:
		return raw_hex.substr(38, 2).hex_to_int() == 0
	return true

func get_foot_cell() -> Vector2i:
	# From sub_59C48A (0x59C48A): foot-anchor grid cell ((x + 20) / 40, y / 40) used by sub_59F04D
	var local := position - map_origin
	return Vector2i(int(floor((local.x + 20.0) / float(CELL_SIZE))), int(floor(local.y / float(CELL_SIZE))))
