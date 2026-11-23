# Map Tile Class Hierarchy (`CTileInfo` + `CGOTile*`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + decoded `Client/data/tile_info.json` (3,369 tiles).
> **Rule:** Map elements are defined by ONE 52-byte tagged-union attribute table (`CTileInfo`) and ONE runtime inheritance hierarchy (`CGOTile*`). Movement-blocking and flame-blocking are maintained in two separate per-cell grids on `CPlayMap` (`map_view.gd`).

## Behavior summary
1. **`CTileInfo`** (`CMapObjToTileInfo`, `0x97818D` -> `0x977FFB`) parses each tile's 52-byte `raw` blob from `res://data/tile_info.json` as a tagged union keyed by `type = b[0]`:
- **`type == 0` (`Ground`):** `width = b[4]`, `height = b[8]`, conveyor speed `b[12]` in **pixels/tick** (`2 px/tick` = `66.67 px/s` at 30ms/tick on `TileConv/Conv*`, `0x5C02AA` -> `0x5BFA43`), `conveyor_in_mask = b[16]` (`1=Left, 2=Up, 4=Right, 8=Down`), `conveyor_out_dir = b[20]` (`0=Left, 1=Up, 2=Right, 3=Down, -1=none`), special island ground `b[24] == 1`, special no-bomb ground `u16(b[42..43]) >= 10000` (`0x71F913` -> `0x72975F`).
- **`type == 1` (`Static`):** `width = b[4]`, `height = b[8]`, `b[12]` (set to `1` on 161 tiles like `Rock10`, `Z_Candlelight`, `Temple01..11`; never read by `CGOTileStatic` at runtime — `UNKNOWN`), `b[16..19]` (`custom_static_id`, `0x5C15DF`: `10001..10199` for `Tile15_Static/Aft%02d` @ `0x743780`/`0x7453F6`).
- **`type == 2` (`Box`):** `hp = b[4]` (default `1` if `0` @ `0x5BF3C0`; `>= 255` indestructible @ `0x5BF6F9`), `is_movable = (b[8] != 0)`, `spike_dir_mask = b[12]` (`PinBlock01..05`/`Urchins00`: bitmask `1=Left face, 2=Up face, 4=Right face, 8=Down face, 16=Omni/floor` @ `0x7299A8`/`0x72964B`), `explode_on_break = (b[13] != 0)` (`ExplodeBlock01`/`JellyBombBlock00` -> `0x7322B5`).
- **`type == 3` (`Passable`):**
  - `player_passable_dirs = b[4..7]` (`sub_5C0E98`/`sub_5C0F18`, 4-dir player entry/exit; `(0,0,0,0)` on `Icewater00`/`TransparentBlock`/`Line01..04` blocks players)
  - `bomb_passable_dirs = b[8..11]` (`sub_5C1030`/`sub_5C107A`, 4-dir bomb pass; `(1,1,1,1)` on `Icewater00`/`TransparentBlock` lets bombs pass while blocking players!)
  - `flame_passable_dirs = b[12..15]` (`sub_5C10E1`/`sub_5C1136`, 4-dir flame pass)
  - `item_visible_inside = (b[16] != 0)` (`ca.exe.c:666537`), `bomb_visible_inside = (b[17] != 0)` (`ca.exe.c:333307`), `detonate_bomb_on_touch = (b[18] != 0)` (`PinTile01`, server-authoritative in original client), `conceals_bomber = (b[19] == 0)` (`0x59F04D`), `draw_under_player = (b[20] != 0)` (`ca.exe.c:661370`), `indestructible_by_flame = (b[24] != 0)` (`0x70F346`).
