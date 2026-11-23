class_name CGOMonMissile
extends Node2D

## Season 2 Monster Missile projectile (createmonmissile action).
## Renders real MonsterSeason2/Bomb_M_Missile00..06 sprites and travels along angle.

var velocity: Vector2 = Vector2.ZERO
var max_dist: float = 300.0
var traveled: float = 0.0
var missile_type: int = 5
var angle_deg: float = 0.0
var active: bool = true
var sprite_path: String = ""
var _sp: Sprite2D = null
var _anim_t: float = 0.0

static func resolve_missile_sprite_path(p_type: int, p_angle_deg: float) -> String:
	var t := clampi(p_type, 0, 6)
	if t == 5:
		var ang_idx := int(round(fposmod(p_angle_deg, 360.0) / 30.0)) % 12
		return "MonsterSeason2/Bomb_M_Missile05_%02d" % ang_idx
	return "MonsterSeason2/Bomb_M_Missile%02d" % t

func setup(start_pos: Vector2, p_angle_deg: float, p_speed: float = 5.0, p_max_len: float = 300.0, p_type: int = 5) -> void:
	position = start_pos
	angle_deg = p_angle_deg
	missile_type = p_type
	max_dist = maxf(40.0, p_max_len)
	traveled = 0.0
	active = true
	var rad := deg_to_rad(p_angle_deg)
	var px_per_sec := clampf(p_speed * 36.0, 60.0, 360.0)
	velocity = Vector2(cos(rad), sin(rad)) * px_per_sec
	sprite_path = resolve_missile_sprite_path(p_type, p_angle_deg)
	z_index = 15
	if _sp == null:
		_sp = Sprite2D.new()
		_sp.centered = false
		add_child(_sp)
	_update_frame()

func _update_frame() -> void:
	if _sp == null or not is_inside_tree():
		return
	var sdb := get_node_or_null("/root/SpriteDB")
	if sdb == null:
		return
	var f_idx := int(_anim_t * 12.0) % 4
	var f: Dictionary = sdb.get_frame(sprite_path, f_idx)
	if f.is_empty():
		f = sdb.get_frame(sprite_path, 0)
	if not f.is_empty() and f.get("texture") != null:
		_sp.texture = f["texture"]
		_sp.position = -f["offset"]

func step_missile(delta: float, players: Array) -> bool:
	if not active:
		return false
	var dp := velocity * delta
	position += dp
	traveled += dp.length()
	_anim_t += delta
	_update_frame()

	for p in players:
		if not is_instance_valid(p) or not p.get("alive") or p.get("in_bubble"):
			continue
		var p_center: Vector2 = p.position + Vector2(20.0, -20.0)
		if position.distance_to(p_center) < 24.0:
			if p.has_method("trap_in_bubble"):
				p.trap_in_bubble()
			active = false
			return false

	if traveled >= max_dist:
		active = false
		return false
	return true
