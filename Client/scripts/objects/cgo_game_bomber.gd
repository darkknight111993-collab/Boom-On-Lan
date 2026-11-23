class_name CGOGameBomber
extends "res://scripts/objects/cgo_bomber.gd"

## In-match bomber entity (CA.exe RTTI .?AVCGOGameBomber@@ @ 0xe22574, ctor sub_5B231F, dtor sub_5AF829).
## Used for all players in a match (1P, 2P, remote, AI). Game-mode subclasses (Monster, Zombie,
## Captain, Survival, etc.) inherit from this class. Network packet reception lives outside in
## CGameStage / CGameMsgCache (sub_6F4FD1), not inside CGOGameBomber.

const ACTION_COOLDOWN_TICKS := 26 # 0x1A guard in sub_5B19B3 @ 0x5b19d5

var match_tick_counter: int = 0
var last_multi_bomb_tick: int = -ACTION_COOLDOWN_TICKS # this[3144]
var _match_event_flag: bool = false # this[169] cleared by sub_5AE4DA

func on_match_event(event_type: int) -> bool:
	# From sub_5AE4DA (off_C356D4 event callback): on event+8 == 0, clear flag & SetVisible(1)
	if event_type != 0:
		return false
	_match_event_flag = false
	set_bomber_visible(true)
	_update_visuals()
	return true

func can_trigger_multi_bomb() -> bool:
	# From sub_5B19B3 @ 0x5b19d5
	return (match_tick_counter - last_multi_bomb_tick) >= ACTION_COOLDOWN_TICKS

func record_multi_bomb_tick() -> void:
	last_multi_bomb_tick = match_tick_counter

func _on_tick() -> void:
	match_tick_counter += 1
	super._on_tick()
