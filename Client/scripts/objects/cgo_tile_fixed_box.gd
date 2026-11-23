class_name CGOTileFixedBox
extends "res://scripts/objects/cgo_tile_fixed.gd"

## Breakable stationary box tile (CA.exe RTTI .?AVCGOTileFixedBox@@ @ 0xe2fdf0, ctor sub_5BF25F, Init sub_5BF3C0).
## Supports multi-hit HP (b[4]), indestructible boxes (hp >= 255, sub_5BF6F9), 15-tick hit-flash (sub_5BF711),
## and chain explosion on break (b[13], sub_5BF5BD -> sub_7322B5).

signal box_broken(box: CGOTileFixedBox, col: int, row: int)
signal explode_requested(col: int, row: int)

const HIT_FLASH_TICKS := 14 # 15 ticks inclusive (14..0) in sub_5BF711 & sub_5BF5BD

var hp: int = 1
var max_hp: int = 1
var spike_dir_mask: int = 0
var explode_on_break: bool = false
var hit_flash_ticks: int = -1
var is_broken: bool = false

func init_tile(info: CTileInfoClass, obj_id: int, col: int, row: int) -> void:
	super.init_tile(info, obj_id, col, row)
	if info != null:
		hp = info.hp if info.hp > 0 else CTileInfoClass.DEFAULT_BOX_HP
		max_hp = hp
		spike_dir_mask = info.spike_dir_mask
		explode_on_break = info.explode_on_break
	else:
		hp = CTileInfoClass.DEFAULT_BOX_HP
		max_hp = hp
		spike_dir_mask = 0
		explode_on_break = false
	hit_flash_ticks = -1
	is_broken = false

func is_indestructible() -> bool:
	# From sub_5BF6F9: hp >= 255
	return hp >= CTileInfoClass.INDESTRUCTIBLE_HP

func on_hit(force_destroy: bool = false) -> bool:
	# From sub_5BF711 (CGOTileFixedBox::OnHit)
	if not tile_active or is_broken:
		return false
	if force_destroy:
		hp = 0
	elif not is_indestructible():
		hp = maxi(hp - 1, 0)
	if hp > 0:
		hit_flash_ticks = HIT_FLASH_TICKS
		return false
	is_broken = true
	hit_flash_ticks = -1
	box_broken.emit(self, cell.x, cell.y)
	return true

func finish_break() -> void:
	# From sub_5BF5BD (CGOTileFixedBox::Update)
	tile_active = false
	if explode_on_break:
		explode_requested.emit(cell.x, cell.y)

static func calc_shaken_state_index(cur_idx: int) -> int:
	# From sub_5BF1B3 / sub_5C0753: odd idle states (1,3,5,7) -> even shaken states (2,4,6,8)
	if cur_idx < 1:
		return 2
	if (cur_idx % 2) != 0:
		return cur_idx + 1
	return cur_idx

static func calc_damaged_state_index(remaining_hp: int, total_states: int) -> int:
	# From sub_5BF5BD @ 0x5bf5ff..0x5bf633: next idle crack state after 15-tick shake
	var idx: int = 1 - 2 * remaining_hp + total_states
	return idx if idx >= 1 else 1

func _on_tick() -> void:
	if hit_flash_ticks >= 0:
		hit_flash_ticks -= 1
