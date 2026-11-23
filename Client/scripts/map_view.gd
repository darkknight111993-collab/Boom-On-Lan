extends Node2D
# Map viewer & Battleground engine with:
# - Full 30ms fixed-tick ObjectTable animations (CGameObjectTemplate::sub_45F608)
# - CGOTilePassable bush shaking (sub_45E96E), CGOTileFixedBox breaking (sub_45DBF1)
# - CGOTileStaticReactive random/proximity triggers (sub_5F2B61)
# - CGOItem floating/shadow (sub_457DA7)
# - Playable character movement with Corner Sliding / Corner Assist (GAME_PLAN.md §5.1)
# - Bomb placement, one-way exit collision, 2.7s fuse & chain reaction (GAME_PLAN.md §5.2)
# - 4-direction water flame propagation, box breaking & item drops (GAME_PLAN.md §5.2)
# - Bubble trap, 5s countdown, teammate rescue & enemy pop kill (GAME_PLAN.md §5.3)
# - Item pickups: Bomb, Fire, Roller, MaxPower (GAME_PLAN.md §5.4)
# - Bot AI with danger evasion, tactical bomb placement & item seeking
# - HUD digital timer countdown (3:00 -> 0:00) and Game Over WIN/LOSE banners

const CELL := 40
const TICK_SEC := 0.03 # CA.exe fixed 30ms update tick (0x1E ms)

@export var embedded := false
@export var initial_map := "Camp08"
@export var show_spawns := true
@export var spawn_monsters_enabled := false # Tạm thời ẩn quái và NPC theo yêu cầu
@export var bot_ai_enabled := false # Tắt AI bot trên map test theo yêu cầu người dùng
@export var spawn_p2_enabled := true # Cho phép tắt P2/Bot trong màn test 1P thuần túy
@export var game_mode_id := 0 # CComponent::MODE_DEFAULT (0), MODE_HEDGEHOG (11) (sub_73D4B0)

const CComponentClass = preload("res://scripts/modes/c_component.gd")
const CMonsterComponentClass = preload("res://scripts/modes/c_monster_component.gd")
const CGOBossMonClass = preload("res://scripts/objects/cgo_boss_mon.gd")
const CGOMonMissileClass = preload("res://scripts/objects/cgo_mon_missile.gd")
var _mode_components: Array = [] # CGameStage::this[5413] active CComponent list (sub_70A304)
var _monster_comp: CMonsterComponentClass = null
var _mon_missiles: Array = []

func get_component(mode_id: int) -> CComponentClass:
	# From sub_70A304 (CGameStage::GetComponent)
	for comp in _mode_components:
		if comp != null and comp.get_type() == mode_id:
			return comp
	return null

func get_active_component() -> CComponentClass:
	var comp: CComponentClass = get_component(game_mode_id)
	if comp == null:
		comp = CComponentClass.create_for_mode(game_mode_id, self)
		_mode_components.append(comp)
	return comp

func _is_test_mode() -> bool:
	if not bot_ai_enabled:
		return true
	if _maps.size() > 0 and _cur < _maps.size():
		var mname: String = str(_maps[_cur])
		if mname.begins_with("DevTest") or mname.begins_with("Test") or mname == "Camp08":
			return true
	return false

var _table := {}
var _tile_info := {}
var _item_sprites := {}
var _bomber_attrs := {}
var _maps: PackedStringArray = []
var _cur := 0
var _label := Label.new()
var _tick_accum := 0.0
var _global_tick := 0
var _anim_nodes: Array[Dictionary] = []
var _cell_objects := {} # Vector2i(x, y) -> anim entry (Static / FixedBox / MoveAbleBox)
var _passable_objects := {} # Vector2i(x, y) -> anim entry (CGOTilePassable separate layer, sub_7293B4)
var _tiles := {} # Vector2i(x, y) -> CGOTile instance (Static / FixedBox / MoveAbleBox)
var _passable_tiles := {} # Vector2i(x, y) -> CGOTilePassable instance (sub_7293B4)
var _ground_tiles := {} # Vector2i(x, y) -> CTileInfo (conveyor/special ground)
var _game_item_man: CGameItemManClass = CGameItemManClass.new() # CGameItemMan (0xe47fec)
var _rail_ground_cells := {} # Vector2i(x, y) -> true (Rail ground for RailCar speed_alt, sub_597EC6)
var _player_last_passable_cell := {} # player_id -> Vector2i (triggers shake on every passable cell entry, ca.exe.c:343302)
var _flame_blocked := {} # Vector2i(x, y) -> bool (CPlayMap::loc_96C1F4, sub_72991D/sub_729970)
var _box_push_hold := {} # player_id -> {cell: Vector2i, dir: Vector2i, elapsed: float}
var _floating_items: Array[Dictionary] = []
var _pending_cell_items := {} # Vector2i(x, y) -> Dictionary (hidden item inside destructible block)
var _cur_map_drops: Array = []
var _cur_origin := Vector2.ZERO
var _cols := 15
var _rows := 13
var _next_id := 1

const CMapActionBombClass = preload("res://scripts/objects/c_map_action_bomb.gd")
const CTileInfoClass = preload("res://scripts/objects/ctile_info.gd")
const CGOTileClass = preload("res://scripts/objects/cgo_tile.gd")
const CGOTileGroundClass = preload("res://scripts/objects/cgo_tile_ground.gd")
const CGOTileStaticClass = preload("res://scripts/objects/cgo_tile_static.gd")
const CGOTileFixedBoxClass = preload("res://scripts/objects/cgo_tile_fixed_box.gd")
const CGOTileMoveAbleBoxClass = preload("res://scripts/objects/cgo_tile_movable_box.gd")
const CGOTilePassableClass = preload("res://scripts/objects/cgo_tile_passable.gd")
const CGONpcBasicMonClass = preload("res://scripts/objects/cgo_npc_basic_mon.gd")
const CGONpcAttackMonClass = preload("res://scripts/objects/cgo_npc_attack_mon.gd")
const CGONpcMonEggClass = preload("res://scripts/objects/cgo_npc_mon_egg.gd")
const CGODartClass = preload("res://scripts/objects/cgo_dart.gd")
const CItemAttrClass = preload("res://scripts/objects/citem_attr.gd")
const CGameItemManClass = preload("res://scripts/objects/c_game_item_man.gd")
const CGOGlyphClass = preload("res://scripts/objects/cgo_glyph.gd")
const CGOExplosionClass = preload("res://scripts/objects/cgo_explosion.gd")

# Gameplay state (when embedded in GameStage)
var _map_action_bomb: Node2D = null
var _players: Array[CGOBomber] = []
var _bombs: Array[Dictionary] = []
var _flames: Array[Dictionary] = []
var _tank_projectiles: Array[Dictionary] = []
var _monsters: Array[Node2D] = []
var _darts: Array[Node2D] = []
var _traps: Array[Node2D] = []
var _match_seconds_left := 180.0
var _match_over := false
var _match_over_timer := 0.0
var _start_banner: Node2D = null
var _result_banner: Node2D = null
var _item_hud_slots: Array[Dictionary] = [] # 1P/2P Ctrl item icons inside Game/ItemBox01 (647, 466)
var _personal_hud_slots: Array[Dictionary] = [] # 6 slots (keys 1..6) inside Game/GameStageItem (152, 564)

static func get_map_origin(cols: int, rows: int) -> Vector2:
	var ox := 20.0 if cols > 15 else (CELL * (15 - cols) / 2.0 + 20.0)
	var oy := 41.0 if rows > 13 else (CELL * (13 - rows) / 2.0 + 41.0)
	return Vector2(ox, oy)

var _camera_scroll: Vector2 = Vector2.ZERO
var _base_offset: Vector2 = Vector2.ZERO

static func compute_camera_focus(p1_pos: Vector2, p1_alive: bool, p2_pos: Vector2, p2_alive: bool, is_2p: bool) -> Vector2:
	if is_2p:
		if p1_alive and p2_alive:
			return (p1_pos + p2_pos) * 0.5
		if p2_alive and not p1_alive:
			return p2_pos
	return p1_pos

static func compute_camera_scroll(target_px: Vector2, cols: int, rows: int, origin: Vector2) -> Vector2:
	var max_x := maxf(0.0, float(cols * CELL) - 600.0)
	var max_y := maxf(0.0, float(rows * CELL) - 520.0)
	var sx := clampf(target_px.x - origin.x - 300.0, 0.0, max_x) if max_x > 0.0 else 0.0
	var sy := clampf(target_px.y - origin.y - 260.0, 0.0, max_y) if max_y > 0.0 else 0.0
	return Vector2(sx, sy)

func _update_scrolling_camera(delta: float, snap: bool = false) -> void:
	if _cols <= 15 and _rows <= 13:
		_camera_scroll = Vector2.ZERO
		position = _base_offset
		return
	var focus_px := _cur_origin
	if not _players.is_empty() and is_instance_valid(_players[0]):
		var p1: CGOBomber = _players[0]
		var p2: CGOBomber = _players[1] if _players.size() > 1 and is_instance_valid(_players[1]) else null
		focus_px = compute_camera_focus(
			p1.position, p1.alive,
			p2.position if p2 != null else p1.position,
			p2.alive if p2 != null else false,
			Session.is_2p
		)
	var desired := compute_camera_scroll(focus_px, _cols, _rows, _cur_origin)
	_camera_scroll = desired if snap else _camera_scroll.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	position = _base_offset - _camera_scroll
	if not embedded and _label != null:
		_label.position = _camera_scroll + Vector2(8, 4)

func _ready() -> void:
	for t: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/objecttable.json")):
		_table[int(t.id)] = t
	if FileAccess.file_exists("res://data/tile_info.json"):
		_tile_info = JSON.parse_string(FileAccess.get_file_as_string("res://data/tile_info.json"))
	if FileAccess.file_exists("res://data/item_attr.json"):
		var ia: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_attr.json"))
		for it: Dictionary in ia.get("items", []):
			_item_sprites[str(it.get("name", ""))] = str(it.get("name2", it.get("sprite", "")))
	if FileAccess.file_exists("res://data/bomber_attr.json"):
		var ba: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/bomber_attr.json"))
		for b: Dictionary in ba:
			_bomber_attrs[str(b.name)] = b

	_maps = DirAccess.get_directories_at(SpriteDB.root.path_join("Map"))
	if embedded and not initial_map.begins_with("Test") and not initial_map.begins_with("DevTest"):
		if Session.selected_map != "":
			initial_map = Session.selected_map
		game_mode_id = Session.selected_component_id
	_cur = maxi(_maps.find(initial_map), 0)
	if not embedded:
		_label.position = Vector2(10, 5)
		_label.z_index = 200
		add_child(_label)
	_map_action_bomb = CMapActionBombClass.new()
	_map_action_bomb.map_origin = get_map_origin(_cols, _rows)
	_map_action_bomb.tile_check_callback = func(c: Vector2i) -> int:
		return get_tile_kind(c.x, c.y)
	_map_action_bomb.box_destroy_callback = func(c: Vector2i) -> void:
		break_box(c)
	_map_action_bomb.bomb_passable_callback = func(from_c: Vector2i, to_c: Vector2i, dir_idx: int) -> bool:
		return CGOTilePassableClass.can_traverse_step(_passable_tiles.get(from_c, null), _passable_tiles.get(to_c, null), dir_idx, 1)
	_map_action_bomb.flame_passable_callback = func(from_c: Vector2i, to_c: Vector2i, dir_idx: int) -> bool:
		return CGOTilePassableClass.can_traverse_step(_passable_tiles.get(from_c, null), _passable_tiles.get(to_c, null), dir_idx, 2)
	_map_action_bomb.bomb_placed.connect(_on_map_action_bomb_placed)
	_map_action_bomb.bomb_exploded.connect(_on_map_action_bomb_exploded)
	add_child(_map_action_bomb)

	_show()

func tile_type(obj_id: int) -> int:
	if not _table.has(obj_id):
		return -1
	var info: Variant = _tile_info.get(_table[obj_id].name, null)
	return int(info.type) if info is Dictionary else -1

func get_tile_kind(gx: int, gy: int) -> int:
	if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
		return 1 # treat outside map as solid wall
	var gp := Vector2i(gx, gy)
	if _cell_objects.has(gp):
		var obj_id := int(_cell_objects[gp].id)
		return tile_type(obj_id)
	if _passable_objects.has(gp):
		return 3
	return 0 # ground

func _create_tile_object(obj_id: int, gp: Vector2i) -> CGOTileClass:
	var t_name: String = str(_table[obj_id].name) if _table.has(obj_id) else ""
	var info: CTileInfoClass = CTileInfoClass.get_info(t_name)
	var tile: CGOTileClass
	if info == null:
		tile = CGOTileClass.new()
	else:
		match info.tile_type:
			1:
				tile = CGOTileStaticClass.new()
			2:
				tile = CGOTileMoveAbleBoxClass.new() if info.is_movable else CGOTileFixedBoxClass.new()
			3:
				tile = CGOTilePassableClass.new()
			_:
				tile = CGOTileGroundClass.new()
	tile.map_origin = _cur_origin
	tile.init_tile(info, obj_id, gp.x, gp.y)
	if tile is CGOTileFixedBoxClass or tile is CGOTileMoveAbleBoxClass:
		tile.explode_requested.connect(_on_tile_explode_requested)
	return tile

