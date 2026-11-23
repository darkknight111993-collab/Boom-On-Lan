extends Control
# Generic screen: builds from JSON, routes button actions & modal dialogs. Set `screen` on the scene root.

const ScreenBuilder = preload("res://scripts/screen_builder.gd")
const MapViewScript = preload("res://scripts/map_view.gd")
const DialogManagerScript = preload("res://scripts/dialog_manager.gd")
const CMyPageDlgClass = preload("res://scripts/mypage_dialog.gd")

@export var screen := ""
var dialogs: DialogManagerScript
var _is_2p := false
var _room_blink_timer := 0.0
var _room_blink_frame := 0
var _slot_cosmetic_layers: Array[Control] = []

const _ROOM_SLOT_ANCHORS: Array[Vector2] = [
	Vector2(56.0, 182.0), Vector2(162.0, 182.0), Vector2(268.0, 182.0), Vector2(374.0, 182.0),
	Vector2(56.0, 328.0), Vector2(162.0, 328.0), Vector2(268.0, 328.0), Vector2(374.0, 328.0),
]
var _ch_active_tab := "free"
var _ch_page := 1
var _ch_game_mode := "ca" # "ca" (Boom Online) | "hc" (Hidden Catch)
var _ch_banner_idx := 1
var _ch_bar_nodes: Array = []
var _ch_new_nodes: Array = []
var _ch_tooltip_panel: PanelContainer = null
var _ch_tooltip_label: Label = null

const _CH_BANNER_SLIDES := [
	{"title": "CHÀO MỪNG ĐẾN BOOM ON LAN", "body": "Chơi offline & mạng LAN đầy đủ chế độ:\nĐại Chiến, Săn Nhím, Săn Quái, Đấu Boss RPG."},
	{"title": "CHẾ ĐỘ SĂN NHÍM (HEDGEHOG)", "body": "Biến hình thành Nhím siêu tốc, dùng Nhím Giả\nvà Siêu Nhím để đánh bại đối thủ!"},
	{"title": "KÊNH SIÊU CẤP & ĐẤU HẠNG", "body": "Kênh LT / CB dành cho người chơi dưới grade 2.\nKênh Đấu Hạng (DH) mở từ cấp 10 trở lên."},
	{"title": "PHÒNG TẬP & BẢN ĐỒ KHINH KHÍ CẦU", "body": "Hỗ trợ đầy đủ bản đồ TestAirship01, Camp08,\nVillage10 cùng vật phẩm & thú cưỡi."},
	{"title": "PHÍM TẮT NHANH", "body": "F1: Hướng dẫn   |   F10: Tùy chọn\nESC: Đóng hộp thoại / Quay lại phòng chờ."},
]

func _process(delta: float) -> void:
	if screen == "prepare":
		_room_blink_timer += delta
		var cycle: float = fposmod(_room_blink_timer, 2.8)
		var new_frame := 0
		if cycle < 0.12:
			new_frame = 1
		elif cycle < 0.24:
			new_frame = 2
		elif cycle < 0.36:
			new_frame = 1
		else:
			new_frame = 0
		if new_frame != _room_blink_frame:
			_room_blink_frame = new_frame
			_update_room_slots()

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/screens/%s.json" % screen))
	ScreenBuilder.build(self, data)
	dialogs = DialogManagerScript.new(self)
	add_child(dialogs)
	if screen == "game_stage":
		var mv := Node2D.new()
		mv.set_script(MapViewScript)
		mv.embedded = true
		var target_map := Session.selected_map
		if not DirAccess.dir_exists_absolute(SpriteDB.root.path_join("Map").path_join(target_map)):
			target_map = "Camp08" if DirAccess.dir_exists_absolute(SpriteDB.root.path_join("Map/Camp08")) else "Factory15"
		mv.initial_map = target_map
		# Clip embedded playfield to (20,41, 600x520) so scrolling maps never bleed over HUD
		var clip := Control.new()
		clip.name = "PlayfieldClip"
		clip.position = Vector2(20, 41)
		clip.size = Vector2(600, 520)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mv._base_offset = Vector2(-20, -41)
		mv.position = Vector2(-20, -41)
		add_child(clip)
		move_child(clip, 1)
		clip.add_child(mv)
	if data.has("bgm"):
		AudioManager.play_bgm(data.bgm)
	if screen == "login":
		# like the original: OK stays disabled until required fields are filled
		for f: LineEdit in [$user_id, $password, $user2_id, $password2]:
			f.text_changed.connect(_refresh_login)
			f.text_submitted.connect(func(_t):
				if not ($btn_login as TextureButton).disabled:
					AudioManager.play_sfx("Bt_c_Success")
					on_action("login")
			)
		($user_id as LineEdit).text = ""
		($password as LineEdit).text = ""
		_set_login_2p(false)
	if screen == "select_server":
		_init_select_server()
	if screen == "lobby":
		var nick := get_node_or_null("Nick") as Label
		if nick and Session.nickname != "":
			nick.text = "%s & %s" % [Session.nickname, Session.nickname2] if Session.is_2p else Session.nickname
		var stats := get_node_or_null("ProfileStats") as Label
		if stats:
			stats.text = Session.get_profile_stats_text()
		_refresh_lobby_rooms()
	if screen == "prepare":
		var rt := get_node_or_null("RoomTitle") as Label
		if rt:
			rt.text = Session.room_title
		var mn := get_node_or_null("MapName") as Label
		if mn:
			mn.text = Session.get_map_name_vn(Session.selected_map)
		var mp := get_node_or_null("MapPreview") as TextureRect
		if mp:
			var mm := SpriteDB.get_map_minimap(Session.selected_map)
			if mm:
				mp.texture = mm
		var sn := get_node_or_null("Slot0Nick") as Label
		if sn and Session.nickname != "":
			sn.text = "%s / %s" % [Session.nickname, Session.nickname2] if Session.is_2p else Session.nickname
		_apply_char_selection(Session.selected_char_slot)
		_apply_team_selection(Session.team_color_idx)
		_init_prepare_slot_controls()
		if not NetworkManager.room_updated.is_connected(_on_network_room_updated):
			NetworkManager.room_updated.connect(_on_network_room_updated)

