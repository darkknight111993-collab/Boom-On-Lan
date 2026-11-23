extends SceneTree

const CGOItemBoxClass = preload("res://scripts/objects/cgo_item_box.gd")
const CGameItemManClass = preload("res://scripts/objects/c_game_item_man.gd")
const CGOBomberClass = preload("res://scripts/objects/cgo_bomber.gd")
const CGOTileGroundClass = preload("res://scripts/objects/cgo_tile_ground.gd")
const CTileInfoClass = preload("res://scripts/objects/ctile_info.gd")

func _init() -> void:
	print("[TEST] Running Active Item Box (CGOItemBox) & CGameItemMan tests (TV-I1..TV-I8)...")

	# TV-I1: CGOItemBox 24-slot capacity, merge & bounds (0x5B70E6 / 0x5B75BD / 0x5B8396)
	var box := CGOItemBoxClass.new()
	assert(box.slots.size() == 24, "TV-I1: CGOItemBox has 24 slots")
	assert(box.get_slot(-1).is_empty() and box.get_slot(24).is_empty(), "TV-I1: Out-of-range get_slot")
	assert(box.get_slot_count(-1) == 0 and box.get_slot_count(24) == 0, "TV-I1: Out-of-range get_slot_count")
	var s_ban: int = box.add_item("Banana3")
	assert(s_ban == 0 and box.get_slot_count(s_ban) == 3, "TV-I1: Banana3 allocates slot 0 with 3 charges")
	var s_ban2: int = box.add_item("Banana2")
	assert(s_ban2 == 0 and box.get_slot_count(s_ban) == 5, "TV-I1: Banana2 merges into Banana slot (count=5)")
	print("  [PASS] TV-I1: CGOItemBox 24-slot capacity, merge & bounds (0x5B70E6/0x5B75BD/0x5B8396)")

	# TV-I2: Two-tier context_slot vs manual_slot fallback (0x5B836B / 0x5B7F91 / 0x5B877C)
	var s_ndl: int = box.add_item("Item/ItemNiddle")
	assert(box.select_manual_slot(s_ban) and box.manual_slot == s_ban, "TV-I2: Manual slot set to Banana")
	assert(box.select_slot(s_ndl) and box.context_slot == s_ndl, "TV-I2: Context slot set to Needle")
	assert(box.get_active_slot() == s_ndl, "TV-I2: Active slot prefers context_slot (0x5B836B)")
	var used: Dictionary = box.consume_selected()
	assert(str(used.get("name", "")) == "Item/ItemNiddle" and box.context_slot == -1, "TV-I2: Consuming clears context_slot (0x5B87B1)")
	assert(box.get_active_slot() == s_ban, "TV-I2: Falls back to manual_slot (Banana)")
	print("  [PASS] TV-I2: Two-tier context_slot -> manual_slot fallback (0x5B836B/0x5B7F91/0x5B877C)")

	# TV-I3: Excluded cycle types (12/24) & 24-entry history ring (0x5B7582 / 0x5B84CB)
	var s_span: int = box.add_item("Item/ItemSpanner")
	var s_scan: int = box.add_item("Item/ItemScanner")
	assert(box.is_excluded_from_cycle(s_span) == true, "TV-I3: item_type 12 excluded (0x5B7582)")
	assert(box.is_excluded_from_cycle(s_scan) == true, "TV-I3: item_type 24 excluded (0x5B7582)")
	assert(box.is_excluded_from_cycle(s_ban) == false, "TV-I3: Banana not excluded")
	assert(box.manual_slot == s_ban, "TV-I3: Excluded items did not overwrite manual_slot")
	assert(box.history_ring.size() >= 1 and box.history_ring[box.history_ring.size() - 1] == s_ban, "TV-I3: history_ring tracks manual selections (0x5B84CB)")
	print("  [PASS] TV-I3: Excluded cycle types (12/24) & history_ring (0x5B7582/0x5B84CB)")

	# TV-I4: Bubble trap auto-select priority: Needle family -> Oxygen (0x59B51B / 0x59E53F)
	box.clear()
	var s_oxy: int = box.add_item("Item/ItemOxygen")
	var s_sj: int = box.add_item("Item/ItemSJNeedle1")
	assert(box.on_trapped_in_bubble() == true and box.get_active_slot() == s_sj, "TV-I4: Prefers Needle variant over Oxygen (0x59B51B)")
	box.consume_selected()
	assert(box.on_trapped_in_bubble() == true and box.get_active_slot() == s_oxy, "TV-I4: Falls back to Oxygen after Needle used (0x59E53F)")
	print("  [PASS] TV-I4: Bubble trap auto-select priority Needle -> Oxygen (0x59B51B/0x59E53F)")

	# TV-I5: Match start auto-select: Scanner -> Dart (0x5A517F)
	box.clear()
	var s_dart: int = box.add_item("Item/ItemDart")
	assert(box.on_match_start() == true and box.get_active_slot() == s_dart, "TV-I5: Selects Dart when no Scanner")
	var s_sc2: int = box.add_item("Item/ItemScanner")
	assert(box.on_match_start() == true and box.get_active_slot() == s_sc2, "TV-I5: Prefers Scanner over Dart (0x5A517F)")
	print("  [PASS] TV-I5: Match start auto-select Scanner -> Dart (0x5A517F)")

	# TV-I6: CGameItemMan ground trap placement, self-cell immunity & trigger (0x5BFE98 / 0x89B145 / 0x89B623)
	var man := CGameItemManClass.new()
	var bomber := CGOBomberClass.new()
	bomber.setup(0, "P1", "Character/C00", 2, 2, Color.RED)
	bomber.start_ticks = 0
	bomber.apply_item("Banana3")
	# Blocked wall cell fails without consuming charge
	assert(man.try_place_bomber_trap(bomber, CGOTileGroundClass.TRAP_BANANA, 15, 13, 1) == false, "TV-I6: Wall blocks trap placement")
	assert(bomber.banana_count == 3, "TV-I6: Failed placement preserves charge")
	# Open ground cell places trap, consumes 1 charge, grants self-immunity
	assert(man.try_place_bomber_trap(bomber, CGOTileGroundClass.TRAP_BANANA, 15, 13, 0) == true, "TV-I6: Ground trap placed")
	assert(bomber.banana_count == 2 and bomber._placed_trap_cell == Vector2i(2, 2), "TV-I6: Charge consumed & self-immunity set")
	assert(man.check_bomber_ground_trap(bomber, Vector2(1, 0), null, Callable(), bomber.position) == 0, "TV-I6: Self-immunity skips trigger (0x59C2B2)")
	# Leave and re-enter triggers Banana slide until wall
	bomber._placed_trap_cell = Vector2i(-1, -1)
	var stop_x: float = bomber.position.x + 45.0
	var triggered: int = man.check_bomber_ground_trap(
		bomber, Vector2(1, 0), null,
		func(pos: Vector2, _pid: int) -> bool: return pos.x <= stop_x,
		bomber.position
	)
	assert(triggered == CGOTileGroundClass.TRAP_BANANA and bomber.action == "slide_jump" and bomber.slide_ticks == 999, "TV-I6: Re-entry triggers Banana slide")
	for _t in range(8):
		bomber._on_tick()
	assert(bomber.slide_ticks == 0 and bomber.action == "idle", "TV-I6: Slide stops at obstacle (0x59E23F)")
	man.clear()
	print("  [PASS] TV-I6: CGameItemMan placement, self-immunity & Banana slide trigger (0x5BFE98/0x89B145/0x89B623)")

	# TV-I7: CGameItemMan.resolve_banana_slide_dir (0x593737)
	var conv_r: CTileInfoClass = CTileInfoClass.get_info("TileConv/ConvRR00") # visual dir Right(2) -> bomber dir Right(3)
	assert(CGameItemManClass.resolve_banana_slide_dir(0, Vector2(-1, 0), conv_r) == 2, "TV-I7: Active move_dir Left(2) wins")
	assert(CGameItemManClass.resolve_banana_slide_dir(0, Vector2.ZERO, conv_r) == 3, "TV-I7: Conveyor visual dir Right(3) when idle")
	assert(CGameItemManClass.resolve_banana_slide_dir(1, Vector2.ZERO, null) == 1, "TV-I7: Facing dir Up(1) on normal ground")
	print("  [PASS] TV-I7: CGameItemMan.resolve_banana_slide_dir priority verified (0x593737)")

	# TV-I8: CGOBomber backwards-compatible counts & HUD synced with item_box
	bomber.item_box.clear()
	bomber.apply_item("Item/ItemNiddle")
	bomber.apply_item("Item/ItemOxygen")
	bomber.apply_item("Item/ItemDart")
	bomber.apply_item("Banana2")
	bomber.apply_item("Item/ItemBond")
	bomber.apply_item("Item/ItemTrap")
	assert(bomber.needle_count == 1 and bomber.oxygen_count == 1 and bomber.dart_count == 3, "TV-I8: Consumable counts synced")
	assert(bomber.banana_count == 2 and bomber.bond_count == 3 and bomber.mine_count == 2, "TV-I8: Ground trap counts synced")
	var inv: Array[Dictionary] = bomber.get_inventory_slots()
	assert(inv.size() == 6 and int(inv[0].count) == 1 and int(inv[2].count) == 3 and int(inv[3].count) == 2, "TV-I8: 6-slot personal bar synced")
	bomber.trap_in_bubble()
	var qhud: Dictionary = bomber.get_quick_item_hud()
	assert(str(qhud.get("sprite", "")) == "Item/Niddle" and int(qhud.get("count", 0)) == 1, "TV-I8: Trapped HUD auto-selects Needle")
	bomber.free()
	CTileInfoClass._by_name.clear()
	print("  [PASS] TV-I8: CGOBomber properties, trap auto-select & HUD synced with CGOItemBox")

	print("[TEST] ALL ITEM BOX & GAME ITEM MANAGER TESTS PASSED!")
	quit(0)
