# Task 01: Airship (Đĩa bay / UFO) Item — Analysis, Spec & Core Logic Parity

## Scope (Addresses & Data in `ca_unpacked.exe.i64`)
- `0x89F3DE` (`CItemAttr::Load`, inferred) — verify exact meaning of the 8 `fields` in `Ship/Airship` (`[2, 10, 0, 1, 2, 0, 0, 0]`) and `Ship/AirshipBroken` (`[2, 2, 0, 1, 2, 0, 0, 0]`).
- `0x59FA89` (`CGOBomber::DumpDebugState`, inferred) — extract exact `CGOBomber` struct offsets for `m_nShipRideCount`, `m_nShipChangeCount`, `m_fAbNotEatItem`, `m_fAbPassBox`.
- `0x59B81C` (`CGOBomber::ApplyItem`, inferred), `0x59B6F6` (`CGOBomber::RideShip`, inferred), `0x5B872A` (`CShip::SetShip`, inferred), `0x5975D1` (`CGOBomber::RefreshShipStats`, inferred).
- Callers of `0x59B6F6`: `0x59BA8A`, `0x59E53F`, `0x59ED72`, `0x5A517F` — trace dismount, bomb-hit absorption while riding, and `m_fAbPassBox` / `m_fAbNotEatItem` checks in movement & item pickup (`kCGOBomber_IsMovableGrid` / `kCGOBomber_MoveSimple`).

## Workflows
1. **`/analyst`**: Trace the addresses above via `ida-pro` MCP (cross-check `ca.exe.c` / `ca.exe.g.c` snippets if helpful) and write `docs/migration/specs/item_airship.md` with full evidence (addresses + pseudocode excerpts + test vectors + `UNKNOWN` list).
2. **`/porter`**: Implement/align pure logic from `docs/migration/specs/item_airship.md` (no reading decompile directly) and add headless unit tests.

## Files Allowed to Edit
- `/analyst`: `docs/migration/specs/item_airship.md`, `docs/migration/parity_matrix.md`
- `/porter`:
  - `Client/scripts/objects/citem_attr.gd`
  - `Client/scripts/objects/cgo_bomber.gd`
  - `Client/tools/test_airship_logic.gd`
  - `docs/migration/parity_matrix.md`

## Acceptance Criteria
- Every Airship behavior claim in `docs/migration/specs/item_airship.md` cites address + pseudocode (no guessing; ambiguities marked `UNKNOWN`).
- Exact mechanics verified for:
  1. Picking up `Item/ItemAirship` (flying mount, speed=10) and `Item/ItemAirshipBroken` (speed=2).
  2. `m_fAbPassBox`: flying over destructible boxes (tile type 2) while blocked by solid walls (tile type 1) & map bounds.
  3. `m_fAbNotEatItem`: whether riding Airship blocks eating other ground items, and exact interaction with ground items / bombs.
  4. Hit by explosion while riding Airship: dismount behavior, invincibility duration (if any), and what happens if dismounted on top of a box!
  5. Animation states (`Ship/Airship` id 933, `Ship/AirshipBroken` id 934) and bomber seat offset/draw order.
- Headless unit test `godot --headless --path Client --script res://tools/test_airship_logic.gd` passes with 0 errors.

## Golden Test Cases Needed (`docs/migration/golden/airship.md`)
- Riding `Item/ItemAirship` over breakable boxes vs solid walls.
- Walking over another ground item while riding `Item/ItemAirship`.
- Getting hit by a bomb explosion while riding `Item/ItemAirship` (both on open tile and while hovering over a breakable box).
- Placing bombs while riding `Item/ItemAirship` (allowed or blocked? on box vs open tile?).
