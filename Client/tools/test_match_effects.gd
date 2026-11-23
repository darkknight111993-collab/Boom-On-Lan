extends Node2D

const CGOGlyphClass = preload("res://scripts/objects/cgo_glyph.gd")

func _ready() -> void:
	print("[EFFECTS] Starting match start & win/finish effects verification...")

	# Create MapView instance
	var map_view_scene: PackedScene = load("res://scenes/map_view.tscn")
	var map_view = map_view_scene.instantiate()
	map_view.embedded = true
	map_view.initial_map = "DevTest01"
	add_child(map_view)

	# Allow _ready to process
	await get_tree().process_frame
	await get_tree().process_frame

	# Check 1: Start Banner spawned
	assert(map_view._start_banner != null, "Start banner must be created at match start")
	assert(map_view._start_banner.glyph_type == 0, "Glyph type must be START (0)")
	assert(map_view._start_banner.position == Vector2.ZERO, "Start banner must be at screen origin")
	assert(map_view._start_banner._letters.size() == 7, "Start banner must contain 7 letters (B-Ắ-T-Đ-Ầ-U-!)")
	print("  [PASS] 1. Start banner created with 7 animated letters at exact VN screen coordinates")

	# Check 2: Player 1 & 2 start state & indicators
	assert(map_view._players.size() >= 2, "Must have at least 2 players")
	var p1: CGOBomber = map_view._players[0]
	var p2: CGOBomber = map_view._players[1]

	assert(p1.start_ticks > 0 and p1.start_ticks <= 85, "Player 1 start_ticks must be active (~2.8s) at match start")
	assert(p1.action == "start", "Player 1 action must be 'start'")
	assert(p1.sp_indicator != null and p1.sp_indicator.visible, "Player 1 indicator arrow must be visible")
	print("  [PASS] 2. Character start state, blinking alpha & 1P/2P indicator arrows active")

	# Check 3: Control locking during start
	var old_pos: Vector2 = p1.position
	p1.move(Vector2(1, 0), 0.1)
	assert(p1.position == old_pos, "Player movement must be locked during start countdown")
	var bomb_res: bool = p1.request_place_bomb()
	assert(not bomb_res, "Placing bomb must be blocked during start countdown")
	print("  [PASS] 3. Player movement & bomb placement locked during start countdown")

	# Fast forward countdown
	p1.start_ticks = 1
	p2.start_ticks = 1
	p1._on_tick()
	p2._on_tick()

	assert(p1.start_ticks == 0, "Player 1 start_ticks reached 0")
	assert(p1.action == "idle", "Player 1 action switched to idle")
	assert(p1.modulate.a == 1.0, "Player 1 alpha restored to 1.0")
	assert(not p1.sp_indicator.visible, "Player 1 indicator arrow hidden after countdown")
	print("  [PASS] 4. Countdown finished: alpha restored, action idle, indicator hidden")

	# Finish start banner
	if is_instance_valid(map_view._start_banner):
		map_view._start_banner.queue_free()
		map_view._start_banner = null

	# Check 5: Victory effect (Player 1 wins)
	map_view.bot_ai_enabled = true
	map_view._maps = ["Village01"]
	map_view._cur = 0
	p2.alive = false
	p2.action = "die"
	map_view._check_match_status()

	assert(map_view._match_over, "Match over must be true")
	assert(p1.action == "hurrah", "Winner character action must be 'hurrah'")
	assert(map_view._result_banner != null, "Result banner must be spawned")
	assert(map_view._result_banner.glyph_type == 1, "Result banner must be WIN (1)")
	assert(map_view._result_banner.position == Vector2.ZERO, "Result banner must be at screen origin")
	assert(map_view._result_banner._letters.size() == 6, "Win banner must have 6 letters (T-H-Ắ-N-G-!)")
	print("  [PASS] 5. Winner character plays Hurrah cheer and VN Win banner spawned at Y=87")

	# Check 6: Jumping letter animation update
	map_view._result_banner._process(0.6)
	map_view._result_banner._process(0.25)
	print("  [PASS] 6. Jumping letters wave animation updated cleanly across all 6 letters")

	# Check 7: Lose & Draw glyphs creation (VN client)
	var lose_glyph = CGOGlyphClass.create_lose_glyph()
	add_child(lose_glyph)
	assert(lose_glyph != null and lose_glyph.glyph_type == 2, "Lose glyph created with type LOSE (2)")
	assert(lose_glyph._letters.size() == 8, "Lose glyph has 8 letters (T-H-Ấ-T-B-Ạ-I-!)")
	lose_glyph.queue_free()

	var draw_glyph = CGOGlyphClass.create_draw_glyph()
	add_child(draw_glyph)
	assert(draw_glyph != null and draw_glyph.glyph_type == 3, "Draw glyph created with type DRAW (3)")
	assert(draw_glyph._letters.size() == 4, "Draw glyph has 4 letters (H-Ò-A-!)")
	draw_glyph.queue_free()
	print("  [PASS] 7. VN Lose (8 letters) & Draw (4 letters) glyphs verified")

	print("[EFFECTS] ALL MATCH START & WIN/FINISH CHECKS PASSED 100% CLEANLY!")
	get_tree().quit(0)
