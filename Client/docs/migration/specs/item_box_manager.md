# Active Item Box (`CGOItemBox`) & Match Item Manager (`CGameItemMan`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + decoded `Client/data/item_attr.json`.
> **Rule:** Active/consumable in-match items (Needle family, Oxygen, Dart, Shield, Potion, Banana, Bond, Mine, Pushpin, etc.) are owned per-bomber by **`CGOItemBox`** (`CGOBomber::this[655]`), while match-level item effects and ground-trap execution are coordinated by **`CItemMan` -> `CGameItemMan`**.

## Behavior summary
1. **`CGOItemBox`** (`.?AVCGOItemBox@@` @ `0xe30044`, `0x5B70E6..0x5B8860`) holds up to **24 active item slots (`0..23`)** per bomber, each storing an item record (`name`, `item_type`, `category`) and remaining charge count (`0x5B75BD`).
2. **Two-tier active slot selection (`0x5B836B`):**
   - `context_slot` (`this[334]` @ `+1336`, set by `0x5B7F91` / `0x5B872A`): temporary context-auto-selected slot (e.g. Needle or Oxygen when trapped in a bubble, Dart/Scanner at match start).
   - `manual_slot` (`this[335]` @ `+1340`, set by `0x5B877C` + 24-entry circular history ring `this[232..303]` @ `0x5B84CB`): user's manually chosen quick-item slot.
   - `get_active_slot()` (`0x5B836B`): if `context_slot` is still valid (`0x5B7BA3`), return `context_slot`; otherwise clear `context_slot = -1` and fall back to `manual_slot`.
3. **Context auto-select rules on `CGOBomber`:**
   - **On trapped in bubble (`0x59E53F` -> `0x59B51B`):** tries to select any Needle variant (`Item/ItemNiddle`, `Item/ItemSJNeedle1..7`, `Item/ItemCokeNeedle`, `Item/ItemNeedle*`, `Item/ItemNiddleplus`, `Item/WinningNeedle*`); if none available, falls back to `Item/ItemOxygen` (and checks teammate `Item/ItemCpNiddle` in team/couple modes).
   - **On match start (`0x5A517F`):** tries to select `Item/ItemScanner`; if absent, falls back to `Item/ItemDart`.
