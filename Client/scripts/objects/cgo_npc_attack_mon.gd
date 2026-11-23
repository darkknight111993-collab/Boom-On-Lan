class_name CGONpcAttackMon
extends "res://scripts/objects/cgo_npc_basic_mon.gd"

## CGONpcAttackMon - Quái rượt đuổi / tấn công
## Ported from CA.exe CGONpcAttackMon (sub_5189C0, sub_518D41, sub_51906A)
## Inherits CGONpcBasicMon and adds line-of-sight aggro and charge speed.

@export var aggro_range: int = 8 # Maximum tiles in straight line to detect
@export var charge_speed: float = 140.0 # Faster speed when chasing

var is_charging: bool = false
var target_bomber: Node = null

func setup_attack_mon(m_id: String, col: int, row: int, base_speed: float = 80.0, c_speed: float = 140.0, drop_item: String = "Item/Bomb", initial_hp: int = 1) -> void:
	super.setup(m_id, col, row, base_speed, drop_item, initial_hp)
	charge_speed = c_speed

func scan_for_target(bombers: Array, is_cell_blocked: Callable) -> bool:
	if not alive:
		is_charging = false
		target_bomber = null
		return false
	
	target_bomber = null
	is_charging = false
	
	var cur_col := cell.x
	var cur_row := cell.y
	
	for b in bombers:
		if b == null or not is_instance_valid(b) or not b.get("alive") or b.get("in_bubble"):
			continue
		
		var b_cell: Vector2i = b.get("cell") if b.get("cell") != null else Vector2i.ZERO
		
		# Check horizontal line-of-sight (same row)
		if b_cell.y == cur_row:
			var dist := b_cell.x - cur_col
			if absi(dist) <= aggro_range:
				var clear := true
				var step_dir := 1 if dist > 0 else -1
				var c := cur_col + step_dir
				while c != b_cell.x:
					if is_cell_blocked.is_valid() and is_cell_blocked.call(c, cur_row):
						clear = false
						break
					c += step_dir
				if clear:
					is_charging = true
					target_bomber = b
					dir = 3 if step_dir > 0 else 2 # MON_DIR_NAMES: 0:Down, 1:Up, 2:Left, 3:Right
					return true
		
		# Check vertical line-of-sight (same column)
		elif b_cell.x == cur_col:
			var dist := b_cell.y - cur_row
			if absi(dist) <= aggro_range:
				var clear := true
				var step_dir := 1 if dist > 0 else -1
				var r := cur_row + step_dir
				while r != b_cell.y:
					if is_cell_blocked.is_valid() and is_cell_blocked.call(cur_col, r):
						clear = false
						break
					r += step_dir
				if clear:
					is_charging = true
					target_bomber = b
					dir = 0 if step_dir > 0 else 1 # Down (0) or Up (1)
					return true

	# Check proximity aggro (follow around corners within aggro_range)
	var best_target: Node = null
	var min_dist := aggro_range + 1
	for b in bombers:
		if b == null or not is_instance_valid(b) or not b.get("alive") or b.get("in_bubble"):
			continue
		var b_cell: Vector2i = b.get("cell") if b.get("cell") != null else Vector2i.ZERO
		var m_dist := absi(b_cell.x - cur_col) + absi(b_cell.y - cur_row)
		if m_dist <= aggro_range and m_dist < min_dist:
			min_dist = m_dist
			best_target = b

	if best_target != null:
		var bt_cell: Vector2i = best_target.get("cell")
		var dx := bt_cell.x - cur_col
		var dy := bt_cell.y - cur_row
		var candidates: Array[int] = []
		if dy > 0 and not is_cell_blocked.call(cur_col, cur_row + 1):
			candidates.append(0) # Down
		if dy < 0 and not is_cell_blocked.call(cur_col, cur_row - 1):
			candidates.append(1) # Up
		if dx < 0 and not is_cell_blocked.call(cur_col - 1, cur_row):
			candidates.append(2) # Left
		if dx > 0 and not is_cell_blocked.call(cur_col + 1, cur_row):
			candidates.append(3) # Right

		if not candidates.is_empty():
			is_charging = true
			target_bomber = best_target
			if dir in candidates:
				return true
			if absi(dx) >= absi(dy):
				var pref := [3 if dx > 0 else 2, 0 if dy > 0 else 1]
				for p in pref:
					if p in candidates:
						dir = p
						return true
			else:
				var pref := [0 if dy > 0 else 1, 3 if dx > 0 else 2]
				for p in pref:
					if p in candidates:
						dir = p
						return true
			dir = candidates[0]
			return true
					
	return false

func step_ai(delta: float, is_cell_blocked: Callable) -> void:
	if not alive:
		super.step_ai(delta, is_cell_blocked)
		return
	
	# Temporarily substitute speed if charging
	var orig_speed := move_speed
	if is_charging:
		move_speed = charge_speed
	
	super.step_ai(delta, is_cell_blocked)
	
	move_speed = orig_speed
