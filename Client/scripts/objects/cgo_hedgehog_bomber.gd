class_name CGOHedgehogBomber
extends "res://scripts/objects/cgo_game_bomber.gd"

## Hedgehog mode bomber entity (CA.exe RTTI .?AVCGOHedgehogBomber@@ @ 0xe40b24,
## ctor sub_74A690, dtor sub_74A7A1, reset sub_74A84C, debug dump sub_74A051).
## Implements real Hedgehog transformation (states 58..75), ItemFakeHedgehog (type 41),
## and ItemSuperHedgehog (type 42).

const HEDGEHOG_DEFAULT_SPEED := 4   # sub_74A84C & sub_74A11F
const HEDGEHOG_MAX_SPEED := 6       # sub_74962D: if (a2 + m_nHedgehogSpeed < 7)
const HEDGEHOG_SLIDE_SPEED := 10    # sub_74A414: fixed 10 px/tick during states 71..74
const FAKE_HEDGEHOG_TICKS := 500    # sub_749DD1: 1000 * 15 / 30 = 500 ticks (15s)
const SUPER_HEDGEHOG_TICKS := 33    # sub_749EA1: 33 ticks (~1s)

signal hedgehog_item_dropped(item_code: String, drop_cell: Vector2i)

var m_bIsHedgehog: bool = false             # this[3150] @ +12600 (sub_749AE5)
var m_wImitationHedgehogTime: int = 0       # this[3151] @ +12604
var m_bImitationHedgehog: bool = false      # this[3152] @ +12608
var m_nSuperHedgehogCount: int = 0          # this[3153] @ +12612
var m_nHedgehogSpeed: int = HEDGEHOG_DEFAULT_SPEED # this[3154] @ +12616
var m_vHedgehogEatItems: Array[String] = [] # this[3155..3156]

func is_hedgehog() -> bool:
	return m_bIsHedgehog

func set_hedgehog(enabled: bool) -> void:
	# From sub_749AE5
	m_bIsHedgehog = enabled

func is_hedgehog_faint() -> bool:
	# From sub_749824: state == 60 (Faint) || state == 75 (Struggle)
	return cur_state_idx == STATE_HEDGEHOG_FAINT or cur_state_idx == STATE_HEDGEHOG_STRUGGLE

func can_hedgehog_collide() -> bool:
	# From sub_7491D4 & sub_749824: active Hedgehog not in faint/struggle
	return alive and m_bIsHedgehog and not is_hedgehog_faint()

func check_hedgehog_hitbox(target_rect: Rect2) -> bool:
	# From sub_749B1F: Hedgehog collision check against target rect
	return can_hedgehog_collide() and get_flame_hitbox().intersects(target_rect)

func reset_hedgehog_state() -> void:
	# From sub_74A84C
	m_bIsHedgehog = false
	m_wImitationHedgehogTime = 0
	m_bImitationHedgehog = false
	m_nSuperHedgehogCount = 0
	m_nHedgehogSpeed = HEDGEHOG_DEFAULT_SPEED
	m_vHedgehogEatItems.clear()

func transform_to_hedgehog() -> bool:
	# From sub_74A11F: transform human into real Hedgehog instead of dying
	if not alive or m_bIsHedgehog:
		return false
	if mount != null or (go_ship != null and go_ship.is_valid()):
		destroy_mount()
		ship_dismount_ticks = 0
		_dismount_ship_sprite_path = ""
	in_bubble = false
	bubble_state = ""
	shield_ticks = 0
	devil_ticks = 0
	auto_bomb_ticks = 0
	reverse_dir_ticks = 0
	camouflage_ticks = 0
	hollow_ticks = 0
	kart_nitro_ticks = 0
	rescue_invuln_ticks = 0
	m_bIsHedgehog = true
	m_nHedgehogSpeed = HEDGEHOG_DEFAULT_SPEED
	m_wImitationHedgehogTime = 0
	m_bImitationHedgehog = false
	m_nSuperHedgehogCount = 0
	action = "hedgehog_rebirth"
	super.set_bomber_state(STATE_HEDGEHOG_DIE, false, true)
	_play_audio("Cha_HedgehogRebirth")
	_update_visuals()
	return true

