class_name CGOTile
extends "res://scripts/objects/c_game_object.gd"

## Base class for all map tile entities (CA.exe RTTI .?AVCGOTile@@ @ 0xe241c4, ctor sub_5BEC86).

const CTileInfoClass = preload("res://scripts/objects/ctile_info.gd")

var tile_info: CTileInfoClass = null
var object_id: int = -1
var tile_active: bool = true

func init_tile(info: CTileInfoClass, obj_id: int, col: int, row: int) -> void:
	tile_info = info
	object_id = obj_id
	tile_active = true
	set_cell(col, row)

func blocks_movement() -> bool:
	return tile_active and tile_info != null and tile_info.blocks_movement

func blocks_flame() -> bool:
	return tile_active and tile_info != null and tile_info.blocks_flame
