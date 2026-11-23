class_name CGOTileMoveAbleBox
extends "res://scripts/objects/cgo_tile.gd"

## Pushable box tile (CA.exe RTTI .?AVCGOTileMoveAbleBox@@ @ 0xe30498, dtor sub_5C0798).
## Inherits directly from CGOTile (not CGOTileFixed). Pushed via CPlayMap::PushMoveAbleBox (sub_730EF4).

signal box_broken(box: CGOTileMoveAbleBox, col: int, row: int)
signal explode_requested(col: int, row: int)

const HIT_FLASH_TICKS := 14

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
	return hp >= CTileInfoClass.INDESTRUCTIBLE_HP

func can_push() -> bool:
	return tile_active and not is_broken

func push_to(col: int, row: int) -> void:
	# From sub_730EF4 (CPlayMap::PushMoveAbleBox)
	set_cell(col, row)

func on_hit(force_destroy: bool = false) -> bool:
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
	tile_active = false
	if explode_on_break:
		explode_requested.emit(cell.x, cell.y)

func _on_tick() -> void:
	if hit_flash_ticks >= 0:
		hit_flash_ticks -= 1
