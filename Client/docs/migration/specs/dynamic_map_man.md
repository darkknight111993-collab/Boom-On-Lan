# `CDynamicMapMan` — Map Selection & Mode Filtering Spec

> **Original class:** `CDynamicMapMan` (`TSingleton<CDynamicMapMan>`, RTTI `0xE3E3B8`, `dword_E60930`), `CMapSelectDialog` (`0xE33F44`), `CMapSelectDialogStrategy` (`0xE33F64`: Normal `0xE33F8C`, StageClear `0xE33FB4`, AIBattle `0xE33FE0`, RPG `0xE3400C`)
> **Target Godot class:** `Client/scripts/modes/c_dynamic_map_man.gd` (`class_name CDynamicMapMan extends RefCounted`)
> **Data sources:** Server-pushed cache `fxdynmapinfo.ssd` (absent from workspace; offline Godot fallback uses `Client/data/game_modes.json` + `Client/data/map_group.json`)

## Behavior summary
`CDynamicMapMan` holds the client's runtime map catalog parsed from `fxdynmapinfo.ssd` (`0x6E0C5A -> 0x6E077C`). Whenever `CMapSelectDialog` opens or toggles `ShowMapListAll` (`0x648EA4 -> 0x648E3D`), it rebuilds the selectable map list (`0x6E0D2C`) by evaluating `IsMapSelectable` (`0x6DEE48`) across every loaded map record.

## Class / state (`CDynamicMapMan` -> `c_dynamic_map_man.gd`)
- `this + 16` (`v2 + 4`): `std::vector<DynMapRecord>` (`132` bytes per record, appended via `0x6E03A8`).
- `this + 72`: map count (`sub_414543`).
- `this + 96`: default/selected map index (`sub_6DC01D`, setter `sub_6DBFBE`).
- `this + 120`: `mode_filter` enum `0..10` (`sub_6DC035`).
- `this + 132`: filtered list count (`sub_6DBFB3`); `this + 144`: filtered index entries (8 bytes each).
- `this + 24152`: map-group visibility table (`MapGroupVisible`, `0x6DBC56` / `0x6DE88C`).

## `fxdynmapinfo.ssd` Binary Record Layout (`sub_6E077C` @ `0x6E077C`)
- Header: `uint16 map_count` (`sub_A62F70`), version hash check (`sub_A62570 == this[3]`).
- Per-map record (`DynMapRecord`):
  - `+0` (`uint32` `v16`): `map_id`
  - `+4` (`uint8` `v17`): `flags_04`
  - `+8` (`16B` `v18`): obfuscated string `map_code` (`sub_911168`; compared against `"MonEasyRandom"` / `"MonBeginnerRandom"` in `0x6DF780`)
  - `+24` (`16B` `v19`): obfuscated string `map_name`
  - `+40` (`uint8` `v20`): **`category_type`** (`3` = AI-eligible override, `6` = Monster/StageClear, `12` = Zzolman/Captain, `13` = SnowBall/Timebomb, `24` = IamBoss, `29` = Special/Case-10)
  - `+41` (`uint8` `v21`): **`group_id`** (`89` = `Theme/SweetCandy`, `106/120` = no AI/Tutorial, `109` = SuperFighter, `112` = SuperFighter2, `137 [0x89]` = IamBoss, `138` = `Theme/ThemeDefault`, `146 [0x92]` = Case-10, `238` = no Survival/Hedgehog/Captain/Timebomb/AI/Tutorial, `239 [0xEF]` = Case-7, `241 [0xF1]` = Case-6)
  - `+44` (`std::string` `v22`): `theme_name` (formatted as `"Theme/%s"`)
  - `+72` (`std::string` `v23`): `description`
  - `+100` (`uint8` `v24`), `+101` (`uint8` `v25`), `+104` (`uint32` `v26`): packed RGB color (`BYTE2, BYTE1, BYTE0`)
  - `+108` (`uint8` `v27`): player-limit / tier byte (if `v27 / 10 == 1`, decoded as `v27 %= 10` and `flag_v33 = 1`)
  - `+109` (`uint8` `v28`), `+110` (`uint8` `v29`): `ai_restrict_flag` (checked in `0x6DE433` AI Battle predicate)
  - `+112` (`uint16` `v30`), `+114` (`uint8` `v31`), `+116` (`uint32` `v32`): extra attributes

