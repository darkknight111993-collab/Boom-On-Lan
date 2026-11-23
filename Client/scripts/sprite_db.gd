extends Node
# Loads decoded sprites from res://Assets/fx (read with Image.load, independent of editor import).

var root_fx: String = ProjectSettings.globalize_path("res://Assets/fx")
var root_charte: String = ProjectSettings.globalize_path("res://Assets/charte")
var root_emote: String = ProjectSettings.globalize_path("res://Assets/emote")
var root_fxasset: String = ProjectSettings.globalize_path("res://Assets/fxasset")
var root: String = root_fx
var _meta := {}
var _img_cache := {}
var _tex_cache := {}
var _btn_cache := {}
var _map_icon_cache := {}
var _char_frame_cache := {}
var _deco_frame_cache := {}

# 6 unique assets that exist only inside charte/IDDX/<pack>/entry_XX (verified from 0x99FEAA / 0xA388C0)
const IDDX_FALLBACK := {
	"AvatarDeco/A06_20_0007_0LayerAdjust": "IDDX/A06_20_0007/entry_00",
	"AvatarDeco/A06_20_0007_0LayerStatic": "IDDX/A06_20_0007/entry_01",
	"AvatarDeco/A06_20_0007_1LayerAdjust": "IDDX/A06_20_0007/entry_02",
	"AvatarDeco/A06_20_0007_1LayerStatic": "IDDX/A06_20_0007/entry_03",
	"AvatarDeco/A06_30_0004_0LayerStatic": "IDDX/A06_30_0004/entry_00",
	"AvatarDeco/A06_30_0004_1LayerStatic": "IDDX/A06_30_0004/entry_01",
	"AvatarDeco/A06_41_0002_0LayerAdjust": "IDDX/A06_41_0002/entry_00",
	"AvatarDeco/A06_41_0002_0LayerStatic": "IDDX/A06_41_0002/entry_01",
	"AvatarDeco/A06_41_0002_1LayerAdjust": "IDDX/A06_41_0002/entry_02",
	"AvatarDeco/A06_41_0002_1LayerStatic": "IDDX/A06_41_0002/entry_03",
	"AvatarDeco/A06_50_0002_0LayerStatic": "IDDX/A06_50_0002/entry_00",
	"AvatarDeco/A06_50_0002_1LayerStatic": "IDDX/A06_50_0002/entry_01",
	"Icon/A06_10_0001icon": "IDDX/IconA06_10_0001icon/entry_00",
	"Icon/A10_10_0001icon": "IDDX/IconA10_10_0001icon/entry_00",
}

func resolve_sprite_dir(sprite_path: String) -> String:
	if IDDX_FALLBACK.has(sprite_path):
		return root_charte.path_join(str(IDDX_FALLBACK[sprite_path]))
	if sprite_path.begins_with("charte/"):
		var sub := sprite_path.substr(7)
		if IDDX_FALLBACK.has(sub):
			return root_charte.path_join(str(IDDX_FALLBACK[sub]))
		return root_charte.path_join(sub)
	if sprite_path.begins_with("emote/"):
		return root_emote.path_join(sprite_path.substr(6))
	if sprite_path.begins_with("fxasset/"):
		return root_fxasset.path_join(sprite_path.substr(8))
	if sprite_path.begins_with("fx/"):
		return root_fx.path_join(sprite_path.substr(3))
	if sprite_path.begins_with("BombDeco/") or sprite_path.begins_with("AvatarDeco/") or sprite_path.begins_with("CharDeco/"):
		return root_charte.path_join(sprite_path)
	if sprite_path.begins_with("IDDeco/") or sprite_path.begins_with("Fanfare/"):
		return root_emote.path_join(sprite_path)
	if FileAccess.file_exists(root_charte.path_join(sprite_path).path_join("sprite.json")):
		return root_charte.path_join(sprite_path)
	if FileAccess.file_exists(root_emote.path_join(sprite_path).path_join("sprite.json")):
		return root_emote.path_join(sprite_path)
	return root_fx.path_join(sprite_path)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _sprite(sprite_path: String) -> Variant:
	if not _meta.has(sprite_path):
		var dir := resolve_sprite_dir(sprite_path)
		_meta[sprite_path] = _read_json(dir.path_join("sprite.json"))
	return _meta[sprite_path]

func _image(file: String) -> Image:
	if not _img_cache.has(file):
		_img_cache[file] = Image.load_from_file(file) if FileAccess.file_exists(file) else null
	return _img_cache[file]