- **`type == 4` (`Deco`):** decorative/fly tiles (7 tiles).
2. **`CGOTile`** (`0x5BEC86`) extends `CGameObject` and is the base class for all map tiles.
3. **`CGOTileGround`** (`0x5C0095`, `type == 0`), **`CGOTileFixed`** (`0x5BEE39`) -> **`CGOTileStatic`** (`0x5C157A`, `type == 1`), **`CGOTileFixedBox`** (`0x5BF25F`, `type == 2 & !is_movable`), **`CGOTilePassable`** (`0x5C12BF`, `type == 3`), and **`CGOTileMoveAbleBox`** (`0x5C0798`, `type == 2 & is_movable`, inherits `CGOTile`).
4. **`CGOTileFixedBox::on_hit()` (`0x5BF711`):** ignores damage if `is_indestructible()` (`hp >= 255`); otherwise decrements `hp`. If `hp > 0`, triggers 15-tick hit-flash (`hit_flash_ticks = 14`); if `hp == 0`, marks broken, emits `broken` (clearing flame/move block and dropping item), and if `explode_on_break` (`0x5BF5BD`), emits `explode_requested` (`0x7322B5`).
5. **`CGOTileMoveAbleBox` (`0x730EF4`):** can be pushed onto an adjacent empty cell, updating both movement-block and flame-block grids and crushing any ground item on the destination cell.

## Class / state (original class -> Godot class)

### 1. `CMapObjToTileInfo` (`0xe54e08`) -> `Client/scripts/objects/ctile_info.gd` (`Resource`)
- Static loader: `load_data(file_path: String = "res://data/tile_info.json") -> void`, `get_info(tile_name: String) -> CTileInfo`, `get_count() -> int`.
- Per-entry `Resource` fields (`from_dict(tile_name: String, entry: Dictionary) -> CTileInfo`):
  - `tile_name: String`
  - `tile_type: int` (`0=Ground, 1=Static, 2=Box, 3=Passable, 4=Deco`)
  - `width: int`, `height: int`
  - `is_conveyor: bool` (`type == 0 and b[12] == 2`, `TileConv/Conv*`)
  - `conveyor_in_mask: int` (`type == 0`, `b[16]`: `1=Left, 2=Up, 4=Right, 8=Down`)
  - `conveyor_out_dir: int` (`type == 0`, `b[20]`: `0=Left, 1=Up, 2=Right, 3=Down, 255=-1`)
  - `is_special_ground: bool` (`type == 0 and b[24] != 0`, `IslandA*`)
  - `custom_static_id: int` (`type == 1`, `u32_le(b[16..19])`, `0x5C15DF`)
  - `hp: int` (`type == 2`: `int(b[4])` if `b[4] > 0` else `1`, per `0x5BF3C0`)
  - `is_movable: bool` (`type == 2 and b[8] != 0`)
  - `spike_dir_mask: int` (`type == 2`, `b[12]`: `0`, `1`, `2`, `4`, `8`, `16` on `PinBlock01..05`/`Urchins00`)
  - `explode_on_break: bool` (`type == 2 and b[13] != 0`, per `0x5BF5BD`)
  - `player_passable_dirs: Array[bool]` (`type == 3`, `[b[4]!=0..b[7]!=0]`, per `0x5C0E98`)
  - `bomb_passable_dirs: Array[bool]` (`type == 3`, `[b[8]!=0..b[11]!=0]`, per `0x5C1030`)
  - `passable_dirs: Array[bool]` (`type == 3`, flame `[b[12]!=0..b[15]!=0]`, per `0x5C10E1`)
  - `item_visible_inside: bool` (`type == 3 and b[16] != 0`, `ca.exe.c:666537`)
  - `bomb_visible_inside: bool` (`type == 3 and b[17] != 0`, `ca.exe.c:333307`)
  - `detonate_bomb_on_touch: bool` (`type == 3 and b[18] != 0`, `PinTile01`)
  - `conceals_bomber: bool` (`type == 3 and b[19] == 0`, per `0x59F04D`)
  - `draw_under_player: bool` (`type == 3 and b[20] != 0`, `ca.exe.c:661370`)
  - `indestructible_by_flame: bool` (`type == 3 and b[24] != 0`, per `0x70F346`)
  - `blocks_movement: bool` (`tile_type in [1, 2]`, or `tile_type == 3` with all `player_passable_dirs == false`)
  - `blocks_flame: bool` (`tile_type in [1, 2]`, or `tile_type == 3` with all `passable_dirs == false`)

