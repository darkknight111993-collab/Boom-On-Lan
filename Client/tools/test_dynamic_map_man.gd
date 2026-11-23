extends SceneTree

const CDynamicMapManClass = preload("res://scripts/modes/c_dynamic_map_man.gd")
const CComponentClass = preload("res://scripts/modes/c_component.gd")

func _init() -> void:
	print("[TEST] Running CDynamicMapMan tests (TV-DM1..TV-DM5)...")

	var mm := CDynamicMapManClass.new()
	assert(not mm.get_game_modes().is_empty(), "game_modes.json must load cleanly")

	# TV-DM1: Exact sub_6DD516 (0x6DD516) group_id +41 game-type rules
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(109, 18) == true, "group 109 allows SuperFighter (18)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(109, 21) == true, "group 109 allows SuperFighter2 (21)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(109, 0) == false, "group 109 blocks Default (0)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(112, 21) == true, "group 112 allows SuperFighter2 (21)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(112, 18, true) == true, "group 112 allows 18 when 21 enabled")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(112, 18, false) == false, "group 112 blocks 18 when 21 disabled")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(137, 27) == true, "group 137 allows IamBoss (27)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(137, 0) == false, "group 137 blocks Default (0)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(0, 27) == false, "IamBoss (27) blocks non-137 maps")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(238, 11) == false, "group 238 blocks Hedgehog (11)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(238, 0) == true, "group 238 allows Default (0)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(120, 16) == false, "group 120 blocks AI Battle (16)")
	assert(CDynamicMapManClass.is_map_allowed_for_game_type(106, 15) == false, "group 106 blocks Tutorial (15)")
	print("  [PASS] TV-DM1: IsMapAllowedForGameType group_id rules (0x6DD516)")

	# TV-DM2: Mode-specific map lists & alias resolution (hedgehog/stage_clear/ai_battle/superf2)
	var normal_maps: Array[String] = mm.get_maps(CComponentClass.MODE_DEFAULT)
	var hh_maps: Array[String] = mm.get_maps(CComponentClass.MODE_HEDGEHOG)
	var sc_maps: Array[String] = mm.get_maps(CComponentClass.MODE_STAGE_CLEAR)
	var ai_maps: Array[String] = mm.get_maps(CComponentClass.MODE_AI_BATTLE)
	var sf2_maps: Array[String] = mm.get_maps(CComponentClass.MODE_SUPER_FIGHTER2)
	assert(normal_maps.has("Camp08") and normal_maps.size() == 281, "MODE_DEFAULT uses clean classic normal pool (281), got %d" % normal_maps.size())
	assert(hh_maps.size() == 52 and mm.get_mode_name_vn("hedgehog") == "Chế độ Nhím", "MODE_HEDGEHOG uses gametype pool (52)")
	assert(sc_maps.size() == 289 and mm.get_mode_name_vn("stage_clear") == "Săn Quái", "MODE_STAGE_CLEAR uses monster2 pool (289)")
	assert(ai_maps.size() == 34 and mm.get_mode_name_vn("ai_battle") == "Đấu Máy", "MODE_AI_BATTLE uses battle pool (34)")
	assert(sf2_maps.size() == 40 and mm.get_mode_name_vn("super_fighter2") == "Super Fighter 2", "MODE_SUPER_FIGHTER2 uses superf2 pool (40)")
	print("  [PASS] TV-DM2: Mode-specific map lists & alias resolution")

	# TV-DM3: Ladder (case 4) & Practice (case 5) map_group.json filtering (0x6DEE48)
	var ladder_maps: Array[String] = mm.get_maps(CComponentClass.MODE_HEDGEHOG, "ladder")
	assert(ladder_maps.size() == 6 and ladder_maps.has("Camp08") and ladder_maps.has("Patrit14"), "Ladder strategy uses LadderMapGroup")
	var prac_maps: Array[String] = mm.get_maps(CComponentClass.MODE_DEFAULT, "normal", CDynamicMapManClass.MODE_FILTER_PRACTICE)
	assert(prac_maps.size() >= 30 and prac_maps.has("Village00"), "Practice filter uses PraticeMapGroup")
	print("  [PASS] TV-DM3: LadderMapGroup & PraticeMapGroup filtering (0x6DEE48)")

	# TV-DM4: Default map lookup
	assert(mm.get_default_map(CComponentClass.MODE_DEFAULT) == "Camp08", "Default map for MODE_DEFAULT is Camp08")
	assert(mm.get_default_map(CComponentClass.MODE_DEFAULT, "ladder") == "Camp08", "Default map for ladder is first LadderMapGroup entry")
	print("  [PASS] TV-DM4: Default map per component & strategy")

	# TV-DM5: MapSelect_PlayerLimitOver (0x68B85D) using real map.json spawns[] + override
	assert(mm.get_map_max_players("Camp08") == 8, "Camp08 has 8 spawns in map.json")
	assert(mm.get_map_max_players("Village10") == 6, "Village10 has 6 spawns in map.json")
	assert(mm.check_player_limit("Village10", 6)["ok"] == true, "6 players allowed on Village10")
	assert(mm.check_player_limit("Village10", 7)["ok"] == false, "7 players blocked on Village10 (6 spawns)")
	assert(mm.get_map_max_players("TestAirship01") == 2, "TestAirship01 uses map_meta override (2) from game_modes.json")
	assert(mm.check_player_limit("TestAirship01", 2)["ok"] == true, "map_meta limit 2 allows 2 players")
	assert(mm.check_player_limit("TestAirship01", 3)["ok"] == false, "map_meta limit 2 blocks 3 players")
	print("  [PASS] TV-DM5: MapSelect_PlayerLimitOver (0x68B85D) from map.json spawns[]")

	# TV-DM6: All 11 mode_filter cases (0..10) in is_map_selectable (0x6DEE48)
	var rec_normal := {"category_type": 0, "group_id": 0}
	var rec_mon := {"category_type": 6, "group_id": 0}
	var rec_cap := {"category_type": 12, "group_id": 0xF1}
	var rec_tb := {"category_type": 13, "group_id": 0xEF}
	var rec_boss := {"category_type": 24, "group_id": 0x89}
	var rec_hc := {"category_type": 29, "group_id": 0x92}
	var rec_ai_bad := {"category_type": 0, "group_id": 0, "ai_restrict": true}
	var rec_ai_ok := {"category_type": 3, "group_id": 0, "ai_restrict": true}
	assert(CDynamicMapManClass.is_map_selectable(rec_normal, 0, CDynamicMapManClass.MODE_FILTER_DEFAULT) == true, "case 0 allows normal")
	assert(CDynamicMapManClass.is_map_selectable(rec_mon, 0, CDynamicMapManClass.MODE_FILTER_DEFAULT) == false, "case 0 blocks monster")
	assert(CDynamicMapManClass.is_map_selectable(rec_mon, 14, CDynamicMapManClass.MODE_FILTER_MONSTER) == true, "case 3 allows monster")
	assert(CDynamicMapManClass.is_map_selectable(rec_mon, 14, CDynamicMapManClass.MODE_FILTER_MONSTER_FILTERED) == true, "case 4 allows non-random monster")
	assert(CDynamicMapManClass.is_map_selectable(rec_ai_bad, 16, CDynamicMapManClass.MODE_FILTER_AI_BATTLE) == false, "case 5 blocks ai_restrict when cat != 3")
	assert(CDynamicMapManClass.is_map_selectable(rec_ai_ok, 16, CDynamicMapManClass.MODE_FILTER_AI_BATTLE) == true, "case 5 allows ai_restrict when cat == 3")
	assert(CDynamicMapManClass.is_map_selectable(rec_ai_ok, 16, CDynamicMapManClass.MODE_FILTER_AI_BATTLE_NO_TEAM) == true, "case 9 AI variant allows cat == 3")
	assert(CDynamicMapManClass.is_map_selectable(rec_cap, 12, CDynamicMapManClass.MODE_FILTER_CAPTAIN_ZZOLMAN) == true, "case 6 allows Captain/Zzolman")
	assert(CDynamicMapManClass.is_map_selectable(rec_tb, 13, CDynamicMapManClass.MODE_FILTER_TIMEBOMB_SNOWBALL) == true, "case 7 allows Timebomb/SnowBall")
	assert(CDynamicMapManClass.is_map_selectable(rec_boss, 27, CDynamicMapManClass.MODE_FILTER_IAM_BOSS) == true, "case 8 allows IamBoss")
	assert(CDynamicMapManClass.is_map_selectable(rec_hc, 29, CDynamicMapManClass.MODE_FILTER_SPECIAL_HIDDEN) == true, "case 10 allows Special/HiddenCatch")
	print("  [PASS] TV-DM6: All 11 mode_filter cases (0..10, 0x6DEE48)")

	# TV-DM7: fxdynmapinfo.ssd player-limit byte decode (0x6E077C)
	var d1: Dictionary = CDynamicMapManClass.decode_player_limit_byte(18)
	assert(int(d1["max_players"]) == 8 and bool(d1["tier_flag"]) == true, "v27=18 -> max_players=8, tier_flag=true")
	var d2: Dictionary = CDynamicMapManClass.decode_player_limit_byte(4)
	assert(int(d2["max_players"]) == 4 and bool(d2["tier_flag"]) == false, "v27=4 -> max_players=4, tier_flag=false")
	print("  [PASS] TV-DM7: decode_player_limit_byte (0x6E077C)")

	# TV-DM8: ShowMapListAll (0x648EA4) splits classic vs extended_maps in normal
	assert(not normal_maps.has("Kart00") and not normal_maps.has("Bula01") and not normal_maps.has("Hidden01") and not normal_maps.has("ExCamp01"), "Default normal excludes Kart/Bula/Hidden/Ex")
	var normal_all: Array[String] = mm.get_maps(CComponentClass.MODE_DEFAULT, "normal", 0, true)
	assert(normal_all.size() == 390 and normal_all.has("ExCamp01") and normal_all.has("EventCamp00"), "show_all=true includes extended_maps (281+109=390), got %d" % normal_all.size())
	print("  [PASS] TV-DM8: ShowMapListAll classic vs extended_maps (0x648EA4)")

	# TV-DM9: Separated modes (kart/bula/hidden_catch/iam_boss) & gametype/25 aliases
	var kart_maps: Array[String] = mm.get_maps(CComponentClass.MODE_KART)
	var bula_maps: Array[String] = mm.get_maps(CComponentClass.MODE_BULA)
	var hc_maps: Array[String] = mm.get_maps(28)
	var boss_maps: Array[String] = mm.get_maps(CComponentClass.MODE_IAM_BOSS)
	var sfv_maps: Array[String] = mm.get_maps(25)
	assert(kart_maps.size() == 18 and bula_maps.size() == 24 and hc_maps.size() == 24 and boss_maps.size() == 8 and sfv_maps.size() == 40, "Separated mode pools exact counts")
	assert(preload("res://scripts/modes/c_lobby_flow.gd").mode_key_to_component_id("gametype") == CComponentClass.MODE_CAPTAIN, "gametype card fallback -> MODE_CAPTAIN (12)")
	print("  [PASS] TV-DM9: Separated Kart/Bula/HiddenCatch/IamBoss pools & gametype/25 links")

	# TV-DM10: Theme prefix filter (MapGroupVisible 0x6DBC56)
	var camp_only: Array[String] = mm.get_maps(CComponentClass.MODE_DEFAULT, "normal", 0, false, "Camp")
	assert(camp_only.size() == 15 and camp_only.has("Camp08") and not camp_only.has("Village10"), "Camp theme filter returns 15 Camp maps")
	var themes: Array[String] = CDynamicMapManClass.get_themes_for_maps(normal_maps)
	assert(themes.size() == 16 and themes.has("Camp") and themes.has("Village"), "Classic normal has 16 themes, got %d" % themes.size())
	print("  [PASS] TV-DM10: Theme prefix filtering (MapGroupVisible 0x6DBC56)")

	# TV-DM11: Vietnamese natural alphabetical map sorting (Đ near D, 2 before 10, case-insensitive)
	var sample := ["Camp10", "Camp02", "forest21", "Forest20", "Ladder01", "Village01"]
	var vn_names := {
		"Camp10": "Doanh trại 10",
		"Camp02": "Doanh trại 02",
		"Ladder01": "Đấu trường 01",
		"Village01": "Làng Boom 01",
		"Forest20": "Rừng rậm 20",
		"forest21": "Rừng rậm 21",
	}
	var sorted_vn: Array[String] = CDynamicMapManClass.sort_maps_by_name(sample, func(c: String) -> String: return str(vn_names.get(c, c)))
	assert(sorted_vn == ["Ladder01", "Camp02", "Camp10", "Village01", "Forest20", "forest21"], "VN natural sort order mismatch: %s" % str(sorted_vn))
	print("  [PASS] TV-DM11: Vietnamese natural alphabetical map sorting")

	print("[TEST] ALL CDYNAMICMAPMAN TESTS PASSED!")
	quit(0)
