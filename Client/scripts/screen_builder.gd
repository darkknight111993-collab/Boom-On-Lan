class_name ScreenBuilder
# Builds a screen or dialog from JSON. Element: {kind, sprite?, x, y, action?, text?, ...}
# kinds: jpg, image, button, text_button, edit, label, color_rect, checkbox, slider, item_list.
# CA.exe (CRenderD3D9::sub_68B7A0) draws every logical image at anchor - offset.

static func build(root: Control, data: Dictionary, handler: Object = null) -> void:
	var target: Object = handler if handler != null else root
	for e: Dictionary in data.elements:
		var pos := Vector2(e.x, e.y)
		match e.kind:
			"jpg":
				var bg := TextureRect.new()
				bg.texture = SpriteDB.get_jpg(e.sprite)
				bg.position = pos
				root.add_child(bg)
			"color_rect":
				var cr := ColorRect.new()
				cr.position = pos
				cr.size = Vector2(e.w, e.h)
				cr.color = Color.from_string(e.get("color", "#003875"), Color(0, 0.22, 0.46, 1.0))
				if e.has("id"):
					cr.name = e.id
				root.add_child(cr)
			"image":
				var f := SpriteDB.get_frame(e.sprite, e.get("frame", 0))
				if f.is_empty():
					continue
				var img := TextureRect.new()
				img.texture = f.texture
				img.position = pos - f.offset
				if e.has("id"):
					img.name = e.id
				root.add_child(img)
			"button":
				# CCtrlButton::sub_6A43F0: 0=normal, 1=pressed, 2=disabled, 3=hover (padded for 0px jitter)
				var bt := SpriteDB.get_button_textures(e.sprite, e.get("frame", 0))
				if bt.is_empty():
					continue
				var b := TextureButton.new()
				b.focus_mode = Control.FOCUS_NONE
				for prop in bt.textures:
					b.set(prop, bt.textures[prop])
				if e.has("id"):
					b.name = e.id
				b.position = pos + bt.origin
				if e.get("disabled", false):
					b.disabled = true
				if e.has("text") and e.text != "":
					var lbl := Label.new()
					lbl.text = e.text
					lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					lbl.add_theme_font_size_override("font_size", e.get("font_size", 12))
					lbl.add_theme_color_override("font_color", Color.from_string(e.get("font_color", "#ffffff"), Color.WHITE))
					lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					b.add_child(lbl)
				var action: String = e.get("action", "unsupported")
				var hover_sfx: String = e.get("sfx_hover", _default_hover_sfx(e))
				var click_sfx: String = e.get("sfx_click", _default_click_sfx(e))
				if hover_sfx != "":
					b.mouse_entered.connect(func(): if not b.disabled: AudioManager.play_sfx(hover_sfx))
				if click_sfx != "":
					b.pressed.connect(func(): AudioManager.play_sfx(click_sfx))
				b.pressed.connect(target.call.bind("on_action", action))
				root.add_child(b)
			"text_button":
				var tb := Button.new()
				tb.focus_mode = Control.FOCUS_NONE
				if e.has("id"):
					tb.name = e.id
				tb.position = pos
				tb.size = Vector2(e.w, e.h)
				tb.text = e.get("text", "")
				tb.flat = true
				tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
				tb.add_theme_font_size_override("font_size", e.get("font_size", 11))
				tb.add_theme_color_override("font_color", Color.from_string(e.get("font_color", "#ffffff"), Color.WHITE))
				tb.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.5))
				var action: String = e.get("action", "unsupported")
				tb.mouse_entered.connect(func(): AudioManager.play_sfx("Bt_r_Default"))
				tb.pressed.connect(func(): AudioManager.play_sfx("Bt_p_Default"))
				tb.pressed.connect(target.call.bind("on_action", action))
				root.add_child(tb)
			"edit":
				var le := LineEdit.new()
				le.name = e.id
				le.position = pos
				le.secret = e.get("secret", false)
				le.placeholder_text = ""
				le.visible = e.get("visible", true)
				le.clip_contents = true
				var sb := StyleBoxEmpty.new()
				sb.content_margin_left = 3.0
				sb.content_margin_right = 2.0
				sb.content_margin_top = 0.0
				sb.content_margin_bottom = 0.0
				le.add_theme_stylebox_override("normal", sb)
				le.add_theme_stylebox_override("focus", sb)
				le.add_theme_stylebox_override("read_only", sb)
				le.add_theme_constant_override("minimum_character_width", 0)
				le.add_theme_font_size_override("font_size", e.get("font_size", 11))
				le.add_theme_color_override("font_color", Color.from_string(e.get("font_color", "#000000"), Color.BLACK))
				le.add_theme_color_override("caret_color", Color.from_string(e.get("font_color", "#000000"), Color.BLACK))
				root.add_child(le)
				# Set size once in tree so theme min height (16px) replaces default 31px
				if le.is_inside_tree():
					le.size = Vector2(e.w, e.h)
				else:
					le.tree_entered.connect(func(): le.size = Vector2(e.w, e.h), CONNECT_ONE_SHOT)
			"label":
				var l := Label.new()
				if e.has("id"):
					l.name = e.id
				l.position = pos
				if e.get("wrap", false):
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.clip_text = true
					l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if e.has("font_size"):
					l.add_theme_font_size_override("font_size", e.font_size)
				if e.has("font_color"):
					l.add_theme_color_override("font_color", Color.from_string(e.font_color, Color.WHITE))
				l.text = e.text
				root.add_child(l)
				if e.has("w") and e.has("h"):
					var box := Vector2(e.w, e.h)
					l.custom_minimum_size = box
					l.size = box
					if not l.is_inside_tree():
						l.tree_entered.connect(func(): l.size = box, CONNECT_ONE_SHOT)
			"checkbox":
				var cb := CheckBox.new()
				if e.has("id"):
					cb.name = e.id
				cb.position = pos
				cb.button_pressed = e.get("checked", false)
				cb.scale = Vector2(0.8, 0.8)
				root.add_child(cb)
			"slider":
				var sl := HSlider.new()
				if e.has("id"):
					sl.name = e.id
				sl.position = pos
				sl.size = Vector2(e.w, e.h)
				sl.min_value = 0.0
				sl.max_value = 1.0
				sl.step = 0.05
				sl.value = e.get("value", 1.0)
				root.add_child(sl)
			"item_list":
				var il := ItemList.new()
				if e.has("id"):
					il.name = e.id
				il.position = pos
				il.size = Vector2(e.w, e.h)
				il.fixed_icon_size = Vector2i(24, 21)
				il.allow_reselect = true
				il.mouse_filter = Control.MOUSE_FILTER_STOP
				il.add_theme_font_size_override("font_size", 12)
				il.add_theme_color_override("font_color", Color.WHITE)
				il.add_theme_color_override("font_selected_color", Color(1.0, 0.95, 0.4))
				il.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
				var sel_sb := StyleBoxFlat.new()
				sel_sb.bg_color = Color(0.08, 0.48, 0.85, 0.75)
				il.add_theme_stylebox_override("selected", sel_sb)
				il.add_theme_stylebox_override("selected_focus", sel_sb)
				var vsb := il.get_v_scroll_bar()
				vsb.custom_minimum_size.x = 14
				_style_scrollbar(vsb)
				il.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed:
						if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
							vsb.value += 48.0
							il.accept_event()
						elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
							vsb.value -= 48.0
							il.accept_event()
				)
				root.add_child(il)
			"mode_strip":
				var sc := ScrollContainer.new()
				if e.has("id"):
					sc.name = e.id
				sc.position = pos
				sc.size = Vector2(e.w, e.h)
				sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
				_style_scrollbar(sc.get_h_scroll_bar())
				var hbox := HBoxContainer.new()
				hbox.name = "Cards"
				hbox.add_theme_constant_override("separation", 3)
				for m: Dictionary in e.modes:
					var bt := SpriteDB.get_button_textures(m.sprite, 0)
					if bt.is_empty():
						continue
					var btn := TextureButton.new()
					btn.focus_mode = Control.FOCUS_NONE
					btn.name = "mode_" + str(m.id)
					btn.set_meta("mode_id", str(m.id))
					btn.set_meta("mode_sprite", str(m.sprite))
					btn.set_meta("mode_label", str(m.label))
					for prop in bt.textures:
						btn.set(prop, bt.textures[prop])
					btn.tooltip_text = str(m.label)
					btn.mouse_entered.connect(func(): AudioManager.play_sfx("Bt_r_Default"))
					btn.pressed.connect(func(): AudioManager.play_sfx("Bt_p_Default"))
					btn.pressed.connect(target.call.bind("on_action", "dialog:select_mode:" + str(m.id)))
					# Clickable 4 sub-mode buttons inside KIỂU CHƠI card (Gametype_bt01: 4 frames from y=44, step 34)
					if m.has("sub_icons"):
						var subs: Array = m.sub_icons
						for si in subs.size():
							var sub: Dictionary = subs[si]
							var sub_id: String = str(sub.get("id", m.id))
							var sub_label: String = str(sub.get("label", sub_id))
							var sbtn := Button.new()
							sbtn.name = "sub_" + sub_id
							sbtn.focus_mode = Control.FOCUS_NONE
							sbtn.flat = true
							sbtn.position = Vector2(10, 44 + si * 34)
							sbtn.size = Vector2(120, 30)
							sbtn.set_meta("mode_id", sub_id)
							sbtn.set_meta("mode_label", "Kiểu Chơi - %s" % sub_label)
							sbtn.set_meta("component_id", int(sub.get("component_id", 0)))
							sbtn.mouse_entered.connect(func(): AudioManager.play_sfx("Bt_r_Default"))
							sbtn.pressed.connect(func(): AudioManager.play_sfx("Bt_p_Default"))
							sbtn.pressed.connect(target.call.bind("on_action", "dialog:select_mode:" + sub_id))
							var sf := SpriteDB.get_frame(sub.sprite, 0)
							if not sf.is_empty():
								var ic := TextureRect.new()
								ic.texture = sf.texture
								ic.position = Vector2(4, 3)
								ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
								sbtn.add_child(ic)
							var slbl := Label.new()
							slbl.name = "Label"
							slbl.text = sub_label
							slbl.position = Vector2(34, 6)
							slbl.add_theme_font_size_override("font_size", 11)
							slbl.add_theme_color_override("font_color", Color.WHITE)
							slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
							sbtn.add_child(slbl)
							btn.add_child(sbtn)
					hbox.add_child(btn)
				sc.add_child(hbox)
				sc.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed:
						if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
							sc.scroll_horizontal += 146
							sc.accept_event()
						elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
							sc.scroll_horizontal -= 146
							sc.accept_event()
				)
				root.add_child(sc)
				# Left / Right scroll buttons for wide mode strips
				var b_left := Button.new()
				b_left.text = "<"
				b_left.focus_mode = Control.FOCUS_NONE
				b_left.position = Vector2(pos.x - 18, pos.y + e.h * 0.5 - 14)
				b_left.size = Vector2(18, 28)
				b_left.pressed.connect(func(): sc.scroll_horizontal = maxi(sc.scroll_horizontal - 146, 0))
				root.add_child(b_left)
				var b_right := Button.new()
				b_right.text = ">"
				b_right.focus_mode = Control.FOCUS_NONE
				b_right.position = Vector2(pos.x + e.w, pos.y + e.h * 0.5 - 14)
				b_right.size = Vector2(18, 28)
				b_right.pressed.connect(func(): sc.scroll_horizontal += 146)
				root.add_child(b_right)

