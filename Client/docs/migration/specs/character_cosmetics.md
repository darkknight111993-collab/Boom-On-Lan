# Character Cosmetics & 13-Slot Decoration Renderer (`AvatarDeco`, `CharDeco`, `IDDeco`, `BombDeco`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + `Client/Assets/charte/` & `Client/Assets/emote/`.
> **Rule:** Every character supports **13 AvatarDeco slots (`0..12`)** using the exact path formula `AvatarDeco/A%02d_%2d_%04d` (`0x58E2DA`), plus `CharDeco` (4-dir/static overlays), `IDDeco` (nameplate frame), and `BombDeco` (already wired on `CGOBomb`).

## Behavior summary
1. **13-Slot Part-Code Mapping (`sub_58E281` @ `0x58E281`):**
   - `slot 0..9` -> `part_code = 10 * slot` (`0, 10, 20, 30, 40, 50, 60, 70, 80, 90`)
   - `slot 10` -> `part_code = 21`
   - `slot 11` -> `part_code = 41`
   - `slot 12` -> `part_code = 22`
2. **Sprite Naming Formula (`sub_58E2DA` @ `0x58E2DA` -> `sub_58E4E0` @ `0x58E4E0`):**
   - `AvatarDeco/A%02d_%2d_%04d` where `char_num` is the 2-digit character index (`00..42`), `part_code` is from `0x58E281`, and `deco_id` is the 4-digit item ID (`0001..9999`).
   - Each `AvatarDeco` item has `_0LayerAdjust` / `_0LayerStatic` (and optional `_1LayerAdjust` / `_1LayerStatic`) sub-layers; `LayerAdjust` is tinted by `team_color` identically to base character layers (`SpriteDB.get_character_frame`).
3. **Character Body Compatibility (`sub_970BBC` @ `0x970BBC`):**
   - A decoration authored for `equip_char_id` is compatible with `char_id` iff `equip_char_id == char_id`, OR `(char_id == 12 && equip_char_id == 6)`, OR `(char_id == 14 && equip_char_id == 5)`, OR `(char_id == 15 && equip_char_id == 8)`.
4. **Mutual Exclusion Rules (`sub_8BE9E1` @ `0x8BE9E1`, called by `sub_58EE0D` @ `0x58ef08`):**
   - Equipping a combo/full-body slot automatically unequips conflicting sub-slots (category `19` = AvatarDeco):
     - `slot 2` clears `[10, 12]`
     - `slot 3` clears `[10, 12]`
     - `slot 4` clears `[11, 12]`
     - `slot 6` clears `[11, 12]`
     - `slot 10` (part `21`) clears `[2, 3, 12]`
     - `slot 11` (part `41`) clears `[4, 6, 12]`
     - `slot 12` (part `22`, full costume) clears `[2, 3, 4, 6, 10, 11]`
5. **`BombDeco`, `CharDeco`, `IDDeco`:**
   - `BombDeco/Bomb001..`: already wired through `Session.equipped_bomb_skin` -> `CGOBomber.bomb_skin` -> `CGOBomb`.
   - `CharDeco/CharDeco_*[Down|Up|Left|Right]`: directional or static overlay synced with bomber `dir`.
   - `IDDeco/IDDeco_C*`: animated/static frame drawn behind/around `name_lbl`.
   - `SpriteDB.resolve_sprite_dir()` (`Client/scripts/sprite_db.gd`) already resolves `charte/`, `emote/`, `AvatarDeco/`, `CharDeco/`, `BombDeco/`, `IDDeco/`.

## Class / state (original class -> Godot class)

### `CGOBomberCosmetics` (`0x58E281` / `0x58E2DA` / `0x58EE0D` / `0x8BE9E1` / `0x970BBC`) -> `Client/scripts/objects/cgo_bomber_cosmetics.gd` (`extends RefCounted`)
- Constants: `MAX_SLOTS := 13`
- Static helpers:
  - `slot_to_part_code(slot_idx: int) -> int` (`0x58E281`)
  - `format_avatar_deco_path(char_id: int, slot_idx: int, deco_id: int) -> String` (`0x58E2DA` -> `0x58E4E0`)
  - `is_char_compatible(equip_char_id: int, char_id: int) -> bool` (`0x970BBC`)
  - `get_conflicting_slots(slot_idx: int) -> Array[int]` (`0x8BE9E1`)
