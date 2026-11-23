# Bomber Class Hierarchy (`CBomberAttr` + `CGOBomberBase` -> `CGOBomber` -> `CGOGameBomber`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + decoded `Client/data/bomber_attr.json`.
> **Rule:** All player characters on the map share ONE data table (`CBomberAttr`) and ONE runtime inheritance chain. Characters (`Character/C00`..`C42`, i.e., Bazzi, Dao, Marid, etc.) are data rows, **never** subclasses. Subclasses exist only per game mode / context.

## Behavior summary
1. **`CBomberAttr`** loads `"Attr/BomberAttr"` (`Client/data/bomber_attr.json`, up to 43 entries) and provides base/max `speed`, `bomb`, `power` stats plus derived UI/sprite asset paths (`Prepare/%s`, `<name>_Display`, `<name>_Portrait`, `<name>_Emotion`). `bomb_max` is hard-capped at `<= 10` (`0x9714c5`).
2. **`CGOBomberBase`** is the minimal `Node2D` map-entity base class (`0x592A2B`) holding cell/position/map_origin/visibility state.
3. **`CGOBomber`** (`extends CGOBomberBase`, `0x5A3F7D`) implements all shared bomber simulation & visuals for every player and non-match context: `CBomberAttr` stat initialization, movement, collision hooks, shared mount system (`CGOShip` + `CShipAttr`), bubble trap/rescue/death, debuffs, `m_bVisible` (`0x594E07`/`0x594E17`/`0x59F107`), and sprite rendering.
4. **`CGOGameBomber`** (`extends CGOBomber`, `0x5B231F`) adds the match-play layer used by **all players in a match** (1P, 2P, remote, AI): bomb action cooldown (`0x1A` = 26 units, `0x5B19B3`), match bomb placement/kick/throw request hooks (`0x5B0053`, `0x5B19B3`, `0x5B1D7B`), and match event visibility callback (`0x5AE4DA`). Network packet reception stays outside `CGOGameBomber` in `CGameStage` / `CGameMsgCache` (`0x6F4FD1`).

## Class / state (original class -> Godot class)

### 1. `CBomberAttr` (`0xe5471c`) -> `Client/scripts/objects/cbomber_attr.gd` (`Resource`)
- Original: `TSingleton<CBomberAttr>` (`dword_E60844`, ctor `0x971B9A`, dtor `0x971CD5`, load `0x97124A`), array of 43 × 412-byte `BomberAttr` entries (`0x9710C1` -> `0x970FEC`).
- Godot fields per `CBomberAttr` `Resource` entry (loaded from `res://data/bomber_attr.json`):
  - `char_id: int` — index into table (`0..42`)
  - `char_name: String` — raw name from JSON (e.g., `"Character/C00"`)
  - `short_name: String` — substring after `'/'` (e.g., `"C00"`, from `sub_9E2454` `'/'` split at `0x9713db`)
  - `prepare_path: String` — `"Prepare/" + short_name` (`0x971401`)
  - `display_path: String` — `char_name + "_Display"` (`0x971446`)
  - `portrait_path: String` — `char_name + "_Portrait"` (`0x971467`)
  - `emotion_path: String` — `char_name + "_Emotion"` (`0x971422`)
  - `category: int` — `stats[0]` (`v10[116]`)
  - `speed_init: int` — `stats[1]` (`v10 + 117`, getter `0x971A0F`)
  - `speed_max: int` — `stats[2]` (`v10 + 120`, getter `0x9715E8`)
  - `bomb_init: int` — `stats[3]` (`v10 + 123`, getter `0x971A6C`)
  - `bomb_max: int` — `mini(stats[4], 10)` (`v10 + 126`, cap at `0x9714c5`, getter `0x971604`)
  - `power_init: int` — `stats[5]` (`v10 + 129`, getter `0x971AC9`)
  - `power_max: int` — `stats[6]` (`v10 + 132`, getter `0x971620`)
- Static loader methods on `CBomberAttr`:
  - `load_data(file_path: String = "res://data/bomber_attr.json") -> void`
  - `get_attr(key: Variant) -> CBomberAttr` (accepts `int` index, `"Character/C00"`, or `"C00"`)
  - `get_count() -> int`

