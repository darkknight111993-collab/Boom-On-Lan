extends SceneTree

const CosmeticsClass = preload("res://scripts/objects/cgo_bomber_cosmetics.gd")
const BomberClass = preload("res://scripts/objects/cgo_bomber.gd")
const BomberBaseClass = preload("res://scripts/objects/cgo_bomber_base.gd")
const SpriteDBScript = preload("res://scripts/sprite_db.gd")

var _fails: int = 0

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("[FAIL] " + msg)
	else:
		print("[PASS] " + msg)

func _init() -> void:
	_test_tv_c1_part_codes()
	_test_tv_c2_path_format()
	_test_tv_c3_char_compat()
	_test_tv_c4_mutual_exclusion()
	_test_tv_c5_state_to_frame_mapping()
	_test_tv_c6_iddx_fallback_and_bomber_render()

	if _fails > 0:
		printerr("Character cosmetics tests FAILED: %d" % _fails)
		quit(1)
	else:
		print("ALL CHARACTER COSMETICS TESTS PASSED")
		quit(0)

func _test_tv_c1_part_codes() -> void:
	_assert(CosmeticsClass.slot_to_part_code(0) == 0, "TV-C1: slot 0 -> 0")
	_assert(CosmeticsClass.slot_to_part_code(1) == 10, "TV-C1: slot 1 -> 10")
	_assert(CosmeticsClass.slot_to_part_code(9) == 90, "TV-C1: slot 9 -> 90")
	_assert(CosmeticsClass.slot_to_part_code(10) == 21, "TV-C1: slot 10 -> 21")
	_assert(CosmeticsClass.slot_to_part_code(11) == 41, "TV-C1: slot 11 -> 41")
	_assert(CosmeticsClass.slot_to_part_code(12) == 22, "TV-C1: slot 12 -> 22")
	_assert(CosmeticsClass.slot_to_part_code(13) == 0, "TV-C1: slot 13 -> 0")

func _test_tv_c2_path_format() -> void:
	_assert(CosmeticsClass.format_avatar_deco_path(2, 1, 1) == "AvatarDeco/A02_10_0001", "TV-C2: (2,1,1) -> AvatarDeco/A02_10_0001")
	_assert(CosmeticsClass.format_avatar_deco_path(0, 12, 5) == "AvatarDeco/A00_22_0005", "TV-C2: (0,12,5) -> AvatarDeco/A00_22_0005")
	_assert(CosmeticsClass.format_avatar_deco_path(6, 11, 2) == "AvatarDeco/A06_41_0002", "TV-C2: (6,11,2) -> AvatarDeco/A06_41_0002")

func _test_tv_c3_char_compat() -> void:
	_assert(CosmeticsClass.is_char_compatible(2, 2), "TV-C3: same char 2==2")
	_assert(CosmeticsClass.is_char_compatible(6, 12), "TV-C3: char 12 accepts 6")
	_assert(CosmeticsClass.is_char_compatible(5, 14), "TV-C3: char 14 accepts 5")
	_assert(CosmeticsClass.is_char_compatible(8, 15), "TV-C3: char 15 accepts 8")
	_assert(not CosmeticsClass.is_char_compatible(6, 14), "TV-C3: char 14 rejects 6")

func _test_tv_c4_mutual_exclusion() -> void:
	var c := CosmeticsClass.new()
	c.equip_slot(2, "AvatarDeco/A02_20_0001")
	c.equip_slot(3, "AvatarDeco/A02_30_0001")
	c.equip_slot(4, "AvatarDeco/A02_40_0001")
	c.equip_slot(6, "AvatarDeco/A02_60_0001")
	var cleared_12: Array[int] = c.equip_slot(12, "AvatarDeco/A02_22_0001")
	_assert(cleared_12 == [2, 3, 4, 6], "TV-C4: slot 12 clears [2,3,4,6], got %s" % str(cleared_12))
	_assert(c.slots[12] == "AvatarDeco/A02_22_0001" and c.slots[2] == "" and c.slots[6] == "", "TV-C4: slot 12 active and conflicts empty")

	_assert(CosmeticsClass.get_conflicting_slots(10) == [2, 3, 12], "TV-C4: slot 10 conflicts [2,3,12]")
	var cleared_10: Array[int] = c.equip_slot(10, "AvatarDeco/A02_21_0001")
	_assert(cleared_10 == [12] and c.slots[12] == "", "TV-C4: slot 10 clears active slot 12")

	c.equip_slot(4, "AvatarDeco/A02_40_0001")
	c.equip_slot(6, "AvatarDeco/A02_60_0001")
	_assert(CosmeticsClass.get_conflicting_slots(11) == [4, 6, 12], "TV-C4: slot 11 conflicts [4,6,12]")
	var cleared_11: Array[int] = c.equip_slot(11, "AvatarDeco/A02_41_0001")
	_assert(cleared_11 == [4, 6] and c.slots[4] == "" and c.slots[6] == "", "TV-C4: slot 11 clears active [4,6]")

