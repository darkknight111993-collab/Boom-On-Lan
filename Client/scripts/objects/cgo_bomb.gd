class_name CGOBomb
extends "res://scripts/objects/c_game_object.gd"

## CGOBomb - Bomb entity ported from CA.exe CGOBomb & CBombOwner
## Handles countdown, pulse animation, throw physics, sliding/kicking physics, and explosion trigger.

signal exploded(bomb: Node2D)
signal slide_stopped(bomb: Node2D, stop_cell: Vector2i, slide_dir_v: Vector2i)

enum State {
	IDLE,
	THROWN,
	SLIDING,
	TANK_SHOT,
}

# 4 directions from exe (0x91D7B8 / 0x91D7BC)
const DIR_VECTORS: Array[Vector2i] = [
	Vector2i(-1, 0), # 0: LEFT
	Vector2i(0, -1), # 1: UP
	Vector2i(1, 0),  # 2: RIGHT
	Vector2i(0, 1),  # 3: DOWN
]

# Kicking / sliding phase tables extracted from CA.exe (0x9150C0..0x915208)
const KICK_PHASE0_Y := [-33, -33, -33, -33, -33, -33, -33, -33, -33, -33, -32, -30, -27, -23, -18]
const KICK_PHASE0_SPEED := [16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16]
const KICK_PHASE1_Y := [-35, -55, -70, -80, -85, -80, -75, -70, -60, -45, -30, -18]
const KICK_PHASE1_SPEED := [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
const KICK_PHASE2_Y := [-12, -17, -20, -17, -12, -17, -20, -17, -12, -17, -20, -17]
const KICK_PHASE2_SPEED := [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
const KICK_PHASE3_Y := [-12, -17, -20, -17]
const KICK_PHASE3_SPEED := [10, 10, 10, 10]

# Animation frames for default basic bomb (ObjectTable ID 4: Bomb/BasicBomb)
const DEFAULT_BOMB_FRAMES := [[0, 6], [1, 6], [2, 6], [3, 6]]

@export var owner_id: int = -1
@export var power: int = 1
@export var countdown: float = 3.0 # ~100 ticks (3000ms)
@export var skin_sprite: String = "Bomb/Bomb00"

var bomb_state: State = State.IDLE
var is_exploded := false

# Thrown motion variables (CA.exe sub_443339 & sub_442BF1: parabolic arc + toroidal screen wrapping)
const THROW_BASE_DURATION := 0.45
var throw_duration := 0.45
var throw_elapsed := 0.0
var throw_target_cell := Vector2i.ZERO
var throw_start_pixel := Vector2.ZERO
var throw_dir_v := Vector2i.ZERO
var throw_total_steps := 0

# Sliding / kicking motion variables (sub_442BF1: ~12-16 px/tick = 400 px/s)
const KICK_SLIDE_SPEED := 400.0
var slide_dir := 0
var slide_dir_v := Vector2i.ZERO
var slide_target_cell := Vector2i.ZERO
var slide_phase := 0
var slide_step := 0
var slide_pixel_pos := Vector2.ZERO

# Tank shot sliding variables (sub_442542 / sub_442948)
const TANK_SHOT_SPEED := 666.67 # 20 px/tick * 33.33 ticks/s in CA.exe sub_442948
var tank_target_cell := Vector2i.ZERO

static func _play_sfx(sfx_name: String) -> void:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("AudioManager"):
		var mgr = (ml as SceneTree).root.get_node("AudioManager")
		# In VN client asset pack, character bomb sounds use "Cha_Bomb*" prefix
		if sfx_name == "Wave/BombIgnite":
			mgr.call("play_sfx", "Cha_BombIgnite")
		elif sfx_name == "Wave/BombExplode":
			mgr.call("play_sfx", "Cha_BombExplode")
		else:
			mgr.call("play_sfx", sfx_name)

func _ready() -> void:
	super._ready()
	z_index = 1 + cell.y
	# Play sound ID 2: Wave/BombIgnite (sub_4389EA / sub_66AF20)
	_play_sfx("Wave/BombIgnite")
	play_anim(skin_sprite, DEFAULT_BOMB_FRAMES, true)

func setup(col: int, row: int, bomb_power: int, bomb_owner: int = -1, skin: String = "Bomb/Bomb00") -> void:
	set_cell(col, row)
	z_index = 1 + row
	power = bomb_power
	owner_id = bomb_owner
	skin_sprite = skin if skin != "" else "Bomb/Bomb00"

func _on_update(delta: float) -> void:
	if is_exploded:
		return

	match bomb_state:
		State.IDLE:
			_update_idle(delta)
		State.THROWN:
			_update_thrown(delta)
		State.SLIDING:
			_update_sliding(delta)
		State.TANK_SHOT:
			_update_tank_shot(delta)

func _update_idle(delta: float) -> void:
	countdown -= delta
	if countdown <= 0.0:
		explode()

func start_tank_shot(target_col: int, target_row: int) -> void:
	bomb_state = State.TANK_SHOT
	tank_target_cell = Vector2i(target_col, target_row)

func _update_tank_shot(delta: float) -> void:
	countdown -= delta
	if countdown <= 0.0:
		explode()
		return
	var target_anchor := get_cell_anchor(tank_target_cell.x, tank_target_cell.y)
	var step: float = TANK_SHOT_SPEED * delta
	if position.distance_to(target_anchor) <= step:
		position = target_anchor
		set_cell(tank_target_cell.x, tank_target_cell.y)
		bomb_state = State.IDLE
	else:
		var dir_v := (target_anchor - position).normalized()
		position += dir_v * step
		var local_x: float = position.x - map_origin.x
		var local_y: float = position.y - map_origin.y - 39.0
		var cur_col: int = int(round(local_x / float(CELL_SIZE)))
		var cur_row: int = int(round(local_y / float(CELL_SIZE)))
		if cur_col != cell.x or cur_row != cell.y:
			set_cell(cur_col, cur_row)

func start_throw(target_col: int, target_row: int, dir_v: Vector2i = Vector2i.ZERO, duration: float = 0.0) -> void:
	bomb_state = State.THROWN
	throw_elapsed = 0.0
	throw_start_pixel = position
	throw_target_cell = Vector2i(target_col, target_row)
	throw_dir_v = dir_v
	z_index = 20 # Render above players and map walls during flight

	# If dir_v was not passed explicitly, infer it if possible
	if throw_dir_v == Vector2i.ZERO:
		var diff := throw_target_cell - cell
		if diff.x != 0 and diff.y == 0:
			throw_dir_v = Vector2i(signi(diff.x), 0)
		elif diff.y != 0 and diff.x == 0:
			throw_dir_v = Vector2i(0, signi(diff.y))

	# Compute total forward steps along throw_dir_v with map wrapping (COLS=15, ROWS=13)
	if throw_dir_v.x != 0:
		var diff_steps: int = (throw_target_cell.x - cell.x) * throw_dir_v.x
		throw_total_steps = posmod(diff_steps, 15)
		if throw_total_steps == 0:
			throw_total_steps = 15 # Full loop around map
	elif throw_dir_v.y != 0:
		var diff_steps: int = (throw_target_cell.y - cell.y) * throw_dir_v.y
		throw_total_steps = posmod(diff_steps, 13)
		if throw_total_steps == 0:
			throw_total_steps = 13 # Full loop around map
	else:
		throw_total_steps = 0

	if duration > 0.0:
		throw_duration = duration
	else:
		throw_duration = 0.45 if throw_total_steps <= 3 else 0.45 + (throw_total_steps - 3) * 0.04

func _update_thrown(delta: float) -> void:
	countdown -= delta
	if countdown <= 0.0:
		explode()
		return

	throw_elapsed += delta
	var progress: float = clampf(throw_elapsed / throw_duration, 0.0, 1.0)
	var target_anchor := get_cell_anchor(throw_target_cell.x, throw_target_cell.y)

	var arc_offset: float = -60.0 * sin(progress * PI)

	if throw_dir_v != Vector2i.ZERO and throw_total_steps > 0:
		var dist_px: float = progress * float(throw_total_steps * CELL_SIZE)
		var unwrapped_x: float = throw_start_pixel.x + float(throw_dir_v.x) * dist_px
		var unwrapped_y: float = throw_start_pixel.y + float(throw_dir_v.y) * dist_px

		# Wrap relative to map area (15*40=600 width, 13*40=520 height)
		var rel_x: float = unwrapped_x - map_origin.x
		var wrapped_x: float = map_origin.x + fposmod(rel_x, 600.0)

		var rel_y: float = unwrapped_y - map_origin.y - 39.0
		var wrapped_y: float = map_origin.y + 39.0 + fposmod(rel_y, 520.0)

		position = Vector2(wrapped_x, wrapped_y + arc_offset)
	else:
		var base_pos: Vector2 = throw_start_pixel.lerp(target_anchor, progress)
		position = Vector2(base_pos.x, base_pos.y + arc_offset)

	if progress >= 1.0:
		position = target_anchor
		set_cell(throw_target_cell.x, throw_target_cell.y)
		z_index = 1 + throw_target_cell.y
		bomb_state = State.IDLE

func start_slide(direction: Variant, target: Vector2i = Vector2i(-1, -1)) -> void:
	bomb_state = State.SLIDING
	if direction is Vector2i:
		slide_dir_v = direction
	elif direction is int:
		var d: int = direction
		if d >= 0 and d < DIR_VECTORS.size():
			slide_dir_v = DIR_VECTORS[d]
		else:
			slide_dir_v = Vector2i(0, 1)
	else:
		slide_dir_v = Vector2i(0, 1)

	if target != Vector2i(-1, -1):
		slide_target_cell = target
	else:
		slide_target_cell = cell + slide_dir_v
	slide_pixel_pos = position

func _update_sliding(delta: float) -> void:
	countdown -= delta
	if countdown <= 0.0:
		explode()
		return

	var target_anchor := get_cell_anchor(slide_target_cell.x, slide_target_cell.y)
	var step: float = KICK_SLIDE_SPEED * delta
	if position.distance_to(target_anchor) <= step:
		position = target_anchor
		set_cell(slide_target_cell.x, slide_target_cell.y)
		bomb_state = State.IDLE
		slide_stopped.emit(self, slide_target_cell, slide_dir_v)
	else:
		var dir_v := (target_anchor - position).normalized()
		position += dir_v * step
		var local_x: float = position.x - map_origin.x
		var local_y: float = position.y - map_origin.y - 39.0
		var cur_col: int = int(round(local_x / float(CELL_SIZE)))
		var cur_row: int = int(round(local_y / float(CELL_SIZE)))
		if cur_col != cell.x or cur_row != cell.y:
			set_cell(cur_col, cur_row)

func explode() -> void:
	if is_exploded:
		return
	is_exploded = true
	# Play sound ID 1: Wave/BombExplode (sub_4E6AB4 / sub_66AF20)
	_play_sfx("Wave/BombExplode")
	exploded.emit(self)
	queue_free()