func _on_tile_explode_requested(col: int, row: int) -> void:
	# From sub_5BF5BD -> sub_7322B5 (ExplodeBlock01 / JellyBombBlock00 chain explosion)
	if _map_action_bomb == null:
		return
	var b: Node2D = _map_action_bomb.place_bomb(col, row, 1, -1)
	if b != null and b.has_method("explode"):
		b.call("explode")

func _exit_tree() -> void:
	for t_obj in _tiles.values():
		if is_instance_valid(t_obj):
			t_obj.free()
	_tiles.clear()
	for p_obj in _passable_tiles.values():
		if is_instance_valid(p_obj):
			p_obj.free()
	_passable_tiles.clear()
	_game_item_man.clear()

func set_flame_blocked(gx: int, gy: int, blocked: bool) -> void:
	# From sub_72991D (CPlayMap::SetFlameBlocked)
	var gp := Vector2i(gx, gy)
	if blocked:
		_flame_blocked[gp] = true
	else:
		_flame_blocked.erase(gp)

func is_flame_blocked(gx: int, gy: int) -> bool:
	# From sub_729970 (CPlayMap::IsFlameBlocked)
	if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
		return true
	return _flame_blocked.get(Vector2i(gx, gy), false)

func _sync_box_concealment(gp: Vector2i) -> void:
	# Syncs visibility of MoveAbleBox (sub_5C0C2E), floating items (b[16]), and bombs (b[17]) inside active CGOTilePassable
	var p_tile: Variant = _passable_tiles.get(gp, null)
	var p_active: bool = (p_tile is CGOTilePassableClass) and (p_tile as CGOTilePassableClass).tile_active
	if _cell_objects.has(gp):
		var entry: Dictionary = _cell_objects[gp]
		var sp: Sprite2D = entry.get("sprite", null)
		var tile: Variant = _tiles.get(gp, null)
		if is_instance_valid(sp) and tile is CGOTileMoveAbleBoxClass:
			var t_name: String = tile.tile_info.tile_name if tile.tile_info != null else ""
			var is_turn_box: bool = t_name.find("TurnBox") != -1
			var conceals_box: bool = p_active and (p_tile as CGOTilePassableClass).is_concealing()
			sp.visible = not ((not is_turn_box) and conceals_box)
	var item_vis: bool = (not p_active) or (p_tile.tile_info != null and p_tile.tile_info.item_visible_inside)
	for it: Dictionary in _floating_items:
		if it.grid_pos == gp:
			if is_instance_valid(it.sprite):
				(it.sprite as Sprite2D).visible = item_vis
			if is_instance_valid(it.shadow):
				(it.shadow as Sprite2D).visible = item_vis
	if _map_action_bomb != null and _map_action_bomb.has_bomb_at(gp.x, gp.y):
		var b: Node2D = _map_action_bomb.get_bomb_at(gp.x, gp.y)
		if is_instance_valid(b):
			b.visible = (not p_active) or (p_tile.tile_info != null and p_tile.tile_info.bomb_visible_inside)