### 2. `CGOBomberBase` (`0xe225a8`) -> `Client/scripts/objects/cgo_bomber_base.gd` (`Node2D`)
- Original: ctor `0x592A2B` (vtable `0xc33cbc`, inherits drawable map object `sub_58EC45`).
- Godot fields & methods:
  - `const CELL_SIZE := 40`
  - `var cell := Vector2i(1, 1)`
  - `var map_origin := Vector2.ZERO`
  - `var dir := 0` (`0=Down, 1=Up, 2=Left, 3=Right`)
  - `var m_bVisible: bool = true` (original `this[2471]` @ `+9884`, initialized `1` in `0x5A3F7D`)
  - `set_bomber_visible(v: bool) -> void` (`0x594E07`)
  - `get_bomber_visible() -> bool` (`0x594E17`)
  - `is_bomber_visible(hidden_in_bush: bool = false) -> bool` (`0x59F107`: returns `false` if `hidden_in_bush` else `m_bVisible`)
  - `set_cell(cx: int, cy: int) -> void`, `get_center() -> Vector2`
  - **90-State `ObjectTable` Animation Player (`0x58DF45`, `Character/<prefix>_A`):**
    - `load_bomber_states(char_prefix: String) -> void` (cached from `Client/data/objecttable.json`)
    - `set_bomber_state(state_idx: int, loop: bool = true, restart: bool = false) -> void`
    - `step_bomber_state_tick() -> bool` (30ms fixed-tick step accumulator)
    - `get_bomber_state_frame() -> Dictionary` (`{"action": String, "frame": int}`)
    - Direction remap: `dir` (`0=Down, 1=Up, 2=Left, 3=Right`) -> ObjectTable order (`Left=0, Up=1, Right=2, Down=3`) via `BOMBER_DIR_TO_OT_DIR = [3, 1, 0, 2]`.
    - Key states (`Character/C00_A`): `00 Blink` (7 steps / 135 ticks), `01 Die` (44 steps / 92 ticks), `03 Hurrah` (24 steps / 204 ticks), `04..07 Ride L/U/R/D` (6-step ping-pong `[0,1,2,3,2,1]` / 24 ticks), `16..19 Throw L/U/R/D` (4 steps / 6 ticks), `20..23 Walk L/U/R/D` (6 steps `[0,1,2,0,3,4]` × 3 ticks = 18 ticks), `24 Start` (49 steps / 78 ticks).
    - **Complete 90-State Machine (`CGOBomber::OnStateTick` @ `0x5A0F75`, `CGOBomber::SetState` @ `0x59BD5C`):**
      - `0` `Blink`, `1` `Die` (on finish: if Ghost rebirth `0x594D4A` -> `43`, else deactivate), `2` `Faint` (timer `this[500] >= this[501]` -> `15`), `3` `Hurrah`.
      - `4..7` `Ride L/U/R/D`, `8..11` `StopRide L/U/R/D`, `12..15` `Stop L/U/R/D` (on finish -> `0` `Blink`), `16..19` `Throw L/U/R/D` (on finish -> `state - 4`), `20..23` `Walk L/U/R/D`.
      - `24` `Start` (on finish -> `15` `StopDown`), `25` `LockedIn` (legacy static bubble), `26` `Release` (on finish -> `15`).
      - `27..30` `SlideJump L/U/R/D` (fixed `10` px/tick + spin), `31..34` `SlideJumpHold L/U/R/D` (`sub_598840`), `35..38` `Drill L/U/R/D` (on finish -> `state - 23` = `Stop`), `39..42` `SlideRide L/U/R/D` (`10` px/tick on mount).
      - `43` `GhostIn` (`GhostInOut` 0..7, on finish -> `51`), `44..47` `GhostWalk L/U/R/D` (half speed `max(1, speed / 2)`), `48..51` `GhostStop L/U/R/D`, `57` `GhostOut` (`GhostInOut` 7..0, on finish -> deactivate).
      - `52..55` **`LockedInMove L/U/R/D`** (slow bubble movement: `1` px every `2` ticks = `0.5` px/tick, syncs bubble `this[603]`), `56` **`LockedInStop`** (stationary in bubble; `0x59BD5C` guards `52..56` as active LockedIn group).
      - `58..75` **Hedgehog** (`CGOHedgehogBomber`, `0x74A11F..0x74A8D9`).
      - `76..79` **`SnowThrow L/U/R/D`** (`Walk*_A` 2f `4:3, 2:-1`, handled by `CGOSnowBallBomber` `0x7CD235` / `0x7CD392` & `CGOSnowBearBomber` `0x443B0C`: on finish -> `dir + 12` `Stop`), `80` `SnowHit` (`SnowHit03_A`), `81` `SnowDying` (`SnowDying_A`), `82..85` **`SnowSpin L/U/R/D`** (`SnowSpin*_A`, handled by `0x7CD235` & `0x443B0C`, allowed to interrupt `52..56` in `0x59BD5C`), `86..89` `StaticStop L/U/R/D` (`Walk*_A` 1f `0:100`, reserved static pose — not dispatched in `0x5A0F75`/`0x7CD235`).

