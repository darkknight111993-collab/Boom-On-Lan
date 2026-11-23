# Monster Arena / StageClear NPCs, Script Engine & AI (`CMonsterComponent`, `CStageClearComponent`, `CGONpc*`, `CPatternHandler*`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + 444 maps containing `<StageClearScript>` in `Client/Assets/fx/Map/*/map.json` + 780 sprite folders in `Client/Assets/fx/Monster/`.
> **Key discovery:** All 48 Crazy Arcade monster & boss types share a single data-driven **`StageClearScript` XML state machine** (`<InitInfo>`, `<TriggerTable>`, `<ActionList>`, `<Action>`) paired with **6 concrete `CPatternHandler*` AI movement classes** (`0x774171` / `0x7A78DA`).

## Behavior summary
1. **Master Monster Type Registry (`sub_C0789B` @ `0xC0789B`):** Registers 48 `<InitInfo type="...">` strings to integer `NpcType` IDs (`2..51`), covering all Classic, StageClear, Boss, and Season 2 monsters (`basicmon=5`, `icemon=6`, `eggmon=7`, `pudadakmon=8`, `bossmon1=4`, `bossmon2=9`, `smallrobot/bossrobot=13`, `bombmissile=15`, `wrigglemon=17`, `starfishmon=20`, `bossturtle=21`, `bluemon=23`, `bossgolem=24`, `bossgolem2=25`, `minigolem=27`, `pebblegolem=29`, `zzolman=30`, `largegourd=32`, `largepoopoo=33`, `lodumanimon=35`, `mon2ndkuo..mon2ndsandking=36..44`, `bouncemon=45`, `sharkmon=46`, `goldenbonusmon=47`, `snowbear=48`, `pebblesnow=50`).
2. **XML Script Parser (`sub_49C43B` @ `0x49C43B`, `sub_49908A` @ `0x49908A`, `sub_497A42` @ `0x497A42`):**
   - Each map's `map.json["script_xml"]` contains `<mapscriptoption>` (`playTime`, `bgm`, `clearbonus01..04`) and `<StageClearScript><ScriptObjects><ScriptObject>` blocks.
   - Each `<ScriptObject>` has:
     - `<InitInfo>`: `type`, `image`, `pos="x,y"`, `fromStart`, `class`, `boss`, `life="max=20,anger=7,gagebar=1"`, `CollisionSize`, `CollisionAttr="user=1,bomb=1,flames=1"`, `passType="Box=0,static=1,bomb=0"`, `lucci`.
     - `<TriggerTable><Time until="ms"><Trigger type="..." ActionList="id"/></Time></TriggerTable>`: maps 29 event triggers (`sub_497A42`: `default=0`, `selflocked=1`, `locked=2`, `bomberlocked=3`, `selfdie=4`, `die=5`, `bomberdie=6`, `bosslocked=7`, `bossdamaged=8`, `bossanger=9`, `monhpchanged=10`, `failaction=11`, `selfreleased=12`, `released=13`, `bomberreleased=14`, `selfdamaged=15`, `damaged=16`, `bomberdamaged=17`, `firstmondie=18`, `lastmonleft=19`, `createdefault=20`, `combine=21`, `transform=22`, `bossin=23`, `approach=24`, `appear=25`, `classalldie=26`, `puzzlebox=27`, `itemmeetthecondition=28`) to `<ActionList>` IDs.
     - `<ActionList name="id" next="next_id">`: ordered sequence of `<Action name="...">` commands (`sub_49908A`: `none=0`, `move=1`, `wait=4`, `turn=6`, `setstate=7`, `attack=8`, `pattern=9`, `createobj=10`, `playanim=11`, `orderscript=12`, `settriggeroption=13`, `destroystaticbox=14`, `changebgm=15`, `ai=16`, plus script aliases `appear`, `disappear`, `transfer`, `say`, `suicide`, `destroybox`, `destroypassable`).
