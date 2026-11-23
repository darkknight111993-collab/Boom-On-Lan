# Architecture Mapping: Original Client -> Godot 4

- **Analysis source (read-only):** `\AnalizeVNClient` (`ca_unpacked.exe.i64`, `ca.exe.c` [IDA Pro], `ca.exe.g.c` [Ghidra])
- **RE tool:** `ida-pro` MCP (`idalib-mcp` headless on `ca_unpacked.exe.i64`; REA is not used)
- **Target project:** `\Client` (`project.godot`, 800x600, `TEXTURE_FILTER_NEAREST`); **language:** GDScript (static typing)
- **Tick rate / update order:** Fixed 30 ms tick (`TICK_SEC = 0.03`, `0x1E` ms in `ca_unpacked.exe`), accumulated in `_process` / `_physics_process` (`Client/scripts/map_view.gd`).
- **Data strategy:** Decoded `Client/data/*.json` (`item_attr.json`, `objecttable.json`, `tile_info.json`, `bomber_attr.json`, `map_group.json`) + `Client/Assets/fx/Map/<MapName>/map.json`.
- **Headless test command:**
  - Single test: `godot --headless --path Client --script res://tools/<test_script>.gd`
  - Example (verified): `godot --headless --path Client --script res://tools/test_bomb_objects.gd`
  - Scene test: `godot --headless --path Client res://scenes/<test_scene>.tscn`

## Subsystem Mapping (Wave 1 Focus: Map + Airship/UFO Item Test Stage)

