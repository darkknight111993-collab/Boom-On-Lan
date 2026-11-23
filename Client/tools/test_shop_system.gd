extends SceneTree

const CShopItemManClass = preload("res://scripts/modes/c_shop_item_man.gd")
const CUserInventoryManClass = preload("res://scripts/modes/c_user_inventory_man.gd")
const CGOItemBoxClass = preload("res://scripts/objects/cgo_item_box.gd")
const CGOShopBomberClass = preload("res://scripts/objects/cgo_shop_bomber.gd")
const SpriteDBScript = preload("res://scripts/sprite_db.gd")

var _fails: int = 0

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("[FAIL] " + msg)
	else:
		print("[PASS] " + msg)

func _init() -> void:
	var shop := CShopItemManClass.new()
	_test_tv_s1_catalog_and_tabs(shop)
	_test_tv_s2_currency_and_search(shop)
	_test_tv_s3_pagination(shop)
	_test_tv_s4_purchase_and_funds(shop)
	_test_tv_s5_equip_and_unequip(shop)
	_test_tv_s6_loadout_to_item_box(shop)
	_test_tv_s7_serialization(shop)
	_test_tv_s8_shop_bomber_preview(shop)

	if _fails > 0:
		printerr("Shop system tests FAILED: %d" % _fails)
		quit(1)
	else:
		print("ALL SHOP SYSTEM TESTS PASSED")
		quit(0)

func _test_tv_s1_catalog_and_tabs(shop: CShopItemManClass) -> void:
	_assert(shop.catalog.size() >= 15, "TV-S1: shop_catalog.json loaded (%d items)" % shop.catalog.size())
	for tab in CShopItemManClass.VALID_TABS:
		var list: Array[Dictionary] = shop.get_items(tab)
		_assert(not list.is_empty(), "TV-S1: tab '%s' has items (%d)" % [tab, list.size()])
		for e: Dictionary in list:
			_assert(str(e.get("tab", "")) == tab, "TV-S1: item '%s' matches tab '%s'" % [str(e.get("id", "")), tab])

func _test_tv_s2_currency_and_search(shop: CShopItemManClass) -> void:
	var lucci_items: Array[Dictionary] = shop.get_items("all", "all", "lucci")
	_assert(not lucci_items.is_empty(), "TV-S2: lucci filter returns items")
	for e: Dictionary in lucci_items:
		_assert(str(e.get("currency", "")) == "lucci", "TV-S2: lucci filter excludes cash item '%s'" % str(e.get("id", "")))

	var kw_vn: Array[Dictionary] = shop.get_items("all", "all", "all", "Kim Tự Cứu")
	_assert(kw_vn.size() == 1 and str(kw_vn[0].get("id", "")) == "item_needle_10", "TV-S2: Vietnamese keyword matches Kim Tự Cứu")

	var kw_id: Array[Dictionary] = shop.get_items("all", "all", "all", "bomb_001")
	_assert(kw_id.size() == 1, "TV-S2: ASCII ID keyword matches bomb_001")

func _test_tv_s3_pagination(shop: CShopItemManClass) -> void:
	var all_items: Array[Dictionary] = shop.get_items("all")
	var p0: Dictionary = shop.get_page(all_items, 0, 8)
	_assert((p0["items"] as Array).size() == 8 and int(p0["page"]) == 0, "TV-S3: page 0 returns 8 items")
	var p_oob: Dictionary = shop.get_page(all_items, 999, 8)
	_assert(int(p_oob["page"]) == int(p_oob["total_pages"]) - 1, "TV-S3: out-of-range page clamps cleanly")
	var p_neg: Dictionary = shop.get_page(all_items, -5, 8)
	_assert(int(p_neg["page"]) == 0, "TV-S3: negative page clamps to 0")

func _test_tv_s4_purchase_and_funds(shop: CShopItemManClass) -> void:
	var inv := CUserInventoryManClass.new()
	inv.lucci = 1000
	var needle: Dictionary = shop.get_item_by_id("item_needle_10") # 500 Lucci, 10 charges
	var res1: Dictionary = inv.purchase_item(needle)
	_assert(bool(res1["ok"]) and inv.lucci == 500 and inv.get_owned_consumable_count("Item/ItemNiddle") == 10, "TV-S4: buy 500 Lucci item succeeds (lucci=500, count=10)")

	var hat: Dictionary = shop.get_item_by_id("hat_cat_01") # 2000 Lucci
	var res2: Dictionary = inv.purchase_item(hat)
	_assert(not bool(res2["ok"]) and str(res2["reason"]) == "insufficient_funds" and inv.lucci == 500, "TV-S4: insufficient funds rejected without changing balance")

