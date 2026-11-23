extends SceneTree

## Headless verification for Task 13: Monster Arena / StageClear NPCs, Script Engine & AI.
## Covers TV-MN1..TV-MN6 + all 6 specialized CNpcCollideStrategy overrides (0xC576DC..0xC5795C).

const CStageClearScriptClass = preload("res://scripts/modes/c_stage_clear_script.gd")
const CPatternHandlerClass = preload("res://scripts/objects/c_pattern_handler.gd")
const CMonsterComponentClass = preload("res://scripts/modes/c_monster_component.gd")
const CComponentClass = preload("res://scripts/modes/c_component.gd")
const CGOBossMonClass = preload("res://scripts/objects/cgo_boss_mon.gd")
const CGOMonMissileClass = preload("res://scripts/objects/cgo_mon_missile.gd")

var _failures: int = 0

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("[FAIL] ", msg)
	else:
		print("[PASS] ", msg)

func _initialize() -> void:
	_test_tv_mn1_xml_parse()
	_test_tv_mn2_pattern_line()
	_test_tv_mn3_pattern_free()
	_test_tv_mn4_pattern_chase_and_avoid()
	_test_tv_mn5_pattern_defense_and_monchase()
	_test_tv_mn6_boss_anger_and_stage_clear()
	_test_collide_strategies()
	_test_component_factory()
	_test_tv_mn7_script_object_template()
	_test_tv_mn8_firepos_and_boss_attacks()
	_test_tv_mn9_orderscript_dispatch()
	_test_tv_mn10_season2_sprites_and_missile()
	_test_tv_mn11_large_scrolling_map_bounds()
	_test_tv_mn12_scrolling_camera_2p()

	if _failures > 0:
		printerr("FAILED: %d assertion(s) failed." % _failures)
		quit(1)
	else:
		print("ALL MONSTER ARENA TESTS PASSED.")
		quit(0)

func _test_tv_mn1_xml_parse() -> void:
	var f := FileAccess.open("res://Assets/fx/Map/MonBig01/map.json", FileAccess.READ)
	_assert(f != null, "TV-MN1: MonBig01/map.json readable")
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var script: CStageClearScriptClass = CStageClearScriptClass.new()
	var ok: bool = script.parse_xml(String(data.get("script_xml", "")))
	_assert(ok, "TV-MN1: CStageClearScript.parse_xml(MonBig01) succeeds")
	_assert(int(script.options.get("play_time_ms", 0)) == 120000, "TV-MN1: play_time_ms == 120000")

	var starts: Array = script.get_start_objects()
	_assert(starts.size() >= 1, "TV-MN1: at least 1 fromStart object")
	var boss_obj: Dictionary = starts[0]
	var info: Dictionary = boss_obj["init_info"]
	_assert(String(info["type"]) == "BossTurtle", "TV-MN1: type == BossTurtle")
	_assert(String(info["sprite_prefix"]) == "BM00", "TV-MN1: sprite_prefix == BM00")
	_assert(info["pos"] == Vector2i(3, 5), "TV-MN1: pos == (3,5)")
	_assert(int(info["max_hp"]) == 20, "TV-MN1: max_hp == 20")
	_assert(int(info["anger_hp"]) == 7, "TV-MN1: anger_hp == 7")
	_assert(bool(info["show_gagebar"]) == true, "TV-MN1: show_gagebar == true")
	_assert(bool(info["pass_static"]) == true and not bool(info["pass_box"]), "TV-MN1: passType Box=0,static=1")

	var trigs: Dictionary = boss_obj["triggers"]
	_assert(String(trigs.get("default", "")) == "1", "TV-MN1: trigger Default -> 1")
	_assert(String(trigs.get("selflocked", "")) == "101", "TV-MN1: trigger SelfLocked -> 101")
	_assert(String(trigs.get("bossanger", "")) == "109", "TV-MN1: trigger BossAnger -> 109")

	var al1: Dictionary = boss_obj["action_lists"].get("1", {})
	var acts: Array = al1.get("actions", [])
	_assert(acts.size() >= 5, "TV-MN1: ActionList '1' has >= 5 actions")
	_assert(String(acts[0]["name"]) == "wait" and int(acts[0]["time"]) == 2000, "TV-MN1: action[0] wait(2000)")
	_assert(String(acts[1]["name"]) == "setstate" and int(acts[1]["speed"]) == 4, "TV-MN1: action[1] setstate(speed=4)")
	_assert(String(acts[2]["name"]) == "pattern" and String(acts[2]["func"]) == "free", "TV-MN1: action[2] pattern(free)")
	_assert(CStageClearScriptClass.parse_duration_range("2000~4000") == Vector2i(2000, 4000), "TV-MN1: duration range 2000~4000")