func _texture(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		var img := _image(file)
		_tex_cache[file] = ImageTexture.create_from_image(img) if img else null
	return _tex_cache[file]

# Returns {texture, image, offset, canvas_size, pivot, size} or {} when frame has no image.
# CA.exe (CRenderD3D9::sub_68B7A0) draws every logical image at: draw_pos = anchor - offset.
func get_frame(sprite_path: String, idx: int) -> Dictionary:
	var m: Variant = _sprite(sprite_path)
	if m == null or idx < 0 or idx >= m.frames.size():
		return {}
	var f: Dictionary = m.frames[idx]
	if f.get("file") == null:
		return {}
	var dir := resolve_sprite_dir(sprite_path)
	var file: String = dir.path_join(f.file)
	var tex := _texture(file)
	if tex == null:
		return {}
	var extra: Array = f.get("extra", [tex.get_width(), tex.get_height(), 0, 0])
	return {
		"texture": tex,
		"image": _image(file),
		"offset": Vector2(f.offset[0], f.offset[1]),
		"canvas_size": Vector2(extra[0], extra[1]),
		"pivot": Vector2(extra[2], extra[3]),
		"size": Vector2(tex.get_width(), tex.get_height()),
	}

# Pads CCtrlButton states (sub_6A43F0: 0=normal, 1=pressed, 2=disabled, 3=hover) into a shared
# bounding box so TextureButton switches states with 0px position jitter.
func get_button_textures(sprite_path: String, normal_idx: int = 0) -> Dictionary:
	var key := "%s#%d" % [sprite_path, normal_idx]
	if _btn_cache.has(key):
		return _btn_cache[key]
	var state_map := {
		"texture_normal": normal_idx,
		"texture_pressed": 1,
		"texture_disabled": 2,
		"texture_hover": 3,
	}
	var frames := {}
	for prop in state_map:
		var f := get_frame(sprite_path, state_map[prop])
		if not f.is_empty():
			frames[prop] = f
	if not frames.has("texture_normal"):
		_btn_cache[key] = {}
		return {}

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for prop in frames:
		var f: Dictionary = frames[prop]
		var lx: float = -f.offset.x
		var ly: float = -f.offset.y
		min_x = minf(min_x, lx)
		min_y = minf(min_y, ly)
		max_x = maxf(max_x, lx + f.size.x)
		max_y = maxf(max_y, ly + f.size.y)

	var bw := int(max_x - min_x)
	var bh := int(max_y - min_y)
	var out_tex := {}
	for prop in frames:
		var f: Dictionary = frames[prop]
		var dx := int(-f.offset.x - min_x)
		var dy := int(-f.offset.y - min_y)
		if dx == 0 and dy == 0 and int(f.size.x) == bw and int(f.size.y) == bh:
			out_tex[prop] = f.texture
		else:
			var canvas := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
			var src: Image = f.image
			if src.get_format() != Image.FORMAT_RGBA8:
				src = src.duplicate()
				src.convert(Image.FORMAT_RGBA8)
			canvas.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(dx, dy))
			out_tex[prop] = ImageTexture.create_from_image(canvas)

	var res := {"origin": Vector2(min_x, min_y), "textures": out_tex}
	_btn_cache[key] = res
	return res

# Full-screen backgrounds are stored as <path>/image.jpg.
func get_jpg(sprite_path: String) -> Texture2D:
	return _texture(root.path_join(sprite_path).path_join("image.jpg"))

# Original 148x128 minimap preview at Assets/fx/Etc/<map_name>_mm
func get_map_minimap(map_name: String) -> Texture2D:
	var f := get_frame("Etc/%s_mm" % map_name, 0)
	return f.texture if not f.is_empty() else null

