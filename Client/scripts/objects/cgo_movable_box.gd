class_name CGOTileMovableBox
extends "res://scripts/objects/cgo_tile.gd"

## CGOTileMovableBox - Hộp có thể đẩy trượt ô
## Ported from CA.exe CGOTileMovableBox (sub_45D9C2, sub_45D9DE, sub_224150)

signal box_moved(from_cell: Vector2i, to_cell: Vector2i)

@export var slide_speed: float = 160.0 # Speed when sliding to new cell
var is_sliding: bool = false
var target_anchor: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	tile_type = Type.BOX

func push(dir: Vector2i, is_cell_blocked: Callable) -> bool:
	if is_broken or is_sliding:
		return false
	
	var target_c := cell + dir
	if target_c.x < 0 or target_c.x >= 15 or target_c.y < 0 or target_c.y >= 13:
		return false
	
	if is_cell_blocked.is_valid() and is_cell_blocked.call(target_c.x, target_c.y):
		return false
	
	# Start sliding
	var old_cell := cell
	set_cell(target_c.x, target_c.y)
	target_anchor = get_cell_anchor(target_c.x, target_c.y)
	# Reset position back to old position so it animates forward
	position = get_cell_anchor(old_cell.x, old_cell.y)
	is_sliding = true
	box_moved.emit(old_cell, target_c)
	return true

func _physics_process(delta: float) -> void:
	if not is_sliding:
		return
	
	position = position.move_toward(target_anchor, slide_speed * delta)
	if position.distance_squared_to(target_anchor) < 0.1:
		position = target_anchor
		is_sliding = false
