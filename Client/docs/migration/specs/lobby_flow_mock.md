# Mock End-to-End Lobby & Match Bootstrap Schema (`mock_lobby_flow.json`)

> **Files:** `Client/data/channels.json` (static channel catalog per tab), `Client/data/mock_lobby_flow.json` (accounts, rooms, match bootstrap)
> **Purpose:** Single offline/LAN mock data source driving the complete flow `login.tscn -> select_server.tscn -> lobby.tscn -> prepare.tscn -> game_stage.tscn` without requiring a live login/lobby server.

## Flow mapping
1. **Login (`login.tscn` -> `AuthService` + `Session`):**
   - Reads `accounts[]` (`id`, `username`, `password_hash`, `nickname`, `level`, `exp`, `lucci`, `cash`, `wins`, `losses`, `draws`, `selected_char`, `equipped`, `inventory`).
   - Backward-compatible with existing `Client/data/database.json` and `init_db.sql`.
2. **Server & Channel Select (`select_server.tscn`):**
   - Reads `servers[]` -> `channels[]` (`id`, `index`, `name_vn`, `type`, `lobby_strategy`, `create_room_policy`, `min_level`, `max_level`, `population`, `max_population`, `allowed_component_ids`, `special_component_ids`).
   - **Per-channel room creation architecture (`CA.exe` evidence):**
     - **Layer 1 — `CLobbyStrategy` (`0xe2624c`, factory `0x6B5F29`, 9 subclasses):** each channel type binds a lobby strategy with `Slot 4` (`GetCreatableGameTypes`) and `Slot 10` (`OnClickCreateRoom(a2)`):
       1. `CNormalLobbyStrategy` (`0xc52bcc`, default): `Slot 4 = 0x6B7F49` (filters channel modes `0`, `14`, `16`, `10..13`, `18..21/25`). `Slot 10 = 0x6B8DD8`: `a2==0` opens full CreateRoom dialog (`0x6172B8`: title, password, `TeamArrange`, `game_type`); `a2==1` creates Tutorial (`15`) with no dialog; `a2==2/3` creates practice `Default (0)` (`a2==3` forces map `89`).
       2. `CRPGLobbyStrategy` (`0xc52d14`, `sub_8DAF28()`): `Slot 4 = 0x6B9466` (only `17`). Inherits `0x6B8DD8`, bypasses dialog and immediately creates `"RPG Room"` (`game_type = 17`, no password).
       3. `CStageClearLobbyStrategy` (`0xc52e24`, `sub_8DADCA() || sub_8DADE6()`): `Slot 4 = 0x6B9E8A` (only `14`). `Slot 10 = 0x6BA21E`: `a2==0` opens simplified dialog (`0x61B7D5(14)`: title + password, forces `team=1, game_type=14`); `a2==1` creates Tutorial (`15`) with no dialog.
       4. `CLadderLobbyStrategy` (`0xc529dc`, `sub_8DAB40()`): `Slot 4 = 0x6B6BCD` (only `0`). `Slot 10 = 0x6B6D64`: validates eligibility (`sub_8DAB89` -> `"CantMakeLadderRoom"`, `sub_8DAFD7(1)` -> `"CantMakeLadderSeasonRoom"`), then opens Ladder dialog (`0x61A730`: title, password, 3 radio buttons for match size `1/2/3`).
       5. `CMissionLobbyStrategy` (`0xc52b5c`, `sub_8DAB24()`): `Slot 4 = 0x6B76A8` (only `0`). `Slot 10 = 0x6B7855`: opens simplified dialog (`0x61B7D5(0)`: title, password, mission option `0x61B6E8`).
       6. `CExchangeLobbyStrategy` (`0xc52944`, `sub_8DAAD5() == 128`): `Slot 4 = 0x6B606A` (none). `Slot 10 = 0x6B6641`: opens Exchange room dialog (`0x6198BC`: title, password, checkbox flag -> `sub_6B6441`).
       7. `CSpecialTournamentLobbyStrategy` (`0xc52da4`, `sub_8DAD87() || sub_8DAD95()`): `Slot 4 = 0x6B94CF` (none). `Slot 10 = 0x6B9A53 -> 0x6B9867`: bypasses dialog, creates `"TournamentRoom"` (no password) and sends packet `77` directly (`0x88849F`).
       8. `CHiddenCatchLobbyStrategy` (`0xc1fa34`, `sub_8DAF47()`): `0x51C4EB` (`28`, `29`, `100`). `Slot 10 = 0x4B07CE`: `a2==1` creates Single (`31`) with no dialog; `a2==0` opens HiddenCatch dialog (`0x424E6E`: title, password, mode `28` Normal vs `31` Single + theme).
       9. `CWinningLobbyStrategy` (`0xc284b4`, `sub_8DACD5()`): `Slot 4 = 0x517653` (only `0`). `Slot 10 = 0x5174EB` (`nullsub_857`): manual room creation disabled (auto-matched winning streak).
     - **Layer 2 — Channel mode filter & sort order (`0x6277FC`, `0x8EAB5C`, `0x8EAE1D`, `0x97542F`):**
       - Basic enabled set (`dword_E60884 + 1056`, `sub_8EAB5C`): `0` (Default, always enabled), `10` (Survival), `11` (Hedgehog), `12` (Captain), `13` (Timebomb), `14` (NpcBattle), `16` (AIBattle).
       - Special/event enabled set (`dword_E60884 + 1116`, `sub_8EAE1D` + `sub_97542F`): `18/21/25` (SuperFighter), `19` (Zzolman), `20` (SnowBallFight), `27` (IamBoss).
       - Fixed UI priority order in `sub_6277FC`: `100 (All) -> 27 -> 0 -> 20 -> 19 -> 18/21/25 -> 14 -> 16 -> 10..13`, with `10..13` grouped into the secondary tab (`v16 = 0`, `CreateDlgRenewGT*`).
       - Label lookup `sub_626E4B` also resolves `28 = HiddenCatch_NormalMode`, `29 = HiddenCatch_CompetitionMode`, `25 = SuperFighter` variant.
