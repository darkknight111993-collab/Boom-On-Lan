class_name CMonsterComponent
extends "res://scripts/modes/c_component.gd"

## Monster Arena / StageClear / Boss / Season 2 game mode component.
## Ported from CA.exe CMonsterComponent (0xe412e4) & CStageClearComponent (0xe3e894).

signal stage_cleared(win_team: int)
signal trigger_dispatched(trigger_name: String, source: Node)

const CStageClearScriptClass = preload("res://scripts/modes/c_stage_clear_script.gd")
const CGOBossMonClass = preload("res://scripts/objects/cgo_boss_mon.gd")

var stage_script: CStageClearScriptClass = null
var active_monsters: Array = []
var total_killed: int = 0
var is_stage_cleared: bool = false
var _next_instance_id: int = 1

func _init(p_component_id: int = MODE_STAGE_CLEAR, p_stage: Node = null) -> void:
	super._init(p_component_id, p_stage)
	stage_script = CStageClearScriptClass.new()

func load_script_xml(xml_text: String) -> bool:
	active_monsters.clear()
	total_killed = 0
	is_stage_cleared = false
	_next_instance_id = 1
	return stage_script.parse_xml(xml_text)

var grid_cols: int = 15
var grid_rows: int = 13

func create_monster_node(obj_def: Dictionary) -> CGOBossMonClass:
	var mon: CGOBossMonClass = CGOBossMonClass.new()
	mon.setup_from_script(obj_def, _next_instance_id, grid_cols, grid_rows)
	_next_instance_id += 1
	active_monsters.append(mon)
	return mon

func spawn_start_monsters(add_node_cb: Callable) -> Array:
	var spawned: Array = []
	if stage_script == null:
		return spawned
	for obj_def in stage_script.get_start_objects():
		var mon := create_monster_node(obj_def)
		if add_node_cb.is_valid():
			add_node_cb.call(mon)
		spawned.append(mon)
	return spawned

func spawn_class_monsters(obj_class: int, spawn_cell: Vector2i, add_node_cb: Callable) -> Array:
	var spawned: Array = []
	if stage_script == null or active_monsters.size() >= 18:
		return spawned
	var defs := stage_script.get_objects_by_class(obj_class)
	if defs.is_empty():
		return spawned
	var def_copy: Dictionary = defs[0].duplicate(true)
	var info: Dictionary = def_copy.get("init_info", {})
	info["pos"] = spawn_cell
	def_copy["init_info"] = info
	var mon := create_monster_node(def_copy)
	if add_node_cb.is_valid():
		add_node_cb.call(mon)
	spawned.append(mon)
	return spawned

func on_monster_damaged(mon: Node) -> void:
	if mon == null:
		return
	var is_b := bool(mon.get("is_boss"))
	if is_b:
		dispatch_trigger("bossdamaged", mon)
	else:
		dispatch_trigger("damaged", mon)
	dispatch_trigger("monhpchanged", mon)

func on_monster_angered(mon: Node) -> void:
	dispatch_trigger("bossanger", mon)

func on_monster_died(mon: Node) -> void:
	if mon == null:
		return
	active_monsters.erase(mon)
	total_killed += 1
	if total_killed == 1:
		dispatch_trigger("firstmondie", mon)
	if active_monsters.size() == 1:
		dispatch_trigger("lastmonleft", mon)

	# Check classalldie
	var dead_cls := int(mon.get("obj_class"))
	var any_same_cls := false
	for m in active_monsters:
		if is_instance_valid(m) and bool(m.get("alive")) and int(m.get("obj_class")) == dead_cls:
			any_same_cls = true
			break
	if not any_same_cls:
		dispatch_trigger("classalldie", mon)

	# Check stage clear (all required monsters/bosses dead)
	if not is_stage_cleared and get_alive_count() == 0:
		is_stage_cleared = true
		stage_cleared.emit(0)

func get_alive_count() -> int:
	var cnt := 0
	for m in active_monsters:
		if is_instance_valid(m) and bool(m.get("alive")):
			cnt += 1
	return cnt

func dispatch_trigger(trigger_name: String, source: Node = null) -> void:
	trigger_dispatched.emit(trigger_name, source)
	for m in active_monsters:
		if is_instance_valid(m) and bool(m.get("alive")) and m.has_method("fire_trigger"):
			m.fire_trigger(trigger_name)
