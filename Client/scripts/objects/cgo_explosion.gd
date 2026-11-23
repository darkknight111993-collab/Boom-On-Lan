class_name CGOExplosion
extends "res://scripts/objects/c_game_object.gd"

## CGOFlame segment: group/frame data comes from Flame/Flame in ObjectTable.

const OBJECT_TABLE_PATH := "res://data/objecttable.json"
const FLAME_TEMPLATE_NAME := "Flame/Flame"
const FLAME_SPRITE := "Bomb/Fire00"
static var _flame_groups: Array = []
var _delay_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	_apply_current_frame()
	if _delay_remaining > 0.0:
		sprite_node.visible = false

func _process(delta: float) -> void:
	if _delay_remaining > 0.0:
		_delay_remaining = maxf(_delay_remaining - delta, 0.0)
		if _delay_remaining == 0.0 and sprite_node != null:
			sprite_node.visible = true
	super._process(delta)

func setup(col: int, row: int, group_idx: int = 0, delay_ticks: int = 0) -> void:
	set_cell(col, row)
	if _flame_groups.is_empty():
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(OBJECT_TABLE_PATH))
		if entries is Array:
			for entry in entries:
				if entry is Dictionary and entry.get("name", "") == FLAME_TEMPLATE_NAME:
					_flame_groups = entry.get("states", [])
					break
	if group_idx < 0 or group_idx >= _flame_groups.size():
		queue_free()
		return
	var group: Dictionary = _flame_groups[group_idx]
	var frames: Array = group.get("frames", [])
	if frames.is_empty():
		queue_free()
		return
	play_anim(FLAME_SPRITE, frames, false)
	_delay_remaining = maxi(delay_ticks, 0) * TICK_SEC
	anim_tick_timer = -_delay_remaining
	animation_finished.connect(queue_free)