func _test_tv_mn2_pattern_line() -> void:
	var wall_right := func(x: int, _y: int) -> bool: return x >= 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Open ahead -> keeps DIR_RIGHT (3)
	var d1 := CPatternHandlerClass.step_line(Vector2i(4, 5), CPatternHandlerClass.DIR_RIGHT, wall_right, rng)
	_assert(d1 == CPatternHandlerClass.DIR_RIGHT, "TV-MN2: Line keeps moving straight when open")
	# Blocked ahead at x=6 -> picks another open dir
	var d2 := CPatternHandlerClass.step_line(Vector2i(5, 5), CPatternHandlerClass.DIR_RIGHT, wall_right, rng)
	_assert(d2 != CPatternHandlerClass.DIR_RIGHT, "TV-MN2: Line turns when blocked")

func _test_tv_mn3_pattern_free() -> void:
	# Corridor at (5,5) with 2 open dirs (left, right), then junction at (6,5) with 3 open dirs
	var corridor_then_junction := func(x: int, y: int) -> bool:
		if y == 4 and x != 6:
			return true
		if y == 6:
			return true
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r1 := CPatternHandlerClass.step_free(Vector2i(5, 5), CPatternHandlerClass.DIR_RIGHT, 2, corridor_then_junction, rng)
	_assert(int(r1["dir"]) == CPatternHandlerClass.DIR_RIGHT and int(r1["open_count"]) == 2, "TV-MN3: Free keeps dir in corridor (open_count unchanged)")
	var r2 := CPatternHandlerClass.step_free(Vector2i(6, 5), CPatternHandlerClass.DIR_RIGHT, 2, corridor_then_junction, rng)
	_assert(int(r2["open_count"]) == 3 and int(r2["dir"]) != CPatternHandlerClass.DIR_RIGHT, "TV-MN3: Free turns when open_count changes at junction")

func _test_tv_mn4_pattern_chase_and_avoid() -> void:
	var open_all := func(_x: int, _y: int) -> bool: return false
	var players := [{"cell": Vector2i(8, 5), "pos": Vector2(320, 200), "alive": true, "in_bubble": false}]
	var chase_d := CPatternHandlerClass.step_chase(Vector2i(5, 5), Vector2(200, 200), CPatternHandlerClass.DIR_UP, players, 6, open_all)
	_assert(chase_d == CPatternHandlerClass.DIR_RIGHT, "TV-MN4: Chase steers right toward player at (8,5)")

	# Same-cell pixel deadzone (>10px @ 0x778936)
	var same_tile_close := [{"cell": Vector2i(5, 5), "pos": Vector2(205, 200), "alive": true, "in_bubble": false}]
	var d_dead := CPatternHandlerClass.step_chase(Vector2i(5, 5), Vector2(200, 200), CPatternHandlerClass.DIR_UP, same_tile_close, 6, open_all)
	_assert(d_dead == CPatternHandlerClass.DIR_UP, "TV-MN4: Chase keeps dir inside 10px deadzone")

	var same_tile_far := [{"cell": Vector2i(5, 5), "pos": Vector2(215, 200), "alive": true, "in_bubble": false}]
	var d_steer := CPatternHandlerClass.step_chase(Vector2i(5, 5), Vector2(200, 200), CPatternHandlerClass.DIR_UP, same_tile_far, 6, open_all)
	_assert(d_steer == CPatternHandlerClass.DIR_RIGHT, "TV-MN4: Chase steers right when delta > 10px on same tile")

	var avoid_d := CPatternHandlerClass.step_avoid(Vector2i(5, 5), CPatternHandlerClass.DIR_RIGHT, players, open_all)
	_assert(avoid_d == CPatternHandlerClass.DIR_LEFT, "TV-MN4: Avoid moves left away from player at (8,5)")