func push_movable_box(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	# From sub_730EF4 (CPlayMap::PushMoveAbleBox): may enter CGOTilePassable layer (unless player-blocked)
	if to_cell.x < 0 or to_cell.x >= _cols or to_cell.y < 0 or to_cell.y >= _rows:
		return false
	if not _tiles.has(from_cell) or _cell_objects.has(to_cell):
		return false
	var dest_pass: Variant = _passable_tiles.get(to_cell, null)
	if dest_pass is CGOTilePassableClass and (dest_pass as CGOTilePassableClass).blocks_movement():
		return false
	var tile: Variant = _tiles[from_cell]
	if not (tile is CGOTileMoveAbleBoxClass) or not tile.can_push():
		return false
	if _map_action_bomb != null and _map_action_bomb.has_bomb_at(to_cell.x, to_cell.y):
		return false
	_tiles.erase(from_cell)
	set_flame_blocked(from_cell.x, from_cell.y, false)
	tile.push_to(to_cell.x, to_cell.y)
	_tiles[to_cell] = tile
	set_flame_blocked(to_cell.x, to_cell.y, true)
	if _cell_objects.has(from_cell):
		var entry: Dictionary = _cell_objects[from_cell]
		_cell_objects.erase(from_cell)
		var sp: Sprite2D = entry.sprite
		var old_pos: Vector2 = sp.position
		entry.grid_pos = to_cell
		entry.px = _cur_origin.x + to_cell.x * CELL
		entry.py = _cur_origin.y + to_cell.y * CELL
		sp.z_index = 2 + to_cell.y
		_apply_anim_frame(entry)
		var target_pos: Vector2 = sp.position
		if is_inside_tree() and DisplayServer.get_name() != "headless":
			sp.position = old_pos
			var tw := create_tween()
			tw.tween_property(sp, "position", target_pos, 0.30) # Exact CA.exe CGOTileMoveAbleBox::Update: 4 px / 30ms tick (40px = 10 ticks = 0.30s)
		_cell_objects[to_cell] = entry
		_sync_box_concealment(to_cell)
	if dest_pass is CGOTilePassableClass:
		shake_passable(to_cell, to_cell.x != from_cell.x)
	# Crush any floating ground item at destination (sub_730EF4 @ 0x731035..0x731071)
	for i in range(_floating_items.size() - 1, -1, -1):
		var it: Dictionary = _floating_items[i]
		if it.grid_pos == to_cell:
			if is_instance_valid(it.sprite):
				(it.sprite as Sprite2D).queue_free()
			if is_instance_valid(it.shadow):
				(it.shadow as Sprite2D).queue_free()
			_floating_items.remove_at(i)
	return true

func is_tile_concealing(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
		return false
	var gp := Vector2i(gx, gy)
	if _passable_tiles.has(gp):
		return (_passable_tiles[gp] as CGOTilePassableClass).is_concealing()
	return false

func _get_player_by_id(who_id: int) -> CGOBomber:
	for p: CGOBomber in _players:
		if p.player_id == who_id:
			return p
	return null

func is_tile_walkable(gx: int, gy: int, who_id := -1) -> bool:
	if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
		return false
	var k := get_tile_kind(gx, gy)
	if k == 1: # 1: wall
		return false
	if k == 2: # 2: box
		var p := _get_player_by_id(who_id)
		if p == null or not p.can_pass_box():
			return false
	var gp := Vector2i(gx, gy)
	if k == 3 and _passable_tiles.has(gp) and (_passable_tiles[gp] as CGOTilePassableClass).blocks_movement():
		return false # Passable tile with b[4..7] == 0 (Icewater00, TransparentBlock, Line01..04)
	if _map_action_bomb != null and _map_action_bomb.has_bomb_at(gx, gy):
		var b: Node2D = _map_action_bomb.get_bomb_at(gx, gy)
		if b != null and int(b.owner_id) == who_id and who_id >= 0:
			var p := _get_player_by_id(who_id)
			if p != null:
				var b_anchor := get_cell_anchor(gx, gy)
				if absf(p.position.x - b_anchor.x) < 34.0 and absf(p.position.y - b_anchor.y) < 34.0:
					return true # Still walking off the bomb
		return false
	return true

func _can_player_fit(anchor_pos: Vector2, who_id: int) -> bool:
	var p := _get_player_by_id(who_id)
	var check_pass_dirs: bool = p != null and not p.can_pass_box()
	var center := anchor_pos + Vector2(20.0, -19.5)
	var r := 11.0
	var corners := [
		center + Vector2(-r, -r),
		center + Vector2(r, -r),
		center + Vector2(-r, r),
		center + Vector2(r, r),
	]
	for c in corners:
		var gx := int(floor((c.x - _cur_origin.x) / CELL))
		var gy := int(floor((c.y - _cur_origin.y) / CELL))
		if not is_tile_walkable(gx, gy, who_id):
			return false
		if check_pass_dirs:
			var target_c := Vector2i(gx, gy)
			if target_c != p.cell and (_passable_tiles.has(p.cell) or _passable_tiles.has(target_c)):
				var d_idx: int = _vec_to_dir_idx(target_c - p.cell)
				if d_idx >= 0 and not CGOTilePassableClass.can_traverse_step(_passable_tiles.get(p.cell, null), _passable_tiles.get(target_c, null), d_idx, 0):
					return false
	return true

func _update_bgm(map_name: String) -> void:
	var regex := RegEx.create_from_string("^([A-Za-z_-]+)")
	var match_result := regex.search(map_name)
	var theme := match_result.get_string(1) if match_result else map_name
	var file_path := SpriteDB.root.path_join("MP3").path_join(theme).path_join("sound.ogg")
	if FileAccess.file_exists(file_path):
		AudioManager.play_bgm(theme)
	else:
		AudioManager.stop_bgm()

func _find_state(id: int, state_name: String) -> Dictionary:
	if id < 0 or not _table.has(id) or _table[id].states == null:
		return {}
	var states: Array = _table[id].states
	for s: Dictionary in states:
		if str(s.state).nocasecmp_to(state_name) == 0:
			return s
	return states[0] if not states.is_empty() else {}

func _has_state(id: int, state_name: String) -> bool:
	if id < 0 or not _table.has(id) or _table[id].states == null:
		return false
	for s: Dictionary in _table[id].states:
		if str(s.state).nocasecmp_to(state_name) == 0:
			return true
	return false

func _apply_anim_frame(entry: Dictionary) -> void:
	var st: Dictionary = entry.state_data
	if st.is_empty() or (st.frames as Array).is_empty():
		return
	var pair: Array = st.frames[entry.frame_idx]
	var f := SpriteDB.get_frame(str(st.sprite), int(pair[0]))
	if f.is_empty():
		return
	var s: Sprite2D = entry.sprite
	s.texture = f.texture
	s.position = Vector2(entry.px - f.offset.x, entry.py + 39 - f.offset.y)

func _set_entry_state(entry: Dictionary, state_name: String, loop_override := true, next_state := "Default") -> void:
	var st := _find_state(int(entry.id), state_name)
	if st.is_empty() or (st.frames as Array).is_empty():
		return
	entry.state_name = state_name
	entry.state_data = st
	entry.frame_idx = 0
	entry.tick_in_frame = 0
	entry.loop = loop_override
	entry.next_state = next_state
	_apply_anim_frame(entry)
	if not _anim_nodes.has(entry):
		_anim_nodes.append(entry)

func set_cell_state(grid_pos: Vector2i, state_name: String, loop_override := true, next_state := "Default") -> void:
	if _cell_objects.has(grid_pos):
		_set_entry_state(_cell_objects[grid_pos], state_name, loop_override, next_state)
	elif _passable_objects.has(grid_pos):
		_set_entry_state(_passable_objects[grid_pos], state_name, loop_override, next_state)

func shake_passable(grid_pos: Vector2i, horizontal := true, play_sfx := true) -> void:
	# From sub_5C1175 (CGOTilePassable::SetShakeState): ShakenVert(1) / ShakenHorz(2) + SFX 158 (Tent) / 63 (Herb)
	if not _passable_objects.has(grid_pos):
		return
	var entry: Dictionary = _passable_objects[grid_pos]
	var target := "ShakenHorz" if horizontal else "ShakenVert"
	if not _has_state(int(entry.id), target) or (_find_state(int(entry.id), target).get("frames", []) as Array).size() <= 1:
		target = "ShakenHorz" if _has_state(int(entry.id), "ShakenHorz") else ""
	if target != "":
		_set_entry_state(entry, target, false, "Default")
	if play_sfx and _table.has(int(entry.id)):
		var t_name: String = str(_table[int(entry.id)].name)
		if t_name.find("Tent") != -1:
			AudioManager.play_sfx("Obj_Tent")
		elif t_name.find("Herb") != -1 or t_name.find("BasicBlock_Pass") != -1 or t_name.find("Plant") != -1 or t_name.find("Z_Passa") != -1 or t_name.find("Mons2_Pass") != -1:
			AudioManager.play_sfx("Obj_Herb")

func capture_static_tile(gp: Vector2i) -> bool:
	# From sub_7453F6 (10101..10199 -> swap CGOTileStatic sprite to "Tile15_Static/Aft%02d")
	var tile: Variant = _tiles.get(gp, null)
	if not (tile is CGOTileStaticClass) or not (tile as CGOTileStaticClass).is_capturable_static():
		return false
	var aft_name: String = (tile as CGOTileStaticClass).get_captured_sprite_name()
	if aft_name != "" and _cell_objects.has(gp):
		var entry: Dictionary = _cell_objects[gp]
		var sp: Sprite2D = entry.get("sprite", null)
		var f: Dictionary = SpriteDB.get_frame(aft_name, 0)
		if is_instance_valid(sp) and not f.is_empty():
			sp.texture = f.texture
			sp.position = Vector2(entry.px - f.offset.x, entry.py + 39 - f.offset.y)
	return true

func break_box(grid_pos: Vector2i) -> void:
	# Burn passable bush/tile on separate passable layer if present (sub_70F346)
	if _passable_objects.has(grid_pos) and _passable_tiles.has(grid_pos):
		var p_tile: CGOTilePassableClass = _passable_tiles[grid_pos]
		if p_tile.on_flame_hit():
			var p_entry: Dictionary = _passable_objects[grid_pos]
			if _has_state(int(p_entry.id), "Broken"):
				_set_entry_state(p_entry, "Broken", false, "__remove__")
			else:
				if is_instance_valid(p_entry.sprite):
					(p_entry.sprite as Sprite2D).queue_free()
				_passable_objects.erase(grid_pos)
				_passable_tiles.erase(grid_pos)
				_sync_box_concealment(grid_pos)
	if not _cell_objects.has(grid_pos):
		return
	var entry: Dictionary = _cell_objects[grid_pos]
	var tile: Variant = _tiles.get(grid_pos, null)
	if tile is CGOTileFixedBoxClass or tile is CGOTileMoveAbleBoxClass:
		if not tile.on_hit():
			# Multi-hit box survived: play Shaken state then transition to damaged crack state (sub_5BF1B3 / sub_5BF5BD)
			if not tile.is_indestructible() and _table.has(int(entry.id)):
				var states: Array = _table[int(entry.id)].states
				if states.size() > 2:
					var cur_idx: int = 1
					for si in range(states.size()):
						if str(states[si].state).nocasecmp_to(str(entry.state_name)) == 0:
							cur_idx = si
							break
					var shaken_idx: int = CGOTileFixedBoxClass.calc_shaken_state_index(cur_idx)
					var next_idx: int = CGOTileFixedBoxClass.calc_damaged_state_index(int(tile.hp), states.size())
					if shaken_idx < states.size() and next_idx < states.size():
						_set_entry_state(entry, str(states[shaken_idx].state), false, str(states[next_idx].state))
					elif next_idx < states.size():
						_set_entry_state(entry, str(states[next_idx].state), true, str(states[next_idx].state))
			return
		set_flame_blocked(grid_pos.x, grid_pos.y, false)
	if _has_state(int(entry.id), "Broken"):
		_set_entry_state(entry, "Broken", false, "__remove__")

func spawn_floating_item(grid_pos: Vector2i, item_code: String) -> void:
	var sp_path: String = _item_sprites.get(item_code, "")
	if sp_path == "":
		if item_code.begins_with("Item/Item"):
			sp_path = "Item/" + item_code.substr(9)
		elif item_code.begins_with("Item/"):
			sp_path = item_code
		else:
			sp_path = "Item/" + item_code
	var f := SpriteDB.get_frame(sp_path, 0)
	if f.is_empty():
		return
	var px := _cur_origin.x + grid_pos.x * CELL
	var py := _cur_origin.y + grid_pos.y * CELL
	var sh_idx := 7
	var sh_f := SpriteDB.get_frame("Shadow/Shadow", sh_idx)
	var sh_sprite := Sprite2D.new()
	sh_sprite.centered = false
	if not sh_f.is_empty():
		sh_sprite.texture = sh_f.texture
		sh_sprite.position = Vector2(px - sh_f.offset.x, py + 39 - sh_f.offset.y)
	sh_sprite.z_index = 1 + grid_pos.y
	add_child(sh_sprite)

	var item_sprite := Sprite2D.new()
	item_sprite.centered = false
	item_sprite.texture = f.texture
	item_sprite.position = Vector2(px - f.offset.x, py + 39 - f.offset.y)
	item_sprite.z_index = 1 + grid_pos.y
	add_child(item_sprite)

	_floating_items.append({
		"grid_pos": grid_pos,
		"item_code": item_code,
		"sprite_path": sp_path,
		"px": px,
		"py": py,
		"offset": f.offset,
		"sprite": item_sprite,
		"shadow": sh_sprite,
		"spawn_tick": _global_tick,
	})
	_sync_box_concealment(grid_pos)

func _roll_drop_item() -> String:
	if _cur_map_drops.is_empty():
		return CItemAttrClass.get_random_drop_item()
	var total_w := 0
	for d: Dictionary in _cur_map_drops:
		var w := int(d.get("weight", 0))
		if w > 0:
			total_w += w
	if total_w <= 0:
		return ""
	var r := randi() % total_w
	var acc := 0
	for d: Dictionary in _cur_map_drops:
		var w := int(d.get("weight", 0))
		if w <= 0:
			continue
		acc += w
		if r < acc:
			return str(d.get("item", d.get("name", "")))
	return ""

# -------------------------------------------------------------------------
# GAMEPLAY: PLAYERS, BOMBS, FLAMES & SIMULATION
# -------------------------------------------------------------------------

func _map_has_tank(mname: String) -> bool:
	var tank_maps := ["Camp04", "Camp05", "Camp10", "Camp11"]
	return mname in tank_maps or mname.to_lower().contains("tank")

func _get_mount_sprite_path(mount_id: String, dir: int, shooting := false) -> String:
	var dirs_capital: Array[String] = ["-Down", "-Up", "-Left", "-Right"]
	var dirs_lower: Array[String] = ["_down", "_up", "_left", "_right"]
	var dirs_kart: Array[String] = ["_Down", "_Up", "_Left", "_Right"]
	if mount_id == "Tank" or mount_id == "MonS2Tank":
		var suffix: String = dirs_lower[dir]
		if shooting:
			suffix += "_shooting"
		return "Ship/Tank" + suffix
	elif mount_id.begins_with("Kart"):
		return "Ship/Kart" + dirs_kart[dir]
	else:
		return "Ship/" + mount_id + dirs_capital[dir]

func _equip_player_mount(p: CGOBomber, mount_id: String) -> void:
	p.equip_mount(mount_id)

func _find_nearest_open_cell(origin_cell: Vector2i) -> Vector2i:
	if get_tile_kind(origin_cell.x, origin_cell.y) == 0:
		return origin_cell
	var best_cell := origin_cell
	var best_dist := 999999
	for r in range(1, maxi(_cols, _rows)):
		for gy in range(maxi(0, origin_cell.y - r), mini(_rows, origin_cell.y + r + 1)):
			for gx in range(maxi(0, origin_cell.x - r), mini(_cols, origin_cell.x + r + 1)):
				if get_tile_kind(gx, gy) == 0:
					var d := absi(gx - origin_cell.x) + absi(gy - origin_cell.y)
					if d < best_dist:
						best_dist = d
						best_cell = Vector2i(gx, gy)
		if best_dist < 999999:
			return best_cell
	return best_cell

func _destroy_player_mount(p: CGOBomber) -> void:
	# From sub_5AF1D0 (OnHitWhileRidingShip): dismount and snap out of any overlapped breakable box
	p.destroy_mount()
	if get_tile_kind(p.cell.x, p.cell.y) == 2:
		var safe_cell := _find_nearest_open_cell(p.cell)
		p.set_cell(safe_cell.x, safe_cell.y)
	_create_flame_at(p.cell)

func _shoot_tank(p: CGOBomber) -> void:
	p.shoot_tank()

func _spawn_players(m: Dictionary) -> void:
	for p: CGOBomber in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	if _map_action_bomb != null:
		for child in _map_action_bomb.get_children():
			child.queue_free()
		_map_action_bomb._active_bombs.clear()
	for b: Dictionary in _bombs:
		if is_instance_valid(b.sprite):
			b.sprite.queue_free()
	_bombs.clear()
	for f: Dictionary in _flames:
		if is_instance_valid(f.sprite):
			f.sprite.queue_free()
	_flames.clear()
	for proj: Dictionary in _tank_projectiles:
		if is_instance_valid(proj.sprite):
			proj.sprite.queue_free()
	_tank_projectiles.clear()
	for mon in _monsters:
		if is_instance_valid(mon):
			mon.queue_free()
	_monsters.clear()
	for d in _darts:
		if is_instance_valid(d):
			d.queue_free()
	_darts.clear()
	if is_instance_valid(_start_banner):
		_start_banner.queue_free()
		_start_banner = null
	if is_instance_valid(_result_banner):
		_result_banner.queue_free()
		_result_banner = null

	var spawns: Array = m.get("spawns", [[1, 1], [13, 11]])
	if spawns.is_empty():
		spawns = [[1, 1], [13, 11]]

	var mname := _maps[_cur]
	var map_has_tank := _map_has_tank(mname)

	# Player 1 (Local)
	var p1_char := Session.selected_char if Session.selected_char != "" else "Character/C00"
	if p1_char == "Character/Random" or p1_char == "Random":
		p1_char = Session.roll_random_character()
	var p1_sp_idx: int = posmod(Session.team_color_idx, spawns.size())
	var p1_sp: Array = spawns[p1_sp_idx]
	var p1_color := Session.get_team_color(Session.team_color_idx)
	var p1_mount := "Tank" if map_has_tank else Session.equipped_mount
	var p1_skin := Session.equipped_bomb_skin
	_players.append(_create_player(0, Session.nickname if Session.nickname != "" else "Player 1", p1_char, Vector2i(int(p1_sp[0]), int(p1_sp[1])), p1_color, false, p1_skin, p1_mount))

	# Player 2 (Local 2P or Bot)
	if spawn_p2_enabled:
		var p2_is_bot := not Session.is_2p
		var p2_name := Session.nickname2 if Session.is_2p and Session.nickname2 != "" else "Bot Bazzi"
		var p2_char := "Character/C01"
		var p2_team_idx: int = Session.user2_team_color_idx if Session.is_2p else ((Session.team_color_idx + 1) % 8)
		var p2_sp_idx: int = posmod(Session.user2_team_color_idx if Session.is_2p else (p1_sp_idx + 1), spawns.size())
		var p2_sp: Array = spawns[p2_sp_idx] if spawns.size() > 1 else [mini(int(spawns[0][0]) + 4, _cols - 2), mini(int(spawns[0][1]) + 4, _rows - 2)]
		var p2_color := Session.get_team_color(p2_team_idx)
		var p2_mount := "Tank" if map_has_tank else ""
		var p2_skin := Session.user2_equipped_bomb_skin if Session.is_2p else "Bomb/Bomb00"
		_players.append(_create_player(1, p2_name, p2_char, Vector2i(int(p2_sp[0]), int(p2_sp[1])), p2_color, p2_is_bot, p2_skin, p2_mount))

	_spawn_monsters(m)
	_update_scrolling_camera(0.0, true)

	_match_seconds_left = 180.0
	_match_over = false
	_match_over_timer = 0.0

	# Match start announcement and animated banner (exact screen positions in CGOGlyph)
	AudioManager.play_sfx("Ntc_GameStart")
	_start_banner = CGOGlyphClass.create_start_glyph()
	_start_banner.position = Vector2.ZERO
	_start_banner.tree_exited.connect(func(): _start_banner = null)
	add_child(_start_banner)

func _is_monster_arena_map(m: Dictionary) -> bool:
	if spawn_monsters_enabled:
		return true
	if get_active_component() is CMonsterComponentClass:
		return true
	var mname: String = str(m.get("name", ""))
	if mname.is_empty() and _maps.size() > 0 and _cur < _maps.size():
		mname = str(_maps[_cur])
	return mname.begins_with("Mon") or mname.begins_with("Boss") or mname.begins_with("BonusBigRPG") or mname.begins_with("RPG")

func _register_script_monster(mon: CGOBossMonClass) -> void:
	mon.map_origin = _cur_origin
	mon.set_cell(mon.cell.x, mon.cell.y)
	mon.drop_spawned.connect(func(code: String, c: Vector2i) -> void:
		spawn_floating_item(c, code)
	)
	mon.boss_damaged.connect(func(src: CGOBossMonClass, _hp: int) -> void:
		if _monster_comp != null:
			_monster_comp.on_monster_damaged(src)
	)
	mon.boss_angered.connect(func(src: CGOBossMonClass) -> void:
		if _monster_comp != null:
			_monster_comp.on_monster_angered(src)
	)
	mon.monster_died.connect(func(src: CGONpcBasicMonClass, _c: Vector2i) -> void:
		if _monster_comp != null:
			_monster_comp.on_monster_died(src)
	)
	mon.create_object_requested.connect(func(target_cls: int, spawn_c: Vector2i) -> void:
		if _monster_comp != null:
			_monster_comp.spawn_class_monsters(target_cls, spawn_c, func(child_mon: CGOBossMonClass) -> void:
				_register_script_monster(child_mon)
			)
	)
	mon.attack_requested.connect(func(src: CGOBossMonClass, attack_info: Dictionary) -> void:
		_on_monster_attack_requested(src, attack_info)
	)
	mon.order_script_requested.connect(func(target_cls: int, list_name: String) -> void:
		if _monster_comp == null:
			return
		for other in _monster_comp.active_monsters:
			if is_instance_valid(other) and bool(other.get("alive")):
				if target_cls == 0 or int(other.get("obj_class")) == target_cls:
					other.start_action_list(list_name)
	)
	add_child(mon)
	_monsters.append(mon)

func _on_monster_attack_requested(mon: CGOBossMonClass, attack_info: Dictionary) -> void:
	if _match_over or mon == null or not mon.alive:
		return
	var afunc := String(attack_info.get("func", "direction")).to_lower()
	if afunc == "createmonmissile":
		var missile: CGOMonMissileClass = CGOMonMissileClass.new()
		missile.setup(
			mon.position + Vector2(20.0, -20.0),
			float(attack_info.get("angle", 0.0)),
			float(attack_info.get("speed", 5.0)),
			float(attack_info.get("maxmovelen", 300.0)),
			int(attack_info.get("missiletype", 5))
		)
		add_child(missile)
		_mon_missiles.append(missile)
		return
	if (afunc == "bombmissile" or afunc == "createboxmon") and _monster_comp != null:
		var cls_id := int(attack_info.get("class", 0))
		if cls_id > 0:
			_monster_comp.spawn_class_monsters(cls_id, mon.cell, func(child_mon: CGOBossMonClass) -> void:
				_register_script_monster(child_mon)
			)
			return
	if _map_action_bomb == null:
		return
	var power := clampi(int(attack_info.get("power", 2)), 1, 7)
	var owner_id := -100 - mon.instance_id
	for tc in mon.compute_attack_cells(attack_info):
		if get_tile_kind(tc.x, tc.y) in [1, 2]:
			continue
		if not _map_action_bomb.has_bomb_at(tc.x, tc.y):
			_map_action_bomb.place_bomb(tc.x, tc.y, power, owner_id, "Bomb/Bomb00")

func _spawn_monsters(m: Dictionary) -> void:
	_monster_comp = null
	if not _is_monster_arena_map(m):
		return
	var script_xml: String = m.get("script_xml", "")
	if script_xml.is_empty():
		return

	var comp: CComponentClass = get_active_component()
	if comp is CMonsterComponentClass:
		_monster_comp = comp
	else:
		_monster_comp = CMonsterComponentClass.new(CComponentClass.MODE_STAGE_CLEAR, self)

	if _monster_comp.load_script_xml(script_xml):
		_monster_comp.grid_cols = _cols
		_monster_comp.grid_rows = _rows
		_monster_comp.spawn_start_monsters(func(mon: CGOBossMonClass) -> void:
			_register_script_monster(mon)
		)
		return

	# Fallback for legacy maps without <ScriptObject> blocks
	var regex := RegEx.new()
	regex.compile("<InitInfo[^>]+pos=\"(\\d+),(\\d+)\"[^>]*>")
	var matches := regex.search_all(script_xml)
	for mat in matches:
		var x := int(mat.get_string(1))
		var y := int(mat.get_string(2))
		var full_tag := mat.get_string(0)
		var mon_id := "SM02" if full_tag.contains("SmallMonster2") else "SM01"
		if full_tag.contains("Egg"):
			var egg := CGONpcMonEggClass.new()
			egg.setup_egg(x, y, "SM01", 10.0, _cur_origin)
			add_child(egg)
			_monsters.append(egg)
			continue
		var mon: Node2D = CGONpcBasicMonClass.new()
		mon.setup(mon_id, x, y, 70.0, _roll_drop_item(), 1)
		mon.map_origin = _cur_origin
		mon.set_cell(x, y)
		mon.drop_spawned.connect(func(code: String, c: Vector2i) -> void:
			spawn_floating_item(c, code)
		)
		add_child(mon)
		_monsters.append(mon)

func _fire_dart(p: CGOBomber) -> void:
	if not p.alive or p.in_bubble or _match_over:
		return
	var dart = p.try_fire_dart()
	if dart != null:
		dart.map_origin = _cur_origin
		add_child(dart)
		_darts.append(dart)
		AudioManager.play_sfx("Wave/Dart")

func _create_player(id: int, p_name: String, char_code: String, grid_pos: Vector2i, team_color: Color, is_bot: bool, bomb_skin := "", initial_mount := "") -> CGOBomber:
	var p: CGOBomber = get_active_component().create_bomber()
	p.map_origin = _cur_origin
	var attr: Dictionary = _bomber_attrs.get(char_code, {})
	var eq := {}
	if id == 0:
		eq = {
			"hat": Session.equipped_hat,
			"cloth": Session.equipped_cloth,
			"face": Session.equipped_face,
			"char_deco": Session.equipped_char_deco,
			"id_deco": Session.equipped_id_deco
		}
	p.setup(id, p_name, char_code, grid_pos.x, grid_pos.y, team_color, is_bot, bomb_skin, initial_mount, attr, eq)
	if id == 0 and not is_bot:
		Session.get_inventory_man().apply_to_bomber_item_box(p.item_box)
	p.bomb_requested.connect(_on_bomber_bomb_requested)
	p.tank_shot.connect(_on_bomber_tank_shot)
	add_child(p)
	return p

func _update_player_visuals(p: Variant) -> void:
	if p is CGOBomber:
		p._update_visuals()

# -------------------------------------------------------------------------
# CORNER SLIDING & PLAYER MOVEMENT
# -------------------------------------------------------------------------

func _move_player(p: CGOBomber, move_dir: Vector2, delta: float) -> void:
	if not p.alive or _match_over:
		if not p.alive and p.action != "die":
			p.action = "die"
			p._update_visuals()
		elif p.alive and p.action != "hurrah":
			p.action = "hurrah"
			p._update_visuals()
		return

	if move_dir != Vector2.ZERO and p.can_kick_bomb():
		_check_bomb_kick(p, move_dir)
	if move_dir != Vector2.ZERO and not p.can_pass_box():
		_try_push_movable_box(p, move_dir, delta)
	else:
		_box_push_hold.erase(p.player_id)

	p.on_special_ground = _rail_ground_cells.has(p.cell)
	p.move(move_dir, delta, _can_player_fit)
	_apply_conveyor_push(p, delta, move_dir)
	_clamp_2p_viewport_leash(p)
	_check_ground_trap(p, move_dir)
	_update_player_bush_state(p, move_dir)
	_check_item_pickup(p)
	_check_bubble_touch(p)

func _clamp_2p_viewport_leash(p: CGOBomber) -> void:
	if not Session.is_2p or (_cols <= 15 and _rows <= 13):
		return
	if _players.size() < 2 or not is_instance_valid(_players[0]) or not is_instance_valid(_players[1]):
		return
	if not _players[0].alive or not _players[1].alive:
		return
	if p != _players[0] and p != _players[1]:
		return
	var pos := p.position
	if _cols > 15:
		pos.x = clampf(pos.x, _cur_origin.x + _camera_scroll.x, _cur_origin.x + _camera_scroll.x + 560.0)
	if _rows > 13:
		pos.y = clampf(pos.y, _cur_origin.y + _camera_scroll.y + 39.0, _cur_origin.y + _camera_scroll.y + 519.0)
	if pos != p.position:
		p.position = pos
		var nc := clampi(int(round((pos.x - _cur_origin.x) / float(CELL))), 0, _cols - 1)
		var nr := clampi(int(round((pos.y - _cur_origin.y - 39.0) / float(CELL))), 0, _rows - 1)
		p.cell = Vector2i(nc, nr)

func _apply_conveyor_push(p: CGOBomber, delta: float, move_dir := Vector2.ZERO) -> void:
	# From sub_5BFA43 (CGOTileGround::ApplyConveyor): b[12] px/tick, center-pull b[16], push-out b[20]
	if p.can_pass_box() or p.in_bubble:
		return
	var g_info: Variant = _ground_tiles.get(p.cell, null)
	if not (g_info is CTileInfoClass) or not g_info.is_conveyor:
		return
	# From sub_593737 -> sub_5BFA0A: face & animate along conveyor visual dir when no manual input
	if move_dir == Vector2.ZERO and (p.action == "idle" or p.action == "blink" or p.action == "walk"):
		var vis_dir: int = CGOTileGroundClass.get_conveyor_visual_dir(
			g_info.conveyor_speed_px_per_tick, g_info.conveyor_in_mask, g_info.conveyor_out_dir
		)
		if vis_dir >= 0 and vis_dir < 4:
			const CONV_TO_BOMBER_DIR: Array[int] = [2, 1, 3, 0] # 0=L->2, 1=U->1, 2=R->3, 3=D->0
			p.dir = CONV_TO_BOMBER_DIR[vis_dir]
			p.action = "walk"
			p.idle_ticks = 0
	var tile_anchor: Vector2 = get_cell_anchor(p.cell.x, p.cell.y)
	var step: Vector2 = CGOTileGroundClass.compute_conveyor_step(
		p.position, tile_anchor, g_info.conveyor_speed_px_per_tick, g_info.conveyor_in_mask, g_info.conveyor_out_dir, delta
	)
	if step == Vector2.ZERO:
		return
	var next_pos: Vector2 = p.position + step
	if _can_player_fit(next_pos, p.player_id):
		p.position = next_pos
		p._update_grid_cell()

func place_ground_trap(gp: Vector2i, trap_type: int, owner_id: int = -1) -> bool:
	# Delegated to CGameItemMan (0x5BFE98 / 0x59AA2B)
	var placed: bool = _game_item_man.place_ground_trap(
		gp, trap_type, owner_id, _cols, _rows, get_tile_kind(gp.x, gp.y),
		_ground_tiles.get(gp, null), _cur_origin, self, get_cell_anchor(gp.x, gp.y), SpriteDB
	)
	if placed and trap_type == CGOTileGroundClass.TRAP_BANANA:
		AudioManager.play_sfx("Itm_PutBanana")
	return placed

func _check_ground_trap(p: CGOBomber, move_dir: Vector2) -> void:
	# Delegated to CGameItemMan (0x59C2B2 -> 0x89B145 -> 0x89B623 -> 0x593737)
	var triggered: int = _game_item_man.check_bomber_ground_trap(
		p, move_dir, _ground_tiles.get(p.cell, null), _can_player_fit,
		get_cell_anchor(p.cell.x, p.cell.y), _destroy_player_mount
	)
	if triggered == CGOTileGroundClass.TRAP_BANANA:
		AudioManager.play_sfx("Itm_UseBanana")

func _update_player_bush_state(p: CGOBomber, move_dir: Vector2) -> void:
	# From sub_59F04D / sub_59F107: conceal bomber if either logical cell (v7) or foot-anchor cell (v6, sub_59C48A) is a concealing passable tile
	var foot_cell: Vector2i = p.get_foot_cell()
	var is_flying: bool = p.mount != null and bool(p.mount.get("is_flying", false))
	var on_concealing: bool = is_tile_concealing(p.cell.x, p.cell.y) or (foot_cell != p.cell and is_tile_concealing(foot_cell.x, foot_cell.y))
	var concealed: bool = on_concealing and not p.in_bubble and not is_flying
	# Shake passable tile on EVERY new passable cell entry (including bush-to-bush, ca.exe.c:343302 -> sub_5C1175)
	var cur_pass_cell := Vector2i(-1, -1)
	if not is_flying:
		if _passable_tiles.has(p.cell):
			cur_pass_cell = p.cell
		elif foot_cell != p.cell and _passable_tiles.has(foot_cell):
			cur_pass_cell = foot_cell
	var last_pass: Vector2i = _player_last_passable_cell.get(p.player_id, Vector2i(-1, -1))
	if cur_pass_cell != last_pass:
		_player_last_passable_cell[p.player_id] = cur_pass_cell
		if cur_pass_cell != Vector2i(-1, -1):
			shake_passable(cur_pass_cell, absf(move_dir.x) >= absf(move_dir.y))
	if p.in_bush != concealed:
		p.in_bush = concealed
		p._update_visuals()

func _try_push_movable_box(p: CGOBomber, move_dir: Vector2, delta: float) -> void:
	# From sub_730EF4: require short hold (0.15s = 5 ticks) against adjacent CGOTileMoveAbleBox before pushing
	var push_dir := Vector2i(1 if move_dir.x > 0 else -1, 0) if absf(move_dir.x) > absf(move_dir.y) else Vector2i(0, 1 if move_dir.y > 0 else -1)
	var box_cell: Vector2i = p.cell + push_dir
	if not (_tiles.get(box_cell, null) is CGOTileMoveAbleBoxClass):
		_box_push_hold.erase(p.player_id)
		return
	var box_anchor := get_cell_anchor(box_cell.x, box_cell.y)
	if p.position.distance_to(box_anchor) > 42.0:
		_box_push_hold.erase(p.player_id)
		return
	var st: Dictionary = _box_push_hold.get(p.player_id, {})
	if st.get("cell", Vector2i(-1, -1)) == box_cell and st.get("dir", Vector2i.ZERO) == push_dir:
		st["elapsed"] = float(st.get("elapsed", 0.0)) + delta
	else:
		st = {"cell": box_cell, "dir": push_dir, "elapsed": delta}
	_box_push_hold[p.player_id] = st
	if float(st["elapsed"]) >= 0.15:
		_box_push_hold.erase(p.player_id)
		push_movable_box(box_cell, box_cell + push_dir)

func _check_bomb_kick(p: CGOBomber, move_dir: Vector2) -> void:
	if _map_action_bomb == null:
		return
	var kick_dir_v: Vector2i
	if absf(move_dir.x) > absf(move_dir.y):
		kick_dir_v = Vector2i(1 if move_dir.x > 0 else -1, 0)
	else:
		kick_dir_v = Vector2i(0, 1 if move_dir.y > 0 else -1)

	var check_cell := p.cell + kick_dir_v
	if not _map_action_bomb.has_bomb_at(check_cell.x, check_cell.y):
		return

	var b: Node2D = _map_action_bomb.get_bomb_at(check_cell.x, check_cell.y)
	if b == null or b.get("bomb_state") != CGOBomb.State.IDLE:
		return

	var b_anchor := get_cell_anchor(check_cell.x, check_cell.y)
	if p.position.distance_to(b_anchor) > 38.0:
		return

	var target_cell: Vector2i = _map_action_bomb.trace_kick_target(check_cell.x, check_cell.y, kick_dir_v)
	if target_cell == check_cell:
		# From sub_702DE4 @ 0x702e9f: kicking bomb into adjacent spike face triggers 300ms rapid fuse
		if has_spike_for_dir(check_cell + kick_dir_v, _vec_to_dir_idx(kick_dir_v)):
			b.countdown = minf(float(b.get("countdown")), 0.3)
			p.trigger_throw_anim()
			AudioManager.play_sfx("Cha_KickBomb")
		return

	b.start_slide(kick_dir_v, target_cell)
	p.trigger_throw_anim()
	AudioManager.play_sfx("Cha_KickBomb")

func _check_item_pickup(p: CGOBomber) -> void:
	if not p.alive or p.in_bubble or not p.can_eat_item():
		return
	var i := _floating_items.size() - 1
	while i >= 0:
		var it: Dictionary = _floating_items[i]
		if it.grid_pos == p.cell:
			var code: String = str(it.item_code)
			p.apply_item(code)
			AudioManager.play_sfx("Itm_ItemEaten")
			if is_instance_valid(it.sprite):
				(it.sprite as Sprite2D).queue_free()
			if is_instance_valid(it.shadow):
				(it.shadow as Sprite2D).queue_free()
			_floating_items.remove_at(i)
		i -= 1

func _check_bubble_touch(p: CGOBomber) -> void:
	if not p.alive:
		return
	for other: CGOBomber in _players:
		if other.player_id == p.player_id or not other.alive or not other.in_bubble:
			continue
		if not other.can_pop_or_rescue():
			continue # 16-tick grace period (sub_4F3D22)
		if other.cell == p.cell or p.get_center().distance_to(other.get_center()) < 26.0:
			if Session.is_2p and p.player_id == 0 and other.player_id == 1:
				other.rescue()
				other.cheer()
				AudioManager.play_sfx("Cha_BomberRelease_SnowBall")
			else:
				if not get_active_component().on_player_popped(other):
					other.pop_kill()
					AudioManager.play_sfx("Cha_BomberDie_SnowBall")


# -------------------------------------------------------------------------
# BOMBS & FLAMES
# -------------------------------------------------------------------------

func _place_bomb(p: CGOBomber) -> void:
	if not p.alive or p.in_bubble or _match_over:
		return
	if p.active_bombs >= p.get_effective_bomb_capacity():
		return
	if _map_action_bomb == null:
		return

	var place_cell := p.get_bomb_placement_cell()
	if place_cell.x < 0 or place_cell.x >= _cols or place_cell.y < 0 or place_cell.y >= _rows:
		return
	if get_tile_kind(place_cell.x, place_cell.y) in [1, 2]:
		return # From sub_5B1D7B / sub_59A895 / sub_6E3E58: sub_72C18E(..., 1, 0) blocks bombs on boxes/walls
	var skin: String = p.bomb_skin

	if p.m_fAbTank:
		# Tank shoots bomb along the lane (sub_4E5022 & sub_442542)
		p.trigger_tank_shoot_anim()
		var dir_v := Vector2i(int(CGOBomber.DIR_VECTORS[p.dir].x), int(CGOBomber.DIR_VECTORS[p.dir].y))
		var target_cell: Vector2i = _map_action_bomb.trace_tank_shot_target(place_cell.x, place_cell.y, dir_v)
		if target_cell != place_cell:
			var b: Node2D = _map_action_bomb.place_bomb(place_cell.x, place_cell.y, p.power_cur, p.player_id, skin)
			if b != null:
				p.active_bombs += 1
				b.exploded.connect(func(_b: Node2D) -> void:
					p.active_bombs = maxi(p.active_bombs - 1, 0)
				)
				b.start_tank_shot(target_cell.x, target_cell.y)
			return
		elif not _map_action_bomb.has_bomb_at(place_cell.x, place_cell.y):
			var b: Node2D = _map_action_bomb.place_bomb(place_cell.x, place_cell.y, p.power_cur, p.player_id, skin)
			if b != null:
				p.active_bombs += 1
				b.exploded.connect(func(_b: Node2D) -> void:
					p.active_bombs = maxi(p.active_bombs - 1, 0)
				)
			return
		return

	if _map_action_bomb.has_bomb_at(place_cell.x, place_cell.y):
		if p.can_punch_bomb():
			var dir_v := Vector2i(int(CGOBomber.DIR_VECTORS[p.dir].x), int(CGOBomber.DIR_VECTORS[p.dir].y))
			var b: Node2D = _map_action_bomb.get_bomb_at(place_cell.x, place_cell.y)
			if b != null and b.get("bomb_state") == CGOBomb.State.IDLE:
				var target_cell: Vector2i = _map_action_bomb.trace_throw_target(place_cell.x, place_cell.y, dir_v)
				_map_action_bomb._active_bombs.erase(place_cell)
				b.start_throw(target_cell.x, target_cell.y, dir_v)
				p.trigger_throw_anim()
				AudioManager.play_sfx("Cha_ThrowBomb")
		return

	var b: Node2D = _map_action_bomb.place_bomb(place_cell.x, place_cell.y, p.power_cur, p.player_id, skin)
	if b != null:
		p.active_bombs += 1
		b.exploded.connect(func(_b: Node2D) -> void:
			p.active_bombs = maxi(p.active_bombs - 1, 0)
		)

func _on_bomber_bomb_requested(player: CGOBomber, _col: int, _row: int) -> void:
	_place_bomb(player)

func _on_bomber_tank_shot(_start_pos: Vector2, _d: Vector2, owner_id: int) -> void:
	for p: CGOBomber in _players:
		if p.player_id == owner_id:
			_place_bomb(p)
			break

func _vec_to_dir_idx(v: Vector2i) -> int:
	if v.x < 0: return 0
	if v.y < 0: return 1
	if v.x > 0: return 2
	if v.y > 0: return 3
	return -1

func has_spike_for_dir(at_cell: Vector2i, dir_idx: int) -> bool:
	# From sub_7299A8 (CPlayMap::HasSpikeForDir); MoveAbleBox moves its mask with _tiles (sub_729701)
	var p_tile: Variant = _passable_tiles.get(at_cell, null)
	if p_tile is CGOTilePassableClass and (p_tile as CGOTilePassableClass).detonates_bomb_on_touch():
		return dir_idx == -1
	var tile: Variant = _tiles.get(at_cell, null)
	if tile is CGOTileFixedBoxClass or tile is CGOTileMoveAbleBoxClass:
		if tile.tile_active and not tile.is_broken:
			return CTileInfoClass.has_spike_for_dir(int(tile.spike_dir_mask), dir_idx)
	return false

func _on_map_action_bomb_placed(bomb: Node2D) -> void:
	if bomb == null:
		return
	bomb.cell_changed.connect(func(old_c: Vector2i, new_c: Vector2i) -> void:
		if _passable_tiles.has(new_c):
			shake_passable(new_c, new_c.x != old_c.x)
		_sync_box_concealment(old_c)
		_sync_box_concealment(new_c)
		_check_pin_tile_detonate(bomb, new_c)
	)
	if bomb.has_signal("slide_stopped"):
		bomb.slide_stopped.connect(func(b: Node2D, stop_cell: Vector2i, s_dir: Vector2i) -> void:
			# From sub_5BE35F @ 0x5be498: sliding bomb stopping against a spike face detonates
			if is_instance_valid(b) and has_spike_for_dir(stop_cell + s_dir, _vec_to_dir_idx(s_dir)):
				if b.has_method("explode"):
					b.call_deferred("explode")
		)
	if _passable_tiles.has(bomb.cell):
		shake_passable(bomb.cell, true)
	_sync_box_concealment(bomb.cell)
	_check_pin_tile_detonate(bomb, bomb.cell)

func _check_pin_tile_detonate(bomb: Node2D, at_cell: Vector2i) -> void:
	# PinTile01 / omni-spike (b[18] != 0 or mask & 0x10 @ sub_58F806): detonate immediately
	if not is_instance_valid(bomb):
		return
	if has_spike_for_dir(at_cell, -1):
		if bomb.has_method("explode"):
			bomb.call_deferred("explode")

func _on_map_action_bomb_exploded(_center: Vector2i, blast_cells: Array[Vector2i]) -> void:
	for cell in blast_cells:
		if _passable_tiles.has(cell):
			break_box(cell) # Burn passable bushes with b[24] == 0 (sub_70F346)
		_destroy_floating_item_at(cell)
		for mon in _monsters:
			if is_instance_valid(mon) and mon.get("alive") and mon.cell == cell:
				mon.hit_by_flame(cell)
	_check_players_hit_flames(blast_cells)

func _create_flame_at(cell: Vector2i) -> void:
	if _map_action_bomb != null:
		_map_action_bomb._spawn_explosion_segment(cell.x, cell.y)
	_check_players_hit_flames([cell])

func _destroy_floating_item_at(cell: Vector2i) -> void:
	var i := _floating_items.size() - 1
	while i >= 0:
		var it: Dictionary = _floating_items[i]
		if it.grid_pos == cell:
			if is_instance_valid(it.sprite):
				(it.sprite as Sprite2D).queue_free()
			if is_instance_valid(it.shadow):
				(it.shadow as Sprite2D).queue_free()
			_floating_items.remove_at(i)
		i -= 1

func _check_players_hit_flames(cells: Array[Vector2i]) -> void:
	for p: CGOBomber in _players:
		if not p.alive or not p.can_be_hit_by_flame():
			continue
		var hb: Rect2 = p.get_flame_hitbox()
		var total_overlap_area: float = 0.0
		for cell in cells:
			var flame_rect := Rect2(_cur_origin + Vector2(cell.x * CELL, cell.y * CELL), Vector2(CELL, CELL))
			var inter := hb.intersection(flame_rect)
			if inter.size.x > 0.0 and inter.size.y > 0.0:
				total_overlap_area += inter.size.x * inter.size.y
		# CA.exe sub_4EDB76: requires total overlap area >= 2/3 of 32x15 hitbox (320 px^2 out of 480 px^2)
		if total_overlap_area >= 320.0:
			if p.mount != null:
				_destroy_player_mount(p)
			elif not get_active_component().on_player_hit_by_flame(p):
				p.trap_in_bubble()

func _check_player_hit_flame(cell: Vector2i) -> void:
	_check_players_hit_flames([cell])

# -------------------------------------------------------------------------
# BOT AI & TACTICAL DECISION ENGINE
# -------------------------------------------------------------------------

func get_danger_map() -> Dictionary:
	var danger: Dictionary = {}
	if _map_action_bomb == null:
		return danger

	# 1. Active flame / explosion segments
	for child in _map_action_bomb.get_children():
		if child is CGOExplosionClass:
			danger[child.cell] = true

	# 2. Active bombs and their cross blast rays
	for bomb_pos: Vector2i in _map_action_bomb._active_bombs:
		var bomb = _map_action_bomb._active_bombs[bomb_pos]
		var power: int = int(bomb.power) if "power" in bomb else 1
		danger[bomb_pos] = true

		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			for step in range(1, power + 1):
				var ray_cell: Vector2i = bomb_pos + d * step
				if ray_cell.x < 0 or ray_cell.x >= _cols or ray_cell.y < 0 or ray_cell.y >= _rows:
					break
				var kind := get_tile_kind(ray_cell.x, ray_cell.y)
				if kind == 1: # Hard wall blocks blast ray
					break
				danger[ray_cell] = true
				if kind == 2: # Soft destructible box is hit, but blocks further blast
					break

	return danger

func _find_safe_path(start: Vector2i, is_goal: Callable, is_traversable: Callable) -> Array[Vector2i]:
	if is_goal.call(start):
		return []

	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	var found_goal := Vector2i(-1, -1)

	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if is_goal.call(cur):
			found_goal = cur
			break
		for d in dirs:
			var nxt := cur + d
			if nxt.x < 0 or nxt.x >= _cols or nxt.y < 0 or nxt.y >= _rows:
				continue
			if visited.has(nxt):
				continue
			if not is_traversable.call(nxt):
				continue
			visited[nxt] = true
			parent[nxt] = cur
			queue.append(nxt)

	if found_goal == Vector2i(-1, -1):
		return []

	var path: Array[Vector2i] = []
	var trace := found_goal
	while trace != start:
		path.push_front(trace)
		trace = parent[trace]
	return path

func _can_safely_place_bomb(b: CGOBomber, current_danger: Dictionary) -> bool:
	if _map_action_bomb == null or _map_action_bomb.has_bomb_at(b.cell.x, b.cell.y):
		return false
	if b.active_bombs >= b.get_effective_bomb_capacity():
		return false

	var sim_danger := current_danger.duplicate()
	sim_danger[b.cell] = true
	var power: int = b.power_cur
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		for step in range(1, power + 1):
			var ray_cell: Vector2i = b.cell + d * step
			if ray_cell.x < 0 or ray_cell.x >= _cols or ray_cell.y < 0 or ray_cell.y >= _rows:
				break
			var k := get_tile_kind(ray_cell.x, ray_cell.y)
			if k == 1:
				break
			sim_danger[ray_cell] = true
			if k == 2:
				break

	# Check if an escape path to a tile NOT in sim_danger exists from b.cell
	var is_traversable := func(c: Vector2i) -> bool:
		if c == b.cell:
			return true
		return is_tile_walkable(c.x, c.y, b.player_id)

	var is_goal := func(c: Vector2i) -> bool:
		return not sim_danger.has(c) and is_tile_walkable(c.x, c.y, b.player_id)

	var esc := _find_safe_path(b.cell, is_goal, is_traversable)
	return not esc.is_empty() and esc.size() <= 5

func get_cell_anchor(col: int, row: int) -> Vector2:
	return _cur_origin + Vector2(float(col * CELL), float(row * CELL + 39))

func _direction_to_cell(pos: Vector2, target_cell: Vector2i) -> Vector2:
	var cur_col := int(round((pos.x - _cur_origin.x) / CELL))
	var cur_row := int(round((pos.y - _cur_origin.y - 39.0) / CELL))
	var anchor: Vector2 = get_cell_anchor(target_cell.x, target_cell.y)
	var diff: Vector2 = anchor - pos

	# Align on perpendicular axis first to avoid clipping corridor obstacles
	if target_cell.x != cur_col and absf(diff.y) > 4.0:
		return Vector2(0.0, 1.0 if diff.y > 0 else -1.0)
	if target_cell.y != cur_row and absf(diff.x) > 4.0:
		return Vector2(1.0 if diff.x > 0 else -1.0, 0.0)

	if absf(diff.x) > absf(diff.y):
		if absf(diff.x) > 2.0:
			return Vector2(1.0 if diff.x > 0 else -1.0, 0.0)
		elif absf(diff.y) > 2.0:
			return Vector2(0.0, 1.0 if diff.y > 0 else -1.0)
	else:
		if absf(diff.y) > 2.0:
			return Vector2(0.0, 1.0 if diff.y > 0 else -1.0)
		elif absf(diff.x) > 2.0:
			return Vector2(1.0 if diff.x > 0 else -1.0, 0.0)
	return Vector2.ZERO

func _update_bot(b: CGOBomber, delta: float) -> void:
	if not b.alive or b.in_bubble or _match_over or b.start_ticks > 0:
		return

	b.ai_timer -= delta
	var danger_map := get_danger_map()
	var in_danger := danger_map.has(b.cell)

	# 1. EVASION: If bot is in danger, survival is absolute priority!
	if in_danger:
		var is_traversable := func(c: Vector2i) -> bool:
			if c == b.cell:
				return true
			if not is_tile_walkable(c.x, c.y, b.player_id):
				return false
			if _map_action_bomb != null:
				for child in _map_action_bomb.get_children():
					if child is CGOExplosionClass and child.cell == c:
						return false
			return true

		var is_goal := func(c: Vector2i) -> bool:
			return not danger_map.has(c) and is_tile_walkable(c.x, c.y, b.player_id)

		var esc_path := _find_safe_path(b.cell, is_goal, is_traversable)
		if not esc_path.is_empty():
			b.bot_target_cell = esc_path[0]
			b.bot_dir = _direction_to_cell(b.position, esc_path[0])
		else:
			# Fallback: choose any walkable adjacent tile that is not currently an active flame
			var fallback_dirs := [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
			fallback_dirs.shuffle()
			for fd in fallback_dirs:
				var tc: Vector2i = b.cell + Vector2i(int(fd.x), int(fd.y))
				if is_tile_walkable(tc.x, tc.y, b.player_id):
					b.bot_dir = fd
					break
		_move_player(b, b.bot_dir, delta)
		return

	# If not in danger, bot is SAFE.
	# Check if current movement has reached target cell
	if b.bot_target_cell != Vector2i(-1, -1):
		if b.cell == b.bot_target_cell:
			b.bot_target_cell = Vector2i(-1, -1)
		else:
			b.bot_dir = _direction_to_cell(b.position, b.bot_target_cell)

	# High level tactical decision
	if b.ai_timer <= 0.0 or b.bot_target_cell == Vector2i(-1, -1):
		b.ai_timer = 0.2

		# Priority 1: POP TRAPPED ENEMY (Instant Win!) OR RESCUE TEAMMATE
		var enemy_in_bubble: CGOBomber = null
		var friend_in_bubble: CGOBomber = null
		for pl: CGOBomber in _players:
			if pl.player_id != b.player_id and pl.alive and pl.in_bubble:
				if Session.is_2p and pl.team_color == b.team_color:
					friend_in_bubble = pl
				else:
					enemy_in_bubble = pl

		var target_bubble: CGOBomber = enemy_in_bubble if enemy_in_bubble != null else friend_in_bubble
		if target_bubble != null:
			var safe_walk := func(c: Vector2i) -> bool:
				return not danger_map.has(c) and is_tile_walkable(c.x, c.y, b.player_id)
			var bubble_path := _find_safe_path(b.cell, func(c: Vector2i) -> bool: return c == target_bubble.cell, safe_walk)
			if not bubble_path.is_empty():
				b.bot_target_cell = bubble_path[0]
				b.bot_dir = _direction_to_cell(b.position, bubble_path[0])
				_move_player(b, b.bot_dir, delta)
				return

		# Priority 2: COLLECT FLOATING ITEMS
		if not _floating_items.is_empty():
			var safe_walk := func(c: Vector2i) -> bool:
				return not danger_map.has(c) and is_tile_walkable(c.x, c.y, b.player_id)
			var nearest_item_path: Array[Vector2i] = []
			var min_dist := 999
			for it: Dictionary in _floating_items:
				var ic: Vector2i = it.grid_pos
				if danger_map.has(ic):
					continue
				var ipath := _find_safe_path(b.cell, func(c: Vector2i) -> bool: return c == ic, safe_walk)
				if not ipath.is_empty() and ipath.size() < min_dist:
					min_dist = ipath.size()
					nearest_item_path = ipath

			if not nearest_item_path.is_empty() and min_dist <= 8:
				b.bot_target_cell = nearest_item_path[0]
				b.bot_dir = _direction_to_cell(b.position, nearest_item_path[0])
				_move_player(b, b.bot_dir, delta)
				return

		# Priority 3: COMBAT BOMBING / BOX CLEARING
		var near_box := false
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if get_tile_kind(b.cell.x + d.x, b.cell.y + d.y) == 2:
				near_box = true
				break

		var near_enemy := false
		for pl: CGOBomber in _players:
			if pl.player_id != b.player_id and pl.alive and not pl.in_bubble:
				var m_dist := absi(pl.cell.x - b.cell.x) + absi(pl.cell.y - b.cell.y)
				if m_dist <= 2:
					near_enemy = true
					break

		if (near_box or near_enemy) and _can_safely_place_bomb(b, danger_map):
			_place_bomb(b)
			var new_danger := get_danger_map()
			var is_traversable := func(c: Vector2i) -> bool:
				if c == b.cell:
					return true
				return is_tile_walkable(c.x, c.y, b.player_id)
			var is_goal := func(c: Vector2i) -> bool:
				return not new_danger.has(c) and is_tile_walkable(c.x, c.y, b.player_id)
			var esc := _find_safe_path(b.cell, is_goal, is_traversable)
			if not esc.is_empty():
				b.bot_target_cell = esc[0]
				b.bot_dir = _direction_to_cell(b.position, esc[0])
			_move_player(b, b.bot_dir, delta)
			return

		# Priority 4: ADVANCE TOWARDS NEAREST ENEMY OR BOX
		var safe_walk := func(c: Vector2i) -> bool:
			return not danger_map.has(c) and is_tile_walkable(c.x, c.y, b.player_id)

		var is_target := func(c: Vector2i) -> bool:
			for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor := c + d
				if get_tile_kind(neighbor.x, neighbor.y) == 2:
					return true
			for pl: CGOBomber in _players:
				if pl.player_id != b.player_id and pl.alive and not pl.in_bubble and pl.cell == c:
					return true
			return false

		var advance_path := _find_safe_path(b.cell, is_target, safe_walk)
		if not advance_path.is_empty():
			b.bot_target_cell = advance_path[0]
			b.bot_dir = _direction_to_cell(b.position, advance_path[0])
		else:
			var safe_dirs: Array[Vector2] = []
			for d in [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
				var tc: Vector2i = b.cell + Vector2i(int(d.x), int(d.y))
				if not danger_map.has(tc) and is_tile_walkable(tc.x, tc.y, b.player_id):
					safe_dirs.append(d)
			if not safe_dirs.is_empty():
				b.bot_dir = safe_dirs[randi() % safe_dirs.size()]
				b.bot_target_cell = b.cell + Vector2i(int(b.bot_dir.x), int(b.bot_dir.y))
			else:
				b.bot_dir = Vector2.ZERO

		# Bot tank shooting
		if b.mount != null and b.mount.get("can_shoot", false):
			for target: CGOBomber in _players:
				if target.player_id != b.player_id and target.alive:
					var dx: int = int(target.cell.x) - int(b.cell.x)
					var dy: int = int(target.cell.y) - int(b.cell.y)
					if (dx == 0 and abs(dy) <= 5 and sign(dy) == (1 if b.dir == 0 else -1 if b.dir == 1 else 0)) or \
					   (dy == 0 and abs(dx) <= 5 and sign(dx) == (1 if b.dir == 3 else -1 if b.dir == 2 else 0)):
						b.shoot_tank()
						break

		# Bot dart shooting
		if b.dart_count > 0:
			for target: CGOBomber in _players:
				if target.player_id != b.player_id and target.alive:
					var dx: int = int(target.cell.x) - int(b.cell.x)
					var dy: int = int(target.cell.y) - int(b.cell.y)
					if (dx == 0 and abs(dy) <= 6) or (dy == 0 and abs(dx) <= 6):
						_fire_dart(b)
						break

	var move_v: Vector2 = b.bot_dir
	_move_player(b, move_v, delta)

func _update_timer_hud() -> void:
	if not embedded:
		return
	var parent := get_parent()
	if parent != null and parent.name == "PlayfieldClip":
		parent = parent.get_parent()
	if parent == null:
		return
	var secs := maxi(int(_match_seconds_left), 0)
	var mins := secs / 60
	var rem_s := secs % 60
	var digits := [mins / 10, mins % 10, rem_s / 10, rem_s % 10]
	var ids := ["TimerMinTens", "TimerMinOnes", "TimerSecTens", "TimerSecOnes"]
	for i in 4:
		var node := parent.get_node_or_null(ids[i]) as TextureRect
		if node:
			var f := SpriteDB.get_frame("Game/Timer", digits[i])
			if not f.is_empty():
				node.texture = f.texture
	_update_item_hud(parent)

func _update_item_hud(parent: Node) -> void:
	if _item_hud_slots.is_empty():
		const SLOT_POS: Array[Vector2] = [Vector2(663, 488), Vector2(729, 488)]
		for i in range(2):
			var icon := TextureRect.new()
			icon.position = SLOT_POS[i]
			icon.size = Vector2(40, 40)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.z_index = 20
			parent.add_child(icon)
			var lbl := Label.new()
			lbl.position = SLOT_POS[i] + Vector2(18, 26)
			lbl.size = Vector2(28, 16)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
			lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.z_index = 21
			parent.add_child(lbl)
			_item_hud_slots.append({"icon": icon, "lbl": lbl, "sprite": "", "count": -1})
	for i in range(2):
		var slot: Dictionary = _item_hud_slots[i]
		var icon: TextureRect = slot.icon
		var lbl: Label = slot.lbl
		if not is_instance_valid(icon) or not is_instance_valid(lbl):
			continue
		var info: Dictionary = {}
		if i < _players.size() and (i == 0 or Session.is_2p):
			info = _players[i].get_quick_item_hud()
		var sp_name: String = str(info.get("sprite", ""))
		var cnt: int = int(info.get("count", 0))
		if sp_name == slot.sprite and cnt == slot.count:
			continue
		slot.sprite = sp_name
		slot.count = cnt
		if sp_name == "" or cnt <= 0:
			icon.visible = false
			lbl.visible = false
		else:
			var f := SpriteDB.get_frame(sp_name, 0)
			icon.texture = f.texture if not f.is_empty() else null
			icon.visible = icon.texture != null
			lbl.text = "x%d" % cnt
			lbl.visible = icon.visible
	if _personal_hud_slots.is_empty():
		for i in range(6):
			var base_pos := Vector2(246 + i * 40, 568)
			var p_icon := TextureRect.new()
			p_icon.position = base_pos
			p_icon.size = Vector2(28, 28)
			p_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p_icon.z_index = 20
			parent.add_child(p_icon)
			var p_lbl := Label.new()
			p_lbl.position = base_pos + Vector2(10, 16)
			p_lbl.size = Vector2(22, 14)
			p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			p_lbl.add_theme_font_size_override("font_size", 10)
			p_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			p_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
			p_lbl.add_theme_constant_override("outline_size", 3)
			p_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p_lbl.z_index = 21
			parent.add_child(p_lbl)
			_personal_hud_slots.append({"icon": p_icon, "lbl": p_lbl, "count": -1})
	var p1_slots: Array[Dictionary] = _players[0].get_inventory_slots() if _players.size() > 0 else []
	for i in range(mini(6, _personal_hud_slots.size())):
		var ps: Dictionary = _personal_hud_slots[i]
		var p_icon: TextureRect = ps.icon
		var p_lbl: Label = ps.lbl
		if not is_instance_valid(p_icon) or not is_instance_valid(p_lbl):
			continue
		var s_info: Dictionary = p1_slots[i] if i < p1_slots.size() else {}
		var cnt: int = int(s_info.get("count", 0))
		if cnt == ps.count:
			continue
		ps.count = cnt
		if cnt <= 0:
			p_icon.visible = false
			p_lbl.visible = false
		else:
			var f := SpriteDB.get_frame(str(s_info.get("sprite", "")), 0)
			p_icon.texture = f.texture if not f.is_empty() else null
			p_icon.visible = p_icon.texture != null
			p_lbl.text = "%d" % cnt
			p_lbl.visible = p_icon.visible

func _check_match_status() -> void:
	if _match_over:
		return
	if not embedded:
		# Ở bản đồ test độc lập, không tự ý kích hoạt kết thúc trận
		return
	if _is_test_mode():
		# Ở chế độ test hoặc test map (DevTest01), không tự động kết thúc trận và thoát game
		return
	if is_instance_valid(_start_banner):
		return
	if _players.size() > 0 and _players[0].start_ticks > 0:
		return

	var p1_alive: bool = _players.size() > 0 and bool(_players[0].alive)
	var p2_alive: bool = _players.size() > 1 and bool(_players[1].alive)

	if not p1_alive or not p2_alive or _match_seconds_left <= 0.0:
		_match_over = true
		var is_win := p1_alive and not p2_alive
		var is_draw := not p1_alive and not p2_alive
		var result := "draw" if is_draw else ("win" if is_win else "loss")
		AuthService.record_match_result(Session.user_id, result)

		for pl: CGOBomber in _players:
			if pl.alive:
				pl.cheer()
			else:
				if pl.action != "die":
					pl.action = "die"
					pl._update_visuals()

		if is_instance_valid(_result_banner):
			_result_banner.queue_free()
			_result_banner = null

		if is_win:
			AudioManager.play_sfx("Ntc_Win")
			_result_banner = CGOGlyphClass.create_win_glyph()
		elif not p1_alive and p2_alive:
			AudioManager.play_sfx("Ntc_Lose")
			_result_banner = CGOGlyphClass.create_lose_glyph()
		else:
			AudioManager.play_sfx("Ntc_Draw")
			_result_banner = CGOGlyphClass.create_draw_glyph()

		_result_banner.position = Vector2.ZERO
		add_child(_result_banner)

# -------------------------------------------------------------------------
# MAIN PROCESS LOOP
# -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_accum += delta
	var steps := mini(int(_tick_accum / TICK_SEC), 15)
	if steps > 0:
		_tick_accum -= steps * TICK_SEC
		for _s in steps:
			_global_tick += 1
			_step_animations()
			_step_floating_items()
			if not _players.is_empty():
				get_active_component().on_tick(_players)

	if embedded or _players.size() > 0:
		# Tank projectiles tick
		var proj_idx := _tank_projectiles.size() - 1
		while proj_idx >= 0:
			var proj: Dictionary = _tank_projectiles[proj_idx]
			var move_step: float = proj.speed * delta
			proj.pos += proj.dir * move_step
			proj.range_left -= move_step
			(proj.sprite as Sprite2D).position = proj.pos

			var gx := int(floor((proj.pos.x - _cur_origin.x) / CELL))
			var gy := int(floor((proj.pos.y - _cur_origin.y) / CELL))
			var gp := Vector2i(gx, gy)
			var hit := false

			if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
				hit = true
			else:
				var kind := get_tile_kind(gx, gy)
				if kind == 1:
					hit = true
					_create_flame_at(gp)
				elif kind == 2:
					hit = true
					break_box(gp)
					_create_flame_at(gp)

				if not hit:
					for pl: CGOBomber in _players:
						if pl.player_id != proj.owner_id and pl.alive and pl.get_center().distance_to(proj.pos) < 18.0:
							hit = true
							if pl.in_bubble:
								pl.pop_kill()
								AudioManager.play_sfx("Cha_BomberDie_SnowBall")
							elif pl.mount != null:
								_destroy_player_mount(pl)
							else:
								pl.trap_in_bubble()
							break

			if hit or proj.range_left <= 0:
				if is_instance_valid(proj.sprite):
					(proj.sprite as Sprite2D).queue_free()
				_tank_projectiles.remove_at(proj_idx)
			proj_idx -= 1

		# Darts tick
		var dart_idx := _darts.size() - 1
		while dart_idx >= 0:
			var d = _darts[dart_idx]
			if not is_instance_valid(d) or not d.get("active"):
				_darts.remove_at(dart_idx)
				dart_idx -= 1
				continue
			var col_targets: Array = []
			col_targets.append_array(_players)
			col_targets.append_array(_monsters)
			if _map_action_bomb != null:
				col_targets.append_array(_map_action_bomb.get_children())
			d.check_collision_with_objects(col_targets)
			dart_idx -= 1

		# Monsters tick
		var is_blocked := func(gx: int, gy: int) -> bool:
			if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
				return true
			var k := get_tile_kind(gx, gy)
			if k == 1 or k == 2:
				return true
			if _map_action_bomb != null and _map_action_bomb.has_bomb_at(gx, gy):
				return true
			if _map_action_bomb != null:
				for child in _map_action_bomb.get_children():
					if child is CGOExplosionClass and child.cell == Vector2i(gx, gy):
						return true
			return false

		var player_targets: Array = []
		var mon_targets: Array = []
		if not _monsters.is_empty():
			for pl: CGOBomber in _players:
				player_targets.append({"cell": pl.cell, "pos": pl.position, "alive": pl.alive, "in_bubble": pl.in_bubble})
			for mm in _monsters:
				if is_instance_valid(mm) and mm is CGOBossMonClass:
					mon_targets.append({"id": mm.instance_id, "cell": mm.cell, "pos": mm.position, "alive": mm.alive})

		var mon_idx := _monsters.size() - 1
		while mon_idx >= 0:
			var m = _monsters[mon_idx]
			if not is_instance_valid(m):
				_monsters.remove_at(mon_idx)
				mon_idx -= 1
				continue
			if m is CGOBossMonClass:
				var pass_b: bool = m.pass_box
				var pass_s: bool = m.pass_static
				var pass_bm: bool = m.pass_bomb
				var mon_blocked := func(gx: int, gy: int) -> bool:
					if gx < 0 or gx >= _cols or gy < 0 or gy >= _rows:
						return true
					var k := get_tile_kind(gx, gy)
					if k == 1 and not pass_s:
						return true
					if k == 2 and not pass_b:
						return true
					if not pass_bm and _map_action_bomb != null and _map_action_bomb.has_bomb_at(gx, gy):
						return true
					return false
				m.step_script_ai(delta, mon_blocked, player_targets, mon_targets)
				for pl: CGOBomber in _players:
					m.check_bomber_collision(pl)
			elif m is CGONpcBasicMonClass:
				if m is CGONpcAttackMonClass:
					m.scan_for_target(_players, is_blocked)
				m.step_ai(delta, is_blocked)
				for pl: CGOBomber in _players:
					m.check_bomber_collision(pl)
			mon_idx -= 1

		var mis_idx := _mon_missiles.size() - 1
		while mis_idx >= 0:
			var mis = _mon_missiles[mis_idx]
			if not is_instance_valid(mis) or not mis.step_missile(delta, _players):
				if is_instance_valid(mis):
					mis.queue_free()
				_mon_missiles.remove_at(mis_idx)
			mis_idx -= 1

		_update_scrolling_camera(delta)

		# Match clock only counts down after start banner finishes and until match is over
		var match_running := (_start_banner == null) and not _match_over and (_players.is_empty() or _players[0].start_ticks <= 0)
		if match_running:
			_match_seconds_left = maxf(_match_seconds_left - delta, 0.0)
		_update_timer_hud()

		# Post-match return to room timing (6.5s delay matching original BnB results duration)
		if embedded and _match_over:
			_match_over_timer += delta
			if _match_over_timer >= 6.5:
				Session.goto("prepare")
				return

		# Player 1 controls (In 1P: Arrow Keys or WASD; In 2P: Left side: WASD / RDFG)
		if _players.size() > 0:
			var p1: CGOBomber = _players[0]
			var m1 := Vector2.ZERO
			if Session.is_2p:
				if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_G):
					m1.x += 1.0
				elif Input.is_key_pressed(KEY_A):
					m1.x -= 1.0
				elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_V):
					m1.y += 1.0
				elif Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_R):
					m1.y -= 1.0
			else:
				if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
					m1.x += 1.0
				elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
					m1.x -= 1.0
				elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
					m1.y += 1.0
				elif Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
					m1.y -= 1.0
			_move_player(p1, m1, delta)

		# Player 2 controls / Bot (In 2P: Right side: Arrow Keys & Numpad)
		if _players.size() > 1:
			var p2: CGOBomber = _players[1]
			if p2.is_bot:
				if not _is_test_mode():
					_update_bot(p2, delta)
			else:
				var m2 := Vector2.ZERO
				if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_KP_6):
					m2.x += 1.0
				elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_KP_4):
					m2.x -= 1.0
				elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_KP_2):
					m2.y += 1.0
				elif Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_KP_8):
					m2.y -= 1.0
				_move_player(p2, m2, delta)

		_check_match_status()

