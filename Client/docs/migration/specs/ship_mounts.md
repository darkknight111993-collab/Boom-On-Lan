# Shared Mount System (`CShipAttr` & `CGOShip` — Airship, Owl, Turtle, Octopus, Chicken, RailCar, Kart, Tank)

> Replaces & generalizes `specs/item_airship.md`. In `ca_unpacked.exe.i64`, ALL mounts share **one single entity class (`CGOShip`, RTTI `.?AVCGOShip@@` @ `0xe30264`)** and **one data table (`CShipAttr`, RTTI `.?AVCShipAttr@@` @ `0xe4853c`)** — there are NO per-mount subclasses (`CGOAirship`, `CGOOwl`, `CGOTurtle` do not exist).

## Behavior summary
- All category-2 (`fields[2] == 2`) items in `Attr/ItemAttr` (`0x89F3DE`) represent mounts referencing a `CShipAttr` record by `ship_id` (`fields[3]`).
- When a `CGOBomber` eats a category-2 item (`0x89CAC8`), the client calls `CGOBomber::RideShip(ship_id, x, y)` (`0x5992A0`, vtable `+328`).
- If `RideShip` succeeds (bomber valid & `!m_goShip.IsValid()`), `CGOShip::Init` (`0x5BC88E`) loads the template name via `0x5BC742`, marks `is_flying = (ship_type == 2)`, copies the 2 speed slots (`speed_normal`, `speed_alt`) and 5 ability slots (`ab0..ab4`), and `0x89CAC8` enables ability slots 0..3 via `ApplyShipAbility` (`0x89B0D4`):
  - `1` → `m_fAbNotEatItem = 1` (`0x599BAC`, `CGOBomber + 1672`)
  - `2` → `m_fAbPassBox = 1` (`0x599B78`, `CGOBomber + 1648`)
  - `3` → ability 3 (`0x599BE3`, `+421*4`)
  - `4` → Kart flag (`0x599C0F`, `+424*4`)
  - `5` → Tank flag (`0x599C68`, `+427*4`)
  - `6` → ability 6 (`0x599CB5`)
- Mounting sets `m_nShipRideCount = 15` (`0x5A3F7D` @ `0x5a47c3`, 450 ms). Getting hit by explosion while riding (`0x5AF1D0` → `0x59F248`) sets `m_nShipRideCount = -50` (`0x5A3F7D` @ `0x5a47d4`, 1.50 s) + 50-tick invulnerability, and if the bomber's 40×40 box overlaps a breakable/movable box, snaps the bomber to a safe grid cell `(40*col, 40*row + 39)` via `0x594AE3`.
- When `m_nShipRideCount < 0` increments to `0` (`0x5A6244` @ `0x5a67cc`), `CGOBomber::UnrideShip` (`0x59937D`) invalidates `m_goShip`, calls `RemoveShipAbilities` (`0x89C49E`) to clear all 5 ability slots, and transitions riding states `[8..11]` to `state + 4`.
- Special-case mount hooks observed in binary:
  - `ship_id == 16` (Shark): appends `%s%02d` variant suffix (`0x5BC742` @ `0x5bc783`) and attaches `CGOShipEffectSharkEatBomb` (`.?AVCGOShipEffectSharkEatBomb@@` @ `0xe3023c`, `0x5BC88E` @ `0x5bca16`).
  - `ship_id == 10 || 11` (Kart): boost check in `0x5BC639` + `0x5A6244` (`0x5a64f0–0x5a6542`).
  - `Item/ItemAirshipBroken`: triggers `Item/ItemSpanner` hint (`0x59B81C` @ `0x59b925`); `Turtle0`/`Octopus0` trigger `Can` hints (`0x59b8ef–0x59b9d2`).
  - **Mount / Vehicle SFX ownership (`0x5BC4E0..0x5BCDB3` vs `CGOBomber`):** `CGOShip` itself has **0 audio calls** (`CGOShip::Update` `0x5BCA63` only updates sprite states from owner `CGOBomber` at `this + 264`). All mount/vehicle SFX (ride, fire, boost, looping move) are played/stopped by `CGOBomber` via `sub_6734D5(sound_id, ...)` and `sub_67171F(sound_id)` (e.g., `133..136` at `ca.exe.c:348848..348941` & `349414..349422`, `168..170` / `198..201` at `ca.exe.c:340521..341211`). In Godot, `Itm_TankMove` and `Itm_KartMove` assets exist in `Client/Assets/fx/Wave/` and belong in `cgo_bomber.gd` (not yet wired).