### 2. `CGOTile` (`0xe241c4`) -> `Client/scripts/objects/cgo_tile.gd` (`extends CGameObject`)
- Fields: `var tile_info: CTileInfo = null`, `var object_id: int = -1`, `var tile_active: bool = true`.
- Methods: `init_tile(info: CTileInfo, obj_id: int, col: int, row: int) -> void`, `blocks_movement() -> bool`, `blocks_flame() -> bool`.

### 3. `CGOTileGround` (`0xe303c4`) -> `Client/scripts/objects/cgo_tile_ground.gd` (`extends CGOTile`)
- Represents `type == 0` ground tiles (`blocks_movement() == false`, `blocks_flame() == false`).
- **Ground traps (`0x5BFE98` `SetGroundTrap`, `0x5BFDE9` `IsTrapActive`, `0x5C01FD` `ClearGroundTrap`, `0x59C2B2` -> `0x89B145` guard -> `0x89B623` execute):**
  - `TRAP_BOND = 1` (`Item/BondGround`, SFX `167` -> `113`): skips flying bombers; applies `12s = 400` tick slow debuff (`0x597233`), forcing `CGOBomber::GetSpeed` (`0x59EC93` @ `0x59ecd6` -> `0x599A12`) to return `2`.
  - `TRAP_MINE = 2` (Mine, SFX `172` -> `114`): skips shielded bombers; dismounts ship or snaps bomber to cell center `(40*col, 40*row + 39)` and traps in bubble.
  - `TRAP_BANANA = 3` (`Item/BananaGround`, SFX `166` -> `112` `Itm_UseBanana`): skips flying bombers; calls `CGOBomber::StartSlide` (`0x593737`: `SlideJump 27..30` / `SlideRide 39..42` along move dir / conveyor visual dir / facing dir at `10 px/tick` until hitting obstacle via `0x59E23F`).
  - `TRAP_PUSHPIN = 4` (`Item/PushpinGround`): skipped for bombers in `0x89B145`.

### 4. `CGOTileFixed` (`0xe241a8`) -> `Client/scripts/objects/cgo_tile_fixed.gd` (`extends CGOTile`)
- Stationary grid tile base (`0x5BEE39`).

### 5. `CGOTileStatic` (`0xe2418c`) -> `Client/scripts/objects/cgo_tile_static.gd` (`extends CGOTileFixed`)
- Unbreakable wall/obstacle (`type == 1`, `blocks_movement() == true`, `blocks_flame() == true`).

### 6. `CGOTileFixedBox` (`0xe2fdf0`) -> `Client/scripts/objects/cgo_tile_fixed_box.gd` (`extends CGOTileFixed`)
- Signals: `box_broken(box: CGOTileFixedBox, col: int, row: int)`, `explode_requested(col: int, row: int)`.
- Fields: `var hp: int = 1`, `var max_hp: int = 1`, `var spike_dir_mask: int = 0`, `var explode_on_break: bool = false`, `var hit_flash_ticks: int = -1`, `var is_broken: bool = false`.
- Methods:
  - `is_indestructible() -> bool` (`hp >= 255`, `0x5BF6F9`)
  - `on_hit(force_destroy: bool = false) -> bool` (`0x5BF711`: returns `true` if destroyed, `false` if survived with `hit_flash_ticks = 14`)
  - `finish_break() -> void` (`0x5BF5BD`: sets `tile_active = false`; if `explode_on_break`, emits `explode_requested`)

### 7. `CGOTileMoveAbleBox` (`0xe30498`) -> `Client/scripts/objects/cgo_tile_movable_box.gd` (`extends CGOTile`)
- Shares HP/indestructible/spike fields with `CGOTileFixedBox`, plus `can_push() -> bool` and `push_to(col: int, row: int) -> void` (`0x730EF4`).