# Cached small thumbnail icon for map list rows (lazy-loaded on demand).
func get_map_icon(map_name: String, icon_size := Vector2i(24, 21)) -> Texture2D:
	if _map_icon_cache.has(map_name):
		return _map_icon_cache[map_name]
	var f := get_frame("Etc/%s_mm" % map_name, 0)
	if f.is_empty() or f.image == null:
		_map_icon_cache[map_name] = null
		return null
	var img: Image = (f.image as Image).duplicate()
	img.resize(icon_size.x, icon_size.y, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_map_icon_cache[map_name] = tex
	return tex

# Multi-layer character composite frame (handles A/B/C static & adjust layers seamlessly)
func get_character_frame(char_prefix: String, action: String = "WalkDown", frame: int = 0) -> Dictionary:
	if char_prefix.begins_with("Character/"):
		char_prefix = char_prefix.substr(10)
	var key := "%s#%s#%d" % [char_prefix, action, frame]
	if _char_frame_cache.has(key):
		return _char_frame_cache[key]

	var adjust_frames: Array = []
	var static_frames: Array = []
	var cw := 0
	var ch := 0
	var pivot := Vector2.ZERO

	if action == "Die" or action == "Faint":
		var af := get_frame("Character/%s-%sLayerAdjust" % [char_prefix, action], frame)
		if not af.is_empty():
			adjust_frames.append(af)
			if cw == 0 and af.has("canvas_size"):
				cw = int(af.canvas_size.x)
				ch = int(af.canvas_size.y)
				pivot = af.pivot
		var sf := get_frame("Character/%s-%sLayerStatic" % [char_prefix, action], frame)
		if not sf.is_empty():
			static_frames.append(sf)
			if cw == 0 and sf.has("canvas_size"):
				cw = int(sf.canvas_size.x)
				ch = int(sf.canvas_size.y)
				pivot = sf.pivot
	else:
		var adjust_layer_names := ["BLayerAdjust", "CLayerAdjust", "ALayerAdjust"]
		var static_layer_names := ["BLayerStatic", "CLayerStatic", "ALayerStatic"]

		for l_name in adjust_layer_names:
			var sp := "Character/%s-%s_%s" % [char_prefix, action, l_name]
			var f := get_frame(sp, frame)
			if f.is_empty() and action != "WalkDown":
				f = get_frame("Character/%s-WalkDown_%s" % [char_prefix, l_name], 0)
			if not f.is_empty():
				adjust_frames.append(f)
				if cw == 0 and f.has("canvas_size"):
					cw = int(f.canvas_size.x)
					ch = int(f.canvas_size.y)
					pivot = f.pivot

		for l_name in static_layer_names:
			var sp := "Character/%s-%s_%s" % [char_prefix, action, l_name]
			var f := get_frame(sp, frame)
			if f.is_empty() and action != "WalkDown":
				f = get_frame("Character/%s-WalkDown_%s" % [char_prefix, l_name], 0)
			if not f.is_empty():
				static_frames.append(f)
				if cw == 0 and f.has("canvas_size"):
					cw = int(f.canvas_size.x)
					ch = int(f.canvas_size.y)
					pivot = f.pivot

	if adjust_frames.is_empty() and static_frames.is_empty():
		return {}

	if cw <= 0 or ch <= 0:
		cw = 66
		ch = 76
		pivot = Vector2(13, 75)

	var adj_canvas: Image = null
	if not adjust_frames.is_empty():
		adj_canvas = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		for af: Dictionary in adjust_frames:
			var src: Image = af.get("image")
			if src != null:
				if src.get_format() != Image.FORMAT_RGBA8:
					src = src.duplicate()
					src.convert(Image.FORMAT_RGBA8)
				var dx: int = int(pivot.x - af.offset.x)
				var dy: int = int(pivot.y - af.offset.y)
				adj_canvas.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(dx, dy))

		# In BnB, ALayerAdjust assets are authored in red. Normalize to grayscale luminance
		# so Godot's modulate cleanly and accurately applies any team color (Red, Blue, Yellow, Green, etc.)
		for y in adj_canvas.get_height():
			for x in adj_canvas.get_width():
				var col := adj_canvas.get_pixel(x, y)
				if col.a > 0.001:
					var lum: float = maxf(col.r, maxf(col.g, col.b))
					adj_canvas.set_pixel(x, y, Color(lum, lum, lum, col.a))

	var st_canvas: Image = null
	if not static_frames.is_empty():
		st_canvas = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		for sf: Dictionary in static_frames:
			var src: Image = sf.get("image")
			if src != null:
				if src.get_format() != Image.FORMAT_RGBA8:
					src = src.duplicate()
					src.convert(Image.FORMAT_RGBA8)
				var dx: int = int(pivot.x - sf.offset.x)
				var dy: int = int(pivot.y - sf.offset.y)
				st_canvas.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(dx, dy))

	var res := {
		"adjust_texture": ImageTexture.create_from_image(adj_canvas) if adj_canvas != null else null,
		"static_texture": ImageTexture.create_from_image(st_canvas) if st_canvas != null else null,
		"offset": pivot,
		"canvas_size": Vector2(cw, ch),
	}
	_char_frame_cache[key] = res
	return res

# AvatarDeco single-slot frame (sheet_idx 0 or 1, 44-frame pose sheet, LayerAdjust normalized for team modulate)
func get_avatar_deco_frame(deco_base: String, sheet_idx: int, frame_idx: int) -> Dictionary:
	var norm_base := deco_base if deco_base.begins_with("AvatarDeco/") else "AvatarDeco/" + deco_base
	var key := "%s#%d#%d" % [norm_base, sheet_idx, frame_idx]
	if _deco_frame_cache.has(key):
		return _deco_frame_cache[key]

	var af: Dictionary = get_frame("%s_%dLayerAdjust" % [norm_base, sheet_idx], frame_idx)
	var sf: Dictionary = get_frame("%s_%dLayerStatic" % [norm_base, sheet_idx], frame_idx)
	if af.is_empty() and sf.is_empty():
		_deco_frame_cache[key] = {}
		return {}

	var adj_tex: Texture2D = null
	var adj_off: Vector2 = Vector2.ZERO
	if not af.is_empty() and af.get("image") != null:
		var src: Image = (af.get("image") as Image).duplicate()
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)
		for y in src.get_height():
			for x in src.get_width():
				var col := src.get_pixel(x, y)
				if col.a > 0.001:
					var lum: float = maxf(col.r, maxf(col.g, col.b))
					src.set_pixel(x, y, Color(lum, lum, lum, col.a))
		adj_tex = ImageTexture.create_from_image(src)
		adj_off = af.offset

	var res := {
		"adjust_texture": adj_tex,
		"adjust_offset": adj_off,
		"static_texture": sf.texture if not sf.is_empty() else null,
		"static_offset": sf.offset if not sf.is_empty() else Vector2.ZERO,
	}
	_deco_frame_cache[key] = res
	return res