### 3. `CGOBomber` (`0xe22590`) -> `Client/scripts/objects/cgo_bomber.gd` (`extends CGOBomberBase`)
- Original: ctor `0x5A3F7D` (vtable `0xc348ec`), `Update` `0x5A6244`, `Render` `0x5A700B`.
- Godot changes (preserve all existing Wave 1 mount/collision/bubble APIs):
  - `extends "res://scripts/objects/cgo_bomber_base.gd"` (use `preload` constants for headless CLI safety)
  - `var bomber_attr: CBomberAttr = null`
  - `apply_character_attr(key: Variant) -> bool`: loads `CBomberAttr.get_attr(key)` and sets `char_prefix`, `speed`, `speed_max`, `bombs_cur`, `bombs_max`, `power_cur`, `power_max`.
  - Respects `is_bomber_visible()` in `_update_visuals()` (hides bomber sprites when `false`, matching `0x5A700B` @ `0x5a70f3`).

### 4. `CGOGameBomber` (`0xe22574`) -> `Client/scripts/objects/cgo_game_bomber.gd` (`extends CGOBomber`)
- Original: ctor `0x5B231F` (calls `0x5A3F7D`, vtable `0xc359a0`), dtor `0x5AF829`, event callback `0x5AE4DA` (`off_C356D4`), bomb actions `0x5B0053` / `0x5B19B3` / `0x5B1D7B`.
- Godot fields & methods:
  - `const ACTION_COOLDOWN_TICKS := 26` (`0x1A` guard in `0x5B19B3` @ `0x5b19d5`)
  - `var match_tick_counter: int = 0`
  - `var last_multi_bomb_tick: int = -26` (`this[3144]`)
  - `var _match_event_flag: bool = false` (`this[169]` cleared by `0x5AE4DA`)
  - `on_match_event(event_type: int) -> bool` (`0x5AE4DA`: if `event_type == 0`, clears `_match_event_flag = false` and calls `set_bomber_visible(true)`, returns `true`; else `false`)
  - `can_trigger_multi_bomb() -> bool` (`match_tick_counter - last_multi_bomb_tick >= ACTION_COOLDOWN_TICKS`)
  - `record_multi_bomb_tick() -> void`
  - Override `_on_tick() -> void`: increments `match_tick_counter` and calls `super._on_tick()`.
  - `Client/scripts/map_view.gd` spawns `CGOGameBomber` for match players (1P/2P/AI) and initializes stats from `CBomberAttr`.

### 5. `CGOHedgehogBomber` (`0xe40b24`, Spec'd) -> future `Client/scripts/objects/cgo_hedgehog_bomber.gd` (`extends CGOGameBomber`)
- Original: ctor `0x74A690` (calls `CGOGameBomber::sub_5B231F`), dtor `0x74A7A1`, reset/init `0x74A84C`, debug dump `0x74A051`, paired with `CHedgehogComponent` (`0xe40b00`) and `CGOHedgehogDisplay` (`0xe40b44`).
- Extended fields (after `CGOGameBomber`, verified by `0x74A051`, `0x74A690`, `0x74A84C`):
  - `m_bIsHedgehog: bool` (`this[3150]` @ `+12600`, setter `0x749AE5`): `0` = human, `1` = real Hedgehog.
  - `m_wImitationHedgehogTime: int` (`this[3151]` @ `+12604`): Fake Hedgehog countdown (`15s = 500` ticks @ 30ms, `1000 * 15 / 30` in `0x749DD1`).
  - `m_bImitationHedgehog: bool` (`this[3152]` @ `+12608`): disguised as Hedgehog via `Item/ItemFakeHedgehog`.
  - `m_nSuperHedgehogCount: int` (`this[3153]` @ `+12612`): Super Hedgehog spin countdown (`33` ticks in `0x749EA1`, rotates `67..70` every 2 ticks in `0x749646`).
  - `m_nHedgehogSpeed: int` (`this[3154]` @ `+12616`): Hedgehog move speed (default `4` in `0x74A84C` & `0x74A11F`, `+2` per `SuperHedgehog`, capped `< 7` i.e. max `6` in `0x74962D`).
  - `m_vHedgehogEatItems: Array` (`this[3155..3156]`, count `(end - begin) >> 2` in `0x74A051`): eaten item list dropped back onto the map when hit (`0x74A8D9` -> `0x74A8B1`).