3. **6 Unified `CPatternHandler*` AI Movement Behaviors (`sub_7748EF` @ `0x7748EF` -> `sub_774171` @ `0x774171`; Season 2 `sub_7A6DE2` -> `sub_7A78DA`):**
   - `<action name="pattern" func="line|free" event="none|chase|avoid|defense|monchase" duration="min~max" wait="ms" think="0|1" userdist="..." defenserange="..."/>`
   - **Base movement (`func`):**
     - `1` = `CPatternHandlerLine` (`0x778F21` / `Execute` `0x778FB9`): walks straight until next tile in current dir (`0=Up, 1=Left, 2=Down, 3=Right`) is blocked (`sub_778043`), then picks a new open direction (`sub_77818C`).
     - `2` = `CPatternHandlerFree` (`0x778CE4` / `Execute` `0x778D84`): walks until blocked OR until the count of open 4-way neighbors (`v8`) changes (entering a junction/intersection), then picks a new open direction (`sub_77818C`).
   - **Event override (`event`):**
     - `3` = `CPatternHandlerChase` (`0x7786B8` / `Execute` `0x778849`): scans alive players; if on same cell and pixel delta `> 10 px`, turns directly toward player; otherwise steers toward nearest player within `userdist` (`sub_77872C`).
     - `4` = `CPatternHandlerAvoid` (`0x7782A8` / `Execute` `0x778592`): collects all alive, non-trapped players' cells, scores all 4 neighbor directions (`sub_778365`), and picks the direction maximizing distance away from players (`sub_7784A8`).
     - `5` = `CPatternHandlerDefense` (`0x778A11` / `Execute` `0x778BB5`): keeps moving if next cell stays inside `defenserange` rect (`sub_778AE4`); otherwise picks randomly among all directions that remain inside `defenserange`.
     - `6` = `CPatternHandlerMonChase` (`0x7790CD` / `Execute` `0x77925E`): same as `Chase` but targets other alive `CGONpcBasicMon` instances (excluding self ID).

## Class / state (original class -> Godot class)

### 1. `CStageClearScript` (`sub_49C43B`, `sub_49908A`, `sub_497A42`) -> `Client/scripts/modes/c_stage_clear_script.gd` (`extends RefCounted`)
- Parses `map.json["script_xml"]` into:
  - `options: Dictionary` (`play_time_ms`, `bgm`, `clear_bonuses`)
  - `objects: Array[Dictionary]` (each with `init_info`, `triggers`, `action_lists`)
- Helper `parse_life_attr("max=20,anger=7,gagebar=1") -> Dictionary` (`max_hp`, `anger_hp`, `show_gagebar`)
- Helper `parse_pass_type("Box=0,static=1,bomb=0") -> Dictionary` (`pass_box`, `pass_static`, `pass_bomb`)
- Helper `parse_duration_range("2000~4000") -> Vector2i` (`0x774989` `"%u~%u"`)

### 2. `CPatternHandler` (`0x774171` / `0x7782A8..0x77925E`) -> `Client/scripts/objects/c_pattern_handler.gd` (`extends RefCounted`)
- Implements all 6 exact decision algorithms: `step_line()`, `step_free()`, `step_chase()`, `step_avoid()`, `step_defense()`, `step_mon_chase()`.
- Grid direction convention in `0x778FB9` / `0x778D84`: `0 = Up (0,-1)`, `1 = Left (-1,0)`, `2 = Down (0,+1)`, `3 = Right (+1,0)` (mapped to `CGOBomber` dir `0=D,1=U,2=L,3=R`).

### 3. `CMonsterComponent` (`0xe412e4`) & `CStageClearComponent` (`0xe3e894`) -> `Client/scripts/modes/c_monster_component.gd` (`extends CComponent`)
- Reads `CStageClearScript` on map load, spawns all `fromStart="1"` monsters/bosses automatically (replacing the disabled `spawn_monsters_enabled := false` flag for Monster/StageClear maps).
- Dispatches global triggers (`firstmondie`, `lastmonleft`, `classalldie`, `bossanger`, `bossdamaged`, `bomberdie`, `bomberlocked`) and evaluates stage-clear win condition when all required monsters/bosses are dead.