func _set_login_2p(enabled: bool) -> void:
	_is_2p = enabled
	var tbl := $log_table as TextureRect
	var f := SpriteDB.get_frame("LoginStage/LO_LogTable01" if enabled else "LoginStage/LO_LogTable00", 0)
	if not f.is_empty():
		tbl.texture = f.texture
		tbl.custom_minimum_size = f.size
		tbl.reset_size()
	tbl.position = Vector2(143, 413) if enabled else Vector2(188, 413)

	# Both 1P and 2P tab buttons remain visible simultaneously.
	# The active tab is disabled (selected), the other tab is enabled (clickable).
	var b1 := $btn_1p as TextureButton
	var b2 := $btn_2p as TextureButton
	b1.visible = true
	b2.visible = true
	b1.disabled = not enabled
	b2.disabled = enabled
	if enabled:
		b1.position = Vector2(151, 437)
		b2.position = Vector2(572, 437)
	else:
		b1.position = Vector2(196, 437)
		b2.position = Vector2(529, 437)

	var u1 := $user_id as LineEdit
	var p1 := $password as LineEdit
	var u2 := $user2_id as LineEdit
	var p2 := $password2 as LineEdit
	if enabled:
		u1.position = Vector2(358, 463)
		p1.position = Vector2(358, 488)
		u1.size = Vector2(88, 19)
		p1.size = Vector2(88, 19)
		u2.position = Vector2(451, 463)
		p2.position = Vector2(451, 488)
		u2.size = Vector2(88, 19)
		p2.size = Vector2(88, 19)
		u2.visible = true
		p2.visible = true
		if u2.text == "":
			u2.text = "player2"
			p2.text = "123"
	else:
		u1.position = Vector2(403, 463)
		p1.position = Vector2(403, 488)
		u1.size = Vector2(91, 19)
		p1.size = Vector2(91, 19)
		u2.visible = false
		p2.visible = false
	_refresh_login()

func _refresh_login(_t := "") -> void:
	var p1_ok := ($user_id as LineEdit).text != "" and ($password as LineEdit).text != ""
	var p2_ok := (not _is_2p) or (($user2_id as LineEdit).text != "" and ($password2 as LineEdit).text != "")
	($btn_login as TextureButton).disabled = not (p1_ok and p2_ok)

func _apply_char_selection(slot_idx: int) -> void:
	var slots := Session.get_char_slots()
	if slots.is_empty():
		return
	slot_idx = clampi(slot_idx, 0, slots.size() - 1)
	Session.selected_char_slot = slot_idx
	var info: Dictionary = slots[slot_idx]
	Session.selected_char = str(info.get("char", "Character/C00"))
	var banner := get_node_or_null("CharBanner") as TextureRect
	if banner:
		var bf := SpriteDB.get_frame(str(info.get("banner_sprite", "Etc/ChaInfo_Char00")), 0)
		if not bf.is_empty():
			banner.texture = bf.texture
	for i in slots.size():
		var btn := get_node_or_null("CharBtn%d" % i) as TextureButton
		if btn == null:
			continue
		var sp := str((slots[i] as Dictionary).get("button_sprite", ""))
		var bt := SpriteDB.get_button_textures(sp, 3 if i == slot_idx else 0)
		for prop in bt.textures:
			btn.set(prop, bt.textures[prop])
		btn.tooltip_text = str((slots[i] as Dictionary).get("name_vn", ""))
	var chk := get_node_or_null("CharCheck") as TextureRect
	if chk:
		var cx := 490 + (slot_idx % 4) * 72 + 38
		var cy := 116 + (slot_idx / 4) * 47 - 5
		chk.position = Vector2(cx, cy)
	_update_room_slots()

func _apply_team_selection(team_idx: int) -> void:
	Session.team_color_idx = clampi(team_idx, 0, 7)
	var chk := get_node_or_null("TeamCheck") as TextureRect
	if chk:
		chk.position = Vector2(484 + Session.team_color_idx * 37 + 10, 272)
	_update_room_slots()