---

## Class / state (original class -> Godot class)

### 1. `CShipAttr` (RTTI `.?AVCShipAttr@@` @ `0xe4853c`) & `CItemAttr` (`.?AVCItemAttr@@` @ `0xe48524`) → `CItemAttr` (`Client/scripts/objects/citem_attr.gd`)
| Field / Method | Address | Evidence / Layout |
| :--- | :--- | :--- |
| `CItemAttr::Load` | `0x89F3DE` | Loads `"Attr/ItemAttr"` (`0xc77d7c`). 192B `CShipAttr` records at `this + 244140` (`v7-64`: name[64], `v7+0`: `ship_id`, `+12`: `ship_type`, `+24/+36`: `speed[2]`, `+48..+96`: `abilities[5]`). 244B item records at `this + 28`. |
| `IsShipOrItemName` | `0x8D8DA0` | `return !sub_9E2FD1(a1, "Ship/", 5) \|\| sub_9E2FD1(a1, "Item/", 5) == 0;` |
| `CItemAttr::EatItem` | `0x89CAC8` | Category `2` (`0x89cc63`): reads `ship_id = *(v8 + 184)`, calls `RideShip` (`vtable+328`), then applies ability slots 0..3 via `0x89B0D4`. |
| `ApplyShipAbility` | `0x89B0D4` | `switch (ability_id)`: `1`=`m_fAbNotEatItem`, `2`=`m_fAbPassBox`, `3`=`+421*4`, `4`=Kart, `5`=Tank, `6`=`0x599CB5`. |
| `RemoveShipAbilities` | `0x89C49E` | Calls `0x89B0D4(ab, 0, bomber)` for all 5 ability slots (`v2 + 132..180`). |

### 2. `CGOShip` (RTTI `.?AVCGOShip@@` @ `0xe30264`, embedded at `CGOBomber + 2104`) → Mount state in `CGOBomber` (`Client/scripts/objects/cgo_bomber.gd`)
| Field / Method | Address | Evidence / Layout |
| :--- | :--- | :--- |
| `CGOShip::CGOShip` | `0x5BC4E0` | Inherits `CGameObject` (`0x58D298`), vtable `0xc3661c` / `0xc36614`. Fields: `+144` (`+36*4`): `ship_id`; `+156` (`+39*4`): variant; `+168` (`+42*4`): `is_flying`; `+180, +192` (`+45*4`, 2×12B): `speed[2]`; `+204..+252` (`+51*4`, 5×12B): `abilities[5]`. |
| `CGOShip::ResolveSpriteName` | `0x5BC742` | Looks up `CShipAttr` name via `0x89EF9B` + `0x89F275` (`"Ship/Airship"`, `"Ship/Owl"`, `"Ship/Turtle0"`, ...). Only `ship_id == 16` appends `%02d`. |
| `CGOShip::Init` | `0x5BC88E` | Sets template via `vtable+20`, copies `ship_id`, `is_flying = (ship_type == 2)`, `speed[2]`, `abilities[5]`, initial state `7`, marks valid (`vtable+12`, `1`). |
| `CGOShip::GetAltSpeed` | `0x597EC6` | Returns `speed[1]` (`+192`) if non-zero, else falls back to `speed[0]` (`+180`). |
| `CGOShip::IsKartBoosting` | `0x5BC639` | `(ship_id == 10 \|\| ship_id == 11) && (state - 8) <= 3`. In `0x5A6244` (`ca.exe.c:349464..349476`): doubles speed (`v58 *= 2`); Kart fuel (`CGOBomber + 2452*4`) halves speed when `< 240` and drops to `2 px/tick` at `0`. |
| `CGOShip::IsSpecialAction` | `0x5BC676` | `(ship_id in [12, 14, 15, 16]) && (state - 8) <= 3` (Tank fire / Shark eat action states). |
| `CGOShip::IsSharkEating` / `UpdateSharkVariant` | `0x5BC717` / `0x5BC7C9` | `ship_id == 16`: eats bomb states `12..15` (`0x5BC717`); updates `%s%02d` variant (`0` if `eaten == 0`, `1` if `1..2`, `2` if `>= 3`, `0x5BC7C9`). |
| `CGOShip::Update` | `0x5BCA63` | Syncs sprite state (`Move`/`Shoot`/`Idle`) from owner `CGOBomber` (`this + 264`); **no audio calls** (`sub_6734D5`/`sub_67171F` never called in `CGOShip`). |

