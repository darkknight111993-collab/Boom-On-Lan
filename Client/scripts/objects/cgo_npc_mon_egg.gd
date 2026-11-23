class_name CGONpcMonEgg
extends "res://scripts/objects/c_game_object.gd"

## CGONpcMonEgg - Trứng quái vật đẻ con
## Ported from CA.exe CGONpcMonEgg (sub_51BDD8, sub_51BF4E, sub_51C073)

signal egg_hatched(monster_id: String, at_cell: Vector2i)
signal egg_destroyed(at_cell: Vector2i)

@export var monster_id: String = "SM01"
@export var hatch_duration: float = 5.0

var hatch_timer: float = 0.0
var is_hatched: bool = false
var is_destroyed: bool = false

func setup_egg(col: int, row: int, spawn_mon_id: String = "SM01", duration: float = 5.0, p_map_origin: Vector2 = Vector2(20, 41)) -> void:
	map_origin = p_map_origin
	monster_id = spawn_mon_id
	hatch_duration = duration
	hatch_timer = duration
	is_hatched = false
	is_destroyed = false
	set_cell(col, row)
	play_anim("Shop/S_DlgBasketEggAppearB", [[0, 10]], true)

func _physics_process(delta: float) -> void:
	if is_hatched or is_destroyed:
		return
	
	hatch_timer -= delta
	
	# Visual shake / pulse as time runs out
	if hatch_timer <= 1.5:
		# Rapid pulse animation
		var fr := int(hatch_timer * 10.0) % 2
		play_anim("Shop/S_DlgBasketEggBreakB", [[fr, 2]], true)
	
	if hatch_timer <= 0.0:
		hatch()

func hatch() -> void:
	if is_hatched or is_destroyed:
		return
	is_hatched = true
	egg_hatched.emit(monster_id, cell)
	queue_free()

func hit_by_flame(flame_cell: Vector2i) -> bool:
	if is_hatched or is_destroyed:
		return false
	if flame_cell == cell:
		destroy_egg()
		return true
	return false

func destroy_egg() -> void:
	if is_hatched or is_destroyed:
		return
	is_destroyed = true
	egg_destroyed.emit(cell)
	queue_free()
