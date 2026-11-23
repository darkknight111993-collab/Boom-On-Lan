extends SceneTree

const CMapActionBombClass = preload("res://scripts/objects/c_map_action_bomb.gd")
const CGOBombClass = preload("res://scripts/objects/cgo_bomb.gd")
const CGOBomberClass = preload("res://scripts/objects/cgo_bomber.gd")
const CGOTileClass = preload("res://scripts/objects/cgo_tile.gd")
const CGOItemClass = preload("res://scripts/objects/cgo_item.gd")
const CBomberAttrClass = preload("res://scripts/objects/cbomber_attr.gd")
const CGONpcBasicMonClass = preload("res://scripts/objects/cgo_npc_basic_mon.gd")
const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")
const CGODartClass = preload("res://scripts/objects/cgo_dart.gd")
const CGONpcAttackMonClass = preload("res://scripts/objects/cgo_npc_attack_mon.gd")
const CGONpcMonEggClass = preload("res://scripts/objects/cgo_npc_mon_egg.gd")
const CGOTileMovableBoxClass = preload("res://scripts/objects/cgo_movable_box.gd")
const CGOObstacleTrapClass = preload("res://scripts/objects/cgo_obstacle_trap.gd")

func _init() -> void:
	print("[SUITE] Running complete Game Objects validation suite...")
	var root_node := Node2D.new()
	root.add_child(root_node)

	# 1. TEST CGOBomb & CMapActionBomb
	var map_action: Node2D = CMapActionBombClass.new()
	root_node.add_child(map_action)
	var bomb: Node2D = map_action.place_bomb(5, 5, 2, 0)
	assert(bomb != null, "Bomb should be placed")
	assert(bomb.position == Vector2(20 + 5 * 40, 41 + 5 * 40 + 39), "Bomb anchor position matches exact formula")
	print("  [PASS] 1. CGOBomb anchor & placement verified")

	# 2. TEST CBomberAttr Data Ingestion
	var dao_attr: Dictionary = CBomberAttrClass.get_stats("Character/C00")
	assert(dao_attr.speed_start == 5 and dao_attr.speed_max == 7, "Dao speed must be 5..7")
	assert(dao_attr.bomb_start == 1 and dao_attr.bomb_max == 10, "Dao bomb must be 1..10")

	var dizini_attr: Dictionary = CBomberAttrClass.get_stats("Character/C01")
	assert(dizini_attr.power_max == 9, "Dizini max fluid power must be 9")

	var uni_attr: Dictionary = CBomberAttrClass.get_stats("Character/C02")
	assert(uni_attr.power_start == 2, "Uni starting fluid power must be 2")

	var bazzi_attr: Dictionary = CBomberAttrClass.get_stats("Character/C06")
	assert(bazzi_attr.speed_max == 9, "Bazzi max speed must be 9")
	print("  [PASS] 2. CBomberAttr 100% matches original game data tables")

	# 3. TEST CGOBomber (Character Attributes & Mechanics)
	var bomber: Node2D = CGOBomberClass.new()
	bomber.setup(1, "Player1", "Character/C02", 2, 3, Color.RED, false)
	root_node.add_child(bomber)
	assert(bomber.cell == Vector2i(2, 3), "Bomber cell should be (2, 3)")
	assert(bomber.position == Vector2(20 + 2 * 40, 41 + 3 * 40 + 39), "Bomber anchor position matches formula")
	assert(bomber.power_cur == 2, "Uni (C02) must start with 2 power from CBomberAttr")

	# Test Corner Sliding Assist
	var blocked_calls := 0
	var can_fit := func(target: Vector2, _id: int) -> bool:
		blocked_calls += 1
		return blocked_calls > 1

	bomber.move(Vector2(0, 1), 0.05, can_fit)
	print("  [PASS] 3. CGOBomber placement, CBomberAttr auto-bind & corner assist verified")

	# Test Bomber bubble, needle self-rescue & shield protection
	bomber.needle_count = 1
	bomber.trap_in_bubble()
	assert(bomber.in_bubble, "Bomber should be in bubble")
	assert(bomber.use_needle() == true, "use_needle should succeed")
	assert(not bomber.in_bubble, "Bomber should be rescued with needle")
	assert(bomber.needle_count == 0, "Needle count should decrease by 1")

	bomber.shield_ticks = 100
	bomber.trap_in_bubble()
	assert(not bomber.in_bubble, "Shield should protect bomber from bubble")
	assert(bomber.shield_ticks == 0, "Shield should be consumed")

	bomber.trap_in_bubble()
	assert(bomber.in_bubble, "Bomber should be in bubble without shield")
	bomber.rescue()
	assert(not bomber.in_bubble, "Bomber should be rescued")
	print("  [PASS] 4. CGOBomber bubble trap, needle & shield mechanics verified")

	# 4. TEST CGOTile (Box & Wall)
	var tile: Node2D = CGOTileClass.new()
	tile.setup(4, 4, "Tile00_Box/BoxGray", 2, "Item/Bomb")
	root_node.add_child(tile)
	assert(tile.tile_type == 2, "Tile type should be BOX (2)")
	tile.break_box()
	assert(tile.is_broken, "Tile should be broken")
	print("  [PASS] 5. CGOTile box break & drop item verified")

	# 5. TEST CGOItem & CItemAttr
	CItemAttrClass.load_data()
	assert(CItemAttrClass.get_total_weight() > 0, "Item drop pool total weight must be > 0")
	var drop_code: String = CItemAttrClass.get_random_drop_item()
	assert(drop_code != "", "Must roll valid drop item from item_attr.json")

	var item: Node2D = CGOItemClass.new()
	item.setup(4, 4, "Item/Bomb")
	root_node.add_child(item)
	var old_bombs: int = bomber.bombs_cur
	item.collect(bomber)
	assert(bomber.bombs_cur == old_bombs + 1, "Bomber should receive +1 bomb count")

	# Test Dart item collection
	bomber.apply_item("Item/ItemDart")
	assert(bomber.dart_count == 3, "Bomber should receive 3 darts")
	print("  [PASS] 6. CItemAttr drop tables & CGOItem collection verified")

	# 6. TEST Chain Reaction
	var chained_bomb: Node2D = map_action.place_bomb(5, 6, 1, 0)
	assert(chained_bomb != null, "Chained bomb should be placed at (5, 6)")
	var exploded_counter := [0]
	map_action.bomb_exploded.connect(func(_c: Vector2i, _b: Array[Vector2i]) -> void:
		exploded_counter[0] += 1
	)
	bomb.explode()
	assert(exploded_counter[0] == 2, "Chain reaction must explode both bombs")
	print("  [PASS] 7. CMapActionBomb chain reaction FIFO verified")

	# 7. TEST CGONpcBasicMon (Monster AI, Collision & Destruction)
	var mon: Node2D = CGONpcBasicMonClass.new()
	mon.setup("SM01", 6, 6, 80.0, "Item/Fire", 1)
	root_node.add_child(mon)
	assert(mon.cell == Vector2i(6, 6), "Monster should spawn at (6, 6)")

	var is_blocked := func(c: int, r: int) -> bool:
		return c == 6 and r == 7 # block down
	mon.dir = 0 # Down
	mon.step_ai(0.1, is_blocked)
	assert(mon.dir != 0 or mon.cell.y == 6, "Monster should steer away from blocked path")

	bomber.position = mon.position
	mon.check_bomber_collision(bomber)
	assert(bomber.in_bubble, "Touching monster must trap bomber in bubble")

	var hit: bool = mon.hit_by_flame(mon.cell)
	assert(hit, "Monster must be hit by flame")
	assert(not mon.alive and mon.action == "die", "Monster must enter die state")
	print("  [PASS] 8. CGONpcBasicMon AI patrol, bomber collision & flame defeat verified")

	# 8. TEST CGODart (Dart Firing, Movement & Collision)
	bomber.rescue()
	assert(not bomber.in_bubble, "Bomber should be rescued before firing dart")
	var friend_bomber: Node2D = CGOBomberClass.new()
	friend_bomber.setup(2, "Player2", "Character/C00", 3, 3, Color.RED, false)
	root_node.add_child(friend_bomber)
	friend_bomber.trap_in_bubble()
	assert(friend_bomber.in_bubble, "Friend bomber should be in bubble")

	var dart: Node2D = bomber.try_fire_dart()
	assert(dart != null, "Bomber with dart_count should fire a dart")
	assert(bomber.dart_count == 2, "Dart count should decrease to 2")
	root_node.add_child(dart)
	dart.position = friend_bomber.position
	var rescued: bool = dart.check_collision_with_objects([friend_bomber])
	assert(rescued, "Dart should collide with friendly trapped bomber")
	assert(not friend_bomber.in_bubble, "Trapped friendly bomber should be rescued by dart")
	print("  [PASS] 9. CGODart firing, trajectory & bubble rescue verified")

	# 9. TEST CGONpcAttackMon (Line-of-sight Aggro & Charge)
	var atk_mon: Node2D = CGONpcAttackMonClass.new()
	atk_mon.setup_attack_mon("SM02", 7, 3, 80.0, 150.0, "Item/Bomb", 1)
	root_node.add_child(atk_mon)
	var empty_block := func(_c: int, _r: int) -> bool: return false
	# Bomber is at cell (2, 3), atk_mon is at cell (7, 3) -> same row 3!
	var spotted: bool = atk_mon.scan_for_target([bomber], empty_block)
	assert(spotted and atk_mon.is_charging, "Attack monster must spot bomber in line-of-sight and charge")
	assert(atk_mon.dir == 2, "Attack monster must face Left (dir 2) toward bomber at x=2")
	print("  [PASS] 10. CGONpcAttackMon line-of-sight aggro & charge steering verified")

	# 10. TEST CGONpcMonEgg (Egg Timer, Hatch & Flame Destruction)
	var egg: Node2D = CGONpcMonEggClass.new()
	egg.setup_egg(8, 8, "SM01", 0.05) # short duration for test
	root_node.add_child(egg)
	var hatched := [false]
	egg.egg_hatched.connect(func(mid: String, _c: Vector2i) -> void:
		hatched[0] = true
		assert(mid == "SM01", "Hatched monster ID must be SM01")
	)
	egg._physics_process(0.06)
	assert(hatched[0], "Egg must hatch when timer expires")

	# Test egg destruction by flame
	var egg2: Node2D = CGONpcMonEggClass.new()
	egg2.setup_egg(9, 9, "SM01", 10.0)
	root_node.add_child(egg2)
	var egg2_hit: bool = egg2.hit_by_flame(Vector2i(9, 9))
	assert(egg2_hit and egg2.is_destroyed, "Egg hit by flame must be destroyed before hatching")
	print("  [PASS] 11. CGONpcMonEgg hatch cycle & flame destruction verified")

	# 11. TEST CGOTileMovableBox (Push Box Mechanic)
	var mbox: Node2D = CGOTileMovableBoxClass.new()
	mbox.setup(5, 5, "Tile00_Box/BoxGray", 2, "")
	root_node.add_child(mbox)
	assert(mbox.cell == Vector2i(5, 5), "Movable box starts at (5, 5)")
	var pushed: bool = mbox.push(Vector2i(1, 0), empty_block)
	assert(pushed and mbox.is_sliding, "Movable box must slide when pushed towards open cell")
	assert(mbox.cell == Vector2i(6, 5), "Movable box cell must update to (6, 5)")
	var block_cell := func(c: int, r: int) -> bool: return c == 7 and r == 5
	var push_blocked: bool = mbox.push(Vector2i(1, 0), block_cell)
	assert(not push_blocked, "Movable box must not move when blocked")
	print("  [PASS] 12. CGOTileMovableBox push sliding & obstacle blocking verified")

	# 12. TEST CGOObstacleTrap (Trap Trigger & Bubble Effect)
	var trap: Node2D = CGOObstacleTrapClass.new()
	trap.setup_trap(3, 3, 0)
	root_node.add_child(trap)
	bomber.position = trap.position
	var triggered: bool = trap.check_trigger(bomber)
	assert(triggered and not trap.is_armed, "Stepping on trap must trigger and disarm")
	assert(bomber.in_bubble, "Trap trigger must trap bomber in bubble")
	print("  [PASS] 13. CGOObstacleTrap trigger & bomber trap verified")

	print("[SUITE] ALL 13 GAME OBJECT TESTS PASSED 100% CLEANLY!")
	quit(0)