### 3. `CGOBomber` (RTTI `.?AVCGOBomber@@` @ `0xe22590`) → `CGOBomber` (`Client/scripts/objects/cgo_bomber.gd`)
| Method / Field | Address | Evidence / Behavior |
| :--- | :--- | :--- |
| `CGOBomber::CGOBomber` | `0x5A3F7D` | Initializes `this+10492` (`this[2623]`) = **`15`** (mount ticks), `this+10504` (`this[2626]`) = **`50`** (dismount ticks). |
| `CGOBomber::DumpDebugState` | `0x59FA89` | Verifies offsets: `m_nSpeed` (`+1624`), `m_fAbPassBox` (`+1648`), `m_fAbNotEatItem` (`+1672`), `m_goShip` (`+2104`), `m_nShipRideCount` (`+2380`), `m_nShipChangeCount` (`+2392`). |
| `SetAbPassBox` / `IsAbPassBox` | `0x599B78` / `0x599BA4` | Writes/reads `CGOBomber + 1648`. |
| `SetAbNotEatItem` / `CanEatItem` | `0x599BAC` / `0x59D510` | Writes/checks `CGOBomber + 1672`; when `1`, ground items are ignored on overlap. |
| `RideShip(ship_id, x, y)` | `0x5992A0` | Guards `IsValid(this) && !m_goShip.IsValid()`. Inits `m_goShip`, sets `m_nShipRideCount = 15`, `m_nShipChangeCount = 0`. |
| `TakeOffShip()` | `0x59F248` | Vtable `+332`. Sets `m_nShipRideCount = -50`, grants 50-tick invulnerability (`vtable[129](50, 0, 0)`), updates riding states. |
| `OnHitWhileRidingShip()` | `0x5AF1D0` | Calls `0x59F248`; if 40×40 rect overlaps breakable (`0x7292F3`) or movable (`0x71FBFD`) box, snaps bomber to safe cell `(40*col, 40*row + 39)` via `0x594AE3`. |
| `UnrideShip()` | `0x59937D` | Invalidates `m_goShip`, calls `0x89C49E` (`RemoveShipAbilities`), transitions riding state `8..11 -> state + 4`. |
| `IsMovableGrid` | `0x598646` | Calls `CPlayMap::IsBlockedTile` (`0x72C18E`): when `m_fAbPassBox == 1`, skips breakable (`0x7297EE`) & movable (`0x729826`) boxes; still blocked by bounds, walls (`0x729890`, `map+0x93059C`), and bombs (`0x71F9DF`, `0x725941`, `0x5C0F18`). |
| `GetStepPixelsPerTick` | `0x595CB6` / `0x59EC93` | When `m_goShip.IsValid() && m_nShipRideCount >= 0`, returns `speed[0]` (`m_goShip+180`) in px/30ms tick (or `0x597EC6` on special tile). |
| `GetShipRenderPos` / `RenderShip` | `0x5990D6` / `0x59923A` | Parabolic mount/dismount jump arcs & dismount blink visibility. |

---

## Formulas and constants (with addresses)

