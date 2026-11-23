# Task 13: Monster Arena / StageClear NPCs & Bosses (`CMonsterComponent`, `CStageClearComponent`, `CGONpc*`)

## Goal
Port the Monster Arena (`CMonsterComponent` @ `0xe412e4`) and StageClear (`CStageClearComponent` @ `0xe3e894`) NPC/Monster/Boss runtime so all `Mon*` / `Boss` maps parse their existing `map.json["script_xml"]` (`<StageClearScript><ScriptObjects><ScriptObject><InitInfo .../>`) and spawn real Crazy Arcade monsters (tê tê/rùa, bạch tuộc, hải cẩu, sao biển, quái băng, robot, hồn ma Hải Tặc, trứng quái, Boss Rùa / Golem / PooPoo / Bầu khổng lồ...) using the **780 decoded sprite folders** already in `Client/Assets/fx/Monster/`.

## Current Status in Godot (`Client/`)
- **Not yet ported for Monster Arena / StageClear:**
  - Only 3 stub classes exist (`cgo_npc_basic_mon.gd`, `cgo_npc_attack_mon.gd`, `cgo_npc_mon_egg.gd`), hardcoded to `SM01`/`SM02`/`Egg` from `placed_monsters` (which is empty on `Mon*` maps).
  - `map_view.gd:21` currently sets `spawn_monsters_enabled := false`.
  - `map.json["script_xml"]` (`<StageClearScript>`, `18–25 KB` per `Mon*` map) is **not parsed yet**.
- **Assets already decoded and ready:**
  - **50 monster/boss families (780 folders)** in `Client/Assets/fx/Monster/`: `SM00..SM21` (22 tiểu yêu), `BM00..BM08` (9 Boss lớn), `AquaMon00`, `C14G-InOut`/`C14G-Walking` (Hồn ma Hải Tặc), `Blackrabbit`/`goldrabbit`/`rabbit`, `LargePooPoo`, `pumpkinBonus`, `MonSealBomb`, `Missile`, `RPG*`, `Z*` (Zombie).
  - **360 Monster/Boss maps** in `Client/Assets/fx/Map/` (`MonBig01..`, `MonGolem01..`, `IamBoss01..`, `BonusBigRPG01..`).

## Scope (IDA Addresses in `AnalizeVNClient/ca_unpacked.exe.i64`)
- **Mode Components:**
  - `CMonsterComponent` (`0xe412e4`) & `CStageClearComponent` (`0xe3e894`)
- **NPC / Monster Class Hierarchy (`CGONpcObject` @ `0xe23ffc`):**
  - Base: `CGONpcBasicMon` (`0xe23fdc`), `CGONpcAttackMon` (`0xe23fbc`), `CGONpcMonEgg` (`0xe414c0`)
  - Classic Monsters: `CGONpcTurtleMon` (`0xe41598`), `CGONpcSealMon` (`0xe4151c`), `CGONpcStarFishMon` (`0xe41558`), `CGONpcBounceMon` (`0xe413e0`), `CGONpcBlueMon` (`0xe413a4`), `CGONpcIceMon` (`0xe41440`), `CGONpcPudadakMon` (`0xe414dc`), `CGONpcSnowMon` (`0xe2406c`), `CGONpcSnowBearMon` (`0xe23f9c`), `CGONpcZzolmanMon` (`0xe3f4f8`), `CGONpcRobotMon` (`0xe414fc`), `CGONpcSmallRobot` (`0xe41538`), `CGONpcCaptainBomber` (`0xe23b98`), `CGONpcBombMissile` (`0xe413c0`)
  - Bosses: `CGONpcGolemMon` (`0xe41420`), `CGONpcMiniGolemMon` (`0xe4149c`), `CGONpcLargePooPoo` (`0xe4147c`), `CGONpcLargeGourd` (`0xe4145c`), `BossTurtle` (`BM00`..`BM08`)
  - Season 2 / RPG Monsters (`0xe43c2c..0xe43ce8`): `CGONpcMonSeason2BasicMon`, `Kuo`, `RKuo`, `MKuo`, `Riguner`, `SFlower`

## Recommended Sub-Phases
1. **Phase 13A (`/analyst` -> `/porter`): `StageClearScript` XML Parser & Monster Factory:**
   - Parse `<StageClearScript><ScriptObjects><ScriptObject><InitInfo .../>` from `map.json["script_xml"]` into pure `CStageClearScript` data (`type`, `image`, `hp`, `speed`, `pos`, `boss`, `skills`, `playTime`, `clearbonus`).
   - Map all `type` values across `Mon*` maps to their exact `Monster/*` sprite prefixes (`SM00..SM21`, `BM00..BM08`, `C14G`, `AquaMon00`, etc.).
2. **Phase 13B (`/porter`): Core Monster & Boss AI + `CMonsterComponent` / `CStageClearComponent`:**
   - Implement `CMonsterComponent` & `CStageClearComponent` (extends `CComponent`), enable monster spawning automatically in Monster/StageClear/RPG modes (instead of global `spawn_monsters_enabled := false`).
   - Support multi-HP Bosses with HP bar (`BM00_gagebar`), anger phase (`*_anger`), projectile attacks (`CGONpcBombMissile`), egg hatching (`CGONpcMonEgg`), and player-contact / flame-hit damage.
3. **Phase 13C (`/porter`): Special Monster Behaviors & Verification:**
   - Add specialized behaviors (Turtle/Armadillo shell roll, Ghost phase/teleport `C14G-InOut`, Golem roll, Seal bomb, Rabbit bonus).
   - Headless unit tests (`Client/tools/test_monster_arena.gd`) + `--write-movie` visual verification on `MonBig01` & `MonGolem01`.

## Allowed Files
- Spec: `docs/migration/specs/monster_arena_npcs.md` (+ mirror)
- New scripts: `Client/scripts/modes/c_stage_clear_script.gd`, `Client/scripts/modes/c_monster_component.gd`, `Client/scripts/objects/cgo_boss_mon.gd`
- Updated scripts: `Client/scripts/objects/cgo_npc_basic_mon.gd`, `Client/scripts/objects/cgo_npc_attack_mon.gd`, `Client/scripts/modes/c_component.gd`, `Client/scripts/map_view.gd`
- Tests: `Client/tools/test_monster_arena.gd`

## Acceptance Criteria
- Loading `MonBig01`, `MonGolem01`, and standard `Mon*` maps parses `script_xml` cleanly and spawns the exact monsters/bosses defined in the map.
- Monsters/bosses move, animate using `Assets/fx/Monster/*`, take flame damage, decrement HP, play death animations, and trigger stage clear when all required monsters/bosses are defeated.
- Classic PvP maps remain unaffected (0 monsters spawned unless the mode/map defines them).
- Headless tests + `--write-movie` visual check pass cleanly.