func _step_animations() -> void:
	var i := _anim_nodes.size() - 1
	while i >= 0:
		var entry: Dictionary = _anim_nodes[i]
		if not is_instance_valid(entry.sprite):
			_anim_nodes.remove_at(i)
			i -= 1
			continue
		if entry.get("reactive", false) and entry.state_name == "Default":
			entry.reactive_cd = int(entry.get("reactive_cd", 220)) - 1
			if entry.reactive_cd <= 0:
				entry.reactive_cd = 200 + (randi() % 67)
				var r_state := "User" if _has_state(int(entry.id), "User") else ("Twinkle" if _has_state(int(entry.id), "Twinkle") else "")
				if r_state != "":
					set_cell_state(entry.grid_pos, r_state, false, "Default")
					i -= 1
					continue

		var frames: Array = entry.state_data.frames
		if frames.is_empty():
			i -= 1
			continue
		var dur := int(frames[entry.frame_idx][1])
		if dur < 0:
			i -= 1
			continue
		entry.tick_in_frame += 1
		if entry.tick_in_frame >= maxi(dur, 1):
			entry.tick_in_frame = 0
			entry.frame_idx += 1
			if entry.frame_idx >= frames.size():
				if entry.loop:
					entry.frame_idx = 0
					_apply_anim_frame(entry)
				else:
					var nxt := str(entry.get("next_state", "Default"))
					if nxt == "__remove__":
						var gp: Vector2i = entry.grid_pos
						if entry.get("is_passable", false):
							_passable_tiles.erase(gp)
							_passable_objects.erase(gp)
							(entry.sprite as Sprite2D).queue_free()
							_anim_nodes.remove_at(i)
							_sync_box_concealment(gp)
						else:
							if _tiles.has(gp):
								var finished_tile: Variant = _tiles[gp]
								if finished_tile is CGOTileFixedBoxClass or finished_tile is CGOTileMoveAbleBoxClass:
									finished_tile.finish_break()
								_tiles.erase(gp)
							set_flame_blocked(gp.x, gp.y, false)
							(entry.sprite as Sprite2D).queue_free()
							_cell_objects.erase(gp)
							_anim_nodes.remove_at(i)
							if _pending_cell_items.has(gp):
								var ci = _pending_cell_items[gp]
								_pending_cell_items.erase(gp)
								var chance: int = int(ci.get("chance", 100)) if ci is Dictionary else 100
								if randi() % 100 < chance:
									spawn_floating_item(gp, str(ci.get("name", ci)))
							elif randf() < 0.45:
								var dropped_item := _roll_drop_item()
								if dropped_item != "":
									spawn_floating_item(gp, dropped_item)
					else:
						_set_entry_state(entry, nxt, true, "Default")
			else:
				_apply_anim_frame(entry)
		i -= 1

