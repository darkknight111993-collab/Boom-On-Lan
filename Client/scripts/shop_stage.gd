extends Control

## CShopStageNew controller (CA.exe .?AVCShopStageNew@@ @ 0xe44fb0, 0x807303 / 0x7F59A0 / 0x7FEC22 / 0x804C7E / 0x806B85).

const ScreenBuilder = preload("res://scripts/screen_builder.gd")
const DialogManagerScript = preload("res://scripts/dialog_manager.gd")
const CGOShopBomberClass = preload("res://scripts/objects/cgo_shop_bomber.gd")

var dialogs: DialogManagerScript
var _active_tab: String = "special"
var _currency_filter: String = "all"
var _keyword: String = ""
var _page: int = 0
var _grid_container: Control = null
var _search_input: LineEdit = null
var _page_label: Label = null
var _preview_bomber: CGOShopBomberClass = null

# CShopBuyDlg (0xe33b4c) confirmation modal state
var _buy_dlg_overlay: ColorRect = null
var _buy_dlg_icon: TextureRect = null
var _buy_dlg_title: Label = null
var _buy_dlg_detail: Label = null
var _buy_dlg_confirm_btn: Button = null
var _pending_buy_entry: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/screens/shop.json"))
	ScreenBuilder.build(self, data)
	dialogs = DialogManagerScript.new(self)
	add_child(dialogs)
	if data.has("bgm"):
		AudioManager.play_bgm(data.bgm)

	# Item grid container inside IDA bounding rect (31, 128) -> (450, 512)
	_grid_container = Control.new()
	_grid_container.position = Vector2(31, 128)
	_grid_container.size = Vector2(420, 384)
	add_child(_grid_container)

	# Search bar next to S_BtSearch (470, 46)
	_search_input = LineEdit.new()
	_search_input.position = Vector2(18, 82)
	_search_input.size = Vector2(210, 22)
	_search_input.placeholder_text = "Tìm vật phẩm..."
	_search_input.text_changed.connect(func(txt: String) -> void:
		_keyword = txt
		_page = 0
		_refresh_grid()
	)
	add_child(_search_input)

	# Pagination controls at bottom of grid
	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.position = Vector2(180, 506)
	prev_btn.size = Vector2(28, 22)
	prev_btn.pressed.connect(func() -> void:
		_page = maxi(0, _page - 1)
		_refresh_grid()
	)
	add_child(prev_btn)

	_page_label = Label.new()
	_page_label.position = Vector2(214, 508)
	_page_label.size = Vector2(56, 20)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 11)
	add_child(_page_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.position = Vector2(276, 506)
	next_btn.size = Vector2(28, 22)
	next_btn.pressed.connect(func() -> void:
		_page += 1
		_refresh_grid()
	)
	add_child(next_btn)

	# Live preview character at exact IDA anchor (546, 186) (0x806B85 @ 0x806c6a)
	_preview_bomber = CGOShopBomberClass.new()
	add_child(_preview_bomber)
	var inv := Session.get_inventory_man()
	_preview_bomber.setup_preview(Session.selected_char, Session.get_team_color(Session.team_color_idx), inv.equipped_cosmetics, Vector2(556.0, 262.0))

	_refresh_balances()
	_refresh_grid()
	_build_buy_dialog()

func on_action(action: String) -> void:
	if action.begins_with("shop:tab:"):
		_active_tab = action.substr(9)
		_page = 0
		_refresh_grid()
	elif action.begins_with("shop:currency:"):
		var cur := action.substr(14)
		_currency_filter = "all" if _currency_filter == cur else cur
		_page = 0
		_refresh_grid()
	elif action == "shop:search":
		if _search_input:
			_search_input.grab_focus()
	elif action == "shop:undo":
		if _preview_bomber:
			_preview_bomber.undo_preview()
		_set_status("Đã khôi phục trang phục đang mặc.")
	elif action == "shop:hide":
		if _preview_bomber:
			_preview_bomber.hide_preview_cosmetics()
		_set_status("Đã ẩn trang phục mặc thử.")
	elif action == "shop:cycle_char":
		var chars := ["Character/C00", "Character/C02", "Character/C06", "Character/C14", "Character/C15"]
		var idx := chars.find(Session.selected_char)
		Session.selected_char = chars[(idx + 1) % chars.size()]
		var inv := Session.get_inventory_man()
		inv.equipped_cosmetics["character"] = Session.selected_char
		_preview_bomber.setup_preview(Session.selected_char, Session.get_team_color(Session.team_color_idx), inv.equipped_cosmetics, Vector2(556.0, 262.0))
	elif action == "shop:recharge" or action == "shop:lucky":
		dialogs.show_notice("Chức năng nạp Xu / Vòng quay chỉ khả dụng ở bản online.")
	elif action == "shop:back":
		Session.sync_from_inventory()
		AuthService.save_active_inventory()
		Session.goto(Session.shop_return_scene if Session.shop_return_scene != "" else "lobby")

func _refresh_balances() -> void:
	var inv := Session.get_inventory_man()
	var ll := get_node_or_null("LucciLabel") as Label
	if ll:
		ll.text = "%d" % inv.lucci
	var cl := get_node_or_null("CashLabel") as Label
	if cl:
		cl.text = "%d" % inv.cash

func _set_status(msg: String) -> void:
	var sl := get_node_or_null("StatusLabel") as Label
	if sl:
		sl.text = msg

func _refresh_grid() -> void:
	for ch in _grid_container.get_children():
		ch.queue_free()
	var shop_man := Session.get_shop_man()
	var inv := Session.get_inventory_man()
	var items: Array[Dictionary] = shop_man.get_items(_active_tab, "all", _currency_filter, _keyword)
	var pg: Dictionary = shop_man.get_page(items, _page, 6)
	_page = int(pg["page"])
	if _page_label:
		_page_label.text = "%d / %d" % [_page + 1, int(pg["total_pages"])]

	var page_items: Array = pg["items"]
	for i in range(page_items.size()):
		var entry: Dictionary = page_items[i]
		var col: int = i % 2
		var row: int = i / 2
		var card := Panel.new()
		card.position = Vector2(col * 208, row * 122)
		card.size = Vector2(202, 114)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.96, 1.0, 0.92)
		sb.border_color = Color(0.22, 0.52, 0.82, 1.0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		card.add_theme_stylebox_override("panel", sb)
		_grid_container.add_child(card)

		# Item icon
		var icon_tr := TextureRect.new()
		icon_tr.position = Vector2(8, 22)
		icon_tr.size = Vector2(48, 48)
		icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_f: Dictionary = SpriteDB.get_frame(str(entry.get("icon", entry.get("sprite", ""))), 0)
		if not icon_f.is_empty():
			icon_tr.texture = icon_f.texture
		card.add_child(icon_tr)

		# Item name & price
		var name_lbl := Label.new()
		name_lbl.position = Vector2(60, 8)
		name_lbl.size = Vector2(136, 32)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.text = str(entry.get("name_vn", entry.get("id", "")))
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.05, 0.2, 0.45))
		card.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.position = Vector2(60, 44)
		price_lbl.size = Vector2(136, 18)
		var cur_txt := "Xu" if str(entry.get("currency", "lucci")) == "cash" else "Lucci"
		price_lbl.text = "%d %s" % [int(entry.get("price", 0)), cur_txt]
		price_lbl.add_theme_font_size_override("font_size", 10)
		price_lbl.add_theme_color_override("font_color", Color(0.75, 0.35, 0.0))
		card.add_child(price_lbl)

		# Try-on button
		var try_btn := Button.new()
		try_btn.text = "Mặc thử"
		try_btn.position = Vector2(60, 80)
		try_btn.size = Vector2(64, 24)
		try_btn.add_theme_font_size_override("font_size", 10)
		try_btn.pressed.connect(func() -> void:
			if _preview_bomber:
				_preview_bomber.try_on(entry)
			_set_status("Đang mặc thử: %s" % str(entry.get("name_vn", "")))
		)
		card.add_child(try_btn)

		# Buy / Equip button
		var owned: bool = inv.is_owned(str(entry.get("id", "")))
		var is_consumable: bool = str(entry.get("slot_type", "")) == "consumable"
		var act_btn := Button.new()
		act_btn.text = "Trang bị" if (owned and not is_consumable) else "Mua"
		act_btn.position = Vector2(128, 80)
		act_btn.size = Vector2(66, 24)
		act_btn.add_theme_font_size_override("font_size", 10)
		act_btn.pressed.connect(func() -> void:
			if owned and not is_consumable:
				inv.equip_item(entry)
				Session.sync_from_inventory()
				AuthService.save_active_inventory()
				_preview_bomber.setup_preview(Session.selected_char, Session.get_team_color(Session.team_color_idx), inv.equipped_cosmetics, Vector2(556.0, 262.0))
				_set_status("Đã trang bị: %s" % str(entry.get("name_vn", "")))
				_refresh_balances()
				_refresh_grid()
			else:
				open_buy_dialog(entry)
		)
		card.add_child(act_btn)

