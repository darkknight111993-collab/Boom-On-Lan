# Shop & Account Inventory System (`CShopStageNew`, `CShopItemMan`, `CUserInventoryMan`, `CGOShopBomber`)

> **Source of truth:** `AnalizeVNClient/ca_unpacked.exe.i64` (IDA Pro `idalib-mcp`, base `0x00400000`) + `Client/Assets/fx/Shop/` + `Client/data/item_attr.json` / `bomber_attr.json`.
> **Rule:** Shop catalog filtering/pricing (`CShopItemMan`) and owned account inventory/loadout (`CUserInventoryMan`) are pure headless-testable `RefCounted` classes. UI layout coordinates in `Client/data/screens/shop.json` are taken directly from `CShopStageNew` (`0x7F59A0`, `0x7FEC22`, `0x804C7E`, `0x806B85`).

## Behavior summary
1. **`CShopItemMan`** (`.?AVCShopItemMan@@` @ `0xe48660`, ctor `0x8B1D42`, dtor `0x8B2AD6`) loads the shop catalog (`Client/data/shop_catalog.json`), filters items by the 5 main tabs (`Special`, `Item`, `Set`, `Char`, `Slot`), sub-category, currency (`All`/`Cash`/`Lucci`), and search keyword, and paginates item cards.
2. **`CUserInventoryMan`** (`.?AVCUserInventoryMan@@` @ `0xe48740`, ctor `0x8BA9DF`) + **`CUserItemMan`** (`0xe487fc`, ctor `0x8C07AC`) manages the logged-in user's Lucci/Cash balances, owned item records, equipped cosmetics (`character`, `hat`, `cloth`, `face`, `id_deco`, `bomb_skin`, `mount`), and 6 personal match slots (`CÁ NHÂN` `1..6`) that populate `CGOBomber.item_box` at match start.
3. **`CShopStageNew`** (`.?AVCShopStageNew@@` @ `0xe44fb0`, ctor `0x807303`, `OnEnter` `0x806B85`, `InitTabs` `0x7F59A0`, `InitButtons` `0x804C7E`, `InitItemGrid` `0x7FEC22`) renders the `800×600` Shop stage, live preview (`CGOShopBomber` @ `0xe448e4`), buy confirmation (`CShopBuyDlg` @ `0xe33b4c`), and search.

## Exact `CShopStageNew` UI Coordinates (Extracted from IDA)
- **Top marquee / notice bar (`0x806B85` @ `0x806bdb`):** rect `(30, 10, 452, 12)`
- **Main 5-Tab Bar (`0x7F59A0` @ `0x7f5a7f..0x7f5ae0`, `0xC02311`, `0xE44C50..0xE44C60`):**
  - Container rect: `x=2, y=36, w=446, h=40` (`id=4004`)
  - Active tab size: `82×36` (`sub_A84E05`); inactive tab width `34`, Y offset `+6` (`sub_A84E26`)
  - Exact tab order (`5000..5004`):
    1. `5000`: `Shop/S_TabSpecial` (Đặc biệt / Nổi bật)
    2. `5001`: `Shop/S_TabItem` (Vật phẩm / Trang bị)
    3. `5002`: `Shop/S_TabSet` (Bộ đồ)
    4. `5003`: `Shop/S_TabChar` (Nhân vật)
    5. `5004`: `Shop/S_TabSlot` (Túi đồ / Kho cá nhân)
- **Sub-tab bar (`0x7F59A0` + `0xE44C64..0xE44C68`):**
  - Origin: `(18, 83)`, button height `18`, normal text color `RGB(0, 100, 157)` (`0x7f5ce0`)
- **Currency filter buttons (`0x7F59A0` + `0xE44C6C..0xE44C78`):**
  - `Shop/S_BtCash` (`4900`): **`(408, 82)`**
  - `Shop/S_BtLucci` (`4901`): **`(449, 82)`**
- **Item grid (`0x7FEC22` @ `0x7ff36c..0x7ff3a9`):**
  - Bounding rect: `x=31..450, y=128..396` (or `Shop/S_Main` on Special/Home tab)
  - Per-card action buttons (`0x7FEC22` @ `0x7fefd1..0x7ff088`): `Shop/S_BtBuy` at local `(+172, +52)`, `Shop/S_BtRent` at local `(+82, +52)` (or `Shop/S_BtGet` for free/event items @ `0x7f916e`)
  - Per-card badges (`0x7FEC22` @ `0x7ff178..0x7ff2bc`): `Shop/NewGlyph`, `Shop/HotGlyph`, `Shop/IcoFree`, `Shop/IcoEvent`, `Shop/RentBorder`
- **Stage action buttons (`0x804C7E`):**
  - `Shop/S_BtSearch` (`6103`): **`(470, 46)`**
  - `Shop/S_BtSelecCharDown` (`6100`): **`(557, 5)`**
  - `Shop/S_BtUndo` (`6102`, reset try-on preview): **`(528, 287)`**
  - `Shop/S_BtHide` (`6101`, clear try-on preview): **`(528, 311)`**
  - `Shop/S_BtRechaCash` (`6104`): **`(621, 431)`**
  - `Shop/S_BtLucky` / `Shop/S_BtLuckyBasket` (`6107`/`6108`): **`(558, 526)`**
- **Live preview character (`0x806B85` @ `0x806c6a`, `0x806c9b`, `0x806ea1`):**
  - Bomber preview anchor: **`(546, 186)`** (classic `(529, 186)`), preview assist **`(643, 199)`**

