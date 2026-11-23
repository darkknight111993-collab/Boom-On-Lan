# Game Mode Component System (`CComponent` -> `CDefaultComponent` / `CHedgehogComponent`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`).
> **Rule:** All game modes share ONE base class (`CComponent`, `0xe239b0`) owned by `CGameStage` (`std::list<CComponent*>` @ `this[5413]`). Mode-specific rules live in `C<Mode>Component` subclasses; mode-specific bomber state lives in `CGO<Mode>Bomber extends CGOGameBomber`.

## Behavior summary
1. **`CComponent`** (`0xe239b0`, ctor `0x73D1FF`) is the common base class for all ~30+ game modes. Each instance stores `component_id` (`this[4]`, getter `0x73B7B1`) and a back-pointer to `CGameStage` (`this[13]`, getter `0x73B7B5`).
2. **`CGameStage::GetComponent(id)`** (`0x70A304`) scans `this[5413]` and returns the active `CComponent*` matching `component_id`.
3. **5 horizontal `IComponentAddOn`s (`0x7BD32F`, attached via `CComponent::AddAddOn` @ `0x73CF68` into `this[5]` list, deduped by `AddOnID` via `0x73C38B`):**
   - `AddOnID = 1`: `CComponentAddOnAI` (`0x7CADEE`)
   - `AddOnID = 3`: `CComponentAddOnMonster` (`0x7BF16D`) — attached to `CDefaultComponent`, `CMonsterComponent`, `CZzolmanComponent`, `CSnowBallBonusComponent`, `CSnowBearComponent`
   - `AddOnID = 4`: `CComponentAddOnSkill` (`0x7C83DB`, registers 13 skills `0..12`, passed `a7 = 4` by `CRPGComponent` `0x7B3248`)
   - `AddOnID = 5`: `CComponentAddOnSpecialTile` (`0x485A26`) — attached to `CMonsterComponent`, `CSnowBearComponent`
   - `AddOnID = 6`: `CComponentAddOnRevival` (`0x7C0C5D`, revival countdown `15` @ `+68`) — attached to `CAIBattleComponent`, `CMonsterComponent`, `CSnowBearComponent`
4. **`CDefaultComponent`** (`0xe23990`, ctor `0x7DF28E`, ID `0`) implements standard Classic match rules using `CGOGameBomber` (and attaches `CComponentAddOnMonster` `0x7BF16D`).
5. **`CHedgehogComponent`** (`0xe40b00`, ctor `0x74900D`, `component_id = 11`) implements Hedgehog mode using `CGOHedgehogBomber`:
   - On player death (`0x749111`), looks up `bomber = sub_6E5C2B(stage, slot)` and calls `sub_74A11F(bomber)` (`CGOHedgehogBomber::transform_to_hedgehog()`) instead of eliminating them.
   - Each tick (`0x749342` -> `0x7491D4`), checks active Hedgehogs (`!is_hedgehog_faint()`, `0x749824`) against target hitboxes (`0x749B1F`) to pop/impact targets.
   - On match end (`0x749159`), sets winning-team Hedgehogs to state `61` (`Hedgehog-Hurrah`) and losing-team Hedgehogs to state `62` (`Hedgehog-Cry`).

## Class / state (original class -> Godot class)

### 1. `CComponent` (`0xe239b0`) -> `Client/scripts/modes/c_component.gd` (`RefCounted`)
- Original: ctor `0x73D1FF(this, component_id)`, `GetType()` `0x73B7B1` (`this[4]`), `GetGameStage()` `0x73B7B5` (`this[13]`).
- Godot fields & hooks (minimal complete interface, no unused abstractions):
  - `const MODE_DEFAULT := 0`
  - `const MODE_KART := 1` (`0x738547`)
  - `const MODE_HEDGEHOG := 11` (`0x749020`)
  - `const MODE_ZZOLMAN := 19` (`0x70b92a`)
  - `const MODE_SNOW_BEAR := 33` (`0x44992d`)
  - `var component_id: int = MODE_DEFAULT`
  - `var stage: Node = null` (back-reference to `map_view.gd`)
  - `func get_type() -> int` (`0x73B7B1`)
  - `func get_game_stage() -> Node` (`0x73B7B5`)
  - `func create_bomber() -> CGOGameBomber`: factory hook returning the bomber subclass for this mode (default: `CGOGameBomber.new()`).
  - `func on_match_start(_players: Array) -> void`
  - `func on_tick(_players: Array) -> void`
  - `func on_player_hit_by_flame(_bomber: CGOGameBomber) -> bool`: returns `true` if mode consumed the hit (preventing default bubble/death).
  - `func on_player_popped(_bomber: CGOGameBomber) -> bool`: returns `true` if mode consumed the pop (e.g. transform to Hedgehog instead of death).
  - `func on_match_end(_players: Array, _win_team: int) -> void`

