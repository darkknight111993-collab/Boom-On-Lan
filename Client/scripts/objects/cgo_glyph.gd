class_name CGOGlyph
extends Node2D

## Reconstructed BnB match announcement glyphs from CA.exe:
## - CGOStartGlyph ("Game/Start" letters with drop & scale)
## - CGOWinGlyph ("Game/Win" letters with dynamic sequential wave-jump)
## - CGOLoseGlyph ("Game/Lose" letters with droop/fade)
## - CGODrawGlyph ("Game/Draw" letters)
## Exact screen coordinates from CA.exe (CRenderD3D9 draw_pos = anchor - offset)

signal finished

enum GlyphType { START, WIN, LOSE, DRAW }

@export var glyph_type: GlyphType = GlyphType.START
@export var auto_free_delay: float = 0.0 # 0.0 = do not auto free (used for match result)

var _letters: Array[Sprite2D] = []
var _letter_info: Array[Dictionary] = []
var _age: float = 0.0
var _jump_idx: int = 0
var _jump_timer: float = 0.0
var _sdb: Object = null

static func create_start_glyph() -> Node2D:
	var g = new()
	g.glyph_type = GlyphType.START
	g.auto_free_delay = 2.8
	return g

static func create_win_glyph() -> Node2D:
	var g = new()
	g.glyph_type = GlyphType.WIN
	g.auto_free_delay = 0.0 # Persistent until stage transition
	return g

static func create_lose_glyph() -> Node2D:
	var g = new()
	g.glyph_type = GlyphType.LOSE
	g.auto_free_delay = 0.0
	return g

static func create_draw_glyph() -> Node2D:
	var g = new()
	g.glyph_type = GlyphType.DRAW
	g.auto_free_delay = 0.0
	return g

func _ready() -> void:
	z_index = 350
	_sdb = _get_sprite_db()
	_setup_glyph()

func _get_sprite_db() -> Object:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("SpriteDB"):
		return (ml as SceneTree).root.get_node("SpriteDB")
	var sdb_class = preload("res://scripts/sprite_db.gd")
	return sdb_class.new()

func _setup_glyph() -> void:
	match glyph_type:
		GlyphType.START:
			_setup_start()
		GlyphType.WIN:
			_setup_win()
		GlyphType.LOSE:
			_setup_lose()
		GlyphType.DRAW:
			_setup_draw()

func _setup_start() -> void:
	var sp_path := "Game/Start"
	# Exact screen coordinates from CA.exe CGOStartGlyph sub_5CDBD9(64) Vietnam (line 77372):
	# X: [140, 185, 231, 291, 345, 397, 463], Y: 249 ("BẮT ĐẦU!")
	var anchors := [
		Vector2(140.0, 249.0),
		Vector2(185.0, 249.0),
		Vector2(231.0, 249.0),
		Vector2(291.0, 249.0),
		Vector2(345.0, 249.0),
		Vector2(397.0, 249.0),
		Vector2(463.0, 249.0)
	]
	var frames := [0, 1, 2, 3, 4, 5, 6]

	for i in frames.size():
		var f_idx: int = frames[i]
		var f: Dictionary = _sdb.get_frame(sp_path, f_idx)
		if f.is_empty():
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.texture = f.texture
		# CRenderD3D9 draw_pos = anchor - offset
		var target_pos: Vector2 = anchors[i] - f.offset
		s.position = target_pos + Vector2(0, -60)
		s.modulate.a = 0.0
		add_child(s)
		_letters.append(s)
		_letter_info.append({"base_pos": target_pos, "anchor": anchors[i], "frame_norm": f_idx, "sprite_path": sp_path})

		# Pop/drop tween with bounce (stately cascading drop matching original BnB timing)
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(s, "position", target_pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.22)

