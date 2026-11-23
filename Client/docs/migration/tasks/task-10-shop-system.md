# Task 10: Shop & Account Inventory System (`CShopStageNew`, `CShopItemMan`, `CUserInventoryMan`, `CGOShopBomber`)

## Goal
Port the Crazy Arcade Shop & Account Inventory subsystem to Godot 4 (`Client/`), connecting Lobby/Prepare (`Shop` button) to a full `800x600` Shop screen where players can browse categories (`Đặc biệt`, `Vật phẩm`, `Bộ đồ`, `Nhân vật`, `Túi đồ`), try on cosmetics/bombs/mounts on a live bomber preview, purchase with Lucci/Cash (offline/mock database first, LAN-server ready), and equip both cosmetics and the 6 personal match item slots (`CÁ NHÂN` `1..6`) that load into `CGOItemBox` at match start.

## Scope (IDA Addresses in `AnalizeVNClient/ca_unpacked.exe.i64`)
- **Catalog (`CShopItemMan`, `.?AVCShopItemMan@@` @ `0xe48660`):**
  - `0x8B1D42` (ctor), `0x8B2AD6` (dtor), catalog table loading, category/sub-tab filtering, Cash vs Lucci currency filtering, search, pagination.
- **Account Inventory (`CUserItemMan` @ `0xe487fc`, `CUserInventoryMan` @ `0xe48740`, `CItemInventoryNew` @ `0xe483c8`):**
  - `0x8C07AC` / `0x8C0623` (`CUserItemMan`), `0x8BA9DF` / `0x8BABC9` (`CUserInventoryMan`), `UserItem` (`0xe3ced4`).
  - Owned item list, Lucci/Cash balance, equip/unequip cosmetics (`hat`, `cloth`, `face`, `id_deco`, `bomb_skin`, `mount`, `character`), and 6-slot personal match item loadout -> `CGOItemBox`.
  - Also resolves deferred Task 09 `UNKNOWN`s as needed (`0x97569E` mode item allowlist, `dword_E30008` slot-grid cursor).
- **Shop Stage UI (`CShopStageNew`, `.?AVCShopStageNew@@` @ `0xe44fb0`):**
  - `0x807303` (ctor), `0x807149` (dtor), `0x85C174` (UI layout & button/tab setup: `Shop/S_TabSpecial`, `S_TabItem`, `S_TabSet`, `S_TabChar`, `S_TabSlot`, `S_BtCash`, `S_BtLucci`, `S_BtBuy`, `S_BtRent`, `S_BtGet`, `S_BtSearch`, `S_BtUndo`, `S_BtHide`).
  - Dialogs: `CShopBuyDlg` (`0xe33b4c`), `CShopRentDlg` (`0xe33c28`), `CItemSearchDlg` (`0xe27bd4`), `CShopInventoryPopupDlg` (`0xe33bc8`).
- **Live Try-On Preview (`CGOShopBomber` @ `0xe448e4` + `CShopAction*` @ `0xe44900..0xe44ab0`):**
  - `0x7EECF2` (ctor), `0x7EEA58` (dtor), `0x7F1EEF..0x7F2830` (preview actions: `Wait`, `SetBomb`, `UseShield`, `UseSpring`, `UseSpecialItem`, `UseNormalItem`).

## Recommended Sub-Phases (Non-Overlapping)
1. **Phase 10A — Data & Pure Logic (`/analyst` -> `/porter`):**
   - Decompile `CShopItemMan` (`0x8B1D42`+) & `CUserInventoryMan` (`0x8BA9DF`+) & `CUserItemMan` (`0x8C07AC`+).
   - Write `docs/migration/specs/shop_system.md`.
   - Create `Client/data/shop_catalog.json` (derived from `Client/Assets/fx/` + `item_attr.json` / `bomber_attr.json`), `Client/scripts/modes/c_shop_item_man.gd`, `Client/scripts/modes/c_user_inventory_man.gd`, and headless `Client/tools/test_shop_system.gd`.
2. **Phase 10B — `CShopStageNew` UI & Buy/Equip Flow:**
   - Extract exact widget coordinates from `0x85C174` (`CShopStageNew::InitUI`) + `Client/Assets/fx/Shop/`.
   - Create `Client/data/screens/shop.json` + `Client/scenes/shop.tscn`, wire `Shop` navigation in `lobby.json` / `prepare.json` / `screen.gd`, wire `Session` & `AuthService` persistence, and visually verify via `--write-movie`.
3. **Phase 10C — `CGOShopBomber` Live Preview & Personal Slot Loadout -> `CGOItemBox`:**
   - Port `Client/scripts/objects/cgo_shop_bomber.gd` (`extends CGOBomber`) for try-on preview + Undo/Hide.
   - Load equipped 6 personal slots from `CUserInventoryMan` into `CGOBomber.item_box` at match start (`map_view.gd`).

## Out of Scope (Deferred to LAN Server Wave)
- Real Nexon Cash recharge (`S_BtRechaCash`), real-money coupon/present network packets (`CShopNexonPassCheckDlg`, `CShopCouponDlg`), and Auction/UserMarket (`CUserMarketStage`, `CExchangeStage`).

## Allowed Files
- Spec: `docs/migration/specs/shop_system.md` (+ mirror)
- Data & UI: `Client/data/shop_catalog.json`, `Client/data/screens/shop.json`, `Client/scenes/shop.tscn`, `Client/data/dialogs.json`
- Scripts: `Client/scripts/modes/c_shop_item_man.gd`, `Client/scripts/modes/c_user_inventory_man.gd`, `Client/scripts/objects/cgo_shop_bomber.gd`, plus wiring in `Client/scripts/session.gd`, `Client/scripts/auth_service.gd`, `Client/scripts/screen.gd`, `Client/scripts/map_view.gd`
- Tests: `Client/tools/test_shop_system.gd`

## Golden Reference Needed (Optional, Helpful for Phase 10B)
- A screenshot of the original VN client Shop screen (`GameStage/ShopStage.png`) if available, so Phase 10B can visually cross-check exact tab/grid/preview alignment (otherwise Phase 10B will extract exact `(x, y)` coordinates directly from `0x85C174` in IDA).

## Acceptance Criteria
- Pure `CShopItemMan` & `CUserInventoryMan` pass headless unit tests (`TV-S1..TV-S8`: tab/currency filter, search, purchase deducts Lucci/Cash, insufficient funds rejected, equip/unequip cosmetic & 6 personal slots, persistence in `AuthService`).
- `scenes/shop.tscn` renders cleanly at `800x600` using `Client/Assets/fx/Shop/` sprites and navigates cleanly to/from Lobby & Prepare.
- Equipped cosmetics & 6 personal items from Shop appear in `Prepare` and load into `CGOBomber.item_box` in `game_stage.tscn`.
