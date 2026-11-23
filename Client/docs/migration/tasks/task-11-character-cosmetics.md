# Task 11: Character Cosmetics & 13-Slot Decoration Renderer (`AvatarDeco`, `CharDeco`, `IDDeco`, `BombDeco`)

## Goal
Render equipped character cosmetics (hat, cloth, face/eyes, wings/flag/aura, ID name frame) on `CGOBomber` (and `CGOShopBomber` preview) matching the original client's 13-slot decoration system (`0x5A517F` -> `0x58F6EF` -> `0x58F557` -> `0x58EE0D`), using the already-decoded `Client/Assets/charte/` and `Client/Assets/emote/` sprites.

## Verified Prerequisites
- **`SpriteDB` (`Client/scripts/sprite_db.gd`):** `resolve_sprite_dir()` **already supports** `charte/`, `emote/`, `fxasset/`, `fx/`, `BombDeco/`, `AvatarDeco/`, `CharDeco/`, `IDDeco/`, `Fanfare/` — no loader rewrite needed.
- **`BombDeco` (Water Bomb Skins):** **Already wired & rendering** via `Session.equipped_bomb_skin` -> `CGOBomber.bomb_skin` -> `CMapActionBomb.place_bomb()` -> `CGOBomb.setup()` (`Client/Assets/charte/BombDeco/Bomb001..`).
- **Cosmetic Assets Present:**
  - `Client/Assets/charte/AvatarDeco/*LayerAdjust` & `*LayerStatic` (team-colorable + static layers)
  - `Client/Assets/charte/CharDeco/*` (static & 4-direction `Down/Up/Left/Right`)
  - `Client/Assets/emote/IDDeco/IDDeco_C*` (animated/static ID name frames)
  - **`IDDX/` Unique Items Note (must handle in `/porter`):** 4 `AvatarDeco` items (`A06_20_0007`, `A06_30_0004`, `A06_41_0002`, `A06_50_0002`) and 2 icons (`IconA06_10_0001icon`, `IconA10_10_0001icon`) exist **only** in `Client/Assets/charte/IDDX/<name>/entry_00..03/` (not in `AvatarDeco/` or `Icon/`). Add a small `SpriteDB` fallback (or flatten them) so `AvatarDeco/<item>_{0|1}Layer{Adjust|Static}` and `Icon/<item>` resolve cleanly for all 6 items (note: `A06_20_0007` has 4 layers, `A06_30_0004` & `A06_50_0002` have 2 Static-only layers `entry_00`/`entry_01`, `A06_41_0002` has 4 layers).

## Scope (IDA Addresses in `AnalizeVNClient/ca_unpacked.exe.i64`)
- `0x5A517F` (`for (i = 0; i < 13; ++i)` decoration equip loop on bomber init)
- `0x8D4A0F` -> `0x58E7AA` (13-slot equip data reader)
- `0x58F6EF` -> `0x58F557` -> `0x58EE0D` (13-slot decoration attachment, Z-order back/front split, and `LayerAdjust`/`LayerStatic` compositing)
- `0x5C9741` -> `0x8D9F9C` -> `0x8D5463` (90-state -> 44-frame `AvatarDeco` mapping via `0xC37AF8`/`0xC37C60`; pass sprite `frame_idx`, NOT timeline `step_idx`)

## Allowed Files
- Spec: `docs/migration/specs/character_cosmetics.md` (+ mirror `Client/docs/migration/specs/character_cosmetics.md`)
- New Godot helper: `Client/scripts/objects/cgo_bomber_cosmetics.gd` (`class_name CGOBomberCosmetics extends RefCounted`)
- Updated loader (if using fallback): `Client/scripts/sprite_db.gd` (fallback lookup into `charte/IDDX/<name>/entry_XX` for the 6 unique `IDDX/` items)
- Updated renderer: `Client/scripts/objects/cgo_bomber.gd` (add cosmetic `Sprite2D` back/front + `IDDeco` layers synced in `_update_visuals()` using `0xC37AF8`/`0xC37C60` and hidden on all 46 `-1` states: `Die`, `Faint`, `LockedIn*`, `Ghost*`, `Hedgehog*`, `SnowHit/Dying/Spin`, `StaticStop`)
- Tests: `Client/tools/test_character_cosmetics.gd` + `--write-movie` visual check of bomber wearing `AvatarDeco` + `IDDeco` + `BombDeco`

## Execution Phases
1. **`/analyst` (DONE):** Decompiled all cosmetic & `IDDX/` functions; zero `UNKNOWN`s remaining in `docs/migration/specs/character_cosmetics.md`.
2. **`/porter` (READY):** Implement `cgo_bomber_cosmetics.gd`, add `IDDX/` fallback in `sprite_db.gd` for the 6 unique items, wire cosmetic layers into `cgo_bomber.gd::_update_visuals()`, add headless unit tests + `--write-movie` visual verification.

## Acceptance Criteria
- Equipping `hat`, `cloth`, `face`, `char_deco`, and `id_deco` renders aligned with the bomber's pivot/offset across all 4 directions (`Down/Up/Left/Right`) and team-colors `LayerAdjust` correctly.
- Cosmetics hide cleanly when `is_bomber_visible() == false` (bush concealment), in Ghost mode, or when transformed into Hedgehog (`0x74A11F`).
- `BombDeco/Bomb001`.. skins verified end-to-end with `CGOBomb`.
- Headless tests and visual `--write-movie` check pass cleanly.
