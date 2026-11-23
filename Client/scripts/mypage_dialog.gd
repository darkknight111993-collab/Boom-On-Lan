class_name CMyPageDlg
extends Control

## Personal Inventory & MyInfo Dialog (CA.exe CMyPageDlg / "MyPage Dialog" @ 0x959D15, GlobalUI/BtMyItem @ 0x5E229A).
## Lets players view owned items from CUserInventoryMan, equip/unequip cosmetics with live CGOShopBomber preview,
## manage the 6 personal match slots (1..6), and view account profile stats without entering the Shop.

signal dialog_closed

const CGOShopBomberClass = preload("res://scripts/objects/cgo_shop_bomber.gd")
const CShopItemManClass = preload("res://scripts/modes/c_shop_item_man.gd")
const CUserInventoryManClass = preload("res://scripts/modes/c_user_inventory_man.gd")

const PAGE_SIZE: int = 6
const SLOT_LABELS := [
	["hat", "Mũ"],
	["cloth", "Áo/Bộ"],
	["face", "Mặt"],
	["char_deco", "Trang trí"],
	["id_deco", "Khung tên"],
	["bomb_skin", "Bóng nước"],
]

var _inv: CUserInventoryManClass = null
var _shop_man: CShopItemManClass = null
var _active_main_tab: String = "myitem" # "myitem" | "myinfo"
var _active_cat: String = "all" # "all" | "cosmetic" | "bomb_skin" | "id_deco" | "consumable"
var _keyword: String = ""
var _page: int = 0

var _panel: Panel = null
var _preview_bomber: CGOShopBomberClass = null
var _equipped_box: VBoxContainer = null
var _myitem_root: Control = null
var _myinfo_root: Control = null
var _grid_container: Control = null
var _loadout_bar: HBoxContainer = null
var _page_label: Label = null
var _status_label: Label = null
var _myinfo_label: Label = null
var _tab_myitem_btn: Button = null
var _tab_myinfo_btn: Button = null

func setup_dialog(inv: CUserInventoryManClass, shop_man: CShopItemManClass) -> void:
	_inv = inv
	_shop_man = shop_man
	_build_ui()
	_refresh_all()

