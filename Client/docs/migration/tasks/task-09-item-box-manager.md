# Task 09: Active Item Box (`CGOItemBox`) & Match Item Manager (`CGameItemMan`)

## Goal
Standardize all active/usable in-match items (Needle family, Oxygen, Dart, Shield, Potion, Banana, Bond, Mine, Pushpin, Scanner, Spring, Drill, RemoteBomb, etc.) into the original client's two-class architecture — **`CGOItemBox`** (per-bomber 24-slot active item box) and **`CGameItemMan`** (match-level item & ground-trap coordinator) — instead of scattered `*_count` variables on `CGOBomber` and inline dictionaries in `map_view.gd`.

## Scope (IDA Addresses in `AnalizeVNClient/ca_unpacked.exe.i64`)
- **`CGOItemBox`** (`.?AVCGOItemBox@@` @ `0xe30044`, `CGOBomber::this[655]`):
  - `0x5B70E6` (slot accessor), `0x5B7BA3` (slot validity), `0x5B76BC` (active/lock check), `0x5B763E` (clear active state)
  - `0x5B8396` (`FindItemSlot` across 24 slots `0..23`), `0x5B7F91` (`SelectSlot` `this[334]`), `0x5B872A` (`SelectItemByName`), `0x5B87B1` (`UseSelectedItem`), `0x5B85BD` (`GetSelectedSlot`)
- **`CGOBomber` context auto-select hooks:**
  - `0x59B51B` (`TrySelectNeedle` — full Needle variant list)
  - `0x59B6F6` (`TrySelectItemByName`)
  - `0x59E53F` (`OnTrappedInBubble` — Needle -> Oxygen -> CpNiddle priority)
  - `0x5A517F` (match start auto-select: Scanner -> Dart)
- **`CItemMan` -> `CGameItemMan`** (`.?AVCItemMan@@` @ `0xe48008`, `.?AVCGameItemMan@@` @ `0xe47fec`):
  - `0x89DB3A` (`CItemMan` ctor), `0x89D95B` (dtor), `0x89B145` (`CanTriggerGroundTrap`), `0x89B623` (`ExecuteGroundTrap`), `0x89B21F` (`CanUseActiveItem`)
  - `0x889DA8` (`CGameItemMan` ctor), `0x889E0B` (`UseActiveItem` dispatch)
  - `item_attr.json` `item_type` (`fields[2]`) dispatch table (`11`=Ground trap, `21`=Dart, `22`=Oxygen, `23`/`45`/`46`=Needle variants, `25`=Potion, `29`=Shield, `41`/`42`=Hedgehog items, etc.)

## Out of Scope (Deferred)
- `CUserItemMan` (`0xe487fc`) / `CItemInventoryNew` (`0xe483c8`) persistent shop/account inventory & database sync (future Shop/Account wave).
- Network packets for item use (`CGameClientPacket` / `CGameServerPacket`, future LAN wave).

## Allowed Files
- Spec: `docs/migration/specs/item_box_manager.md` (+ mirror `Client/docs/migration/specs/item_box_manager.md`)
- New Godot classes:
  - `Client/scripts/objects/cgo_item_box.gd` (`class_name CGOItemBox extends RefCounted`)
  - `Client/scripts/objects/c_game_item_man.gd` (`class_name CGameItemMan extends RefCounted`)
- Refactored callers (keep backwards-compatible property accessors so existing tests keep passing):
  - `Client/scripts/objects/cgo_bomber.gd` (owns `var item_box: CGOItemBox`, delegates `apply_item`, `needle_count`/`dart_count`/`oxygen_count`/`banana_count`/`bond_count`/`mine_count`/`pushpin_count`, `get_quick_item_hud()`, `get_inventory_slots()`)
  - `Client/scripts/map_view.gd` (owns `var _game_item_man: CGameItemMan`, delegates `_ground_traps`, `place_ground_trap()`, `_check_ground_trap()`, `_trigger_player_quick_action()`, `_use_player_inventory_slot()`)
- Tests:
  - `Client/tools/test_item_box_manager.gd` (new headless suite `TV-I1..TV-I8`)
  - Update `docs/migration/parity_matrix.md` (+ mirror)

## Execution Phases
1. **`/analyst`**: Decompile `0x5B70E6`, `0x5B7BA3`, `0x5B877C`, `0x5B836B`, and `CItemMan` `item_type` dispatch in IDA; write `docs/migration/specs/item_box_manager.md` with exact 24-slot layout, Needle/Oxygen/Dart auto-select rules, `item_type` table, and `TV-I1..TV-I8`.
2. **`/porter`**: Implement `CGOItemBox` and `CGameItemMan`, refactor `cgo_bomber.gd` and `map_view.gd` to delegate cleanly while preserving compatibility properties, and add `Client/tools/test_item_box_manager.gd`.
3. **Verify**: Run `test_item_box_manager.gd` + full headless regression (`test_bomber_hierarchy.gd`, `test_map_tiles.gd`, `test_bomb_objects.gd`, `test_airship_logic.gd`, `test_game_mode_component.gd`, `test_lobby_flow_mock.gd`, `test_dynamic_map_man.gd`) + `scenes/game_stage.tscn` smoke check.

## Acceptance Criteria
- `CGOItemBox` models 24 slots (`0..23`), `selected_slot`, `find_item_slot()`, `select_item_by_name()`, `add_item()` (with charge counts from `CItemAttr`), `use_selected_item()`, and context auto-select (`on_trapped_in_bubble`: Needle family -> Oxygen; `on_match_start`: Scanner -> Dart).
- `CGameItemMan` owns ground-trap placement/trigger (`Bond`/`Mine`/`Banana`/`Pushpin`) and unified active-item execution for `CGOBomber`.
- `CGOBomber` no longer duplicates trap/consumable selection logic; `map_view.gd` delegates trap storage and item-use dispatch to `CGameItemMan`.
- All new (`TV-I1..TV-I8`) and existing headless test suites pass with exit code 0.