3. **Lobby (`lobby.tscn`):**
   - Reads `rooms[]` filtered by `channel_id` and `lobby_users[]` filtered by `channel_id`.
   - Supports room create/join/password check (`locked`, `password`, `status` = `"waiting"` | `"playing"`).
4. **Prepare Room (`prepare.tscn`):**
   - Reads active room's `slots[0..7]` (`state`: `"occupied"` | `"open"` | `"closed"`, `is_host`, `is_ready`, `is_bot`, `char_code`, `team_color_idx` in `0..7` matching `Session.TEAM_COLORS`).
   - Enforces original BnB start guard: at least 2 distinct `team_color_idx` among occupied slots (except 1P sandbox maps).
5. **Match Start (`game_stage.tscn` -> `map_view.gd`):**
   - Builds `match_start_payload` from the active room (`component_id` -> `map_view.game_mode_id`, `map_code` -> `map_view.initial_map`, `players[]` -> `_create_player()`).

## Audit of current Godot Lobby layout & Modals (gaps to fix in Task 07)

### 1. Lobby layout (`Client/data/screens/lobby.json`)
- **Hardcoded static room cards:** `S02`, `S08`, `S22` (`"Post 3 t? 2c 2f (4cs)"` broken encoding) are baked into `lobby.json`; clicking any card jumps straight to `goto:prepare` without selecting `room_id`/`mode`/`map` or checking room password.
- **Create Room button ignores channel strategy:** `LB_Bt_T_CreateRenew` (218, 48) hardcodes `"action": "dialog:create_room"`, ignoring `CLobbyStrategy` (`0x6B5F29`: RPG/Tournament bypass dialog, Winning disables manual create, Ladder/StageClear/Mission/Exchange/HiddenCatch open dedicated dialogs).
- **Mode filter & ShowAll unwired:** `LB_Bt_T_GameTypeRenew` (488, 60) and `LB_Bt_T_ShowAllRenew` (571, 64) are `"unsupported"` instead of filtering by channel modes (`0x6277FC`).
- **Left user list panel unwired:** `LB_Bt_All`, `LB_Bt_Guild`, and paging buttons do not populate `lobby_users`.

