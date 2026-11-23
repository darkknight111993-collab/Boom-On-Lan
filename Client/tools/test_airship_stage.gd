extends Node2D

## Playable TestAirship01 stage root.
## - Interactive (Godot Editor F6): plays normally with 0 interference.
## - Headless (`godot --headless --path Client res://scenes/test_airship_stage.tscn`):
##   runs automated assertions and exits cleanly.

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		return

	print("[TEST] Verifying TestAirship01 isolated test stage...")
	var map_view: Node2D = get_node("MapView")
	assert(map_view != null, "MapView node must exist")

	# 1. Verify isolated player/NPC/bot state
	assert(map_view._players.size() == 1, "Must spawn exactly 1 player (no P2/bots)")
	assert(map_view._monsters.is_empty(), "Must spawn 0 monsters")
	var p1: CGOBomber = map_view._players[0]
	assert(p1.cell == Vector2i(1, 1), "Player 1 must spawn at (1, 1)")
	print("  [PASS] 1. Isolated 1P spawn at (1, 1), 0 bots, 0 monsters")

	# 2. Verify all 11 mount items exist on map (and 0 unrelated items)
	const EXPECTED_MOUNTS := [
		"Item/Airship", "Item/AirshipBroken", "Item/Owl",
		"Item/Turtle0", "Item/Turtle1", "Item/Octopus0", "Item/Octopus1",
		"Item/RailCar", "Item/Chicken", "Item/Kart", "Item/Tank"
	]
	assert(map_view._floating_items.size() == EXPECTED_MOUNTS.size(), "Must have all 11 mount items on map")
	for it: Dictionary in map_view._floating_items:
		var code: String = str(it.item_code)
		assert(EXPECTED_MOUNTS.has(code), "Unexpected non-mount item: " + code)
	print("  [PASS] 2. All 11 mount items spawned on map")

	# 3. Verify tile walkability BEFORE picking up Airship
	assert(map_view.get_tile_kind(5, 3) == 2, "Cell (5, 3) must be a breakable box")
	assert(map_view.get_tile_kind(7, 3) == 1, "Cell (7, 3) must be a solid wall")
	assert(map_view.is_tile_walkable(5, 3, p1.player_id) == false, "On foot: breakable box must block")
	assert(map_view.is_tile_walkable(7, 3, p1.player_id) == false, "On foot: solid wall must block")
	print("  [PASS] 3. On-foot collision verified (box & wall blocked)")

	# 4. Walk onto (2, 1) and pick up Item/Airship
	p1.set_cell(2, 1)
	map_view._check_item_pickup(p1)
	assert(p1.mount != null and p1.mount.get("short_name") == "Airship", "Player 1 must mount Airship")
	assert(p1.get_effective_speed() == 10, "Airship speed must be 10")
	assert(p1.can_pass_box() == true, "Airship must grant m_fAbPassBox")
	assert(p1.can_eat_item() == false, "Airship must set m_fAbNotEatItem")
	assert(map_view._floating_items.size() == EXPECTED_MOUNTS.size() - 1, "Picked-up Airship item must be removed")
	print("  [PASS] 4. Picked up Item/Airship -> mounted Ship/Airship (speed=10)")

	# 5. Verify tile walkability WHILE riding Airship (TV-10)
	assert(map_view.is_tile_walkable(5, 3, p1.player_id) == true, "Airship must fly over breakable box (5, 3)")
	assert(map_view.is_tile_walkable(7, 3, p1.player_id) == false, "Airship must still be blocked by solid wall (7, 3)")
	assert(map_view.is_tile_walkable(0, 0, p1.player_id) == false, "Airship must still be blocked by border wall (0, 0)")
	print("  [PASS] 5. Airship collision verified (passes boxes, blocked by walls)")

	# 6. Verify m_fAbNotEatItem: walking onto Item/AirshipBroken at (4, 1) does NOT eat it
	p1.set_cell(4, 1)
	map_view._check_item_pickup(p1)
	assert(map_view._floating_items.size() == EXPECTED_MOUNTS.size() - 1, "Ground item must remain untouched while m_fAbNotEatItem=true")
	assert(p1.mount.get("short_name") == "Airship", "Existing Airship mount must not be replaced")
	print("  [PASS] 6. m_fAbNotEatItem verified (ground item ignored while riding)")

	# 7. Verify TV-11: bomb placement blocked while hovering over breakable box (5, 3), allowed on open ground (3, 1)
	p1.start_ticks = 0
	p1.set_cell(5, 3)
	map_view._place_bomb(p1)
	assert(p1.active_bombs == 0, "TV-11: Bomb must NOT be placed on top of breakable box (5, 3)")
	p1.set_cell(3, 1)
	map_view._place_bomb(p1)
	assert(p1.active_bombs == 1, "TV-11: Bomb MUST be placed on open ground (3, 1) while riding Airship")
	print("  [PASS] 7. TV-11 verified (bomb blocked on box, allowed on open ground)")

	# 8. Verify TV-10: dismount while hovering over breakable box (5, 3) snaps bomber to open cell
	p1.set_cell(5, 3)
	map_view._destroy_player_mount(p1)
	assert(p1.mount == null, "TV-10: Mount must be destroyed")
	assert(map_view.get_tile_kind(p1.cell.x, p1.cell.y) == 0, "TV-10: Bomber must snap out of box to open cell")
	print("  [PASS] 8. TV-10 verified (dismount over box snapped to safe cell %s)" % str(p1.cell))

	# 9. Verify Herb00 bush concealment & bush-to-bush shake on (2, 7) -> (3, 7) (sub_59F04D / sub_5C1175)
	assert(map_view.get_tile_kind(2, 7) == 3 and map_view.is_tile_concealing(2, 7) == true, "Cell (2, 7) must be concealing Herb00 bush")
	var herb_sp: Sprite2D = map_view._passable_objects[Vector2i(2, 7)].sprite
	var herb_idle_pos: Vector2 = herb_sp.position
	p1.set_cell(2, 7)
	map_view._update_player_bush_state(p1, Vector2(1, 0))
	assert(p1.in_bush == true and p1.is_bomber_visible() == false, "Entering Herb00 bush must conceal bomber")
	assert(p1.sp_static.visible == false and p1.sp_adjust.visible == false and p1.name_lbl.visible == false, "Entering Herb00 must hide bomber sprites & label")
	assert(map_view._passable_objects[Vector2i(2, 7)].state_name == "ShakenHorz", "Entering Herb00@(2,7) horizontally must trigger ShakenHorz")
	assert(herb_sp.position != herb_idle_pos, "ShakenHorz frame 1 must visually offset Herb00 sprite by 4px (f.offset vs f.pivot)")
	p1.set_cell(3, 7)
	map_view._update_player_bush_state(p1, Vector2(1, 0))
	assert(map_view._passable_objects[Vector2i(3, 7)].state_name == "ShakenHorz", "Walking bush-to-bush must shake Herb00@(3,7) too")
	p1.set_cell(1, 7)
	map_view._update_player_bush_state(p1, Vector2(-1, 0))
	assert(p1.in_bush == false and p1.is_bomber_visible() == true, "Leaving Herb00 bush must reveal bomber")
	assert(p1.sp_static.visible == true and p1.sp_adjust.visible == true and p1.name_lbl.visible == true, "Leaving Herb00 must restore on-foot sprites & label")
	print("  [PASS] 9. Herb00 bush concealment & bush-to-bush shake verified at (2, 7) -> (3, 7)")

	# 10. Verify MoveAbleBox push (including INTO Herb00 bush + concealment), StrongBox02 multi-hit & Herb00 flame burn on stage
	assert(map_view.push_movable_box(Vector2i(2, 8), Vector2i(3, 8)) == true, "BoxGray@(2,8) must push to (3,8)")
	assert(map_view.is_flame_blocked(2, 8) == false and map_view.is_flame_blocked(3, 8) == true, "Flame-block grid must move with BoxGray")
	assert(map_view.push_movable_box(Vector2i(3, 8), Vector2i(3, 7)) == true, "BoxGray@(3,8) must push INTO Herb00@(3,7) passable layer")
	assert((map_view._cell_objects[Vector2i(3, 7)].sprite as Sprite2D).visible == false, "BoxGray inside Herb00@(3,7) must be concealed (0x5C0C2E)")
	assert(map_view._passable_objects[Vector2i(3, 7)].state_name == "ShakenVert", "Pushing BoxGray vertically into Herb00@(3,7) must trigger ShakenVert")
	var strong2_tile = map_view._tiles.get(Vector2i(4, 8), null)
	assert(strong2_tile != null and strong2_tile.hp == 2, "StrongBox02@(4,8) must start with hp=2")
	map_view.break_box(Vector2i(4, 8))
	assert(strong2_tile.hp == 1 and map_view.is_flame_blocked(4, 8) == true, "StrongBox02 hit #1 must survive")
	var strong2_entry: Dictionary = map_view._cell_objects[Vector2i(4, 8)]
	assert(strong2_entry.state_name == "Default01_Shaken" and strong2_entry.next_state == "Default02", "StrongBox02 hit #1 must play Default01_Shaken -> Default02")
	map_view.break_box(Vector2i(4, 8))
	assert(strong2_tile.hp == 0 and map_view.is_flame_blocked(4, 8) == false, "StrongBox02 hit #2 must break")
	var bush_blast: Array[Vector2i] = [Vector2i(2, 7)]
	# Verify bomb & item concealment inside Herb00@(2,7) before burning it (b[16]==0, b[17]==0)
	var b_bush: Node2D = map_view._map_action_bomb.place_bomb(2, 7, 1, p1.player_id)
	assert(b_bush != null and b_bush.visible == false, "Bomb inside Herb00@(2,7) must be concealed (b[17]==0)")
	map_view._on_map_action_bomb_exploded(Vector2i(2, 7), bush_blast)
	assert(map_view.is_tile_concealing(2, 7) == false, "Herb00@(2,7) must burn away on flame hit")
	assert(b_bush.visible == true, "Burning Herb00@(2,7) must reveal concealed bomb inside")
	map_view._map_action_bomb._active_bombs.erase(Vector2i(2, 7))
	b_bush.queue_free()
	var exp_tile = map_view._tiles.get(Vector2i(8, 8), null)
	assert(exp_tile != null and exp_tile.explode_on_break == true, "ExplodeBlock01@(8,8) must have explode_on_break=true")
	var chain_exploded := [false]
	map_view._map_action_bomb.bomb_exploded.connect(func(c: Vector2i, _cells: Array[Vector2i]) -> void:
		if c == Vector2i(8, 8):
			chain_exploded[0] = true
	)
	exp_tile.on_hit()
	exp_tile.finish_break()
	assert(chain_exploded[0] == true, "ExplodeBlock01@(8,8) must trigger real map chain explosion")
	print("  [PASS] 10. MoveAbleBox push, StrongBox02 2-hit, Herb00 flame-burn & ExplodeBlock01 chain verified")

	print("[TEST] ALL TESTAIRSHIP01 STAGE CHECKS PASSED!")
	get_tree().quit(0)
