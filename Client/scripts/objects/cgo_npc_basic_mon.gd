class_name CGONpcBasicMon
extends "res://scripts/objects/c_game_object.gd"

## CGONpcBasicMon - Base Monster / NPC Entity
## Ported from CA.exe CGONpcBasicMon with grid patrol AI, direction steering,
## bomber collision damage, and water flame destruction.

signal monster_died(mon: CGONpcBasicMon, cell: Vector2i)
signal drop_spawned(item_code: String, cell: Vector2i)

const MON_DIR_NAMES := ["Down", "Up", "Left", "Right"]
const MON_DIR_VECTORS: Array[Vector2] = [
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(-1, 0),
	Vector2(1, 0)
]

@export var monster_id: String = "SM01"
@export var mon_name: String = "Monster"
@export var hp: int = 1
@export var max_hp: int = 1
@export var move_speed: float = 80.0 # ~2.4 px/tick
@export var touch_damage_lethal: bool = false # false = trap in bubble, true = instant die

var grid_cols: int = 15
var grid_rows: int = 13

var dir: int = 0
var alive: bool = true
var action: String = "walk"
var anim_tick: int = 0
var anim_frame: int = 0
var die_timer: float = 0.0

var drop_item_code: String = "Item/Bomb"
var drop_chance: float = 0.5

# Visual node
var sp_visual: Sprite2D
var _sprite_path_cache: Dictionary = {}

func _init() -> void:
	sp_visual = Sprite2D.new()
	sp_visual.centered = false
	add_child(sp_visual)

func setup(m_id: String, col: int, row: int, m_speed: float = 80.0, drop_item: String = "Item/Bomb", initial_hp: int = 1) -> void:
	monster_id = m_id
	hp = initial_hp
	max_hp = initial_hp
	move_speed = m_speed
	drop_item_code = drop_item
	alive = true
	action = "walk"
	dir = randi() % 4
	anim_frame = 0
	anim_tick = 0
	set_cell(col, row)
	_update_visuals()

func _resolve_sprite_path(act: String, d_name: String) -> String:
	var key := "%s#%s#%s" % [monster_id, act, d_name]
	if _sprite_path_cache.has(key):
		return _sprite_path_cache[key]

	var candidates: Array[String] = []
	if act == "die":
		candidates = [
			"Monster/%s_Die" % monster_id,
			"Monster/%s_Dead" % monster_id,
			"Monster/%s-Die" % monster_id
		]
	else:
		candidates = [
			"Monster/%s_Walking_%s" % [monster_id, d_name],
			"Monster/%s_Walking%s" % [monster_id, d_name],
			"Monster/%s_%s" % [monster_id, d_name],
			"Monster/%s_Walk%s" % [monster_id, d_name],
			"Monster/%s-Walking_%s" % [monster_id, d_name],
			"Monster/%s-Walk%s" % [monster_id, d_name]
		]

	var sdb: Object = _get_sprite_db()
	var selected := candidates[0]
	if sdb != null:
		for c in candidates:
			var dir_path: String = sdb.resolve_sprite_dir(c)
			if FileAccess.file_exists(dir_path.path_join("sprite.json")):
				selected = c
				break

	_sprite_path_cache[key] = selected
	return selected

func _update_visuals() -> void:
	if sp_visual == null:
		return
	var sdb: Object = _get_sprite_db()
	if sdb == null:
		return

	var d_name: String = MON_DIR_NAMES[dir]
	var path := _resolve_sprite_path(action, d_name)

	var f_idx := anim_frame
	if action == "die":
		f_idx = mini(int(die_timer * 10.0), 6)
	else:
		f_idx = (anim_frame / 3) % 4

	var f: Dictionary = sdb.get_frame(path, f_idx)
	if f.is_empty():
		# Try frame 0
		f = sdb.get_frame(path, 0)

	if not f.is_empty() and f.get("texture") != null:
		sp_visual.visible = true
		sp_visual.texture = f.texture
		sp_visual.position = -f.offset
	else:
		sp_visual.visible = false

