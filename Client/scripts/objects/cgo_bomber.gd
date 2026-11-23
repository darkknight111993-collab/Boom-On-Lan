class_name CGOBomber
extends "res://scripts/objects/cgo_bomber_base.gd"

const CBomberAttrScript = preload("res://scripts/objects/cbomber_attr.gd")
const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")
const CShipAttrClass = preload("res://scripts/objects/cship_attr.gd")
const CGOShipClass = preload("res://scripts/objects/cgo_ship.gd")
const CGOItemBoxClass = preload("res://scripts/objects/cgo_item_box.gd")
const CGOBomberCosmeticsClass = preload("res://scripts/objects/cgo_bomber_cosmetics.gd")

## CGOBomber - Playable Character & Bot entity
## Ported from CA.exe CGOBomber with 4-direction movement, Corner Sliding Assist,
## bubble trap, teammate rescue, pop kill, item progression, and layer rendering.

signal bomb_requested(player: CGOBomber, col: int, row: int)
signal tank_shot(start_pos: Vector2, dir_vec: Vector2, owner_id: int)
signal trapped(player: CGOBomber)
signal rescued(player: CGOBomber)
signal died(player: CGOBomber)

# 4 directions: 0: Down, 1: Up, 2: Left, 3: Right
const DIR_NAMES := ["Down", "Up", "Left", "Right"]
const DIR_VECTORS: Array[Vector2] = [
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(-1, 0),
	Vector2(1, 0)
]

@export var player_id: int = 0
@export var player_name: String = "Player"
@export var char_code: String = "Character/C00"
@export var char_prefix: String = "C00"
@export var team_color: Color = Color(1.0, 0.2, 0.2)
@export var is_bot: bool = false
@export var bomb_skin: String = "Bomb/Bomb00"
@export var can_kick: bool = false
@export var can_punch: bool = false
var item_box: CGOItemBoxClass = CGOItemBoxClass.new() # Embedded CGOItemBox (CGOBomber::this[655], 0xe30044)
var dart_count: int:
	get: return item_box.get_count_by_type(21)
	set(v): item_box.set_item_count("Item/ItemDart", v, 21, 0, "Item/Dart")
var needle_count: int:
	get: return item_box.get_needle_total_count()
	set(v): item_box.set_item_count("Item/ItemNiddle", v, 23, 0, "Item/Niddle")
var oxygen_count: int:
	get: return item_box.get_count_by_type(22)
	set(v): item_box.set_item_count("Item/ItemOxygen", v, 22, 0, "Item/Oxygen")
var banana_count: int:
	get: return item_box.get_count_by_type(11, 3)
	set(v): item_box.set_item_count("Banana1", v, 11, 3, "Item/Banana00")
var bond_count: int:
	get: return item_box.get_count_by_type(11, 1)
	set(v): item_box.set_item_count("Item/ItemBond", v, 11, 1, "Item/Bond")
var mine_count: int:
	get: return item_box.get_count_by_type(11, 2)
	set(v): item_box.set_item_count("Item/ItemTrap", v, 11, 2, "Item/Trap")
var pushpin_count: int:
	get: return item_box.get_count_by_type(11, 4)
	set(v): item_box.set_item_count("Pin", v, 11, 4, "Item/Pushpin")
@export var shield_ticks: int = 0
@export var devil_ticks: int = 0
@export var auto_bomb_ticks: int = 0   # Skeleton0 (144 ticks = 4.32s, sub_445DEE)
@export var reverse_dir_ticks: int = 0 # Skeleton1 (144 ticks = 4.32s, sub_445E0F)
@export var camouflage_ticks: int = 0  # Item/Camouflage (ngụy trang 244 ticks, sub_447B95)
@export var hollow_ticks: int = 0      # Item/ItemHollow (bóng tàng hình 244 ticks, sub_445DBB)
@export var kart_nitro_ticks: int = 0  # Item/Nitro (boost xe đua Kart speed 10, Section 16.4)

@export var equipped_hat: String = ""
@export var equipped_cloth: String = ""
@export var equipped_face: String = ""
@export var equipped_char_deco: String = ""
@export var equipped_id_deco: String = ""
var cosmetics: CGOBomberCosmeticsClass = CGOBomberCosmeticsClass.new() # 13-slot AvatarDeco + CharDeco + IDDeco (0x58EE0D)

var is_shielded: bool:
	get: return shield_ticks > 0

var is_devil: bool:
	get: return devil_ticks > 0 or reverse_dir_ticks > 0 or auto_bomb_ticks > 0

var is_trapped: bool:
	get: return in_bubble

# Compatibility properties
var id: int:
	get: return player_id
	set(val): player_id = val

var grid_pos: Vector2i:
	get: return cell
	set(val): set_cell(val.x, val.y)

var world_pos: Vector2:
	get: return get_center()

# Stats from CBomberAttr
var bomber_attr: CBomberAttrScript = null
var speed: int = 5
var base_speed: int = 5
var speed_max: int = 7
var bombs_cur: int = 1
var bombs_max: int = 10
var active_bombs: int = 0
var power_cur: int = 1
var power_max: int = 7

# Abilities from mounts (CShipAttr / sub_585800)
var m_fAbNotEatItem: bool = false
var m_fAbPassBox: bool = false
var m_fAbTank: bool = false
var on_special_ground: bool = false # Rail ground flag for RailCar speed_alt (sub_597EC6)
var bond_ticks: int = 0 # Glue slow debuff (sub_597233: 12s = 400 ticks @ 30ms)
var _placed_trap_cell: Vector2i = Vector2i(-1, -1) # Self-immunity cell until bomber leaves (0x59AA2B / 0x59C2B2 / 0x5A6244)
var slide_ticks: int = 0
var _slide_can_fit_cb: Callable = Callable()
var is_ghost: bool = false
var ghost_rebirth_enabled: bool = false

# Bubble trap (CGOBubble / sub_44DA8F / sub_4F3D22)
const BUBBLE_TOTAL_TICKS := 200 # 6.0s (200 ticks * 0.03s)
const BUBBLE_GRACE_TICKS := 16  # 480ms grace period (16 ticks * 0.03s)
var bubble_elapsed_ticks: int = 0
var bubble_anim_ticks: int = 0
var bubble_state: String = "lock" # "lock", "live", "kill"
var rescue_invuln_ticks: int = 0  # 33 ticks (1.0s) invulnerability after rescue (sub_44A18B)
var ship_dismount_ticks: int = 0  # 50 ticks (1.5s) flame invulnerability after mount hit (sub_5A3F7D / sub_59F248)
var ship_ride_count: int = 0  # 15 ticks (450ms) suction to tile center on mount (sub_5A3F7D)
var _dismount_ship_sprite_path: String = "" # Last ship sprite shown blinking during dismount (sub_59923A)

# Hurrah animation sequence (Character/Cxx_A group 3 in objecttable.json)
const HURRAH_CYCLE_TICKS := 204 # 6.12s
const HURRAH_SEQUENCE: Array = [
	[0, 66],
	[1, 6], [0, 6], [2, 6], [0, 6],
	[3, 6], [0, 6], [3, 6], [0, 6], [3, 6], [0, 6], [3, 6], [0, 6],
	[1, 6], [0, 6], [2, 6], [0, 6],
	[3, 6], [0, 6], [3, 6], [0, 6], [3, 6], [3, 6], [0, 6]
]