### 2. `CDefaultComponent` (`0xe23990`) -> `Client/scripts/modes/c_default_component.gd` (`extends CComponent`)
- `component_id = MODE_DEFAULT`
- Uses `CGOGameBomber` and standard bubble/death rules (returns `false` on hit/pop hooks so `map_view.gd` runs default behavior).

### 3. `CHedgehogComponent` (`0xe40b00`) -> `Client/scripts/modes/c_hedgehog_component.gd` (`extends CComponent`)
- Original: ctor `0x74900D` (`sub_73D1FF(this, 11)`), `OnMatchEnd` `0x749159`, `UpdateCollision` `0x7491D4`, `UpdateTick` `0x749342`.
- Godot overrides:
  - `component_id = MODE_HEDGEHOG` (`11`)
  - `create_bomber()` -> returns `CGOHedgehogBomber.new()`
  - `on_player_hit_by_flame(bomber)`: if `bomber is CGOHedgehogBomber`, calls `bomber.on_flame_hit_hedgehog()` (`0x74A8D9`); returns `true` when stunned as Hedgehog.
  - `on_player_popped(bomber)`: if `bomber is CGOHedgehogBomber` and not already Hedgehog, calls `bomber.transform_to_hedgehog()` (`0x74A11F`) and returns `true`.
  - `find_hedgehog_hits(players: Array, targets: Array) -> Array`: pure helper matching `0x7491D4` / `0x749B1F` (returns `[hedgehog, target]` pairs where `hedgehog.can_hedgehog_collide()` and hitbox overlaps).
  - `on_match_end(players: Array, win_team: int)` (`0x749159`): for every real Hedgehog in `players`, sets state `61` (`STATE_HEDGEHOG_HURRAH`) if `team_id == win_team` else `62` (`STATE_HEDGEHOG_CRY`).

## Formulas and constants (with addresses)
- **Full `ComponentID` factory table (`CGameStage::CreateComponent` @ `0x73D4B0`):**

| ID | Hex | Original Class | Constructor | Base / Notes |
| :---: | :---: | :--- | :--- | :--- |
| `0` | `0x00` | `CDefaultComponent` (also `CBonusComponent` `0x742B2A`) | `0x7DF28E` | `CComponent` — Classic default mode |
| `1` | `0x01` | `CKartComponent` | `0x74B358` | `CComponent` — Kart racing mode |
| `2` | `0x02` | `CBulaComponent` | `0x742F22` | `CComponent` — Bula / tile capture (`Tile15_Static/Aft%02d`) |
| `4` | `0x04` | `CRabbitCatchComponent` | `0x77CE74` | `CComponent` — Rabbit Catch |
| `5` | `0x05` | `CWriggleComponent` | `0x7A2B66` | `CComponent` — Wriggle |
| `6` | `0x06` | `CZombieComponent` | `0x7A99A9` | `CComponent` — Zombie mode |
| `7` | `0x07` | `CGoldFlagComponent` | `0x7AC92F` | `CComponent` — Gold Flag (overrides 43 chars: speed=7, bomb=0, power=0) |
| `8` | `0x08` | `CCloverComponent` | `0x7AD98D` | `CComponent` — Clover (overrides 43 chars: speed=6, bomb=0, power=0) |
| `10` | `0x0A` | `CSurvivalComponent` | `0x74C35C` | `CComponent` — Survival |
| `11` | `0x0B` | `CHedgehogComponent` | `0x74900D` | `CComponent` — Hedgehog (`CGOHedgehogBomber`) |
| `12` | `0x0C` | `CCaptainComponent` | `0x748885` | `CComponent` — Captain |
| `13` | `0x0D` | `CTimebombComponent` | `0x74D842` | `CComponent` — Timebomb |
| `14` | `0x0E` | `CStageClearComponent` | `0x755F54` | `CMonsterComponent` (`0x7B6510`) — Monster Stage Clear S1 |
| `15` | `0x0F` | `CTutorialComponent` | `0x79CC1D` | `CComponent` — Tutorial |
| `16` | `0x10` | `CAIBattleComponent` | `0x785845` | `CComponent` — AI Battle |
| `17` | `0x11` | `CRPGComponent` | `0x7B3248` | `CMonsterComponent` (`0x7B6510`) — RPG / Boss |
| `18` | `0x12` | `CSuperFighterComponent` | `0x7B91ED` | `CComponent` — Super Fighter 1 |
| `19` | `0x13` | `CZzolmanComponent` | `0x7BCF8A` | `CComponent` — Zzolman |
| `20` | `0x14` | `CSnowBallFightComponent` / `CSnowBallBonusComponent` | `0x7D1994` / `0x7D05AA` | `CComponent` — Snowball Fight (`a3 != 0` -> Bonus) |
| `21` | `0x15` | `CSuperFighterComponent2` | `0x7D3282` | `CSuperFighterComponent` — Super Fighter 2 |
| `22` | `0x16` | `CMonSeason2Component` | `0x7DB11E` | `CMonsterComponent` (`0x7B6510`) — Monster Season 2 |
| `23` | `0x17` | `CConfusedFightComponent` | `0x7DDE31` | `CComponent` — Confused Fight (`30000`ms timer) |
| `26` | `0x1A` | `CFighterOfLegendComponent` | `0x489E65` | `CAIBattleComponent` (`0x785845`) — Fighter of Legend |
| `27` | `0x1B` | `CIamBossComponent` | `0x4A962B` | `CComponent` — I am Boss (`IamBoss/SealSkill1..2`) |
| `30` | `0x1E` | `CNpcCaptainComponent` | `0x441F7F` | `CDefaultComponent` (`0x7DF28E`) — NPC Captain |
| `32` | `0x20` | `CAIBattleComponent` | `0x785845` | `CComponent` — AI Battle variant 2 |
| `33` | `0x21` | `CSnowBearComponent` | `0x44A063` / `0x44991A` | `CComponent` — Snow Bear |