### 4. `CGONpcMonster` (`CGONpcBasicMon` `0xe23fdc`, `CGONpcAttackMon` `0xe23fbc`, `CGONpcBossMon` `BM00..BM08`) -> `Client/scripts/objects/cgo_npc_basic_mon.gd` + `cgo_boss_mon.gd`
- Executes `<ActionList>` (`wait`, `setstate`, `pattern`, `move`, `attack`, `createobj`, `appear`/`disappear`, `transfer`, `say`, `playanim`, `suicide`).
- Multi-HP Boss support (`max_hp`, `anger_hp` triggering `bossanger`, optional HP bar `BM00_gagebar`, multi-tile `CollisionSize` & `firePos` bomb/missile attacks).

## Formulas and constants (with addresses)
- **Pattern duration range (`0x774989`):** `sscanf(str, "%u~%u", &min_ms, &max_ms)`; if only 1 number is present, `max_ms = min_ms`.
- **Default AI config (`0x774c03..0x774c31`):** `v26 = [0, 10, 12, 2, 11, 1, think]` (default `think = 1`).
- **Same-cell chase pixel deadzone (`0x778936`, `0x7793ca`):** `abs(mon_px - target_px) > 10` before steering horizontally/vertically on the same tile.
- **Boss anger threshold (`<InitInfo life="max=20,anger=7,gagebar=1"/>`):** triggers `bossanger (9)` when `hp <= anger_hp`.

## Test vectors (code-evidence)
- **TV-MN1 (`CStageClearScript` XML parse, `0x49C43B`/`0x49908A`/`0x497A42`):** parsing `MonBig01/map.json["script_xml"]` extracts `BossTurtle` at `(3,5)` with `max_hp=20, anger_hp=7, gagebar=1`, trigger `Default->1`, `SelfLocked->101`, `BossAnger->109`, and `ActionList "1"` containing `wait(2000)`, `SetState(speed=4)`, `pattern(func=free, duration=3000)`, `CreateObj(class=101)`.
- **TV-MN2 (`CPatternHandlerLine` `0x778FB9`):** keeps moving straight when next cell is walkable; picks a new open direction when blocked.
- **TV-MN3 (`CPatternHandlerFree` `0x778D84`):** turns when blocked AND re-evaluates direction when open-neighbor count `v8` changes at a junction.
- **TV-MN4 (`CPatternHandlerChase` `0x778849` & `Avoid` `0x778592`):** `Chase` steers toward player within `userdist` (and uses `>10px` deadzone on same tile); `Avoid` picks the neighbor maximizing distance from alive players.
- **TV-MN5 (`CPatternHandlerDefense` `0x778BB5`):** stays inside `defenserange` rect and rebounds randomly when approaching the boundary.
- **TV-MN6 (`CMonsterComponent` trigger & win flow):** damaging a Boss from `hp=8` to `hp=7` (`<= anger_hp`) fires `bossanger`; killing all required monsters triggers stage clear.