# State
var alive: bool = true
var in_bubble: bool = false
var bubble_ticks: int = 0
var bubble_max_ticks: int = 200 # 6.0 seconds (sub_4F3D22)
var dir: int = 0
var action: String = "start"
var go_ship: CGOShipClass = CGOShipClass.new() # Embedded m_goShip (CGOBomber + 2104)
var mount: Variant = null # Backwards-compatible mount Dictionary synced with go_ship
var is_shooting: bool = false
var shoot_ticks: int = 0
var shoot_cooldown: float = 0.0

# Animation & state counters
var anim_tick: int = 0
var anim_frame: int = 0
var idle_ticks: int = 0
var throw_ticks: int = 0
var start_ticks: int = 85
var hurrah_ticks: int = 0
var die_ticks: int = 0

# Bot AI
var ai_timer: float = 0.0
var bot_dir: Vector2 = Vector2.ZERO
var bot_target_cell: Vector2i = Vector2i(-1, -1)

# Visual nodes
var shadow: Sprite2D
var sp_mount: Sprite2D
var sp_char_deco: Sprite2D
var sp_adjust: Sprite2D
var sp_static: Sprite2D
var _deco_layer: Node2D
var _deco_adjust_nodes: Array[Sprite2D] = []
var _deco_static_nodes: Array[Sprite2D] = []
var sp_bubble: Sprite2D
var sp_indicator: Sprite2D
var sp_id_deco: Sprite2D
var name_lbl: Label

func apply_character_attr(key: Variant) -> bool:
	# From sub_97124A / CBomberAttr getters (0x971A0F..0x971620)
	var attr_res: CBomberAttrScript = CBomberAttrScript.get_attr(key)
	if attr_res == null:
		return false
	bomber_attr = attr_res
	char_code = attr_res.char_name
	char_prefix = attr_res.short_name
	base_speed = attr_res.speed_init
	speed = attr_res.speed_init
	speed_max = attr_res.speed_max
	bombs_cur = attr_res.bomb_init
	bombs_max = attr_res.bomb_max
	power_cur = attr_res.power_init
	power_max = attr_res.power_max
	load_bomber_states(char_prefix)
	return true

func setup(p_id: int, p_name: String, c_code: String, col: int, row: int, color: Color, bot: bool = false, skin: String = "", initial_mount: String = "", attr: Dictionary = {}, equipped_items: Dictionary = {}) -> void:
	player_id = p_id
	player_name = p_name
	char_code = c_code
	team_color = color
	is_bot = bot
	bomb_skin = skin if skin != "" else "Bomb/Bomb00"

	equipped_hat = str(equipped_items.get("hat", ""))
	equipped_cloth = str(equipped_items.get("cloth", ""))
	equipped_face = str(equipped_items.get("face", ""))
	equipped_char_deco = str(equipped_items.get("char_deco", ""))
	equipped_id_deco = str(equipped_items.get("id_deco", ""))
	cosmetics.clear_all()
	if equipped_hat != "":
		cosmetics.equip_slot(1, equipped_hat)
	if equipped_cloth != "":
		cosmetics.equip_slot(2, equipped_cloth)
	if equipped_face != "":
		cosmetics.equip_slot(3, equipped_face)
	var extra_slots: Variant = equipped_items.get("slots", null)
	if extra_slots is Dictionary:
		for k: Variant in (extra_slots as Dictionary).keys():
			cosmetics.equip_slot(int(k), str((extra_slots as Dictionary)[k]))
	cosmetics.char_deco = equipped_char_deco
	cosmetics.id_deco = equipped_id_deco

	apply_character_attr(char_code)
	if not attr.is_empty():
		base_speed = int(attr.get("base_speed", base_speed))
		speed = base_speed
		speed_max = int(attr.get("max_speed", speed_max))
		bombs_cur = int(attr.get("base_bomb", bombs_cur))
		bombs_max = mini(int(attr.get("max_bomb", bombs_max)), CBomberAttrScript.BOMB_MAX_CAP)
		power_cur = int(attr.get("base_power", power_cur))
		power_max = int(attr.get("max_power", power_max))
		can_kick = bool(attr.get("can_kick", false))
		can_punch = bool(attr.get("can_punch", false))
	else:
		can_kick = false
		can_punch = false

	alive = true
	in_bubble = false
	visible = true
	modulate.a = 1.0
	die_ticks = 0
	action = "start"
	start_ticks = 78
	anim_frame = 0
	load_bomber_states(char_prefix)
	set_bomber_state(STATE_START, false, true)
	item_box.on_match_start() # Auto-select Scanner -> Dart (0x5A517F)

	if sp_adjust != null:
		sp_adjust.modulate = team_color
	if name_lbl != null:
		name_lbl.text = player_name
		name_lbl.visible = true

	set_cell(col, row)

	if initial_mount != "":
		equip_mount(initial_mount)

	_update_visuals()

func _init() -> void:
	# Build composite visual nodes immediately upon instantiation
	shadow = Sprite2D.new()
	shadow.centered = false
	add_child(shadow)

	sp_mount = Sprite2D.new()
	sp_mount.centered = false
	sp_mount.visible = false
	add_child(sp_mount)

	sp_char_deco = Sprite2D.new()
	sp_char_deco.centered = false
	sp_char_deco.visible = false
	add_child(sp_char_deco)

	sp_adjust = Sprite2D.new()
	sp_adjust.centered = false
	sp_adjust.modulate = team_color
	add_child(sp_adjust)

	sp_static = Sprite2D.new()
	sp_static.centered = false
	add_child(sp_static)

	_deco_layer = Node2D.new()
	add_child(_deco_layer)

	sp_bubble = Sprite2D.new()
	sp_bubble.centered = false
	sp_bubble.visible = false
	add_child(sp_bubble)

	sp_indicator = Sprite2D.new()
	sp_indicator.centered = true
	sp_indicator.visible = false
	sp_indicator.z_index = 20
	add_child(sp_indicator)

	sp_id_deco = Sprite2D.new()
	sp_id_deco.centered = true
	sp_id_deco.visible = false
	add_child(sp_id_deco)

	name_lbl = Label.new()
	name_lbl.text = player_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(40, 14)
	name_lbl.position = Vector2(0, -42)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	add_child(name_lbl)

func _ready() -> void:
	_update_anchor_position()
	_update_visuals()

func get_center() -> Vector2:
	return position + Vector2(20.0, -19.5)

func get_bomb_placement_cell() -> Vector2i:
	# CA.exe sub_449C1D converts the continuous pixel position with x+20 and y-15 offsets.
	return Vector2i(
		int(floor((position.x - map_origin.x + 20.0) / float(CELL_SIZE))),
		int(floor((position.y - map_origin.y - 15.0) / float(CELL_SIZE)))
	)

func get_flame_hitbox() -> Rect2:
	# CA.exe sub_4EDB76: clips a 32x15 rect from (x+4, y-15) against flame cells.
	return Rect2(position + Vector2(4.0, -15.0), Vector2(32.0, 15.0))

static func get_hurrah_frame(ticks: int) -> int:
	var t: int = ticks % HURRAH_CYCLE_TICKS
	for pair in HURRAH_SEQUENCE:
		var fr: int = int(pair[0])
		var dur: int = int(pair[1])
		if t < dur:
			return fr
		t -= dur
	return 0

func get_effective_speed(on_special_tile: bool = false) -> int:
	# From sub_59EC93 & sub_597EC6 (CGOShip::GetAltSpeed)
	if bond_ticks > 0:
		return 2 # Exact CA.exe sub_59EC93 @ 0x59ecd6 -> sub_599A12 (this[451] != 0)
	if go_ship != null and go_ship.is_valid():
		return go_ship.get_speed(on_special_tile)
	if mount != null:
		if on_special_tile:
			var alt: int = int(mount.get("speed_alt", 0))
			if alt > 0:
				return alt
		return int(mount.get("speed", 5))
	return speed