static func _style_scrollbar(sb: ScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.2, 0.45, 0.85)
	track.set_corner_radius_all(3)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.18, 0.72, 1.0, 0.95)
	grab.set_corner_radius_all(3)
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color(0.45, 0.88, 1.0, 1.0)
	grab_hi.set_corner_radius_all(3)
	sb.add_theme_stylebox_override("scroll", track)
	sb.add_theme_stylebox_override("grabber", grab)
	sb.add_theme_stylebox_override("grabber_highlight", grab_hi)
	sb.add_theme_stylebox_override("grabber_pressed", grab_hi)

static func _default_hover_sfx(e: Dictionary) -> String:
	var sp: String = e.get("sprite", "").to_lower()
	var act: String = e.get("action", "").to_lower()
	if act == "quit" or "exit" in sp or "out" in sp:
		return "Bt_r_Out"
	if "channel" in sp:
		return "Bt_r_List"
	return "Bt_r_Default"

static func _default_click_sfx(e: Dictionary) -> String:
	var sp: String = e.get("sprite", "").to_lower()
	var act: String = e.get("action", "").to_lower()
	if act == "quit" or "exit" in sp or "out" in sp:
		return "Bt_c_Out"
	if act == "login" or "btlogok" in sp or "btok" in sp:
		return "Bt_c_Success"
	if "speaker" in sp or "ignore" in sp or "pop" in sp:
		return "Bt_c_Pop"
	if "cancle" in sp or "cancel" in sp or "close" in sp:
		return "Bt_c_Cancle"
	return "Bt_p_Default"