### 2. Modal dialogs (`Client/data/dialogs.json` + `Client/scripts/dialog_manager.gd`)
- **Single create-room modal used for all channel types:** Currently only `Lobby/Dlg_Creat_MS2_Extension` (743×430) is defined, whereas `Client/Assets/fx/Lobby/` already contains the exact `CA.exe` dialog backgrounds:
  - Normal (`0x6172B8`): `Lobby/Dlg_Creat_MS2_Extension` (must filter cards by channel `allowed_component_ids` + `special_component_ids`, group `10..13` `Gametype_bt_Survival / Hedgehog / Captain / TimeBomb`, and support `TeamArrange`).
  - StageClear (`0x61B7D5(14)`): `Lobby/Dlg_LB-MMCreate` (title + password only).
  - Ladder (`0x61A730`): `Lobby/Dlg_LB-Create_Ladder` (title + password + 3 match-size radios).
  - Mission (`0x61B7D5(0)`): `Lobby/Dlg_LB-Create_Mission`.
  - Exchange (`0x6198BC`): `Lobby/Dlg_LB-Create_ChatExcRoom`.
  - HiddenCatch (`0x424E6E`): `Lobby/Dlg_Create_Hidden02`.
  - Password prompt for locked rooms: `Lobby/Dlg_LB-RoomPw` *(missing from `dialogs.json`)*.
- **Room password dropped on submit (`dialog_manager.gd:333`):** `room_lock` / `room_pw` in `create_room` and `ri_pw` in `room_info` are never persisted or validated.
- **Missing `component_id` & `default_map` sync:** `dialog:submit_create_room` sets `Session.game_mode` string only; it does not map to `CComponent::MODE_*` or reset `Session.selected_map` to the chosen mode's `default_map`.
- **Hardcoded `lobby_room_info` (`Lobby/Dlg_LB-RoomInfo8`):** Shows hardcoded level `449` and only 2 static rows (`ri_p1`/`ri_p2`) instead of the selected room's 8 slots.
- **Hardcoded `room_info` (`Prepare/Dlg_PRE-RoominfoRenew`):** Always displays `"Chế độ chơi: Thường (Bom nước cổ điển)"` and `"Đấu đội / Tự do"` regardless of active room mode.

## `CSelectServerStage` Channel Selection Spec & UI Audit (`CA.exe` evidence)

### 1. Layout, Tabs & Pagination (`0x854E09`, `0x857C23`, `0x8585B8`, `0x858AB4`)
- **Tabs (`sub_857C23` @ `0x857C23`, `sub_8585B8` @ `0x8585B8`):**
  - Container at `(401, 122)`, size `388×102`; each tab button is `71×102` at `x = 71 * tab_idx`, ID `1000 + tab_idx`, using `CH_Tab_%s`, `CH_ChBar_%s` (blank colored bar), and `SelectServer/ChannelBalloon%s` -> `CH_Tab_%s_Ba` (green animated speech-balloon sprite above the active tab).
  - Exact engine order of 5 tabs (`sub_8585B8`), VN balloon text (`CH_Tab_*_Ba`), and `CH_ChBar_%s` description text RGB (`sub_857C23` @ `0x857DAF..0x857E30`):
    0. `Novice` (`CH_Tab_Novice_Ba`: **TẬP SỰ**, yellow bar `CH_ChBar_Novice`): `RGB(144, 48, 0)`
    1. `Free` (`CH_Tab_Free_Ba`: **TỰ DO**, orange bar `CH_ChBar_Free`): `RGB(138, 0, 0)`
    2. `Ladder` (`CH_Tab_Ladder_Ba`: **SIÊU CẤP**, purple bar `CH_ChBar_Ladder`): `RGB(80, 0, 114)`
    3. `Special` (`CH_Tab_Special_Ba`: **ĐẶC BIỆT**, pink bar `CH_ChBar_Special`): `RGB(138, 0, 46)`
    4. `Event` (`CH_Tab_Event_Ba`: **SỰ KIỆN**, green bar `CH_ChBar_Event`): `RGB(6, 91, 0)`
  - Visible count comes from `sub_854A7D()` (`*(dword_E60E54 + 456)`). VN client (`GameStage/SelectServerStage.png`) displays the **first 4 tabs**: `Tập Sự` (`Novice`), `Tự Do` (`Free`), `Siêu Cấp` (`Ladder`), `Đặc Biệt` (`Special`), hiding the 5th tab `Sự Kiện` (`Event`).