static func ship_speed_to_pixels_per_sec(speed_px_per_tick: int) -> float:
	# From sub_59EC93: ship speed is integer pixels per 30ms tick (10 -> 333.33 px/s, 2 -> 66.67 px/s)
	return float(speed_px_per_tick) / CGOShipClass.TICK_SEC

func can_eat_item() -> bool:
	return alive and not in_bubble and not m_fAbNotEatItem

func can_pass_box() -> bool:
	return m_fAbPassBox or (mount != null and mount.get("can_pass_box", false))

func set_ab_pass_box(enabled: bool) -> bool:
	# From sub_599B78 (CGOBomber::SetAbPassBox)
	if m_fAbPassBox == enabled:
		return false
	m_fAbPassBox = enabled
	return true

func set_ab_not_eat_item(enabled: bool) -> bool:
	# From sub_599BAC (CGOBomber::SetAbNotEatItem)
	if m_fAbNotEatItem == enabled:
		return false
	m_fAbNotEatItem = enabled
	return true

static func get_ship_jump_arc_dy(ride_count: int) -> int:
	return CGOShipClass.calc_jump_arc_dy(ride_count)

static func is_ship_visible_for_ride_count(ride_count: int) -> bool:
	return CGOShipClass.calc_visible_for_ride_count(ride_count)

func try_use_oxygen() -> bool:
	if not alive or not in_bubble or oxygen_count <= 0:
		return false
	oxygen_count -= 1
	bubble_elapsed_ticks = 0
	bubble_ticks = BUBBLE_TOTAL_TICKS
	_play_audio("Wave/Release")
	_update_visuals()
	return true

func can_be_hit_by_flame() -> bool:
	if not alive:
		return false
	if in_bubble:
		return false # CA.exe sub_449CB9: trapped bombers are IMMUNE to flames!
	if ship_dismount_ticks > 0:
		return false # CA.exe sub_44AF53: 50 ticks invulnerability after mount loss
	if rescue_invuln_ticks > 0:
		return false # CA.exe sub_44A18B: 33 ticks invulnerability after rescue
	return true

func can_pop_or_rescue() -> bool:
	return in_bubble and bubble_elapsed_ticks >= BUBBLE_GRACE_TICKS and bubble_state == "lock"

func can_kick_bomb() -> bool:
	return can_kick and mount == null and alive and not in_bubble

func can_punch_bomb() -> bool:
	return can_punch and mount == null and alive and not in_bubble

func trigger_throw_anim() -> void:
	if not alive or in_bubble or is_ghost:
		return
	action = "throw"
	throw_ticks = 6
	anim_tick = 0
	set_bomber_state(STATE_THROW_BASE + bomber_dir_to_ot_dir(dir), false, true)
	_update_visuals()

func trigger_drill_anim() -> void:
	# From CGOBomber::OnStateTick (0x5A0F75 case 35..38): plays drill then returns to Stop
	if not alive or in_bubble or is_ghost:
		return
	action = "drill"
	set_bomber_state(STATE_DRILL_BASE + bomber_dir_to_ot_dir(dir), false, true)
	_update_visuals()

func start_slide(slide_dir: int, duration_ticks: int = 8, can_fit_callback: Callable = Callable()) -> void:
	# From CGOBomber::OnStateTick (0x5A0F75 case 27..30 / 39..42) & 0x593737/0x59E23F: fixed 10 px/tick slide until blocked
	if not alive or in_bubble or is_ghost:
		return
	dir = clampi(slide_dir, 0, 3)
	slide_ticks = 999 if (duration_ticks <= 0 and can_fit_callback.is_valid()) else maxi(1, duration_ticks)
	_slide_can_fit_cb = can_fit_callback
	var ot_d: int = bomber_dir_to_ot_dir(dir)
	if mount != null:
		action = "slide_ride"
		set_bomber_state(STATE_SLIDE_RIDE_BASE + ot_d, true, true)
	else:
		action = "slide_jump"
		set_bomber_state(STATE_SLIDE_JUMP_BASE + ot_d, true, true)
	_update_visuals()

func enter_ghost_mode() -> void:
	# From sub_59E9D2 (RebirthToGhost) & 0x5A0F75 case 43 -> 51
	if mount != null:
		destroy_mount()
	in_bubble = false
	bubble_state = ""
	alive = true
	is_ghost = true
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	set_bomber_visible(true)
	action = "ghost_in"
	set_bomber_state(STATE_GHOST_IN, false, true)
	_update_visuals()

func exit_ghost_mode() -> void:
	# From 0x5A0F75 case 57: GhostOut -> deactivate
	if not is_ghost:
		return
	action = "ghost_out"
	set_bomber_state(STATE_GHOST_OUT, false, true)
	_update_visuals()

func trigger_tank_shoot_anim() -> void:
	is_shooting = true
	shoot_ticks = 24
	_play_audio("Itm_TankFire")
	_update_visuals()

func move(move_dir: Vector2, delta: float, can_fit_callback: Callable = Callable()) -> void:
	if not alive:
		return

	if in_bubble:
		if move_dir != Vector2.ZERO:
			if abs(move_dir.x) > abs(move_dir.y):
				dir = 3 if move_dir.x > 0 else 2
			else:
				dir = 0 if move_dir.y > 0 else 1
			# Slow crawl: 1 px per 2 ticks = 16.67 px/s (CA.exe 0x5A0F75 case 52..55)
			set_bomber_state(STATE_LOCKED_IN_MOVE_BASE + bomber_dir_to_ot_dir(dir), true)
			var slow_step: float = 16.67 * delta
			var target_pos: Vector2 = position + move_dir * slow_step
			if not can_fit_callback.is_valid() or can_fit_callback.call(target_pos, player_id):
				position = target_pos
				_update_grid_cell()
		else:
			set_bomber_state(STATE_LOCKED_IN_STOP, true)
		return

	if is_ghost:
		if action == "ghost_in" or action == "ghost_out":
			return
		if move_dir == Vector2.ZERO:
			action = "ghost_stop"
			_update_visuals()
			return
		action = "ghost_walk"
		if abs(move_dir.x) > abs(move_dir.y):
			dir = 3 if move_dir.x > 0 else 2
		else:
			dir = 0 if move_dir.y > 0 else 1
		# Half speed in Ghost mode (0x5A0F75 case 44..47: max(1, speed / 2))
		var g_speed: int = maxi(1, int(get_effective_speed() / 2))
		var g_step: float = CBomberAttrScript.speed_to_pixels_per_sec(g_speed) * delta
		var g_target: Vector2 = position + move_dir * g_step
		if not can_fit_callback.is_valid() or can_fit_callback.call(g_target, player_id):
			position = g_target
			_update_grid_cell()
		_update_visuals()
		return

	if slide_ticks > 0 or action == "drill":
		return

	if start_ticks > 0:
		return

	if ship_dismount_ticks > 20:
		return # Midair dismount bounce

	if (is_devil or reverse_dir_ticks > 0) and move_dir != Vector2.ZERO:
		move_dir = -move_dir

	if move_dir == Vector2.ZERO:
		_sync_mount_move_sfx(false)
		if action != "start" and action != "throw" and action != "die" and action != "hurrah":
			idle_ticks += 1
			action = "blink" if idle_ticks >= 100 else "idle"
		anim_tick = 0
		_update_visuals()
		return

	_sync_mount_move_sfx(true)
	idle_ticks = 0
	if action != "start" and action != "hurrah":
		action = "walk"

	# Update direction
	if abs(move_dir.x) > abs(move_dir.y):
		dir = 3 if move_dir.x > 0 else 2 # Right / Left
	else:
		dir = 0 if move_dir.y > 0 else 1 # Down / Up

	var step_speed: float = go_ship.get_pixels_per_sec(on_special_ground) if (go_ship != null and go_ship.is_valid()) else CBomberAttrScript.speed_to_pixels_per_sec(get_effective_speed())
	var step: float = step_speed * delta
	var target_pos: Vector2 = position + move_dir * step

	if not can_fit_callback.is_valid() or can_fit_callback.call(target_pos, player_id):
		position = target_pos
	else:
		# Corner Sliding Assist (GAME_PLAN.md §5.1 / CA.exe corner assist)
		if move_dir.y != 0:
			var nearest_col := roundf((position.x - map_origin.x) / float(CELL_SIZE))
			var col_center := map_origin.x + nearest_col * float(CELL_SIZE)
			var offset_x: float = col_center - position.x
			if absf(offset_x) > 1.5 and absf(offset_x) < 19.0:
				var slide_pos := position + Vector2(signf(offset_x) * step * 0.85, 0)
				if can_fit_callback.call(slide_pos, player_id):
					position = slide_pos
		elif move_dir.x != 0:
			var nearest_row := roundf((position.y - map_origin.y - 39.0) / float(CELL_SIZE))
			var row_center := map_origin.y + nearest_row * float(CELL_SIZE) + 39.0
			var offset_y: float = row_center - position.y
			if absf(offset_y) > 1.5 and absf(offset_y) < 19.0:
				var slide_pos := position + Vector2(0, signf(offset_y) * step * 0.85)
				if can_fit_callback.call(slide_pos, player_id):
					position = slide_pos

	_update_grid_cell()
	_update_visuals()

