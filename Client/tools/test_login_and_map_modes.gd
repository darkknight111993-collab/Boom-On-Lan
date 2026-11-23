extends Node

func _ready() -> void:
	print("[VERIFY] Starting Login 1P/2P Switching & Game Modes Map List Verification...")
	var ScreenScript: GDScript = load("res://scripts/screen.gd")

	# =========================================================================
	# TEST 1: Login 1P <-> 2P Switching & Layout
	# =========================================================================
	var login_screen: Control = ScreenScript.new()
	login_screen.screen = "login"
	add_child(login_screen)
	await get_tree().process_frame

	var tbl := login_screen.get_node("log_table") as TextureRect
	var b1 := login_screen.get_node("btn_1p") as TextureButton
	var b2 := login_screen.get_node("btn_2p") as TextureButton
	var u1 := login_screen.get_node("user_id") as LineEdit
	var p1 := login_screen.get_node("password") as LineEdit
	var u2 := login_screen.get_node("user2_id") as LineEdit
	var p2 := login_screen.get_node("password2") as LineEdit
	var btn_login := login_screen.get_node("btn_login") as TextureButton

	# Initial 1P checks
	assert(tbl.position == Vector2(188, 413), "1P: Table pos must be (188, 413)")
	assert(tbl.size == Vector2(424, 137), "1P: Table size must be 424x137")
	assert(b1.visible and b2.visible, "1P: BOTH btn_1p and btn_2p must be visible simultaneously")
	assert(b1.disabled, "1P: btn_1p is disabled (active tab)")
	assert(not b2.disabled, "1P: btn_2p is enabled (clickable to switch to 2P)")
	assert(b1.position == Vector2(196, 437), "1P: btn_1p pos must be (196, 437)")
	assert(b2.position == Vector2(529, 437), "1P: btn_2p position must be (529, 437)")
	assert(u1.position == Vector2(403, 463), "1P: user_id position must be (403, 463)")
	assert(not u2.visible and not p2.visible, "1P: Player 2 inputs must be hidden")
	assert(not btn_login.disabled, "1P: Login button should be enabled with default credentials")
	print("  [PASS] 1. Initial 1P mode layout and simultaneous tab button visibility verified")

	# Switch to 2P
	login_screen.on_action("login_mode:2p")
	await get_tree().process_frame
	assert(tbl.position == Vector2(143, 413), "2P: Table pos must be (143, 413)")
	assert(tbl.size == Vector2(514, 137), "2P: Table size must be 514x137")
	assert(b1.visible and b2.visible, "2P: BOTH btn_1p and btn_2p must be visible simultaneously")
	assert(not b1.disabled, "2P: btn_1p is enabled (clickable to switch to 1P)")
	assert(b2.disabled, "2P: btn_2p is disabled (active tab)")
	assert(b1.position == Vector2(151, 437), "2P: btn_1p position must be (151, 437)")
	assert(b2.position == Vector2(572, 437), "2P: btn_2p position must be (572, 437)")
	assert(u1.position == Vector2(358, 463), "2P: user_id position must be (358, 463)")
	assert(u2.visible and p2.visible, "2P: Player 2 inputs must be visible")
	assert(u2.position == Vector2(451, 463), "2P: user2_id position must be (451, 463)")
	assert(not btn_login.disabled, "2P: Login button enabled with prefilled player 2 credentials")
	print("  [PASS] 2. Switch to 2P mode expands table, repositions fields, and swaps active tab")

	# Switch back to 1P
	login_screen.on_action("login_mode:1p")
	await get_tree().process_frame
	assert(tbl.position == Vector2(188, 413), "Back to 1P: Table pos must return to (188, 413)")
	assert(tbl.size == Vector2(424, 137), "Back to 1P: Table size must shrink back to 424x137")
	assert(b1.visible and b2.visible, "Back to 1P: BOTH buttons remain visible")
	assert(b1.disabled and not b2.disabled, "Back to 1P: 1P active/disabled, 2P clickable")
	assert(b1.position == Vector2(196, 437), "Back to 1P: btn_1p pos must return to (196, 437)")
	assert(b2.position == Vector2(529, 437), "Back to 1P: btn_2p pos must return to (529, 437)")
	assert(u1.position == Vector2(403, 463), "Back to 1P: user_id pos must return to (403, 463)")
	assert(not u2.visible and not p2.visible, "Back to 1P: Player 2 inputs must be hidden")
	print("  [PASS] 3. Switch back to 1P restores exact geometry without size leakage")

	# Multiple cycles stability
	for cycle in 5:
		login_screen.on_action("login_mode:2p")
		login_screen.on_action("login_mode:1p")
	assert(tbl.size == Vector2(424, 137), "Multi-cycle: Table size remains 424x137")
	print("  [PASS] 4. Multi-cycle switching stability confirmed")

	# =========================================================================
	# TEST 2: AuthService independent 1P and 2P session sync
	# =========================================================================
	var r1 := AuthService.login("HeroPlayer1", "pw1", 1)
	var r2 := AuthService.login("BuddyPlayer2", "pw2", 2)
	assert(r1.ok and r2.ok, "Both player logins must succeed")
	assert(Session.user_id == r1.user_id, "Player 1 user_id must NOT be overwritten by Player 2")
	assert(Session.nickname == "HeroPlayer1", "Player 1 nickname must remain HeroPlayer1")
	assert(Session.user2_id == r2.user_id, "Player 2 user2_id must match r2")
	assert(Session.nickname2 == "BuddyPlayer2", "Player 2 nickname2 must match BuddyPlayer2")
	print("  [PASS] 5. AuthService 1P & 2P independent session synchronization verified")

	login_screen.queue_free()

	# =========================================================================
	# TEST 3: Game Modes Definition JSON
	# =========================================================================
	var modes := Session.get_game_modes()
	assert(modes.size() >= 8, "game_modes.json must define at least 8 modes")
	var mode_ids := []
	for m in modes:
		mode_ids.append(m.get("id"))
	for expected_id in ["normal", "gametype", "battle", "monster2", "superf2", "zzolman", "snowball", "rpg"]:
		assert(mode_ids.has(expected_id), "Modes must include %s" % expected_id)
	print("  [PASS] 6. Game modes JSON definition (8 modes) loaded cleanly")

	# =========================================================================
	# TEST 4: Map Dialog Filtering per Game Mode
	# =========================================================================
	var prep_screen: Control = ScreenScript.new()
	prep_screen.screen = "prepare"
	add_child(prep_screen)
	await get_tree().process_frame

	var dialogs: DialogManager = prep_screen.dialogs

	# Case A: Normal mode (Đại Chiến)
	Session.game_mode = "normal"
	Session.selected_map = "Camp08"
	dialogs.open("select_map")
	await get_tree().process_frame

	var map_dlg := dialogs._stack.back().panel as Control
	var map_il := map_dlg.get_node("map_list") as ItemList
	var map_mode_lbl := map_dlg.get_node("map_mode") as Label
	var map_header_lbl := map_dlg.get_node("map_list_header") as Label

	assert(map_mode_lbl.text == "Đại Chiến", "Mode label must show 'Đại Chiến'")
	assert(map_il.item_count == 456, "Normal mode should contain 456 classic maps (got %d)" % map_il.item_count)
	assert(map_header_lbl.text.contains("Đại Chiến") and map_header_lbl.text.contains("456"), "Header must show mode name and count")
	# Ensure Camp08 is selected and at top of the list
	assert(dialogs._selected_map == "Camp08", "Camp08 must be selected in normal mode")
	assert(str(map_il.get_item_metadata(0)) == "Camp08", "Camp08 must be the first map in normal mode list")
	# Ensure non-PVP maps (boss, bonus, lobby, dev test, minigames) do NOT appear in normal mode
	var invalid_normal := ["Monster01", "Bonus01", "LobbySquare01", "DevTest01", "olympicRun01", "Square01", "shopmap01"]
	for i in map_il.item_count:
		var code := str(map_il.get_item_metadata(i))
		for bad in invalid_normal:
			assert(code != bad, "%s must NOT appear in normal mode map list" % bad)
	print("  [PASS] 7. Normal mode (Đại Chiến) map list filtered to 456 genuine PVP battle maps (Camp08 at top)")
	dialogs.close_top()

	# Case B: Monster2 mode (Săn Boss)
	Session.game_mode = "monster2"
	Session.selected_map = "Monster01"
	dialogs.open("select_map")
	await get_tree().process_frame

	var boss_dlg := dialogs._stack.back().panel as Control
	var boss_il := boss_dlg.get_node("map_list") as ItemList
	var boss_mode_lbl := boss_dlg.get_node("map_mode") as Label
	assert(boss_mode_lbl.text == "Săn Boss", "Mode label must show 'Săn Boss'")
	assert(boss_il.item_count == 289, "Monster2 mode should contain 289 boss maps (got %d)" % boss_il.item_count)
	assert(dialogs._selected_map == "Monster01", "Monster01 must be selected in monster2 mode")
	print("  [PASS] 8. Monster2 mode (Săn Boss) map list filtered to 289 boss maps")
	dialogs.close_top()

	# Case C: Snowball mode (Ném Tuyết)
	Session.game_mode = "snowball"
	dialogs.open("select_map")
	await get_tree().process_frame

	var snow_dlg := dialogs._stack.back().panel as Control
	var snow_il := snow_dlg.get_node("map_list") as ItemList
	var snow_mode_lbl := snow_dlg.get_node("map_mode") as Label
	assert(snow_mode_lbl.text == "Ném Tuyết", "Mode label must show 'Ném Tuyết'")
	assert(snow_il.item_count == 11, "Snowball mode should contain 11 maps (got %d)" % snow_il.item_count)
	assert(dialogs._selected_map == "SnowBallFight01", "SnowBallFight01 must be default selected")
	print("  [PASS] 9. Snowball mode (Ném Tuyết) map list filtered to 11 snowball maps")
	dialogs.close_top()

	# =========================================================================
	# TEST 10: Room Slot 0 & Slot 1 Character & Shadow Precise Alignment
	# =========================================================================
	var s0_sh := prep_screen.get_node("Slot0Shadow") as TextureRect
	var s0_st := prep_screen.get_node("Slot0CharStatic") as TextureRect
	var s1_sh := prep_screen.get_node("Slot1Shadow") as TextureRect
	var s1_st := prep_screen.get_node("Slot1CharStatic") as TextureRect

	# Slot 0 recess in Prepare/CAStage_1 is [27, 125], center = 76.0, pedestal floor = 182.0
	var s0_sh_center := s0_sh.position.x + 16.0 # shadow width 32
	var s0_sh_bottom := s0_sh.position.y + 15.0 # shadow height 15
	var s0_char_center := s0_st.position.x + 28.0 # canvas width 56, body center dx=28
	assert(absf(s0_sh_center - 76.0) < 0.5, "Slot 0 shadow center must be 76.0 (got %.1f)" % s0_sh_center)
	assert(absf(s0_sh_bottom - 182.0) < 0.5, "Slot 0 shadow bottom must be floor Y=182.0 (got %.1f)" % s0_sh_bottom)
	assert(absf(s0_char_center - 76.0) < 0.5, "Slot 0 character center must be 76.0 (got %.1f)" % s0_char_center)

	# Slot 1 recess in Prepare/CAStage_1 is [133, 231], center = 182.0, pedestal floor = 182.0
	var s1_sh_center := s1_sh.position.x + 16.0
	var s1_sh_bottom := s1_sh.position.y + 15.0
	var s1_char_center := s1_st.position.x + 28.0
	assert(absf(s1_sh_center - 182.0) < 0.5, "Slot 1 shadow center must be 182.0 (got %.1f)" % s1_sh_center)
	assert(absf(s1_sh_bottom - 182.0) < 0.5, "Slot 1 shadow bottom must be floor Y=182.0 (got %.1f)" % s1_sh_bottom)
	assert(absf(s1_char_center - 182.0) < 0.5, "Slot 1 character center must be 182.0 (got %.1f)" % s1_char_center)
	print("  [PASS] 10. Room Slot 0 & Slot 1 character body and shadow centered symmetrically on pedestals")

	prep_screen.queue_free()

	# =========================================================================
	# TEST 11: In-Match Items Hidden Behind Destructible Blocks
	# =========================================================================
	var MapViewClass: GDScript = load("res://scripts/map_view.gd")
	var mv = MapViewClass.new()
	mv.embedded = true
	mv.initial_map = "Camp08"
	add_child(mv)
	await get_tree().process_frame

	# On Camp08, cell (0, 0) and (0, 2) have blocks (objects) that contain pre-configured cell_items
	assert(mv._cell_objects.has(Vector2i(0, 0)), "Camp08 cell (0, 0) must have a destructible block")
	assert(mv._pending_cell_items.has(Vector2i(0, 0)), "Item at (0, 0) must be hidden in _pending_cell_items")
	
	# Verify that no visible floating item exists at (0, 0) while the block is standing
	var item_at_0_0_visible := false
	for it: Dictionary in mv._floating_items:
		if it.grid_pos == Vector2i(0, 0):
			item_at_0_0_visible = true
			break
	assert(not item_at_0_0_visible, "Item at (0, 0) must NOT be visible while block is standing")

	# Verify object block z-index is higher than items (z_index = 2 + y vs 1 + y)
	var block_0_0 = mv._cell_objects[Vector2i(0, 0)].sprite as Sprite2D
	assert(block_0_0.z_index >= 2, "Block z-index must be at least 2 + y (got %d)" % block_0_0.z_index)

	# Break the block at (0, 0) and advance frames until __remove__
	mv.break_box(Vector2i(0, 0))
	for f in 40:
		mv._process(0.016)

	# Now the block should be removed and the hidden item should have spawned!
	assert(not mv._cell_objects.has(Vector2i(0, 0)), "Block at (0, 0) must be destroyed and removed")
	var item_spawned := false
	for it: Dictionary in mv._floating_items:
		if it.grid_pos == Vector2i(0, 0):
			item_spawned = true
			break
	assert(item_spawned, "Hidden item at (0, 0) must spawn once the block is destroyed")
	print("  [PASS] 11. In-match items remain hidden behind blocks until destroyed")

	mv.queue_free()

	print("[VERIFY] ALL 11 LOGIN SWITCHING, ROOM POSITIONING, AND MATCH ITEM CHECKS PASSED 100%!")
	get_tree().quit(0)
