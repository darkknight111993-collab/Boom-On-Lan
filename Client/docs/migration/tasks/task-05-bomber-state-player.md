# Task 05: `CGOBomberBase` `ObjectTable` 90-State Animation Player

## Goal
Replace hardcoded per-render-frame animation math (`anim_frame % 5`, `anim_tick >= 4`, etc.) in `Client/scripts/objects/cgo_bomber.gd` with a pure 30ms fixed-tick `ObjectTable` state player on `CGOBomberBase` (`Client/scripts/objects/cgo_bomber_base.gd`), matching the original `CGameObject::SetState` (`vtable+92`) + `UpdateAnim` (`sub_58DF45`) and all 90 states (`00..89`) in `Client/data/objecttable.json`.

## Original Addresses & Data in Scope
- **`CGameObject` / `CGOBomberBase`**: `0x592A2B` (ctor), `0x58DF45` (`UpdateAnim` — steps `[frame_idx, duration_ticks]` at 30ms/tick, returns `2` when non-looping state finishes), `vtable+92` (`SetState(state_idx)`).
- **`CGOBomber::DumpDebugState`**: `0x59FA89` (verifies all bomber attributes/timers at 30ms/tick).
- **`ObjectTable` (`Client/data/objecttable.json`)**: 90 states (`00..89`) per character (`Character/C00_A`, `C01_A`, `B01_A`, etc.).

## Files Allowed to Edit
- `Client/scripts/objects/cgo_bomber_base.gd`
- `Client/scripts/objects/cgo_bomber.gd`
- `Client/tools/test_bomber_hierarchy.gd`
- `docs/migration/specs/bomber_hierarchy.md`
- `docs/migration/parity_matrix.md`

## Acceptance Criteria
1. `CGOBomberBase.load_bomber_states("C00")` loads all 90 states (`00..89`) from `res://data/objecttable.json`.
2. `step_bomber_state_tick()` advances frames strictly on 30ms ticks (`_on_tick()`), independent of render FPS.
3. `Walk` (`20..23`) plays `[0,1,2,0,3,4]` at 3 ticks/step; `Ride` (`4..7`) plays `[0,1,2,3,2,1]` at `[6,3,3,6,3,3]` ticks; `Blink` (`0`) plays 7 steps / 135 ticks; `Throw` (`16..19`) plays `[2,1,1,2]` ticks; `Start` (`24`) and `Die` (`1`) follow their exact `objecttable.json` tables.
4. All 5 headless test suites pass with 0 regressions.