func _step_floating_items() -> void:
	for it: Dictionary in _floating_items:
		if not is_instance_valid(it.sprite):
			continue
		var age := _global_tick - int(it.spawn_tick)
		var n5 := int((age % 60) / 5)
		var dy := (9 - n5) if n5 > 5 else (n5 - 3)
		var it_offset: Vector2 = it.get("offset", Vector2.ZERO)
		(it.sprite as Sprite2D).position = Vector2(it.px - it_offset.x, it.py + 39 - it_offset.y + dy)
		var sh_idx := 8 if dy > 0 else 7
		var sh_f := SpriteDB.get_frame("Shadow/Shadow", sh_idx)
		if not sh_f.is_empty() and is_instance_valid(it.shadow):
			(it.shadow as Sprite2D).texture = sh_f.texture
			(it.shadow as Sprite2D).position = Vector2(it.px - sh_f.offset.x, it.py + 39 - sh_f.offset.y)

func _show() -> void:
	_anim_nodes.clear()
	_cell_objects.clear()
	_passable_objects.clear()
	for t_obj in _tiles.values():
		if is_instance_valid(t_obj):
			t_obj.free()
	_tiles.clear()
	for p_obj in _passable_tiles.values():
		if is_instance_valid(p_obj):
			p_obj.free()
	_passable_tiles.clear()
	_game_item_man.clear()
	_ground_tiles.clear()
	_game_item_man.clear()
	_rail_ground_cells.clear()
	_player_last_passable_cell.clear()
	_flame_blocked.clear()
	_floating_items.clear()
	_cur_map_drops.clear()
	_pending_cell_items.clear()
	for c in get_children():
		if c != _label and c != _map_action_bomb:
			c.queue_free()
	var mname := _maps[_cur]
	var path := SpriteDB.root.path_join("Map").path_join(mname).path_join("map.json")
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not embedded:
		var vn_name := Session.get_map_name_vn(mname)
		_label.text = "%s [%s] (%d/%d)  [Mũi tên/WASD: di chuyển | Space: đặt bom | Ctrl: item/kích nổ | [/] hoặc PgUp/PgDn: đổi map]" % [vn_name, mname, _cur + 1, _maps.size()]
	_update_bgm(mname)
	if m == null:
		if not embedded:
			_label.text += "  no map.json"
		return
	_cols = int(m.cols)
	_rows = int(m.rows)
	_cur_map_drops = m.get("items", m.get("drops", []))
	var origin := get_map_origin(_cols, _rows)
	_cur_origin = origin
	if _map_action_bomb != null:
		_map_action_bomb.map_origin = _cur_origin
	for y in _rows:
		for x in _cols:
			var cell: Dictionary = m.grid[y][x]
			for layer in ["ground", "object"]:
				var obj_id := int(cell[layer])
				var st := _find_state(obj_id, "Default")
				if st.is_empty() or (st.frames as Array).is_empty():
					continue
				var f := SpriteDB.get_frame(str(st.sprite), int(st.frames[0][0]))
				if f.is_empty():
					continue
				var s := Sprite2D.new()
				s.centered = false
				s.texture = f.texture
				var px := origin.x + x * CELL
				var py := origin.y + y * CELL
				s.position = Vector2(px - f.offset.x, py + 39 - f.offset.y)
				s.z_index = 0 if layer == "ground" else 2 + y
				add_child(s)

				var is_reactive := _has_state(obj_id, "User") or _has_state(obj_id, "Twinkle")
				var entry := {
					"id": obj_id,
					"layer": layer,
					"grid_pos": Vector2i(x, y),
					"sprite": s,
					"px": px,
					"py": py,
					"state_name": str(st.state),
					"state_data": st,
					"frame_idx": 0,
					"tick_in_frame": 0,
					"loop": true,
					"next_state": "Default",
					"reactive": is_reactive,
					"reactive_cd": 120 + (randi() % 120),
				}
				if layer == "ground":
					var g_name: String = str(_table[obj_id].name) if _table.has(obj_id) else ""
					var g_info: CTileInfoClass = CTileInfoClass.get_info(g_name)
					if g_info != null and g_info.is_conveyor:
						_ground_tiles[Vector2i(x, y)] = g_info
					if g_name.find("Rail") != -1:
						_rail_ground_cells[Vector2i(x, y)] = true
				elif layer == "object":
					var gp_obj := Vector2i(x, y)
					var tile_obj: CGOTileClass = _create_tile_object(obj_id, gp_obj)
					entry["tile"] = tile_obj
					if tile_obj is CGOTilePassableClass:
						entry["is_passable"] = true
						_passable_tiles[gp_obj] = tile_obj
						_passable_objects[gp_obj] = entry
						if tile_obj.tile_info != null and tile_obj.tile_info.draw_under_player:
							s.z_index = 0 # Draw over ground (later sibling at z=0) & strictly under explosions(1)/items/bombs/players (sub_71F938, b[20] != 0)
						if tile_obj.blocks_flame():
							set_flame_blocked(x, y, true)
					else:
						_tiles[gp_obj] = tile_obj
						set_flame_blocked(x, y, tile_obj.blocks_flame())
						_cell_objects[gp_obj] = entry
				if (st.frames as Array).size() > 1 or is_reactive:
					_anim_nodes.append(entry)

	_spawn_players(m)
	# Items inside destructible blocks are hidden until the block is destroyed.
	# Items on open tiles spawn immediately.
	for ci in m.get("cell_items", []):
		if ci is Dictionary and ci.get("name") != null:
			var gp := Vector2i(int(ci.x), int(ci.y))
			if _cell_objects.has(gp):
				_pending_cell_items[gp] = ci
			else:
				spawn_floating_item(gp, str(ci.name))
	if not embedded and show_spawns:
		for sp: Array in m.spawns:
			var r := ColorRect.new()
			r.color = Color(1, 0, 0, 0.25)
			r.position = origin + Vector2(sp[0], sp[1]) * CELL
			r.size = Vector2(CELL, CELL)
			r.z_index = 50
			add_child(r)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var local_pos := get_local_mouse_position() - _cur_origin
		var gx := int(floor(local_pos.x / CELL))
		var gy := int(floor(local_pos.y / CELL))
		var gp := Vector2i(gx, gy)
		if _cell_objects.has(gp):
			var obj_id := int(_cell_objects[gp].id)
			if _has_state(obj_id, "ShakenHorz") or _has_state(obj_id, "ShakenVert"):
				shake_passable(gp, randf() < 0.5)
			elif _has_state(obj_id, "Broken"):
				break_box(gp)
			elif _has_state(obj_id, "User"):
				set_cell_state(gp, "User", false, "Default")