func _update_grid_cell() -> void:
	# Match sub_449C1D: grid cell = ((x + 20) / 40, (y - 15) / 40).
	var bomb_cell := get_bomb_placement_cell()
	var new_col := bomb_cell.x
	var new_row := bomb_cell.y
	new_col = clampi(new_col, 0, 14)
	new_row = clampi(new_row, 0, 12)
	if new_col != cell.x or new_row != cell.y:
		var old := cell
		cell = Vector2i(new_col, new_row)
		if cell != _placed_trap_cell:
			_placed_trap_cell = Vector2i(-1, -1) # Clear self-trap immunity on leaving cell (0x5A6244 @ 0x5a6d9f)
		cell_changed.emit(old, cell)

	_update_visuals()

func get_effective_bomb_capacity() -> int:
	# CA.exe: CBombOwner::sub_43866E (line 74279) - if m_fAbTank != 0, return bombs_max
	if m_fAbTank:
		return bombs_max
	return bombs_cur

func request_place_bomb() -> bool:
	if not alive or in_bubble or start_ticks > 0:
		return false
	if active_bombs >= get_effective_bomb_capacity():
		return false
	var place_cell := get_bomb_placement_cell()
	bomb_requested.emit(self, place_cell.x, place_cell.y)
	return true

func equip_mount(mount_id: String) -> bool:
	# From sub_5992A0 (CGOBomber::RideShip): refuse if dead or already riding a ship
	if not alive or mount != null or (go_ship != null and go_ship.is_valid()):
		return false

	var ship_res: CShipAttrClass = CItemAttrClass.get_ship_resource(mount_id)
	if ship_res == null:
		ship_res = CShipAttrClass.new()
		ship_res.ship_name = mount_id
		ship_res.short_name = mount_id.substr(5) if mount_id.begins_with("Ship/") else mount_id
	go_ship.init_ship(ship_res)
	mount = go_ship.to_mount_dict()
	set_ab_not_eat_item(ship_res.ab_not_eat_item)
	set_ab_pass_box(ship_res.ab_pass_box)
	m_fAbTank = ship_res.ab_tank
	is_shooting = false
	ship_ride_count = CGOShipClass.MOUNT_TICKS
	if ship_res.ab_tank:
		_play_audio("Itm_TankRide")
	else:
		_play_audio("Obj_ItemShip00")
	_update_visuals()
	return true

func destroy_mount() -> void:
	# From sub_59937D (CGOBomber::UnrideShip), sub_59F248 (TakeOffShip) & sub_89C49E (RemoveShipAbilities)
	if mount == null and (go_ship == null or not go_ship.is_valid()):
		return
	_dismount_ship_sprite_path = go_ship.get_sprite_path(dir, false) if (go_ship != null and go_ship.is_valid()) else ""
	if go_ship != null:
		go_ship.clear()
	mount = null
	set_ab_not_eat_item(false)
	set_ab_pass_box(false)
	m_fAbTank = false
	is_shooting = false
	ship_ride_count = 0
	ship_dismount_ticks = CGOShipClass.DISMOUNT_TICKS
	action = "stop_ride"
	_sync_mount_move_sfx(false)
	_play_audio("Obj_ItemShip01")
	_update_visuals()

func trigger_kart_boost() -> bool:
	# From sub_5BCBB5 / sub_5BC639: Ctrl/E quick action triggers Kart Nitro boost (2x speed for 12 ticks)
	if not alive or in_bubble or go_ship == null or not go_ship.is_kart():
		return false
	if not go_ship.trigger_kart_boost():
		return false
	_play_audio("Itm_KartNitro")
	return true

func shoot_tank() -> bool:
	if not alive or in_bubble:
		return false
	if mount == null or not m_fAbTank:
		return false
	if shoot_cooldown > 0.0:
		return false

	shoot_cooldown = 0.4
	trigger_tank_shoot_anim()
	var d: Vector2 = DIR_VECTORS[dir]
	var start_pos := get_center() + d * 20.0
	tank_shot.emit(start_pos, d, player_id)
	return true

func trap_in_bubble() -> void:
	if not alive or in_bubble:
		return
	if shield_ticks > 0:
		shield_ticks = 0
		_play_audio("Wave/Release")
		return
	if mount != null:
		destroy_mount()
		return

	_sync_mount_move_sfx(false)
	in_bubble = true
	bubble_state = "lock"
	bubble_elapsed_ticks = 0
	bubble_anim_ticks = 0
	bubble_ticks = BUBBLE_TOTAL_TICKS
	action = "faint"
	item_box.on_trapped_in_bubble() # Auto-select Needle family -> Oxygen (0x59E53F / 0x59B51B)
	_play_audio("Wave/LockedIn")
	trapped.emit(self)
	_update_visuals()

func use_needle() -> bool:
	if not alive or not in_bubble:
		return false
	if item_box.consume_needle().is_empty():
		return false
	rescue()
	return true

func rescue() -> void:
	if not alive or not in_bubble:
		return
	in_bubble = false
	bubble_state = "live"
	bubble_anim_ticks = 0
	action = "idle"
	rescue_invuln_ticks = 33 # 1.0s invulnerability (sub_44A18B)
	_play_audio("Wave/Release")
	rescued.emit(self)
	_update_visuals()

func cheer() -> void:
	if not alive:
		return
	action = "hurrah"
	hurrah_ticks = 0
	_update_visuals()

func pop_kill() -> void:
	if not alive:
		return
	if in_bubble:
		bubble_state = "kill"
		bubble_anim_ticks = 0
	in_bubble = false
	alive = false
	action = "die"
	die_ticks = 0
	anim_frame = 0
	set_bomber_state(STATE_DIE, false, true)
	_play_audio("Wave/Die")
	died.emit(self)
	_update_visuals()