## Formulas and constants (`sub_6DEE48`, `sub_6DD516`, `sub_68B85D`)

### 1. Complete `mode_filter` (`sub_6DC035` @ `this + 120`) Dispatch Table (`0x6DEE48`)
| Case | Predicate | Rule (`CA.exe` evidence) | Notes |
|---:|---|---|---|
| `0` (`default`) | `sub_6DCD82` (`0x6DCD82`) | Normal multiplayer: excludes Monster (`0x6DC168`), Case-6 (`0x6DC1B6`), Case-7 (`0x6DC1FB`), solo-only (`0x6DC626`) | Standard PvP |
| `1` | `sub_6DCD82` (`== 1`) | Practice / Solo-2P: allows `0x6DC626` when local user count `!= 2`; blocks `0x6DC5EF` | Practice / 1P |
| `2` | `sub_6DCD82` (`== 2`) | Special PvP / Tournament: same as `0` plus blocks `0x6DC5AE` | Restricted PvP |
| `3` | `sub_6DCE42` (`0x6DCE42`) | Monster / StageClear (`14`/`22`): `sub_6DC168` (`sub_988D48(group_id)` or `category_type == 6`) or `sub_6DC47F`; default map picker (`0x6DF780`) selects `"MonBeginnerRandom"` / `"MonEasyRandom"` | StageClear |
| `4` | `sub_6DE3E7` (`0x6DE3E7`) | Filtered Monster (`sub_6DC168 && !IsRandom && (!this[6042] || sub_6DDC14)`) | Forces `component_id = 0` in `0x6DEE48` |
| `5` | `sub_6DE433` (`0x6DE433`) | AI Battle (`sub_6DCD82 && sub_6DD516(map, 16) && !sub_6DC5AE && !IsRandom && (!byte+110 || category_type == 3)`) | Forces `component_id = 0` in `0x6DEE48` |
| `6` | `sub_6DCE87` (`0x6DCE87`) | `sub_6DC1B6` (`group_id == 0xF1 [241]` or `category_type == 12`) or `sub_6DC47F` | Captain / Zzolman group |
| `7` | `sub_6DCEBC` (`0x6DCEBC`) | `sub_6DC1FB` (`group_id == 0xEF [239]` or `category_type == 13`) or `sub_6DC47F` | Timebomb / SnowBall group |
| `8` | `sub_6DCF26` (`0x6DCF26`) | `sub_6DC285` (`group_id == 0x89 [137]` or `category_type == 24`) or `sub_6DC47F` | IamBoss (`27`) |
| `9` | `sub_6DE4B8` (`0x6DE4B8`) | Delegates to `sub_6DE433` (AI Battle), clearing `a3 = 0` (skips team-flag check `0x6DC81E`) | AI Battle variant |
| `10` | `sub_6DCEF1` (`0x6DCEF1`) | `sub_6DC240` (`group_id == 0x92 [146]` or `category_type == 29`) or `sub_6DC47F` | Special / HiddenCatch (`29`) |

### 2. Game-Type Rule Table (`sub_6DD516` @ `0x6DD516`)
- `group_id == 109`: allowed only for `component_id` in `{18, 21, 25}` (SuperFighter family).
- `group_id == 112`: allowed only for `21`, `18` (when `21` enabled), or `25`.
- `group_id == 137`: allowed only for `27` (IamBoss); conversely `component_id == 27` only allows `group_id == 137`.
- `group_id == 238`: blocked in `{10, 11, 12, 13, 15, 16}` (Survival, Hedgehog, Captain, Timebomb, Tutorial, AI Battle).
- `group_id == 106` or `120`: blocked in `{15, 16}` (Tutorial, AI Battle).