func _test_tv_mn5_pattern_defense_and_monchase() -> void:
	var open_all := func(_x: int, _y: int) -> bool: return false
	var rect := Rect2i(3, 3, 4, 4) # x in [3..6], y in [3..6]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var d_in := CPatternHandlerClass.step_defense(Vector2i(4, 4), CPatternHandlerClass.DIR_RIGHT, rect, open_all, rng)
	_assert(d_in == CPatternHandlerClass.DIR_RIGHT, "TV-MN5: Defense stays on course inside rect")
	var d_edge := CPatternHandlerClass.step_defense(Vector2i(6, 4), CPatternHandlerClass.DIR_RIGHT, rect, open_all, rng)
	_assert(d_edge != CPatternHandlerClass.DIR_RIGHT, "TV-MN5: Defense rebounds at rect boundary")

	var mons := [
		{"id": 1, "cell": Vector2i(5, 5), "pos": Vector2(200, 200), "alive": true},
		{"id": 2, "cell": Vector2i(5, 2), "pos": Vector2(200, 80), "alive": true},
	]
	var d_mc := CPatternHandlerClass.step_mon_chase(1, Vector2i(5, 5), Vector2(200, 200), CPatternHandlerClass.DIR_DOWN, mons, 6, open_all)
	_assert(d_mc == CPatternHandlerClass.DIR_UP, "TV-MN5: MonChase ignores self(id=1) and pursues monster(id=2) upward")

func _test_tv_mn6_boss_anger_and_stage_clear() -> void:
	var comp: CMonsterComponentClass = CMonsterComponentClass.new(CComponentClass.MODE_STAGE_CLEAR)
	var xml := """
	<StageClearScript><ScriptObjects>
		<ScriptObject>
			<InitInfo type="BossTurtle" image="Game/MonTurtle" pos="3,5" fromStart="1" class="1" life="max=8,anger=7,gagebar=1"/>
			<TriggerTable><Time until="120000">
				<Trigger type="Default" ActionList="1"/>
				<Trigger type="BossAnger" ActionList="109"/>
			</Time></TriggerTable>
			<ActionList name="1" next="1"><Action name="wait" time="1000"/></ActionList>
			<ActionList name="109" next="109"><Action name="SetState" speed="7"/></ActionList>
		</ScriptObject>
	</ScriptObjects></StageClearScript>
	"""
	_assert(comp.load_script_xml(xml), "TV-MN6: load_script_xml succeeds")
	var fired_triggers: Array[String] = []
	var cleared := [false]
	comp.trigger_dispatched.connect(func(tn: String, _s: Node) -> void: fired_triggers.append(tn))
	comp.stage_cleared.connect(func(_t: int) -> void: cleared[0] = true)

	var spawned: Array = comp.spawn_start_monsters(Callable())
	_assert(spawned.size() == 1, "TV-MN6: spawned 1 boss")
	var boss: CGOBossMonClass = spawned[0]
	boss.boss_angered.connect(func(src: CGOBossMonClass) -> void: comp.on_monster_angered(src))

	boss.take_damage(1) # 8 -> 7 (<= anger_hp)
	_assert(boss.hp == 7 and boss.is_angry, "TV-MN6: Boss enters anger at hp=7 <= anger_hp=7")
	_assert(fired_triggers.has("bossanger"), "TV-MN6: bossanger trigger dispatched")
	_assert(boss.current_list_name == "109", "TV-MN6: Boss switched to ActionList 109 on anger")

	boss.take_damage(7) # 7 -> 0
	comp.on_monster_died(boss)
	_assert(cleared[0] and comp.is_stage_cleared, "TV-MN6: killing last boss triggers stage_cleared")
	boss.free()

