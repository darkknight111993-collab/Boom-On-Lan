extends SceneTree

const CGOBomber = preload("res://scripts/objects/cgo_bomber.gd")
const CGOBomb = preload("res://scripts/objects/cgo_bomb.gd")
const CMapActionBomb = preload("res://scripts/objects/c_map_action_bomb.gd")

func _init() -> void:
	print("[KICK_PUNCH_TEST] Starting Kick & Punch Bomb verification...")

	# 1. Setup CMapActionBomb
	var root_node := Node2D.new()
	var map_action_bomb := CMapActionBomb.new()
	root_node.add_child(map_action_bomb)

	# Setup simple tile check callback: (5, 1) is a wall, others empty
	map_action_bomb.tile_check_callback = func(cell: Vector2i) -> int:
		if cell == Vector2i(5, 1):
			return 1 # Wall
		return 0

	# 2. Setup Bomber
	var bomber := CGOBomber.new()
	bomber.setup(0, "TestPlayer", "Character/C00", 1, 1, Color.RED)
	root_node.add_child(bomber)

	assert(not bomber.can_kick, "Bomber must NOT have kick by default")
	assert(not bomber.can_punch, "Bomber must NOT have punch by default")
	assert(not bomber.can_kick_bomb(), "can_kick_bomb() must be false initially")
	assert(not bomber.can_punch_bomb(), "can_punch_bomb() must be false initially")
	print("  [PASS] 1. Initial kick and punch abilities are false")

	# 3. Test apply_item
	bomber.apply_item("Item/ItemShoe")
	assert(bomber.can_kick, "apply_item(ItemShoe) must enable can_kick")
	assert(bomber.can_kick_bomb(), "can_kick_bomb() must be true")

	bomber.apply_item("Item/ItemPunch")
	assert(bomber.can_punch, "apply_item(ItemPunch) must enable can_punch")
	assert(bomber.can_punch_bomb(), "can_punch_bomb() must be true")
	print("  [PASS] 2. apply_item correctly activates ItemShoe and ItemPunch")

	# When riding mount, can_kick_bomb and can_punch_bomb must be false (sub_447AAF / sub_447B01)
	bomber.equip_mount("Turtle0")
	assert(not bomber.can_kick_bomb(), "Mounted bomber cannot kick bomb (sub_447AAF)")
	assert(not bomber.can_punch_bomb(), "Mounted bomber cannot punch bomb (sub_447B01)")
	bomber.destroy_mount()
	bomber.ship_dismount_ticks = 0 # reset for test
	assert(bomber.can_kick_bomb(), "Dismounted bomber can kick bomb again")
	assert(bomber.can_punch_bomb(), "Dismounted bomber can punch bomb again")
	print("  [PASS] 3. Mount correctly disables kick and punch (sub_447AAF & sub_447B01)")

	# 4. Test Kick Bomb slide
	# Place bomb at (2, 1)
	var bomb1: Node2D = map_action_bomb.place_bomb(2, 1, 1, 0)
	assert(bomb1 != null, "Bomb placed at (2, 1)")

	# Facing Right: dir_v = (1, 0). Wall at (5, 1). Free space up to (4, 1).
	var kick_target: Vector2i = map_action_bomb.trace_kick_target(2, 1, Vector2i(1, 0))
	assert(kick_target == Vector2i(4, 1), "Kick target must stop before wall at (4, 1), got %s" % str(kick_target))

	# Start slide
	bomb1.start_slide(Vector2i(1, 0), kick_target)
	assert(bomb1.bomb_state == CGOBomb.State.SLIDING, "Bomb state is SLIDING")
	
	# Simulate slide update until arrival
	for i in range(40):
		bomb1._on_update(0.016)
		if bomb1.bomb_state == CGOBomb.State.IDLE:
			break
	assert(bomb1.bomb_state == CGOBomb.State.IDLE, "Bomb finished sliding and returned to IDLE")
	assert(bomb1.cell == Vector2i(4, 1), "Bomb arrived at target cell (4, 1), got %s" % str(bomb1.cell))
	assert(map_action_bomb.has_bomb_at(4, 1), "map_action_bomb tracks bomb at (4, 1)")
	assert(not map_action_bomb.has_bomb_at(2, 1), "map_action_bomb no longer has bomb at (2, 1)")
	print("  [PASS] 4. Kick bomb sliding physics & grid tracking verified cleanly")

	# 5. Test Punch Bomb throw (3-tile leap + map wrapping)
	# Place bomb at (1, 5)
	var bomb2: Node2D = map_action_bomb.place_bomb(1, 5, 1, 0)
	assert(bomb2 != null, "Bomb placed at (1, 5)")

	# Facing Right: dir_v = (1, 0). 3-tile leap forward reaches (4, 5) on open map
	var throw_target: Vector2i = map_action_bomb.trace_throw_target(1, 5, Vector2i(1, 0))
	assert(throw_target == Vector2i(4, 5), "Throw target leaps to (4, 5), got %s" % str(throw_target))

	# Test toroidal wrapping: throwing from (13, 5) facing right wraps around border and skips occupied (1, 5) to (2, 5)
	var wrap_target: Vector2i = map_action_bomb.trace_throw_target(13, 5, Vector2i(1, 0))
	assert(wrap_target == Vector2i(2, 5), "Throw target wraps around map border to (2, 5), got %s" % str(wrap_target))
	print("  [PASS] 5. Punch bomb toroidal map wrapping & obstacle skip verified cleanly (13, 5 -> 2, 5)")

	# Start throw
	map_action_bomb._active_bombs.erase(Vector2i(1, 5))
	bomb2.start_throw(throw_target.x, throw_target.y, Vector2i(1, 0))
	assert(bomb2.bomb_state == CGOBomb.State.THROWN, "Bomb state is THROWN")
	assert(bomb2.z_index == 20, "Bomb z_index raised to 20 during air flight")

	# Advance halfway through throw duration
	var half_dur: float = bomb2.throw_duration * 0.5
	bomb2._on_update(half_dur)
	assert(bomb2.bomb_state == CGOBomb.State.THROWN, "Bomb still in flight at t=%f" % half_dur)

	# Finish throw
	bomb2._on_update(bomb2.throw_duration)
	assert(bomb2.bomb_state == CGOBomb.State.IDLE, "Bomb landed and returned to IDLE")
	assert(bomb2.cell == Vector2i(4, 5), "Bomb arrived at landing cell (4, 5)")
	assert(bomb2.z_index == 1 + 5, "Bomb z_index restored to ground level")
	print("  [PASS] 6. Punch bomb parabolic arc trajectory & flight landing verified cleanly")

	print("[KICK_PUNCH_TEST] ALL KICK & PUNCH TESTS PASSED 100%!")
	quit(0)