| Original subsystem | Key functions / classes (VN `ca_unpacked.exe.i64`) | Godot equivalent (`Client/`) | Headless-testable? |
| :--- | :--- | :--- | :--- |
| Item & Mount Attributes | `CItemAttr` (`0x89F3DE` load `Attr/ItemAttr`, `0x8D8DA0`) | `Client/scripts/objects/citem_attr.gd` + `Client/data/item_attr.json` | Yes (`RefCounted`) |
| Ground Item Entity | `CGOItem` (`.?AVCGOItem@@`) | `Client/scripts/objects/cgo_item.gd` (logic decoupled from bobbing visual) | Partial (needs pure logic split) |
| Bomber & Shared Mount System | `CGOBomber` (`0x5992A0`, `0x59F248`, `0x5AF1D0`, `0x59937D`, `0x59EC93`), `CGOShip` (`.?AVCGOShip@@` @ `0xe30264`: `0x5BC4E0`, `0x5BC742`, `0x5BC88E`), `CShipAttr` (`.?AVCShipAttr@@` @ `0xe4853c`) | `Client/scripts/objects/cship_attr.gd` (`Resource`), `Client/scripts/objects/cgo_ship.gd` (`RefCounted`), `Client/scripts/objects/cgo_bomber.gd` (`specs/ship_mounts.md`) | Yes (pure static helpers + headless stage) |
| Map / Tile Collision | `CPlayMap` / `CGOTileFixedBox` / `kCGOBomber_IsMovableGrid` (`0x8FB6FE` hooks) | `Client/scripts/map_view.gd` (`get_tile_kind`, `tile_type`) + `Client/data/tile_info.json` | Yes (via headless scene/script) |
| Airship Test Stage (Sandbox) | Isolated test map + all 11 mounts (`CShipAttr` ids 1..12) | `Client/Assets/fx/Map/TestAirship01/map.json` + `Client/scenes/test_airship_stage.tscn` + `Client/tools/test_airship_stage.gd` | Yes (headless + playable in Godot) |
| Bomber Character Attributes | `CBomberAttr` (`TSingleton<CBomberAttr>`, `0xe5471c`, ctor `0x971B9A`, load `0x97124A` `"Attr/BomberAttr"`, 43 × 412B) | `Client/scripts/objects/cbomber_attr.gd` (`Resource` + table loader) + `Client/data/bomber_attr.json` | Yes (`RefCounted`/`Resource`) |
| Bomber Class Hierarchy (Wave 2) | `CGOBomberBase` (`0x592A2B`) -> `CGOBomber` (`0x5A3F7D`, vtable `0xc348ec`) -> `CGOGameBomber` (`0x5B231F`, dtor `0x5AF829`, vtable `0xc359a0`) | `cgo_bomber_base.gd` -> `cgo_bomber.gd` -> `cgo_game_bomber.gd` (mode subclasses inherit from `CGOGameBomber`; no per-character subclasses) | Yes (headless unit + stage tests) |
| Map Tile Attributes & Hierarchy (Wave 3) | `CMapObjToTileInfo` (`0x97818D` -> `0x977FFB`), `CGOTTile` (`0xe30364`), `CGOTile` (`0x5BEC86`) -> `CGOTileGround` (`0x5C0095`), `CGOTileMoveAbleBox` (`0x5C0798`), `CGOTileFixed` (`0x5BEE39`) -> `CGOTileStatic` (`0x5C157A`), `CGOTileFixedBox` (`0x5BF25F`/`0x5BF3C0`/`0x5BF711`), `CGOTilePassable` (`0x5C12BF`) | `Client/scripts/objects/ctile_info.gd` (`Resource` + loader for `tile_info.json`), `cgo_tile.gd` -> `cgo_tile_ground.gd`, `cgo_tile_fixed.gd` -> `cgo_tile_static.gd`, `cgo_tile_fixed_box.gd`, `cgo_tile_passable.gd`, `cgo_tile_movable_box.gd` | Yes (headless unit + stage tests) |
| Game Mode Components (Wave 4) | `CComponent` (`0xe239b0`, ctor `0x73D1FF`, `0x73B7B1`, `0x73B7B5`), `CGameStage::GetComponent` (`0x70A304`), `CDefaultComponent` (`0xe23990`), `CHedgehogComponent` (`0xe40b00`, ctor `0x74900D`, ID `11`), plus 5 `CComponentAddOn*` (`AI`, `Monster`, `Revival`, `SpecialTile`, `Skill`) | `Client/scripts/modes/c_component.gd` (`RefCounted`) -> `c_default_component.gd`, `c_hedgehog_component.gd` (wired into `map_view.gd`) | Yes (`RefCounted`, headless unit tests) |
| Channel Select & Lobby Flow | `CSelectServerStage` (`0x854E1D`, `0x857C23`, `0x8585B8`, `0x858AB4`, `0x66F70C`), `CLobbyStrategy` factory (`0x6B5F29`, 9 subclasses), `BuildCreateRoomGameTypeList` (`0x6277FC`) | `Client/scripts/modes/c_lobby_flow.gd` (`RefCounted`) + `Client/data/channels.json` + `Client/data/mock_lobby_flow.json` + `Client/scripts/screen.gd` | Yes (`RefCounted`, `test_lobby_flow_mock.gd`) |
| Map Catalog & Mode Filtering | `CDynamicMapMan` (`0xE3E3B8`, `0x6E077C` `fxdynmapinfo.ssd`, `0x6E0D2C`, `0x6DEE48`, `0x6DD516`), `CMapSelectDialog` (`0x648E3D`), `MapSelect_PlayerLimitOver` (`0x68B85D`) | `Client/scripts/modes/c_dynamic_map_man.gd` (`RefCounted`) + `Client/data/game_modes.json` + `Client/data/map_group.json` | Yes (`RefCounted`, `test_dynamic_map_man.gd`) |
| Active Items, Quick-Slot & Personal Inventory (Wave 5) | `CGOItemBox` (`0xe30044`, `CGOBomber::this[655]`, `0x5B70E6..0x5B8860`: 24 slots, active slot `this[334]`, auto-select `0x59B51B`/`0x59E53F`/`0x5A517F`), `CItemMan` (`0xe48008`, `0x89DB3A`) -> `CGameItemMan` (`0xe47fec`, `0x889DA8`, `0x889E0B`, `0x89B145`/`0x89B623`), `CUserItemMan` (`0xe487fc`, `0x8C0623`) | `Client/scripts/objects/cgo_item_box.gd` (`RefCounted` on `CGOBomber`) + `Client/scripts/objects/c_game_item_man.gd` (`RefCounted` on `map_view.gd`) + future `c_user_item_man.gd` | Yes (`RefCounted`, headless unit tests) |
| Shop, Catalog & Account Inventory (Wave 6) | `CShopStageNew` (`0xe44fb0`, `0x807303`, `0x85C174`), `CShopItemMan` (`0xe48660`, `0x8B1D42`), `CUserItemMan` (`0xe487fc`, `0x8C07AC`), `CUserInventoryMan` (`0xe48740`, `0x8BA9DF`), `CGOShopBomber` (`0xe448e4`, `0x7EECF2`) + `CShopAction*` (`0xe44900..0xe44ab0`), `CShopBuyDlg`/`CShopRentDlg`/`CShopPresentDlg` | `Client/scripts/modes/c_shop_item_man.gd`, `Client/scripts/modes/c_user_inventory_man.gd`, `Client/data/shop_catalog.json`, `Client/data/screens/shop.json`, `Client/scenes/shop.tscn` | Yes (`RefCounted` catalog/inventory + headless tests) |
| Character Cosmetics & 13-Slot Decoration Renderer (Wave 6B) | `CGOBomber` 13-slot equip loop (`0x5A517F` -> `0x8D4A0F` -> `0x58E7AA`, `0x58F6EF` -> `0x58F557` -> `0x58EE0D`), `AvatarDeco` / `CharDeco` / `IDDeco` / `BombDeco` | `Client/scripts/objects/cgo_bomber_cosmetics.gd` (`RefCounted`/layer helper on `CGOBomber`) + `SpriteDB.resolve_sprite_dir()` (already supports `charte/` & `emote/`) | Yes (pure layer/path resolver + `--write-movie` visual check) |