func use_fake_hedgehog(duration_sec: int = 15) -> bool:
	# From sub_749E45 -> sub_749DD1: human-only 15s disguise as Hedgehog
	if not alive or in_bubble or m_bIsHedgehog or m_bImitationHedgehog:
		return false
	m_bImitationHedgehog = true
	m_wImitationHedgehogTime = int((1000 * duration_sec) / 30)
	super.set_bomber_state(STATE_HEDGEHOG_DIE, false, true)
	_play_audio("Cha_HedgehogRebirth")
	_update_visuals()
	return true

func cancel_fake_hedgehog() -> void:
	# From sub_749646 / sub_749F3F / sub_74A8D9
	if not m_bImitationHedgehog and m_wImitationHedgehogTime <= 0:
		return
	m_bImitationHedgehog = false
	m_wImitationHedgehogTime = 0
	super.set_bomber_state(STATE_STOP_BASE + bomber_dir_to_ot_dir(dir), true, true)
	_update_visuals()

func use_super_hedgehog() -> bool:
	# From sub_749EA1 & sub_74962D: real Hedgehog only when speed + 2 <= 7
	if not alive or not m_bIsHedgehog:
		return false
	if m_nHedgehogSpeed + 2 > 7:
		return false
	m_nSuperHedgehogCount = SUPER_HEDGEHOG_TICKS
	if m_nHedgehogSpeed + 2 < 7:
		m_nHedgehogSpeed += 2
	super.set_bomber_state(STATE_HEDGEHOG_STOP_BASE, true, true)
	_play_audio("Itm_UseSuperHedgehog")
	_update_visuals()
	return true

func on_flame_hit_hedgehog() -> bool:
	# From sub_74A8D9: hit while Fake -> reveal human; hit while real Hedgehog -> stun 60->75 & drop 1 item
	if m_bImitationHedgehog:
		cancel_fake_hedgehog()
	if not m_bIsHedgehog:
		return false
	if not is_hedgehog_faint():
		super.set_bomber_state(STATE_HEDGEHOG_FAINT, false, true)
		if not m_vHedgehogEatItems.is_empty():
			var dropped: String = m_vHedgehogEatItems.pop_back()
			hedgehog_item_dropped.emit(dropped, cell)
	m_nSuperHedgehogCount = 0
	_update_visuals()
	return true

func can_eat_item() -> bool:
	# From sub_74970C: while Hedgehog, disallow eating in states 59..62, 71..74, 75, or during SuperHedgehog
	if not m_bIsHedgehog:
		return super.can_eat_item()
	if not alive:
		return false
	if cur_state_idx >= STATE_HEDGEHOG_DIE and cur_state_idx <= STATE_HEDGEHOG_CRY:
		return false
	if cur_state_idx == STATE_HEDGEHOG_STRUGGLE:
		return false
	if cur_state_idx >= STATE_HEDGEHOG_SLIDE_BASE and cur_state_idx <= STATE_HEDGEHOG_SLIDE_BASE + 3:
		return false
	if m_nSuperHedgehogCount > 0:
		return false
	return true

func get_effective_speed(on_special_tile: bool = false) -> int:
	if m_bIsHedgehog:
		if cur_state_idx >= STATE_HEDGEHOG_SLIDE_BASE and cur_state_idx <= STATE_HEDGEHOG_SLIDE_BASE + 3:
			return HEDGEHOG_SLIDE_SPEED
		return m_nHedgehogSpeed
	return super.get_effective_speed(on_special_tile)

func apply_item(code: String) -> void:
	if code.contains("FakeHedgehog"):
		use_fake_hedgehog()
		return
	if code.contains("SuperHedgehog"):
		use_super_hedgehog()
		return
	if m_bIsHedgehog:
		m_vHedgehogEatItems.append(code)
		return
	super.apply_item(code)