4. **`CItemMan` (`0xe48008`, `0x89DB3A`) -> `CGameItemMan` (`0xe47fec`, `0x889DA8`, `0x889E0B`):**
   - Owns match ground traps (`Bond=1`, `Mine=2`, `Banana=3`, `Pushpin=4`), validates trigger guards (`0x89B145`: Bond/Banana skip flying, Mine skips shielded, Pushpin skips bombers), and executes ground-trap effects (`0x89B623`).
   - Coordinates active item usage (`0x889E0B` -> `0x89B21F`: rejects if locked/dead, otherwise invokes bomber's active item effect).
5. **HUD projection (`Game/ItemBox01` & `Game/GameStageItem`):**
   - `Ctrl` quick-item box (`Game/ItemBox01` at `647, 466`) displays `get_active_slot()` (sprite + remaining charges).
   - 6-slot personal bar (`Game/GameStageItem` at `152, 564`) maps keys `1..6` to the bomber's personal item slots (`Needle`, `Oxygen`, `Dart`, `Banana`, `Bond`, `Mine`).

## Class / state (original class -> Godot class)

### 1. `CGOItemBox` (`0xe30044`) -> `Client/scripts/objects/cgo_item_box.gd` (`extends RefCounted`)
- Constants:
  - `MAX_SLOTS := 24` (`0..23`, `0x5B70E6` / `0x5B8396`)
  - `NEEDLE_ITEM_NAMES: Array[String]` (`0x59B51B`: `"Item/ItemNiddle"`, `"Item/ItemSJNeedle1"`..`"Item/ItemSJNeedle7"`, `"Item/ItemCokeNeedle"`, `"Item/ItemNeedleG"`, `"Item/ItemNeedleC"`, `"Item/ItemNeedleSP"`, `"Item/ItemNeedleE"`, `"Item/ItemNeedleL"`, `"Item/ItemNeedleF"`, `"Item/ItemNiddleplus"`, `"Item/WinningNeedle"`, `"Item/WinningNeedleC"`, `"Item/ItemNeedle_Bazzi"`, `"Item/ItemNeedle_Marid"`, `"Item/ItemNeedle_Uni"`)
- Fields:
  - `var enabled: bool = true` (`this[345]` @ `0x5B7BA3`)
  - `var slots: Array[Dictionary] = []` (24 entries: `{"name": String, "sprite": String, "item_type": int, "param": int, "count": int}`) — maps `this[64..87]` (`0x5B70E6`) + `this + 640 + 12*i` (`0x5B75BD`)
  - `var context_slot: int = -1` (`this[334]` @ `+1336`, `0x5B7F91`)
  - `var manual_slot: int = -1` (`this[335]` @ `+1340`, `0x5B877C`)
  - `var history_ring: Array[int] = []` (up to `24` recent manual slot indices, `0x5B84CB`)
- Methods:
  - `clear() -> void`
  - `get_slot(slot_idx: int) -> Dictionary` (`0x5B70E6`)
  - `get_slot_count(slot_idx: int) -> int` (`0x5B75BD`)
  - `is_slot_valid(slot_idx: int) -> bool` (`0x5B7BA3`: `enabled and slot_idx in 0..23 and count > 0`)
  - `is_excluded_from_cycle(slot_idx: int) -> bool` (`0x5B7582`: `item_type == 12 or item_type == 24`)
  - `find_item_slot(item_name: String) -> int` (`0x5B8396`: scans `0..23`, returns `-1` if missing)
  - `find_slot_by_type(item_type: int, param: int = -1) -> int`
  - `add_item(item_name: String, count: int = -1, item_type: int = -1, param: int = -1, sprite: String = "") -> int` (merges into existing matching slot or first empty slot; pulls default charges/`item_type`/`param`/`sprite` from `CItemAttr` when omitted; updates `manual_slot` if not excluded)
  - `set_item_count(item_name: String, count: int, item_type: int = -1, param: int = -1, sprite: String = "") -> void` (for backwards-compatible `*_count` property setters on `CGOBomber`)
  - `get_item_count(item_name: String) -> int` / `get_count_by_type(item_type: int, param: int = -1) -> int`
  - `select_slot(slot_idx: int) -> bool` (`0x5B7F91`: sets `context_slot`)
  - `select_manual_slot(slot_idx: int) -> bool` (`0x5B877C` + `0x5B84CB`: clears `context_slot`, sets `manual_slot`, pushes to `history_ring`)
  - `select_item_by_name(item_name: String) -> bool` (`0x5B872A`: `find_item_slot` -> `select_slot`)
  - `get_active_slot() -> int` (`0x5B836B`: valid `context_slot` else `manual_slot`, else first valid slot)
  - `try_select_needle() -> bool` (`0x59B51B`: scans `NEEDLE_ITEM_NAMES`)
  - `on_trapped_in_bubble() -> bool` (`0x59E53F`: `try_select_needle()` else `select_item_by_name("Item/ItemOxygen")`)
  - `on_match_start() -> bool` (`0x5A517F`: `select_item_by_name("Item/ItemScanner")` else `select_item_by_name("Item/ItemDart")`)
  - `consume_slot(slot_idx: int) -> Dictionary` (`0x5B87B1`: decrements `count`, clears `context_slot = -1`, returns consumed slot dict `{name, sprite, item_type, param}`)
  - `consume_selected() -> Dictionary` (`0x5B87B1`: consumes `get_active_slot()`)
  - `get_quick_hud_info(in_bubble: bool) -> Dictionary` (`{sprite, count}` for `Game/ItemBox01`)
  - `get_personal_bar_slots() -> Array[Dictionary]` (6 slots for `Game/GameStageItem`: `1=Needle, 2=Oxygen, 3=Dart, 4=Banana, 5=Bond, 6=Mine`)

### 2. `CItemMan` (`0xe48008`) -> `CGameItemMan` (`0xe47fec`) -> `Client/scripts/objects/c_game_item_man.gd` (`extends RefCounted`)
- Fields:
  - `var ground_traps: Dictionary = {}` (`Vector2i -> {"tile": CGOTileGround, "sprite": Sprite2D}`)
- Methods:
  - `clear() -> void` (frees all `CGOTileGround` trap instances and clears `ground_traps`)
  - `can_place_ground_trap(gp: Vector2i, trap_type: int, cols: int, rows: int, tile_kind: int) -> bool` (`0x59AA2B` / `0x5BFE98`)
  - `place_ground_trap(gp: Vector2i, trap_type: int, owner_id: int, ground_info: Variant, map_origin: Vector2, parent_node: Node2D, cell_anchor: Vector2) -> bool` (`0x5BFE98`)
  - `try_place_bomber_trap(bomber: Variant, trap_type: int, cols: int, rows: int, tile_kind: int, ground_info: Variant, map_origin: Vector2, parent_node: Node2D, cell_anchor: Vector2) -> bool` (checks `can_place_ground_trap` before consuming slot charge; sets `bomber._placed_trap_cell = bomber.cell` per `0x59AA2B`)
  - `check_bomber_ground_trap(bomber: Variant, move_dir: Vector2, ground_info: Variant, can_fit_cb: Callable, cell_anchor: Vector2, dismount_cb: Callable) -> int` (`0x59C2B2` -> `0x89B145` -> `0x89B623` -> `0x593737`: returns triggered `trap_type` or `0`)
  - `resolve_banana_slide_dir(bomber_dir: int, move_dir: Vector2, ground_info: Variant) -> int` (`0x593737`: active `move_dir` -> conveyor visual dir `0x5BFA0A` -> `bomber_dir`)
  - `can_use_active_item(bomber: Variant) -> bool` (`0x89B21F` / `0x889E0B`)

## Formulas and constants (with addresses)
- `MAX_SLOTS = 24` (`a2 > 0x17` guard in `0x5B70E6`, `0x5B75BD`, `0x5B8396`, `0x5B872A`)
- `HISTORY_RING_SIZE = 24` (`(tail + 1) % 24` in `0x5B84CB` @ `0x5b8521`)
- `EXCLUDED_CYCLE_TYPES = [12, 24]` (`v4 == 12 || v4 == 24` in `0x5B7582` @ `0x5b75b4`: mount upgrades & Scanner)
- `item_attr.json` `fields = [drop_weight, charges, item_type, param0, ...]`:
  - `type 11`: Ground traps (`param0`: `1=Bond` 3 charges, `2=Mine` 2 charges, `3=Banana` 1/2/3/8 charges, `4=Pushpin` 3 charges)
  - `type 21`: `Item/ItemDart` (3 charges)
  - `type 22`: `Item/ItemOxygen` (1 charge)
  - `type 23` / `45` / `46`: Needle variants (`Item/ItemNiddle`, `Item/ItemCpNiddle`, `Item/ItemSJNeedle1..7`, 1 charge)
  - `type 24`: `Item/ItemScanner` (1 charge)
  - `type 25`: `Item/ItemPotion` (3 charges)
  - `type 29`: `Item/ItemShield` (2 charges, `2000ms`), `Blind` (3 charges)
  - `type 31`: `Nitro` (3 charges)
- `BOND_DURATION_TICKS = 400` (`12s = 1000 * 12 / 30` @ `0x597233`), `BOND_SPEED = 2` (`0x59EC93` @ `0x59ecd6` -> `0x599A12`)

## Flow / state machine
1. **Pickup (`CGOBomber.apply_item(code)`):** passive items (`type 1`) and mounts (`type 2`) apply immediately; active/consumable items (`type 11, 21, 22, 23, 24, 25, 29, 45, 46, ...`) call `item_box.add_item(...)` which merges charges into the matching slot (or allocates an empty slot in `0..23`) and sets `manual_slot` if not excluded (`0x5B7582`).
2. **Context change:**
   - Match start (`0x5A517F`) -> `item_box.on_match_start()` selects Scanner -> Dart into `context_slot`.
   - Trapped in bubble (`0x59E53F`) -> `item_box.on_trapped_in_bubble()` selects Needle family (`0x59B51B`) -> Oxygen into `context_slot`.
3. **Quick-action (`Ctrl`/`E`) or Personal Slot (`1..6`):**
   - `Ctrl`: resolves `item_box.get_active_slot()` (`context_slot` if valid else `manual_slot`, `0x5B836B`), executes via `CGameItemMan` / `CGOBomber`, consumes 1 charge, and clears `context_slot = -1` (`0x5B87B1`).
   - `1..6`: dispatches the specific personal bar slot (`Needle`, `Oxygen`, `Dart`, `Banana`, `Bond`, `Mine`).
4. **Ground trap step (`CGameItemMan.check_bomber_ground_trap`):**
   - Skips if `bomber.cell == bomber._placed_trap_cell` (`0x59C2B2` @ `0x59c376`).
   - Validates `CGOTileGround.can_trigger_trap(is_flying, is_shielded)` (`0x89B145`).
   - Consumes trap & executes `Banana` (slide until blocked `0x593737`/`0x59E23F`), `Bond` (`400` ticks speed `2`), or `Mine` (dismount/bubble) (`0x89B623`).

## Test vectors (code-evidence)
- **TV-I1 (`CGOItemBox` 24-slot capacity & merge, `0x5B70E6` / `0x5B75BD` / `0x5B8396`):** adding `"Banana3"` allocates slot 0 with `count=3`; adding `"Banana2"` merges into same trap type or slot; out-of-range slot `-1`/`24` returns `false` / `0`.
- **TV-I2 (Two-tier `context_slot` vs `manual_slot` fallback, `0x5B836B` / `0x5B7F91` / `0x5B877C`):** `manual_slot = Banana`, `context_slot = Needle` -> `get_active_slot()` returns Needle; consuming last Needle clears `context_slot = -1` and `get_active_slot()` falls back to `manual_slot` (Banana).
- **TV-I3 (`is_excluded_from_cycle` & history ring, `0x5B7582` / `0x5B84CB`):** `item_type == 12` (`ItemSpanner`) and `24` (`ItemScanner`) return `is_excluded_from_cycle() == true`; selecting manual slots pushes unique entries into `history_ring` (capped at 24).
- **TV-I4 (Bubble trap auto-select priority, `0x59B51B` / `0x59E53F`):** bomber holding `Item/ItemOxygen` + `Item/ItemSJNeedle1` -> `on_trapped_in_bubble()` selects `Item/ItemSJNeedle1`; after consuming Needle, next `on_trapped_in_bubble()` selects `Item/ItemOxygen`.
- **TV-I5 (Match start auto-select, `0x5A517F`):** bomber holding `Item/ItemDart` -> `on_match_start()` selects Dart; if also holding `Item/ItemScanner`, selects Scanner first.
- **TV-I6 (`CGameItemMan` ground trap placement, self-cell immunity & trigger, `0x5BFE98` / `0x89B145` / `0x89B623`):** `try_place_bomber_trap` places Banana, consumes 1 charge, sets `_placed_trap_cell`; stepping on same cell does not trigger; leaving and re-entering triggers `SlideJump` until blocked (`0x59E23F`); placing on solid wall returns `false` without consuming charge.
- **TV-I7 (`CGameItemMan.resolve_banana_slide_dir`, `0x593737`):** active `move_dir` overrides conveyor/facing; zero `move_dir` on conveyor uses conveyor visual dir (`0x5BFA0A`); zero `move_dir` on normal ground uses bomber facing `dir`.
- **TV-I8 (`CGOBomber` backwards compatibility):** `bomber.needle_count`, `bomber.dart_count`, `bomber.oxygen_count`, `bomber.banana_count`, `bomber.bond_count`, `bomber.mine_count`, `bomber.pushpin_count` stay synced with `bomber.item_box` and `get_quick_item_hud()` / `get_inventory_slots()`.

## Functions covered (address list)
- `0x5B70E6`, `0x5B7582`, `0x5B75BD`, `0x5B760E`, `0x5B763E`, `0x5B76BC`, `0x5B7BA3`, `0x5B7F91`, `0x5B836B`, `0x5B8396`, `0x5B84CB`, `0x5B85BD`, `0x5B872A`, `0x5B877C`, `0x5B87B1`
- `0x59AA2B`, `0x59B51B`, `0x59B6F6`, `0x59C2B2`, `0x59E53F`, `0x5A517F`, `0x593737`, `0x59E23F`, `0x59EC93`, `0x599A12`, `0x597233`
- `0x5BFE98`, `0x5BFDE9`, `0x5C01FD`, `0x89B145`, `0x89B21F`, `0x89B623`, `0x89D95B`, `0x89DB3A`, `0x889DA8`, `0x889E0B`

## UNKNOWN (Deferred -> Shop/Account Wave)
- `sub_97569E` (called in `0x5B7BA3`): per-game-mode / map item allowlist table (e.g., disabling Needle/Shield in specific tournament/event modes) — **[Shop/Account & Mode Rules wave]** (`UNKNOWN`, default allow all in offline mode).
- `dword_E30008` (`5 * this[311] + this[310]` lookup in `0x5B87B1`): 2D slot-grid UI cursor mapping for multi-page `CGOItemBox` quick-cycle — **[Shop/Account wave]** (`UNKNOWN`, offline Godot uses direct 6-slot personal bar + `context_slot`/`manual_slot`).
- `CItemMan` sub-managers `sub_89D49F` (`12028B`) and `sub_8C2EA5` (`65540B`): internal pools for active map items/effects — **[Shop/Account wave]** (`UNKNOWN`, non-blocking for Task 09 offline refactor).
- `CUserItemMan` (`0xe487fc`, `0x8C0623`) / `CItemInventoryNew` (`0xe483c8`) account persistence & shop equip sync into 6 personal slots — **[Shop/Account wave]** (`UNKNOWN`).