func apply_item(code: String) -> void:
	if code.contains("Bomb") and not code.contains("Missile") and not code.contains("Hollow"):
		bombs_cur = mini(bombs_cur + 1, bombs_max)
	elif code.contains("Fire"):
		power_cur = mini(power_cur + 1, power_max)
	elif code.contains("Roller"):
		speed = mini(speed + 1, speed_max)
	elif code.contains("MaxPower"):
		power_cur = power_max
	elif code.contains("Shoe"):
		can_kick = true
	elif code.contains("Punch"):
		can_punch = true
	elif code.contains("RedDevil"): # RedDevil buff: +3 speed + kick bomb (sub_5879D9)
		can_kick = true
		speed = mini(speed + 3, speed_max)
	elif code.contains("Skeleton0"):
		auto_bomb_ticks = 144
	elif code.contains("Skeleton1"):
		reverse_dir_ticks = 144
		devil_ticks = 144
	elif code.contains("Skeleton"):
		reverse_dir_ticks = 144
		devil_ticks = 144
	elif code.contains("Turtle0"):
		equip_mount("Turtle0")
	elif code.contains("Turtle1"):
		equip_mount("Turtle1")
	elif code.contains("Octopus0"):
		equip_mount("Octopus0")
	elif code.contains("Octopus1"):
		equip_mount("Octopus1")
	elif code.contains("Owl"):
		equip_mount("Owl")
	elif code.contains("Kart"):
		equip_mount("Kart")
	elif code.contains("AirshipBroken"):
		equip_mount("AirshipBroken")
	elif code.contains("Airship"):
		equip_mount("Airship")
	elif code.contains("Tank"):
		equip_mount("Tank")
	elif code.contains("Can"): # Lon tăng lực: upgrade Turtle0 -> Turtle1, Octopus0 -> Octopus1
		if mount != null:
			var m_short: String = str(mount.get("short_name", mount.get("id", "")))
			if m_short == "Turtle0":
				go_ship.clear()
				mount = null
				equip_mount("Turtle1")
			elif m_short == "Octopus0":
				go_ship.clear()
				mount = null
				equip_mount("Octopus1")
	elif code.contains("Spanner"): # Cờ-lê: upgrade AirshipBroken -> Airship
		if mount != null:
			var m_short: String = str(mount.get("short_name", mount.get("id", "")))
			if m_short == "AirshipBroken":
				go_ship.clear()
				mount = null
				equip_mount("Airship")
	elif code.contains("RailCar"):
		equip_mount("RailCar")
	elif code.contains("Chicken"):
		equip_mount("Chicken")
	elif code.contains("Nitro"):
		if mount != null and mount.get("is_kart", false):
			go_ship.speed_override = 10
			mount["speed"] = 10
			kart_nitro_ticks = 300
	elif code.contains("Dart"):
		item_box.add_item("Item/ItemDart", 3, 21, 0, "Item/Dart")
	elif code.contains("Banana8") or code.contains("Banana03"):
		item_box.add_item("Banana8", 8, 11, 3, "Item/Banana00")
	elif code.contains("Banana3") or code.contains("Banana02"):
		item_box.add_item("Banana3", 3, 11, 3, "Item/Banana00")
	elif code.contains("Banana2") or code.contains("Banana01"):
		item_box.add_item("Banana2", 2, 11, 3, "Item/Banana00")
	elif code.contains("Banana"):
		item_box.add_item("Banana1", 1, 11, 3, "Item/Banana00")
	elif code.contains("Bond"):
		item_box.add_item("Item/ItemBond", 3, 11, 1, "Item/Bond")
	elif code.contains("ItemTrap") or code == "Trap":
		item_box.add_item("Item/ItemTrap", 2, 11, 2, "Item/Trap")
	elif code == "Pin" or code.contains("Pushpin"):
		item_box.add_item("Pin", 3, 11, 4, "Item/Pushpin")
	elif code.contains("Needle") or code.contains("Niddle"):
		item_box.add_item(code if code.begins_with("Item/") else "Item/ItemNiddle", 1, 23, 0, "Item/Niddle")
	elif code.contains("Oxygen"):
		item_box.add_item("Item/ItemOxygen", 1, 22, 0, "Item/Oxygen")
	elif code.contains("Shield"):
		shield_ticks = 300
	elif code.contains("Camouflage") or code.contains("Mask"):
		camouflage_ticks = 244
	elif code.contains("Hollow"):
		hollow_ticks = 244
	elif code.contains("Potion"):
		auto_bomb_ticks = 0
		reverse_dir_ticks = 0
		devil_ticks = 0
		modulate = Color.WHITE

func try_fire_dart() -> Node:
	if not alive or in_bubble:
		return null
	if item_box.consume_by_type(21).is_empty():
		return null
	var dart = preload("res://scripts/objects/cgo_dart.gd").new()
	dart.setup(self, position, dir, map_origin)
	return dart

func peek_ground_trap() -> int:
	if not alive or in_bubble or is_ghost:
		return 0
	return item_box.peek_ground_trap()

func consume_ground_trap(trap_type: int) -> bool:
	return not item_box.consume_by_type(11, trap_type).is_empty()

func get_quick_item_hud() -> Dictionary:
	# Returns {sprite: String, count: int} for the 1P/2P Ctrl quick-item slot (Game/ItemBox01)
	if not alive:
		return {}
	return item_box.get_quick_hud_info(in_bubble)

func get_inventory_slots() -> Array[Dictionary]:
	# 6 personal HUD slots (keys 1..6 on Game/GameStageItem)
	return item_box.get_personal_bar_slots()