## Class / state (original class -> Godot class)

### 1. `CShopItemMan` (`0xe48660`) -> `Client/scripts/modes/c_shop_item_man.gd` (`extends RefCounted`)
- Fields:
  - `var catalog: Array[Dictionary] = []` (loaded from `res://data/shop_catalog.json`)
  - Each entry: `{"id": String, "name_vn": String, "tab": String, "sub_tab": String, "slot_type": String, "sprite": String, "item_code": String, "currency": String, "price": int, "charges": int, "badge": String}`
- Methods:
  - `load_catalog(path: String = "res://data/shop_catalog.json") -> void`
  - `get_items(tab: String, sub_tab: String = "all", currency_filter: String = "all", keyword: String = "") -> Array[Dictionary]`
  - `get_page(items: Array[Dictionary], page: int, page_size: int = 8) -> Dictionary` (`{"items", "page", "total_pages"}`)
  - `get_item_by_id(item_id: String) -> Dictionary`

### 2. `CUserInventoryMan` (`0xe48740`) + `CUserItemMan` (`0xe487fc`) -> `Client/scripts/modes/c_user_inventory_man.gd` (`extends RefCounted`)
- Fields:
  - `var lucci: int = 10000`
  - `var cash: int = 1000`
  - `var owned_items: Dictionary = {}` (`item_id -> {"count": int, "equipped": bool}`)
  - `var equipped_cosmetics: Dictionary = {"hat": "", "cloth": "", "face": "", "id_deco": "", "bomb_skin": "Bomb/Bomb00", "mount": "", "character": "Character/C00"}`
  - `var personal_loadout: Array[String] = ["Item/ItemNiddle", "Item/ItemOxygen", "Item/ItemDart", "Banana3", "Item/ItemBond", "Item/ItemTrap"]` (6 slots `1..6`)
- Methods:
  - `can_afford(entry: Dictionary) -> bool`
  - `purchase_item(entry: Dictionary) -> Dictionary` (`{"ok": bool, "reason": String, "lucci": int, "cash": int}` — deducts currency, adds charges/ownership)
  - `equip_item(entry: Dictionary) -> bool` (equips cosmetic slot or assigns to personal loadout)
  - `unequip_slot(slot_type: String) -> void`
  - `apply_to_bomber_item_box(item_box: CGOItemBox) -> void` (loads owned match consumables into `CGOBomber.item_box` at match start)
  - `to_dict() -> Dictionary` / `from_dict(d: Dictionary) -> void` (persistence for `AuthService` / `Session`)

## Test vectors (code-evidence)
- **TV-S1 (`CShopItemMan` catalog load & 5-tab filter, `0x7F59A0`/`0xC02311`):** catalog loads items across `special`, `item`, `set`, `char`, `slot`; filtering by `tab="item"` returns only item entries.
- **TV-S2 (Currency & keyword search, `0x7F59A0` `4900`/`4901` & `0x804C7E` `6103`):** filtering `currency="lucci"` excludes `cash`-only items; Vietnamese/ASCII keyword search matches `name_vn` or `id`.
- **TV-S3 (Pagination):** `get_page(items, 0, 8)` returns at most 8 items and clamps out-of-range page indices cleanly.
- **TV-S4 (`CUserInventoryMan` purchase & insufficient funds):** buying a `500` Lucci item when `lucci=1000` succeeds (`lucci == 500`, `owned_items` count increases); buying a `2000` Lucci item fails with `ok=false, reason="insufficient_funds"` and leaves balance unchanged.
- **TV-S5 (Equip / Unequip cosmetics):** equipping a bomb skin updates `equipped_cosmetics["bomb_skin"]`; `unequip_slot("bomb_skin")` restores default `"Bomb/Bomb00"`.
- **TV-S6 (Match loadout -> `CGOItemBox`):** owned Needle/Dart/Banana items in `CUserInventoryMan` load cleanly into `CGOItemBox` via `apply_to_bomber_item_box()`, populating `get_personal_bar_slots()`.
- **TV-S7 (Serialization round-trip):** `to_dict()` -> `from_dict()` preserves `lucci`, `cash`, `owned_items`, and `equipped_cosmetics`.

## Functions covered (address list)
- `0x7F59A0`, `0x7F8FA5`, `0x7FEC22`, `0x802640`, `0x804C7E`, `0x806B85`, `0x807149`, `0x807303`, `0xC02311`
- `0x8B1D42`, `0x8B2AD6`, `0x8BA9DF`, `0x8BABC9`, `0x8C0623`, `0x8C07AC`, `0x7EECF2`, `0x7EEA58`

## UNKNOWN (Deferred to LAN / Full Shop Polish)
- Binary `.ssd` / server-pushed Shop catalog table format (`dword_E6081C` `CShopItemMan` server payload): offline Godot uses `Client/data/shop_catalog.json` seeded from `Client/Assets/fx/` & `item_attr.json` (`UNKNOWN`).
- Exact `S_MoneyCount` / `S_CouponBack` (`0x806d01`, `0x806d41`) sub-widget coordinates read from layout index `14/16/17/18` (`0x806f85..0x80708a`): positioned in `shop.json` directly from the Shop background frame (`UNKNOWN`).
- `CShopAction*` scripted demo timelines (`0x7F1EEF..0x7F2830`): deferred to Phase 10C (`UNKNOWN`).
