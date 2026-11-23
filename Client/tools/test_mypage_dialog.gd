extends SceneTree

const CMyPageDlgClass = preload("res://scripts/mypage_dialog.gd")
const CShopItemManClass = preload("res://scripts/modes/c_shop_item_man.gd")
const CUserInventoryManClass = preload("res://scripts/modes/c_user_inventory_man.gd")
const CGOItemBoxClass = preload("res://scripts/objects/cgo_item_box.gd")
const SpriteDBScript = preload("res://scripts/sprite_db.gd")

var _fails: int = 0

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("[FAIL] " + msg)
	else:
		print("[PASS] " + msg)

func _init() -> void:
	var sdb := SpriteDBScript.new()
	sdb.name = "SpriteDB"
	root.add_child(sdb)

	var shop := CShopItemManClass.new()
	var inv := CUserInventoryManClass.new()
	inv.lucci = 50000
	inv.cash = 10000
	inv.purchase_item(shop.get_item_by_id("hat_cat_01"))
	inv.purchase_item(shop.get_item_by_id("bomb_001"))
	inv.purchase_item(shop.get_item_by_id("item_needle_10"))

	var dlg := CMyPageDlgClass.new()
	dlg.setup_dialog(inv, shop)
	root.add_child(dlg)

	# 1. All 3 owned items appear in filtered list
	var all_owned: Array[Dictionary] = dlg.get_filtered_owned_entries()
	_assert(all_owned.size() == 3, "MyPage: 3 owned items listed (got %d)" % all_owned.size())

	# 2. Category filter works
	dlg.set_category("bomb_skin")
	_assert(dlg.get_filtered_owned_entries().size() == 1, "MyPage: bomb_skin filter returns 1 item")
	dlg.set_category("all")

	# 3. Toggle equip cosmetic (hat) & unequip
	var hat_entry: Dictionary = shop.get_item_by_id("hat_cat_01")
	dlg.toggle_equip_entry(hat_entry)
	_assert(str(inv.equipped_cosmetics["hat"]) == "AvatarDeco/A02_10_0001", "MyPage: toggle_equip equips hat")
	dlg.toggle_equip_entry(hat_entry)
	_assert(str(inv.equipped_cosmetics["hat"]) == "", "MyPage: second toggle_equip unequips hat")

	# 4. Equip bomb_skin + unequip_cosmetic_slot restores default
	dlg.toggle_equip_entry(shop.get_item_by_id("bomb_001"))
	_assert(str(inv.equipped_cosmetics["bomb_skin"]) == "BombDeco/Bomb001", "MyPage: equips bomb_skin")
	dlg.unequip_cosmetic_slot("bomb_skin")
	_assert(str(inv.equipped_cosmetics["bomb_skin"]) == "Bomb/Bomb00", "MyPage: unequip_cosmetic_slot restores default")

	# 5. Toggle consumable in 6-slot personal loadout -> CGOItemBox
	var needle: Dictionary = shop.get_item_by_id("item_needle_10")
	_assert(inv.personal_loadout.has("Item/ItemNiddle"), "MyPage: Needle in default loadout")
	dlg.toggle_equip_entry(needle)
	_assert(not inv.personal_loadout.has("Item/ItemNiddle"), "MyPage: toggle removes Needle from loadout")
	dlg.toggle_equip_entry(needle)
	_assert(inv.personal_loadout.has("Item/ItemNiddle"), "MyPage: toggle re-adds Needle to loadout")
	var box := CGOItemBoxClass.new()
	inv.apply_to_bomber_item_box(box)
	_assert(box.get_needle_total_count() == 10, "MyPage: loadout populates CGOItemBox (10 needles)")

	# 6. Switch to MyInfo tab
	dlg.set_main_tab("myinfo")
	_assert(dlg._myinfo_root.visible and not dlg._myitem_root.visible, "MyPage: MyInfo tab switches visibility")

	dlg.close_dialog()
	sdb.queue_free()

	if _fails > 0:
		printerr("MyPage dialog tests FAILED: %d" % _fails)
		quit(1)
	else:
		print("ALL MYPAGE DIALOG TESTS PASSED")
		quit(0)
