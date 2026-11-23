class_name CGOShopBomber
extends "res://scripts/objects/cgo_bomber.gd"

## Live try-on preview bomber for CShopStageNew (CA.exe .?AVCGOShopBomber@@ @ 0xe448e4, ctor 0x7EECF2,
## CShopAction* @ 0x7F1EEF..0x7F2830: Wait, SetBomb, UseShield, UseSpring, UseSpecialItem, UseNormalItem).

const ACTION_WAIT: String = "Wait"
const ACTION_SET_BOMB: String = "SetBomb"
const ACTION_USE_SHIELD: String = "UseShield"
const ACTION_USE_SPRING: String = "UseSpring"
const ACTION_USE_SPECIAL_ITEM: String = "UseSpecialItem"
const ACTION_USE_NORMAL_ITEM: String = "UseNormalItem"

const DEMO_TICK_SEC: float = 0.03

var _saved_char_code: String = "Character/C00"
var _saved_cosmetics: Dictionary = {}
var _preview_cosmetics: Dictionary = {}
var _preview_anchor: Vector2 = Vector2(556.0, 262.0)
var _preview_bomb_sprite: Sprite2D = null
var _preview_fx_sprite: Sprite2D = null
var _preview_shield_sprite: Sprite2D = null

# CShopAction* live demo state machine
var demo_action: String = ACTION_WAIT
var demo_ticks: int = 0
var _demo_accum: float = 0.0
var _demo_item_sprite: String = ""

func _init() -> void:
	super._init()
	# Mini-arena demo sprites rendered in the green assist stage right next to the cyan preview box (0x806B85)
	_preview_bomb_sprite = Sprite2D.new()
	_preview_bomb_sprite.centered = false
	_preview_bomb_sprite.visible = false
	add_child(_preview_bomb_sprite)

	_preview_fx_sprite = Sprite2D.new()
	_preview_fx_sprite.centered = false
	_preview_fx_sprite.visible = false
	add_child(_preview_fx_sprite)

	_preview_shield_sprite = Sprite2D.new()
	_preview_shield_sprite.centered = true
	_preview_shield_sprite.visible = false
	_preview_shield_sprite.modulate = Color(0.45, 0.85, 1.0, 0.72)
	add_child(_preview_shield_sprite)

func _process(delta: float) -> void:
	_demo_accum += delta
	while _demo_accum >= DEMO_TICK_SEC:
		_demo_accum -= DEMO_TICK_SEC
		tick_demo()

func setup_preview(c_code: String, color: Color, eq_cosmetics: Dictionary, anchor_pos: Vector2 = Vector2(556.0, 262.0)) -> void:
	_saved_char_code = c_code if c_code != "" else "Character/C00"
	_saved_cosmetics = eq_cosmetics.duplicate(true)
	_preview_cosmetics = eq_cosmetics.duplicate(true)
	_preview_anchor = anchor_pos
	demo_action = ACTION_WAIT
	demo_ticks = 0
	_apply_preview_state(_saved_char_code, color, _preview_cosmetics)

func _apply_preview_state(c_code: String, color: Color, eq: Dictionary) -> void:
	setup(0, "", c_code, 0, 0, color, false, str(eq.get("bomb_skin", "Bomb/Bomb00")), str(eq.get("mount", "")), {}, {
		"hat": str(eq.get("hat", "")),
		"cloth": str(eq.get("cloth", "")),
		"face": str(eq.get("face", "")),
		"char_deco": str(eq.get("char_deco", "")),
		"id_deco": str(eq.get("id_deco", "")),
	})
	position = _preview_anchor
	start_ticks = 0
	action = "idle"
	dir = 0
	if is_instance_valid(name_lbl):
		name_lbl.visible = false
	_update_visuals()
	_update_preview_bomb(str(eq.get("bomb_skin", "")), 0)

func _update_preview_bomb(skin: String, frame_idx: int) -> void:
	if not is_instance_valid(_preview_bomb_sprite):
		return
	var sdb: Object = _get_sprite_db()
	if sdb == null or skin == "" or skin == "Bomb/Bomb00":
		_preview_bomb_sprite.visible = false
		return
	var bf: Dictionary = sdb.get_frame(skin, frame_idx % 4)
	if bf.is_empty():
		bf = sdb.get_frame(skin, 0)
	if bf.is_empty():
		_preview_bomb_sprite.visible = false
		return
	_preview_bomb_sprite.visible = true
	_preview_bomb_sprite.texture = bf.texture
	# Place inside the green tiled mini-arena to the right of the preview box
	_preview_bomb_sprite.position = Vector2(126.0, -6.0) - Vector2(bf.offset)

func start_shop_action(action_name: String, item_sprite: String = "") -> void:
	demo_action = action_name
	demo_ticks = 0
	_demo_item_sprite = item_sprite
	position = _preview_anchor
	if is_instance_valid(_preview_fx_sprite):
		_preview_fx_sprite.visible = false
	if is_instance_valid(_preview_shield_sprite):
		_preview_shield_sprite.visible = false
	match action_name:
		ACTION_SET_BOMB:
			action = "idle"
			_update_preview_bomb(str(_preview_cosmetics.get("bomb_skin", "Bomb/Bomb00")), 0)
		ACTION_USE_SHIELD:
			action = "idle"
		ACTION_USE_SPRING:
			action = "hurrah"
		ACTION_USE_SPECIAL_ITEM:
			action = "hurrah"
		ACTION_USE_NORMAL_ITEM:
			action = "throw"
		_:
			demo_action = ACTION_WAIT
			action = "idle"
	_update_visuals()