func _on_tick() -> void:
	if alive:
		if ship_ride_count > 0:
			ship_ride_count -= 1
			# CA.exe sub_5A6244 (0x5a6811..0x5a691a): pull smoothly towards tile center at 4 px/tick & animate -16px mount arc
			var center_pos := map_origin + Vector2(float(cell.x * CELL_SIZE), float(cell.y * CELL_SIZE + 39))
			position = position.move_toward(center_pos, 4.0)
			_update_visuals()
		if rescue_invuln_ticks > 0:
			rescue_invuln_ticks -= 1
		if ship_dismount_ticks > 0:
			ship_dismount_ticks -= 1
			var blink: bool = ((ship_dismount_ticks / 3) % 2) == 0
			modulate.a = 0.35 if blink else 1.0
			if ship_dismount_ticks <= 0:
				_dismount_ship_sprite_path = ""
				if action == "stop_ride":
					action = "idle"
				modulate.a = 1.0
			_update_visuals()
		if shield_ticks > 0:
			shield_ticks -= 1
		if bond_ticks > 0:
			bond_ticks -= 1
		if devil_ticks > 0:
			devil_ticks -= 1
		if auto_bomb_ticks > 0:
			auto_bomb_ticks -= 1
			if auto_bomb_ticks % 6 == 0:
				request_place_bomb()
		if reverse_dir_ticks > 0:
			reverse_dir_ticks -= 1
		if camouflage_ticks > 0:
			camouflage_ticks -= 1
			if is_instance_valid(name_lbl):
				name_lbl.visible = false
			if camouflage_ticks <= 0 and is_instance_valid(name_lbl):
				name_lbl.visible = true
		if hollow_ticks > 0:
			hollow_ticks -= 1
		if kart_nitro_ticks > 0:
			kart_nitro_ticks -= 1
			if kart_nitro_ticks <= 0 and mount != null and mount.get("is_kart", false):
				go_ship.speed_override = -1
				mount["speed"] = 5

		# Purple flash for skeleton debuffs (sub_44769A: timer % 6 < 3)
		var debuff_ticks := maxi(auto_bomb_ticks, maxi(reverse_dir_ticks, devil_ticks))
		if debuff_ticks > 0:
			var purple_on: bool = (debuff_ticks % 6) < 3
			modulate = Color(0.85, 0.45, 1.0, 1.0) if purple_on else Color.WHITE
		elif ship_dismount_ticks <= 0 and start_ticks <= 0 and die_ticks <= 0:
			if camouflage_ticks > 0:
				modulate = Color(1.0, 1.0, 1.0, 0.35)
			elif hollow_ticks > 0:
				modulate = Color(1.0, 1.0, 1.0, 0.5)
			else:
				modulate = Color.WHITE

		if go_ship != null and go_ship.is_valid():
			go_ship.tick_ship()
		# Step ObjectTable 30ms fixed-tick animation player (sub_58DF45)
		if step_bomber_state_tick():
			_update_visuals()
		if action == "walk":
			anim_tick += 1
			if anim_tick >= 3:
				anim_tick = 0
				anim_frame += 1
				_update_visuals()
		if is_shooting:
			shoot_ticks -= 1
			if shoot_ticks <= 0:
				is_shooting = false
				_update_visuals()
		if in_bubble:
			bubble_elapsed_ticks += 1
			bubble_ticks = maxi(BUBBLE_TOTAL_TICKS - bubble_elapsed_ticks, 0)
			if bubble_state == "lock":
				if bubble_elapsed_ticks >= BUBBLE_TOTAL_TICKS:
					if oxygen_count > 0:
						oxygen_count -= 1
						bubble_elapsed_ticks = 0
						bubble_ticks = BUBBLE_TOTAL_TICKS
						_play_audio("Wave/Release")
						_update_visuals()
					else:
						pop_kill()
				else:
					_update_visuals()
		elif bubble_state == "live":
			bubble_anim_ticks += 1
			if bubble_anim_ticks >= 12:
				bubble_state = ""
				if is_instance_valid(sp_bubble):
					sp_bubble.visible = false
			_update_visuals()
		elif bubble_state == "kill":
			bubble_anim_ticks += 1
			if bubble_anim_ticks >= 12:
				bubble_state = ""
				if is_instance_valid(sp_bubble):
					sp_bubble.visible = false
			_update_visuals()
		elif action == "ghost_in":
			if state_finished:
				action = "ghost_stop"
				dir = 0
				set_bomber_state(STATE_GHOST_STOP_BASE + 3, true)
				_update_visuals()
		elif action == "ghost_out":
			if state_finished:
				is_ghost = false
				alive = false
				set_bomber_visible(false)
				_update_visuals()
		elif slide_ticks > 0:
			const DIR_VECS: Array[Vector2] = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
			var next_slide_pos: Vector2 = position + DIR_VECS[clampi(dir, 0, 3)] * 10.0 # Fixed 10 px/tick (0x5A0F75)
			if _slide_can_fit_cb.is_valid() and not _slide_can_fit_cb.call(next_slide_pos, player_id):
				slide_ticks = 0
				_slide_can_fit_cb = Callable()
				action = "idle"
			else:
				position = next_slide_pos
				_update_grid_cell()
				slide_ticks -= 1
				if slide_ticks <= 0:
					_slide_can_fit_cb = Callable()
					action = "idle"
			_update_visuals()
		elif action == "drill":
			if state_finished:
				action = "idle"
				set_bomber_state(get_state_finish_transition(cur_state_idx), true)
				_update_visuals()
		elif throw_ticks > 0:
			throw_ticks -= 1
			if throw_ticks <= 0 and action == "throw":
				action = "idle"
			_update_visuals()
		elif start_ticks > 0:
			start_ticks -= 1
			anim_frame += 1
			var blink: bool = ((start_ticks / 5) % 2) == 0
			modulate.a = 0.35 if blink else 1.0
			if start_ticks <= 0:
				action = "idle"
				modulate.a = 1.0
				if is_instance_valid(sp_indicator):
					sp_indicator.visible = false
			_update_visuals()
		elif action == "hurrah":
			hurrah_ticks += 1
			_update_visuals()
		elif action == "blink":
			if state_finished:
				action = "idle"
				idle_ticks = 0
				anim_frame = 0
				_update_visuals()
	else:
		if action == "die":
			die_ticks += 1
			step_bomber_state_tick()
			if die_ticks >= 92:
				if ghost_rebirth_enabled:
					enter_ghost_mode()
					return
				if die_ticks < 132:
					var blink: bool = (((die_ticks - 92) / 5) % 2) == 0
					modulate.a = 0.2 if blink else 1.0
				else:
					visible = false
					modulate.a = 0.0
					if is_instance_valid(shadow):
						shadow.visible = false
					if is_instance_valid(name_lbl):
						name_lbl.visible = false
			else:
				modulate.a = 1.0
			_update_visuals()

func _on_update(delta: float) -> void:
	if shoot_cooldown > 0.0:
		shoot_cooldown = maxf(shoot_cooldown - delta, 0.0)

static func _get_mount_sprite_path(mount_id: String, d: int, shooting := false, kart_boost := false) -> String:
	var dirs_capital: Array[String] = ["-Down", "-Up", "-Left", "-Right"]
	var dirs_lower: Array[String] = ["_down", "_up", "_left", "_right"]
	var dirs_kart: Array[String] = ["_Down", "_Up", "_Left", "_Right"]
	var clean_id := mount_id.substr(5) if mount_id.begins_with("Ship/") else mount_id
	if clean_id == "Tank" or clean_id == "MonS2Tank":
		var suffix: String = dirs_lower[d]
		if shooting:
			suffix += "_shooting"
		return "Ship/Tank" + suffix
	elif clean_id.begins_with("Kart"):
		if kart_boost:
			return "Ship/KartBoost" + dirs_kart[d]
		return "Ship/Kart" + dirs_kart[d]
	elif clean_id == "Chicken":
		return "Ship/Chicken_Box00" + dirs_capital[d]
	else:
		return "Ship/" + clean_id + dirs_capital[d]

