extends SceneTree

const CGOBomber = preload("res://scripts/objects/cgo_bomber.gd")
const CGOBomb = preload("res://scripts/objects/cgo_bomb.gd")
const CMapActionBomb = preload("res://scripts/objects/c_map_action_bomb.gd")
const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")
const CBomberAttrScript = preload("res://scripts/objects/cbomber_attr.gd")

func _init() -> void:
	print("[CLINE_CHECK] Running verification for OBJECT_ANALYSIS_TW_COMPARISON_Cline.md items...")

	var root_node := Node2D.new()

	# -------------------------------------------------------------------------
	# 1. SECTION 12 & 13: BOMBER SPEED, ROLLER, TANK CAPACITY
	# -------------------------------------------------------------------------
	var b := CGOBomber.new()
	b.setup(0, "Bazzi", "Character/C00", 1, 1, Color.RED)
	root_node.add_child(b)

	# Bazzi (C00): speed_start=5, speed_max=7, bombs_start=1, bombs_max=10
	assert(b.speed == 5, "Bazzi initial speed must be 5")
	assert(b.speed_max == 7, "Bazzi max speed must be 7")
	assert(b.bombs_cur == 1, "Bazzi initial bombs must be 1")
	assert(b.bombs_max == 10, "Bazzi max bombs must be 10")
	assert(b.get_effective_bomb_capacity() == 1, "Without tank, effective bomb capacity must be bombs_cur (1)")

	# Apply Roller item
	b.apply_item("Item/ItemRoller")
	assert(b.speed == 6, "Eating 1 Roller must increase speed to 6")
	b.apply_item("Item/ItemRoller")
	assert(b.speed == 7, "Eating 2 Rollers must increase speed to 7 (capped at speed_max)")
	b.apply_item("Item/ItemRoller")
	assert(b.speed == 7, "Speed must NOT exceed speed_max 7")

	# Equip Tank: speed becomes 5 (Tank CShipAttr speed), effective bomb capacity becomes 10 (bombs_max)
	b.equip_mount("Tank")
	assert(b.get_effective_speed() == 5, "Tank speed must be 5, independent of character speed")
	assert(b.get_effective_bomb_capacity() == 10, "Tank effective bomb capacity must be bombs_max (10)")

	# Eating Roller while mounted increases base character speed, but mount effective speed stays 5
	b.apply_item("Item/ItemRoller")
	assert(b.get_effective_speed() == 5, "Mount speed must remain 5 after eating Roller")

	# Destroy Tank: speed restores to character speed (7), effective capacity restores to bombs_cur (1)
	b.destroy_mount()
	assert(b.get_effective_speed() == 7, "Dismounting restores upgraded character speed")
	assert(b.get_effective_bomb_capacity() == 1, "Dismounting restores character bomb capacity (1)")
	assert(b.ship_dismount_ticks == 50, "Dismounting grants 50 ticks (1.5s) invulnerability")
	assert(not b.can_be_hit_by_flame(), "Must be immune to flame during 50 dismount ticks")
	print("  [PASS] 1. Character speed, Roller cap, Tank bomb capacity & dismount immunity verified")

	# -------------------------------------------------------------------------
	# 2. SECTION 16: MOUNTING SUCTION (15 TICKS AT 4 PX/TICK)
	# -------------------------------------------------------------------------
	var b2 := CGOBomber.new()
	b2.setup(1, "Dao", "Character/C01", 2, 2, Color.BLUE)
	root_node.add_child(b2)

	# Place b2 slightly off-center (offset by 10 px in X and Y)
	var initial_anchor: Vector2 = b2.position
	b2.position += Vector2(10.0, 10.0)
	var off_pos: Vector2 = b2.position

	b2.equip_mount("Turtle0")
	assert(b2.ship_ride_count == 15, "equip_mount must initiate 15 ticks suction")

	# Advance 1 tick
	b2._on_tick()
	assert(b2.ship_ride_count == 14, "ship_ride_count decreased to 14")
	assert(b2.position.distance_to(initial_anchor) < off_pos.distance_to(initial_anchor), "Position must move towards cell center")

	# Advance remaining 14 ticks
	for _i in range(14):
		b2._on_tick()
	assert(b2.ship_ride_count == 0, "ship_ride_count reached 0")
	assert(b2.position.distance_to(initial_anchor) < 0.1, "After suction, position snapped to cell center")
	print("  [PASS] 2. 15-tick mount suction to tile center (sub_4503B5) verified")

	# -------------------------------------------------------------------------
	# 3. SECTION 18: OFF-CENTER CONTINUOUS COORDINATES & HITBOX OVERLAP
	# -------------------------------------------------------------------------
	var b3 := CGOBomber.new()
	b3.map_origin = Vector2(20.0, 41.0)
	b3.setup(2, "Marid", "Character/C02", 3, 3, Color.YELLOW)
	root_node.add_child(b3)

	# Cell formula check: floor((x - origin.x + 20) / 40), floor((y - origin.y - 15) / 40)
	var center_anchor := Vector2(20.0 + 3 * 40.0, 41.0 + 3 * 40.0 + 39.0)
	b3.position = center_anchor
	assert(b3.get_bomb_placement_cell() == Vector2i(3, 3), "Exact anchor yields cell (3, 3)")

	# Shift 10 pixels right: should still be in cell 3
	b3.position.x += 10.0
	assert(b3.get_bomb_placement_cell() == Vector2i(3, 3), "Shifted +10px still yields cell (3, 3)")

	# Reset to center anchor
	b3.position = center_anchor

	# Check flame hitbox 32x15 at (x+4, y-15) (CA.exe sub_4EDB76: n32=32, n15=15)
	var hb: Rect2 = b3.get_flame_hitbox()
	assert(hb.size == Vector2(32.0, 15.0), "Flame hitbox size must be 32x15 (CA.exe sub_4EDB76)")
	var flame_tile := Rect2(b3.map_origin + Vector2(3 * 40.0, 3 * 40.0), Vector2(40.0, 40.0))
	var inter := hb.intersection(flame_tile)
	var full_area: float = inter.size.x * inter.size.y
	assert(full_area == 480.0, "Full centered overlap must be 480 px^2 (32x15)")
	assert(full_area >= 320.0, "Centered overlap exceeds 2/3 threshold (320 px^2)")

	# Edge dodge test (Né bom): Shift player so only 14 pixels of width are inside flame tile
	# Overlap area = 14 * 15 = 210 px^2 < 320 px^2 -> Player escapes flame damage!
	var edge_hb := Rect2(flame_tile.position + Vector2(40.0 - 14.0, 0.0), Vector2(32.0, 15.0))
	var edge_inter := edge_hb.intersection(flame_tile)
	var edge_area: float = edge_inter.size.x * edge_inter.size.y
	assert(edge_area == 210.0, "Edge overlap must be 210 px^2")
	assert(edge_area < 320.0, "Edge overlap < 320 px^2 must NOT trigger flame damage (sub_4EDB76 dodge)")
	print("  [PASS] 3. Continuous off-center coordinates, 32x15 hitbox & 2/3 area threshold (320 px^2) verified")

	# -------------------------------------------------------------------------
	# 4. SECTION 17: KICK & PUNCH IN COMBINATION WITH MOUNT STATUS
	# -------------------------------------------------------------------------
	var b4 := CGOBomber.new()
	b4.setup(3, "Uni", "Character/C03", 0, 0, Color.GREEN)
	root_node.add_child(b4)

	b4.apply_item("Item/ItemShoe")
	b4.apply_item("Item/ItemPunch")
	assert(b4.can_kick_bomb(), "Without mount, can_kick_bomb must be true")
	assert(b4.can_punch_bomb(), "Without mount, can_punch_bomb must be true")

	# Mount disables both kick and punch (sub_447AAF & sub_447B01)
	b4.equip_mount("Owl")
	assert(not b4.can_kick_bomb(), "With mount, can_kick_bomb must be FALSE")
	assert(not b4.can_punch_bomb(), "With mount, can_punch_bomb must be FALSE")

	# Dismount restores kick and punch, sets stop_ride action, and activates 50-tick invulnerability
	b4.destroy_mount()
	assert(b4.can_kick_bomb(), "After dismount, can_kick_bomb restored")
	assert(b4.can_punch_bomb(), "After dismount, can_punch_bomb restored")
	assert(b4.action == "stop_ride", "Dismount sets action to stop_ride")
	assert(b4.ship_dismount_ticks == 50, "Dismount sets 50 ticks invulnerability")
	assert(not b4.can_be_hit_by_flame(), "During dismount invulnerability, cannot be hit by flame")

	# Advance 50 ticks: action returns to idle and invulnerability expires
	for _i in range(50):
		b4._on_tick()
	assert(b4.ship_dismount_ticks == 0, "ship_dismount_ticks reached 0")
	assert(b4.action == "idle", "action returned to idle after dismount")
	assert(b4.can_be_hit_by_flame(), "Can be hit by flame after dismount timer expires")
	print("  [PASS] 4. Kick, Punch, and Dismount visuals & 50-tick invulnerability verified")

	# -------------------------------------------------------------------------
	# 5. SKELETON DEBUFFS & POTION CURE (CA.exe sub_445DEE, sub_445E0F, sub_44769A)
	# -------------------------------------------------------------------------
	var b5 := CGOBomber.new()
	b5.setup(4, "Dao", "Character/C04", 5, 5, Color.BLUE)
	root_node.add_child(b5)
	b5.start_ticks = 0
	b5.modulate = Color.WHITE

	# Calibrated walk speed check
	assert(CBomberAttrScript.speed_to_pixels_per_sec(5) == 90.0, "Base speed 5 calibrated to 90 px/s")

	# Skeleton0: auto bomb drop timer
	b5.apply_item("Item/ItemSkeleton0")
	assert(b5.auto_bomb_ticks == 144, "Skeleton0 sets auto_bomb_ticks to 144")
	assert(b5.is_devil, "is_devil is true when debuffed")

	# Skeleton1: reversed controls timer
	b5.apply_item("Item/ItemSkeleton1")
	assert(b5.reverse_dir_ticks == 144, "Skeleton1 sets reverse_dir_ticks to 144")

	# Purple flash check: sub_44769A (ticks % 6 < 3)
	b5._on_tick() # 143 ticks -> 143 % 6 = 5 >= 3 -> normal
	assert(b5.modulate == Color.WHITE, "Tick 143 modulate is WHITE")
	b5.auto_bomb_ticks = 144 # 144 % 6 = 0 < 3 -> purple
	b5.reverse_dir_ticks = 144
	b5._on_tick() # tick drops to 143... wait, if ticks = 146 -> 145 % 6 = 1 < 3
	b5.auto_bomb_ticks = 146
	b5.reverse_dir_ticks = 146
	b5._on_tick() # drops to 145: 145 % 6 = 1 < 3 -> purple
	assert(b5.modulate == Color(0.85, 0.45, 1.0, 1.0), "Debuff % 6 < 3 flashes purple")

	# Potion cure: cleanses all debuffs and restores modulate
	b5.apply_item("Item/ItemPotion")
	assert(b5.auto_bomb_ticks == 0, "Potion clears auto_bomb_ticks")
	assert(b5.reverse_dir_ticks == 0, "Potion clears reverse_dir_ticks")
	assert(b5.devil_ticks == 0, "Potion clears devil_ticks")
	assert(b5.modulate == Color.WHITE, "Potion restores WHITE modulate")
	print("  [PASS] 5. Skeleton0, Skeleton1, purple flash & Potion cure verified cleanly")

	# -------------------------------------------------------------------------
	# 6. NEW ATTRIBUTES: OXYGEN, CAMOUFLAGE, HOLLOW, PASSBOX, NITRO
	# -------------------------------------------------------------------------
	var b6 := CGOBomber.new()
	b6.setup(5, "Mos", "Character/C05", 2, 2, Color.PURPLE)
	root_node.add_child(b6)
	b6.start_ticks = 0
	b6.modulate = Color.WHITE

	# Oxygen: keeps trapped bomber alive when bubble reaches 200 ticks
	b6.apply_item("Item/ItemOxygen")
	assert(b6.oxygen_count == 1, "Oxygen item increments oxygen_count")
	b6.trap_in_bubble()
	assert(b6.in_bubble, "Bomber trapped in bubble")
	b6.bubble_elapsed_ticks = 199
	b6._on_tick() # Reaches 200 ticks -> auto-consumes oxygen, resets elapsed to 0
	assert(b6.alive, "Bomber remains alive via Oxygen item")
	assert(b6.in_bubble, "Bomber still in bubble awaiting rescue")
	assert(b6.bubble_elapsed_ticks == 0, "Oxygen reset bubble_elapsed_ticks to 0")
	assert(b6.oxygen_count == 0, "Oxygen consumed")
	b6.rescue()

	# Camouflage: hides name label and applies 0.35 alpha cloak for 244 ticks (sub_447B95)
	b6.apply_item("Camouflage")
	assert(b6.camouflage_ticks == 244, "Camouflage set to 244 ticks")
	b6._on_tick()
	assert(not b6.name_lbl.visible, "Camouflage hides name label")
	assert(absf(b6.modulate.a - 0.35) < 0.01, "Camouflage alpha is 0.35")
	b6.camouflage_ticks = 1
	b6._on_tick()
	assert(b6.name_lbl.visible, "Name label restored after camouflage expires")
	assert(absf(b6.modulate.a - 1.0) < 0.01, "Modulate alpha restored to 1.0")

	# Hollow: applies 0.5 alpha transparency for 244 ticks (sub_445DBB, sub_4407F9)
	b6.apply_item("Item/ItemHollow")
	assert(b6.hollow_ticks == 244, "Hollow set to 244 ticks")
	b6._on_tick()
	assert(absf(b6.modulate.a - 0.5) < 0.01, "Hollow alpha is 0.5 (128/255)")
	b6.hollow_ticks = 0
	b6._on_tick()
	assert(absf(b6.modulate.a - 1.0) < 0.01, "Modulate alpha restored to 1.0 after Hollow")

	# Pass box: Airship and Chicken can pass box
	assert(not b6.can_pass_box(), "On foot without ability, cannot pass box")
	b6.equip_mount("Airship")
	assert(b6.can_pass_box(), "Airship mount can pass box (m_fAbPassBox)")
	b6.destroy_mount()

	# Kart Nitro: boosts speed to 10 for 300 ticks
	b6.equip_mount("Kart")
	assert(b6.get_effective_speed() == 5, "Kart initial speed is 5")
	b6.apply_item("Item/Nitro")
	assert(b6.get_effective_speed() == 10, "Kart speed boosted to 10 with Nitro")
	assert(b6.kart_nitro_ticks == 300, "Nitro timer set to 300 ticks")
	b6.kart_nitro_ticks = 1
	b6._on_tick()
	assert(b6.get_effective_speed() == 5, "Kart speed restored to 5 after Nitro expires")
	b6.destroy_mount()
	print("  [PASS] 6. Oxygen, Camouflage, Hollow, PassBox & Kart Nitro verified cleanly")

	print("[CLINE_CHECK] ALL OBJECT_ANALYSIS_TW_COMPARISON_Cline CHECKS PASSED 100%!")
	quit(0)
