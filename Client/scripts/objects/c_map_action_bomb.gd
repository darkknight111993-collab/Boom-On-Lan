class_name CMapActionBomb
extends Node2D

## CMapActionBomb - Coordinates bomb placement, countdown, blast rays, and chain reactions.
## Ported from CA.exe CMapActionBomb & sub_4E6AB4 / sub_4E61E3 / sub_4E3E83.

const CGOBombClass = preload("res://scripts/objects/cgo_bomb.gd")
const CGOExplosionClass = preload("res://scripts/objects/cgo_explosion.gd")

signal bomb_placed(bomb: Node2D)
signal bomb_exploded(center_cell: Vector2i, blast_cells: Array[Vector2i])

const COLS := 15
const ROWS := 13

# 4 directions: Left, Up, Right, Down (sub_4E61E3 / 0x91D7B8)
const DIRS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
]

# Map of Vector2i cell -> CGOBomb
var _active_bombs: Dictionary = {}
var map_origin: Vector2 = Vector2(20, 41)

# Callback to check tile collision: func(cell: Vector2i) -> int (0: passable, 1: wall, 2: box, 3: CGOTilePassable)
var tile_check_callback: Callable = Callable()
var box_destroy_callback: Callable = Callable()
# Directional passable callbacks: func(from_cell: Vector2i, to_cell: Vector2i, dir_idx: int) -> bool
var bomb_passable_callback: Callable = Callable()
var flame_passable_callback: Callable = Callable()

func _ready() -> void:
	z_index = 1

func place_bomb(col: int, row: int, power: int = 1, owner_id: int = -1, skin: String = "Bomb/Bomb00") -> Node2D:
	var target_cell := Vector2i(col, row)
	if _active_bombs.has(target_cell):
		return null # Cell already has a bomb

	var bomb: Node2D = CGOBombClass.new()
	bomb.map_origin = map_origin
	bomb.setup(col, row, power, owner_id, skin)
	bomb.exploded.connect(_on_bomb_exploded)
	bomb.cell_changed.connect(_on_bomb_cell_changed.bind(bomb))
	_active_bombs[target_cell] = bomb
	add_child(bomb)
	bomb_placed.emit(bomb)
	return bomb

func get_bomb_at(col: int, row: int) -> Node2D:
	return _active_bombs.get(Vector2i(col, row), null)

func has_bomb_at(col: int, row: int) -> bool:
	return _active_bombs.has(Vector2i(col, row))

## Scans straight along dir_v for Tank bomb shot / Kick bomb (sub_4E5022) until an obstacle is reached
func trace_tank_shot_target(col: int, row: int, dir_v: Vector2i) -> Vector2i:
	var cur := Vector2i(col, row)
	var last_valid := cur
	var dir_idx: int = DIRS.find(dir_v)
	while true:
		var next_cell := cur + dir_v
		if next_cell.x < 0 or next_cell.x >= COLS or next_cell.y < 0 or next_cell.y >= ROWS:
			break
		if tile_check_callback.is_valid():
			var t_type: int = tile_check_callback.call(next_cell)
			if t_type == 1 or t_type == 2: # 1: wall, 2: box
				break
		if bomb_passable_callback.is_valid() and not bomb_passable_callback.call(cur, next_cell, dir_idx):
			break
		if _active_bombs.has(next_cell):
			break
		cur = next_cell
		last_valid = cur
	return last_valid

## Scans straight along dir_v for Kick bomb (sub_4EE238 / sub_4E5022).
## Returns start_cell if immediate next cell is blocked (cannot kick).
func trace_kick_target(col: int, row: int, dir_v: Vector2i) -> Vector2i:
	return trace_tank_shot_target(col, row, dir_v)