func _ready() -> void:
	if _inv == null:
		var sess: Node = _get_autoload("Session")
		if sess != null:
			_inv = sess.call("get_inventory_man")
			_shop_man = sess.call("get_shop_man")
	if _panel == null:
		_build_ui()
		_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_dialog()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	size = Vector2(800, 600)
	z_index = 60

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.58)
	backdrop.size = Vector2(800, 600)
	add_child(backdrop)

	_panel = Panel.new()
	_panel.position = Vector2(56, 48)
	_panel.size = Vector2(688, 504)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.22, 0.45, 0.98)
	sb.border_color = Color(0.55, 0.85, 1.0, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# Header bar + 2 main tabs (Myinfo/MP_TabBarMyItem & MP_TabBarMyInfo)
	var title := Label.new()
	title.text = "CÁ NHÂN — KHO ĐỒ & TRANG BỊ"
	title.position = Vector2(16, 10)
	title.size = Vector2(300, 24)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	_panel.add_child(title)

	_tab_myitem_btn = Button.new()
	_tab_myitem_btn.text = "Kho Đồ (MyItem)"
	_tab_myitem_btn.position = Vector2(330, 8)
	_tab_myitem_btn.size = Vector2(130, 26)
	_tab_myitem_btn.pressed.connect(func() -> void: set_main_tab("myitem"))
	_panel.add_child(_tab_myitem_btn)

	_tab_myinfo_btn = Button.new()
	_tab_myinfo_btn.text = "Thông Tin (MyInfo)"
	_tab_myinfo_btn.position = Vector2(466, 8)
	_tab_myinfo_btn.size = Vector2(136, 26)
	_tab_myinfo_btn.pressed.connect(func() -> void: set_main_tab("myinfo"))
	_panel.add_child(_tab_myinfo_btn)

	var close_btn := Button.new()
	close_btn.text = "Đóng"
	close_btn.position = Vector2(612, 8)
	close_btn.size = Vector2(64, 26)
	close_btn.pressed.connect(close_dialog)
	_panel.add_child(close_btn)

	# Left column: Live character preview + currently equipped slots with Unequip buttons
	var preview_bg := Panel.new()
	preview_bg.position = Vector2(14, 44)
	preview_bg.size = Vector2(210, 178)
	preview_bg.clip_contents = true
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.14, 0.56, 0.88, 0.92)
	psb.border_color = Color(0.75, 0.93, 1.0, 1.0)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	preview_bg.add_theme_stylebox_override("panel", psb)
	_panel.add_child(preview_bg)

	_preview_bomber = CGOShopBomberClass.new()
	preview_bg.add_child(_preview_bomber)

	var eq_hdr := Label.new()
	eq_hdr.text = "ĐANG TRANG BỊ"
	eq_hdr.position = Vector2(16, 228)
	eq_hdr.size = Vector2(206, 18)
	eq_hdr.add_theme_font_size_override("font_size", 11)
	eq_hdr.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	_panel.add_child(eq_hdr)

	_equipped_box = VBoxContainer.new()
	_equipped_box.position = Vector2(14, 248)
	_equipped_box.size = Vector2(210, 214)
	_panel.add_child(_equipped_box)

	_status_label = Label.new()
	_status_label.position = Vector2(14, 472)
	_status_label.size = Vector2(660, 20)
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.72))
	_panel.add_child(_status_label)

	# Right column: MyItem tab
	_myitem_root = Control.new()
	_myitem_root.position = Vector2(236, 44)
	_myitem_root.size = Vector2(438, 424)
	_panel.add_child(_myitem_root)

	var cats := [
		["all", "Tất cả"],
		["cosmetic", "Trang phục"],
		["bomb_skin", "Bóng nước"],
		["id_deco", "Khung tên"],
		["consumable", "Vật phẩm"],
	]
	var cx: int = 0
	for pair in cats:
		var b := Button.new()
		b.text = str(pair[1])
		b.position = Vector2(cx, 0)
		b.size = Vector2(84, 24)
		b.add_theme_font_size_override("font_size", 10)
		var cat_id: String = str(pair[0])
		b.pressed.connect(func() -> void: set_category(cat_id))
		_myitem_root.add_child(b)
		cx += 88

	var search := LineEdit.new()
	search.position = Vector2(0, 30)
	search.size = Vector2(260, 24)
	search.placeholder_text = "Tìm trong kho đồ..."
	search.text_changed.connect(func(txt: String) -> void:
		_keyword = txt
		_page = 0
		_refresh_item_grid()
	)
	_myitem_root.add_child(search)

	_grid_container = Control.new()
	_grid_container.position = Vector2(0, 60)
	_grid_container.size = Vector2(438, 276)
	_myitem_root.add_child(_grid_container)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.position = Vector2(160, 340)
	prev_btn.size = Vector2(28, 22)
	prev_btn.pressed.connect(func() -> void:
		_page = maxi(0, _page - 1)
		_refresh_item_grid()
	)
	_myitem_root.add_child(prev_btn)

	_page_label = Label.new()
	_page_label.position = Vector2(194, 342)
	_page_label.size = Vector2(54, 20)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 11)
	_myitem_root.add_child(_page_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.position = Vector2(254, 340)
	next_btn.size = Vector2(28, 22)
	next_btn.pressed.connect(func() -> void:
		_page += 1
		_refresh_item_grid()
	)
	_myitem_root.add_child(next_btn)

	var lo_hdr := Label.new()
	lo_hdr.text = "6 Ô VẬT PHẨM CÁ NHÂN (PHÍM 1..6 TRONG TRẬN):"
	lo_hdr.position = Vector2(0, 368)
	lo_hdr.size = Vector2(438, 16)
	lo_hdr.add_theme_font_size_override("font_size", 10)
	lo_hdr.add_theme_color_override("font_color", Color(0.8, 0.94, 1.0))
	_myitem_root.add_child(lo_hdr)

	_loadout_bar = HBoxContainer.new()
	_loadout_bar.position = Vector2(0, 386)
	_loadout_bar.size = Vector2(438, 36)
	_myitem_root.add_child(_loadout_bar)

	# Right column: MyInfo tab
	_myinfo_root = Control.new()
	_myinfo_root.position = Vector2(236, 44)
	_myinfo_root.size = Vector2(438, 424)
	_myinfo_root.visible = false
	_panel.add_child(_myinfo_root)

	_myinfo_label = Label.new()
	_myinfo_label.position = Vector2(12, 12)
	_myinfo_label.size = Vector2(414, 380)
	_myinfo_label.add_theme_font_size_override("font_size", 13)
	_myinfo_label.add_theme_color_override("font_color", Color.WHITE)
	_myinfo_root.add_child(_myinfo_label)

func set_main_tab(tab_name: String) -> void:
	_active_main_tab = tab_name
	if _myitem_root:
		_myitem_root.visible = (tab_name == "myitem")
	if _myinfo_root:
		_myinfo_root.visible = (tab_name == "myinfo")
	_refresh_myinfo()

func set_category(cat_id: String) -> void:
	_active_cat = cat_id
	_page = 0
	_refresh_item_grid()

func get_filtered_owned_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _inv == null:
		return result
	var kw: String = _keyword.strip_edges().to_lower()
	for item_id: String in _inv.owned_items.keys():
		var rec: Dictionary = _inv.owned_items[item_id]
		if int(rec.get("count", 0)) <= 0:
			continue
		var entry: Dictionary = _shop_man.get_item_by_id(item_id) if _shop_man != null else {}
		if entry.is_empty():
			entry = {
				"id": item_id,
				"name_vn": item_id,
				"slot_type": str(rec.get("slot_type", "")),
				"item_code": str(rec.get("item_code", "")),
				"sprite": str(rec.get("sprite", "")),
				"icon": str(rec.get("sprite", "")),
			}
		var st: String = str(entry.get("slot_type", ""))
		if _active_cat == "cosmetic":
			if not (st in ["hat", "cloth", "face", "char_deco", "character"]):
				continue
		elif _active_cat != "all" and st != _active_cat:
			continue
		if kw != "":
			var nm: String = str(entry.get("name_vn", "")).to_lower()
			if not nm.contains(kw) and not item_id.to_lower().contains(kw):
				continue
		var merged: Dictionary = entry.duplicate(true)
		merged["owned_count"] = int(rec.get("count", 0))
		result.append(merged)
	return result

func toggle_equip_entry(entry: Dictionary) -> bool:
	if _inv == null:
		return false
	var st: String = str(entry.get("slot_type", ""))
	var code: String = str(entry.get("item_code", ""))
	if st == "consumable":
		if _inv.personal_loadout.has(code):
			_inv.personal_loadout.erase(code)
			_set_status("Đã gỡ khỏi ô cá nhân: %s" % str(entry.get("name_vn", code)))
		else:
			_inv.equip_item(entry)
			_set_status("Đã gắn vào ô cá nhân: %s" % str(entry.get("name_vn", code)))
	else:
		if str(_inv.equipped_cosmetics.get(st, "")) == code:
			_inv.unequip_slot(st)
			_set_status("Đã gỡ: %s" % str(entry.get("name_vn", code)))
		else:
			_inv.equip_item(entry)
			_set_status("Đã đeo: %s" % str(entry.get("name_vn", code)))
	_sync_and_save()
	_refresh_all()
	return true

func unequip_cosmetic_slot(slot_type: String) -> void:
	if _inv == null:
		return
	_inv.unequip_slot(slot_type)
	_set_status("Đã gỡ trang bị ô %s." % slot_type)
	_sync_and_save()
	_refresh_all()

func _get_autoload(node_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + node_name)
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(node_name)
	return null

func _sync_and_save() -> void:
	var sess: Node = _get_autoload("Session")
	if sess != null:
		sess.call("sync_from_inventory")
	var auth: Node = _get_autoload("AuthService")
	if auth != null:
		auth.call("save_active_inventory")

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg

func _refresh_all() -> void:
	_refresh_preview()
	_refresh_equipped_list()
	_refresh_item_grid()
	_refresh_loadout_bar()
	_refresh_myinfo()

func _refresh_preview() -> void:
	if _inv == null or _preview_bomber == null:
		return
	var char_code: String = str(_inv.equipped_cosmetics.get("character", "Character/C00"))
	var team_col: Color = Color(0.92, 0.0, 0.0)
	var sess: Node = _get_autoload("Session")
	if sess != null:
		team_col = sess.call("get_team_color", int(sess.get("team_color_idx")))
	_preview_bomber.setup_preview(char_code, team_col, _inv.equipped_cosmetics, Vector2(56.0, 132.0))
	if is_instance_valid(_preview_bomber._preview_bomb_sprite) and _preview_bomber._preview_bomb_sprite.visible:
		_preview_bomber._preview_bomb_sprite.position.x = 68.0

func _refresh_equipped_list() -> void:
	if _equipped_box == null or _inv == null:
		return
	for ch in _equipped_box.get_children():
		ch.queue_free()
	for pair in SLOT_LABELS:
		var slot_key: String = str(pair[0])
		var slot_vn: String = str(pair[1])
		var val: String = str(_inv.equipped_cosmetics.get(slot_key, ""))
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var short_val: String = val.get_file() if val != "" else "(Trống)"
		lbl.text = "%s: %s" % [slot_vn, short_val]
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var is_default: bool = (val == "" or (slot_key == "bomb_skin" and val == CUserInventoryManClass.DEFAULT_BOMB_SKIN))
		if not is_default:
			var btn := Button.new()
			btn.text = "Gỡ"
			btn.custom_minimum_size = Vector2(36, 20)
			btn.add_theme_font_size_override("font_size", 9)
			btn.pressed.connect(func() -> void: unequip_cosmetic_slot(slot_key))
			row.add_child(btn)
		_equipped_box.add_child(row)

func _refresh_item_grid() -> void:
	if _grid_container == null or _inv == null:
		return
	for ch in _grid_container.get_children():
		ch.queue_free()
	var items: Array[Dictionary] = get_filtered_owned_entries()
	var total_pages: int = maxi(1, int(ceili(float(items.size()) / float(PAGE_SIZE))))
	_page = clampi(_page, 0, total_pages - 1)
	if _page_label:
		_page_label.text = "%d / %d" % [_page + 1, total_pages]

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Kho đồ trống. Hãy vào Cửa Hàng để mua trang phục hoặc vật phẩm!"
		empty_lbl.position = Vector2(12, 90)
		empty_lbl.size = Vector2(414, 48)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		_grid_container.add_child(empty_lbl)
		return

	var start_idx: int = _page * PAGE_SIZE
	var end_idx: int = mini(start_idx + PAGE_SIZE, items.size())
	var sdb: Node = _get_autoload("SpriteDB")
	for idx in range(start_idx, end_idx):
		var local_i: int = idx - start_idx
		var entry: Dictionary = items[idx]
		var col: int = local_i % 2
		var row: int = local_i / 2
		var card := Panel.new()
		card.position = Vector2(col * 220, row * 90)
		card.size = Vector2(214, 84)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.96, 1.0, 0.94)
		sb.border_color = Color(0.22, 0.52, 0.82, 1.0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", sb)
		_grid_container.add_child(card)

		var icon_tr := TextureRect.new()
		icon_tr.position = Vector2(6, 18)
		icon_tr.size = Vector2(46, 46)
		icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if sdb != null:
			var f: Dictionary = sdb.call("get_frame", str(entry.get("icon", entry.get("sprite", ""))), 0)
			if not f.is_empty():
				icon_tr.texture = f.texture
		card.add_child(icon_tr)

		var nm := Label.new()
		nm.position = Vector2(56, 6)
		nm.size = Vector2(152, 30)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.text = str(entry.get("name_vn", entry.get("id", "")))
		nm.add_theme_font_size_override("font_size", 10)
		nm.add_theme_color_override("font_color", Color(0.05, 0.2, 0.45))
		card.add_child(nm)

		var st: String = str(entry.get("slot_type", ""))
		var code: String = str(entry.get("item_code", ""))
		var is_eq: bool = (_inv.personal_loadout.has(code) if st == "consumable" else str(_inv.equipped_cosmetics.get(st, "")) == code)
		var cnt: int = int(entry.get("owned_count", 1))
		var info := Label.new()
		info.position = Vector2(56, 36)
		info.size = Vector2(82, 18)
		info.text = ("SL: %d" % cnt) if st == "consumable" else ("Đang đeo" if is_eq else "Sở hữu")
		info.add_theme_font_size_override("font_size", 10)
		info.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2) if is_eq else Color(0.35, 0.35, 0.45))
		card.add_child(info)

		var eq_btn := Button.new()
		eq_btn.text = "Gỡ" if is_eq else "Đeo"
		eq_btn.position = Vector2(138, 52)
		eq_btn.size = Vector2(68, 24)
		eq_btn.add_theme_font_size_override("font_size", 10)
		eq_btn.pressed.connect(func() -> void: toggle_equip_entry(entry))
		card.add_child(eq_btn)

