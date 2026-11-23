# Task 03: Bomber Class Hierarchy (`CBomberAttr` + `CGOBomberBase` -> `CGOBomber` -> `CGOGameBomber`)

## Goal
Split the current monolithic `Client/scripts/objects/cgo_bomber.gd` into the exact class hierarchy verified in `ca_unpacked.exe.i64`, so all players (1P, 2P, remote, AI) share one character attribute table and one inheritable runtime hierarchy ready for future game-mode subclasses (`CGOMonGameBomber`, `CGOZombieBomber`, `CGOSquareBomber`, `CGODisplayBomber`, etc.).

## Original Addresses & Classes in Scope
- **`CBomberAttr`** (`.?AVCBomberAttr@@` @ `0xe5471c`, singleton `dword_E60844`):
  - `0x971B9A` (ctor), `0x97124A` (`Load` `"Attr/BomberAttr"`), `0x9710C1` (`BomberAttr[43]` array ctor, 412 bytes/entry)
  - `0x971A0F` (`GetInitSpeed`), `0x971A6C` (`GetInitBomb`), `0x971AC9` (`GetInitPower`)
  - `0x9715E8` (`GetMaxSpeed`), `0x971604` (`GetMaxBomb`), `0x971620` (`GetMaxPower`)
- **`CGOBomberBase`** (`.?AVCGOBomberBase@@` @ `0xe225a8`, vtable `0xc33cbc`):
  - `0x592A2B` (ctor, inherits drawable map entity `sub_58EC45`)
  - `0x594E07` (`SetVisible`), `0x594E17` (`GetVisible`), `0x59F107` (`IsVisible`, `vtable[117]`, checks bush concealment `0x59F04D` + `m_bVisible`)
- **`CGOBomber`** (`.?AVCGOBomber@@` @ `0xe22590`, vtable `0xc348ec`):
  - `0x5A3F7D` (ctor), `0x5A6244` (`Update`), `0x5A700B` (`Render`) — shared movement, collision, mounts (`CGOShip`), bubble, debuffs, visuals
- **`CGOGameBomber`** (`.?AVCGOGameBomber@@` @ `0xe22574`, vtable `0xc359a0`):
  - `0x5B231F` (ctor), `0x5AF829` (dtor), `0x5AE4DA` (`OnMatchEvent`, `off_C356D4` -> `SetVisible(1)`)
  - `0x5B0053` (`PlaceOrThrowBomb`, packet `115`), `0x5B19B3` (`MultiBombAction`, `0x1A` cooldown, packet `209`), `0x5B1D7B` (`DeferBombOper`)
  - Network boundary: server -> `CGOGameBomber` packet dispatch stays in `CGameStage` / `CGameMsgCache` (`0x6F4FD1`), not inside `CGOGameBomber`.

## Expected Spec File
- `docs/migration/specs/bomber_hierarchy.md` (written by `/analyst` before `/porter` touches code)

## Files Allowed to Edit (during `/porter` + `/godot-adapter`)
- `Client/scripts/objects/cbomber_attr.gd` (new: `Resource` + static table loader from `res://data/bomber_attr.json`)
- `Client/scripts/objects/cgo_bomber_base.gd` (new: `class_name CGOBomberBase extends Node2D`)
- `Client/scripts/objects/cgo_bomber.gd` (refactor: `extends CGOBomberBase`, load base stats via `CBomberAttr`)
- `Client/scripts/objects/cgo_game_bomber.gd` (new: `class_name CGOGameBomber extends CGOBomber`, owns match bomb/action cooldown & match hooks)
- `Client/scripts/map_view.gd` (spawn `CGOGameBomber` for match players)
- `Client/tools/test_bomber_hierarchy.gd` (new headless unit test)

## Acceptance Criteria
1. `CBomberAttr` loads all entries from `Client/data/bomber_attr.json`, enforces `bomb_max <= 10` (`0x9714c5`), and resolves the 4 UI/sprite paths (`Prepare/%s`, `_Display`, `_Portrait`, `_Emotion`).
2. Exact inheritance chain in GDScript: `Node2D` -> `CGOBomberBase` -> `CGOBomber` -> `CGOGameBomber` (using `preload` constants for headless CLI compatibility).
3. `map_view.gd` spawns `CGOGameBomber` for all match players (1P/2P/AI) with stats initialized from `CBomberAttr`.
4. All headless tests pass with 0 regressions:
   - `godot --headless --path Client --script res://tools/test_bomber_hierarchy.gd`
   - `godot --headless --path Client --script res://tools/test_airship_logic.gd`
   - `godot --headless --path Client res://scenes/test_airship_stage.tscn`
   - `godot --headless --path Client --script res://tools/test_bomb_objects.gd`

## Golden Test Cases Needed (`docs/migration/golden/bomber_hierarchy.md`)
- Starting stats (`speed`, `bomb`, `power`) and caps (`speed_max`, `bomb_max`, `power_max`) for at least 2 characters (e.g., `Character/C00` Bazzi and `Character/C01` Dao/Marid) in the original client.
- Bomb placement cooldown behavior when spamming Space (`0x1A` guard in `0x5B19B3`).