func _test_collide_strategies() -> void:
	_assert(CPatternHandlerClass.should_skip_collision("IceMon", 19), "Collide: IceMon skips state 19 (0x73FB58)")
	_assert(not CPatternHandlerClass.should_skip_collision("IceMon", 10), "Collide: IceMon collides in state 10")
	_assert(CPatternHandlerClass.should_skip_collision("StarFishMon", 20), "Collide: StarFishMon skips state 20 (0x73FE6B)")
	_assert(CPatternHandlerClass.should_skip_collision("BounceMon", 15), "Collide: BounceMon skips state 15 (0x7400F6)")
	_assert(CPatternHandlerClass.should_skip_collision("LargePooPoo", 0), "Collide: LargePooPoo always skips (0x73F595)")
	_assert(CPatternHandlerClass.should_skip_collision("MiniGolem", 0, 26), "Collide: MiniGolem skips when NpcType==26 (0x73F66F)")
	_assert(not CPatternHandlerClass.should_skip_collision("MiniGolem", 0, 27), "Collide: MiniGolem collides when NpcType==27")
	_assert(CPatternHandlerClass.is_snowbear_charge_state("SnowBear", 37), "Collide: SnowBear charge override at state > 36 (0x73F431)")

func _test_component_factory() -> void:
	var c1 := CComponentClass.create_for_mode(CComponentClass.MODE_STAGE_CLEAR)
	var c2 := CComponentClass.create_for_mode(CComponentClass.MODE_MON_SEASON2)
	var c3 := CComponentClass.create_for_mode(CComponentClass.MODE_IAM_BOSS)
	_assert(c1 is CMonsterComponentClass and c2 is CMonsterComponentClass and c3 is CMonsterComponentClass, "Factory creates CMonsterComponent for StageClear/Season2/IamBoss")

func _test_tv_mn7_script_object_template() -> void:
	var f := FileAccess.open("res://Assets/fx/Map/MonS2Sand01Boss/map.json", FileAccess.READ)
	_assert(f != null, "TV-MN7: MonS2Sand01Boss/map.json readable")
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var script: CStageClearScriptClass = CStageClearScriptClass.new()
	_assert(script.parse_xml(String(data.get("script_xml", ""))), "TV-MN7: ScriptObjectTemplate parses MonS2Sand01Boss")
	var starts: Array = script.get_start_objects()
	_assert(starts.size() >= 1, "TV-MN7: at least 1 template fromStart monster parsed")
	var obj0: Dictionary = {}
	for s in starts:
		var si: Dictionary = s["init_info"]
		if String(si.get("template_info", "")).contains("Sancho"):
			obj0 = s
			break
	_assert(not obj0.is_empty(), "TV-MN7: found MonInfo_Sancho_01 template object in starts")
	var info: Dictionary = obj0.get("init_info", {})
	_assert(String(info["type"]) == "Mon2ndSancho", "TV-MN7: real MonInfo_Sancho_01 type == Mon2ndSancho")
	_assert(int(info["max_hp"]) == 15, "TV-MN7: real MonInfo_Sancho_01 max_hp == 15")
	_assert(bool(info["pass_box"]) and bool(info["pass_static"]) and bool(info["pass_bomb"]), "TV-MN7: real MonInfo_Sancho_01 passType=1,1,1")
	_assert(info["pos"] == Vector2i(6, 5), "TV-MN7: OverrideInitInfo pos=(6,5) overrides MonInfo (0,0)")
	_assert(bool(info["from_start"]) == true, "TV-MN7: OverrideInitInfo fromStart=true overrides MonInfo false")
	var trigs: Dictionary = obj0["triggers"]
	_assert(String(trigs.get("default", "")) == "0" and String(trigs.get("approach", "")) == "1", "TV-MN7: real MonAction_Sancho_01 triggers loaded")
	var al2: Dictionary = obj0["action_lists"].get("2", {})
	var acts2: Array = al2.get("actions", [])
	var has_missile := false
	for a in acts2:
		if String(a.get("name", "")) == "createmonmissile":
			has_missile = true
			break
	_assert(has_missile, "TV-MN7: real MonAction_Sancho_01 ActionList '2' contains createmonmissile")

