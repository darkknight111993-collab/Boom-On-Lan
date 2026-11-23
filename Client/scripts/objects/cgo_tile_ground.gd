class_name CGOTileGround
extends "res://scripts/objects/cgo_tile.gd"

## Ground map tile (CA.exe RTTI .?AVCGOTileGround@@ @ 0xe303c4, ctor sub_5C0095, type == 0).
## Conveyor push: sub_5BFA43 (b[12] px/tick, b[16] center-pull in-mask, b[20] push-out dir).
## Conveyor visual dir: sub_5BFA0A.

const CONVEYOR_TICK_SEC := 0.03 # 30ms/tick in original client
const CONVEYOR_DIR_VECTORS: Array[Vector2] = [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]

# Ground trap types (CGOTileGround::SetGroundTrap @ 0x5BFE98, trigger @ 0x89B145 / 0x89B623)
const TRAP_NONE := 0
const TRAP_BOND := 1    # Item/BondGround (glue slow 12s = 400 ticks @ 0x597233)
const TRAP_MINE := 2    # Landmine (dismount or trap in bubble @ 0x89B623)
const TRAP_BANANA := 3  # Item/BananaGround (triggers SlideJump/SlideRide @ 0x593737)
const TRAP_PUSHPIN := 4 # Item/PushpinGround (skipped for bombers @ 0x89B145)

var trap_type: int = TRAP_NONE
var trap_active: bool = false
var trap_owner_id: int = -1

func set_ground_trap(t_type: int, owner_id: int = -1) -> void:
	# From sub_5BFE98 (CGOTileGround::SetGroundTrap)
	trap_type = t_type
	trap_active = t_type != TRAP_NONE
	trap_owner_id = owner_id

func clear_ground_trap() -> void:
	# From sub_5C01FD (CGOTileGround::ClearGroundTrap)
	trap_type = TRAP_NONE
	trap_active = false
	trap_owner_id = -1

func can_trigger_trap(is_flying: bool, is_shielded: bool) -> bool:
	# From sub_89B145: Bond(1)/Banana(3) skip flying; Mine(2) skips shielded; Pushpin(4) skips bombers
	if not trap_active:
		return false
	match trap_type:
		TRAP_BOND, TRAP_BANANA:
			return not is_flying
		TRAP_MINE:
			return not is_shielded
		TRAP_PUSHPIN:
			return false
		_:
			return false

static func get_trap_sprite_path(t_type: int) -> String:
	# From sub_5BFE98: exact ground trap sprite paths
	match t_type:
		TRAP_BOND: return "Item/BondGround"
		TRAP_BANANA: return "Item/BananaGround"
		TRAP_PUSHPIN: return "Item/PushpinGround"
		_: return ""

func blocks_movement() -> bool:
	return false

func blocks_flame() -> bool:
	return false

static func get_conveyor_visual_dir(speed_px: int, in_mask: int, out_dir: int) -> int:
	# From sub_5BFA0A: first set bit of in_mask (0..3), else out_dir
	if speed_px <= 0:
		return -1
	if (in_mask & 1) != 0:
		return 0
	if (in_mask & 2) != 0:
		return 1
	if (in_mask & 4) != 0:
		return 2
	if (in_mask & 8) != 0:
		return 3
	return out_dir

static func compute_conveyor_step(pos: Vector2, tile_anchor: Vector2, speed_px: int, in_mask: int, out_dir: int, delta: float) -> Vector2:
	# From sub_5BFA43 (CGOTileGround::ApplyConveyor):
	# Phase 1 pulls bomber toward tile_anchor along in_mask axes; Phase 2 pushes along out_dir once centered.
	if speed_px <= 0 or delta <= 0.0:
		return Vector2.ZERO
	var budget: float = float(speed_px) * (delta / CONVEYOR_TICK_SEC)
	var rem: float = budget
	var move := Vector2.ZERO
	if (in_mask & 1) != 0 and pos.x > tile_anchor.x:
		var s: float = minf(rem, pos.x - tile_anchor.x)
		move.x -= s
		rem -= s
	if (in_mask & 2) != 0 and pos.y > tile_anchor.y:
		var s: float = minf(rem, pos.y - tile_anchor.y)
		move.y -= s
		rem -= s
	if (in_mask & 4) != 0 and pos.x < tile_anchor.x:
		var s: float = minf(rem, tile_anchor.x - pos.x)
		move.x += s
		rem -= s
	if (in_mask & 8) != 0 and pos.y < tile_anchor.y:
		var s: float = minf(rem, tile_anchor.y - pos.y)
		move.y += s
		rem -= s
	if rem >= budget - 0.0001 and out_dir >= 0 and out_dir < CONVEYOR_DIR_VECTORS.size():
		move += CONVEYOR_DIR_VECTORS[out_dir] * rem
	return move

func get_visual_dir() -> int:
	if tile_info == null:
		return -1
	return get_conveyor_visual_dir(tile_info.conveyor_speed_px_per_tick, tile_info.conveyor_in_mask, tile_info.conveyor_out_dir)
