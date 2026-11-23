class_name CGameObject
extends Node2D

## Base class for all BnB Game Objects (Characters, Bombs, Items, Monsters)
## Ported from CA.exe CGameObject & CSensorTrigger

signal cell_changed(old_cell: Vector2i, new_cell: Vector2i)
signal animation_finished

const CELL_SIZE := 40
const TICK_SEC := 0.03 # 1 tick = 30ms in CA engine

@export var cell: Vector2i = Vector2i.ZERO
@export var map_origin: Vector2 = Vector2(20, 41)

var sprite_node: Sprite2D
var current_sprite_path := ""
var current_frames: Array = [] # [[frame_idx, duration_ticks], ...]
var anim_frame_idx := 0
var anim_tick_timer := 0.0
var anim_loop := true
var anim_finished: bool = false
var _tick_accum: float = 0.0

static var _sprite_db_ref: Object = null

static func _get_sprite_db() -> Object:
	if _sprite_db_ref == null:
		var ml: MainLoop = Engine.get_main_loop()
		if ml is SceneTree and (ml as SceneTree).root.has_node("SpriteDB"):
			_sprite_db_ref = (ml as SceneTree).root.get_node("SpriteDB")
		else:
			_sprite_db_ref = preload("res://scripts/sprite_db.gd").new()
	return _sprite_db_ref

func _ready() -> void:
	sprite_node = Sprite2D.new()
	sprite_node.centered = false
	add_child(sprite_node)
	_update_anchor_position()

## Computes world anchor position for cell (col, row): anchor = (40*col, 40*row + 39)
func get_cell_anchor(col: int, row: int) -> Vector2:
	return map_origin + Vector2(col * CELL_SIZE, row * CELL_SIZE + 39)

func set_cell(col: int, row: int) -> void:
	var old := cell
	cell = Vector2i(col, row)
	_update_anchor_position()
	if old != cell:
		cell_changed.emit(old, cell)

func _update_anchor_position() -> void:
	position = get_cell_anchor(cell.x, cell.y)

## Plays an animation sequence defined by sprite path and frames [[frame_idx, duration_ticks], ...]
func play_anim(sprite_path: String, frames: Array, loop: bool = true) -> void:
	current_sprite_path = sprite_path
	current_frames = frames
	anim_loop = loop
	anim_frame_idx = 0
	anim_tick_timer = 0.0
	anim_finished = false
	_apply_current_frame()

func _apply_current_frame() -> void:
	if current_frames.is_empty():
		return
	var fr_info: Array = current_frames[anim_frame_idx]
	var logical_idx: int = fr_info[0]
	var sdb: Object = _get_sprite_db()
	if sdb == null:
		return
	var data: Dictionary = sdb.get_frame(current_sprite_path, logical_idx)
	if data.is_empty() or data.get("texture") == null:
		if sprite_node:
			sprite_node.visible = false
		return

	if sprite_node:
		sprite_node.visible = true
		sprite_node.texture = data.texture
		# CA.exe: draw_pos = anchor - offset (sub_68B7A0)
		var offset: Vector2 = data.offset
		sprite_node.position = -offset

func _process(delta: float) -> void:
	_tick_animation(delta)
	_tick_accum += delta
	while _tick_accum >= TICK_SEC:
		_tick_accum -= TICK_SEC
		_on_tick()
	_on_update(delta)

func _tick_animation(delta: float) -> void:
	if current_frames.is_empty() or anim_finished:
		return
	anim_tick_timer += delta
	while true:
		if current_frames.is_empty() or anim_finished:
			break
		var fr_info: Array = current_frames[anim_frame_idx]
		var duration_ticks: int = fr_info[1]
		if duration_ticks < 0:
			return # Infinite hold on current frame (-1 in CA.exe)
		if duration_ticks == 0:
			duration_ticks = 1

		var frame_duration_sec: float = duration_ticks * TICK_SEC
		if anim_tick_timer >= frame_duration_sec:
			anim_tick_timer -= frame_duration_sec
			anim_frame_idx += 1
			if anim_frame_idx >= current_frames.size():
				if anim_loop:
					anim_frame_idx = 0
					_apply_current_frame()
				else:
					anim_frame_idx = current_frames.size() - 1
					anim_finished = true
					animation_finished.emit()
					return
			else:
				_apply_current_frame()
		else:
			break

## Virtual fixed tick (30ms) method for subclasses (CGameStage::sub_4F5658)
func _on_tick() -> void:
	pass

## Virtual update method for subclasses
func _on_update(_delta: float) -> void:
	pass
