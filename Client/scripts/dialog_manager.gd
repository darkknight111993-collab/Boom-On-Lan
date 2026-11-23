class_name DialogManager
extends Control
# Manages modal/popup sub-screens defined in res://data/dialogs.json.
# Reuses ScreenBuilder.build() for identical CA.exe offset/button rendering.

const ScreenBuilder = preload("res://scripts/screen_builder.gd")

var _defs := {}
var _stack: Array[Dictionary] = []
var _owner_screen: Control
var _tut_page := 1
var _selected_map := ""
var _map_show_all := false
var _map_theme_filter := ""
var _pending_mode := "normal"
var _pending_team_arrange := 0
var _wait_timer: Timer

func _init(owner_screen: Control) -> void:
	_owner_screen = owner_screen
	size = Vector2(800, 600)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	var raw := FileAccess.get_file_as_string("res://data/dialogs.json")
	if raw != "":
		_defs = JSON.parse_string(raw)

func has_open() -> bool:
	return not _stack.is_empty()

func show_notice(msg: String) -> void:
	open("notice", {"msg": msg})

func open(dlg_id: String, params: Dictionary = {}) -> void:
	if not _defs.has(dlg_id):
		return
	# Toggle popup menu if already open
	if dlg_id == "menu" and not _stack.is_empty() and _stack.back().id == "menu":
		close_top()
		return
	# Close menu before opening another dialog
	if not _stack.is_empty() and _stack.back().id == "menu":
		close_top()

	var def: Dictionary = _defs[dlg_id]
	var layer := Control.new()
	layer.size = Vector2(800, 600)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP if def.get("modal", true) else Control.MOUSE_FILTER_PASS

	if def.get("modal", true):
		var dim := ColorRect.new()
		dim.size = Vector2(800, 600)
		dim.color = Color(0, 0, 0, 0.35)
		layer.add_child(dim)
	else:
		# Non-modal popup (e.g. menu): click outside closes it
		var catcher := Control.new()
		catcher.size = Vector2(800, 600)
		catcher.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				close_top()
		)
		layer.add_child(catcher)

	var panel := Control.new()
	panel.position = Vector2(def.x, def.y)
	panel.size = Vector2(def.w, def.h)
	ScreenBuilder.build(panel, def, self)
	layer.add_child(panel)
	add_child(layer)

	var entry := {"id": dlg_id, "layer": layer, "panel": panel, "params": params}
	_stack.append(entry)
	_setup_dialog(entry)

func close_top() -> void:
	if _stack.is_empty():
		return
	var top: Dictionary = _stack.pop_back()
	if top.id == "login_wait" and _wait_timer:
		_wait_timer.stop()
		_wait_timer.queue_free()
		_wait_timer = null
	(top.layer as Control).queue_free()