func set_bomber_state(state_idx: int, loop: bool = true, force_restart: bool = false) -> void:
	# From sub_749A20: while disguised as FakeHedgehog, remap stop/walk/throw (12..23) to Hedgehog stop (67..70)
	var target: int = state_idx
	if m_wImitationHedgehogTime > 0 or m_bImitationHedgehog:
		if (target >= STATE_STOP_BASE and target <= STATE_STOP_BASE + 3) \
				or (target >= STATE_WALK_BASE and target <= STATE_WALK_BASE + 3):
			target = STATE_HEDGEHOG_STOP_BASE + bomber_dir_to_ot_dir(dir)
			m_bImitationHedgehog = true
		elif m_bImitationHedgehog and target >= STATE_THROW_BASE and target <= STATE_THROW_BASE + 3:
			target = STATE_HEDGEHOG_STOP_BASE + bomber_dir_to_ot_dir(dir)
	super.set_bomber_state(target, loop, force_restart)

func _resolve_on_foot_state(ot_d: int) -> void:
	if m_bImitationHedgehog and cur_state_idx == STATE_HEDGEHOG_DIE and not state_finished:
		return
	if not m_bIsHedgehog:
		super._resolve_on_foot_state(ot_d)
		return
	if cur_state_idx == STATE_HEDGEHOG_DIE or cur_state_idx == STATE_HEDGEHOG_FAINT or cur_state_idx == STATE_HEDGEHOG_STRUGGLE:
		return
	match action:
		"walk":
			super.set_bomber_state(STATE_HEDGEHOG_WALK_BASE + ot_d, true)
		"slide":
			super.set_bomber_state(STATE_HEDGEHOG_SLIDE_BASE + ot_d, true)
		"blink":
			super.set_bomber_state(STATE_HEDGEHOG_BLINK, false)
		"hurrah":
			super.set_bomber_state(STATE_HEDGEHOG_HURRAH, true)
		"cry":
			super.set_bomber_state(STATE_HEDGEHOG_CRY, true)
		_:
			super.set_bomber_state(STATE_HEDGEHOG_STOP_BASE + ot_d, true)

func _on_tick() -> void:
	# From sub_749646: FakeHedgehog countdown + SuperHedgehog spin
	if m_wImitationHedgehogTime > 0:
		m_wImitationHedgehogTime -= 1
	if m_bImitationHedgehog and m_wImitationHedgehogTime <= 0:
		cancel_fake_hedgehog()

	super._on_tick()

	if m_nSuperHedgehogCount > 0:
		var prev: int = m_nSuperHedgehogCount
		m_nSuperHedgehogCount -= 1
		if (prev & 1) == 0:
			var next_ot_dir: int = (bomber_dir_to_ot_dir(dir) + 1) % 4
			# Map ObjectTable dir (0=L,1=U,2=R,3=D) back to CGOBomber dir (0=D,1=U,2=L,3=R)
			const OT_TO_BOMBER_DIR: Array[int] = [2, 1, 3, 0]
			dir = OT_TO_BOMBER_DIR[next_ot_dir]
			super.set_bomber_state(STATE_HEDGEHOG_STOP_BASE + next_ot_dir, true, true)
			_update_visuals()

	# From sub_74A414 (a2 == 2 animation-finish transitions)
	if state_finished:
		if cur_state_idx == STATE_HEDGEHOG_DIE:
			action = "idle"
			super.set_bomber_state(STATE_HEDGEHOG_STOP_BASE + 3, true, true) # 70: WalkDown idle
			_update_visuals()
		elif cur_state_idx == STATE_HEDGEHOG_FAINT:
			super.set_bomber_state(STATE_HEDGEHOG_STRUGGLE, false, true) # 75: Faint struggle (99 ticks)
			_play_audio("Cha_HedgehogStruggle")
			_update_visuals()
		elif cur_state_idx == STATE_HEDGEHOG_STRUGGLE:
			action = "idle"
			super.set_bomber_state(STATE_HEDGEHOG_STOP_BASE + 3, true, true) # 70: WalkDown idle
			_update_visuals()