func _try_place_specific_ground_trap(p: CGOBomber, trap_type: int) -> bool:
	var placed: bool = _game_item_man.try_place_bomber_trap(
		p, trap_type, _cols, _rows, get_tile_kind(p.cell.x, p.cell.y),
		_ground_tiles.get(p.cell, null), _cur_origin, self, get_cell_anchor(p.cell.x, p.cell.y), SpriteDB
	)
	if placed and trap_type == CGOTileGroundClass.TRAP_BANANA:
		AudioManager.play_sfx("Itm_PutBanana")
	return placed

func _try_place_player_ground_trap(p: CGOBomber) -> bool:
	return _try_place_specific_ground_trap(p, p.peek_ground_trap())

func _trigger_player_quick_action(p: CGOBomber) -> void:
	if not p.alive or p.start_ticks > 0:
		return
	if p.in_bubble:
		if p.needle_count > 0:
			p.use_needle()
		elif p.oxygen_count > 0:
			p.try_use_oxygen()
	elif p.m_fAbTank:
		_place_bomb(p)
	elif p.go_ship != null and p.go_ship.is_kart():
		p.trigger_kart_boost()
	elif p.dart_count > 0:
		_fire_dart(p)
	elif _try_place_player_ground_trap(p):
		pass
	elif _map_action_bomb != null and _map_action_bomb.detonate_owner_bomb(p.player_id):
		pass