func _setup_dialog(entry: Dictionary) -> void:
	var panel: Control = entry.panel
	match entry.id:
		"notice":
			var lbl := panel.get_node_or_null("msg") as Label
			if lbl:
				lbl.text = str(entry.params.get("msg", ""))
		"create_room":
			var rn := panel.get_node_or_null("room_name") as LineEdit
			if rn:
				rn.text = Session.room_title
			_filter_create_room_modes(panel)
			_pending_mode = "normal" # Default mode 1 (ĐẠI CHIẾN)
			_apply_mode_selection(panel, _pending_mode)
			_apply_team_arrange_selection(panel, 0)
			var lk := panel.get_node_or_null("room_lock") as CheckBox
			var pw := panel.get_node_or_null("room_pw") as LineEdit
			if lk and pw:
				pw.editable = false
				lk.toggled.connect(func(on: bool): pw.editable = on)
		"create_room_stage_clear", "create_room_ladder":
			var lk2 := panel.get_node_or_null("room_lock") as CheckBox
			var pw2 := panel.get_node_or_null("room_pw") as LineEdit
			if lk2 and pw2:
				pw2.editable = false
				lk2.toggled.connect(func(on: bool): pw2.editable = on)
		"room_password":
			var jpw := panel.get_node_or_null("join_pw") as LineEdit
			if jpw:
				jpw.text = ""
				jpw.grab_focus()
		"room_info":
			var rt := panel.get_node_or_null("ri_title") as LineEdit
			if rt:
				rt.text = Session.room_title
			var rpw := panel.get_node_or_null("ri_pw") as LineEdit
			if rpw:
				rpw.text = Session.room_password
			var mode_vn := Session.get_mode_name_vn(Session.game_mode)
			var rmh := panel.get_node_or_null("ri_mode_header") as Label
			if rmh:
				rmh.text = "Chế độ chơi: %s" % mode_vn
			var rml := panel.get_node_or_null("ri_mode_lbl") as Label
			if rml:
				rml.text = mode_vn
		"lobby_room_info":
			var flow = Session.get_lobby_flow()
			var rid: int = int(entry.params.get("room_id", Session.active_room_id))
			var room: Dictionary = flow.get_room(rid)
			var slots: Array = room.get("slots", [])
			for i in range(8):
				var p_lbl := panel.get_node_or_null("ri_p%d" % (i + 1)) as Label
				var lv_lbl := panel.get_node_or_null("ri_lv%d" % (i + 1)) as Label
				if i < slots.size() and str(slots[i].get("state", "")) == "occupied":
					var s: Dictionary = slots[i]
					var tag := " (Chủ phòng)" if bool(s.get("is_host", false)) else (" [Bot]" if bool(s.get("is_bot", false)) else "")
					if p_lbl: p_lbl.text = "%s%s" % [str(s.get("nickname", "Player")), tag]
					if lv_lbl: lv_lbl.text = str(int(s.get("level", 1)))
				else:
					if p_lbl: p_lbl.text = "[Đóng]" if (i < slots.size() and str(slots[i].get("state", "")) == "closed") else "[Chỗ trống]"
					if lv_lbl: lv_lbl.text = "-"
		"register":
			var male := panel.get_node_or_null("reg_male") as CheckBox
			var female := panel.get_node_or_null("reg_female") as CheckBox
			if male and female:
				male.pressed.connect(func(): male.button_pressed = true; female.button_pressed = false)
				female.pressed.connect(func(): female.button_pressed = true; male.button_pressed = false)
		"option":
			var s_bgm := panel.get_node_or_null("opt_bgm") as HSlider
			var s_sfx := panel.get_node_or_null("opt_sfx") as HSlider
			if s_bgm:
				s_bgm.value = AudioManager.bgm_volume
				s_bgm.value_changed.connect(AudioManager.set_bgm_volume)
			if s_sfx:
				s_sfx.value = AudioManager.sfx_volume
				s_sfx.value_changed.connect(AudioManager.set_sfx_volume)
		"tutorial":
			_tut_page = 1
			_refresh_tutorial(panel)
		"select_map":
			_populate_map_list(panel)
		"login_wait":
			_start_login_wait(panel, entry.params)

func _refresh_tutorial(panel: Control) -> void:
	_tut_page = clampi(_tut_page, 1, 20)
	var sp := "Tutorial/%02d" % _tut_page
	var f := SpriteDB.get_frame(sp, 0)
	var img := panel.get_node_or_null("tut_page") as TextureRect
	if img and not f.is_empty():
		img.texture = f.texture
	var lbl := panel.get_node_or_null("tut_counter") as Label
	if lbl:
		lbl.text = "Trang %d / 20" % _tut_page

func _filter_create_room_modes(panel: Control) -> void:
	# Filter create-room cards by channel allowed_component_ids + special_component_ids (sub_6277FC)
	var allowed: Array[int] = Session.get_lobby_flow().get_channel_creatable_modes(Session.selected_channel_id)
	var cards := panel.get_node_or_null("mode_strip/Cards")
	if cards == null:
		return
	var flow = Session.get_lobby_flow()
	for c in cards.get_children():
		if not (c is TextureButton):
			continue
		var btn := c as TextureButton
		var cid := str(btn.get_meta("mode_id", ""))
		if cid == "gametype":
			var any_sub := false
			for child in btn.get_children():
				if child is Button and child.has_meta("component_id"):
					var sub_ok: bool = allowed.has(int(child.get_meta("component_id", -1)))
					child.visible = sub_ok
					if sub_ok:
						any_sub = true
			btn.visible = any_sub
		else:
			var comp_id: int = flow.mode_key_to_component_id(cid)
			btn.visible = allowed.has(comp_id)