func _refresh_loadout_bar() -> void:
	if _loadout_bar == null or _inv == null:
		return
	for ch in _loadout_bar.get_children():
		ch.queue_free()
	for i in range(CUserInventoryManClass.PERSONAL_SLOT_COUNT):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(68, 32)
		slot_btn.add_theme_font_size_override("font_size", 9)
		if i < _inv.personal_loadout.size():
			var code: String = _inv.personal_loadout[i]
			var cnt: int = _inv.get_owned_consumable_count(code)
			slot_btn.text = "%d: %s(%d)" % [i + 1, code.get_file().left(6), cnt]
		else:
			slot_btn.text = "%d: (Trống)" % (i + 1)
		_loadout_bar.add_child(slot_btn)

func _refresh_myinfo() -> void:
	if _myinfo_label == null or _inv == null:
		return
	var sess: Node = _get_autoload("Session")
	var nick: String = str(sess.get("nickname")) if sess != null else "Player"
	var lvl: int = int(sess.get("level")) if sess != null else 1
	var wins: int = int(sess.get("wins")) if sess != null else 0
	var losses: int = int(sess.get("losses")) if sess != null else 0
	var draws: int = int(sess.get("draws")) if sess != null else 0
	var wr: float = float(sess.call("get_winrate")) if sess != null else 0.0
	_myinfo_label.text = (
		"Nhân vật: %s\n" % nick
		+ "Cấp độ: %d   |   Tỉ lệ thắng: %.1f%%\n" % [lvl, wr]
		+ "Thành tích: %d Thắng / %d Thua / %d Hòa\n\n" % [wins, losses, draws]
		+ "Vàng (Lucci): %d\n" % _inv.lucci
		+ "Xu (Cash): %d\n" % _inv.cash
		+ "Tổng vật phẩm sở hữu: %d" % _inv.owned_items.size()
	)

func close_dialog() -> void:
	_sync_and_save()
	dialog_closed.emit()
	queue_free()