### 3. Player-Count Guard (`sub_68B85D` @ `0x68B85D`)
- Server response `v3 == 1` displays localized `MapSelect_PlayerLimitOver` with `max_players` byte (`sub_A65670`).

## Test vectors (`Client/tools/test_dynamic_map_man.gd`, source: code-evidence)
- **TV-DM1:** `is_map_allowed_for_game_type()` matches all `0x6DD516` branches (`109`, `112`, `137`, `238`, `106`, `120`, normal `0`).
- **TV-DM2:** `get_maps()` returns mode-specific maps for `MODE_DEFAULT (0)`, `MODE_HEDGEHOG (11)`, `MODE_STAGE_CLEAR (14)`.
- **TV-DM3:** `channel_strategy == "ladder"` / `MODE_FILTER_PRACTICE` restrict to `LadderMapGroup` / `PraticeMapGroup` (`map_group.json`).
- **TV-DM4:** `get_default_map()` returns valid default map per `component_id` & channel strategy.
- **TV-DM5:** `check_player_limit()` enforces `MapSelect_PlayerLimitOver` (`0x68B85D`).

## Functions covered (address list)
- `0x64832E`, `0x648E3D`, `0x648EA4`, `0x64B0D1`, `0x64B0DD` (`CMapSelectDialog` & `CMapSelectDialogStrategy`)
- `0x68B85D` (`OnSelectMapResponse` / `MapSelect_PlayerLimitOver`)
- `0x6DBC56`, `0x6DE88C` (`MapGroupVisible` persistence)
- `0x6DBFBE`, `0x6DBFB3`, `0x6DC01D`, `0x6DC035` (`CDynamicMapMan` getters/setters)
- `0x6DC168`, `0x6DC1B6`, `0x6DC1FB`, `0x6DC240`, `0x6DC285` (category/group predicates)
- `0x6DCD82`, `0x6DCE42`, `0x6DCE87`, `0x6DCEBC`, `0x6DCEF1`, `0x6DCF26`, `0x6DE3E7`, `0x6DE433`, `0x6DE4B8` (`mode_filter` `0..10` predicates)
- `0x6DD516` (`IsMapAllowedForGameType`), `0x6DEE48` (`IsMapSelectable`), `0x6DF1B0`, `0x6DF780` (`GetDefaultMapIndex`), `0x6E077C` (`ParseDynMapInfo`), `0x6E0C5A` (`LoadDynMapCache`), `0x6E0D2C` (`BuildFilteredList`)

## LAN Server Wave Note (replacing `fxdynmapinfo.ssd`)
- Offline/Phase 1 uses `Assets/fx/Map/<map_code>/map.json` (`spawns.size()`) as default `max_players`, overridden by optional `map_meta` entries in `Client/data/game_modes.json` (`{max_players, group_id, category_type, ai_restrict, disabled}`).
- In the future LAN Server wave, the server/host will push this `map_meta` table on login/channel-join to replace `CA.exe`'s server-pushed `fxdynmapinfo.ssd` cache (`0x6E0C5A -> 0x6E077C`).

## UNKNOWN
- Binary `fxdynmapinfo.ssd` payload is server-pushed at runtime and not present in this repository, so exact per-map `group_id` (`+41`), `category_type` (`+40`), and `max_players` (`+108`) values for every VN map are `UNKNOWN` until captured from a live VN server or cached `.ssd` file.
- Exact meaning of `v24`, `v25`, `v28`, `v30`, `v31`, `v32` in `sub_6E077C` (`DynMapRecord` auxiliary fields) is `UNKNOWN` (not needed for map-by-mode filtering).
