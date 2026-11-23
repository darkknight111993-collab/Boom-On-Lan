class_name CPatternHandler
extends RefCounted

## Unified Monster AI Pattern Handlers & Special CNpcCollideStrategy Overrides.
## Ported from CA.exe:
## - CPatternHandlerLine     (0x778F21 / Execute 0x778FB9)
## - CPatternHandlerFree     (0x778CE4 / Execute 0x778D84)
## - CPatternHandlerChase    (0x7786B8 / Execute 0x778849, deadzone >10px @ 0x778936)
## - CPatternHandlerAvoid    (0x7782A8 / Execute 0x778592)
## - CPatternHandlerDefense  (0x778A11 / Execute 0x778BB5)
## - CPatternHandlerMonChase (0x7790CD / Execute 0x77925E)
## - CNpcCollideStrategy overrides (0xC576DC..0xC5795C)

const GRID_W := 15
const GRID_H := 13
const SAME_CELL_DEADZONE_PX := 10.0 # Verified at 0x778936 & 0x7793CA
const CStageClearScriptClass = preload("res://scripts/modes/c_stage_clear_script.gd")

# CA.exe Pattern direction convention (0x778FB9 / 0x778D84):
# 0 = Up (0,-1), 1 = Left (-1,0), 2 = Down (0,+1), 3 = Right (+1,0)
const DIR_UP := 0
const DIR_LEFT := 1
const DIR_DOWN := 2
const DIR_RIGHT := 3

const DIR_VECS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(1, 0),
]

# Maps pattern dir (0=U,1=L,2=D,3=R) <-> CGOBomber/CGONpcBasicMon dir (0=D,1=U,2=L,3=R)
static func to_bomber_dir(pat_dir: int) -> int:
	match pat_dir:
		DIR_UP: return 1
		DIR_LEFT: return 2
		DIR_DOWN: return 0
		DIR_RIGHT: return 3
		_: return 0

static func from_bomber_dir(bomber_dir: int) -> int:
	match bomber_dir:
		1: return DIR_UP
		2: return DIR_LEFT
		0: return DIR_DOWN
		3: return DIR_RIGHT
		_: return DIR_DOWN

static func _is_cell_open(c: Vector2i, is_blocked: Callable, grid_w: int = GRID_W, grid_h: int = GRID_H) -> bool:
	if c.x < 0 or c.x >= grid_w or c.y < 0 or c.y >= grid_h:
		return false
	if is_blocked.is_valid():
		return not bool(is_blocked.call(c.x, c.y))
	return true

static func _open_dirs(cell: Vector2i, is_blocked: Callable, grid_w: int = GRID_W, grid_h: int = GRID_H) -> Array[int]:
	var dirs: Array[int] = []
	for d in 4:
		if _is_cell_open(cell + DIR_VECS[d], is_blocked, grid_w, grid_h):
			dirs.append(d)
	return dirs