### 8. `CGOTilePassable` (`0xe304bc`) -> `Client/scripts/objects/cgo_tile_passable.gd` (`extends CGOTileFixed`)
- Methods:
  - `blocks_movement() -> bool` (`tile_active and tile_info.blocks_movement`; true when all `player_passable_dirs` are `false`, e.g. `Icewater00`, `TransparentBlock`, `Line01..04`)
  - `blocks_flame() -> bool` (`tile_active and tile_info.blocks_flame`)
  - `is_concealing() -> bool` (`tile_info.conceals_bomber`, `0x59F04D`)
  - `is_player_passable_from_dir(dir_idx: int) -> bool` (`0x5C0E98`, `b[4..7]`)
  - `is_bomb_passable_from_dir(dir_idx: int) -> bool` (`0x5C1030`, `b[8..11]`)
  - `is_passable_from_dir(dir_idx: int) -> bool` (`0x5C10E1`, `b[12..15]` flame passable)
  - `detonates_bomb_on_touch() -> bool` (`tile_active and tile_info.detonate_bomb_on_touch`, `b[18] != 0`, `PinTile01`)
  - `on_flame_hit() -> bool` (`0x70F346`: if `not tile_info.indestructible_by_flame`, marks `tile_active = false` and returns `true`; else returns `false`).

## Formulas and constants (with addresses)
- `TILE_INFO_BYTES = 52` (`0x977FFB` @ `0x9780d1`)
- `INDESTRUCTIBLE_HP = 255` (`hp >= 255`, `0x5BF6F9`)
- `DEFAULT_BOX_HP = 1` (`if hp == 0: hp = 1`, `0x5BF3C0` @ `0x5bf46f`)
- `BOX_HIT_FLASH_TICKS = 14` (15 ticks inclusive `14..0`, `0x5BF711` @ `0x5bf757` & `0x5BF5BD`)
- `calc_shaken_state_index(cur_idx)` (`sub_5BF1B3` / `sub_5C0753`): `2` if `cur_idx < 1`, `cur_idx + 1` if `cur_idx % 2 == 1`, else `cur_idx` (switches `Default` `1` -> `Default01_Shaken` `2`, `Default02` `3` -> `Default02_Shaken` `4`, ...)
- `calc_damaged_state_index(hp, total_states)` (`sub_5BF5BD` @ `0x5bf5ff..0x5bf633`): `max(1, 1 - 2 * hp + total_states)` (e.g. `StrongBox01` `total=10`: `hp=4 -> 3 Default02`, `hp=3 -> 5 Default03`, `hp=1 -> 9 Default05`)
- `PASSABLE_CONCEAL_BYTE = 19` (`b[19] == 0` -> conceals, `0x59F04D`)
- `PASSABLE_PERMANENT_BYTE = 24` (`b[24] != 0` -> survives flame/push, `0x70F346`)
- **Conveyor push (`CGOTileGround::ApplyConveyor`, `0x5BFA43`, called from `CGOBomber::Update` `0x5A6244` @ `0x5a664d`):**
  - Speed = `b[12]` pixels/tick (`2 px/tick` = `66.67 px/s` at 30ms/tick). Skipped if `sub_594D4A(bomber)` (`this[2333]`) or `speed <= 0`.
  - Phase 1 (center-pull via `in_mask = b[16]`): `rem = speed`. For each bit `1=L` (`bomber.x > tile.x`), `2=U` (`bomber.y > tile.y`), `4=R` (`bomber.x < tile.x`), `8=D` (`bomber.y < tile.y`), moves `min(rem, abs(delta))` via `sub_59D894(bomber, dir, step)` and decrements `rem`.
  - Phase 2 (push-out via `out_dir = b[20]`): if `rem >= speed` and `out_dir != -1`, moves `rem` pixels in `out_dir`.