- Instance state & methods:
  - `var slots: Array[String]` (13 entries, `""` if empty)
  - `var char_deco: String = ""`
  - `var id_deco: String = ""`
  - `equip_slot(slot_idx: int, sprite_base: String) -> Array[int]` (equips slot, clears conflicting slots via `get_conflicting_slots()`, returns cleared slot indices)
  - `clear_slot(slot_idx: int) -> void`
  - `clear_all() -> void`

## Test vectors (code-evidence)
- **TV-C1 (`slot_to_part_code`, `0x58E281`):** `0->0, 1->10, 9->90, 10->21, 11->41, 12->22, 13->0`.
- **TV-C2 (`format_avatar_deco_path`, `0x58E2DA`/`0x58E4E0`):** `(2, 1, 1)` -> `"AvatarDeco/A02_10_0001"`, `(0, 12, 5)` -> `"AvatarDeco/A00_22_0005"`.
- **TV-C3 (`is_char_compatible`, `0x970BBC`):** `(2, 2)==true`, `(6, 12)==true`, `(5, 14)==true`, `(8, 15)==true`, `(6, 14)==false`.
- **TV-C4 (`equip_slot` mutual exclusion, `0x8BE9E1`):** equip slots `2, 3, 4, 6`, then equip slot `12` (full costume) -> clears `[2, 3, 4, 6]` cleanly; equip slot `10` -> clears `[2, 3, 12]`; equip slot `11` -> clears `[4, 6, 12]`.

## `Assets/charte` (`CharTE` Pack) Architecture (`0x5C8265` / `0x8E4A03`)
- At startup (`0x8E4A03`), the client mounts 4 pack files: `fxite`, `charte`, `emote`, `fxasset`.
- `CGameObjectTemplateLib` (`0x5C8265`, `dword_E60948`) loads `ObjectTable/CharTEObjectTable` (`Client/Assets/charte/ObjectTable/CharTEObjectTable/objecttable.json`, **726 entries**: `AvatarDeco` 370, `CharDeco` 251, `GradeDeco` 41, `BombDeco` 40, `_ForITE` 13, `LadderDeco` 11) into the shared ObjectTable registry alongside `fx`, `emote`, and `fxasset`.
- Subdirectories in `Client/Assets/charte/`:
  - `AvatarDeco/` (`1,565` folders): `A%02d_%2d_%04d_{0|1}Layer{Adjust|Static}` (44-frame pose sheets; `_0` front layer, `_1` back layer).
  - `BombDeco/` (`39` folders, `CBombDecoMan` `0x591F35`): `Bomb001..Bomb039` (4-frame animated bomb skins).
  - `CharDeco/` (`663`) & `CharDecoAdj/` (`426`, `CCharDecoMan` `0x5AA4B6`): `CharDeco_%c%04d` / `C%02d_CharDeco_%c%04d` static or 4-dir (`Down/Left/Right/Up`) character overlays (`CharDecoAdj` adds `LayerAdjust`+`LayerStatic`).
  - `GradeDeco/` (`80`, `0xc7c99c`) & `LadderDeco/` (`10`, `0xc7ca00`): rank/grade badges (`Small`, `Large` `G`, `Preview`).
  - `Icon/` (`899`): Shop & Inventory thumbnail icons (`A02_10_0001icon`, `CharDeco_*Icon`, `GradeDeco_*icon`, `LadderDeco_*icon`).
  - `IDDX/` (`12`): legacy `CWDAAgent::BatchProcess` (`0x99FEAA`) on-demand mini-packs (`.idx` + `.idd` pairs mounted via `CPackSysMan::Attach` `0xA388C0`). See **IDDX Binary Schema** below.

