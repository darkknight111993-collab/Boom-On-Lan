extends Node

var _player: AudioStreamPlayer
var _current_bgm := ""
var _cache := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _sfx_cache := {}
var _loop_players: Dictionary = {} # key -> {player: AudioStreamPlayer, sfx: String}
var bgm_volume := 1.0
var sfx_volume := 1.0

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	if _player:
		_player.volume_db = linear_to_db(bgm_volume) if bgm_volume > 0.001 else -80.0

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var db := linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0
	for p in _sfx_players:
		p.volume_db = db
	for entry in _loop_players.values():
		var lp: AudioStreamPlayer = entry.player
		if is_instance_valid(lp):
			lp.volume_db = db

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

func play_bgm(bgm_name: String) -> void:
	if _current_bgm == bgm_name and _player.playing:
		return
	_current_bgm = bgm_name
	if bgm_name == "":
		_player.stop()
		return

	var stream: AudioStreamOggVorbis = _cache.get(bgm_name)
	if stream == null:
		var clean := bgm_name
		if clean.to_lower().begins_with("mp3/"):
			clean = clean.substr(4)
		var file_path := SpriteDB.root.path_join("MP3").path_join(clean).path_join("sound.ogg")
		if not FileAccess.file_exists(file_path):
			push_warning("BGM file not found: %s" % file_path)
			return
		stream = AudioStreamOggVorbis.load_from_file(file_path)
		if stream:
			stream.loop = true
			_cache[bgm_name] = stream

	if stream:
		_player.stream = stream
		_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	_player.stop()

func play_sfx(sfx_name: String) -> void:
	if sfx_name == "":
		return
	var clean := sfx_name
	if clean.to_lower().begins_with("wave/"):
		clean = clean.substr(5)
	var stream: AudioStreamOggVorbis = _sfx_cache.get(clean)
	if stream == null:
		var file_path := SpriteDB.root.path_join("Wave").path_join(clean).path_join("sound.ogg")
		if not FileAccess.file_exists(file_path):
			push_warning("SFX file not found: %s" % file_path)
			return
		stream = AudioStreamOggVorbis.load_from_file(file_path)
		if stream:
			stream.loop = false
			_sfx_cache[clean] = stream

	if stream and not _sfx_players.is_empty():
		var p := _sfx_players[_sfx_idx]
		_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
		p.stream = stream
		p.play()

func play_loop_sfx(key: String, sfx_name: String) -> void:
	if key == "" or sfx_name == "":
		return
	var clean := sfx_name
	if clean.to_lower().begins_with("wave/"):
		clean = clean.substr(5)
	if _loop_players.has(key):
		var cur: Dictionary = _loop_players[key]
		var lp: AudioStreamPlayer = cur.player
		if is_instance_valid(lp) and cur.sfx == clean and lp.playing:
			return
	var file_path := SpriteDB.root.path_join("Wave").path_join(clean).path_join("sound.ogg")
	if not FileAccess.file_exists(file_path):
		return
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(file_path)
	if stream == null:
		return
	stream.loop = true
	var lp: AudioStreamPlayer
	if _loop_players.has(key) and is_instance_valid(_loop_players[key].player):
		lp = _loop_players[key].player
	else:
		lp = AudioStreamPlayer.new()
		lp.bus = "Master"
		lp.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0
		add_child(lp)
	lp.stream = stream
	lp.play()
	_loop_players[key] = {"player": lp, "sfx": clean}

func stop_loop_sfx(key: String) -> void:
	if not _loop_players.has(key):
		return
	var lp: AudioStreamPlayer = _loop_players[key].player
	if is_instance_valid(lp):
		lp.stop()