1. **Complete `CShipAttr` Table** (`Client/data/item_attr.json`, verified against `0x89F3DE` + `0x5BC88E` + `0x89B0D4`):
   | `ship_id` | `name` | `ship_type` (`1`=ground, `2`=fly) | `speed_normal` (px/30ms) | `speed_alt` (px/30ms) | Abilities (`0x89B0D4`) |
   | :---: | :--- | :---: | :---: | :---: | :--- |
   | `1` | `Ship/Airship` | `2` (fly) | `10` (333.33 px/s) | `0` | `1` (`NotEatItem`), `2` (`PassBox`) |
   | `2` | `Ship/Owl` | `1` (ground) | `5` (166.67 px/s) | `0` | none |
   | `3` | `Ship/Turtle0` | `1` (ground) | `2` (66.67 px/s) | `0` | none |
   | `4` | `Ship/Turtle1` | `1` (ground) | `9` (300.00 px/s) | `0` | none |
   | `5` | `Ship/AirshipBroken` | `2` (fly) | `2` (66.67 px/s) | `0` | `1` (`NotEatItem`), `2` (`PassBox`) |
   | `6` | `Ship/Octopus0` | `1` (ground) | `2` (66.67 px/s) | `0` | none |
   | `7` | `Ship/Octopus1` | `1` (ground) | `9` (300.00 px/s) | `0` | none |
   | `8` | `Ship/RailCar` | `1` (ground) | `2` (66.67 px/s) | `10` (333.33 px/s) | none |
   | `9` | `Ship/Chicken` | `2` (fly) | `10` (333.33 px/s) | `0` | `1` (`NotEatItem`), `2` (`PassBox`) |
   | `10` / `11` | `Ship/Kart` | `1` (ground) | `5` (166.67 px/s) | `10` (333.33 px/s) | `4` (`Kart`) |
   | `12` | `Ship/Tank` | `1` (ground) | `5` (166.67 px/s) | `0` | `5` (`Tank`) |
2. **Mount / Dismount Tick Constants** (`0x5A3F7D`): mount = `15` ticks (`450 ms`), dismount = `50` ticks (`1.50 s`, `m_nShipRideCount = -50`).
3. **Mount / Dismount Jump Arc** (`0x5990D6`):
   - `c > 0`: `dy = int(16 * (int(3 * c / 2) - 13)^2 / 169) - 16` (peak `-16` px at `c = 9`).
   - `-30 < c <= 0`: `dy = int(36 * (c + 17)^2 / 169) - 36` (peak `-36` px at `c = -17`).
   - `c <= -30`: `dy = 0`.
4. **Dismount Blink Visibility** (`0x59923A`): visible iff `c >= 0` OR (`c <= -10 && (-c) % 8 >= 4`).

---

## Flow / state machine

```text
[On Foot: m_goShip invalid, abilities = 0]
   |  Eat category-2 item (0x89CAC8 -> 0x5992A0 RideShip -> 0x5BC88E CGOShip::Init -> 0x89B0D4)
   v
[Mounting: m_goShip valid, m_nShipRideCount = 15 -> 0 (arc peak -16px)]
   v
[Riding CGOShip: m_goShip valid, m_nShipRideCount == 0]
   - Speed = ship.speed[0] px/30ms (or ship.speed[1] via 0x597EC6 on special tile)
   - Flying mounts (Airship, AirshipBroken, Chicken): m_fAbPassBox=1, m_fAbNotEatItem=1
   - Ground mounts (Owl, Turtle0/1, Octopus0/1, RailCar, Kart, Tank): m_fAbPassBox=0, m_fAbNotEatItem=0 (can still eat items)
   |  Explosion hit (0x5AF1D0 -> 0x59F248 TakeOffShip):
   |  m_nShipRideCount = -50, invuln = 50 ticks; if overlapping box -> snap to safe cell (0x594AE3)
   v
[Dismounting: m_nShipRideCount = -50 -> 0 (+1/tick in 0x5A6244)]
   - Arc peak -36px for -30 < c <= 0 (0x5990D6); blink for c <= -10, hidden for -9..-1 (0x59923A)
   |  Reaches 0 -> 0x59937D UnrideShip -> 0x89C49E RemoveShipAbilities (clears all 5 slots)
   v
[On Foot]
```