## `IDDX/` Binary Schema (`0x99FEAA`, `0xA388C0`, `0xA355B0`, `0xA37880`, `0xA35640`, `0xA26330`)
- Each folder in `Client/Assets/charte/IDDX/` is an unpacked `.idx` + `.idd` mini-pack containing:
  - `entry_00..03/`: already-converted sprite folders (`frames/*.png`, `sprite.json`, `frames.tres`) corresponding in order to the non-ObjectTable entries of `index.bin`.
  - `index.bin`: IDF v15 pack index encrypted with **4-byte CBC-XOR (`sub_A355B0` @ `0xA355B0`, key = `0x5B201FC`)**:
    - `out_u32[0] = 0x5B201FC ^ in_u32[0]`; `out_u32[i] = out_u32[i-1] ^ in_u32[i]`; trailing `size & 3` bytes XORed with low bytes of `out_u32[last]`.
    - Decrypted layout: `magic: u32 (0)`, `version: u32 (15)`, `count: u32`, followed by `count` records of `(name_len: u32, name: ascii[name_len], offset: u32, size: u32, key1: u32, crc: u32)`.
    - Sprite entries have `key1 == 0, crc == 0` (unencrypted); `ObjectTable/<item>` has non-zero `key1` and CRC (`sub_A26330` @ `0xA26330`).
  - `tail.bin` (`130` bytes): encrypted `ObjectTable/<item>` binary (`sub_A35640` @ `0xA35640`, using `key1` from `index.bin`):
    - `out_u32[0] = key1 ^ in_u32[0] ^ 0x9C6C95CE`
    - `out_u32[i] = out_u32[i-1] ^ in_u32[i] ^ ((i * i * (i + 966) * (i + 2020)) & 0xFFFFFFFF) ^ 0x9C6C95CE` (`i >= 1`)
    - Trailing `size & 3` bytes XORed with low bytes of `out_u32[last]`.
    - Decrypted layout (`sub_5C6ABC` @ `0x5C6ABC`): standard single-entry `ObjectTable` (`entry_count=1`, `name="AvatarDeco/<item>"`, `body_offset=34`, `state_count=2`: state `"00"` -> `AvatarDeco/<item>_0` `[0,1]`, state `"01"` -> `AvatarDeco/<item>_1` `[0,1]`).
- **Asset deduplication / unique items in `IDDX/`:**
  - `6` items (`A06_20_0005`, `A06_20_0008`, `A06_30_0005`, `A06_60_0003`, `A10_30_0003`, `A10_50_0001`) are already duplicated in `Assets/charte/AvatarDeco/` + `CharTEObjectTable`.
  - `4` `AvatarDeco` items (`A06_20_0007`, `A06_30_0004`, `A06_41_0002`, `A06_50_0002`) and `2` icons (`IconA06_10_0001icon`, `IconA10_10_0001icon`) exist **only** in `IDDX/` (`entry_00..03` map to `_0LayerAdjust`, `_0LayerStatic`, `_1LayerAdjust`, `_1LayerStatic` for 4-entry items, or `_0LayerStatic`, `_1LayerStatic` for 2-entry items).

## 90-State -> 44-Frame `AvatarDeco` Mapping (`CGOTAvatar::ComposeFrames` `0x5C9741` -> `sub_8D9F9C` `0x8D9F9C` -> `sub_8D5463` `0x8D5463`)
- Each `AvatarDeco` item has **two** 44-frame (`0..43`) pose sheets (each split into `LayerStatic` + team-tinted `LayerAdjust`):
  - **Sheet `_0` (`layer == 0`):** `_0LayerStatic` + `_0LayerAdjust` (in-game movement/ride/slide poses).
  - **Sheet `_1` (`layer == 2`):** `_1LayerStatic` + `_1LayerAdjust` (emotes, lobby `Display`, HUD `Portrait`, `Start`, `Throw`, `Dril`).
- Lookup tables in `.rdata`:
  - `Display`: `0xC37AE0` -> `(layer=2, start=0)`
  - `Portrait`: `0xC37AE8` -> slot 0 `(layer=2, start=41)`, slot 1 `(layer=2, start=43)`
  - `dword_C37AF8[90]` (`0xC37AF8..0xC37C5F`): layer index per `CGOBomberBase` state (`0` = `_0`, `2` = `_1`, `-1` = hidden)
  - `dword_C37C60[90]` (`0xC37C60..0xC37DC7`): start frame index (`0..43`) in that sheet
