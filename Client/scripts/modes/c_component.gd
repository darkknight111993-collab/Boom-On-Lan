class_name CComponent
extends RefCounted

## Common game mode component base class (CA.exe RTTI .?AVCComponent@@ @ 0xe239b0,
## ctor sub_73D1FF, GetType sub_73B7B1, GetGameStage sub_73B7B5).
## Mode-specific rules inherit from CComponent; mode-specific bomber state inherits
## from CGOGameBomber.

const CGOGameBomberClass = preload("res://scripts/objects/cgo_game_bomber.gd")

# Verified ComponentID values from CreateComponent factory (sub_73D4B0)
const MODE_DEFAULT := 0         # CDefaultComponent (0x7DF28E)
const MODE_KART := 1            # CKartComponent (0x74B358)
const MODE_BULA := 2            # CBulaComponent (0x742F22)
const MODE_RABBIT_CATCH := 4    # CRabbitCatchComponent (0x77CE74)
const MODE_WRIGGLE := 5         # CWriggleComponent (0x7A2B66)
const MODE_ZOMBIE := 6          # CZombieComponent (0x7A99A9)
const MODE_GOLD_FLAG := 7       # CGoldFlagComponent (0x7AC92F)
const MODE_CLOVER := 8          # CCloverComponent (0x7AD98D)
const MODE_SURVIVAL := 10       # CSurvivalComponent (0x74C35C)
const MODE_HEDGEHOG := 11       # CHedgehogComponent (0x74900D)
const MODE_CAPTAIN := 12        # CCaptainComponent (0x748885)
const MODE_TIMEBOMB := 13       # CTimebombComponent (0x74D842)
const MODE_STAGE_CLEAR := 14    # CStageClearComponent (0x755F54)
const MODE_TUTORIAL := 15       # CTutorialComponent (0x79CC1D)
const MODE_AI_BATTLE := 16      # CAIBattleComponent (0x785845)
const MODE_RPG := 17            # CRPGComponent (0x7B3248)
const MODE_SUPER_FIGHTER := 18  # CSuperFighterComponent (0x7B91ED)
const MODE_ZZOLMAN := 19        # CZzolmanComponent (0x7BCF8A)
const MODE_SNOWBALL := 20       # CSnowBallFightComponent (0x7D1994)
const MODE_SUPER_FIGHTER2 := 21 # CSuperFighterComponent2 (0x7D3282)
const MODE_MON_SEASON2 := 22    # CMonSeason2Component (0x7DB11E)
const MODE_CONFUSED_FIGHT := 23 # CConfusedFightComponent (0x7DDE31)
const MODE_FIGHTER_LEGEND := 26 # CFighterOfLegendComponent (0x489E65)
const MODE_IAM_BOSS := 27       # CIamBossComponent (0x4A962B)
const MODE_NPC_CAPTAIN := 30    # CNpcCaptainComponent (0x441F7F)
const MODE_AI_BATTLE2 := 32     # CAIBattleComponent variant 2 (0x785845)
const MODE_SNOW_BEAR := 33      # CSnowBearComponent (0x44A063)

var component_id: int = MODE_DEFAULT # this[4] (sub_73B7B1)
var stage: Node = null               # this[13] (sub_73B7B5)

func _init(p_component_id: int = MODE_DEFAULT, p_stage: Node = null) -> void:
	component_id = p_component_id
	stage = p_stage

func get_type() -> int:
	# From sub_73B7B1
	return component_id

func get_game_stage() -> Node:
	# From sub_73B7B5
	return stage

func create_bomber() -> Node:
	return CGOGameBomberClass.new()

func on_match_start(_players: Array) -> void:
	pass

func on_tick(_players: Array) -> void:
	pass

func on_player_hit_by_flame(_bomber: Node) -> bool:
	return false

func on_player_popped(_bomber: Node) -> bool:
	return false

func on_match_end(_players: Array, _win_team: int) -> void:
	pass

static func create_for_mode(mode_id: int, p_stage: Node = null) -> CComponent:
	# From sub_73D4B0 (CreateComponent factory)
	match mode_id:
		MODE_HEDGEHOG:
			var hc = load("res://scripts/modes/c_hedgehog_component.gd").new(p_stage)
			return hc
		MODE_STAGE_CLEAR, MODE_RPG, MODE_MON_SEASON2, MODE_IAM_BOSS, MODE_WRIGGLE, MODE_RABBIT_CATCH, MODE_ZZOLMAN, MODE_SNOW_BEAR:
			var mc = load("res://scripts/modes/c_monster_component.gd").new(mode_id, p_stage)
			return mc
		_:
			var dc = load("res://scripts/modes/c_default_component.gd").new(p_stage)
			return dc