func _apply_mode_selection(panel: Control, mode_id: String) -> void:
	# Clicking the outer gametype card defaults to its first visible sub-mode (e.g. captain/hedgehog)
	var resolved_id := mode_id
	var cards := panel.get_node_or_null("mode_strip/Cards")
	if resolved_id == "gametype" and cards:
		var gt := cards.get_node_or_null("mode_gametype")
		if gt:
			for child in gt.get_children():
				if child is Button and child.visible and child.has_meta("mode_id"):
					resolved_id = str(child.get_meta("mode_id", "hedgehog"))
					break
	_pending_mode = resolved_id
	var chosen_label := resolved_id
	const SUB_MODES := ["captain", "hedgehog", "survival", "timebomb"]
	var is_sub_selected := SUB_MODES.has(resolved_id)
	if cards:
		for c in cards.get_children():
			if not (c is TextureButton):
				continue
			var btn := c as TextureButton
			var cid := str(btn.get_meta("mode_id", ""))
			var sp := str(btn.get_meta("mode_sprite", ""))
			var is_sel := (cid == resolved_id) or (cid == "gametype" and is_sub_selected)
			var bt := SpriteDB.get_button_textures(sp, 3 if is_sel else 0)
			for prop in bt.textures:
				btn.set(prop, bt.textures[prop])
			if cid == resolved_id:
				chosen_label = str(btn.get_meta("mode_label", cid))
			if cid == "gametype":
				for child in btn.get_children():
					if child is Button and child.has_meta("mode_id"):
						var sm_sel := str(child.get_meta("mode_id", "")) == resolved_id
						var lbl_n := child.get_node_or_null("Label") as Label
						if lbl_n:
							lbl_n.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3) if sm_sel else Color.WHITE)
						if sm_sel:
							chosen_label = str(child.get_meta("mode_label", resolved_id))
	var lbl := panel.get_node_or_null("mode_label") as Label
	if lbl:
		lbl.text = chosen_label

func _apply_team_arrange_selection(panel: Control, arrange_idx: int) -> void:
	_pending_team_arrange = clampi(arrange_idx, 0, 2)
	const NAMES := ["Tự do", "Đấu đội", "Tự động"]
	for i in range(3):
		var tb := panel.get_node_or_null("team_arrange_%d" % i) as Button
		if tb:
			tb.text = ("%s %s" % ["●" if i == _pending_team_arrange else "○", NAMES[i]])
			tb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35) if i == _pending_team_arrange else Color.WHITE)