func tick_demo() -> void:
	if demo_action == ACTION_WAIT:
		demo_ticks += 1
		if demo_ticks % 90 == 0:
			action = "blink"
			set_bomber_state(STATE_BLINK, false, true)
		elif action == "blink" and state_finished:
			action = "idle"
		if step_bomber_state_tick():
			_update_visuals()
		return

	demo_ticks += 1
	var sdb: Object = _get_sprite_db()
	match demo_action:
		ACTION_SET_BOMB:
			var skin: String = str(_preview_cosmetics.get("bomb_skin", "Bomb/Bomb00"))
			if skin == "Bomb/Bomb00":
				skin = "BombDeco/Bomb001"
			if demo_ticks < 36:
				_update_preview_bomb(skin, (demo_ticks / 4) % 4)
			elif demo_ticks < 48:
				if is_instance_valid(_preview_bomb_sprite):
					_preview_bomb_sprite.visible = false
				if sdb != null and is_instance_valid(_preview_fx_sprite):
					var wf: Dictionary = sdb.get_frame("Wave/Wave00", mini((demo_ticks - 36) / 3, 3))
					if not wf.is_empty():
						_preview_fx_sprite.visible = true
						_preview_fx_sprite.texture = wf.texture
						_preview_fx_sprite.position = Vector2(126.0, -6.0) - Vector2(wf.offset)
			else:
				start_shop_action(ACTION_WAIT)
		ACTION_USE_SHIELD:
			if demo_ticks < 50:
				if sdb != null and is_instance_valid(_preview_shield_sprite):
					var sf: Dictionary = sdb.get_frame("Bomb/Bubble00", 6)
					if not sf.is_empty():
						_preview_shield_sprite.visible = true
						_preview_shield_sprite.texture = sf.texture
						_preview_shield_sprite.position = Vector2(20.0, -22.0)
						var pulse: float = 0.55 + 0.25 * sin(float(demo_ticks) * 0.25)
						_preview_shield_sprite.modulate = Color(0.45, 0.85, 1.0, pulse)
			else:
				start_shop_action(ACTION_WAIT)
		ACTION_USE_SPRING:
			if demo_ticks <= 24:
				var t: float = float(demo_ticks) / 24.0
				position = _preview_anchor + Vector2(0.0, -36.0 * sin(t * PI))
			else:
				position = _preview_anchor
				start_shop_action(ACTION_WAIT)
		ACTION_USE_SPECIAL_ITEM:
			if demo_ticks < 45:
				if step_bomber_state_tick():
					_update_visuals()
			else:
				start_shop_action(ACTION_WAIT)
		ACTION_USE_NORMAL_ITEM:
			if demo_ticks < 30:
				if sdb != null and _demo_item_sprite != "" and is_instance_valid(_preview_fx_sprite):
					var itf: Dictionary = sdb.get_frame(_demo_item_sprite, 0)
					if not itf.is_empty():
						_preview_fx_sprite.visible = true
						_preview_fx_sprite.texture = itf.texture
						_preview_fx_sprite.position = Vector2(126.0, -24.0 - float(demo_ticks) * 0.4) - Vector2(itf.offset)
				if step_bomber_state_tick():
					_update_visuals()
			else:
				start_shop_action(ACTION_WAIT)

func try_on(entry: Dictionary) -> void:
	var slot_type: String = str(entry.get("slot_type", ""))
	var item_code: String = str(entry.get("item_code", ""))
	if slot_type == "" or item_code == "":
		return
	if slot_type == "character":
		_preview_cosmetics["character"] = item_code
		_apply_preview_state(item_code, team_color, _preview_cosmetics)
		start_shop_action(ACTION_USE_SPECIAL_ITEM)
	elif slot_type == "consumable":
		if item_code.contains("Shield"):
			start_shop_action(ACTION_USE_SHIELD)
		elif item_code.contains("Spring"):
			start_shop_action(ACTION_USE_SPRING)
		else:
			start_shop_action(ACTION_USE_NORMAL_ITEM, str(entry.get("sprite", "")))
	else:
		_preview_cosmetics[slot_type] = item_code
		_apply_preview_state(str(_preview_cosmetics.get("character", _saved_char_code)), team_color, _preview_cosmetics)
		if slot_type == "bomb_skin":
			start_shop_action(ACTION_SET_BOMB)
		else:
			start_shop_action(ACTION_USE_SPECIAL_ITEM)

func undo_preview() -> void:
	# S_BtUndo (0x804C7E id=6102): restore player's actual equipped state
	_preview_cosmetics = _saved_cosmetics.duplicate(true)
	_apply_preview_state(_saved_char_code, team_color, _preview_cosmetics)
	start_shop_action(ACTION_WAIT)

func hide_preview_cosmetics() -> void:
	# S_BtHide (0x804C7E id=6101): strip all preview cosmetics to base character
	_preview_cosmetics = {
		"hat": "",
		"cloth": "",
		"face": "",
		"char_deco": "",
		"id_deco": "",
		"bomb_skin": "Bomb/Bomb00",
		"mount": "",
		"character": str(_preview_cosmetics.get("character", _saved_char_code)),
	}
	_apply_preview_state(str(_preview_cosmetics["character"]), team_color, _preview_cosmetics)
	start_shop_action(ACTION_WAIT)