func step_ai(delta: float, is_cell_blocked: Callable) -> void:
	if not alive:
		die_timer += delta
		_update_visuals()
		if die_timer >= 0.7:
			if drop_item_code != "" and randf() <= drop_chance:
				drop_spawned.emit(drop_item_code, cell)
			monster_died.emit(self, cell)
			queue_free()
		return

	anim_tick += 1
	if anim_tick >= 2:
		anim_tick = 0
		anim_frame += 1

	var step: float = move_speed * delta
	var move_vec: Vector2 = MON_DIR_VECTORS[dir]
	var target_pos: Vector2 = position + move_vec * step

	# Grid alignment check
	var cur_col := cell.x
	var cur_row := cell.y
	var anchor_curr := get_cell_anchor(cur_col, cur_row)

	# Lane centering: align perpendicular axis towards anchor to avoid corner clipping
	if dir == 0 or dir == 1:
		target_pos.x = move_toward(position.x, anchor_curr.x, step)
	elif dir == 2 or dir == 3:
		target_pos.y = move_toward(position.y, anchor_curr.y, step)

	# Intersection turn check when crossing near tile center
	if is_cell_blocked.is_valid() and absf(position.x - anchor_curr.x) <= step + 1.5 and absf(position.y - anchor_curr.y) <= step + 1.5:
		var ortho_dirs: Array[int] = []
		if dir == 0 or dir == 1:
			ortho_dirs.append_array([2, 3])
		else:
			ortho_dirs.append_array([0, 1])
		var open_ortho: Array[int] = []
		for od in ortho_dirs:
			var dvec: Vector2 = MON_DIR_VECTORS[od]
			var tc := cur_col + int(dvec.x)
			var tr := cur_row + int(dvec.y)
			if tc >= 0 and tc < grid_cols and tr >= 0 and tr < grid_rows:
				if not is_cell_blocked.call(tc, tr):
					open_ortho.append(od)
		if not open_ortho.is_empty() and randf() < 0.25:
			dir = open_ortho[randi() % open_ortho.size()]
			move_vec = MON_DIR_VECTORS[dir]
			target_pos = position + move_vec * step
			if dir == 0 or dir == 1:
				target_pos.x = anchor_curr.x
			else:
				target_pos.y = anchor_curr.y

	var next_col := cur_col + int(move_vec.x)
	var next_row := cur_row + int(move_vec.y)

	var blocked := false
	if is_cell_blocked.is_valid():
		if next_col < 0 or next_col >= grid_cols or next_row < 0 or next_row >= grid_rows:
			blocked = true
		elif is_cell_blocked.call(next_col, next_row):
			if dir == 0 and target_pos.y > anchor_curr.y:
				blocked = true
			elif dir == 1 and target_pos.y < anchor_curr.y:
				blocked = true
			elif dir == 2 and target_pos.x < anchor_curr.x:
				blocked = true
			elif dir == 3 and target_pos.x > anchor_curr.x:
				blocked = true

	if blocked:
		# Choose an open direction, prioritizing new/orthogonal paths over direct reversal
		var opposite_dirs := [1, 0, 3, 2] # 0:Down<->1:Up, 2:Left<->3:Right
		var rev_dir: int = opposite_dirs[dir]
		var side_dirs: Array[int] = []
		var reverse_open := false
		for test_d in 4:
			if test_d == dir:
				continue
			var dvec: Vector2 = MON_DIR_VECTORS[test_d]
			var tc := cur_col + int(dvec.x)
			var tr := cur_row + int(dvec.y)
			if tc >= 0 and tc < grid_cols and tr >= 0 and tr < grid_rows:
				if not is_cell_blocked.call(tc, tr):
					if test_d != rev_dir:
						side_dirs.append(test_d)
					else:
						reverse_open = true

		if not side_dirs.is_empty():
			dir = side_dirs[randi() % side_dirs.size()]
		elif reverse_open:
			dir = rev_dir
	else:
		position = target_pos

	# Recalculate cell
	var nc := int(round((position.x - map_origin.x) / float(CELL_SIZE)))
	var nr := int(round((position.y - map_origin.y - 39.0) / float(CELL_SIZE)))
	nc = clampi(nc, 0, grid_cols - 1)
	nr = clampi(nr, 0, grid_rows - 1)
	if nc != cell.x or nr != cell.y:
		var old := cell
		cell = Vector2i(nc, nr)
		cell_changed.emit(old, cell)

	_update_visuals()

func check_bomber_collision(bomber: Node) -> void:
	if not alive or bomber == null:
		return
	if not bomber.get("alive") or bomber.get("in_bubble"):
		return

	var mon_center := position + Vector2(20.0, -20.0)
	var b_pos: Vector2 = bomber.position + Vector2(20.0, -20.0)
	if mon_center.distance_to(b_pos) < 26.0:
		if touch_damage_lethal:
			if bomber.has_method("pop_kill"):
				bomber.pop_kill()
		else:
			if bomber.has_method("trap_in_bubble"):
				bomber.trap_in_bubble()

func hit_by_flame(flame_cell: Vector2i) -> bool:
	if not alive:
		return false
	if flame_cell == cell:
		take_damage(1)
		return true
	return false

func take_damage(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	if not alive:
		return
	alive = false
	action = "die"
	die_timer = 0.0
	_update_visuals()
