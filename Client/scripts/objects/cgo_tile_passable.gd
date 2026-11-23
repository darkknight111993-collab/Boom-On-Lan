class_name CGOTilePassable
extends "res://scripts/objects/cgo_tile_fixed.gd"

## Passable bush / tent / water tile (CA.exe RTTI .?AVCGOTilePassable@@ @ 0xe304bc, ctor sub_5C12BF, type == 3).
## Directional passability: b[12..15] (sub_5C10E1).
## Bomber concealment: b[19] == 0 (sub_59F04D).
## Flame permanence: b[24] != 0 (sub_70F346).

func blocks_movement() -> bool:
	return tile_active and tile_info != null and tile_info.blocks_movement

func blocks_flame() -> bool:
	return tile_active and tile_info != null and tile_info.blocks_flame

func is_concealing() -> bool:
	return tile_active and tile_info != null and tile_info.conceals_bomber

func is_player_passable_from_dir(dir_idx: int) -> bool:
	# From sub_5C0E98 (b[4..7])
	if not tile_active or tile_info == null:
		return true
	if dir_idx < 0 or dir_idx >= tile_info.player_passable_dirs.size():
		return false
	return tile_info.player_passable_dirs[dir_idx]

func is_bomb_passable_from_dir(dir_idx: int) -> bool:
	# From sub_5C1030 (b[8..11]): allows bombs to pass even when player_passable_dirs is all false
	if not tile_active or tile_info == null:
		return true
	if dir_idx < 0 or dir_idx >= tile_info.bomb_passable_dirs.size():
		return false
	return tile_info.bomb_passable_dirs[dir_idx]

func is_passable_from_dir(dir_idx: int) -> bool:
	# From sub_5C10E1 (dir_idx 0..3 -> b[12..15], flame passable)
	if not tile_active or tile_info == null:
		return true
	if dir_idx < 0 or dir_idx >= tile_info.passable_dirs.size():
		return false
	return tile_info.passable_dirs[dir_idx]

func detonates_bomb_on_touch() -> bool:
	# PinTile01 / spike pit (b[18] != 0)
	return tile_active and tile_info != null and tile_info.detonate_bomb_on_touch

func on_flame_hit() -> bool:
	# From sub_70F346 @ 0x70f47c / 0x70f5e8: burnable iff b[24] == 0
	if not tile_active or tile_info == null:
		return false
	if tile_info.indestructible_by_flame:
		return false
	tile_active = false
	return true

static func can_traverse_step(from_tile: Variant, to_tile: Variant, dir_idx: int, mode: int) -> bool:
	# Pure 4-dir exit+entry check (sub_5C0E98/sub_5C0F18 player, sub_5C1030/sub_5C107A bomb, sub_5C10E1/sub_5C1136 flame).
	# dir_idx: 0=Left, 1=Up, 2=Right, 3=Down; opp = (dir_idx + 2) % 4. mode: 0=player, 1=bomb, 2=flame.
	if dir_idx < 0 or dir_idx > 3:
		return true
	var opp: int = (dir_idx + 2) % 4
	if from_tile is CGOTilePassable:
		var ft: CGOTilePassable = from_tile
		match mode:
			0:
				if not ft.is_player_passable_from_dir(dir_idx):
					return false
			1:
				if not ft.is_bomb_passable_from_dir(dir_idx):
					return false
			2:
				if not ft.is_passable_from_dir(dir_idx):
					return false
	if to_tile is CGOTilePassable:
		var tt: CGOTilePassable = to_tile
		match mode:
			0:
				if not tt.is_player_passable_from_dir(opp):
					return false
			1:
				if not tt.is_bomb_passable_from_dir(opp):
					return false
			2:
				if not tt.is_passable_from_dir(opp):
					return false
	return true