func _update_room_slots() -> void:
	var prefix := "C00"
	var parts := Session.selected_char.split("/")
	if parts.size() > 1:
		prefix = parts[1]

	# Slot 0: Player 1 (Local)
	# Recess is [27, 125], center = 76.0. Character body/shadow center is offset +20px relative to anchor.
	# Setting anchor0 = (56.0, 182.0) centers character & shadow precisely at X = 76.0, pedestal floor Y = 182.
	var anchor0 := Vector2(56.0, 182.0)
	var s0_sh := get_node_or_null("Slot0Shadow") as TextureRect
	var s0_st := get_node_or_null("Slot0CharStatic") as TextureRect
	var s0_ad := get_node_or_null("Slot0CharAdjust") as TextureRect

	if prefix == "Random":
		# Original BnB (CA.exe sub_4D324D:206630): Question mark (Prepare/PRE_Img frame 12) replaces character & shadow
		if s0_sh:
			s0_sh.texture = null
		if s0_ad:
			s0_ad.texture = null
		if s0_st:
			var qf := SpriteDB.get_frame("Prepare/PRE_Img", 12)
			if not qf.is_empty():
				s0_st.texture = qf.texture
				# Center precisely in the upper slot recess [27, 94] to [125, 191] (center = 76.0, 142.5)
				s0_st.position = Vector2(round(76.0 - qf.size.x / 2.0), round(142.5 - qf.size.y / 2.0))
				s0_st.modulate = Session.get_team_color(Session.team_color_idx)
			else:
				s0_st.texture = null
		_hide_slot_cosmetics(0)
	else:
		if s0_sh:
			var sh_f := SpriteDB.get_frame("Shadow/Shadow", 0)
			if not sh_f.is_empty():
				s0_sh.texture = sh_f.texture
				s0_sh.position = anchor0 - sh_f.offset
		if s0_st and s0_ad:
			var cf := SpriteDB.get_character_frame(prefix, "Blink", _room_blink_frame)
			if cf.is_empty():
				cf = SpriteDB.get_character_frame(prefix, "WalkDown", 0)
			if not cf.is_empty():
				s0_ad.texture = cf.adjust_texture
				s0_ad.position = anchor0 - cf.offset
				s0_ad.modulate = Session.get_team_color(Session.team_color_idx)
				s0_st.texture = cf.static_texture
				s0_st.position = anchor0 - cf.offset
				s0_st.modulate = Color.WHITE
			else:
				s0_ad.texture = null
				s0_st.texture = null
		_update_slot_cosmetics(0, anchor0, Session.get_team_color(Session.team_color_idx), Session.get_room_slot_cosmetics(0), s0_st)

	# Slot 1: Player 2 (Local 2P or Bot)
	# Recess is [133, 231], center = 182.0. Character body/shadow center is offset +20px relative to anchor.
	# Setting anchor1 = (162.0, 182.0) centers character & shadow precisely at X = 182.0, pedestal floor Y = 182.
	var anchor1 := Vector2(162.0, 182.0)
	var s1_sh := get_node_or_null("Slot1Shadow") as TextureRect
	var s1_st := get_node_or_null("Slot1CharStatic") as TextureRect
	var s1_ad := get_node_or_null("Slot1CharAdjust") as TextureRect
	var p2_prefix := "C01"
	# Keep P2/Bot team independent so changing local player's team only modifies local player
	var p2_team: int = Session.user2_team_color_idx

	if p2_prefix == "Random":
		if s1_sh:
			s1_sh.texture = null
		if s1_ad:
			s1_ad.texture = null
		if s1_st:
			var qf1 := SpriteDB.get_frame("Prepare/PRE_Img", 12)
			if not qf1.is_empty():
				s1_st.texture = qf1.texture
				# Center precisely in the upper slot recess [133, 94] to [231, 191] (center = 182.0, 142.5)
				s1_st.position = Vector2(round(182.0 - qf1.size.x / 2.0), round(142.5 - qf1.size.y / 2.0))
				s1_st.modulate = Session.get_team_color(p2_team)
			else:
				s1_st.texture = null
	else:
		if s1_sh:
			var sh_f := SpriteDB.get_frame("Shadow/Shadow", 0)
			if not sh_f.is_empty():
				s1_sh.texture = sh_f.texture
				s1_sh.position = anchor1 - sh_f.offset
		if s1_st and s1_ad:
			var cf1 := SpriteDB.get_character_frame(p2_prefix, "Blink", _room_blink_frame)
			if cf1.is_empty():
				cf1 = SpriteDB.get_character_frame(p2_prefix, "WalkDown", 0)
			if not cf1.is_empty():
				s1_ad.texture = cf1.adjust_texture
				s1_ad.position = anchor1 - cf1.offset
				s1_ad.modulate = Session.get_team_color(p2_team)
				s1_st.texture = cf1.static_texture
				s1_st.position = anchor1 - cf1.offset
				s1_st.modulate = Color.WHITE
			else:
				s1_ad.texture = null
				s1_st.texture = null
		_update_slot_cosmetics(1, anchor1, Session.get_team_color(p2_team), Session.get_room_slot_cosmetics(1), s1_st)

	# Slots 2..7: LAN / multi-slot players (hidden when empty; renders shadow + char + cosmetics when occupied)
	for slot_i in range(2, 8):
		var eq_i: Dictionary = Session.get_room_slot_cosmetics(slot_i)
		var slot_sh := get_node_or_null("Slot%dShadow" % slot_i) as TextureRect
		var slot_ad := get_node_or_null("Slot%dCharAdjust" % slot_i) as TextureRect
		var slot_st := get_node_or_null("Slot%dCharStatic" % slot_i) as TextureRect
		var slot_nk := get_node_or_null("Slot%dNick" % slot_i) as Label
		var slot_bg := get_node_or_null("Slot%dBadge" % slot_i) as TextureRect
		var slot_lock := get_node_or_null("Slot%dLockImg" % slot_i) as TextureRect
		if Session.room_slot_locked[slot_i]:
			if slot_sh: slot_sh.visible = false
			if slot_ad: slot_ad.visible = false
			if slot_st: slot_st.visible = false
			if slot_nk: slot_nk.text = "ĐÃ KHÓA"
			if slot_bg: slot_bg.visible = false
			if slot_lock: slot_lock.visible = true
			_hide_slot_cosmetics(slot_i)
		elif eq_i.is_empty():
			if slot_sh: slot_sh.visible = false
			if slot_ad: slot_ad.visible = false
			if slot_st: slot_st.visible = false
			if slot_nk: slot_nk.text = ""
			if slot_bg: slot_bg.visible = false
			if slot_lock: slot_lock.visible = false
			_hide_slot_cosmetics(slot_i)
		else:
			if slot_lock: slot_lock.visible = false
			var anc: Vector2 = _ROOM_SLOT_ANCHORS[slot_i]
			var col_i: Color = Session.get_team_color(int(eq_i.get("team_color_idx", slot_i % 8)))
			var ch_str: String = str(eq_i.get("char", "Character/C00"))
			var ch_pref: String = ch_str.split("/")[1] if ch_str.contains("/") else ch_str
			if slot_nk: slot_nk.text = str(eq_i.get("nick", "Player %d" % (slot_i + 1)))
			if slot_bg: slot_bg.visible = bool(eq_i.get("ready", true))
			if slot_sh:
				slot_sh.visible = true
				var sh_f := SpriteDB.get_frame("Shadow/Shadow", 0)
				if not sh_f.is_empty():
					slot_sh.texture = sh_f.texture
					slot_sh.position = anc - sh_f.offset
			if slot_st and slot_ad:
				slot_st.visible = true
				slot_ad.visible = true
				var cfi := SpriteDB.get_character_frame(ch_pref, "Blink", _room_blink_frame)
				if cfi.is_empty():
					cfi = SpriteDB.get_character_frame(ch_pref, "WalkDown", 0)
				if not cfi.is_empty():
					slot_ad.texture = cfi.adjust_texture
					slot_ad.position = anc - cfi.offset
					slot_ad.modulate = col_i
					slot_st.texture = cfi.static_texture
					slot_st.position = anc - cfi.offset
					slot_st.modulate = Color.WHITE
			_update_slot_cosmetics(slot_i, anc, col_i, eq_i, slot_st)