## Calculates punch/throw landing cell (CA.exe sub_442FF7):
## The bomb leaps 3 tiles forward (jumping over obstacles), then lands on the first empty cell.
func trace_throw_target(col: int, row: int, dir_v: Vector2i) -> Vector2i:
	if dir_v == Vector2i.ZERO:
		return Vector2i(col, row)

	var start := Vector2i(col, row)
	var cur_col := posmod(col + 3 * dir_v.x, COLS)
	var cur_row := posmod(row + 3 * dir_v.y, ROWS)

	var is_blocked := func(c: Vector2i) -> bool:
		if tile_check_callback.is_valid():
			var t_type: int = tile_check_callback.call(c)
			if t_type == 1 or t_type == 2: # 1: wall, 2: box
				return true
		if _active_bombs.has(c):
			return true
		return false

	# If the 3rd tile is empty, land right there!
	if not is_blocked.call(Vector2i(cur_col, cur_row)):
		return Vector2i(cur_col, cur_row)

	# If blocked, scan forward (tile 4, 5, 6...) for the next available empty tile
	var max_scan := COLS if dir_v.x != 0 else ROWS
	for _step in range(max_scan):
		cur_col = posmod(cur_col + dir_v.x, COLS)
		cur_row = posmod(cur_row + dir_v.y, ROWS)
		var check := Vector2i(cur_col, cur_row)
		if check == start:
			break
		if not is_blocked.call(check):
			return check

	return start

func detonate_owner_bomb(owner_id: int) -> bool:
	for cell_pos: Vector2i in _active_bombs.keys():
		var b: Node2D = _active_bombs.get(cell_pos, null)
		if is_instance_valid(b) and b.get("owner_id") == owner_id:
			b.call("explode")
			return true
	return false

func _on_bomb_cell_changed(old_cell: Vector2i, new_cell: Vector2i, bomb: Node2D) -> void:
	if _active_bombs.get(old_cell) == bomb:
		_active_bombs.erase(old_cell)
	_active_bombs[new_cell] = bomb

func _on_bomb_exploded(bomb: Node2D) -> void:
	var center: Vector2i = bomb.cell
	var power: int = bomb.power
	_active_bombs.erase(center)

	var blast_cells: Array[Vector2i] = [center]
	_spawn_explosion_segment(center.x, center.y, clampi(power - 1, 0, 14))

	# Ray casting in 4 directions (sub_4E61E3)
	for dir_idx in DIRS.size():
		var dir: Vector2i = DIRS[dir_idx]
		for step in range(1, power + 1):
			var prev_cell: Vector2i = center + dir * (step - 1)
			var cur: Vector2i = center + dir * step
			if cur.x < 0 or cur.x >= COLS or cur.y < 0 or cur.y >= ROWS:
				break # Out of map boundary
			if flame_passable_callback.is_valid() and not flame_passable_callback.call(prev_cell, cur, dir_idx):
				break # Blocked by directional CGOTilePassable (e.g. TentBlue side wall, sub_5C10E1)

			# Check map collision if callback is provided
			if tile_check_callback.is_valid():
				var tile_type: int = tile_check_callback.call(cur)
				if tile_type == 1:
					# Static hard wall stops blast ray
					break
				elif tile_type == 2:
					# Destructible box is hit, damaged, and stops blast ray
					blast_cells.append(cur)
					_spawn_explosion_segment(cur.x, cur.y, _flame_ray_group(dir_idx, power, step), step - 1)
					if box_destroy_callback.is_valid():
						box_destroy_callback.call(cur)
					break

			blast_cells.append(cur)
			_spawn_explosion_segment(cur.x, cur.y, _flame_ray_group(dir_idx, power, step), step - 1)

			# Chain reaction (sub_4E3E83): trigger other bombs in the blast ray
			if _active_bombs.has(cur):
				var chained_bomb: Node2D = _active_bombs[cur]
				# Explode immediately
				chained_bomb.explode()

	bomb_exploded.emit(center, blast_cells)

func _flame_ray_group(dir_idx: int, power: int, step: int) -> int:
	# Flame/Flame groups: 15..29 Left, 30..44 Up, 45..59 Right, 60..74 Down.
	var dir_groups: Array[int] = [15, 30, 45, 60]
	var dir_group: int = dir_groups[dir_idx]
	var remaining_range := clampi(power - step + 1, 1, 15)
	return dir_group + remaining_range - 1

func _spawn_explosion_segment(col: int, row: int, group_idx: int = 0, delay_ticks: int = 0) -> void:
	var exp: Node2D = CGOExplosionClass.new()
	exp.map_origin = map_origin
	exp.setup(col, row, group_idx, delay_ticks)
	add_child(exp)