- **Channel Grid (`sub_854E09` @ `0x854E09`, `sub_858AB4` @ `0x858E4D..0x858F5D`):**
  - `8` channels per page (`2 * (sub_40176C() != 0) + 8`), arranged in **2 columns × 4 rows**:
    - Left col `x = 428`, right col `x = 595` (`col_offset = (idx % 2) ? 167 : 0`).
    - Row `y = 278 + 56 * (idx / 2)`.
  - Up to **5 page buttons** (`1..5`, `CH_Bt_ChNum` at `x = 521 + 30 * i`, `y = 519`, ID `2500..2504`), flanked by `CH_Bt_Left` (`490, 516`) and `CH_Bt_Right` (`676, 516`).
- **Channel Card Rendering (`sub_854E1D` @ `0x854E1D`, colors from `sub_A44980` @ `0xA44980`):**
  - **Channel name:** drawn at `(col_offset + 445, y + 18)` with black outline (`dword_EEEBDC = RGB(0, 0, 0)`):
    - Enterable: **Yellow** (`dword_EEEBE0 = RGB(255, 255, 0)`).
    - Full / locked / ineligible: **Light Gray** (`dword_EEEBE4 = RGB(196, 196, 196)`).
  - **Population bar (`CH_Bar_User`, 12 frames of `21×10` each — `0..5` green-yellow, `6..11` yellow-orange-red):**
    - Drawn as `0..6` horizontal segments starting at `(col_offset + 446, y + 34)` with stride `+22px` (`frame = seg_idx + (can_enter ? 0 : 6)` @ `0x854FBC..0x854FC7`, `0x8550F4`; RPG channel type `0x82` uses `RPG_CH_Bar_User`):
      ```c
      int bars = (pop > 0) ? min(6, 6 * pop / max_pop + 1) : 0;
      if (pop >= max_pop) bars = 6;
      ```
  - **`NEW` badge (`SelectServer/NewGlyph` / `CH_Img_New`, 2 frames):** drawn at `(col_offset + 424, y - 2)` when `sub_8DAAB7(channel_type)` is true (`channel_type` in `{72, 73, 74}`).

### 2. Entry Eligibility & Tooltip Validation (`0x66F4B4`, `0x66F4E4`, `0x66F70C`)
- **Level range (`sub_994BF6` / `sub_994C15`):** checked for all channels (`UpperLevelOnly` / `LowerLevelOnly`).
- **Ladder grade (`sub_994B86` / `sub_994BA2`) & Season Ladder KO (`sub_994BBE` / `sub_994BDA`):** checked via `sub_66F4E4` when `sub_66F4B4(channel_type)` is true (`50 <= channel_type <= 65 || channel_type == 70`); returns `0` (OK), `1` (`LadderLowGrade`), `2` (`LadderHighGrade`), `3`/`4` (Season Ladder KO).
- **Super (`Siêu Cấp`) grade cap (`channel_type == 72`, `sub_66F70C` @ `LABEL_39`):** blocks entry if `max_grade > 0 && user_grade > max_grade` (`CannotEnterChannel...`, matching VN tooltip `"Đây là kênh siêu cấp chỉ dành cho User dưới grade 2"`).
- **Exchange (`channel_type == 0x80`):** checks trade permission (`CantExchangeId`).

