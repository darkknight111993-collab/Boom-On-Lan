# Task 06: Game Mode Component Base (`CComponent`, `CDefaultComponent`, `CHedgehogComponent`)

## Scope (IDA addresses)
- `0x73D1FF` (`CComponent::CComponent`), `0x73B7B1` (`GetType`), `0x73B7B5` (`GetGameStage`), `0x70A304` (`CGameStage::GetComponent`)
- `0x74900D` (`CHedgehogComponent::CHedgehogComponent`, ID `11`), `0x749159` (`OnMatchEnd`), `0x7491D4` (`UpdateCollision`), `0x749342` (`UpdateTick`)

## Spec
- [docs/migration/specs/game_mode_component.md](file:///c:/Users/Martin/source/repos/nguyenhung/BomOnLan/docs/migration/specs/game_mode_component.md)

## Files allowed to create / edit
- Create `Client/scripts/modes/c_component.gd`
- Create `Client/scripts/modes/c_default_component.gd`
- Create `Client/scripts/modes/c_hedgehog_component.gd`
- Edit `Client/scripts/map_view.gd` (wire active `CComponent` instance for bomber creation, flame-hit/pop hooks, and tick hook — default `CDefaultComponent` so existing gameplay is unchanged)
- Create `Client/tools/test_game_mode_component.gd` (`TV-M1..TV-M5`)
- Update `docs/migration/parity_matrix.md` + sync to `Client/docs/migration/`

## Acceptance criteria
1. `CComponent`, `CDefaultComponent`, and `CHedgehogComponent` are pure `RefCounted` classes with static typing and zero scene-tree dependencies.
2. `map_view.gd` defaults to `CDefaultComponent` so all existing tests (`test_airship_stage.tscn`, `test_bomber_hierarchy.gd`, `test_map_tiles.gd`, `test_airship_logic.gd`, `test_bomb_objects.gd`) continue to pass with zero regressions.
3. `godot --headless --path Client --script res://tools/test_game_mode_component.gd` passes `TV-M1..TV-M5`.
4. `parity_matrix.md` rows for `CComponent` and `CHedgehogComponent` updated to `Ported` and synced to `Client/docs/migration/`.

## Golden test cases needed
- None blocking for offline unit parity; for future Hedgehog LAN mode, record a 2P Hedgehog match clip showing bubble-pop -> Hedgehog transform (`59 -> 70`), Hedgehog bumping a trapped teammate/enemy, and end-of-match `Hurrah (61)` / `Cry (62)`.