- **Exact frame formula (`sub_8D5463` @ `0x8d54eb..0x8d55d8`):** for a given `state_idx` (`0..89`) and base character sprite `frame_idx` (unique frame index in the sprite sheet, NOT step index):
  - If `layer == -1`, do **not** render `AvatarDeco`.
  - Otherwise, render `deco_frame = start_frame + frame_idx` from `_0Layer*` (`layer == 0`) or `_1Layer*` (`layer == 2`), aligned by each sprite's `meta.json` pivot (`0x8d5541`).

| States (`0..89`) | Action | Layer (`0xC37AF8`) | Start Frame (`0xC37C60`) | Frame Range (44f sheet) |
|---|---|---|---|---|
| `15, 23, 79` | `StopDown` / `WalkDown` / `SnowThrowDown` | `0` (`_0`) | `0` | `0..4` (5f) |
| `14, 22, 78` | `StopRight` / `WalkRight` / `SnowThrowRight` | `0` (`_0`) | `5` | `5..9` (5f) |
| `13, 21, 77` | `StopUp` / `WalkUp` / `SnowThrowUp` | `0` (`_0`) | `10` | `10..14` (5f) |
| `12, 20, 76` | `StopLeft` / `WalkLeft` / `SnowThrowLeft` | `0` (`_0`) | `15` | `15..19` (5f) |
| `27..30, 31..34` | `SlideJump` / `SlideJumpHold` (L/U/R/D) | `0` (`_0`) | `20` | `20..23` (4f) |
| `39..42` | `SlideRide` (L/U/R/D) | `0` (`_0`) | `24` | `24..27` (4f) |
| `7, 11` | `RideDown` / `StopRideDown` | `0` (`_0`) | `28` | `28..31` (4f) |
| `6, 10` | `RideRight` / `StopRideRight` | `0` (`_0`) | `32` | `32..35` (4f) |
| `5, 9` | `RideUp` / `StopRideUp` | `0` (`_0`) | `36` | `36..39` (4f) |
| `4, 8` | `RideLeft` / `StopRideLeft` | `0` (`_0`) | `40` | `40..43` (4f) |
| `0` (+ `Display`) | `Blink` (and Lobby/Shop `Display`) | `2` (`_1`) | `0` | `0..2` |
| `3, 26` | `Hurrah` / `Release` | `2` (`_1`) | `3` | `3..6` |
| `35..38` | `Dril` (L/U/R/D) | `2` (`_1`) | `7` | `7..14` |
| `24` | `Start` | `2` (`_1`) | `15` | `15..24` |
| `16..19` | `Throw` (L/U/R/D) | `2` (`_1`) | `25` | `25..40` |
| `Portrait` (HUD) | Portrait frame 0 / frame 1 (`0xC37AE8`) | `2` (`_1`) | `41` / `43` | `41..43` |
| `1, 2, 25, 43..57, 58..75, 80..89` | `Die`, `Faint`, `LockedIn*`, `Ghost*`, `Hedgehog*`, `SnowHit/Dying/Spin`, `StaticStop` (**46 states**) | `-1` (hidden) | `-1` | *(not rendered)* |

## Functions covered (address list)
- `0x58E281`, `0x58E2DA`, `0x58E410`, `0x58E478`, `0x58E4E0`, `0x58E7AA`, `0x58E9BC`, `0x58EE0D`, `0x58F557`, `0x58F6EF`, `0x8BE9E1`, `0x8D4A0F`, `0x970BBC`
- `0x5C8265`, `0x5C689C`, `0x5C6ABC`, `0x5C92F1`, `0x5C9741`, `0x8D9F9C`, `0x8D5463`, `0x5AA4B6`, `0x591F35`, `0x8E4A03`
- `0x99FEAA`, `0xA388C0`, `0xA355B0`, `0xA37880`, `0xA35640`, `0xA26330`

## UNKNOWN
- None (all `AvatarDeco`, `CharDeco`, `BombDeco`, `IDDeco`, 90->44 frame mapping, and `IDDX/` schemas verified).