func _setup_win() -> void:
	var sp_path := "Game/Win"
	# Exact screen coordinates from CA.exe CGOWinGlyph sub_5CDBD9(64) Vietnam (line 77490):
	# X: [148, 195, 248, 300, 353, 421], Y: 87 (6 letters: "THẮNG!")
	var anchors := [
		Vector2(148.0, 87.0),
		Vector2(195.0, 87.0),
		Vector2(248.0, 87.0),
		Vector2(300.0, 87.0),
		Vector2(353.0, 87.0),
		Vector2(421.0, 87.0)
	]
	var frames := [0, 1, 2, 3, 4, 5]

	for i in frames.size():
		var f_idx: int = frames[i]
		var f: Dictionary = _sdb.get_frame(sp_path, f_idx)
		if f.is_empty():
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.texture = f.texture
		var target_pos: Vector2 = anchors[i] - f.offset
		s.position = target_pos + Vector2(0, -70)
		s.modulate.a = 0.0
		add_child(s)
		_letters.append(s)
		_letter_info.append({"base_pos": target_pos, "anchor": anchors[i], "frame_norm": f_idx, "sprite_path": sp_path})

		# Drop-in bounce tween (stately cascading drop with punchy bounce)
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(s, "position", target_pos, 0.48).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.2)

func _setup_lose() -> void:
	var sp_path := "Game/Lose"
	# Exact screen coordinates from CA.exe CGOLoseGlyph sub_5CDBD9(64) Vietnam (line 77838):
	# X: [90, 132, 181, 244, 295, 349, 404, 462], Y: 96 (8 letters: "THẤT BẠI!")
	var anchors := [
		Vector2(90.0, 96.0),
		Vector2(132.0, 96.0),
		Vector2(181.0, 96.0),
		Vector2(244.0, 96.0),
		Vector2(295.0, 96.0),
		Vector2(349.0, 96.0),
		Vector2(404.0, 96.0),
		Vector2(462.0, 96.0)
	]
	var frames := [0, 1, 2, 3, 4, 5, 6, 7]

	for i in frames.size():
		var f_idx: int = frames[i]
		var f: Dictionary = _sdb.get_frame(sp_path, f_idx)
		if f.is_empty():
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.texture = f.texture
		var target_pos: Vector2 = anchors[i] - f.offset
		s.position = target_pos + Vector2(0, -50)
		s.modulate.a = 0.0
		add_child(s)
		_letters.append(s)
		_letter_info.append({"base_pos": target_pos, "anchor": anchors[i], "frame_norm": f_idx, "sprite_path": sp_path})

		var tw := create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(s, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.2)

func _setup_draw() -> void:
	var sp_path := "Game/Draw"
	# Exact screen coordinates from CA.exe CGODrawGlyph sub_5CDBD9(64) Vietnam (line 78032):
	# X: [178, 244, 309, 374], Y: 93 (4 letters: "HÒA!")
	var anchors := [
		Vector2(178.0, 93.0),
		Vector2(244.0, 93.0),
		Vector2(309.0, 93.0),
		Vector2(374.0, 93.0)
	]
	var frames := [0, 1, 2, 3]

	for i in frames.size():
		var f_idx: int = frames[i]
		var f: Dictionary = _sdb.get_frame(sp_path, f_idx)
		if f.is_empty():
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.texture = f.texture
		var target_pos: Vector2 = anchors[i] - f.offset
		s.position = target_pos + Vector2(0, -60)
		s.modulate.a = 0.0
		add_child(s)
		_letters.append(s)
		_letter_info.append({"base_pos": target_pos, "anchor": anchors[i], "frame_norm": f_idx, "sprite_path": sp_path})

		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(s, "position", target_pos, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "modulate:a", 1.0, 0.2)

func _process(delta: float) -> void:
	_age += delta

	# Auto-free for start glyph
	if auto_free_delay > 0.0:
		if _age >= auto_free_delay - 0.45 and modulate.a > 0.01:
			modulate.a = maxf(modulate.a - delta * 2.5, 0.0)
		if _age >= auto_free_delay:
			finished.emit()
			queue_free()
			return

	# Sequential wave jumping for WIN glyph ("hiệu ứng nhảy chữ")
	if glyph_type == GlyphType.WIN and _age >= 1.0:
		_jump_timer += delta
		if _jump_timer >= 0.16:
			_jump_timer = 0.0
			if _jump_idx < _letters.size():
				_trigger_letter_jump(_jump_idx)
			_jump_idx = (_jump_idx + 1) % (_letters.size() + 2) # +2 gives a brief resting pause

func _trigger_letter_jump(idx: int) -> void:
	if idx >= _letters.size() or idx >= _letter_info.size():
		return
	var s: Sprite2D = _letters[idx]
	var info: Dictionary = _letter_info[idx]
	var base_pos: Vector2 = info.base_pos

	var jump_peak: float = base_pos.y - 18.0
	var tw := create_tween()
	tw.tween_property(s, "position:y", jump_peak, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", base_pos.y, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