func _test_tv_c5_state_to_frame_mapping() -> void:
	# Verify 0xC37AF8 / 0xC37C60 exact table counts & key states
	var hidden_count := 0
	for st in range(90):
		if CosmeticsClass.STATE_LAYER[st] == -1:
			hidden_count += 1
	_assert(hidden_count == 46, "TV-C5: exactly 46 hidden states in 0xC37AF8, got %d" % hidden_count)

	# WalkDown (state 23) frame 3 -> sheet 0, frame 0 + 3 = 3
	var wd: Dictionary = CosmeticsClass.resolve_avatar_deco_frame(BomberBaseClass.STATE_WALK_BASE + 3, 3)
	_assert(wd.get("sheet_idx") == 0 and wd.get("frame_idx") == 3, "TV-C5: WalkDown f3 -> sheet 0, frame 3")

	# RideLeft (state 4) frame 2 -> sheet 0, frame 40 + 2 = 42
	var rl: Dictionary = CosmeticsClass.resolve_avatar_deco_frame(BomberBaseClass.STATE_RIDE_BASE, 2)
	_assert(rl.get("sheet_idx") == 0 and rl.get("frame_idx") == 42, "TV-C5: RideLeft f2 -> sheet 0, frame 42")

	# Hurrah (state 3) frame 1 -> sheet 1, frame 3 + 1 = 4
	var hr: Dictionary = CosmeticsClass.resolve_avatar_deco_frame(BomberBaseClass.STATE_HURRAH, 1)
	_assert(hr.get("sheet_idx") == 1 and hr.get("frame_idx") == 4, "TV-C5: Hurrah f1 -> sheet 1, frame 4")

	# Hidden states: Die(1), LockedIn(25), GhostIn(43), HedgehogWalk(63), StaticStop(86)
	for h_st in [1, 2, 25, 43, 52, 63, 80, 86]:
		_assert(CosmeticsClass.resolve_avatar_deco_frame(h_st, 0).is_empty(), "TV-C5: state %d hides AvatarDeco" % h_st)

func _test_tv_c6_iddx_fallback_and_bomber_render() -> void:
	var sdb: Node = SpriteDBScript.new()
	sdb.name = "SpriteDB"
	root.add_child(sdb)

	# Verify standard AvatarDeco + all 6 unique IDDX assets resolve & load frames
	var std_f: Dictionary = sdb.get_avatar_deco_frame("AvatarDeco/A02_10_0001", 0, 0)
	_assert(std_f.get("adjust_texture") != null and std_f.get("static_texture") != null, "TV-C6: standard AvatarDeco/A02_10_0001 loads Adjust+Static")

	var iddx_4: Dictionary = sdb.get_avatar_deco_frame("AvatarDeco/A06_20_0007", 0, 0)
	_assert(iddx_4.get("adjust_texture") != null and iddx_4.get("static_texture") != null, "TV-C6: IDDX-only A06_20_0007 loads Adjust+Static")

	var iddx_2: Dictionary = sdb.get_avatar_deco_frame("AvatarDeco/A06_30_0004", 0, 0)
	_assert(iddx_2.get("adjust_texture") == null and iddx_2.get("static_texture") != null, "TV-C6: IDDX-only A06_30_0004 loads Static-only")

	var iddx_ic: Dictionary = sdb.get_frame("Icon/A06_10_0001icon", 0)
	_assert(not iddx_ic.is_empty(), "TV-C6: IDDX-only Icon/A06_10_0001icon loads")

	# Verify CGOBomber equips cosmetics, renders on idle, hides on bush/bubble/ghost
	var b := BomberClass.new()
	root.add_child(b)
	b.setup(0, "CosmeticTest", "Character/C02", 3, 3, Color(0.2, 0.4, 1.0), false, "BombDeco/Bomb001", "", {}, {
		"hat": "AvatarDeco/A02_10_0001",
		"char_deco": "CharDeco/CharDeco_A0015",
		"id_deco": "IDDeco/IDDeco_C001",
	})
	b.start_ticks = 0
	b.action = "idle"
	b._update_visuals()
	_assert(b._deco_static_nodes.size() == 1 and b._deco_static_nodes[0].visible, "TV-C6: bomber renders AvatarDeco on idle")
	_assert(b._deco_adjust_nodes[0].visible and b._deco_adjust_nodes[0].modulate == Color(0.2, 0.4, 1.0), "TV-C6: bomber team-tints LayerAdjust")
	_assert(b.sp_char_deco.visible, "TV-C6: bomber renders CharDeco on idle")
	_assert(b.sp_id_deco.visible, "TV-C6: bomber renders IDDeco behind name_lbl")

	# Bush hide (is_bomber_visible == false) hides all cosmetics
	b.set_bomber_visible(false)
	b._update_visuals()
	_assert(not b._deco_static_nodes[0].visible and not b.sp_char_deco.visible and not b.sp_id_deco.visible, "TV-C6: bush conceal hides all cosmetics")
	b.set_bomber_visible(true)

	# Bubble trap hides AvatarDeco & CharDeco
	b.trap_in_bubble()
	_assert(not b._deco_static_nodes[0].visible and not b.sp_char_deco.visible, "TV-C6: bubble trap hides AvatarDeco & CharDeco")

	# Ghost mode hides AvatarDeco & CharDeco
	b.enter_ghost_mode()
	_assert(not b._deco_static_nodes[0].visible and not b.sp_char_deco.visible, "TV-C6: ghost mode hides AvatarDeco & CharDeco")

	b.queue_free()
	sdb.queue_free()