func _update_visuals() -> void:
	z_index = 2 + cell.y
	if not is_bomber_visible():
		# From sub_5A700B @ 0x5a70f3 (vtable[117] sub_59F107): skip rendering when hidden
		if is_instance_valid(shadow): shadow.visible = false
		if is_instance_valid(sp_mount): sp_mount.visible = false
		if is_instance_valid(sp_static): sp_static.visible = false
		if is_instance_valid(sp_adjust): sp_adjust.visible = false
		if is_instance_valid(sp_bubble): sp_bubble.visible = false
		if is_instance_valid(sp_indicator): sp_indicator.visible = false
		if is_instance_valid(name_lbl): name_lbl.visible = false
		_hide_cosmetics(false)
		return
	if is_instance_valid(name_lbl) and alive:
		name_lbl.visible = true
	var sdb: Object = _get_sprite_db()
	if sdb == null:
		return

	# Draw shadow
	var sh_data: Dictionary = sdb.get_frame("Shadow/Shadow", 0)
	if not sh_data.is_empty():
		shadow.visible = not in_bubble and alive
		shadow.texture = sh_data.texture
		shadow.position = -sh_data.offset

	# Bubble trapped visual
	if in_bubble or action == "faint" or bubble_state == "live" or bubble_state == "kill":
		sp_static.visible = true
		sp_adjust.visible = true
		sp_mount.visible = false
		sp_bubble.visible = true

		if action != "die":
			var fcf: Dictionary = sdb.get_character_frame(char_prefix, "Die", 0)
			if fcf.is_empty():
				fcf = sdb.get_character_frame(char_prefix, "Faint", 0)
			if not fcf.is_empty():
				sp_static.texture = fcf.static_texture
				sp_static.position = -fcf.offset
				sp_adjust.texture = fcf.adjust_texture
				sp_adjust.position = -fcf.offset
			else:
				sp_static.texture = null
				sp_adjust.texture = null

		var b_frame: int = 6
		if bubble_state == "live":
			b_frame = 6 + mini(bubble_anim_ticks / 4, 2)
			sp_bubble.modulate = Color(1.0, 1.0, 1.0)
		elif bubble_state == "kill":
			b_frame = 3 + mini(bubble_anim_ticks / 4, 2)
			sp_bubble.modulate = Color(1.0, 1.0, 1.0)
		else: # "lock"
			if bubble_elapsed_ticks < 4:
				b_frame = 0
			elif bubble_elapsed_ticks < 8:
				b_frame = 1
			elif bubble_elapsed_ticks < 12:
				b_frame = 2
			else:
				b_frame = 6

			if bubble_elapsed_ticks > 150:
				var dark: float = 1.0 - 0.45 * float(bubble_elapsed_ticks - 150) / 50.0
				sp_bubble.modulate = Color(dark, dark, dark)
			else:
				sp_bubble.modulate = Color(1.0, 1.0, 1.0)

		var bf: Dictionary = sdb.get_frame("Bomb/Bubble00", b_frame)
		if not bf.is_empty():
			sp_bubble.texture = bf.texture
			sp_bubble.position = -bf.offset

		name_lbl.position = Vector2(0, -42)
		_hide_cosmetics(true)
		_update_id_deco_visual(sdb)
		if action != "die":
			return

	sp_bubble.visible = false

	# Mount / Riding visual
	if mount != null:
		sp_mount.visible = true
		sp_static.visible = true
		sp_adjust.visible = true

		var mount_id: String = str(mount.get("short_name", mount.get("id", "")))
		var is_kart_boost: bool = go_ship != null and go_ship.is_valid() and go_ship.kart_boosting
		var mount_path := _get_mount_sprite_path(mount_id, dir, is_shooting, is_kart_boost)
		var mf_idx: int = 0
		if is_shooting:
			mf_idx = mini((24 - shoot_ticks) / 4, 5)
		elif is_kart_boost:
			mf_idx = mini((CGOShipClass.KART_BOOST_TICKS - go_ship.kart_boost_ticks) / 3, 3)
		elif action == "walk":
			if mount_id.begins_with("Tank") or mount_id.begins_with("Kart"):
				mf_idx = (anim_frame / 3) % 6
			else:
				const PING_PONG := [0, 1, 2, 3, 2, 1]
				mf_idx = PING_PONG[(anim_frame / 3) % 6]

		var mf: Dictionary = sdb.get_frame(mount_path, mf_idx)
		if not mf.is_empty():
			sp_mount.texture = mf.texture
			sp_mount.position = -mf.offset

		var ot_d: int = bomber_dir_to_ot_dir(dir)
		set_bomber_state((STATE_RIDE_BASE + ot_d) if action == "walk" else (STATE_STOP_RIDE_BASE + ot_d), true)
		var r_sf: Dictionary = get_bomber_state_frame()
		var r_act: String = str(r_sf.get("action", "Ride" + str(DIR_NAMES[dir])))
		var rf_idx: int = int(r_sf.get("frame", 0))
		var arc_dy: float = float(get_ship_jump_arc_dy(ship_ride_count)) if ship_ride_count > 0 else 0.0
		var rcf: Dictionary = sdb.get_character_frame(char_prefix, r_act, rf_idx)
		if not rcf.is_empty():
			sp_static.texture = rcf.static_texture
			sp_static.position = -rcf.offset + Vector2(0.0, arc_dy)
			sp_adjust.texture = rcf.adjust_texture
			sp_adjust.position = -rcf.offset + Vector2(0.0, arc_dy)
		else:
			sp_static.texture = null
			sp_adjust.texture = null

		name_lbl.position = Vector2(0, -50)
		_update_cosmetics_visuals(sdb, cur_state_idx, rf_idx, arc_dy)
		return

	# Dismounting ship blink visibility (sub_59923A: c = -ship_dismount_ticks)
	if ship_dismount_ticks > 0 and _dismount_ship_sprite_path != "":
		var dismount_c: int = -ship_dismount_ticks
		var ship_vis: bool = is_ship_visible_for_ride_count(dismount_c)
		sp_mount.visible = ship_vis
		if ship_vis:
			var dmf: Dictionary = sdb.get_frame(_dismount_ship_sprite_path, 0)
			if not dmf.is_empty():
				sp_mount.texture = dmf.texture
				sp_mount.position = -dmf.offset
	else:
		sp_mount.visible = false
	name_lbl.position = Vector2(0, -42)

	# Indicator above head during start countdown
	if is_instance_valid(sp_indicator):
		if start_ticks > 0 and alive and not in_bubble:
			sp_indicator.visible = true
			var ind_path := "Game/StartIndicator1P_LayerAdjust" if player_id == 0 else "Game/StartIndicator2P_LayerAdjust"
			var ind_f: Dictionary = sdb.get_frame(ind_path, (anim_frame / 2) % 8)
			if not ind_f.is_empty():
				sp_indicator.texture = ind_f.texture
				sp_indicator.position = Vector2(20, -58)
		else:
			sp_indicator.visible = false

	# Action sprite resolution (on foot) via ObjectTable 90-state player (sub_58DF45)
	sp_static.visible = true
	sp_adjust.visible = true
	var ot_d: int = bomber_dir_to_ot_dir(dir)
	_resolve_on_foot_state(ot_d)

	var sf: Dictionary = get_bomber_state_frame()
	var sprite_path: String = str(sf.get("sprite", ""))
	var act_name: String = str(sf.get("action", "Walk" + str(DIR_NAMES[dir])))
	var f_idx: int = int(sf.get("frame", 0))

	var dismount_dy: float = float(get_ship_jump_arc_dy(-ship_dismount_ticks)) if ship_dismount_ticks > 0 else 0.0
	if sprite_path != "" and not sprite_path.begins_with("Character/"):
		# Non-character sprites (e.g. StaticChar/Hedgehog-*) are single-layer frames
		var raw_f: Dictionary = sdb.get_frame(sprite_path, f_idx)
		sp_adjust.visible = false
		sp_adjust.texture = null
		if not raw_f.is_empty():
			sp_static.texture = raw_f.texture
			sp_static.position = -raw_f.offset + Vector2(0.0, dismount_dy)
		else:
			sp_static.texture = null
	else:
		var cf: Dictionary = sdb.get_character_frame(char_prefix, act_name, f_idx)
		if not cf.is_empty():
			sp_static.texture = cf.static_texture
			sp_static.position = -cf.offset + Vector2(0.0, dismount_dy)
			sp_adjust.texture = cf.adjust_texture
			sp_adjust.position = -cf.offset + Vector2(0.0, dismount_dy)
		else:
			sp_static.texture = null
			sp_adjust.texture = null
	_update_cosmetics_visuals(sdb, cur_state_idx, f_idx, dismount_dy)

func _hide_cosmetics(keep_id_deco: bool = false) -> void:
	if is_instance_valid(sp_char_deco):
		sp_char_deco.visible = false
	for sp: Sprite2D in _deco_adjust_nodes:
		if is_instance_valid(sp):
			sp.visible = false
	for sp: Sprite2D in _deco_static_nodes:
		if is_instance_valid(sp):
			sp.visible = false
	if not keep_id_deco and is_instance_valid(sp_id_deco):
		sp_id_deco.visible = false