## Map Tile Class Hierarchy (Wave 3, Verified from `ca_unpacked.exe.i64` RTTI)

```text
CTileInfo (Resource / table loader: Client/data/tile_info.json, 52-byte tagged union by type 0..4)

CGameObject (sub_58D298)
 └── CGOTile (0xe241c4, ctor 0x5BEC86)
      ├── CGOTileGround (0xe303c4, ctor 0x5C0095, type=0) — ground / rail / ice / conveyor
      ├── CGOTileMoveAbleBox (0xe30498, dtor 0x5C0798, type=2 & b[8]==1) — pushable box (0x730EF4)
      └── CGOTileFixed (0xe241a8, ctor 0x5BEE39) — stationary grid obstacles
           ├── CGOTileStatic (0xe2418c, ctor 0x5C157A, type=1) — unbreakable wall (+ Button/Reactive/Lucci/Fishing)
           ├── CGOTileFixedBox (0xe2fdf0, ctor 0x5BF25F, init 0x5BF3C0, type=2 & b[8]==0) — breakable box (HP b[4], >=255 indestructible 0x5BF6F9, explode_on_break b[13] 0x5BF5BD)
           └── CGOTilePassable (0xe304bc, ctor 0x5C12BF, type=3) — passable bush/tent/water (conceal b[19]==0 0x59F04D, burnable b[24]==0 0x70F346)
```

## Player Character Class Hierarchy (Verified from `ca_unpacked.exe.i64` RTTI)

All players on the map share ONE data table (`CBomberAttr`) and ONE runtime inheritance chain. Characters (Bazzi, Dao, Marid, etc.) are data rows (`Character/C00..C42`), **not** subclasses. Subclasses exist only per **game mode / context**:

```text
CBomberAttr (Resource / Singleton loader: Client/data/bomber_attr.json, 43 entries)

Node2D
 └── CGOBomberBase (0xe225a8, ctor 0x592A2B) — base map entity transform/sprite root
      └── CGOBomber (0xe22590, ctor 0x5A3F7D) — shared movement, collision, mounts (CGOShip), bubble, debuffs, visuals
           ├── CGOGameBomber (0xe22574, ctor 0x5B231F) — match + network layer (all 1P/2P/remote/AI players in normal matches)
           │    └── Mode subclasses (future waves): CGOMonGameBomber, CGOZombieBomber, CGOCaptainBomber, CGOSurvivalBomber, ...
           ├── CGOSquareBomber / CGOLobbySquareBomber (future: lobby/square)
           └── CGODisplayBomber (future: UI preview)
```

