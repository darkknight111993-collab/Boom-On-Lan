# Task 12: Personal Inventory & MyInfo Dialog (`CMyPageDlg` / `BtMyitem`)

## Goal
Wire the `GlobalUI/BtMyitem` (`"action": "myitem"`) button in **Lobby** (`Client/data/screens/lobby.json`) and **Prepare** (`Client/data/screens/prepare.json`) to open the **CÁ NHÂN (`CMyPageDlg` / `MyPage Dialog`)** modal so players can view owned items from `CUserInventoryMan`, equip/unequip cosmetics (`hat`, `cloth`, `face`, `char_deco`, `id_deco`, `bomb_skin`, `character`) with live `CGOShopBomber` preview, and customize their 6 personal match item slots (`CÁ NHÂN` `1..6`) without having to enter the Shop.

## Current Status
- `lobby.json` (line 556) and `prepare.json` (line 466) already render `GlobalUI/BtMyitem` with `"action": "myitem"`.
- `screen.gd::on_action("myitem")` currently falls through to the unsupported placeholder notice (`"Chức năng này chưa được hỗ trợ..."`).
- All 172 UI sprites exist in `Client/Assets/fx/Myinfo/` (`Dlg_MI-Dialog`, `MP_TabBarMyItem`, `MP_TabBarMyInfo`, `MP_Back_CharDeco`, `MP_Back_ItemDeco`, `MP_Back_SlotDeco`, `MP_BtItemBack00..03`, `MP_BtExit`, `MP_BtScrLeft/Right`, `MP_BtSearchItem`).
- Underlying data & preview classes are already ported and tested: `CUserInventoryMan` (Task 10), `CGOBomberCosmetics` (Task 11), `CGOShopBomber` (Task 10).

## Scope (IDA Addresses in `AnalizeVNClient/ca_unpacked.exe.i64`)
- `0x5E229A` (`GlobalUI/BtMyItem` button trigger)
- `0x959D15` (`CMyPageDlg` / `"MyPage Dialog"` init: `Myinfo/MP_TabBarMyItem`, `Myinfo/MP_TabBarMyInfo`, `Myinfo/MP_BarSelCha`, `Myinfo/Cha_memo`, `Myinfo/Selzero`)
- `0x955461` / `0x957376` (MyItem tab sub-categories: `ItemDeco`, `CharDeco`, `SlotDeco` 6-slot loadout, `MyInfo` profile stats)

## Allowed Files
- Spec: `docs/migration/specs/mypage_dialog.md` (+ mirror `Client/docs/migration/specs/mypage_dialog.md`)
- New dialog controller: `Client/scripts/mypage_dialog.gd` (or integrated cleanly into `Client/scripts/dialog_manager.gd`)
- Updated callers: `Client/scripts/screen.gd` (route `action == "myitem"` to open `CMyPageDlg` and refresh Prepare/Lobby character preview on close)
- Tests: `Client/tools/test_mypage_dialog.gd` + `--write-movie` visual verification

## Execution Phases
1. **`/analyst`** (optional quick pass): Extract exact tab/grid/preview coordinates from `0x959D15` / `Myinfo/Dlg_MI-Dialog` (or derive directly from `Dlg_MI-Dialog` sprite bounds).
2. **`/porter`**: Implement the `MyPage` personal dialog with 2 main tabs (`Kho đồ / MyItem` + `Thông tin / MyInfo`), category filters (`Tất cả`, `Trang phục`, `Bóng nước`, `Khung tên`, `Vật phẩm`), click-to-equip/unequip with live `CGOShopBomber` preview, 6-slot personal loadout assignment, persistence via `AuthService.save_active_inventory()`, and Refresh of `Prepare` character preview on close.

## Acceptance Criteria
- Clicking `BtMyitem` in Lobby or Prepare opens the Personal Inventory dialog (`CMyPageDlg`) with owned items from `CUserInventoryMan`.
- Equipping/unequipping any owned cosmetic (`hat`, `cloth`, `face`, `char_deco`, `id_deco`, `bomb_skin`, `character`) immediately updates the live preview, persists via `AuthService`, and reflects in Prepare & in-match `CGOBomber`.
- Assigning owned consumables to the 6 personal match slots (`1..6`) updates `CUserInventoryMan.personal_loadout` and loads into `CGOItemBox` at match start.
- Headless tests + `--write-movie` visual check pass cleanly.