func _ensure_slot_cosmetic_layer(slot_idx: int, insert_after: Control) -> Control:
	while _slot_cosmetic_layers.size() < 8:
		_slot_cosmetic_layers.append(null)
	var layer: Control = _slot_cosmetic_layers[slot_idx]
	if layer == null:
		layer = Control.new()
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		if insert_after != null:
			move_child(layer, insert_after.get_index() + 1)
		_slot_cosmetic_layers[slot_idx] = layer
	return layer

func _hide_slot_cosmetics(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < _slot_cosmetic_layers.size() and is_instance_valid(_slot_cosmetic_layers[slot_idx]):
		_slot_cosmetic_layers[slot_idx].visible = false

func _update_slot_cosmetics(slot_idx: int, anchor: Vector2, team_col: Color, eq: Dictionary, insert_after: Control = null) -> void:
	var layer: Control = _ensure_slot_cosmetic_layer(slot_idx, insert_after)
	for ch in layer.get_children():
		ch.queue_free()
	layer.visible = true

	var char_deco: String = str(eq.get("char_deco", ""))
	if char_deco != "":
		var norm_cd := char_deco if char_deco.begins_with("CharDeco/") else "CharDeco/" + char_deco
		var cdf := SpriteDB.get_frame(norm_cd + "Down", 0)
		if cdf.is_empty():
			cdf = SpriteDB.get_frame(norm_cd, 0)
		if not cdf.is_empty():
			var tr := TextureRect.new()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.texture = cdf.texture
			tr.position = anchor - Vector2(cdf.offset)
			layer.add_child(tr)

	# AvatarDeco slots using exact 0xC37AE0 Display/Blink mapping (sheet_idx=1, frame=0+_room_blink_frame)
	for key: String in ["cloth", "face", "hat"]:
		var path: String = str(eq.get(key, ""))
		if path == "":
			continue
		var df := SpriteDB.get_avatar_deco_frame(path, 1, _room_blink_frame)
		if df.is_empty():
			continue
		if df.get("adjust_texture") != null:
			var tr_a := TextureRect.new()
			tr_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr_a.texture = df["adjust_texture"]
			tr_a.modulate = team_col
			tr_a.position = anchor - Vector2(df["adjust_offset"])
			layer.add_child(tr_a)
		if df.get("static_texture") != null:
			var tr_s := TextureRect.new()
			tr_s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr_s.texture = df["static_texture"]
			tr_s.position = anchor - Vector2(df["static_offset"])
			layer.add_child(tr_s)

func _on_network_room_updated(_data: Dictionary) -> void:
	if screen == "prepare":
		_update_room_slots()

func _init_prepare_slot_controls() -> void:
	# Add click-to-toggle (Empty -> Locked -> Bot -> Empty) hitboxes & lock overlays on slots 2..7
	var lock_f := SpriteDB.get_frame("Prepare/PRE_Bt_Slot-Open", 0)
	for slot_i in range(2, 8):
		var col: int = slot_i % 4
		var row: int = slot_i / 4
		var rx: float = 27.0 + float(col) * 106.0
		var ry: float = 94.0 + float(row) * 146.0
		var lock_img := TextureRect.new()
		lock_img.name = "Slot%dLockImg" % slot_i
		lock_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_img.visible = false
		if not lock_f.is_empty():
			lock_img.texture = lock_f.texture
			lock_img.position = Vector2(rx + (98.0 - lock_f.size.x) * 0.5, ry + (98.0 - lock_f.size.y) * 0.5)
		add_child(lock_img)

		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(rx, ry)
		btn.size = Vector2(98.0, 98.0)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var s_idx: int = slot_i
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("Bt_c_Click")
			Session.toggle_room_slot_state(s_idx)
			_update_room_slots()
		)
		add_child(btn)
	_update_room_slots()

