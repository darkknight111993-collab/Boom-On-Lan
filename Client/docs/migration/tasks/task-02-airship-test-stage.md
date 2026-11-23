# Task 02: Isolated Airship (Đĩa bay) Test Stage — Map + Item Only

## Goal
Create a clean, standalone playable + headless-testable Godot 4 test stage containing **ONLY**:
- A minimal 15x13 test map (`TestAirship01`) with:
  - Open walkable ground tiles,
  - A small cluster of destructible boxes (tile type 2) to test flying over boxes (`m_fAbPassBox`),
  - A few solid wall obstacles (tile type 1) to verify walls still block Airship,
  - 1 player spawn at `(1, 1)` (NO bots, NO monsters/NPCs, NO script_xml enemies).
- **ONLY Airship items** placed on the ground right next to spawn:
  - `Item/ItemAirship` at `(2, 1)` (primary UFO test item),
  - Optionally `Item/ItemAirshipBroken` at `(3, 1)` (if user wants to compare normal vs broken UFO; keep map free of all other items).

## Workflows
1. **`/godot-adapter`**: Build the test map JSON, playable scene (`test_airship_stage.tscn`), and headless verification script (`test_airship_stage.gd`) without duplicating game rules into presentation code.
2. **`/qa-parity`**: Verify coverage against `docs/migration/specs/item_airship.md` and run headless tests.

## Files Allowed to Edit
- `Client/Assets/fx/Map/TestAirship01/map.json` (new)
- `Client/scenes/test_airship_stage.tscn` (new)
- `Client/tools/test_airship_stage.gd` (new)
- `Client/scripts/map_view.gd` (ONLY minimal hook if needed to load `TestAirship01` cleanly with `bot_ai_enabled = false`, `spawn_monsters_enabled = false`, and no random unrelated items)
- `docs/migration/parity_matrix.md`

## Acceptance Criteria
- Opening `Client/scenes/test_airship_stage.tscn` in Godot launches directly into `TestAirship01` with:
  - 1 playable bomber, 0 bots, 0 monsters,
  - Ground + breakable boxes + solid walls rendered properly (`TEXTURE_FILTER_NEAREST`),
  - Only Airship item(s) spawned on the map (no other items).
- Player can walk onto `(2, 1)`, pick up `Item/ItemAirship`, visually mount `Ship/Airship`, fly over breakable boxes, and collide with solid walls.
- Headless verification passes:
  `godot --headless --path Client --script res://tools/test_airship_stage.gd`
- Zero `TODO`/`pass` stubs and clean resource teardown on exit.
