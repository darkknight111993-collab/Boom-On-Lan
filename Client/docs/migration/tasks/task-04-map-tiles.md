# Task 04: Map Tile Class Hierarchy (`CTileInfo` + `CGOTile*`)

## Goal
Replace flat `_cell_objects` tile dictionaries in `Client/scripts/map_view.gd` with the exact tile attribute loader (`CTileInfo`) and runtime inheritance hierarchy (`CGOTile*`) from `ca_unpacked.exe.i64`, supporting multi-hit boxes, indestructible boxes (`hp >= 255`), pushable boxes (`CGOTileMoveAbleBox`), chain-exploding boxes (`explode_on_break`), passable bush concealment (`byte +19`) & burnability (`byte +24`), and separate movement-block vs flame-block grids.

## Original Addresses & Classes in Scope
- **`CMapObjToTileInfo`** (`0xe54e08`): `0x97818D` (`LoadFile`), `0x977FFB` (`ParseXml`, 52-byte tagged union in `Client/data/tile_info.json`)
- **`CGOTile`** (`0xe241c4`): `0x5BEC86` (ctor), `0x5BECC0` (dtor)
- **`CGOTileGround`** (`0xe303c4`, `type == 0`): `0x5C0095` (ctor)
- **`CGOTileFixed`** (`0xe241a8`): `0x5BEE39` (ctor)
- **`CGOTileStatic`** (`0xe2418c`, `type == 1`): `0x5C157A` (ctor), `0x5C1611` (`Init`)
- **`CGOTileFixedBox`** (`0xe2fdf0`, `type == 2 & b[8] == 0`): `0x5BF25F` (ctor), `0x5BF3C0` (`Init`), `0x5BF6F9` (`IsIndestructible`: `hp >= 255`), `0x5BF711` (`OnHit`), `0x5BF5BD` (`Update`: 15-tick flash & `explode_on_break` `b[13]` -> `0x7322B5`)
- **`CGOTileMoveAbleBox`** (`0xe30498`, `type == 2 & b[8] == 1`): `0x5C0798` (dtor), `0x730EF4` (`CPlayMap::PushMoveAbleBox`)
- **`CGOTilePassable`** (`0xe304bc`, `type == 3`): `0x5C12BF` (ctor), conceal `b[19] == 0` (`0x59F04D`), burnable `b[24] == 0` (`0x70F346`)
- **`CPlayMap` grids**: `0x72991D` (`SetFlameBlocked`), `0x729970` (`IsFlameBlocked`), `0x729616` (`SetMoveBlocked`)

## Expected Spec File
- `docs/migration/specs/map_tiles.md` (written by `/analyst` before `/porter` edits code; must also resolve remaining `UNKNOWN`s on `type=1 b[12]` and `type=2 b[12]`)

## Files Allowed to Edit (during `/porter` + `/godot-adapter`)
- `Client/scripts/objects/ctile_info.gd` (new: `Resource` + static loader for `res://data/tile_info.json`)
- `Client/scripts/objects/cgo_tile.gd` (new: `class_name CGOTile extends CGameObject`)
- `Client/scripts/objects/cgo_tile_ground.gd` (new: `extends CGOTile`)
- `Client/scripts/objects/cgo_tile_fixed.gd` (new: `extends CGOTile`)
- `Client/scripts/objects/cgo_tile_static.gd` (new: `extends CGOTileFixed`)
- `Client/scripts/objects/cgo_tile_fixed_box.gd` (new: `extends CGOTileFixed`)
- `Client/scripts/objects/cgo_tile_movable_box.gd` (new: `extends CGOTile`)
- `Client/scripts/objects/cgo_tile_passable.gd` (new: `extends CGOTileFixed`)
- `Client/scripts/map_view.gd` (instantiate `CGOTile*` per tile type and maintain separate movement-block & flame-block grids)
- `Client/tools/test_map_tiles.gd` (new headless unit test)

## Acceptance Criteria
1. `CTileInfo` parses all 3,369 entries in `tile_info.json` with exact field extraction (`type`, `width`, `height`, `hp`, `is_movable`, `explode_on_break`, `conceals_bomber`, `indestructible_by_flame`).
2. `CGOTileFixedBox` supports multi-hit HP (`StrongBox01` = 5 hits, `StrongBox02` = 2 hits, default = 1 hit), `hp >= 255` indestructible (`PuzzleUnmovablebox`), 15-tick hit-flash, and `explode_on_break` signal.
3. `CGOTileMoveAbleBox` supports pushing to an empty adjacent cell, updating flame-block/move-block grids, and crushing ground items.
4. `CGOTilePassable` distinguishes concealing (`b[19] == 0`) vs transparent (`b[19] == 1`) and burnable (`b[24] == 0`) vs permanent (`b[24] == 1`).
5. All headless tests pass with 0 regressions (`test_map_tiles.gd`, `test_bomber_hierarchy.gd`, `test_airship_logic.gd`, `test_airship_stage.tscn`, `test_bomb_objects.gd`).

## Golden Test Cases Needed (`docs/migration/golden/map_tiles.md`)
- Multi-hit box (`StrongBox02` = 2 hits, `StrongBox01` = 5 hits) hit-flash and break behavior in the original client.
- Pushing a `MoveAbleBox` onto an empty cell vs onto a ground item vs into a bush (`Herb00`).
- Flame propagation through a passable bush (`Herb00`, burns) vs permanent passable tile (`TentBlue` / `Icewater00`, stays) vs low static tile (`b[12] == 1` if flame-passable).