- 18 `ObjectTable` Hedgehog states (`58..75`, `StaticChar/Hedgehog-*`):
  - `58`: `StaticChar/Hedgehog-Blink` (18 steps / 141 ticks)
  - `59`: `StaticChar/Hedgehog-Die` (12 steps / 47 ticks — transform/rebirth anim)
  - `60`: `StaticChar/Hedgehog-Faint` (5 steps / 14 ticks — hit stun start)
  - `61`: `StaticChar/Hedgehog-Hurrah` (20 steps / 94 ticks)
  - `62`: `StaticChar/Hedgehog-Cry` (8 steps / 59 ticks)
  - `63..66`: `StaticChar/Hedgehog-WalkLeft / Up / Right / Down` (6 steps / 30 ticks)
  - `67..70`: `StaticChar/Hedgehog-WalkLeft / Up / Right / Down` (1 step / 100 ticks — idle/stop)
  - `71..74`: `StaticChar/Hedgehog-Slide` (4 steps / 8 ticks — slide/roll at fixed `10` px/tick in `0x74A414`)
  - `75`: `StaticChar/Hedgehog-Faint` (33 steps / 99 ticks — struggle loop after `60`)
- Behavior & transitions:
  - **Transform to Hedgehog (`0x74A11F`):** clears mount/buffs/debuffs, hides character costume (`sub_5A930A(..., 0)`), sets `m_bIsHedgehog = 1`, `m_nHedgehogSpeed = 4`, plays state `59` + SFX `61` (`Wave/Cha_HedgehogRebirth`). On anim finish (`0x74A414`, `a2 == 2`), transitions to state `70` (idle down).
  - **Item pickup restriction (`0x74970C`):** while `m_bIsHedgehog == 1`, cannot eat items during states `59..62`, `71..74`, or `75`.
  - **Hit by flame while Hedgehog (`0x74A8D9` -> `0x74A414`):** does not die; enters state `60` (`14` ticks), drops 1 eaten item (`0x74A8B1`), clears `m_nSuperHedgehogCount`. When `60` finishes -> state `75` (`99` ticks) + SFX `62` (`Wave/Cha_HedgehogStruggle`); when `75` finishes -> state `70`.
  - **Hedgehog collision (`0x7491D4` -> `0x749B1F`, `0x749824`):** `CHedgehogComponent` checks active Hedgehogs (`state != 60 && state != 75`) against target hitboxes and triggers pop/impact (`vtable+140`).
  - **`Item/ItemFakeHedgehog` (`item_attr` type `41`, `0x749E45` -> `0x749DD1`, `0x749A20`, `0x749646`):** human-only; sets `m_bImitationHedgehog = 1`, `m_wImitationHedgehogTime = 500` ticks (`15s`), plays state `59` + SFX `61`, remaps walk/stop/throw states (`12..23`) to idle Hedgehog `67..70` (`0x749A20`). Cancelled on timeout (`0x749646`), slide (`0x749F3F`), or hit (`0x74A8D9`).
  - **`Item/ItemSuperHedgehog` (`item_attr` type `42`, `0x749EA1`, `0x749646`, `0x74962D`):** Hedgehog-only when `m_nHedgehogSpeed + 2 <= 7`; sets `m_nSuperHedgehogCount = 33` ticks, plays SFX `171` (`Wave/Itm_UseSuperHedgehog`), adds `+2` speed (cap `< 7`).
  - **Godot rendering note:** `get_bomber_state_frame()` must return full `sprite` path (e.g. `StaticChar/Hedgehog-WalkDown`) when porting `CGOHedgehogBomber`, since Hedgehog sprites live under `StaticChar/` rather than `Character/<prefix>-`.

## Formulas and constants (with addresses)
- `MAX_BOMBER_ATTR_SLOTS = 43`, entry size = `412` bytes (`103` DWORDs) — `0x9710C1`
- `BOMB_MAX_CAP = 10` (`if bomb_max > 10: bomb_max = 10`) — `0x9714c5`
- `ACTION_COOLDOWN_TICKS = 0x1A` (`26`) — `0x5B19B3` @ `0x5b19d5`
- `m_bVisible` default = `true` (`1`) — `0x5A3F7D` (`this + 9884`)
- Sprite path derivation (`0x9713db..0x971467`): split `char_name` on `'/'` -> `Prepare/<short>`, `<char_name>_Display`, `<char_name>_Portrait`, `<char_name>_Emotion`

## Flow / state machine
1. **Character creation (match start):**
   `map_view.gd` instantiates `CGOGameBomber` -> `apply_character_attr(char_id_or_name)` reads `CBomberAttr` -> sets initial/max stats & `char_prefix` -> `m_bVisible = true`.
2. **Visibility check (render, `0x5A700B` -> `0x59F107`):**
   If `hidden_in_bush` -> hidden; else visible iff `m_bVisible == true`.
