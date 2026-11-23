class_name CGOTileStatic
extends "res://scripts/objects/cgo_tile_fixed.gd"

## Unbreakable wall / obstacle tile (CA.exe RTTI .?AVCGOTileStatic@@ @ 0xe2418c, ctor sub_5C157A, Init sub_5C1611, type == 1).

func get_custom_static_id() -> int:
	# From sub_5C15DF (returns *(DWORD*)(this[43] + 16))
	return tile_info.custom_static_id if tile_info != null else 0

func is_capturable_static() -> bool:
	# From sub_743780 @ 0x743913: custom_static_id in 10001..10199
	var cid: int = get_custom_static_id()
	return cid >= 10001 and cid <= 10199

func get_captured_sprite_name() -> String:
	# From sub_7453F6 @ 0x745461..0x745485: 10101..10199 -> "Tile15_Static/Aft%02d"
	var cid: int = get_custom_static_id()
	if cid >= 10101 and cid <= 10199:
		return "Tile15_Static/Aft%02d" % (cid - 10100)
	return ""