---

## Test vectors

| # | Scenario | Input | Expected Output | Source |
| :--- | :--- | :--- | :--- | :--- |
| TV-1 | Parse `Ship/Airship` (`id=1`) | `item_attr.json` | `is_flying=true`, `speed=10`, `speed_alt=0`, `ab_not_eat_item=true`, `ab_pass_box=true` | code-evidence (`0x89F3DE`, `0x5BC88E`, `0x89B0D4`) |
| TV-2 | Parse `Ship/AirshipBroken` (`id=5`) | `item_attr.json` | `is_flying=true`, `speed=2`, `speed_alt=0`, `ab_not_eat_item=true`, `ab_pass_box=true` | code-evidence (`0x89F3DE`, `0x5BC88E`, `0x89B0D4`) |
| TV-3 | Parse `Ship/Owl` (`id=2`) & `Ship/Turtle0/1` (`id=3/4`) | `item_attr.json` | `is_flying=false`, `ab_not_eat_item=false`, `ab_pass_box=false`; speeds: Owl=`5`, Turtle0=`2`, Turtle1=`9` | code-evidence (`0x89F3DE`, `0x5BC88E`) |
| TV-4 | Pickup `Item/ItemAirship` on foot | `m_goShip` invalid, eat `ship_id=1` | `RideShip`=`1`, `m_goShip` valid, `m_nShipRideCount=15`, `m_fAbPassBox=1`, `m_fAbNotEatItem=1` | code-evidence (`0x89CAC8`, `0x5992A0`, `0x5A3F7D`) |
| TV-5 | Pickup second mount while riding | `m_goShip` valid, call `RideShip` | `RideShip` returns `0`; current mount unchanged | code-evidence (`0x5992A0` @ `0x5992ba`) |
| TV-6 | Dismount finishes (`m_nShipRideCount` -> `0`) | `c = -1` -> `+1` -> `0` | `UnrideShip` runs, `m_goShip` invalid, all abilities cleared (`0x89C49E`), state `8..11 -> +4` | code-evidence (`0x5A6244`, `0x59937D`, `0x89C49E`) |
| TV-7 | Jump arc (`0x5990D6`) & blink (`0x59923A`) | `c=9`, `c=-17`, `c=-30`; blink `c=0,-5,-10,-12` | `dy(9)=-16`, `dy(-17)=-36`, `dy(-30)=0`; vis `0:T, -5:F, -10:F, -12:T` | code-evidence (`0x5990D6`, `0x59923A`) |
| TV-8 | Alt speed fallback (`0x597EC6`) | Airship (`[10, 0]`) vs RailCar (`[2, 10]`) on special tile | Airship returns `10` (fallback); RailCar returns `10` (`speed_alt`) | code-evidence (`0x597EC6`) |
| TV-9 | `m_fAbPassBox` collision (`0x598646`, `0x72C18E`) | Airship (`PassBox=1`) vs Owl (`PassBox=0`) into breakable box / wall / bomb | Airship passes box, blocked by wall/bomb; Owl blocked by box/wall/bomb | code-evidence (`0x598646`, `0x72C18E`) |
| TV-10 | Dismount over box (`0x5AF1D0`) | Hit while 40×40 rect overlaps breakable/movable box | Sets `c=-50`, invuln=50, snaps bomber to safe cell `(40*col, 40*row+39)` via `0x594AE3` | code-evidence (`0x5AF1D0`, `0x59F248`, `0x594AE3`) |
| TV-11 | Bomb placement while hovering over box (`0x5B1D7B`, `0x59A895`, `0x6E3E58`) | Riding Airship (`m_fAbPassBox=1`) on breakable/movable box vs open ground (manual Space, special bomb, or auto-bomb) | Blocked on box (`sub_72C18E(map, row, col, 1, 0) == 1`); allowed on open ground (`== 0`) | code-evidence (`0x5B1D7B` @ `0x5b1e81`, `0x59A895` @ `0x59a96d`, `0x6E3E58` @ `0x6e3f94`) |