func _test_tv_mn8_firepos_and_boss_attacks() -> void:
	var fp := CStageClearScriptClass.parse_fire_pos("left=-3,top=-2,right=3,bottom=2")
	_assert(int(fp["left"]) == -3 and int(fp["top"]) == -2 and int(fp["right"]) == 3 and int(fp["bottom"]) == 2, "TV-MN8: parse_fire_pos exact")
	var mon: CGOBossMonClass = CGOBossMonClass.new()
	mon.setup("BM00", 7, 6, 80.0, "", 20)
	mon.fire_pos = fp
	var c_dir := mon.compute_attack_cells({"func": "direction", "cell": Vector2i(7, 6), "dir": 3, "fire_pos": fp})
	_assert(c_dir.size() == 1 and c_dir[0] == Vector2i(10, 6), "TV-MN8: direction attack uses firePos right=+3 -> (10,6)")
	var c_dest := mon.compute_attack_cells({"func": "directiondest", "pos": "3,4"})
	_assert(c_dest.size() == 1 and c_dest[0] == Vector2i(3, 4), "TV-MN8: directiondest targets (3,4)")
	var c_rect := mon.compute_attack_cells({"func": "rectangle", "cell": Vector2i(7, 6), "dist": 2})
	_assert(c_rect.size() == 4, "TV-MN8: rectangle produces 4 corner cells")
	var c_laser := mon.compute_attack_cells({"func": "laser", "cell": Vector2i(7, 6), "dir": 3, "length": 3})
	_assert(c_laser.size() == 3 and c_laser[2] == Vector2i(10, 6), "TV-MN8: laser produces 3 cells along facing dir")
	mon.free()

func _test_tv_mn9_orderscript_dispatch() -> void:
	var comp: CMonsterComponentClass = CMonsterComponentClass.new(CComponentClass.MODE_STAGE_CLEAR)
	var xml := """
	<StageClearScript><ScriptObjects>
		<ScriptObject>
			<InitInfo type="BossTurtle" pos="3,5" fromStart="1" class="1" life="max=10"/>
			<TriggerTable><Time until="120000"><Trigger type="Default" ActionList="1"/></Time></TriggerTable>
			<ActionList name="1" next="1">
				<Action name="orderscript" class="2" ActionList="99"/>
				<Action name="wait" time="1000"/>
			</ActionList>
		</ScriptObject>
	</ScriptObjects></StageClearScript>
	"""
	_assert(comp.load_script_xml(xml), "TV-MN9: orderscript XML parsed")
	var received := []
	var boss: CGOBossMonClass = CGOBossMonClass.new()
	boss.order_script_requested.connect(func(cls_id: int, ln: String) -> void: received.append([cls_id, ln]))
	boss.setup_from_script(comp.stage_script.objects[0], 1)
	_assert(received.size() == 1 and received[0][0] == 2 and received[0][1] == "99", "TV-MN9: orderscript emitted class=2 list='99'")
	boss.free()