func _test_tv_s5_equip_and_unequip(shop: CShopItemManClass) -> void:
	var inv := CUserInventoryManClass.new()
	var bomb1: Dictionary = shop.get_item_by_id("bomb_001")
	inv.purchase_item(bomb1)
	_assert(inv.equip_item(bomb1) and str(inv.equipped_cosmetics["bomb_skin"]) == "BombDeco/Bomb001", "TV-S5: equip bomb_skin updates equipped_cosmetics")
	inv.unequip_slot("bomb_skin")
	_assert(str(inv.equipped_cosmetics["bomb_skin"]) == "Bomb/Bomb00", "TV-S5: unequip bomb_skin restores default Bomb/Bomb00")

func _test_tv_s6_loadout_to_item_box(shop: CShopItemManClass) -> void:
	var inv := CUserInventoryManClass.new()
	inv.purchase_item(shop.get_item_by_id("item_needle_10"))
	inv.purchase_item(shop.get_item_by_id("item_dart_10"))
	inv.purchase_item(shop.get_item_by_id("item_banana_10"))
	var box := CGOItemBoxClass.new()
	inv.apply_to_bomber_item_box(box)
	_assert(box.get_needle_total_count() == 10, "TV-S6: Needle loaded into CGOItemBox (10)")
	_assert(box.get_count_by_type(21) == 10, "TV-S6: Dart loaded into CGOItemBox (10)")
	_assert(box.get_count_by_type(11, 3) == 10, "TV-S6: Banana loaded into CGOItemBox (10)")
	var bar: Array[Dictionary] = box.get_personal_bar_slots()
	_assert(bar.size() == 6 and int(bar[0]["count"]) == 10, "TV-S6: get_personal_bar_slots populated")

func _test_tv_s7_serialization(shop: CShopItemManClass) -> void:
	var inv := CUserInventoryManClass.new()
	inv.lucci = 7777
	inv.cash = 333
	var hat: Dictionary = shop.get_item_by_id("hat_cat_01")
	inv.purchase_item(hat)
	inv.equip_item(hat)
	var saved: Dictionary = inv.to_dict()

	var inv2 := CUserInventoryManClass.new()
	inv2.from_dict(saved)
	_assert(inv2.lucci == 5777 and inv2.cash == 333, "TV-S7: serialization preserves lucci/cash")
	_assert(inv2.is_owned("hat_cat_01") and str(inv2.equipped_cosmetics["hat"]) == "AvatarDeco/A02_10_0001", "TV-S7: serialization preserves owned_items & equipped_cosmetics")

func _test_tv_s8_shop_bomber_preview(shop: CShopItemManClass) -> void:
	var sdb := SpriteDBScript.new()
	sdb.name = "SpriteDB"
	root.add_child(sdb)
	var sb := CGOShopBomberClass.new()
	root.add_child(sb)
	sb.setup_preview("Character/C02", Color(1.0, 0.2, 0.2), {"hat": "", "bomb_skin": "Bomb/Bomb00"})
	sb.try_on(shop.get_item_by_id("hat_cat_01"))
	_assert(sb.cosmetics.slots[1] == "AvatarDeco/A02_10_0001" and sb.demo_action == CGOShopBomberClass.ACTION_USE_SPECIAL_ITEM, "TV-S8: try_on hat triggers UseSpecialItem")

	# Verify SetBomb, UseShield, UseSpring, UseNormalItem demo transitions & return to Wait
	sb.try_on(shop.get_item_by_id("bomb_001"))
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_SET_BOMB, "TV-S9: try_on bomb triggers SetBomb")
	for _i in range(50):
		sb.tick_demo()
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_WAIT, "TV-S9: SetBomb completes back to Wait")

	sb.try_on(shop.get_item_by_id("item_shield_10"))
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_USE_SHIELD, "TV-S9: try_on shield triggers UseShield")
	for _i in range(52):
		sb.tick_demo()
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_WAIT, "TV-S9: UseShield completes back to Wait")

	sb.try_on(shop.get_item_by_id("item_spring_10"))
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_USE_SPRING, "TV-S9: try_on spring triggers UseSpring")
	for _i in range(12):
		sb.tick_demo()
	_assert(sb.position.y < 262.0, "TV-S9: UseSpring animates upward jump arc")
	for _i in range(15):
		sb.tick_demo()
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_WAIT and is_equal_approx(sb.position.y, 262.0), "TV-S9: UseSpring lands back at anchor")

	sb.try_on(shop.get_item_by_id("item_dart_10"))
	_assert(sb.demo_action == CGOShopBomberClass.ACTION_USE_NORMAL_ITEM, "TV-S9: try_on dart triggers UseNormalItem")

	_assert(shop.catalog.size() >= 1500, "TV-S9: full catalog loaded with all 845 IDDecos (%d >= 1500 items)" % shop.catalog.size())

	sb.hide_preview_cosmetics()
	_assert(not sb.cosmetics.has_any_avatar_deco(), "TV-S8: CGOShopBomber hide_preview_cosmetics strips cosmetics")
	sb.try_on(shop.get_item_by_id("hat_cat_01"))
	sb.undo_preview()
	_assert(not sb.cosmetics.has_any_avatar_deco(), "TV-S8: CGOShopBomber undo_preview restores saved state")
	sb.queue_free()
	sdb.queue_free()