> **Note (`ComponentID` gaps):** Các ID trống (`3, 9, 24, 25, 28, 29, 31`) không có `case` trong `sub_73D4B0` (một số thuộc nhánh HiddenCatch / Event khởi tạo riêng như `CHiddenCatch*Component` / `CTakeCareOfEventComponent`).

- Match-end Hedgehog states (`0x749159`): win = `61` (`Hedgehog-Hurrah`), lose = `62` (`Hedgehog-Cry`).

## Test vectors (code-evidence)
- **TV-M1 (`CComponent` base & IDs, `0x73D1FF` / `0x73B7B1` / `0x74900D`):** `CDefaultComponent.new().get_type() == 0`; `CHedgehogComponent.new().get_type() == 11`; both `is CComponent` and `is RefCounted`.
- **TV-M2 (Bomber factory):** `CDefaultComponent.create_bomber()` returns `CGOGameBomber` (not `CGOHedgehogBomber`); `CHedgehogComponent.create_bomber()` returns `CGOHedgehogBomber`.
- **TV-M3 (`CHedgehogComponent` pop -> transform & flame -> stun, `0x74A11F` / `0x74A8D9`):** `on_player_popped(h)` returns `true` and sets `h.m_bIsHedgehog == true` (state `59`); once Hedgehog, `on_player_hit_by_flame(h)` returns `true` and sets state `60`.
- **TV-M4 (`CHedgehogComponent` collision filter, `0x7491D4` / `0x749824` / `0x749B1F`):** active Hedgehog overlapping target rect is reported by `find_hedgehog_hits()`; stunned Hedgehog (`state 60` or `75`) is ignored.
- **TV-M5 (`CHedgehogComponent::on_match_end`, `0x749159`):** winning-team Hedgehog enters state `61` (`Hedgehog-Hurrah`); losing-team Hedgehog enters state `62` (`Hedgehog-Cry`); non-Hedgehog human is untouched.

## Functions covered (address list)
- `0x73D4B0` (`CreateComponent` full switch factory for IDs `0..33`)
- `0x73D1FF`, `0x73B7B1`, `0x73B7B5`, `0x73CF68`, `0x73C38B`, `0x70A304` (`CComponent`, AddOn attach/lookup, & `CGameStage::GetComponent`)
- `0x7BD32F` (`IComponentAddOn` base), `0x7CADEE` (AI `1`), `0x7BF16D` (Monster `3`), `0x7C83DB` (Skill `4`), `0x485A26` (SpecialTile `5`), `0x7C0C5D` (Revival `6`)
- `0x7DF28E` (`CDefaultComponent`), `0x74900D`, `0x749073`, `0x749111`, `0x749159`, `0x7491D4`, `0x749342` (`CHedgehogComponent`)
- Mode constructors verified in `0x73D4B0`: `0x742B2A`, `0x74B358`, `0x742F22`, `0x77CE74`, `0x7A2B66`, `0x7A99A9`, `0x7AC92F`, `0x7AD98D`, `0x74C35C`, `0x748885`, `0x74D842`, `0x755F54`, `0x79CC1D`, `0x785845`, `0x7B3248`, `0x7B91ED`, `0x7BCF8A`, `0x7D1994`, `0x7D05AA`, `0x7D3282`, `0x7DB11E`, `0x7DDE31`, `0x489E65`, `0x4A962B`, `0x441F7F`, `0x44A063`, `0x44991A`

## UNKNOWN
- Unused/absent `sub_73D4B0` switch gaps (`3, 9, 24, 25, 28, 29, 31`): not handled by `0x73D4B0` (some belong to HiddenCatch/event modes instantiated separately).
- `CHedgehogComponent` network scoreboard / count sync packet (`0x74B0B4`): `UNKNOWN`, deferred to LAN wave.
