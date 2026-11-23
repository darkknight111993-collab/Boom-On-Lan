class_name CHedgehogComponent
extends "res://scripts/modes/c_component.gd"

## Hedgehog game mode component (CA.exe RTTI .?AVCHedgehogComponent@@ @ 0xe40b00,
## ctor sub_74900D with component_id = 11, OnPlayerDied sub_749111,
## OnMatchEnd sub_749159, UpdateCollision sub_7491D4, UpdateTick sub_749342).

const CGOHedgehogBomberClass = preload("res://scripts/objects/cgo_hedgehog_bomber.gd")
const CGOBomberBaseClass = preload("res://scripts/objects/cgo_bomber_base.gd")

func _init(p_stage: Node = null) -> void:
	super._init(MODE_HEDGEHOG, p_stage)

func create_bomber() -> Node:
	return CGOHedgehogBomberClass.new()

func on_player_hit_by_flame(bomber: Node) -> bool:
	# From sub_74A8D9: real Hedgehog stuns (60 -> 75) instead of entering bubble; FakeHedgehog reveals human
	if bomber is CGOHedgehogBomberClass:
		return (bomber as CGOHedgehogBomberClass).on_flame_hit_hedgehog()
	return false

func on_player_popped(bomber: Node) -> bool:
	# From sub_749111 -> sub_74A11F: popped player transforms into real Hedgehog instead of dying
	if bomber is CGOHedgehogBomberClass and not (bomber as CGOHedgehogBomberClass).is_hedgehog():
		return (bomber as CGOHedgehogBomberClass).transform_to_hedgehog()
	return false

func find_hedgehog_hits(players: Array, targets: Array) -> Array:
	# From sub_7491D4 & sub_749B1F: active Hedgehogs (not faint 60/75, sub_749824) colliding with target rects
	var hits: Array = []
	for p in players:
		if not (p is CGOHedgehogBomberClass):
			continue
		var h: CGOHedgehogBomberClass = p
		if not h.can_hedgehog_collide():
			continue
		for t in targets:
			if t == h:
				continue
			var rect: Rect2 = t.get_flame_hitbox() if t.has_method("get_flame_hitbox") else Rect2()
			if rect.size.x > 0.0 and rect.size.y > 0.0 and h.check_hedgehog_hitbox(rect):
				hits.append([h, t])
	return hits

func on_tick(players: Array) -> void:
	# From sub_749342 -> sub_7491D4: check active Hedgehogs popping trapped players
	var trapped_targets: Array = []
	for p in players:
		if is_instance_valid(p) and p.alive and p.in_bubble and p.can_pop_or_rescue():
			trapped_targets.append(p)
	if trapped_targets.is_empty():
		return
	for pair in find_hedgehog_hits(players, trapped_targets):
		var target = pair[1]
		if not on_player_popped(target):
			target.pop_kill()

func on_match_end(players: Array, win_team: int) -> void:
	# From sub_749159: winning-team Hedgehogs play state 61 (Hurrah), losing-team play 62 (Cry)
	for p in players:
		if not (p is CGOHedgehogBomberClass):
			continue
		var h: CGOHedgehogBomberClass = p
		if not h.is_hedgehog():
			continue
		var p_team: int = int(h.get("team_id")) if "team_id" in h else h.player_id
		if p_team == win_team:
			h.action = "hurrah"
			h.set_bomber_state(CGOBomberBaseClass.STATE_HEDGEHOG_HURRAH, true, true)
		else:
			h.action = "cry"
			h.set_bomber_state(CGOBomberBaseClass.STATE_HEDGEHOG_CRY, true, true)
		h._update_visuals()