- **Spike face bitmask (`CPlayMap::HasSpikeForDir`, `0x7299A8`, setter `0x72964B`, move on box push `0x729701` @ `0x731028`):**
  - `dir == -1` (omni/floor): `(mask >> 4) & 1` (`0x10`, e.g. `PinBlock05`, `PinTile01`)
  - `dir == 0` (bomb moving Left hits Right face): `(mask >> 2) & 1` (`0x04`)
  - `dir == 1` (bomb moving Up hits Down face): `(mask >> 3) & 1` (`0x08`)
  - `dir == 2` (bomb moving Right hits Left face): `(mask >> 0) & 1` (`0x01`)
  - `dir == 3` (bomb moving Down hits Up face): `(mask >> 1) & 1` (`0x02`)
  - Kick into adjacent spike face (`0x702DE4` @ `0x702e9f`) -> rapid `300ms` fuse; sliding bomb stops at spike face (`0x5BE35F` @ `0x5be498`) -> sets `bomb + 292 = 1` (detonate on impact).

## Flow / state machine
1. **Map load (`map_view.gd::_show()`):** looks up `CTileInfo.get_info(name)` for each cell object, instantiates the matching `CGOTile*` subclass (`Static` / `FixedBox` / `MoveAbleBox` / `Passable` / `Ground`), registers initial movement-block and flame-block flags in two separate grids, and caches conveyor ground tiles (`type == 0`, `is_conveyor == true`) into `_ground_tiles`.
2. **Player movement & conveyor (`map_view.gd::is_tile_walkable()`, `_apply_conveyor_push()`):**
   - `type == 3` (`CGOTilePassable`) with `blocks_movement() == true` (`player_passable_dirs == [0,0,0,0]`, e.g. `Icewater00`, `TransparentBlock`, `Line01..04`) blocks walking.
   - Non-flying players standing on a conveyor ground tile in `_ground_tiles` are pushed along `conveyor_out_dir` (`0=Left, 1=Up, 2=Right, 3=Down`).
3. **Movable box push (`0x730EF4`, `0x5C0C2E`, `map_view.gd::push_movable_box()`):** server-authoritative in the original client (`ca.exe.c:627992`); in offline Godot, pushing into a `CGOTileMoveAbleBox` for `0.15s` slides it smoothly over `0.30s` (`10 ticks × 4 px/tick`) onto an empty adjacent cell, updating both grids and crushing ground items. In the original client, `CGOTilePassable` (`sub_7293B4`) is a separate layer from `CGOTileMoveAbleBox` (`sub_71FBFD`), so a pushable box CAN be pushed into a passable bush/tent and is concealed inside it while the passable tile is active (`0x5C0C2E` @ `ca.exe.c:372195`, except `TurnBox`).
4. **Passable tile shake/rustle (`CGOTilePassable::SetShakeState` `0x5C1175`, `Update` `0x5C1380`):**
   - Triggered when a bomber/entity enters a `CGOTilePassable` cell (`ca.exe.c:343302`, `921660`, `1124752`): sets state `1` (vertical, `dir % 2 != 0`) or state `2` (horizontal, `dir % 2 == 0`), and plays SFX `158` (`"Tent"`) or SFX `63` (`"Herb"` / `"BasicBlock_Pass"` / `"Plant"` / `"Z_Passa"` / `"Mons2_Pass"`).
   - When the shake animation finishes (`0x5C1380`), resets to state `0` (`Default`).
