# Task 07: Wire `mock_lobby_flow.json` into Login -> Server/Channel -> Lobby -> Prepare -> Game Stage

## Spec
- [docs/migration/specs/lobby_flow_mock.md](file:///c:/Users/Martin/source/repos/nguyenhung/BomOnLan/docs/migration/specs/lobby_flow_mock.md)
- Data file: [Client/data/mock_lobby_flow.json](file:///c:/Users/Martin/source/repos/nguyenhung/BomOnLan/Client/data/mock_lobby_flow.json)

## Files allowed to edit (when `/porter` runs)
- `Client/data/mock_lobby_flow.json` (add `lobby_strategy`, `create_room_policy`, `special_component_ids` per channel)
- `Client/data/dialogs.json` (add `room_password` using `Lobby/Dlg_LB-RoomPw`, `create_room_stage_clear` using `Lobby/Dlg_LB-MMCreate`, `create_room_ladder` using `Lobby/Dlg_LB-Create_Ladder`; make `lobby_room_info` and `room_info` dynamic)
- `Client/data/screens/lobby.json` (give room slots & user list clean IDs so `screen.gd` hydrates them dynamically from the active channel; wire `GameType` and `ShowAll` filter actions)
- `Client/scripts/session.gd` (store `selected_server_id`, `selected_channel_id`, `active_room_id`, `selected_component_id`, `room_password`, and helper to load `mock_lobby_flow.json`)
- `Client/scripts/auth_service.gd` (seed default accounts/equipped/inventory from `mock_lobby_flow.json` if `user://bnb_lan.json` does not exist)
- `Client/scripts/dialog_manager.gd` (route create-room submit with password + `component_id` + `default_map`; validate `room_password`; hydrate `lobby_room_info` and `room_info` dynamically)
- `Client/scripts/screen.gd` (populate `select_server`, `lobby`, `prepare` from `mock_lobby_flow.json`, route `CreateRoom` via channel `lobby_strategy`, and pass `component_id` + `map_code` to `game_stage`)
- `Client/tools/test_lobby_flow_mock.gd` (headless test validating JSON schema, account lookup, channel strategy/filtering, room join/password/ready/team guard, and `match_start_payload` generation)

## Acceptance criteria
1. `Client/data/mock_lobby_flow.json` parses cleanly and all referenced `char_code`, `component_id`, `map_code`, and `team_color_idx` values exist in `CBomberAttr`, `CComponent`, `game_modes.json`/`TestAirship01`, and `Session.TEAM_COLORS`.
2. Headless test verifies the full state transition `login -> select_channel -> join_room -> start_match` for both Classic (`component_id = 0`) and Hedgehog (`component_id = 11`).
3. All existing 6 headless test suites continue to pass.