func on_action(action: String) -> void:
	if action == "login_mode:1p":
		_set_login_2p(false)
	elif action == "login_mode:2p":
		_set_login_2p(true)
	elif action.begins_with("select_char:"):
		_apply_char_selection(int(action.substr(12)))
	elif action.begins_with("select_team:"):
		AudioManager.play_sfx("Bt_c_Click")
		_apply_team_selection(int(action.substr(12)))
	elif action == "login":
		var uid := ($user_id as LineEdit).text
		var pw := ($password as LineEdit).text
		var uid2 := ($user2_id as LineEdit).text
		var pw2 := ($password2 as LineEdit).text
		var two_p := _is_2p
		dialogs.open("login_wait", {
			"on_done": func():
				var r := AuthService.login(uid, pw, 1)
				if not r.ok:
					dialogs.show_notice(r.get("error", "Bạn đã nhập sai mật khẩu hoặc nhân vật này chưa đăng ký."))
					return
				Session.is_2p = two_p
				if two_p:
					var r2 := AuthService.login(uid2, pw2, 2)
					if not r2.ok:
						dialogs.show_notice(r2.get("error", "Đăng nhập Người chơi 2 thất bại."))
						return
					Session.user2_id = r2.user_id
					Session.nickname2 = r2.nickname
				else:
					Session.user2_id = ""
					Session.nickname2 = ""
				Session.goto("select_server")
		})
	elif action == "ch_game_mode:toggle":
		_ch_game_mode = "hc" if _ch_game_mode == "ca" else "ca"
		_ch_active_tab = "special" if _ch_game_mode == "hc" else "free"
		_ch_page = 1
		_refresh_select_server()
	elif action.begins_with("ch_banner:"):
		_ch_banner_idx = clampi(int(action.substr(10)), 1, _CH_BANNER_SLIDES.size())
		_refresh_select_server_banner()
	elif action.begins_with("ch_tab:"):
		_ch_active_tab = action.substr(7)
		_ch_page = 1
		_refresh_select_server()
	elif action.begins_with("ch_page:"):
		var pv := action.substr(8)
		if pv == "prev":
			_ch_page = maxi(1, _ch_page - 1)
		elif pv == "next":
			_ch_page += 1
		elif pv.is_valid_int():
			_ch_page = int(pv)
		_refresh_select_server()
	elif action.begins_with("ch_select:"):
		_on_select_channel_slot(int(action.substr(10)))
	elif action == "lobby:create_room":
		var flow = Session.get_lobby_flow()
		var route: Dictionary = flow.resolve_create_room_action(Session.selected_channel_id)
		if bool(route.get("disabled", false)):
			dialogs.show_notice("Kênh này không hỗ trợ tạo phòng thủ công.")
		elif bool(route.get("auto_create", false)):
			var comp_id: int = int(route.get("fixed_component_id", 0))
			var host_user := {"id": int(Session.user_id) if Session.user_id.is_valid_int() else 1, "nickname": Session.nickname if Session.nickname != "" else "Player", "level": Session.level, "selected_char": Session.selected_char, "team_color_idx": Session.team_color_idx}
			var created: Dictionary = flow.create_room(Session.selected_channel_id, str(route.get("title", "Room")), "", comp_id, Session.selected_map, host_user)
			Session.apply_room_to_session(created)
			Session.goto("prepare")
		else:
			dialogs.open(str(route.get("dialog", "create_room")))
	elif action == "lobby:show_all":
		Session.lobby_filter_component_id = -1
		_refresh_lobby_rooms()
	elif action == "lobby:cycle_mode_filter":
		var modes: Array[int] = Session.get_lobby_flow().get_channel_creatable_modes(Session.selected_channel_id)
		if modes.is_empty():
			Session.lobby_filter_component_id = -1
		else:
			var cur_idx: int = modes.find(Session.lobby_filter_component_id)
			Session.lobby_filter_component_id = -1 if cur_idx == modes.size() - 1 else modes[cur_idx + 1]
		_refresh_lobby_rooms()
	elif action.begins_with("lobby:join_slot:"):
		var slot_i := int(action.substr(16))
		var rooms: Array = Session.get_lobby_flow().get_rooms(Session.selected_channel_id, Session.lobby_filter_component_id)
		if slot_i >= 0 and slot_i < rooms.size():
			var room: Dictionary = rooms[slot_i]
			var rid: int = int(room.get("room_id", -1))
			var check: Dictionary = Session.get_lobby_flow().can_join_room(rid, "")
			if bool(check.get("ok", false)):
				Session.apply_room_to_session(room)
				Session.goto("prepare")
			elif bool(check.get("need_password", false)):
				dialogs.open("room_password", {"room_id": rid})
			else:
				dialogs.show_notice(str(check.get("error", "Không thể vào phòng.")))
	elif action.begins_with("lobby:room_info:"):
		var info_i := int(action.substr(16))
		var rooms: Array = Session.get_lobby_flow().get_rooms(Session.selected_channel_id, Session.lobby_filter_component_id)
		if info_i >= 0 and info_i < rooms.size():
			dialogs.open("lobby_room_info", {"room_id": int(rooms[info_i].get("room_id", -1))})
	elif action.begins_with("dialog:"):
		dialogs.open(action.substr(7))
	elif action == "goto:game_stage":
		# Original BnB rule: Room must contain at least 2 different teams to start
		if screen == "prepare":
			var p1_team: int = Session.team_color_idx
			var p2_team: int = Session.user2_team_color_idx
			if p1_team == p2_team:
				dialogs.show_notice("Phải có ít nhất 2 đội mới có thể bắt đầu trận đấu!")
				return
		if NetworkManager.is_host:
			NetworkManager.start_match()
		else:
			Session.goto("game_stage")
	elif action == "shop":
		Session.shop_return_scene = screen
		Session.goto("shop")
	elif action == "myitem":
		var dlg := CMyPageDlgClass.new()
		add_child(dlg)
		dlg.dialog_closed.connect(func() -> void:
			if screen == "prepare":
				_update_room_slots()
		)
	elif action.begins_with("goto:"):
		Session.goto(action.substr(5))
	elif action == "quit":
		get_tree().quit()
	else:
		dialogs.show_notice("Chức năng này chưa được hỗ trợ ở giai đoạn 1 (LAN Offline).")