5. **Bomb on `PinTile01` (`b[18] != 0`, `map_view.gd::_on_map_action_bomb_placed()` / `_check_pin_tile_detonate()`):** server-authoritative in the original client; in offline Godot, bombs placed on or sliding (`bomb.cell_changed`) onto a `CGOTilePassable` with `detonates_bomb_on_touch() == true` detonate immediately.
6. **Flame hits cell (`0x72AB7A` -> `0x729970` -> `0x5BF711`):**
   - If cell is flame-blocked (`Static` or `Box`), flame stops at this cell.
   - If `CGOTileFixedBox`/`CGOTileMoveAbleBox`: calls `on_hit()`. If `hp > 0`, plays shaken state (`calc_shaken_state_index` @ `0x5BF1B3`) for 15 ticks then settles to damaged state (`calc_damaged_state_index` @ `0x5BF5BD`, `Default02..05`). If `hp == 0`, clears flame-block & move-block, drops item, and if `explode_on_break` triggers chain explosion (`0x7322B5`).
   - If `CGOTilePassable`: calls `on_flame_hit()` (destroys burnable bushes `b[24]==0` like `Herb00`, leaves permanent `b[24]==1` intact); flame continues through.

## Test vectors (code-evidence)
- **TV-T1 (`CTileInfo` parsing, `0x977FFB` + `tile_info.json`):**
  - `Tile00_Box/BoxOrange`: `type=2, hp=1, is_movable=false, explode_on_break=false`
  - `Tile16_Box/StrongBox01`: `type=2, hp=5, is_movable=true`
  - `Tile16_Box/StrongBox02`: `type=2, hp=2, is_movable=true`
  - `Tile24_Box/PuzzleUnmovablebox`: `type=2, hp=255, is_movable=false` (`is_indestructible() == true`)
  - `Tile30_Box/ExplodeBlock01`: `type=2, hp=1, explode_on_break=true`
  - `Tile30_Box/PinBlock05`: `type=2, hp=255, is_movable=true, spike_dir_mask=16`
- **TV-T2 (`CGOTilePassable` & Ground conveyor, `0x59F04D` / `0x5C0E98` / `0x5C1030` / `0x5C10E1` / `0x70F346`):**
  - `Tile00_Passable/Herb00`: `conceals_bomber=true`, `indestructible_by_flame=false` (`on_flame_hit() == true`), `blocks_movement() == false`
  - `Tile01_Passable/TentBlue`: `conceals_bomber=true`, `indestructible_by_flame=true` (`on_flame_hit() == false`), `passable_dirs=[false, true, false, true]`
  - `Tile02_Passble/Icewater00`: `conceals_bomber=false`, `indestructible_by_flame=true`, `blocks_movement() == true`, `bomb_passable_dirs=[true, true, true, true]`
  - `Tile30_Passable/PinTile01`: `detonates_bomb_on_touch() == true` (`b[18] == 1`)
  - `TileConv/Conv*`: `type=0`, `is_conveyor=true`, `conveyor_in_mask` (`b[16]`), `conveyor_out_dir` (`b[20]`)
- **TV-T3 (`CGOTileFixedBox` multi-hit & indestructible, `0x5BF1B3` / `0x5BF6F9` / `0x5BF711` / `0x5BF5BD`):**
  - `StrongBox02` (`hp=2`): hit #1 -> returns `false`, `hp == 1`, `hit_flash_ticks == 14`; hit #2 -> returns `true`, `hp == 0`, `is_broken == true`.
  - `PuzzleUnmovablebox` (`hp=255`): `on_hit()` -> returns `false`, `hp == 255`.
  - `ExplodeBlock01`: `on_hit()` + `finish_break()` -> emits `explode_requested`.
- **TV-T4 (`CGOTileMoveAbleBox` push, `0x5C0798` / `0x730EF4`):**
  - `CGOTileMoveAbleBox` inherits `CGOTile` (not `CGOTileFixed`), `push_to(4, 3)` updates `cell == Vector2i(4, 3)`.
- **TV-T5 (Inheritance chain):**
  - `CGOTileStatic is CGOTileFixed`, `CGOTileFixedBox is CGOTileFixed`, `CGOTilePassable is CGOTileFixed`, `CGOTileFixed is CGOTile`, `CGOTileGround is CGOTile`, `CGOTileMoveAbleBox is CGOTile`.