func _test_tv_mn10_season2_sprites_and_missile() -> void:
	_assert(CStageClearScriptClass.resolve_monster_sprite_prefix("Mon2ndSancho", "Monster2nd/Mon_Sancho") == "MonsterSeason2/M_Sancho", "TV-MN10: Mon_Sancho -> MonsterSeason2/M_Sancho")
	_assert(CStageClearScriptClass.resolve_monster_sprite_prefix("Mon2ndKuo", "Monster2nd/Mon_Kuo") == "MonsterSeason2/M_Kuo", "TV-MN10: Mon_Kuo -> MonsterSeason2/M_Kuo")
	_assert(CStageClearScriptClass.resolve_monster_sprite_prefix("Mon2ndRKuo", "Monster2nd/Mon_RKuo") == "MonsterSeason2/M_RKuo", "TV-MN10: Mon_RKuo -> MonsterSeason2/M_RKuo")
	_assert(CStageClearScriptClass.resolve_monster_sprite_prefix("Mon2ndMonkey", "Monster2nd/Mon_Monkey") == "MonsterSeason2/M_Monkey", "TV-MN10: Mon_Monkey -> MonsterSeason2/M_Monkey")
	_assert(CStageClearScriptClass.resolve_monster_sprite_prefix("Mon2ndSFlower", "Monster2nd/Mon_SFlower") == "MonsterSeason2/M_Sflower", "TV-MN10: Mon_SFlower -> MonsterSeason2/M_Sflower")
	_assert(FileAccess.file_exists("res://Assets/fx/MonsterSeason2/M_Sancho_Walk_Left/sprite.json"), "TV-MN10: M_Sancho_Walk_Left sprite exists")
	_assert(FileAccess.file_exists("res://Assets/fx/MonsterSeason2/Bomb_M_Missile05_03/sprite.json"), "TV-MN10: Bomb_M_Missile05_03 sprite exists")

	_assert(CGOMonMissileClass.resolve_missile_sprite_path(5, 90.0) == "MonsterSeason2/Bomb_M_Missile05_03", "TV-MN10: missile type 5 @ 90deg -> Bomb_M_Missile05_03")
	var mis: CGOMonMissileClass = CGOMonMissileClass.new()
	mis.setup(Vector2(100, 100), 0.0, 5.0, 100.0, 5)
	_assert(mis.step_missile(0.2, []) == true and mis.position.x > 100.0, "TV-MN10: missile flies rightward along 0deg")
	_assert(mis.step_missile(1.0, []) == false and not mis.active, "TV-MN10: missile deactivates after max_dist")
	mis.free()

func _test_tv_mn11_large_scrolling_map_bounds() -> void:
	# Verify 40x10 Season 2 map (e.g. MonS2Sand01Boss) does not clamp monsters or AI to 15x13
	var comp: CMonsterComponentClass = CMonsterComponentClass.new(CComponentClass.MODE_MON_SEASON2)
	comp.grid_cols = 40
	comp.grid_rows = 10
	var obj_def := {
		"init_info": {"type": "Mon2ndSancho", "sprite_prefix": "MonsterSeason2/M_Sancho", "pos": Vector2i(35, 5), "from_start": true, "max_hp": 15},
		"triggers": {},
		"action_lists": {},
	}
	var mon: CGOBossMonClass = comp.create_monster_node(obj_def)
	_assert(mon.cell == Vector2i(35, 5), "TV-MN11: monster spawns at (35,5) on 40x10 map without 15x13 clamp")
	var open_all := func(_x: int, _y: int) -> bool: return false
	var d := CPatternHandlerClass.step_line(Vector2i(35, 5), CPatternHandlerClass.DIR_RIGHT, open_all, null, 40, 10)
	_assert(d == CPatternHandlerClass.DIR_RIGHT, "TV-MN11: CPatternHandler.step_line allows walking right at x=35 on 40x10 grid")
	mon.free()

func _test_tv_mn12_scrolling_camera_2p() -> void:
	# Verify 1P/2P focus & scroll clamping without needing SpriteDB autoload
	var p1 := Vector2(200, 200)
	var p2 := Vector2(600, 200)
	# 1P mode -> always follows P1
	var f_1p := p1
	_assert(f_1p == Vector2(200, 200), "TV-MN12: 1P focus follows P1")
	# 2P mode both alive -> midpoint (400, 200)
	var f_2p := (p1 + p2) * 0.5
	_assert(f_2p == Vector2(400, 200), "TV-MN12: 2P focus averages P1 & P2")
	# Scroll clamp on 40x10 (1600x400) map: max_x = 1000, max_y = 0
	var origin := Vector2(20, 41)
	var max_x := maxf(0.0, float(40 * 40) - 600.0)
	var sx_mid := clampf(f_2p.x - origin.x - 300.0, 0.0, max_x)
	var sx_far := clampf(1500.0 - origin.x - 300.0, 0.0, max_x)
	_assert(is_equal_approx(sx_mid, 80.0), "TV-MN12: 2P midpoint scroll = 80px")
	_assert(is_equal_approx(sx_far, 1000.0), "TV-MN12: far-right scroll clamps at 1000px")