func _init_select_server() -> void:
	_ch_bar_nodes.clear()
	_ch_new_nodes.clear()
	for i in range(8):
		var col_x: int = 428 if (i % 2) == 0 else 595
		var row_y: int = 278 + 56 * (i / 2)
		var lbl := get_node_or_null("ch_name_%d" % i) as Label
		if lbl:
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 2)
		var segs: Array = []
		for s in range(6):
			var seg := TextureRect.new()
			seg.position = Vector2(col_x + 17 + 22 * s, row_y + 34)
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seg.visible = false
			add_child(seg)
			segs.append(seg)
		_ch_bar_nodes.append(segs)
		var badge := TextureRect.new()
		badge.position = Vector2(col_x - 4, row_y - 2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nf := SpriteDB.get_frame("SelectServerStage/CH_Img_New", 0)
		if not nf.is_empty():
			badge.texture = nf.texture
		badge.visible = false
		add_child(badge)
		_ch_new_nodes.append(badge)
		var btn := get_node_or_null("ch_btn_%d" % i) as TextureButton
		if btn:
			btn.mouse_entered.connect(_show_channel_tooltip.bind(i))
			btn.mouse_exited.connect(_hide_channel_tooltip)
	_ch_tooltip_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.14, 0.34, 0.94)
	sb.border_color = Color(0.45, 0.78, 1.0, 0.95)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	_ch_tooltip_panel.add_theme_stylebox_override("panel", sb)
	_ch_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ch_tooltip_panel.visible = false
	_ch_tooltip_label = Label.new()
	_ch_tooltip_label.add_theme_font_size_override("font_size", 11)
	_ch_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_ch_tooltip_panel.add_child(_ch_tooltip_label)
	add_child(_ch_tooltip_panel)
	for lbl_id in ["ch_mode_title", "ch_banner_title", "ch_banner_body"]:
		var ml := get_node_or_null(lbl_id) as Label
		if ml:
			ml.add_theme_color_override("font_outline_color", Color.BLACK)
			ml.add_theme_constant_override("outline_size", 2)
	_refresh_select_server_banner()
	_refresh_select_server()

func _refresh_select_server_banner() -> void:
	var show_card: bool = _ch_banner_idx > 1
	var bg := get_node_or_null("ch_banner_bg") as CanvasItem
	if bg:
		bg.visible = show_card
	var idx: int = clampi(_ch_banner_idx - 1, 0, _CH_BANNER_SLIDES.size() - 1)
	var slide: Dictionary = _CH_BANNER_SLIDES[idx]
	var bt := get_node_or_null("ch_banner_title") as Label
	if bt:
		bt.visible = show_card
		bt.text = str(slide.get("title", ""))
	var bb := get_node_or_null("ch_banner_body") as Label
	if bb:
		bb.visible = show_card
		bb.text = str(slide.get("body", ""))
	for i in range(1, 6):
		var btn := get_node_or_null("ch_banner_%d" % i) as TextureButton
		if btn == null:
			continue
		var sp := "SelectServerStage/CH_Bt_BaNum%02d" % i
		var tex := SpriteDB.get_button_textures(sp, 3 if i == _ch_banner_idx else 0)
		for prop in tex.textures:
			btn.set(prop, tex.textures[prop])

