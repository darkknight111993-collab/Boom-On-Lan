class_name CGOObstacleTrap
extends "res://scripts/objects/c_game_object.gd"

## CGOObstacleTrap - Bẫy cạm trên bản đồ (TrapGround H/V)
## Ported from CA.exe CGOObstacleTrap, CGOObstacleTrapH, CGOObstacleTrapV (sub_439664, sub_43969D)

signal trap_triggered(entity: Node2D)

enum Orientation {
	HORIZONTAL = 0,
	VERTICAL = 1
}

@export var orientation: int = 0
@export var is_armed: bool = true
@export var rearm_duration: float = 3.0

var rearm_timer: float = 0.0

func setup_trap(col: int, row: int, p_orientation: int = 0, p_map_origin: Vector2 = Vector2(20, 41)) -> void:
	map_origin = p_map_origin
	orientation = p_orientation
	is_armed = true
	set_cell(col, row)
	_update_visuals()

func _update_visuals() -> void:
	var fr := 0 if orientation == Orientation.HORIZONTAL else 1
	play_anim("Item/TrapGround", [[fr, -1]], false)

func check_trigger(entity: Node2D) -> bool:
	if not is_armed or entity == null:
		return false
	
	if position.distance_to(entity.position) < 30.0:
		trigger(entity)
		return true
	return false

func trigger(entity: Node2D) -> void:
	is_armed = false
	rearm_timer = rearm_duration
	trap_triggered.emit(entity)
	
	# If bomber, apply trap slow or trap effect
	if entity.has_method("trap_in_bubble"):
		entity.trap_in_bubble()
	elif entity.get("is_trapped") != null:
		entity.set("is_trapped", true)

func _physics_process(delta: float) -> void:
	if not is_armed:
		rearm_timer -= delta
		if rearm_timer <= 0.0:
			is_armed = true
			_update_visuals()