## Game Mode Component Hierarchy (Wave 4, Verified from `ca_unpacked.exe.i64` RTTI)

```text
CGameStage (std::list<CComponent*> @ this[5413], lookup sub_70A304)
 └── CComponent (0xe239b0, ctor 0x73D1FF, GetType 0x73B7B1, GetGameStage 0x73B7B5)
      ├── CDefaultComponent (0xe23990) — Classic match rules (uses CGOGameBomber)
      ├── CHedgehogComponent (0xe40b00, ctor 0x74900D, id=11) — Hedgehog mode (uses CGOHedgehogBomber)
      └── Other modes (future waves): CSurvivalComponent, CCaptainComponent, CZombieComponent,
          CTimebombComponent, CMonsterComponent, CStageClearComponent, CIamBossComponent,
          CSuperFighterComponent, CKartComponent (id=1), CZzolmanComponent (id=19), CSnowBearComponent (id=33), ...

Horizontal AddOns (composed by modes as needed):
  CComponentAddOnAI (0xe43008), CComponentAddOnMonster (0xe23f48),
  CComponentAddOnRevival (0xe23f20), CComponentAddOnSpecialTile (0xe255d4), CComponentAddOnSkill (0xe4351c)
```

## Active Item & Inventory Class Hierarchy (Wave 5, Verified from `ca_unpacked.exe.i64` RTTI)

```text
CItemAttr (0xe48524) — static item/ship table (Client/data/item_attr.json)

CGOBomber (this[655])
 └── CGOItemBox (0xe30044, 0x5B70E6..0x5B8860) — per-bomber 24-slot active item box
      • Auto-selects context items: Needle family (0x59B51B), Oxygen/CpNiddle (0x59E53F), Scanner/Dart (0x5A517F)
      • Drives HUD: Game/ItemBox01 (1P L-Ctrl / 2P Ctrl-R) & Game/GameStageItem (1..6 personal bar)

CItemMan (0xe48008, ctor 0x89DB3A, dtor 0x89D95B) — 1000-slot map item table + trap execution (0x89B145 / 0x89B623)
 └── CGameItemMan (0xe47fec, ctor 0x889DA8, 0x889E0B) — in-match item usage & server/offline dispatch

TSingleton<CUserItemMan> (0xe487fc, 0x8C0623) + CItemInventoryNew (0xe483c8) + CItemBoxOwner (0xe25028)
 └── Account/lobby inventory -> loads equipped personal items into CGOItemBox at match start (future wave)
```

## Shop & Account Inventory Hierarchy (Wave 6, Verified from `ca_unpacked.exe.i64` RTTI)

```text
CShopItemMan (0xe48660, ctor 0x8B1D42, dtor 0x8B2AD6) — shop catalog, categories, Lucci/Cash prices, search/filter
TSingleton<CUserItemMan> (0xe487fc, ctor 0x8C07AC) — owned UserItem records, equip/unequip state
TSingleton<CUserInventoryMan> (0xe48740, ctor 0x8BA9DF) + CItemInventoryNew (0xe483c8) — bag slots & 6 match personal slots

CShopStageNew (0xe44fb0, ctor 0x807303, UI init 0x85C174) — 800x600 Shop screen
 ├── 5 Main Tabs: S_TabSpecial, S_TabItem, S_TabSet, S_TabChar, S_TabSlot
 ├── Currency / Actions: S_BtCash, S_BtLucci, S_BtBuy, S_BtRent, S_BtGet, S_BtSearch, S_BtUndo, S_BtHide
 ├── Dialogs: CShopBuyDlg (0xe33b4c), CShopRentDlg (0xe33c28), CShopPresentDlg (0xe33a58), CItemSearchDlg (0xe27bd4)
 └── Live Preview: CGOShopBomber (0xe448e4, ctor 0x7EECF2, extends CGOBomber) + CShopAction* (0xe44900..0xe44ab0)
```