func _populate_map_list(panel: Control) -> void:
	var il := panel.get_node_or_null("map_list") as ItemList
	if il == null:
		return
	il.clear()
	var mode_id: String = Session.get_lobby_flow().component_id_to_mode_key(Session.selected_component_id)
	Session.game_mode = mode_id
	var mode_info := Session.get_mode_info(mode_id)
	var mode_vn := Session.get_mode_name_vn(mode_id)
	var maps: Array = Session.get_maps_for_active_room(_map_show_all, _map_theme_filter)
	if maps.is_empty() and _map_theme_filter != "":
		_map_theme_filter = ""
		maps = Session.get_maps_for_active_room(_map_show_all, "")
	if maps.is_empty():
		maps = DirAccess.get_directories_at(SpriteDB.root.path_join("Map"))
	maps = Session.get_map_man().sort_maps_by_name(maps, func(c: String) -> String: return Session.get_map_name_vn(c))

	var theme_btn := panel.get_node_or_null("map_theme_btn") as Button
	if theme_btn:
		theme_btn.text = "Chủ đề: %s" % (_map_theme_filter if _map_theme_filter != "" else "Tất cả")
	var all_btn := panel.get_node_or_null("map_show_all") as Button
	if all_btn:
		all_btn.text = ("● Hiện tất cả" if _map_show_all else "○ Hiện tất cả")

	# Update mode and header labels
	var mode_lbl := panel.get_node_or_null("map_mode") as Label
	if mode_lbl:
		mode_lbl.text = mode_vn
	var header_lbl := panel.get_node_or_null("map_list_header") as Label
	if header_lbl:
		header_lbl.text = "Bản đồ (%s) - %d bản đồ" % [mode_vn, maps.size()]

	_selected_map = Session.selected_map
	var fallback_icon: Texture2D = null
	var f0 := SpriteDB.get_frame("Prepare/Dlg_PRE-SelMapListIcon", 0)
	if not f0.is_empty():
		fallback_icon = f0.texture
	var sel_idx := 0
	var found_selected := false
	for i in maps.size():
		var code := str(maps[i])
		var vn := Session.get_map_name_vn(code)
		var label := "%s (%s)" % [vn, code] if vn != code else code
		il.add_item(label, fallback_icon)
		il.set_item_metadata(i, code)
		if code == _selected_map:
			sel_idx = i
			found_selected = true
	if not found_selected and maps.size() > 0:
		var def_map: String = str(mode_info.get("default_map", maps[0]))
		for i in maps.size():
			if str(maps[i]) == def_map:
				sel_idx = i
				_selected_map = def_map
				break
		if not found_selected and _selected_map == Session.selected_map:
			_selected_map = str(maps[sel_idx])

	il.set_meta("hydrated", {})
	var vsb := il.get_v_scroll_bar()
	vsb.value_changed.connect(func(_v: float): _hydrate_visible_map_icons(il))
	if maps.size() > 0:
		il.select(sel_idx)
		il.ensure_current_is_visible()
		il.grab_focus()
		_update_map_info(panel, str(maps[sel_idx]))
		call_deferred("_hydrate_visible_map_icons", il)
		il.item_selected.connect(func(idx: int):
			_selected_map = str(il.get_item_metadata(idx))
			_update_map_info(panel, _selected_map)
		)
		il.item_activated.connect(func(idx: int):
			_selected_map = str(il.get_item_metadata(idx))
			on_action("dialog:submit_select_map")
		)

func _hydrate_visible_map_icons(il: ItemList) -> void:
	if not is_instance_valid(il) or il.item_count == 0:
		return
	var hydrated: Dictionary = il.get_meta("hydrated", {})
	var vsb := il.get_v_scroll_bar()
	var total_h: float = maxf(vsb.max_value, float(il.item_count) * 27.0)
	var row_h: float = maxf(total_h / float(il.item_count), 20.0)
	var first := maxi(0, int(floor(vsb.value / row_h)) - 4)
	var vis_rows := int(ceil(il.size.y / row_h)) + 8
	var last := mini(il.item_count - 1, first + vis_rows)
	for i in range(first, last + 1):
		if hydrated.has(i):
			continue
		hydrated[i] = true
		var code := str(il.get_item_metadata(i))
		var icon := SpriteDB.get_map_icon(code if code != "" else il.get_item_text(i))
		if icon:
			il.set_item_icon(i, icon)

func _update_map_info(panel: Control, map_name: String) -> void:
	var t := panel.get_node_or_null("map_title") as Label
	if t:
		t.text = Session.get_map_name_vn(map_name)
	var desc_lbl := panel.get_node_or_null("map_desc") as Label
	if desc_lbl:
		var d_vn := Session.get_map_desc_vn(map_name)
		desc_lbl.text = d_vn if d_vn != "" else "Không có mô tả."
		desc_lbl.size = desc_lbl.custom_minimum_size if desc_lbl.custom_minimum_size.x > 0.0 else Vector2(142, 100)
	var prev := panel.get_node_or_null("map_preview") as TextureRect
	if prev:
		var mm := SpriteDB.get_map_minimap(map_name)
		if mm:
			prev.texture = mm
	var path := SpriteDB.root.path_join("Map").path_join(map_name).path_join("map.json")
	if not FileAccess.file_exists(path):
		return
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if m is Dictionary:
		var d := panel.get_node_or_null("map_dim") as Label
		var sp := panel.get_node_or_null("map_spawns") as Label
		if d:
			d.text = "%d x %d" % [int(m.get("cols", 15)), int(m.get("rows", 13))]
		if sp:
			sp.text = str(Session.get_map_man().get_map_max_players(map_name))

