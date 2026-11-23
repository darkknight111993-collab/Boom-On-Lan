extends Node2D

const CGOGlyphClass = preload("res://scripts/objects/cgo_glyph.gd")
const ScreenScript = preload("res://scripts/screen.gd")
const MapViewScript = preload("res://scripts/map_view.gd")

func _ready() -> void:
	print("[VERIFY] Starting room lobby, team color, item shadow, and VN glyph verification...")

	# ---------------------------------------------------------
	# 1. Room lobby blink animation and team color selection
	# ---------------------------------------------------------
	var screen_node = Control.new()
	screen_node.set_script(ScreenScript)
	screen_node.screen = "prepare"
	add_child(screen_node)
	await get_tree().process_frame

	assert(screen_node._room_blink_frame == 0, "Initial blink frame must be 0")
	# Advance blink timer to cycle frames: 0 -> 1 -> 2 -> 1 -> 0
	screen_node._room_blink_timer = 0.0
	screen_node._room_blink_frame = 0
	screen_node._process(0.05) # cycle = 0.05 -> frame 1
	assert(screen_node._room_blink_frame == 1, "Blink frame must advance to 1")
	screen_node._process(0.10) # cycle = 0.15 -> frame 2
	assert(screen_node._room_blink_frame == 2, "Blink frame must advance to 2")
	screen_node._process(0.15) # cycle = 0.30 -> frame 1
	assert(screen_node._room_blink_frame == 1, "Blink frame must return to 1")
	screen_node._process(0.15) # cycle = 0.45 -> frame 0
	assert(screen_node._room_blink_frame == 0, "Blink frame must return to 0 and rest")
	print("  [PASS] 1. Room lobby blink animation cycles (0 -> 1 -> 2 -> 1 -> 0) cleanly")

	# Test team color change on prepare screen: 1:1 match with button colors
	# P1 changes to Yellow (Basic01)
	screen_node._apply_team_selection(1)
	assert(Session.team_color_idx == 1, "Session team color must be 1 (Yellow)")
	var s0_ad := screen_node.get_node_or_null("Slot0CharAdjust") as TextureRect
	var s1_ad := screen_node.get_node_or_null("Slot1CharAdjust") as TextureRect
	if s0_ad:
		assert(s0_ad.modulate == Session.get_team_color(1), "Slot 0 player layer modulate must match Yellow (1)")
	if s1_ad:
		# P2 must remain at its own team color (5: Blue), NOT modified by P1's change
		assert(s1_ad.modulate == Session.get_team_color(Session.user2_team_color_idx), "Slot 1 (P2/Bot) must keep its own team color")

	# P1 changes to Orange (Basic02)
	screen_node._apply_team_selection(2)
	assert(Session.team_color_idx == 2, "Session team color must be 2 (Orange)")
	if s0_ad:
		assert(s0_ad.modulate == Session.get_team_color(2), "Slot 0 player layer modulate must match Orange (2)")
	if s1_ad:
		assert(s1_ad.modulate == Session.get_team_color(Session.user2_team_color_idx), "Slot 1 (P2/Bot) must remain unchanged")

	print("  [PASS] 2. Team color 1:1 correspondence and independent P1-only color switching verified")

	# Test 2-team requirement before starting match
	Session.team_color_idx = 5 # same as P2 (both Blue)
	screen_node.on_action("goto:game_stage")
	assert(screen_node.dialogs._stack.size() > 0, "Must show notice dialog when all players are on the same team")
	screen_node.dialogs.close_top()

	Session.team_color_idx = 0 # different teams (P1: Red, P2: Blue)
	print("  [PASS] 2b. Start match requires at least 2 distinct teams before starting")
	screen_node.queue_free()

	# ---------------------------------------------------------
	# 2. Item Ground Shadow Alignment
	# ---------------------------------------------------------
	var map_view = Node2D.new()
	map_view.set_script(MapViewScript)
	map_view.embedded = true
	map_view.initial_map = "DevTest01"
	add_child(map_view)
	await get_tree().process_frame
	await get_tree().process_frame

	var before_count: int = map_view._floating_items.size()
	map_view.spawn_floating_item(Vector2i(3, 3), "Item/Bomb")
	assert(map_view._floating_items.size() == before_count + 1, "Floating item must be spawned")
	var it: Dictionary = map_view._floating_items.back()
	var sh: Sprite2D = it.shadow
	var expected_sh_x: float = it.px - (-13.0) # frame 7 offset.x is -13 => px + 13
	var expected_sh_y: float = it.py + 39.0 - 19.0 # frame 7 offset.y is 19 => py + 20
	assert(sh.position == Vector2(expected_sh_x, expected_sh_y), "Ground shadow position must be exactly at (px + 13, py + 20)")
	print("  [PASS] 3. Floating item ground shadow is properly positioned on ground tile at (px+13, py+20)")

	# ---------------------------------------------------------
	# 3. Match announcement glyphs (Start, Win, Lose, Draw)
	# ---------------------------------------------------------
	# Match start banner
	assert(map_view._start_banner != null, "Start banner must exist")
	assert(map_view._start_banner.position == Vector2.ZERO, "Start banner position must be Vector2.ZERO")
	assert(map_view._start_banner._letters.size() == 7, "Start banner has 7 letters ('BẮT ĐẦU!')")
	assert(map_view._start_banner.auto_free_delay == 2.8, "Start banner delay must be 2.8s matching CA.exe")
	for info in map_view._start_banner._letter_info:
		assert(info.anchor.y == 249.0, "Start glyph anchor Y must be 249 from CA.exe:77372")
	print("  [PASS] 4. Start banner positioned at Vector2.ZERO with 7 letters (Y=249, delay=2.8s)")

	# Win banner
	var win_glyph = CGOGlyphClass.create_win_glyph()
	add_child(win_glyph)
	assert(win_glyph._letters.size() == 6, "Win banner has 6 letters ('THẮNG!')")
	for info in win_glyph._letter_info:
		assert(info.anchor.y == 87.0, "Win glyph anchor Y must be 87 from CA.exe:77490")
	win_glyph.queue_free()
	print("  [PASS] 5. Win banner positioned with 6 letters ('THẮNG!', Y=87)")

	# Lose banner
	var lose_glyph = CGOGlyphClass.create_lose_glyph()
	add_child(lose_glyph)
	assert(lose_glyph._letters.size() == 8, "Lose banner has 8 letters ('THẤT BẠI!')")
	for info in lose_glyph._letter_info:
		assert(info.anchor.y == 96.0, "Lose glyph anchor Y must be 96 from CA.exe:77838")
	lose_glyph.queue_free()
	print("  [PASS] 6. Lose banner positioned with 8 letters ('THẤT BẠI!', Y=96)")

	# Draw banner
	var draw_glyph = CGOGlyphClass.create_draw_glyph()
	add_child(draw_glyph)
	assert(draw_glyph._letters.size() == 4, "Draw banner has 4 letters ('HÒA!')")
	for info in draw_glyph._letter_info:
		assert(info.anchor.y == 93.0, "Draw glyph anchor Y must be 93 from CA.exe:78032")
	draw_glyph.queue_free()
	print("  [PASS] 7. Draw banner positioned with 4 letters ('HÒA!', Y=93)")

	# ---------------------------------------------------------
	# 8. Room Host character position & bottom 3 character choices
	# ---------------------------------------------------------
	var test_screen = Control.new()
	test_screen.set_script(ScreenScript)
	test_screen.screen = "prepare"
	add_child(test_screen)
	await get_tree().process_frame

	var host_st := test_screen.get_node_or_null("Slot0CharStatic") as TextureRect
	assert(host_st != null, "Slot0CharStatic must exist")
	# With anchor0 = (56.0, 182.0) and C00 offset (8.0, 66.0), position is (48.0, 116.0)
	assert(host_st.position.x == 48.0, "Host character position X must be 48.0 (56 - 8)")

	var slots := Session.get_char_slots()
	assert(slots.size() >= 11, "Must have at least 11 character slots")
	assert(slots[8].char == "Character/C08", "Slot 8 must be Character/C08 (Thiên Sứ)")
	assert(slots[9].char == "Character/C09", "Slot 9 must be Character/C09 (Tí Điệu)")
	assert(slots[10].char == "Character/Random", "Slot 10 must be Character/Random (Ngẫu Nhiên)")

	# Verify selecting Random shows Question Mark (Prepare/PRE_Img frame 12), centered in slot recess and tinted by team color
	test_screen._apply_char_selection(10)
	var host_sh := test_screen.get_node_or_null("Slot0Shadow") as TextureRect
	var host_ad := test_screen.get_node_or_null("Slot0CharAdjust") as TextureRect
	assert(host_sh.texture == null, "Shadow must be null when Random is selected")
	assert(host_ad.texture == null, "Char adjust layer must be null when Random is selected")
	assert(host_st.texture != null, "Question mark texture must be displayed when Random is selected")
	var qf := SpriteDB.get_frame("Prepare/PRE_Img", 12)
	assert(host_st.texture == qf.texture, "Slot 0 texture must match Prepare/PRE_Img frame 12")
	assert(host_st.position == Vector2(56.0, 116.0), "Question mark must be precisely centered in slot recess at (56.0, 116.0)")
	assert(host_st.modulate == Session.get_team_color(Session.team_color_idx), "Question mark must match current team color")

	# Test team color change modulates question mark
	test_screen._apply_team_selection(2) # Orange
	assert(host_st.modulate == Session.get_team_color(2), "Question mark must update to Orange team color")
	test_screen._apply_team_selection(5) # Blue
	assert(host_st.modulate == Session.get_team_color(5), "Question mark must update to Blue team color")

	# Switch back to Slot 0 (C00) and verify character static resets to WHITE and adjust layer has team color
	test_screen._apply_char_selection(0)
	assert(host_sh.texture != null, "Shadow must be restored when normal character is selected")
	assert(host_ad.texture != null, "Adjust layer must be restored when normal character is selected")
	assert(host_st.position == Vector2(48.0, 116.0), "Host character position must return to (48.0, 116.0)")
	assert(host_st.modulate == Color.WHITE, "Static character layer must reset to Color.WHITE")
	assert(host_ad.modulate == Session.get_team_color(5), "Adjust layer must retain current team color (Blue)")
	print("  [PASS] 8. Room host position, Random question mark centering (56, 116), and team color modulation verified")
	test_screen.queue_free()

	# ---------------------------------------------------------
	# 9. Random character weighted probability (Lodumani C14 & Santa C15 rare)
	# ---------------------------------------------------------
	var counts := {}
	var total_rolls := 2000
	for i in total_rolls:
		var c := Session.roll_random_character()
		counts[c] = counts.get(c, 0) + 1

	var c14_count: int = counts.get("Character/C14", 0)
	var c15_count: int = counts.get("Character/C15", 0)
	var c00_count: int = counts.get("Character/C00", 0)
	# Default character (weight 10/106 ~ 9.4% -> ~188 expected): must be significantly higher than rare (3/106 ~ 2.8% -> ~56 expected)
	assert(c14_count > 0, "Lodumani must be rollable in random character pool")
	assert(c15_count > 0, "Santa must be rollable in random character pool")
	assert(c00_count > c14_count * 1.5, "Default character C00 must roll significantly more often than rare Lodumani C14")
	assert(c00_count > c15_count * 1.5, "Default character C00 must roll significantly more often than rare Santa C15")
	print("  [PASS] 9. Random weighted roll: C00 (%d) >> Lodumani C14 (%d) and Santa C15 (%d)" % [c00_count, c14_count, c15_count])

	# ---------------------------------------------------------
	# 10. Match Clock freeze during start delay and return-to-room timer
	# ---------------------------------------------------------
	map_view._process(1.0)
	# During start banner delay (2.8s), match countdown must remain frozen at 180.0
	assert(map_view._match_seconds_left == 180.0, "Match timer must not count down while start banner is active")
	map_view._start_banner = null
	map_view._players[0].start_ticks = 0
	map_view._process(1.0)
	# Now that match started, countdown decrements
	assert(map_view._match_seconds_left < 180.0, "Match timer must decrement once match begins")

	# Check post-match return to room timer
	map_view._match_over = true
	map_view._match_over_timer = 0.0
	map_view._process(2.0)
	assert(map_view._match_over_timer >= 2.0, "Post-match return timer must accumulate")
	print("  [PASS] 10. Match countdown clock frozen at 180 during start delay & post-match return timer accumulates")

	map_view.queue_free()
	print("[VERIFY] ALL ROOM LOBBY, CHARACTER SELECTION, RANDOM ROLL, AND MATCH CLOCK CHECKS PASSED 100%!")
	get_tree().quit(0)