## Functions covered (address list)
- `0x97818D`, `0x977FFB`, `0x5CA14D`, `0x71F913`
- `0x5BEC86`, `0x5BECC0`, `0x5BEE39`, `0x5BFA0A`, `0x5BFA43`, `0x5C0095`, `0x5C02AA`, `0x5C0753`, `0x5C0798`, `0x5C0894`, `0x5C12BF`, `0x5C157A`, `0x5C1611`, `0x5C15DF`
- `0x5BF1B3`, `0x5BF25F`, `0x5BF3C0`, `0x5BF5BD`, `0x5BF6F9`, `0x5BF711`
- `0x5C0E98`, `0x5C0F18`, `0x5C1030`, `0x5C107A`, `0x5C10E1`, `0x5C1136`, `0x59F04D`, `0x70F346`, `0x72964B`, `0x729701`, `0x72975F`, `0x72991D`, `0x729970`, `0x7299A8`, `0x729A24`, `0x72AB7A`, `0x730EF4`, `0x7322B5`, `0x743780`, `0x7453F6`, `0x702DE4`, `0x5BE35F`, `0x58F806`

## Runtime wiring status (Godot `map_view.gd` / `c_map_action_bomb.gd`)
- **All decoded runtime tile rules wired (21/21):**
  - `Ground (0)`: 2-phase conveyor center-pull (`b[16]`) + push-out (`b[20]`) at `b[12]` px/tick (`0x5BFA43`) + conveyor walk anim direction (`0x5BFA0A` -> `0x593737`). Note: `b[24]` (`is_special_ground` on `IslandA*`) is unused metadata (never read in `CGOTileGround::Init` `0x5C02AA` or runtime).
  - `Static (1)`: wall move-block & flame-block (`0x5C157A`, `0x72991D`), `custom_static_id` capture mapping (`10001..10199` -> `Tile15_Static/Aft%02d`, `0x5C15DF`/`0x743780`/`0x7453F6`, `capture_static_tile()`).
  - `Box (2)`: multi-HP (`b[4]`), indestructible (`hp >= 255`), 15-tick shake/crack states (`0x5BF1B3`/`0x5BF5BD`), pushable `CGOTileMoveAbleBox` (`b[8]`, 0.30s slide, crushes items, moves spike mask `0x729701`, can enter separate `CGOTilePassable` layer and hide inside bush/tent `0x5C0C2E`), chain-explode `ExplodeBlock01` (`b[13]`, `0x7322B5`), directional spike faces (`b[12]`, `0x7299A8`: kick 0.3s fuse `0x702DE4` & slide-stop explode `0x5BE35F`).
  - `Passable (3)`: separate `_passable_tiles`/`_passable_objects` layer (`sub_7293B4`), 4-dir player entry/exit (`b[4..7]`, `0x5C0E98`), 4-dir bomb pass (`b[8..11]`, `0x5C1030`), 4-dir flame pass (`b[12..15]`, `0x5C10E1`), bomber/item/bomb concealment & reveal (`b[16]`, `b[17]`, `b[19]==0`, `0x59F04D`), `draw_under_player` (`b[20]`, `0x71F938`), shake (`ShakenHorz`/`ShakenVert`) + SFX (`Obj_Tent` 158 / `Obj_Herb` 63, `0x5C1175`) on every player/bomb/box entry (including bush-to-bush), flame burn/permanence (`b[24]`, `0x70F346`), omni-spike bomb detonation (`b[18]!=0` `PinTile01`, `0x58F806`).

## UNKNOWN
- `type == 1` (`Static`) `b[12] == 1` (present on 161 tiles like `Rock10`, `Z_Candlelight`, `Temple01..11`): never read by `CGOTileStatic` (`0x5C157A..0x5C16C0`) or any of the 20 callers of `sub_729293`; the `type == 1` branch of `CPlayMap::LoadMap` (`0x736449`) is obscured by anti-disassembly bytes (`UNKNOWN`, treat as normal static wall until verified).
