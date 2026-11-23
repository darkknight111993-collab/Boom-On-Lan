class_name CGODart
extends "res://scripts/objects/c_game_object.gd"

## CGODart - Phi tiêu bắn thẳng
## Ported from CA.exe CGODart (sub_4394D5, sub_43D4D0, sub_43D544)

signal hit_target(target: Node2D)
signal expired()

# Directions matching CGOBomber: 0: Down, 1: Up, 2: Left, 3: Right
const DIR_DOWN := 0
const DIR_UP := 1
const DIR_LEFT := 2
const DIR_RIGHT := 3

const DIR_VECTORS := [
	Vector2(0, 1),  # DOWN
	Vector2(0, -1), # UP
	Vector2(-1, 0), # LEFT
	Vector2(1, 0)   # RIGHT
]

# ThrownDart frames mapping: DOWN->3, UP->1, LEFT->2, RIGHT->0
const DIR_FRAMES := [3, 1, 2, 0]

@export var direction: int = DIR_DOWN
@export var speed: float = 1000.0 # 30 px per 30ms tick = 1000 px/s
@export var max_distance: float = 600.0 # 15 tiles * 40 px

var owner_bomber: Node2D = null
var distance_traveled: float = 0.0
var active: bool = true

func _ready() -> void:
	super._ready()
	_update_direction_frame()

func setup(p_owner: Node2D, p_start_pos: Vector2, p_direction: int, p_map_origin: Vector2 = Vector2(20, 41)) -> void:
	owner_bomber = p_owner
	map_origin = p_map_origin
	direction = clampi(p_direction, 0, 3)
	position = p_start_pos
	# Anchor offset: in CA.exe, dart starts at y - 20
	position.y -= 20
	_update_direction_frame()

func _update_direction_frame() -> void:
	var fr_idx: int = DIR_FRAMES[clampi(direction, 0, 3)]
	play_anim("Item/ThrownDart", [[fr_idx, 999]], false)

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	var dir_vec: Vector2 = DIR_VECTORS[clampi(direction, 0, 3)]
	var step: float = speed * delta
	distance_traveled += step
	position += dir_vec * step
	
	# Compute current cell
	var local_pos := position - map_origin
	var col := int(floor(local_pos.x / CELL_SIZE))
	var row := int(floor(local_pos.y / CELL_SIZE))
	
	# Check boundary
	if col < 0 or col >= 15 or row < 0 or row >= 13 or distance_traveled >= max_distance:
		expire()
		return

func check_collision_with_objects(objects: Array) -> bool:
	if not active:
		return false
	
	var my_rect := Rect2(position - Vector2(10, 10), Vector2(20, 20))
	
	for obj in objects:
		if obj == null or not is_instance_valid(obj) or obj == owner_bomber:
			continue
		
		# Check Bomb
		if obj.has_method("explode") and obj.get("active") != false:
			var obj_rect := Rect2(obj.position - Vector2(20, 20), Vector2(40, 40))
			if my_rect.intersects(obj_rect):
				hit_target.emit(obj)
				obj.explode()
				expire()
				return true
		
		# Check Bomber (rescues or eliminates)
		if obj.get("is_trapped") != null and obj.is_trapped:
			var obj_rect := Rect2(obj.position - Vector2(20, 39), Vector2(40, 40))
			if my_rect.intersects(obj_rect):
				hit_target.emit(obj)
				var is_same_team := false
				if owner_bomber and owner_bomber.get("team_color") != null and obj.get("team_color") != null:
					is_same_team = (owner_bomber.team_color == obj.team_color)
				
				if is_same_team:
					if obj.has_method("rescue"):
						obj.rescue()
				else:
					if obj.has_method("pop_kill"):
						obj.pop_kill()
				expire()
				return true
		
		# Check Monster
		if obj.has_method("hit_by_flame") and obj.get("is_dead") != true:
			var obj_rect := Rect2(obj.position - Vector2(20, 39), Vector2(40, 40))
			if my_rect.intersects(obj_rect):
				hit_target.emit(obj)
				obj.hit_by_flame(Vector2.ZERO)
				expire()
				return true
		
		# Check solid obstacle / box
		if obj.get("is_obstacle") == true or (obj.get("is_broken") == false and obj.has_method("hit_by_flame")):
			var obj_rect := Rect2(obj.position - Vector2(0, 39), Vector2(40, 40))
			if my_rect.intersects(obj_rect):
				# Hits obstacle, cannot penetrate
				expire()
				return true
				
	return false

func expire() -> void:
	if not active:
		return
	active = false
	expired.emit()
	queue_free()
