extends SceneTree

const CMapActionBombClass = preload("res://scripts/objects/c_map_action_bomb.gd")

func _init() -> void:
	print("[TEST] Initializing test_bomb_objects...")
	var map_action: Node2D = CMapActionBombClass.new()
	root.add_child(map_action)
	
	# Test 1: Bomb Placement & Anchor Coordinate Formula (40*col, 40*row + 39)
	var bomb: Node2D = map_action.place_bomb(3, 4, 2, 0, "Bomb/Bomb00")
	if bomb == null:
		push_error("Bomb failed to place")
		quit(1)
		return

	if not map_action.has_bomb_at(3, 4):
		push_error("Bomb missing from active bombs dictionary")
		quit(1)
		return

	var expected_pos := Vector2(20 + 3 * 40, 41 + 4 * 40 + 39)
	if bomb.position != expected_pos:
		push_error("Bomb anchor pos mismatch! Expected: %s, Got: %s" % [expected_pos, bomb.position])
		quit(1)
		return

	print("[TEST] Bomb 1 placed at cell: %s, anchor pos: %s (VERIFIED)" % [bomb.cell, bomb.position])

	# Test 2: Chain Reaction with Bomb 2 at (3, 5)
	var bomb2: Node2D = map_action.place_bomb(3, 5, 1, 0, "Bomb/Bomb00")
	if bomb2 == null:
		push_error("Bomb 2 failed to place")
		quit(1)
		return

	print("[TEST] Bomb 2 placed at cell: (3, 5) for chain reaction test")

	# Test 3: Trigger explosion on Bomb 1 and verify chain reaction
	var exploded_counter := [0]
	map_action.bomb_exploded.connect(func(center: Vector2i, _blast: Array[Vector2i]) -> void:
		exploded_counter[0] += 1
		print("[TEST] Event: Bomb exploded at %s" % center)
	)

	bomb.explode()

	if map_action.has_bomb_at(3, 4) or map_action.has_bomb_at(3, 5):
		push_error("Both bombs should be exploded and cleared from active bombs")
		quit(1)
		return

	if exploded_counter[0] < 2:
		push_error("Chain reaction failed to trigger second bomb explosion")
		quit(1)
		return

	print("[TEST] All bomb object tests PASSED cleanly! (Exploded count: %d)" % exploded_counter[0])
	quit(0)
