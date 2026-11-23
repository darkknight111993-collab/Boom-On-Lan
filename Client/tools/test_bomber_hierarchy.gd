extends SceneTree

const CBomberAttrClass = preload("res://scripts/objects/cbomber_attr.gd")
const CGOBomberBaseClass = preload("res://scripts/objects/cgo_bomber_base.gd")
const CGOBomberClass = preload("res://scripts/objects/cgo_bomber.gd")
const CGOGameBomberClass = preload("res://scripts/objects/cgo_game_bomber.gd")
const CGOHedgehogBomberClass = preload("res://scripts/objects/cgo_hedgehog_bomber.gd")

func _init() -> void:
	print("[TEST] Running Bomber Class Hierarchy tests (TV-B1..TV-B8)...")

	# TV-B1: CBomberAttr C00 (Bazzi)
	var c00: CBomberAttrClass = CBomberAttrClass.get_attr("Character/C00")
	assert(c00 != null, "TV-B1: C00 attr must exist")
	assert(c00.speed_init == 5 and c00.speed_max == 7, "TV-B1: C00 speed 5/7")
	assert(c00.bomb_init == 1 and c00.bomb_max == 10, "TV-B1: C00 bomb 1/10")
	assert(c00.power_init == 1 and c00.power_max == 7, "TV-B1: C00 power 1/7")
	assert(c00.prepare_path == "Prepare/C00", "TV-B1: prepare_path")
	assert(c00.display_path == "Character/C00_Display", "TV-B1: display_path")
	assert(c00.portrait_path == "Character/C00_Portrait", "TV-B1: portrait_path")
	assert(c00.emotion_path == "Character/C00_Emotion", "TV-B1: emotion_path")
	print("  [PASS] TV-B1: CBomberAttr C00 stats & derived paths (0x97124A)")

	# TV-B2: CBomberAttr C01 (short name lookup)
	var c01: CBomberAttrClass = CBomberAttrClass.get_attr("C01")
	assert(c01 != null, "TV-B2: C01 attr must exist")
	assert(c01.speed_init == 4 and c01.speed_max == 8, "TV-B2: C01 speed 4/8")
	assert(c01.bomb_init == 2 and c01.bomb_max == 7, "TV-B2: C01 bomb 2/7")
	assert(c01.power_init == 1 and c01.power_max == 9, "TV-B2: C01 power 1/9")
	print("  [PASS] TV-B2: CBomberAttr C01 short-name lookup")

	# TV-B3: bomb_max hard cap <= 10 (0x9714c5)
	var capped: CBomberAttrClass = CBomberAttrClass.from_dict({
		"name": "Character/TestCap",
		"stats": [0, 5, 8, 2, 15, 1, 7, 10, 100, 9]
	}, 99)
	assert(capped.bomb_max == 10, "TV-B3: bomb_max must be capped at 10 (0x9714c5)")
	print("  [PASS] TV-B3: CBomberAttr bomb_max <= 10 cap (0x9714c5)")

	# TV-B4: Inheritance chain Node2D -> CGameObject -> CGOBomberBase -> CGOBomber -> CGOGameBomber
	var p = CGOGameBomberClass.new()
	assert(p is CGOGameBomberClass, "TV-B4: must be CGOGameBomber")
	assert(p is CGOBomberClass, "TV-B4: must inherit CGOBomber")
	assert(p is CGOBomberBaseClass, "TV-B4: must inherit CGOBomberBase")
	assert(p is Node2D, "TV-B4: must inherit Node2D")
	assert(p.apply_character_attr("C01") == true, "TV-B4: apply_character_attr(C01)")
	assert(p.speed == 4 and p.speed_max == 8 and p.bombs_cur == 2 and p.bombs_max == 7 and p.power_max == 9, "TV-B4: C01 stats applied")
	print("  [PASS] TV-B4: Inheritance chain & apply_character_attr")

	# TV-B5: m_bVisible, in_bush & on_match_event (0x594E07 / 0x59F04D / 0x59F107 / 0x5AE4DA)
	assert(p.is_bomber_visible() == true, "TV-B5: default visible must be true")
	assert(p.is_bomber_visible(true) == false, "TV-B5: hidden_in_bush must return false")
	p.in_bush = true
	assert(p.is_bomber_visible() == false, "TV-B5: in_bush=true must hide bomber")
	p.in_bush = false
	assert(p.is_bomber_visible() == true, "TV-B5: in_bush=false must restore bomber")
	p.set_bomber_visible(false)
	assert(p.get_bomber_visible() == false and p.is_bomber_visible() == false, "TV-B5: set_bomber_visible(false)")
	assert(p.on_match_event(1) == false and p.is_bomber_visible() == false, "TV-B5: non-zero event ignored")
	assert(p.on_match_event(0) == true and p.is_bomber_visible() == true, "TV-B5: event 0 restores visible")
	# Verify sub_59F04D byte +19 concealment rule against real tile_info.json entries
	var tile_info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tile_info.json"))
	assert(CGOBomberBaseClass.is_passable_info_concealing(tile_info["Tile00_Passable/Herb00"]) == true, "TV-B5: Herb00 (byte19=0) must conceal")
	assert(CGOBomberBaseClass.is_passable_info_concealing(tile_info["Tile02_Passble/Icewater00"]) == false, "TV-B5: Icewater00 (byte19=1) must NOT conceal")
	p.map_origin = Vector2(20, 41)
	p.set_cell(2, 3)
	assert(p.get_foot_cell() == Vector2i(2, 3), "TV-B5: foot cell at anchor (2, 3) must be (2, 3)")
	p.position += Vector2(0, 5) # foot crosses into row 4 while body center stays in row 3
	assert(p.get_foot_cell() == Vector2i(2, 4), "TV-B5: foot cell after +5px Y must be (2, 4) (0x59C48A)")
	print("  [PASS] TV-B5: m_bVisible, byte+19 & 2-cell bush concealment & on_match_event (0x594E07, 0x59C48A, 0x59F04D, 0x59F107, 0x5AE4DA)")

	# TV-B6: CGOGameBomber 26-tick (0x1A) multi-bomb cooldown (0x5B19B3)
	assert(p.can_trigger_multi_bomb() == true, "TV-B6: ready initially")
	p.record_multi_bomb_tick()
	for _i in range(25):
		p._on_tick()
		assert(p.can_trigger_multi_bomb() == false, "TV-B6: blocked during 25 ticks")
	p._on_tick()
	assert(p.can_trigger_multi_bomb() == true, "TV-B6: ready on tick 26 (0x1A)")
	print("  [PASS] TV-B6: CGOGameBomber 26-tick (0x1A) action cooldown (0x5B19B3)")

	# TV-B7: CGOBomberBase 90-state ObjectTable animation player (0x58DF45)
	p.load_bomber_states("C00")
	assert(p.ot_states.size() == 90, "TV-B7: C00 must load 90 ObjectTable states (got %d)" % p.ot_states.size())
	# WalkDown = state 22 (STATE_WALK_BASE + OT_DIR_DOWN=2): [[0,3],[1,3],[2,3],[0,3],[3,3],[4,3]]
	p.set_bomber_state(CGOBomberBaseClass.STATE_WALK_BASE + CGOBomberBaseClass.bomber_dir_to_ot_dir(0), true, true)
	var walk_seq: Array[int] = [0, 1, 2, 0, 3, 4]
	for idx in range(walk_seq.size()):
		var f: Dictionary = p.get_bomber_state_frame()
		assert(f["action"] == "WalkDown" and int(f["frame"]) == walk_seq[idx], "TV-B7: WalkDown step %d expected %d, got %s" % [idx, walk_seq[idx], str(f)])
		for _t in range(3):
			p.step_bomber_state_tick()
	# Should wrap cleanly back to frame 0 after 18 ticks
	assert(int(p.get_bomber_state_frame()["frame"]) == 0, "TV-B7: WalkDown must loop back to frame 0")
	# RideDown = state 06: [[0,6],[1,3],[2,3],[3,6],[2,3],[1,3]] (24 ticks ping-pong)
	p.set_bomber_state(CGOBomberBaseClass.STATE_RIDE_BASE + CGOBomberBaseClass.bomber_dir_to_ot_dir(0), true, true)
	var ride_frames: Array[int] = [0, 1, 2, 3, 2, 1]
	var ride_durs: Array[int] = [6, 3, 3, 6, 3, 3]
	for idx in range(ride_frames.size()):
		var f: Dictionary = p.get_bomber_state_frame()
		assert(f["action"] == "RideDown" and int(f["frame"]) == ride_frames[idx], "TV-B7: RideDown step %d expected %d, got %s" % [idx, ride_frames[idx], str(f)])
		for _t in range(ride_durs[idx]):
			p.step_bomber_state_tick()
	# ThrowDown = state 18: 4 steps, 6 ticks total, non-looping
	p.set_bomber_state(CGOBomberBaseClass.STATE_THROW_BASE + CGOBomberBaseClass.bomber_dir_to_ot_dir(0), false, true)
	for _t in range(5):
		p.step_bomber_state_tick()
		assert(p.state_finished == false, "TV-B7: ThrowDown must still be active before tick 6")
	p.step_bomber_state_tick()
	assert(p.state_finished == true, "TV-B7: ThrowDown must finish at tick 6")
	# Blink = state 00: 7 steps, 135 ticks total
	p.set_bomber_state(CGOBomberBaseClass.STATE_BLINK, false, true)
	for _t in range(134):
		p.step_bomber_state_tick()
		assert(p.state_finished == false, "TV-B7: Blink must stay active before tick 135")
	p.step_bomber_state_tick()
	assert(p.state_finished == true, "TV-B7: Blink must finish at tick 135")
	print("  [PASS] TV-B7: CGOBomberBase 90-state ObjectTable animation player (0x58DF45)")

	# TV-B8: CGOHedgehogBomber (0x74A690..0x74A8D9)
	var h = CGOHedgehogBomberClass.new()
	assert(h is CGOHedgehogBomberClass and h is CGOGameBomberClass and h is CGOBomberClass, "TV-B8: inheritance chain")
	h.apply_character_attr("C00")
	h.alive = true
	# 1. FakeHedgehog (human-only, 500 ticks, remaps Walk 20..23 -> 67..70)
	assert(h.use_super_hedgehog() == false, "TV-B8: SuperHedgehog must fail for human")
	assert(h.use_fake_hedgehog() == true, "TV-B8: FakeHedgehog succeeds for human")
	assert(h.m_bImitationHedgehog == true and h.m_wImitationHedgehogTime == 500, "TV-B8: FakeHedgehog 500 ticks")
	h.set_bomber_state(CGOBomberBaseClass.STATE_WALK_BASE + 3, true, true)
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_STOP_BASE + 3, "TV-B8: FakeHedgehog remaps Walk -> 70 (0x749A20)")
	for _t in range(500):
		h._on_tick()
	assert(h.m_bImitationHedgehog == false and h.m_wImitationHedgehogTime == 0, "TV-B8: FakeHedgehog expires after 500 ticks")
	# 2. Transform to real Hedgehog (0x74A11F): state 59 (47 ticks) -> 70, can_eat_item restriction (0x74970C)
	assert(h.transform_to_hedgehog() == true, "TV-B8: transform_to_hedgehog()")
	assert(h.m_bIsHedgehog == true and h.m_nHedgehogSpeed == 4, "TV-B8: Hedgehog speed=4")
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_DIE, "TV-B8: starts in state 59")
	assert(h.can_eat_item() == false, "TV-B8: cannot eat item during state 59 (0x74970C)")
	for _t in range(47):
		h._on_tick()
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_STOP_BASE + 3, "TV-B8: state 59 finishes -> 70 (0x74A414)")
	assert(h.can_eat_item() == true, "TV-B8: can eat item in state 70")
	assert(str(h.get_bomber_state_frame().get("sprite", "")) == "StaticChar/Hedgehog-WalkDown", "TV-B8: StaticChar sprite path")
	# 3. SuperHedgehog (0x749EA1 / 0x74962D): +2 speed (4->6), cap < 7, 33 ticks spin
	assert(h.use_super_hedgehog() == true, "TV-B8: SuperHedgehog succeeds for real Hedgehog")
	assert(h.m_nHedgehogSpeed == 6 and h.m_nSuperHedgehogCount == 33, "TV-B8: speed 4->6, 33 ticks")
	assert(h.use_super_hedgehog() == false, "TV-B8: SuperHedgehog refused when speed+2 > 7")
	for _t in range(33):
		h._on_tick()
	assert(h.m_nSuperHedgehogCount == 0, "TV-B8: SuperHedgehog spin finishes after 33 ticks")
	# 4. Hit by flame (0x74A8D9 -> 0x74A414): drops eaten item, 60 (14 ticks) -> 75 (99 ticks) -> 70
	h.apply_item("Item/ItemRoller")
	var dropped_items: Array[String] = []
	h.hedgehog_item_dropped.connect(func(code: String, _c: Vector2i): dropped_items.append(code))
	assert(h.on_flame_hit_hedgehog() == true, "TV-B8: Hedgehog hit by flame stuns instead of dying")
	assert(dropped_items == ["Item/ItemRoller"], "TV-B8: drops eaten item on hit")
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_FAINT and h.is_hedgehog_faint() == true, "TV-B8: enters state 60")
	for _t in range(14):
		h._on_tick()
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_STRUGGLE and h.is_hedgehog_faint() == true, "TV-B8: 60 -> 75 (0x74A414)")
	for _t in range(99):
		h._on_tick()
	assert(h.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_STOP_BASE + 3 and h.is_hedgehog_faint() == false, "TV-B8: 75 -> 70 (0x74A414)")
	h.free()
	print("  [PASS] TV-B8: CGOHedgehogBomber transform, FakeHedgehog, SuperHedgehog & stun cycle (0x74A11F..0x74A8D9)")

	# TV-B9: Full 90-state constants (0..89), group helpers & transition rules (0x5A0F75, 0x59BD5C, 0x7CD392)
	assert(p.ot_states.size() == CGOBomberBaseClass.TOTAL_STATES, "TV-B9: Character/C00_A must have 90 states")
	assert(CGOBomberBaseClass.is_locked_in_state(25) and CGOBomberBaseClass.is_locked_in_state(52) and CGOBomberBaseClass.is_locked_in_state(56) and not CGOBomberBaseClass.is_locked_in_state(57), "TV-B9: LockedIn state group (25, 52..56)")
	assert(CGOBomberBaseClass.is_ghost_state(43) and CGOBomberBaseClass.is_ghost_state(47) and CGOBomberBaseClass.is_ghost_state(51) and CGOBomberBaseClass.is_ghost_state(57) and not CGOBomberBaseClass.is_ghost_state(52), "TV-B9: Ghost state group (43..51, 57)")
	assert(CGOBomberBaseClass.is_slide_state(27) and CGOBomberBaseClass.is_slide_state(34) and CGOBomberBaseClass.is_slide_state(42) and not CGOBomberBaseClass.is_slide_state(35), "TV-B9: Slide state group (27..34, 39..42)")
	assert(CGOBomberBaseClass.is_snowball_state(76) and CGOBomberBaseClass.is_snowball_state(80) and CGOBomberBaseClass.is_snowball_state(85) and not CGOBomberBaseClass.is_snowball_state(86), "TV-B9: SnowBall state group (76..85)")
	assert(CGOBomberBaseClass.can_interrupt_locked_in(1) and CGOBomberBaseClass.can_interrupt_locked_in(26) and CGOBomberBaseClass.can_interrupt_locked_in(59) and CGOBomberBaseClass.can_interrupt_locked_in(82) and not CGOBomberBaseClass.can_interrupt_locked_in(20), "TV-B9: LockedIn interrupt guard (0x59BD5C)")
	assert(CGOBomberBaseClass.get_state_finish_transition(1, true) == 43 and CGOBomberBaseClass.get_state_finish_transition(1, false) == -1, "TV-B9: Die finish -> GhostIn or deactivate")
	assert(CGOBomberBaseClass.get_state_finish_transition(43) == 51 and CGOBomberBaseClass.get_state_finish_transition(57) == -1, "TV-B9: GhostIn -> 51, GhostOut -> -1")
	assert(CGOBomberBaseClass.get_state_finish_transition(35) == 12 and CGOBomberBaseClass.get_state_finish_transition(16) == 12, "TV-B9: Drill/Throw finish -> Stop")
	assert(CGOBomberBaseClass.get_state_finish_transition(79) == 15, "TV-B9: SnowThrow Down (79) finish -> StopDown (15) (0x7CD392)")
	print("  [PASS] TV-B9: Full 90-state constants, group helpers & transition rules (0x5A0F75, 0x59BD5C, 0x7CD392)")

	# TV-B10: Runtime CGOBomber LockedInMove (52..56), Slide (27..30 @ 10 px/tick), Drill (35..38), & Ghost (43 -> 51 -> 44..47 -> 57)
	var b := CGOGameBomberClass.new()
	b.setup(2, "StateTest", "Character/C00", 3, 3, Color.CYAN)
	b.start_ticks = 0
	b.action = "idle"
	# LockedInMove / Stop (52..56)
	b.in_bubble = true
	b.move(Vector2(1, 0), 0.03)
	assert(b.cur_state_idx == CGOBomberBaseClass.STATE_LOCKED_IN_MOVE_BASE + 2, "TV-B10: Bubble move right -> state 54 (LockedInMove Right)")
	b.move(Vector2.ZERO, 0.03)
	assert(b.cur_state_idx == CGOBomberBaseClass.STATE_LOCKED_IN_STOP, "TV-B10: Bubble idle -> state 56 (LockedInStop)")
	b.in_bubble = false
	# SlideJump (27..30, fixed 10 px/tick)
	var x0: float = b.position.x
	b.start_slide(3, 3) # Right for 3 ticks = +30 px
	assert(b.cur_state_idx == CGOBomberBaseClass.STATE_SLIDE_JUMP_BASE + 2, "TV-B10: start_slide right -> state 29")
	for _t in range(3):
		b._on_tick()
	assert(is_equal_approx(b.position.x - x0, 30.0) and b.action == "idle", "TV-B10: 3 ticks of slide = 30 px and returns to idle")
	# Slide blocked by wall stops immediately without penetrating
	var x_wall: float = b.position.x + 15.0
	b.start_slide(3, 5, func(pos: Vector2, _pid: int) -> bool: return pos.x <= x_wall)
	b._on_tick() # +10 <= +15 (ok)
	b._on_tick() # +20 > +15 (blocked -> stop)
	assert(is_equal_approx(b.position.x, x0 + 40.0) and b.slide_ticks == 0 and b.action == "idle", "TV-B10: Slide stops cleanly at wall")
	# Drill (35..38 -> Stop)
	b.dir = 0
	b.trigger_drill_anim()
	assert(b.cur_state_idx == CGOBomberBaseClass.STATE_DRILL_BASE + 3, "TV-B10: trigger_drill_anim down -> state 38")
	for _t in range(12):
		b._on_tick()
	assert(b.action == "idle" and b.cur_state_idx == CGOBomberBaseClass.STATE_STOP_BASE + 3, "TV-B10: Drill finishes -> state 15 (StopDown)")
	# Ghost cycle (43 -> 51 -> 46 half speed -> 57 -> hidden)
	b.enter_ghost_mode()
	assert(b.is_ghost and b.cur_state_idx == CGOBomberBaseClass.STATE_GHOST_IN, "TV-B10: enter_ghost_mode -> state 43")
	for _t in range(25):
		b._on_tick()
	assert(b.action == "ghost_stop" and b.cur_state_idx == CGOBomberBaseClass.STATE_GHOST_STOP_BASE + 3, "TV-B10: GhostIn (24 ticks) -> state 51")
	b.move(Vector2(1, 0), 0.03)
	assert(b.action == "ghost_walk" and b.cur_state_idx == CGOBomberBaseClass.STATE_GHOST_WALK_BASE + 2, "TV-B10: Ghost walk right -> state 46")
	b.exit_ghost_mode()
	assert(b.cur_state_idx == CGOBomberBaseClass.STATE_GHOST_OUT, "TV-B10: exit_ghost_mode -> state 57")
	for _t in range(25):
		b._on_tick()
	assert(not b.is_ghost and not b.alive and not b.is_bomber_visible(), "TV-B10: GhostOut finishes -> hidden/deactivated")
	b.free()
	print("  [PASS] TV-B10: Runtime LockedInMove (52..56), Slide (10 px/tick), Drill (35..38) & Ghost (43..57)")

	p.free()
	print("[TEST] ALL BOMBER CLASS HIERARCHY TESTS PASSED!")
	quit(0)