### 3. Audit of current Godot `select_server.json` & `channels.json`
- **`select_server.json`:** 4 tabs and 5 page buttons are `"unsupported"`; tab 3/4 currently use `CH_Tab_Special`/`CH_Tab_Event` instead of `CH_Tab_Ladder` (**SIÊU CẤP**) / `CH_Tab_Special` (**ĐẶC BIỆT**) as in `SelectServerStage.png`; 8 channel buttons are static (`WinWin-Free`, `LT-01..02`, `CB-01..02`, `TD-01..03`) with no `id` or `channel_id`; `CH_Bar_User` is a single static sprite instead of `0..6` segments (`21×10`, stride `22px`); missing `CH_Tab_*_Ba` balloon, `CH_Img_New` badge and hover tooltip box; top game-mode switcher (`CH_bt_GameModeSelectLeft/RightArrow`) and left ad banner pagination are static background.
- **`channels.json` adjustments needed:**
  1. Match exact 5-tab VN engine mapping (`sub_8585B8` + `CH_Tab_*_Ba`): `novice` = **Tập Sự** (`TS-01..`), `free` = **Tự Do** (`TD-01..`), `ladder` = **Siêu Cấp** (`SC-01..` / `LT-01..` / `CB-01..`), `special` = **Đặc Biệt** (`SQ-01..`, `NH-01..`, `BS-01..`, ...), `event` = **Sự Kiện** (tab 5, hidden when `visible_tabs == 4`).
  2. Add per-channel fields: `channel_type` (e.g. `72` for Super/NEW), `min_grade`, `max_grade`, `tooltip_vn`, `badge`.
  3. Unify `channel_id` values between `channels.json` and `mock_lobby_flow.json`.

## Functions covered (address list)
- `0x854E09`, `0x854E1D`, `0x855466`, `0x857C23`, `0x8585B8`, `0x858AB4`, `0x8DAAB7` (`CSelectServerStage` channel list, tabs, pagination, `CH_Bar_User` 0..6 bar formula, `NewGlyph`)
- `0x66F4B4`, `0x66F4E4`, `0x66F70C` (channel level, ladder grade, Super `type==72` grade cap, Exchange eligibility)
- `0xA44980` (UI text color constants `dword_EEEBD8/DC/E0/E4`)
- `0x6B5F29` (`CreateLobbyStrategy` factory selecting among all 9 `CLobbyStrategy` subclasses)
- `0x6B7F49`, `0x6B8DD8`, `0x6B7E0E` (`CNormalLobbyStrategy` & `CRPGLobbyStrategy` `0x6B9466`)
- `0x6B9E8A`, `0x6BA21E`, `0x6B9DCA` (`CStageClearLobbyStrategy`)
- `0x6B6BCD`, `0x6B6D64`, `0x6B6AF5` (`CLadderLobbyStrategy`)
- `0x6B76A8`, `0x6B7855` (`CMissionLobbyStrategy`)
- `0x6B6641` (`CExchangeLobbyStrategy`), `0x6B9A53`, `0x6B9867` (`CSpecialTournamentLobbyStrategy`)
- `0x4B07CE` (`CHiddenCatchLobbyStrategy`, mode `28` Normal / `31` Single), `0x517653`, `0x5174EB` (`CWinningLobbyStrategy`)
- `0x626E4B` (game type label lookup for create-room dialog, incl. `25`, `28`, `29`, `100`)
- `0x6277FC`, `0x62771B` (`CNormalLobbyStrategy` create-room mode filter & priority sort)
- `0x51C4EB`, `0x51C0D5` (`CHiddenCatchLobbyStrategy` create-room mode list: `28`, `29`, `100`)
- `0x8EAB5C` (`IsBasicGameTypeEnabled` @ `dword_E60884 + 1056`), `0x8EAE1D` (`IsSpecialGameTypeEnabled` @ `dword_E60884 + 1116`), `0x97542F` (`IsSpecialGameTypeId`)
- `0x93F809` (`CCmdLobbyCreateRoom` command factory, RTTI `0xe52808`)

## UNKNOWN
- Original `CA.exe` binary TCP packet layouts for Login/Channel/Lobby/Room sync (deferred to LAN networking wave; `mock_lobby_flow.json` models the client-side state only).
