extends Node2D

func _ready() -> void:
	print("[INTEGRATION] Starting map_view + CMapActionBomb integration test...")
	var scene_res := load("res://scenes/map_view.tscn") as PackedScene
	if scene_res == null:
		push_error("Cannot load map_view.tscn")
		get_tree().quit(1)
		return

	var map_view = scene_res.instantiate()
	map_view.embedded = true
	map_view.initial_map = "Factory15"
	add_child(map_view)

	# Verify players spawned
	if map_view._players.is_empty():
		push_error("No players spawned in embedded mode")
		get_tree().quit(1)
		return
	print("  [PASS] Players spawned in Factory15: %d players" % map_view._players.size())

	# Test 1: Place a bomb via player 0
	var p1: CGOBomber = map_view._players[0]
	var p1_cell: Vector2i = p1.cell
	print("  Player 1 (%s) at cell: %s, bombs_cur: %d, active: %d" % [p1.player_name, p1_cell, p1.bombs_cur, p1.active_bombs])

	map_view._place_bomb(p1)
	if not map_view._map_action_bomb.has_bomb_at(p1_cell.x, p1_cell.y):
		push_error("Bomb failed to register in _map_action_bomb at player cell %s" % p1_cell)
		get_tree().quit(1)
		return

	if p1.active_bombs != 1:
		push_error("Player active_bombs should be 1, got: %d" % p1.active_bombs)
		get_tree().quit(1)
		return

	var placed_bomb = map_view._map_action_bomb.get_bomb_at(p1_cell.x, p1_cell.y)
	print("  [PASS] Bomb 1 placed successfully via _map_action_bomb at: %s" % placed_bomb.cell)

	# Test 2: Cannot place second bomb on same cell
	map_view._place_bomb(p1)
	if p1.active_bombs != 1:
		push_error("Duplicate bomb placement on same cell should be rejected")
		get_tree().quit(1)
		return
	print("  [PASS] Duplicate bomb placement on same cell blocked")

	# Test 3: Chain reaction with an adjacent bomb placed nearby
	var adj_cell := p1_cell + Vector2i(1, 0)
	var bomb2 = map_view._map_action_bomb.place_bomb(adj_cell.x, adj_cell.y, 2, 0)
	print("  Placed adjacent bomb 2 at: %s" % adj_cell)

	# Explode bomb 1 -> must chain explode bomb 2
	print("  Triggering explosion on bomb 1...")
	placed_bomb.explode()

	if p1.active_bombs != 0:
		push_error("Player active_bombs should return to 0 after explosion, got: %d" % p1.active_bombs)
		get_tree().quit(1)
		return

	if map_view._map_action_bomb.has_bomb_at(p1_cell.x, p1_cell.y) or map_view._map_action_bomb.has_bomb_at(adj_cell.x, adj_cell.y):
		push_error("Both bombs should be cleared from active grid after chain explosion")
		get_tree().quit(1)
		return

	print("  [PASS] Chain explosion cleared both bombs and reset player active count")
	print("[INTEGRATION] ALL MAP_VIEW INTEGRATION TESTS PASSED 100%!")
	get_tree().quit(0)