func _refresh_select_server() -> void:
	var logo := get_node_or_null("ch_game_logo") as TextureRect
	if logo:
		var lf := SpriteDB.get_frame("SelectServerStage/CH_Logo_HC" if _ch_game_mode == "hc" else "SelectServerStage/CH_Logo_CA", 0)
		if not lf.is_empty():
			logo.texture = lf.texture
	var mtitle := get_node_or_null("ch_mode_title") as Label
	if mtitle:
		mtitle.text = "HIDDEN CATCH" if _ch_game_mode == "hc" else "BOOM ONLINE"
	var flow = Session.get_lobby_flow()
	var tabs: Array = flow.get_channel_tabs()
	if tabs.is_empty():
		return
	var active_tab_idx: int = 0
	var active_tab: Dictionary = tabs[0]
	for idx in tabs.size():
		if str((tabs[idx] as Dictionary).get("id", "")) == _ch_active_tab:
			active_tab_idx = idx
			active_tab = tabs[idx]
			break
	_ch_active_tab = str(active_tab.get("id", "free"))
	# Exact CA.exe tab layout (sub_858AB4 @ 0x858B6C..0x858B7B):
	# inactive width=71, active extra width=+33 (total 104), inactive y_offset=+25
	var tab_x: int = 404
	for idx in range(4):
		var tb := get_node_or_null("ch_tab_%d" % idx) as TextureButton
		if tb == null:
			continue
		if idx >= tabs.size():
			tb.visible = false
			continue
		tb.visible = true
		var is_active: bool = (idx == active_tab_idx)
		tb.position = Vector2(tab_x, 122 if is_active else 122)
		tab_x += 104 if is_active else 71
		var t: Dictionary = tabs[idx]
		var sp := str(t.get("tab_sprite", ""))
		var bt := SpriteDB.get_button_textures(sp, 3 if is_active else 0)
		for prop in bt.textures:
			tb.set(prop, bt.textures[prop])
	var balloon := get_node_or_null("ch_tab_balloon") as TextureRect
	if balloon:
		balloon.visible = false
	var bar_bg := get_node_or_null("ch_bar_bg") as TextureRect
	if bar_bg:
		var barf := SpriteDB.get_frame(str(active_tab.get("bar_sprite", "")), 0)
		if not barf.is_empty():
			bar_bg.texture = barf.texture
	var bar_desc := get_node_or_null("ch_bar_desc") as Label
	if bar_desc:
		bar_desc.text = str(active_tab.get("desc_vn", ""))
		bar_desc.add_theme_color_override("font_color", Color.html(str(active_tab.get("bar_text_color", "#222222"))))
	var page_info: Dictionary = flow.get_tab_channels_page(_ch_active_tab, _ch_page)
	_ch_page = int(page_info.get("page", 1))
	var total_pages: int = int(page_info.get("total_pages", 1))
	var chs: Array = page_info.get("channels", [])
	if _ch_game_mode == "hc":
		var hc_ch: Dictionary = flow.get_channel("ch_tk_01")
		chs = [hc_ch] if not hc_ch.is_empty() else []
		total_pages = 1
		_ch_page = 1
	for i in range(8):
		var btn := get_node_or_null("ch_btn_%d" % i) as TextureButton
		var lbl := get_node_or_null("ch_name_%d" % i) as Label
		var segs: Array = _ch_bar_nodes[i] if i < _ch_bar_nodes.size() else []
		var badge: TextureRect = _ch_new_nodes[i] if i < _ch_new_nodes.size() else null
		var has_ch: bool = i < chs.size()
		if btn: btn.visible = has_ch
		if lbl: lbl.visible = has_ch
		if not has_ch:
			for seg: TextureRect in segs:
				seg.visible = false
			if badge: badge.visible = false
			continue
		var ch: Dictionary = chs[i]
		var ctype: int = int(ch.get("channel_type", 0))
		var is_rpg: bool = (ctype == 130)
		if btn:
			var bsp := "SelectServerStage/RPG_CH_Bt_Channel" if is_rpg else "SelectServerStage/CH_Bt_Channel"
			var cbt := SpriteDB.get_button_textures(bsp, 0)
			for prop in cbt.textures:
				btn.set(prop, cbt.textures[prop])
		var check: Dictionary = flow.can_enter_channel(ch, Session.level, Session.grade)
		var ok: bool = bool(check.get("ok", true))
		if lbl:
			lbl.text = str(ch.get("code", ch.get("id", "")))
			# Exact CA.exe colors (sub_A44980): Yellow RGB(255,255,0) vs Gray RGB(196,196,196)
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0) if ok else Color(0.769, 0.769, 0.769))
		var bars: int = flow.calc_population_bars(int(ch.get("population", 0)), int(ch.get("max_population", 200)))
		var frame_off: int = flow.get_bar_frame_offset(ok)
		var bar_sp := "SelectServerStage/RPG_CH_Bar_User" if is_rpg else "SelectServerStage/CH_Bar_User"
		for s in range(segs.size()):
			var seg := segs[s] as TextureRect
			if s < bars:
				var sf := SpriteDB.get_frame(bar_sp, s + frame_off)
				if not sf.is_empty():
					seg.texture = sf.texture
					seg.visible = true
				else:
					seg.visible = false
			else:
				seg.visible = false
		if badge:
			badge.visible = flow.has_new_badge(ch)
	var pill := get_node_or_null("ch_page_pill") as TextureRect
	if pill:
		pill.position = Vector2(521 + (_ch_page - 1) * 30, 519)
	for p in range(1, 6):
		var pbtn := get_node_or_null("ch_page_%d" % p) as TextureButton
		if pbtn:
			var df := SpriteDB.get_frame("SelectServerStage/CH_Bt_ChNum", p)
			if not df.is_empty():
				pbtn.texture_normal = df.texture
				pbtn.texture_hover = df.texture
				pbtn.texture_pressed = df.texture
				pbtn.texture_disabled = df.texture
			pbtn.disabled = p > total_pages
			pbtn.modulate = Color.WHITE if p <= total_pages else Color(0.5, 0.5, 0.5, 0.6)