3. **Match event callback (`0x5AE4DA`):**
   `on_match_event(0)` -> `_match_event_flag = false`, `set_bomber_visible(true)`.
4. **Network boundary (for future LAN wave):**
   Server -> Client packets enter `CGameStage` (`0xe25354`) / `CGameMsgCache` (`0x6F4FD1`) and dispatch to `CGOGameBomber` by slot/player ID; `CGOGameBomber` does not own sockets.

## Test vectors (code-evidence)
- **TV-B1 (`CBomberAttr` C00 / Bazzi, `0x97124A` + `bomber_attr.json`):** `get_attr("Character/C00")` -> `speed_init=5, speed_max=7, bomb_init=1, bomb_max=10, power_init=1, power_max=7, prepare_path="Prepare/C00", display_path="Character/C00_Display"`.
- **TV-B2 (`CBomberAttr` C01 / Dao-Marid, `0x97124A` + `bomber_attr.json`):** `get_attr("C01")` -> `speed_init=4, speed_max=8, bomb_init=2, bomb_max=7, power_init=1, power_max=9`.
- **TV-B3 (`bomb_max` cap, `0x9714c5`):** synthetic dict with `stats[4] = 15` -> `bomb_max == 10`.
- **TV-B4 (Inheritance chain, `0x592A2B` -> `0x5A3F7D` -> `0x5B231F`):** `var p = CGOGameBomber.new()` satisfies `p is CGOGameBomber`, `p is CGOBomber`, `p is CGOBomberBase`, `p is Node2D`.
- **TV-B5 (`m_bVisible` & `on_match_event`, `0x594E07` / `0x59F107` / `0x5AE4DA`):** default `is_bomber_visible() == true`; `is_bomber_visible(true) == false`; `set_bomber_visible(false)` -> `is_bomber_visible() == false`; `on_match_event(1) == false` (stays `false`); `on_match_event(0) == true` -> `is_bomber_visible() == true`.
- **TV-B6 (`CGOGameBomber` action cooldown, `0x5B19B3` @ `0x5b19d5`):** `can_trigger_multi_bomb() == true` initially -> `record_multi_bomb_tick()` -> `false` for 25 ticks -> `true` on tick 26.
- **TV-B7 (`CGOBomberBase` 90-state `ObjectTable` player, `0x58DF45`):** `C00` loads 90 states; `WalkDown` plays `[0,1,2,0,3,4]` at 3 ticks/step and loops at 18 ticks; `RideDown` plays `[0,1,2,3,2,1]` at `[6,3,3,6,3,3]` ticks; `ThrowDown` finishes at 6 ticks; `Blink` finishes at 135 ticks.

## Functions covered (address list)
- `0x971B9A`, `0x971CD5`, `0x9710C1`, `0x970FEC`, `0x97124A`
- `0x971A0F`, `0x971A6C`, `0x971AC9`, `0x9715E8`, `0x971604`, `0x971620`
- `0x592A2B`, `0x594E07`, `0x594E17`, `0x59F04D`, `0x59F107`
- `0x5A3F7D`, `0x5A6244`, `0x5A700B`
- `0x5B231F`, `0x5AF829`, `0x5AE4DA`, `0x5B0053`, `0x5B19B3`, `0x5B1D7B`
- `0x6F4FD1` (reference only: network boundary in `CGameStage` / `CGameMsgCache`)
- `0x74A690`, `0x74A7A1`, `0x74A84C`, `0x74A051`, `0x74A11F`, `0x74A414`, `0x74A8D9` (`CGOHedgehogBomber` lifecycle, transform, update, hit stun)
- `0x74962D`, `0x749646`, `0x74970C`, `0x749824`, `0x749872`, `0x749A20`, `0x749AE5`, `0x749B1F`, `0x749DD1`, `0x749E45`, `0x749EA1`, `0x749F3F`, `0x7491D4`, `0x749342` (`CGOHedgehogBomber` & `CHedgehogComponent` mechanics)

## UNKNOWN
- `CBomberAttr` extra fields `stats[7..9]` (`v10[135..137]`, e.g. `10, 100, 9` on C00): parsed in `0x97124A`, never read by client code (`UNKNOWN`, non-blocking for client gameplay).
- Exact `enGameServerPacket` opcode enum for server -> `CGOGameBomber` dispatch: deferred to LAN/multiplayer wave (`UNKNOWN`, not needed for offline Wave 2 refactor).
- `CHedgehogComponent` match-score / network sync packet format (`0x74B0B4`): deferred to Hedgehog mode / LAN wave (`UNKNOWN`).