func _build_buy_dialog() -> void:
	# CShopBuyDlg (0xe33b4c) centered 320x210 confirmation modal
	_buy_dlg_overlay = ColorRect.new()
	_buy_dlg_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_buy_dlg_overlay.size = Vector2(800, 600)
	_buy_dlg_overlay.visible = false
	_buy_dlg_overlay.z_index = 50
	add_child(_buy_dlg_overlay)

	var panel := Panel.new()
	panel.position = Vector2(240, 195)
	panel.size = Vector2(320, 210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.24, 0.48, 0.98)
	sb.border_color = Color(0.55, 0.85, 1.0, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	_buy_dlg_overlay.add_child(panel)

	var hdr := Label.new()
	hdr.text = "XÁC NHẬN MUA VẬT PHẨM"
	hdr.position = Vector2(0, 10)
	hdr.size = Vector2(320, 22)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	panel.add_child(hdr)

	_buy_dlg_icon = TextureRect.new()
	_buy_dlg_icon.position = Vector2(20, 48)
	_buy_dlg_icon.size = Vector2(64, 64)
	_buy_dlg_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_buy_dlg_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(_buy_dlg_icon)

	_buy_dlg_title = Label.new()
	_buy_dlg_title.position = Vector2(96, 46)
	_buy_dlg_title.size = Vector2(210, 34)
	_buy_dlg_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_dlg_title.add_theme_font_size_override("font_size", 12)
	_buy_dlg_title.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(_buy_dlg_title)

	_buy_dlg_detail = Label.new()
	_buy_dlg_detail.position = Vector2(96, 82)
	_buy_dlg_detail.size = Vector2(210, 62)
	_buy_dlg_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_dlg_detail.add_theme_font_size_override("font_size", 11)
	_buy_dlg_detail.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	panel.add_child(_buy_dlg_detail)

	_buy_dlg_confirm_btn = Button.new()
	_buy_dlg_confirm_btn.text = "Mua ngay"
	_buy_dlg_confirm_btn.position = Vector2(60, 162)
	_buy_dlg_confirm_btn.size = Vector2(92, 30)
	_buy_dlg_confirm_btn.pressed.connect(confirm_buy_dialog)
	panel.add_child(_buy_dlg_confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Hủy"
	cancel_btn.position = Vector2(168, 162)
	cancel_btn.size = Vector2(92, 30)
	cancel_btn.pressed.connect(close_buy_dialog)
	panel.add_child(cancel_btn)

func open_buy_dialog(entry: Dictionary) -> void:
	if _buy_dlg_overlay == null:
		return
	_pending_buy_entry = entry.duplicate(true)
	var inv := Session.get_inventory_man()
	var is_cash: bool = str(entry.get("currency", "lucci")).to_lower() == "cash"
	var cur_txt := "Xu" if is_cash else "Lucci"
	var price: int = int(entry.get("price", 0))
	var balance: int = inv.cash if is_cash else inv.lucci
	var can_buy: bool = inv.can_afford(entry)

	_buy_dlg_title.text = str(entry.get("name_vn", entry.get("id", "")))
	if can_buy:
		_buy_dlg_detail.text = "Giá: %d %s\nHiện có: %d %s\nCòn lại: %d %s" % [price, cur_txt, balance, cur_txt, balance - price, cur_txt]
		_buy_dlg_detail.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	else:
		_buy_dlg_detail.text = "Giá: %d %s\nHiện có: %d %s\nKhông đủ %s!" % [price, cur_txt, balance, cur_txt, cur_txt]
		_buy_dlg_detail.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	var icon_f: Dictionary = SpriteDB.get_frame(str(entry.get("icon", entry.get("sprite", ""))), 0)
	_buy_dlg_icon.texture = icon_f.texture if not icon_f.is_empty() else null
	_buy_dlg_confirm_btn.disabled = not can_buy
	_buy_dlg_overlay.visible = true

func confirm_buy_dialog() -> Dictionary:
	if _pending_buy_entry.is_empty():
		close_buy_dialog()
		return {"ok": false, "reason": "no_pending_item"}
	var entry: Dictionary = _pending_buy_entry
	var inv := Session.get_inventory_man()
	var res: Dictionary = inv.purchase_item(entry)
	if bool(res.get("ok", false)):
		inv.equip_item(entry)
		Session.sync_from_inventory()
		AuthService.save_active_inventory()
		if _preview_bomber:
			_preview_bomber.setup_preview(Session.selected_char, Session.get_team_color(Session.team_color_idx), inv.equipped_cosmetics, Vector2(556.0, 262.0))
		_set_status("Đã mua & trang bị: %s" % str(entry.get("name_vn", "")))
	else:
		var cur_txt := "Xu" if str(entry.get("currency", "lucci")) == "cash" else "Lucci"
		_set_status("Không đủ %s để mua %s!" % [cur_txt, str(entry.get("name_vn", ""))])
	close_buy_dialog()
	_refresh_balances()
	_refresh_grid()
	return res

func close_buy_dialog() -> void:
	_pending_buy_entry = {}
	if _buy_dlg_overlay:
		_buy_dlg_overlay.visible = false