## Special `CNpcCollideStrategy` Overrides (`0xC576DC..0xC5795C`)
All 19 `CNpcCollideStrategy` vtables sit contiguously at `0xC576DC..0xC5795C` (7 virtuals each: `[0]` dtor, `[1..2]` base hooks, `[3]` bomber/hitbox skip check, `[4]` bomb/secondary check, `[5]` projectile/state flag, `[6]` monster-vs-monster hook):
- **`CIceMonCollider` (`0xC5773C`, `0x73FB58`):** skips collision (`*out=1, return 0`) when `GetState()` (`vtable+88`) is in `{19, 22, 23}` (frozen/shell states) or `!sub_763E13(mon, cur_time)`.
- **`CStarFishMonCollider` (`0xC577BC`, `0x73FE6B` / `0x73F353`):** skips collision in kick/spin states `{18, 19, 20, 21}` or `!sub_767DD6(mon, cur_time)`; `[5]` (`0x73F353`) reports kicked-slide flag via `sub_766981`.
- **`CSnowBearMonCollider` (`0xC577FC`, `0x73F431`):** returns `0` when `GetState() <= 36`; delegates to `vtable+424` when `GetState() > 36` (charge/snowball state).
- **`CBounceMonCollider` (`0xC5781C`, `0x7400F6` / `0x73F4B2`):** skips collision while airborne/bouncing in states `{14, 15, 16, 17}` or `!sub_761AA8(mon, cur_time)`; `[5]` (`0x73F4B2`) reports bounce state via `sub_7606DD`.
- **`CLargePooPooCollider` (`0xC5785C`, `0x73F595`..`0x73F5D5`):** `[3]` (`0x73F595`) unconditionally skips standard bomber bump (`*out=1, return 0`), routing hits through custom boss handlers.
- **`CMiniGolemCollider` (`0xC5787C`, `0x73F66F`):** skips standard collision when `NpcType == 26` (`sub_8886E2(mon) == 26`, rolling variant) and `!sub_8DAF28()`.

## Functions covered (address list)
- `0xC0789B` (48-entry `NpcType` string->int registry)
- `0x49C43B`, `0x49908A`, `0x497A42` (`StageClearScript` parser, Action ID table, Trigger ID table)
- `0x7748EF`, `0x774171`, `0x7A6DE2`, `0x7A78DA` (Classic & Season 2 `CPatternHandler` factories)
- `0x777E37`, `0x778F21`, `0x778FB9`, `0x778CE4`, `0x778D84`, `0x7786B8`, `0x778849`, `0x7782A8`, `0x778592`, `0x778A11`, `0x778BB5`, `0x7790CD`, `0x77925E` (all 6 `CPatternHandler*` AI classes)
- `0x73FB58`, `0x73FE6B`, `0x73F353`, `0x73F431`, `0x7400F6`, `0x73F4B2`, `0x73F595`, `0x73F66F` (all 6 specialized `CNpcCollideStrategy` overrides @ `0xC576DC..0xC5795C`)

## `MapScriptTemplate` External Templates (`0xc1e6bc`)
- **Location:** `Client/Assets/fx/MapScriptTemplate/<template_name>/data.xml` (407 decoded XML templates: **44 `MonInfo_*`** + **363 `MonAction_*`**).
- **Resolution rule:** `<ScriptObjectTemplate monInfo="MapScriptTemplate/<info>" monAction="MapScriptTemplate/<action>">` loads:
  1. `res://Assets/fx/<monInfo>/data.xml` (`<MonsterInfo><InitInfo .../></MonsterInfo>`), then merges attribute overrides from `<OverrideInitInfo .../>` on top (case-insensitive keys, e.g. `pos`, `class`, `fromStart`, `life`).
  2. `res://Assets/fx/<monAction>/data.xml` (`<MonAction><TriggerTable>...</TriggerTable><ActionList ...>...</ActionList></MonAction>`), including Season 2 actions `createmonmissile` (`missiletype`, `angle`, `damage`, `speed`, `maxmovelen`) and `specialattack`.
- **Season 2 Sprites & Missiles:** Live in `Client/Assets/fx/MonsterSeason2/` (240 folders: `M_Sancho_*`, `M_Kuo_*`, `M_RKuo_*`, `M_MKuo_*`, `M_Monkey_*`, `M_Riguner_*`, `M_Sflower_*`, `BM08_*`, `BM09_*`, and `Bomb_M_Missile00..06` incl. 12-angle `Bomb_M_Missile05_00..11`).

## UNKNOWN
- None (all Monster Arena / StageClear / Season 2 templates, AI patterns, collide strategies, and sprites are resolved).
