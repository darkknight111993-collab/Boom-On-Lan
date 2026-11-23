# Task 08: Clean Up `game_modes.json` & Add Theme Grouping / `ShowMapListAll` in `select_map`

## Goal
Fix the `select_map` dialog so **Đại Chiến (`normal`, `MODE_DEFAULT = 0`)** no longer dumps all 456 mixed maps (including `Kart*`, `Bula*`, `Hidden*`, `Ex*`, `Event*`, `UserContest*`) into one flat list. Match original `CA.exe` `CMapSelectDialog` behavior (`ShowMapListAll` @ `0x648EA4` and `MapGroupVisible` @ `0x6DBC56`).

## Addresses & Functions in Scope
- `0x648EA4` (`CMapSelectDialog::SetShowMapListAll`)
- `0x648E3D` (`CMapSelectDialog::RefreshMapList`)
- `0x6DBC56`, `0x6DE88C` (`CDynamicMapMan::Load/SaveMapGroupVisible`)
- `0x6DEE48` (`CDynamicMapMan::IsMapSelectable`, `a4` / `sub_6DE4CD` standard vs `ShowMapListAll` filter)
- `0x6DD516` (`CDynamicMapMan::IsMapAllowedForGameType`)

## Expected Spec File
- `docs/migration/specs/dynamic_map_man.md`

## Files Allowed to Edit
- `Client/data/game_modes.json`
- `Client/data/dialogs.json` (`select_map` dialog only — optional theme selector / "Hiện tất cả" toggle)
- `Client/scripts/modes/c_lobby_flow.gd`
- `Client/scripts/modes/c_dynamic_map_man.gd`
- `Client/scripts/dialog_manager.gd` (`_populate_map_list` & `select_map` actions)
- `Client/tools/test_dynamic_map_man.gd`, `Client/tools/test_lobby_flow_mock.gd`
- `docs/migration/specs/dynamic_map_man.md`, `docs/migration/parity_matrix.md` (+ sync `Client/docs/migration/`)

## Plan

### 1. Clean up `Client/data/game_modes.json` & Fix Mode Linkages
- **Split misfiled game modes out of `normal` & add missing mode pools:**
  - `Kart00..17` (18 maps) → dedicated mode `"kart"` (`MODE_KART = 1`, `default_map: "Kart00"`).
  - `Bula01..24` (24 maps) → dedicated mode `"bula"` (`MODE_BULA = 2`, `default_map: "Bula01"`).
  - `Hidden01..24` (24 maps) → dedicated mode `"hidden_catch"` (`28/29/31`, `default_map: "Hidden01"`).
  - `IamBoss01..06, iamboss07, IamBoss08` (8 maps from `Client/Assets/fx/Map/`) → dedicated mode `"iam_boss"` (`MODE_IAM_BOSS = 27`, `default_map: "IamBoss01"`, `name_vn: "Tôi là Boss"`).
- **Fix missing `CLobbyFlow` / `CDynamicMapMan` mode mappings:**
  - Map `"gametype"` → `MODE_CAPTAIN (12)` fallback when clicking the `Gametype_bt01` card background.
  - Map `25` (`"super_fighter_var"` → `superf2`), `28` (`"hidden_catch"`), `29` (`"hidden_catch_comp"`), `31` (`"hidden_catch_single"`) in `CLobbyFlow.MODE_KEY_TO_COMPONENT_ID` & `CDynamicMapMan.MODE_KEY_ALIASES` / `MODE_NAME_VN_OVERRIDES`.
- **Split classic vs extended maps inside `normal` (`ShowMapListAll` @ `0x648EA4`):**
  - `normal.maps` (default view, `show_all = false`): **only classic PvP themes** (`Camp`, `Village`, `Factory`, `Forest`, `Patrit`, `Tomb`, `Ocean`, `Desert`, `Ice`, `Mine`, `Xmas`, `Cemetery`, `PangLand`, `Aqua`, `Cookie`, `Kfg`).
  - `normal.extended_maps` (shown only when `show_all = true`): `Ex*`, `Event*`, `UserContest*`, `SnowyFields*`, `seafields*`, `Rabbit*`, `BlackRabbit*`, `Javelin*`, `Clover*`, `Pharaoh*`, `Antarctic*`.

### 2. Theme Grouping & `ShowMapListAll` in `CDynamicMapMan` (`c_dynamic_map_man.gd`)
- Add `get_maps(component_id, channel_strategy, mode_filter, show_all = false, theme_prefix = "")`:
  - When `show_all == false`: returns `maps` only (clean classic list).
  - When `show_all == true`: appends `extended_maps` (no duplicates).
  - When `theme_prefix != ""`: filters to maps matching that theme prefix (case-insensitive, e.g. `"Camp"`, `"Village"`, `"Factory"`).
- Add `get_themes_for_maps(map_list: Array[String]) -> Array[String]` returning sorted unique theme prefixes for the active mode.

### 3. Wire `select_map` Modal (`dialogs.json` + `dialog_manager.gd`)
- Add a compact `"Hiện tất cả"` (`ShowMapListAll`) checkbox/toggle and theme-filter cycle button (`Tất cả chủ đề` / `Camp` / `Village` / ...) in `select_map` header.
- Refresh `map_list` cleanly on toggle without overflowing `map_desc`.

## Acceptance Criteria & Test Vectors
- **TV-DM8:** `normal` default list (`show_all = false`) excludes `Kart*`, `Bula*`, `Hidden*`, `Ex*`, `Event*`, `UserContest*`; `show_all = true` includes `extended_maps`.
- **TV-DM9:** `MODE_KART (1)` returns 18 `Kart*` maps; `MODE_BULA (2)` returns 24 `Bula*` maps; `hidden_catch` returns 24 `Hidden*` maps.
- **TV-DM10:** Theme filter (`theme_prefix = "Camp"`) returns only `Camp*` maps, and `get_themes_for_maps()` returns unique sorted prefixes.
- Headless tests pass:
  - `godot --headless --path Client -s res://tools/test_dynamic_map_man.gd`
  - `godot --headless --path Client -s res://tools/test_lobby_flow_mock.gd`
  - `godot --headless --path Client --quit-after 2 res://scenes/prepare.tscn`
