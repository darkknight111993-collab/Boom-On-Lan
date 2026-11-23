class_name CGameItemMan
extends RefCounted

## Match-level active item & ground-trap manager (CA.exe CItemMan @ 0xe48008 -> CGameItemMan @ 0xe47fec).
## Coordinates ground trap placement (0x5BFE98 / 0x59AA2B), trigger guards (0x89B145),
## trap execution (0x89B623 -> 0x593737 Banana slide / 0x597233 Bond slow / Mine bubble),
## and active item usage guard (0x89B21F / 0x889E0B).

const CGOTileGroundClass = preload("res://scripts/objects/cgo_tile_ground.gd")
const CTileInfoClass = preload("res://scripts/objects/ctile_info.gd")

const BOND_DURATION_TICKS := 400 # 12s @ 30ms (sub_597233)

var ground_traps: Dictionary = {} # Vector2i -> {tile: CGOTileGround, sprite: Sprite2D}

func clear() -> void:
	for entry in ground_traps.values():
		var t: Variant = entry.get("tile", null)
		if is_instance_valid(t):
			t.free()
		var sp: Variant = entry.get("sprite", null)
		if is_instance_valid(sp):
			(sp as Node).queue_free()
	ground_traps.clear()

static func can_use_active_item(bomber: Variant) -> bool:
	# From sub_89B21F & sub_889E0B
	if bomber == null:
		return false
	return bool(bomber.alive) and not bool(bomber.is_ghost) and int(bomber.start_ticks) <= 0

func can_place_ground_trap(gp: Vector2i, trap_type: int, cols: int, rows: int, tile_kind: int) -> bool:
	# From sub_59AA2B / sub_5BFE98
	if gp.x < 0 or gp.x >= cols or gp.y < 0 or gp.y >= rows:
		return false
	if trap_type == CGOTileGroundClass.TRAP_NONE or ground_traps.has(gp):
		return false
	return tile_kind == 0 or tile_kind == 3

func place_ground_trap(
	gp: Vector2i,
	trap_type: int,
	owner_id: int,
	cols: int,
	rows: int,
	tile_kind: int,
	ground_info: Variant = null,
	map_origin: Vector2 = Vector2.ZERO,
	parent_node: Node2D = null,
	cell_anchor: Vector2 = Vector2.ZERO,
	sprite_db: Object = null
) -> bool:
	# From CGOTileGround::SetGroundTrap (0x5BFE98)
	if not can_place_ground_trap(gp, trap_type, cols, rows, tile_kind):
		return false
	var g_tile := CGOTileGroundClass.new()
	g_tile.map_origin = map_origin
	g_tile.init_tile(ground_info if ground_info is CTileInfoClass else null, -1, gp.x, gp.y)
	g_tile.set_ground_trap(trap_type, owner_id)
	var sp: Sprite2D = null
	if parent_node != null and sprite_db != null:
		var sp_path: String = CGOTileGroundClass.get_trap_sprite_path(trap_type)
		if sp_path != "":
			var f: Dictionary = sprite_db.call("get_frame", sp_path, 0)
			if not f.is_empty():
				sp = Sprite2D.new()
				sp.centered = false
				sp.texture = f.texture
				sp.position = Vector2(cell_anchor.x - f.offset.x, cell_anchor.y - f.offset.y)
				sp.z_index = 1 + gp.y
				parent_node.add_child(sp)
	ground_traps[gp] = {"tile": g_tile, "sprite": sp}
	return true

func try_place_bomber_trap(
	bomber: Variant,
	trap_type: int,
	cols: int,
	rows: int,
	tile_kind: int,
	ground_info: Variant = null,
	map_origin: Vector2 = Vector2.ZERO,
	parent_node: Node2D = null,
	cell_anchor: Vector2 = Vector2.ZERO,
	sprite_db: Object = null
) -> bool:
	# From CGOBomber::PlaceGroundTrap (0x59AA2B): check placement before consuming charge
	if not can_use_active_item(bomber) or bool(bomber.in_bubble):
		return false
	if trap_type == CGOTileGroundClass.TRAP_NONE:
		return false
	if not can_place_ground_trap(bomber.cell, trap_type, cols, rows, tile_kind):
		return false
	if not bomber.consume_ground_trap(trap_type):
		return false
	if not place_ground_trap(bomber.cell, trap_type, int(bomber.player_id), cols, rows, tile_kind, ground_info, map_origin, parent_node, cell_anchor, sprite_db):
		return false
	bomber._placed_trap_cell = bomber.cell # 0x59AA2B @ 0x59ad96
	return true