func _update_id_deco_visual(sdb: Object) -> void:
	if not is_instance_valid(sp_id_deco):
		return
	var id_path: String = cosmetics.id_deco if cosmetics.id_deco != "" else equipped_id_deco
	if id_path == "" or not is_instance_valid(name_lbl) or not name_lbl.visible:
		sp_id_deco.visible = false
		return
	var norm_id: String = id_path if id_path.begins_with("IDDeco/") else "IDDeco/" + id_path
	var f: Dictionary = sdb.get_frame(norm_id, 0)
	if f.is_empty():
		sp_id_deco.visible = false
		return
	sp_id_deco.visible = true
	sp_id_deco.texture = f.texture
	var id_y: float = -76.0 if mount == null else -84.0
	sp_id_deco.position = Vector2(20.0, id_y)
	name_lbl.position = Vector2(0.0, id_y - name_lbl.size.y * 0.5)

func _update_cosmetics_visuals(sdb: Object, state_idx: int, base_frame_idx: int, dy_offset: float) -> void:
	_update_id_deco_visual(sdb)
	# CharDeco overlay (hidden in bubble, ghost, dead, or hedgehog transform)
	if is_instance_valid(sp_char_deco):
		var cd_path: String = cosmetics.char_deco if cosmetics.char_deco != "" else equipped_char_deco
		if cd_path == "" or not alive or in_bubble or is_ghost or is_hedgehog_state(state_idx):
			sp_char_deco.visible = false
		else:
			var norm_cd: String = cd_path if cd_path.begins_with("CharDeco/") else "CharDeco/" + cd_path
			var cf: Dictionary = sdb.get_frame("%s%s" % [norm_cd, DIR_NAMES[clampi(dir, 0, 3)]], 0)
			if cf.is_empty():
				cf = sdb.get_frame(norm_cd, 0)
			if not cf.is_empty():
				sp_char_deco.visible = true
				sp_char_deco.texture = cf.texture
				sp_char_deco.position = -cf.offset + Vector2(0.0, dy_offset)
			else:
				sp_char_deco.visible = false

	# 13-slot AvatarDeco (0x5C9741 / 0x8D5463: exact 90-state -> 44-frame lookup)
	var mapping: Dictionary = CGOBomberCosmeticsClass.resolve_avatar_deco_frame(state_idx, base_frame_idx)
	if mapping.is_empty() or not cosmetics.has_any_avatar_deco():
		for sp: Sprite2D in _deco_adjust_nodes:
			if is_instance_valid(sp): sp.visible = false
		for sp: Sprite2D in _deco_static_nodes:
			if is_instance_valid(sp): sp.visible = false
		return

	var sheet_idx: int = int(mapping["sheet_idx"])
	var deco_frame: int = int(mapping["frame_idx"])
	var active: Array[String] = cosmetics.get_active_slots()
	while _deco_adjust_nodes.size() < active.size():
		var a_sp := Sprite2D.new()
		a_sp.centered = false
		_deco_layer.add_child(a_sp)
		_deco_adjust_nodes.append(a_sp)
		var s_sp := Sprite2D.new()
		s_sp.centered = false
		_deco_layer.add_child(s_sp)
		_deco_static_nodes.append(s_sp)

	for i in range(_deco_adjust_nodes.size()):
		var a_sp: Sprite2D = _deco_adjust_nodes[i]
		var s_sp: Sprite2D = _deco_static_nodes[i]
		if i >= active.size():
			a_sp.visible = false
			s_sp.visible = false
			continue
		var df: Dictionary = sdb.get_avatar_deco_frame(active[i], sheet_idx, deco_frame)
		if df.is_empty():
			a_sp.visible = false
			s_sp.visible = false
			continue
		if df.get("adjust_texture") != null:
			a_sp.visible = true
			a_sp.texture = df["adjust_texture"]
			a_sp.modulate = team_color
			a_sp.position = -Vector2(df["adjust_offset"]) + Vector2(0.0, dy_offset)
		else:
			a_sp.visible = false
		if df.get("static_texture") != null:
			s_sp.visible = true
			s_sp.texture = df["static_texture"]
			s_sp.position = -Vector2(df["static_offset"]) + Vector2(0.0, dy_offset)
		else:
			s_sp.visible = false

func _resolve_on_foot_state(ot_d: int) -> void:
	match action:
		"die":
			set_bomber_state(STATE_DIE, false)
		"throw":
			set_bomber_state(STATE_THROW_BASE + ot_d, false)
		"drill":
			set_bomber_state(STATE_DRILL_BASE + ot_d, false)
		"slide_jump":
			set_bomber_state(STATE_SLIDE_JUMP_BASE + ot_d, true)
		"slide_ride":
			set_bomber_state(STATE_SLIDE_RIDE_BASE + ot_d, true)
		"ghost_in":
			set_bomber_state(STATE_GHOST_IN, false)
		"ghost_walk":
			set_bomber_state(STATE_GHOST_WALK_BASE + ot_d, true)
		"ghost_stop":
			set_bomber_state(STATE_GHOST_STOP_BASE + ot_d, true)
		"ghost_out":
			set_bomber_state(STATE_GHOST_OUT, false)
		"snow_throw":
			set_bomber_state(STATE_SNOW_THROW_BASE + ot_d, false)
		"snow_hit":
			set_bomber_state(STATE_SNOW_HIT, false)
		"snow_dying":
			set_bomber_state(STATE_SNOW_DYING, false)
		"snow_spin":
			set_bomber_state(STATE_SNOW_SPIN_BASE + ot_d, true)
		"hurrah":
			set_bomber_state(STATE_HURRAH, true)
		"start":
			set_bomber_state(STATE_START, false)
		"blink":
			set_bomber_state(STATE_BLINK, false)
		"stop_ride":
			set_bomber_state(STATE_STOP_RIDE_BASE + ot_d, true)
		"walk":
			set_bomber_state(STATE_WALK_BASE + ot_d, true)
		_: # idle
			set_bomber_state(STATE_STOP_BASE + ot_d, true)

func _exit_tree() -> void:
	_sync_mount_move_sfx(false)

func _sync_mount_move_sfx(is_moving: bool) -> void:
	var ml: MainLoop = Engine.get_main_loop()
	if not (ml is SceneTree) or not (ml as SceneTree).root.has_node("AudioManager"):
		return
	var am: Node = (ml as SceneTree).root.get_node("AudioManager")
	var key := "mount_%d" % player_id
	if is_moving and alive and not in_bubble and mount != null:
		if m_fAbTank:
			am.call("play_loop_sfx", key, "Itm_TankMove")
			return
		if bool(mount.get("is_kart", false)):
			am.call("play_loop_sfx", key, "Itm_KartMove")
			return
	am.call("stop_loop_sfx", key)

static func _play_audio(sfx_name: String) -> void:
	var mapped := sfx_name
	match sfx_name:
		"Wave/LockedIn":
			mapped = "Cha_LockedIn"
		"Wave/Release":
			mapped = "Cha_Release"
		"Wave/Die":
			mapped = "Cha_Die"
		"Wave/BombIgnite":
			mapped = "Cha_BombIgnite"
		"Wave/BombExplode":
			mapped = "Cha_BombExplode"
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("AudioManager"):
		(ml as SceneTree).root.get_node("AudioManager").call("play_sfx", mapped)