func _get_visible_channels() -> Array:
	var flow = Session.get_lobby_flow()
	if _ch_game_mode == "hc":
		var hc_ch: Dictionary = flow.get_channel("ch_tk_01")
		return [hc_ch] if not hc_ch.is_empty() else []
	return flow.get_tab_channels_page(_ch_active_tab, _ch_page).get("channels", [])

func _show_channel_tooltip(slot_idx: int) -> void:
	if _ch_tooltip_panel == null or _ch_tooltip_label == null:
		return
	var flow = Session.get_lobby_flow()
	var chs: Array = _get_visible_channels()
	if slot_idx < 0 or slot_idx >= chs.size():
		_ch_tooltip_panel.visible = false
		return
	var ch: Dictionary = chs[slot_idx]
	var check: Dictionary = flow.can_enter_channel(ch, Session.level, Session.grade)
	var tip: String = str(ch.get("tooltip_vn", ""))
	if not bool(check.get("ok", true)):
		var reason := str(check.get("reason", ""))
		tip = reason if tip == "" else "%s\n(%s)" % [tip, reason]
	if tip == "":
		_ch_tooltip_panel.visible = false
		return
	_ch_tooltip_label.text = tip
	_ch_tooltip_panel.reset_size()
	var col_x: int = 428 if (slot_idx % 2) == 0 else 595
	var row_y: int = 278 + 56 * (slot_idx / 2)
	_ch_tooltip_panel.position = Vector2(clampi(col_x, 404, 780 - int(_ch_tooltip_panel.size.x)), row_y - 30)
	_ch_tooltip_panel.visible = true

func _hide_channel_tooltip() -> void:
	if _ch_tooltip_panel:
		_ch_tooltip_panel.visible = false

func _on_select_channel_slot(slot_idx: int) -> void:
	var flow = Session.get_lobby_flow()
	var chs: Array = _get_visible_channels()
	if slot_idx < 0 or slot_idx >= chs.size():
		return
	var ch: Dictionary = chs[slot_idx]
	var check: Dictionary = flow.can_enter_channel(ch, Session.level, Session.grade)
	if not bool(check.get("ok", true)):
		dialogs.show_notice(str(check.get("reason", "Không thể vào kênh này.")))
		return
	Session.selected_channel_id = str(ch.get("id", "ch_td_01"))
	Session.lobby_filter_component_id = -1
	Session.goto("lobby")

func _refresh_lobby_rooms() -> void:
	var flow = Session.get_lobby_flow()
	var rooms: Array = flow.get_rooms(Session.selected_channel_id, Session.lobby_filter_component_id)
	for i in range(6):
		var slot_btn := get_node_or_null("room_slot_%d" % i) as CanvasItem
		var info_btn := get_node_or_null("room_info_%d" % i) as CanvasItem
		var num_lbl := get_node_or_null("room_num_%d" % i) as Label
		var title_lbl := get_node_or_null("room_title_%d" % i) as Label
		var state_lbl := get_node_or_null("room_state_%d" % i) as Label
		var count_lbl := get_node_or_null("room_count_%d" % i) as Label
		var has_room: bool = i < rooms.size()
		if slot_btn: slot_btn.visible = has_room
		if info_btn: info_btn.visible = has_room
		if num_lbl: num_lbl.visible = has_room
		if title_lbl: title_lbl.visible = has_room
		if state_lbl: state_lbl.visible = has_room
		if count_lbl: count_lbl.visible = has_room
		if not has_room:
			continue
		var r: Dictionary = rooms[i]
		if num_lbl: num_lbl.text = "%03d" % int(r.get("room_no", i + 1))
		if title_lbl:
			var lock_prefix := "[KHÓA] " if bool(r.get("locked", false)) else ""
			title_lbl.text = "%s%s" % [lock_prefix, str(r.get("title", ""))]
		if state_lbl: state_lbl.text = "WAITING" if str(r.get("status", "waiting")) == "waiting" else "PLAYING"
		if count_lbl: count_lbl.text = "%d/%d" % [flow.get_occupied_count(r), int(r.get("max_players", 8))]

func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.is_pressed():
		return
	var code := (ev as InputEventKey).keycode
	if code == KEY_ESCAPE and dialogs.has_open():
		dialogs.close_top()
		get_viewport().set_input_as_handled()
		return
	if code == KEY_F1:
		dialogs.open("tutorial")
		return
	if code == KEY_F10:
		dialogs.open("option")
		return
	if screen == "lobby" and code == KEY_M:
		Session.goto("map_view")
	elif screen == "game_stage" and code == KEY_ESCAPE:
		Session.goto("prepare")