static func resolve_banana_slide_dir(bomber_dir: int, move_dir: Vector2, ground_info: Variant = null) -> int:
	# From CGOBomber::StartSlide (0x593737): active move_dir -> conveyor visual dir (0x5BFA0A) -> bomber_dir
	if move_dir != Vector2.ZERO:
		if absf(move_dir.x) > absf(move_dir.y):
			return 3 if move_dir.x > 0 else 2
		return 0 if move_dir.y > 0 else 1
	if ground_info is CTileInfoClass and ground_info.is_conveyor:
		var vis_dir: int = CGOTileGroundClass.get_conveyor_visual_dir(
			ground_info.conveyor_speed_px_per_tick,
			ground_info.conveyor_in_mask,
			ground_info.conveyor_out_dir
		)
		if vis_dir >= 0 and vis_dir < 4:
			const CONV_TO_BOMBER_DIR: Array[int] = [2, 1, 3, 0] # 0=L->2, 1=U->1, 2=R->3, 3=D->0
			return CONV_TO_BOMBER_DIR[vis_dir]
	return clampi(bomber_dir, 0, 3)

func check_bomber_ground_trap(
	bomber: Variant,
	move_dir: Vector2,
	ground_info: Variant,
	can_fit_cb: Callable,
	cell_anchor: Vector2,
	dismount_cb: Callable = Callable()
) -> int:
	# From sub_59C2B2 -> sub_89B145 (guard) -> sub_89B623 (execute) -> sub_593737 (Banana slide)
	if bomber == null or not bool(bomber.alive) or bool(bomber.in_bubble) or bool(bomber.is_ghost) or int(bomber.slide_ticks) > 0:
		return CGOTileGroundClass.TRAP_NONE
	if bomber.cell == bomber._placed_trap_cell:
		return CGOTileGroundClass.TRAP_NONE # Self-trap immunity until bomber leaves cell (0x59C2B2 @ 0x59c376)
	if not ground_traps.has(bomber.cell):
		return CGOTileGroundClass.TRAP_NONE
	var entry: Dictionary = ground_traps[bomber.cell]
	var g_tile: CGOTileGroundClass = entry.get("tile", null)
	if g_tile == null:
		ground_traps.erase(bomber.cell)
		return CGOTileGroundClass.TRAP_NONE
	var is_flying: bool = bomber.mount != null and bool(bomber.mount.get("is_flying", false))
	if not g_tile.can_trigger_trap(is_flying, bool(bomber.is_shielded)):
		return CGOTileGroundClass.TRAP_NONE
	var t_type: int = g_tile.trap_type
	g_tile.clear_ground_trap()
	var sp: Variant = entry.get("sprite", null)
	if is_instance_valid(sp):
		(sp as Node).queue_free()
	if is_instance_valid(g_tile):
		g_tile.free()
	ground_traps.erase(bomber.cell)
	match t_type:
		CGOTileGroundClass.TRAP_BANANA:
			var slide_dir: int = resolve_banana_slide_dir(int(bomber.dir), move_dir, ground_info)
			bomber.start_slide(slide_dir, 0, can_fit_cb)
		CGOTileGroundClass.TRAP_BOND:
			bomber.bond_ticks = BOND_DURATION_TICKS
		CGOTileGroundClass.TRAP_MINE:
			if bomber.mount != null and dismount_cb.is_valid():
				dismount_cb.call(bomber)
			elif bomber.mount != null:
				bomber.destroy_mount()
			else:
				bomber.position = cell_anchor
				bomber.trap_in_bubble()
	return t_type
