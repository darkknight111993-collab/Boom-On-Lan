extends SceneTree

const CComponentClass = preload("res://scripts/modes/c_component.gd")
const CDefaultComponentClass = preload("res://scripts/modes/c_default_component.gd")
const CHedgehogComponentClass = preload("res://scripts/modes/c_hedgehog_component.gd")
const CGOGameBomberClass = preload("res://scripts/objects/cgo_game_bomber.gd")
const CGOHedgehogBomberClass = preload("res://scripts/objects/cgo_hedgehog_bomber.gd")
const CGOBomberBaseClass = preload("res://scripts/objects/cgo_bomber_base.gd")

func _init() -> void:
	print("[TEST] Running Game Mode Component tests (TV-M1..TV-M5)...")

	# TV-M1: CComponent base & IDs (0x73D1FF / 0x73B7B1 / 0x74900D)
	var def_comp = CComponentClass.create_for_mode(CComponentClass.MODE_DEFAULT)
	var hh_comp = CComponentClass.create_for_mode(CComponentClass.MODE_HEDGEHOG)
	assert(def_comp is CDefaultComponentClass and def_comp is CComponentClass and def_comp is RefCounted, "TV-M1: CDefaultComponent hierarchy")
	assert(hh_comp is CHedgehogComponentClass and hh_comp is CComponentClass and hh_comp is RefCounted, "TV-M1: CHedgehogComponent hierarchy")
	assert(def_comp.get_type() == 0, "TV-M1: CDefaultComponent ID == 0")
	assert(hh_comp.get_type() == 11, "TV-M1: CHedgehogComponent ID == 11 (0x74900D)")
	print("  [PASS] TV-M1: CComponent hierarchy & factory IDs (0x73D4B0 / 0x73D1FF / 0x74900D)")

	# TV-M2: Bomber factory per mode
	var b_def = def_comp.create_bomber()
	var b_hh = hh_comp.create_bomber()
	assert(b_def is CGOGameBomberClass and not (b_def is CGOHedgehogBomberClass), "TV-M2: Default mode creates CGOGameBomber")
	assert(b_hh is CGOHedgehogBomberClass, "TV-M2: Hedgehog mode creates CGOHedgehogBomber")
	b_def.free()
	print("  [PASS] TV-M2: Bomber factory per mode")

	# TV-M3: CHedgehogComponent pop -> transform (0x749111 -> 0x74A11F) & flame -> stun (0x74A8D9)
	b_hh.apply_character_attr("C00")
	b_hh.alive = true
	b_hh.player_id = 0
	assert(hh_comp.on_player_popped(b_hh) == true, "TV-M3: pop transforms human to Hedgehog")
	assert(b_hh.is_hedgehog() == true and b_hh.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_DIE, "TV-M3: Hedgehog active in state 59")
	for _t in range(47):
		b_hh._on_tick()
	assert(b_hh.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_STOP_BASE + 3, "TV-M3: state 59 -> 70")
	assert(hh_comp.on_player_hit_by_flame(b_hh) == true, "TV-M3: flame stuns Hedgehog")
	assert(b_hh.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_FAINT, "TV-M3: enters state 60")
	print("  [PASS] TV-M3: CHedgehogComponent pop -> transform & flame -> stun (0x749111 / 0x74A11F / 0x74A8D9)")

	# TV-M4: CHedgehogComponent collision filter (0x7491D4 / 0x749824 / 0x749B1F)
	var victim = hh_comp.create_bomber()
	victim.apply_character_attr("C01")
	victim.alive = true
	victim.player_id = 1
	b_hh.set_cell(3, 3)
	victim.set_cell(3, 3)
	# While b_hh is stunned (state 60), must NOT collide
	assert(hh_comp.find_hedgehog_hits([b_hh, victim], [victim]).is_empty(), "TV-M4: stunned Hedgehog (state 60) must not collide")
	# Recover b_hh from stun (14 + 99 ticks)
	for _t in range(14 + 99):
		b_hh._on_tick()
	assert(b_hh.is_hedgehog_faint() == false, "TV-M4: b_hh recovered to idle")
	var hits: Array = hh_comp.find_hedgehog_hits([b_hh, victim], [victim])
	assert(hits.size() == 1 and hits[0][0] == b_hh and hits[0][1] == victim, "TV-M4: active Hedgehog detects overlapping target")
	print("  [PASS] TV-M4: CHedgehogComponent collision filter (0x7491D4 / 0x749824 / 0x749B1F)")

	# TV-M5: CHedgehogComponent::on_match_end (0x749159): win=61 (Hurrah), lose=62 (Cry)
	var loser = hh_comp.create_bomber()
	loser.apply_character_attr("C02")
	loser.alive = true
	loser.player_id = 2
	hh_comp.on_player_popped(loser)
	for _t in range(47):
		loser._on_tick()
	hh_comp.on_match_end([b_hh, victim, loser], 0)
	assert(b_hh.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_HURRAH, "TV-M5: winning Hedgehog -> state 61 (Hurrah)")
	assert(loser.cur_state_idx == CGOBomberBaseClass.STATE_HEDGEHOG_CRY, "TV-M5: losing Hedgehog -> state 62 (Cry)")
	assert(victim.is_hedgehog() == false and victim.cur_state_idx != CGOBomberBaseClass.STATE_HEDGEHOG_CRY, "TV-M5: human untouched")
	b_hh.free()
	victim.free()
	loser.free()
	print("  [PASS] TV-M5: CHedgehogComponent::on_match_end win=61 / lose=62 (0x749159)")

	print("[TEST] ALL GAME MODE COMPONENT TESTS PASSED!")
	quit(0)