---

## Functions covered (address list)
- `0x89F3DE` (`CItemAttr::Load`), `0x8D8DA0` (`IsShipOrItemName`), `0x89CAC8` (`CItemAttr::EatItem`), `0x89D093`, `0x89B05C`, `0x89B0D4` (`ApplyShipAbility`), `0x89C49E` (`RemoveShipAbilities`)
- `0x5BC4E0` (`CGOShip::CGOShip`), `0x5BC742` (`CGOShip::ResolveSpriteName`), `0x5BC88E` (`CGOShip::Init`), `0x5BCA63` (`CGOShip::Update`), `0x597EC6` (`CGOShip::GetAltSpeed`), `0x5BC639` (`CGOShip::IsKartBoosting`), `0x5BC676` (`CGOShip::IsSpecialAction`), `0x5BC6D3`, `0x5BC717` (`CGOShip::IsSharkEating`), `0x5BC7C9` (`CGOShip::UpdateSharkVariant`)
- `0x5A3F7D` (`CGOBomber::CGOBomber`), `0x59FA89` (`CGOBomber::DumpDebugState`), `0x599B78` (`SetAbPassBox`), `0x599BA4` (`IsAbPassBox`), `0x599BAC` (`SetAbNotEatItem`), `0x599BE3`/`0x599C0F`/`0x599C68`
- `0x5992A0` (`RideShip`), `0x59F248` (`TakeOffShip`), `0x5AF1D0` (`OnHitWhileRidingShip`), `0x594AE3` (`GetSafeFallbackCell`), `0x59937D` (`UnrideShip`)
- `0x5990D6` (`GetShipRenderPos`), `0x59923A` (`RenderShip`), `0x58D66D`, `0x598646` (`IsMovableGrid`), `0x72C18E`/`0x7297EE`/`0x71F9DF`/`0x725941`/`0x72C076`/`0x729890`/`0x72A83C`
- `0x5B1D7B` (`CGOGameBomber::DeferBombOper` — manual Space), `0x59A895` (special bomb), `0x6E3E58` (auto-bomb) — all check `!sub_72C18E(map, row, col, 1, 0)`
- `0x595F83`/`0x59D510` (`CanEatItem`), `0x595CB6`/`0x59EC93` (`GetStepPixelsPerTick`), `0x5A6244` (`Update` ship slice), `0x59C560`, `0x59B81C` (`OnItemHint`)

---

## Runtime wiring status (Godot `cgo_ship.gd` / `cgo_bomber.gd` / `audio_manager.gd`)
- **Ported & wired:** core `CShipAttr` / `CGOShip` (`init_ship`, `get_speed`, `get_sprite_path`, `calc_jump_arc_dy` `0x5990D6`, `calc_visible_for_ride_count` `0x59923A`, `MOUNT_TICKS=15`, `DISMOUNT_TICKS=50`, Airship `PassBox`/`NotEatItem`), Tank fire (`Itm_TankFire`) / ride (`Itm_TankRide`), looping vehicle move SFX (`Itm_TankMove` & `Itm_KartMove` via `AudioManager.play_loop_sfx`/`stop_loop_sfx`), dismount SFX (`Obj_ItemShip01`), `RailCar` rail-tile `speed_alt=10` (`0x597EC6`), `Kart` fuel curve & boost `2×` (`0x5BC639`), and `Shark` variant `0/1/2` (`0x5BC7C9`).

## UNKNOWN
- Exact numeric `sound_id` table mapping for `Wave/Itm_TankMove` and `Wave/Itm_KartMove` (loaded from external sound table, not hardcoded string literals in `ca.exe.c`; playback ownership is confirmed in `CGOBomber` via `sub_6734D5` / `sub_67171F`, not `CGOShip`).