func _start_login_wait(panel: Control, params: Dictionary) -> void:
	var steps := [2]
	_wait_timer = Timer.new()
	_wait_timer.wait_time = 0.25
	panel.add_child(_wait_timer)
	_wait_timer.timeout.connect(func():
		steps[0] -= 1
		var d2 := panel.get_node_or_null("wait_d2") as TextureRect
		if d2 and steps[0] >= 0:
			var f := SpriteDB.get_frame("LoginStage/Dlg_LO-WaitingNumber", steps[0])
			if not f.is_empty():
				d2.texture = f.texture
		if steps[0] <= 0:
			_wait_timer.stop()
			close_top()
			var on_done: Callable = params.get("on_done", Callable())
			if on_done.is_valid():
				on_done.call()
	)
	_wait_timer.start()

func on_action(action: String) -> void:
	if action == "dialog:close" or action == "dialog:cancel_login_wait":
		close_top()
	elif action.begins_with("dialog:open:"):
		open(action.substr(12))
	elif action.begins_with("dialog:notice:"):
		show_notice(action.substr(14))
	elif action == "dialog:check_id":
		var p: Control = _stack.back().panel
		var id_txt := (p.get_node("reg_id") as LineEdit).text.strip_edges()
		if id_txt == "":
			show_notice("Vui lòng nhập tên nhân vật trước khi kiểm tra.")
		else:
			show_notice("Tên nhân vật '%s' hợp lệ (chế độ LAN offline)." % id_txt)
	elif action == "dialog:submit_register":
		var p: Control = _stack.back().panel
		var id_txt := (p.get_node("reg_id") as LineEdit).text.strip_edges()
		var pw1 := (p.get_node("reg_pw") as LineEdit).text
		var pw2 := (p.get_node("reg_pw2") as LineEdit).text
		if id_txt == "" or pw1 == "":
			show_notice("Vui lòng nhập đầy đủ Tên nhân vật và Mật khẩu.")
		elif pw1 != pw2:
			show_notice("Mật khẩu xác nhận không khớp.")
		else:
			# TODO(db): lưu tài khoản mới vào DB khi làm backend
			close_top()
			show_notice("Đăng ký thành công '%s'! Bạn có thể đăng nhập ngay." % id_txt)
	elif action == "dialog:submit_forgot_pw":
		var p: Control = _stack.back().panel
		var id_txt := (p.get_node("pw_id") as LineEdit).text.strip_edges()
		if id_txt == "":
			show_notice("Vui lòng nhập tên tài khoản cần tìm mật khẩu.")
		else:
			# TODO(db): truy vấn khôi phục mật khẩu từ DB
			close_top()
			show_notice("Chế độ LAN offline chấp nhận mọi mật khẩu cho tài khoản '%s'." % id_txt)
	elif action.begins_with("dialog:select_mode:"):
		_apply_mode_selection(_stack.back().panel, action.substr(19))
	elif action.begins_with("dialog:select_team_arrange:"):
		_apply_team_arrange_selection(_stack.back().panel, int(action.substr(27)))
	elif action == "dialog:submit_create_room" or action == "dialog:submit_create_room_stage_clear" or action == "dialog:submit_create_room_ladder":
		var p: Control = _stack.back().panel
		var rn := (p.get_node("room_name") as LineEdit).text.strip_edges()
		var lk := p.get_node_or_null("room_lock") as CheckBox
		var pw_edit := p.get_node_or_null("room_pw") as LineEdit
		var room_pw := pw_edit.text.strip_edges() if (lk and lk.button_pressed and pw_edit) else ""
		var flow = Session.get_lobby_flow()
		var comp_id: int = flow.mode_key_to_component_id(_pending_mode)
		if action == "dialog:submit_create_room_stage_clear":
			comp_id = 14
		elif action == "dialog:submit_create_room_ladder":
			comp_id = 0
		var mode_key: String = flow.component_id_to_mode_key(comp_id)
		var mode_info := Session.get_mode_info(mode_key)
		var def_map: String = str(mode_info.get("default_map", Session.selected_map))
		var title := rn if rn != "" else "Phòng của %s" % (Session.nickname if Session.nickname != "" else "Guest")
		var host_user := {"id": int(Session.user_id) if Session.user_id.is_valid_int() else 1, "nickname": Session.nickname if Session.nickname != "" else "Player", "level": Session.level, "selected_char": Session.selected_char, "team_color_idx": Session.team_color_idx}
		var created: Dictionary = flow.create_room(Session.selected_channel_id, title, room_pw, comp_id, def_map, host_user, _pending_team_arrange)
		Session.apply_room_to_session(created)
		NetworkManager.host_room()
		close_top()
		Session.goto("prepare")
	elif action == "dialog:submit_room_password":
		var top_entry: Dictionary = _stack.back()
		var p: Control = top_entry.panel
		var rid: int = int(top_entry.params.get("room_id", -1))
		var entered_pw := (p.get_node("join_pw") as LineEdit).text.strip_edges()
		var res: Dictionary = Session.get_lobby_flow().can_join_room(rid, entered_pw)
		if not bool(res.get("ok", false)):
			show_notice(str(res.get("error", "Mật khẩu không chính xác.")))
			return
		Session.apply_room_to_session(res.get("room", {}))
		close_top()
		Session.goto("prepare")
	elif action == "dialog:submit_room_info":
		var p: Control = _stack.back().panel
		var rt := (p.get_node("ri_title") as LineEdit).text.strip_edges()
		var rpw_edit := p.get_node_or_null("ri_pw") as LineEdit
		if rt != "":
			Session.room_title = rt
			var lbl := _owner_screen.get_node_or_null("RoomTitle") as Label
			if lbl:
				lbl.text = rt
		if rpw_edit != null:
			Session.room_password = rpw_edit.text.strip_edges()
		var active_room: Dictionary = Session.get_lobby_flow().get_room(Session.active_room_id)
		if not active_room.is_empty():
			active_room["title"] = Session.room_title
			active_room["password"] = Session.room_password
			active_room["locked"] = Session.room_password != ""
		close_top()
	elif action == "dialog:map_toggle_all":
		_map_show_all = not _map_show_all
		_populate_map_list(_stack.back().panel)
	elif action == "dialog:map_cycle_theme":
		var all_mode_maps: Array[String] = []
		for mc in Session.get_maps_for_active_room(_map_show_all, ""):
			all_mode_maps.append(str(mc))
		var themes: Array[String] = Session.get_map_man().get_themes_for_maps(all_mode_maps)
		if themes.is_empty():
			_map_theme_filter = ""
		elif _map_theme_filter == "":
			_map_theme_filter = themes[0]
		else:
			var tidx: int = themes.find(_map_theme_filter)
			_map_theme_filter = "" if (tidx < 0 or tidx >= themes.size() - 1) else themes[tidx + 1]
		_populate_map_list(_stack.back().panel)
	elif action == "dialog:submit_select_map":
		if _selected_map != "":
			var flow = Session.get_lobby_flow()
			var active_room: Dictionary = flow.get_room(Session.active_room_id)
			var pcount: int = flow.get_occupied_count(active_room) if not active_room.is_empty() else (2 if Session.is_2p else 1)
			var lim: Dictionary = Session.get_map_man().check_player_limit(_selected_map, pcount)
			if not bool(lim.get("ok", true)):
				show_notice(str(lim.get("error", "Bản đồ vượt quá giới hạn người chơi.")))
				return
			Session.selected_map = _selected_map
			if not active_room.is_empty():
				active_room["map_code"] = _selected_map
			var lbl := _owner_screen.get_node_or_null("MapName") as Label
			if lbl:
				lbl.text = Session.get_map_name_vn(_selected_map)
			var mp := _owner_screen.get_node_or_null("MapPreview") as TextureRect
			if mp:
				var mm := SpriteDB.get_map_minimap(_selected_map)
				if mm:
					mp.texture = mm
		close_top()
	elif action == "dialog:tut_prev":
		_tut_page -= 1
		_refresh_tutorial(_stack.back().panel)
	elif action == "dialog:tut_next":
		_tut_page += 1
		_refresh_tutorial(_stack.back().panel)
	elif action.begins_with("dialog:tut_chapter:"):
		# 8 chapters mapped cleanly across the 20 VN tutorial pages
		var starts := [1, 4, 7, 10, 13, 15, 17, 19]
		var ch := clampi(int(action.substr(19)), 0, starts.size() - 1)
		_tut_page = starts[ch]
		_refresh_tutorial(_stack.back().panel)
	else:
		close_top()
		_owner_screen.call("on_action", action)