static func _pick_open_dir(cell: Vector2i, cur_dir: int, is_blocked: Callable, rng: RandomNumberGenerator = null, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var open := _open_dirs(cell, is_blocked, grid_w, grid_h)
	if open.is_empty():
		return cur_dir
	var non_cur: Array[int] = []
	for d in open:
		if d != cur_dir:
			non_cur.append(d)
	var pool := non_cur if not non_cur.is_empty() else open
	var idx := rng.randi() % pool.size() if rng != null else randi() % pool.size()
	return pool[idx]

## 1. CPatternHandlerLine::Execute (0x778FB9)
## Walks straight until next tile in cur_dir is blocked, then picks a new open direction.
static func step_line(cell: Vector2i, cur_dir: int, is_blocked: Callable, rng: RandomNumberGenerator = null, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var d := clampi(cur_dir, 0, 3)
	if _is_cell_open(cell + DIR_VECS[d], is_blocked, grid_w, grid_h):
		return d
	return _pick_open_dir(cell, d, is_blocked, rng, grid_w, grid_h)

## 2. CPatternHandlerFree::Execute (0x778D84)
## Walks until blocked OR until open 4-way neighbor count v8 changes at a junction.
static func step_free(cell: Vector2i, cur_dir: int, prev_open_count: int, is_blocked: Callable, rng: RandomNumberGenerator = null, grid_w: int = GRID_W, grid_h: int = GRID_H) -> Dictionary:
	var d := clampi(cur_dir, 0, 3)
	var open := _open_dirs(cell, is_blocked, grid_w, grid_h)
	var open_count := open.size()
	var forward_open := _is_cell_open(cell + DIR_VECS[d], is_blocked, grid_w, grid_h)
	var junction_changed := prev_open_count >= 0 and open_count != prev_open_count and open_count >= 2
	var next_dir := d
	if not forward_open or junction_changed:
		next_dir = _pick_open_dir(cell, d, is_blocked, rng, grid_w, grid_h)
	return {"dir": next_dir, "open_count": open_count}

## 3. CPatternHandlerChase::Execute (0x778849)
## Steers toward nearest alive player within user_dist tiles; uses >10px deadzone on same tile (0x778936).
## Each entry in targets: {"cell": Vector2i, "pos": Vector2, "alive": bool, "in_bubble": bool}
static func step_chase(cell: Vector2i, mon_px: Vector2, cur_dir: int, targets: Array, user_dist: int, is_blocked: Callable, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var best_idx := -1
	var best_dist := 999999
	for i in targets.size():
		var t: Dictionary = targets[i]
		if not bool(t.get("alive", true)):
			continue
		var tc: Vector2i = t.get("cell", cell)
		var md := absi(tc.x - cell.x) + absi(tc.y - cell.y)
		if user_dist > 0 and md > user_dist:
			continue
		if md < best_dist:
			best_dist = md
			best_idx = i
	if best_idx < 0:
		return -1

	var target: Dictionary = targets[best_idx]
	var t_cell: Vector2i = target.get("cell", cell)
	var t_px: Vector2 = target.get("pos", mon_px)

	# Same-cell pixel deadzone (> 10px, verified at 0x778936)
	if t_cell == cell:
		var dx := t_px.x - mon_px.x
		var dy := t_px.y - mon_px.y
		if absf(dx) > SAME_CELL_DEADZONE_PX or absf(dy) > SAME_CELL_DEADZONE_PX:
			if absf(dx) >= absf(dy):
				return DIR_RIGHT if dx > 0.0 else DIR_LEFT
			else:
				return DIR_DOWN if dy > 0.0 else DIR_UP
		return cur_dir

	# Pick open direction that minimizes Manhattan distance to target cell
	var open := _open_dirs(cell, is_blocked, grid_w, grid_h)
	if open.is_empty():
		return cur_dir
	var best_dir := open[0]
	var best_score := 999999
	for d in open:
		var nc := cell + DIR_VECS[d]
		var score := absi(t_cell.x - nc.x) + absi(t_cell.y - nc.y)
		if score < best_score:
			best_score = score
			best_dir = d
	return best_dir

## 4. CPatternHandlerAvoid::Execute (0x778592)
## Scores all open neighbor cells and picks the one maximizing total distance from alive non-trapped players.
static func step_avoid(cell: Vector2i, cur_dir: int, players: Array, is_blocked: Callable, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var active_cells: Array[Vector2i] = []
	for p in players:
		var pd: Dictionary = p
		if not bool(pd.get("alive", true)) or bool(pd.get("in_bubble", false)):
			continue
		active_cells.append(pd.get("cell", cell))
	if active_cells.is_empty():
		return -1

	var open := _open_dirs(cell, is_blocked, grid_w, grid_h)
	if open.is_empty():
		return cur_dir
	var best_dir := open[0]
	var best_score := -1
	for d in open:
		var nc := cell + DIR_VECS[d]
		var min_d2 := 999999
		var total_d2 := 0
		for pc in active_cells:
			var dx := pc.x - nc.x
			var dy := pc.y - nc.y
			var d2 := dx * dx + dy * dy
			min_d2 = mini(min_d2, d2)
			total_d2 += d2
		var score := min_d2 * 1000 + total_d2
		if score > best_score:
			best_score = score
			best_dir = d
	return best_dir

## 5. CPatternHandlerDefense::Execute (0x778BB5)
## Keeps moving if next cell stays inside defense_rect; otherwise rebounds randomly inside defense_rect.
static func step_defense(cell: Vector2i, cur_dir: int, defense_rect: Rect2i, is_blocked: Callable, rng: RandomNumberGenerator = null, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var d := clampi(cur_dir, 0, 3)
	var next_c := cell + DIR_VECS[d]
	if defense_rect.has_point(next_c) and _is_cell_open(next_c, is_blocked, grid_w, grid_h):
		return d

	var inside_open: Array[int] = []
	for td in 4:
		var nc := cell + DIR_VECS[td]
		if defense_rect.has_point(nc) and _is_cell_open(nc, is_blocked, grid_w, grid_h):
			inside_open.append(td)
	if not inside_open.is_empty():
		var idx := rng.randi() % inside_open.size() if rng != null else randi() % inside_open.size()
		return inside_open[idx]
	return _pick_open_dir(cell, d, is_blocked, rng, grid_w, grid_h)

## 6. CPatternHandlerMonChase::Execute (0x77925E)
## Same as Chase, targeting other alive CGONpcBasicMon instances (excluding self_id).
static func step_mon_chase(self_id: int, cell: Vector2i, mon_px: Vector2, cur_dir: int, monsters: Array, user_dist: int, is_blocked: Callable, grid_w: int = GRID_W, grid_h: int = GRID_H) -> int:
	var filtered: Array = []
	for m in monsters:
		var md: Dictionary = m
		if int(md.get("id", -1)) == self_id:
			continue
		if not bool(md.get("alive", true)):
			continue
		filtered.append(md)
	if filtered.is_empty():
		return -1
	return step_chase(cell, mon_px, cur_dir, filtered, user_dist, is_blocked, grid_w, grid_h)

## Specialized CNpcCollideStrategy overrides (0xC576DC..0xC5795C).
## Returns true when standard bomber-bump collision must be skipped.
static func should_skip_collision(npc_type: String, state_idx: int, npc_type_id: int = -1) -> bool:
	var t := npc_type.strip_edges().to_lower()
	match t:
		"icemon":
			# CIceMonCollider (0x73FB58): skip in frozen/shell states {19, 22, 23}
			return state_idx == 19 or state_idx == 22 or state_idx == 23
		"starfishmon":
			# CStarFishMonCollider (0x73FE6B): skip in kick/spin states {18, 19, 20, 21}
			return state_idx >= 18 and state_idx <= 21
		"bouncemon":
			# CBounceMonCollider (0x7400F6): skip while airborne {14, 15, 16, 17}
			return state_idx >= 14 and state_idx <= 17
		"largepoopoo":
			# CLargePooPooCollider (0x73F595): always skips standard bomber bump
			return true
		"minigolem", "rollinggolem":
			# CMiniGolemCollider (0x73F66F): skips when NpcType == 26 (rolling variant)
			var tid: int = npc_type_id if npc_type_id >= 0 else CStageClearScriptClass.get_npc_type_id(t)
			return tid == 26
		_:
			return false

static func is_snowbear_charge_state(npc_type: String, state_idx: int) -> bool:
	# CSnowBearMonCollider (0x73F431): special charge override only when state > 36
	return npc_type.strip_edges().to_lower() == "snowbear" and state_idx > 36