func _use_player_inventory_slot(p: CGOBomber, slot: int) -> void:
	if not p.alive or p.start_ticks > 0:
		return
	match slot:
		0:
			p.use_needle()
		1:
			p.try_use_oxygen()
		2:
			_fire_dart(p)
		3:
			_try_place_specific_ground_trap(p, CGOTileGroundClass.TRAP_BANANA)
		4:
			_try_place_specific_ground_trap(p, CGOTileGroundClass.TRAP_BOND)
		5:
			_try_place_specific_ground_trap(p, CGOTileGroundClass.TRAP_MINE)

func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.is_pressed():
		return
	var key := (ev as InputEventKey).keycode

	if _match_over and (key == KEY_ESCAPE or key == KEY_ENTER):
		get_viewport().set_input_as_handled()
		Session.goto("prepare" if embedded else "lobby")
		return

	# 1P Mode / Player 1 actions (Space: đặt bom | Ctrl/E: item nhanh/kích nổ | 1..6: túi đồ)
	if _players.size() > 0:
		var p1: CGOBomber = _players[0]
		# Place Bomb: Spacebar (or Shift in 2P)
		if key == KEY_SPACE or (Session.is_2p and key == KEY_SHIFT):
			get_viewport().set_input_as_handled()
			if p1.start_ticks <= 0:
				_place_bomb(p1)
		# Quick Item / Detonate / Needle / Dart / Tank: Ctrl or E
		elif key == KEY_CTRL or key == KEY_E:
			get_viewport().set_input_as_handled()
			if p1.start_ticks <= 0:
				_trigger_player_quick_action(p1)
		# Inventory Item slots 1..6: Number keys 1..6
		elif key >= KEY_1 and key <= KEY_6:
			get_viewport().set_input_as_handled()
			if p1.start_ticks <= 0:
				_use_player_inventory_slot(p1, key - KEY_1)

	# 2P Mode / Player 2 actions (Right side controls from CA.exe sub_59E0B4)
	if Session.is_2p and _players.size() > 1:
		var p2: CGOBomber = _players[1]
		# Place Bomb: Right Shift, Numpad 0, Enter, Slash
		if key == KEY_SHIFT or key == KEY_KP_0 or key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SLASH:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_place_bomb(p2)
		# Quick Item / Detonate / Needle / Dart / Tank: Right Ctrl, Numpad Period, End, Delete, Q, C
		elif key == KEY_CTRL or key == KEY_KP_PERIOD or key == KEY_END or key == KEY_DELETE or key == KEY_Q or key == KEY_C:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_trigger_player_quick_action(p2)
		# Inventory Item slots 1..6: Navigation cluster & Numpad 1..6
		elif key == KEY_INSERT or key == KEY_KP_1:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 0)
		elif key == KEY_HOME or key == KEY_KP_2:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 1)
		elif key == KEY_PAGEUP or key == KEY_KP_3:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 2)
		elif key == KEY_DELETE or key == KEY_KP_4:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 3)
		elif key == KEY_END or key == KEY_KP_5:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 4)
		elif key == KEY_PAGEDOWN or key == KEY_KP_6:
			get_viewport().set_input_as_handled()
			if p2.start_ticks <= 0:
				_use_player_inventory_slot(p2, 5)

	# Standalone Map Viewer mode keys: đổi map bằng [ ] hoặc PgUp/PgDn, không xung đột mũi tên di chuyển
	if not embedded:
		match key:
			KEY_BRACKETRIGHT, KEY_PAGEDOWN:
				_cur = (_cur + 1) % _maps.size()
				_show()
			KEY_BRACKETLEFT, KEY_PAGEUP:
				_cur = (_cur - 1 + _maps.size()) % _maps.size()
				_show()
			KEY_ESCAPE:
				Session.goto("lobby")
