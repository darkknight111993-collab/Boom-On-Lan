extends SceneTree

const CMapActionBombClass = preload("res://scripts/objects/c_map_action_bomb.gd")
const CGOBombClass = preload("res://scripts/objects/cgo_bomb.gd")
const CGOBomberClass = preload("res://scripts/objects/cgo_bomber.gd")
const CGOExplosionClass = preload("res://scripts/objects/cgo_explosion.gd")
const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")

func _init() -> void:
	print("[SUITE] Running TW Client Parity & User Issues Validation Suite...")
	var root_node := Node2D.new()
	root.add_child(root_node)

	# -------------------------------------------------------------
	# 1. TEST ITEM & MOUNT DATA INGESTION FROM CShipAttr (item_attr.json)
	# -------------------------------------------------------------
	CItemAttrClass.load_data()
	var airship_attr: Dictionary = CItemAttrClass.get_ship_attr("Airship")
	assert(airship_attr.get("speed") == 10, "Airship speed must be 10 (TW Client parity)")
	assert(airship_attr.get("is_flying") == true, "Airship must be flying")
	assert(airship_attr.get("ab_not_eat_item") == true, "Airship must have ab_not_eat_item (m_fAbNotEatItem)")
	assert(airship_attr.get("ab_pass_box") == true, "Airship must have ab_pass_box (m_fAbPassBox)")

	var tank_attr: Dictionary = CItemAttrClass.get_ship_attr("Tank")
	assert(tank_attr.get("speed") == 5, "Tank speed must be 5")
	assert(tank_attr.get("ab_tank") == true, "Tank must have ab_tank (m_fAbTank)")

	var turtle0_attr: Dictionary = CItemAttrClass.get_ship_attr("Turtle0")
	assert(turtle0_attr.get("speed") == 2, "Turtle0 speed must be 2")
	var turtle1_attr: Dictionary = CItemAttrClass.get_ship_attr("Turtle1")
	assert(turtle1_attr.get("speed") == 9, "Turtle1 speed must be 9")

	var octo0_attr: Dictionary = CItemAttrClass.get_ship_attr("Octopus0")
	assert(octo0_attr.get("speed") == 2, "Octopus0 speed must be 2")
	assert(octo0_attr.get("ab_pass_box") == false, "Octopus0 must NOT pass boxes")

	print("  [PASS] 1. CShipAttr[12] data ingestion matches original TW client")

	# -------------------------------------------------------------
	# 2. TEST AIRSHIP / UFO ABILITIES & ITEM BLOCKING
	# -------------------------------------------------------------
	var p1: Node2D = CGOBomberClass.new()
	p1.setup(0, "Player1", "Character/C00", 1, 1, Color.RED, false)
	root_node.add_child(p1)
	p1.equip_mount("Airship")
	assert(p1.mount != null, "Player 1 should be riding Airship")
	assert(p1.get_effective_speed() == 10, "Airship effective speed must be 10")
	assert(p1.m_fAbNotEatItem == true, "Airship must have m_fAbNotEatItem = true")
	assert(p1.can_eat_item() == false, "Airship must NOT be able to eat items (can_eat_item == false)")
	assert(p1.can_pass_box() == true, "Airship must be able to pass boxes")

	# Picking up another mount while riding must be ignored (sub_44780E)
	p1.equip_mount("Turtle0")
	assert(p1.mount.id == "Airship", "Riding Airship must not be overridden by Turtle0 pickup")

	p1.destroy_mount()
	assert(p1.mount == null, "Mount destroyed")
	assert(p1.can_eat_item() == true, "Normal character can eat items again")
	assert(p1.ship_dismount_ticks == 50, "Losing mount grants 50 ticks (1.5s) flame invulnerability (sub_44AF53)")
	assert(p1.can_be_hit_by_flame() == false, "Dismounted player is immune to flames for 50 ticks")
	print("  [PASS] 2. Airship (UFO) speed 10, item pickup blocking & dismount invulnerability verified")

	# -------------------------------------------------------------
	# 3. TEST TANK BOMB SHOOTING & SPEED
	# -------------------------------------------------------------
	var map_action: Node2D = CMapActionBombClass.new()
	root_node.add_child(map_action)
	p1.ship_dismount_ticks = 0 # reset invuln for next test
	p1.equip_mount("Tank")
	assert(p1.get_effective_speed() == 5, "Tank effective speed must be 5")
	assert(p1.m_fAbTank == true, "Tank has m_fAbTank = true")

	# Direction 3 is Right
	p1.dir = 3
	var dir_v := Vector2i(1, 0)
	var target_cell: Vector2i = map_action.trace_tank_shot_target(p1.cell.x, p1.cell.y, dir_v)
	assert(target_cell.x > p1.cell.x, "Tank bomb shot target must be forward along the lane")

	var shot_bomb: Node2D = map_action.place_bomb(p1.cell.x, p1.cell.y, 2, p1.player_id)
	assert(shot_bomb != null, "Tank shot bomb placed")
	shot_bomb.start_tank_shot(target_cell.x, target_cell.y)
	assert(shot_bomb.bomb_state == CGOBombClass.State.TANK_SHOT, "Bomb state should be TANK_SHOT")
	
	# Simulate movement ticks
	shot_bomb._on_update(0.1) # 66.67 px movement
	assert(shot_bomb.position.x > map_action.map_origin.x + p1.cell.x * 40, "Bomb slid forward along lane")
	print("  [PASS] 3. Tank speed 5 & real CGOBomb sliding shot along lane verified")

	# -------------------------------------------------------------
	# 4. TEST BUBBLE TRAPPED STATE, 200 TICKS & FLAME IMMUNITY
	# -------------------------------------------------------------
	p1.destroy_mount()
	p1.ship_dismount_ticks = 0
	p1.trap_in_bubble()
	assert(p1.in_bubble == true, "Player should be trapped in bubble")
	assert(p1.bubble_ticks == 200, "Bubble total ticks must be 200 (6.0 seconds, sub_4F3D22)")
	assert(p1.can_be_hit_by_flame() == false, "Trapped player must be IMMUNE to flame hits (sub_449CB9)")
	assert(p1.can_pop_or_rescue() == false, "First 16 ticks (480ms) grace period cannot be popped or rescued")

	# Step 16 ticks
	for i in range(16):
		p1._on_tick()
	assert(p1.can_pop_or_rescue() == true, "After 16 ticks, player can be rescued or popped")
	assert(p1.bubble_ticks == 200 - 16, "Bubble ticks decremented by 16")

	# Slow crawl movement while trapped
	var pos_before: Vector2 = p1.position
	p1.move(Vector2(1, 0), 0.1) # 1.67 px movement
	assert(p1.position.x > pos_before.x, "Trapped player slowly crawls in bubble (sub_4503B5)")

	# Rescue
	p1.rescue()
	assert(p1.in_bubble == false, "Rescued player is freed")
	assert(p1.rescue_invuln_ticks == 33, "Rescue grants 33 ticks (1.0s) invulnerability (sub_44A18B)")
	assert(p1.can_be_hit_by_flame() == false, "Rescued player is immune to flames for 33 ticks")
	print("  [PASS] 4. Bubble trapped 200 ticks, grace period, flame immunity & slow crawl verified")

	# -------------------------------------------------------------
	# 5. TEST EXPLOSION DROPLET PARTICLE CLEANUP (NO LEFTOVER PARTICLES)
	# -------------------------------------------------------------
	var exp: Node2D = CGOExplosionClass.new()
	exp.setup(3, 3)
	root_node.add_child(exp)
	assert(exp.anim_finished == false, "Explosion starts with anim_finished = false")
	
	# Simulate passage of 20 ticks (10 frames * 2 ticks = 20 ticks = 0.60s)
	exp._process(0.65)
	assert(exp.anim_finished == true, "Explosion animation completes cleanly")
	assert(exp.is_queued_for_deletion() == true, "Explosion node is queued for deletion (no stuck droplets)")
	print("  [PASS] 5. Explosion segment terminates cleanly without leaving droplet particles")

	# -------------------------------------------------------------
	# 6. TEST HURRAH TIMING SEQUENCE
	# -------------------------------------------------------------
	assert(CGOBomberClass.HURRAH_CYCLE_TICKS == 204, "Hurrah cycle must be 204 ticks (6.12s)")
	# Frame 0 must be held for first 66 ticks (1.98s)
	assert(CGOBomberClass.get_hurrah_frame(0) == 0, "Hurrah frame at tick 0 is 0")
	assert(CGOBomberClass.get_hurrah_frame(65) == 0, "Hurrah frame at tick 65 is 0")
	assert(CGOBomberClass.get_hurrah_frame(66) == 1, "Hurrah frame at tick 66 moves to 1")
	print("  [PASS] 6. Hurrah victory sequence matches 204 ticks timing table")

	# -------------------------------------------------------------
	# 7. TEST REDDEVIL & ROLLER SPEED DECOUPLING
	# -------------------------------------------------------------
	p1.speed = 5
	p1.can_kick = false
	p1.apply_item("Item/RedDevil")
	assert(p1.can_kick == true, "RedDevil grants Kick Bomb ability (sub_5879D9)")
	assert(p1.speed >= 7, "RedDevil grants +3 Speed buff (not devil debuff!)")

	# Decoupled Turtle speed:
	p1.speed = 7
	p1.equip_mount("Turtle0")
	assert(p1.get_effective_speed() == 2, "Turtle speed is locked at 2")
	p1.apply_item("Item/Roller")
	assert(p1.get_effective_speed() == 2, "Eating Roller while riding Turtle does NOT speed up Turtle")
	p1.destroy_mount()
	assert(p1.get_effective_speed() >= 7, "Dismounting restores character's accumulated speed")
	print("  [PASS] 7. RedDevil buff & mount speed decoupling verified")

	print("\n[SUITE] ALL TW CLIENT PARITY & FIX VALIDATION CHECKS PASSED 100% CLEANLY!")
	quit(0)
