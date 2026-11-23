extends Node
# LAN Discovery & Multiplayer Manager (GAME_PLAN.md §4)
# - UDP Broadcast discovery on port 42424
# - Server-Authoritative ENetMultiplayerPeer on port 42425

const DISCOVERY_PORT := 42424
const GAME_PORT := 42425
const BROADCAST_INTERVAL := 1.0

signal server_discovered(info: Dictionary)
signal player_connected_to_room(id: int, info: Dictionary)
signal player_disconnected_from_room(id: int)
signal room_updated(room_data: Dictionary)
signal match_started()

var is_host := false
var is_connected_to_server := false
var discovered_servers: Array[Dictionary] = []

var _udp_peer: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _listen_active := false

var _peer: ENetMultiplayerPeer
var _connected_peers := {} # peer_id -> { nickname, char, ready, slot }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	start_discovery_listener()

func _process(delta: float) -> void:
	_poll_discovery(delta)

# -------------------------------------------------------------------------
# LAN DISCOVERY (UDP BROADCAST)
# -------------------------------------------------------------------------

func start_discovery_listener() -> void:
	if _udp_peer == null:
		_udp_peer = PacketPeerUDP.new()
	if not _listen_active:
		var err := _udp_peer.bind(DISCOVERY_PORT)
		if err == OK:
			_listen_active = true
		else:
			push_warning("LAN discovery bind failed on port %d: %d" % [DISCOVERY_PORT, err])

func _poll_discovery(delta: float) -> void:
	if is_host:
		_broadcast_timer += delta
		if _broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_timer = 0.0
			_send_broadcast()

	if _listen_active and _udp_peer and _udp_peer.get_available_packet_count() > 0:
		while _udp_peer.get_available_packet_count() > 0:
			var pkt := _udp_peer.get_packet()
			var sender_ip := _udp_peer.get_packet_ip()
			var txt := pkt.get_string_from_utf8()
			var parsed = JSON.parse_string(txt)
			if parsed is Dictionary and parsed.has("server_name"):
				parsed["host_ip"] = sender_ip
				_handle_discovered_server(parsed)

func _send_broadcast() -> void:
	var b_peer := PacketPeerUDP.new()
	b_peer.set_broadcast_enabled(true)
	b_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	var data := {
		"server_name": Session.room_title if Session.room_title != "" else "BnB LAN Server",
		"host_nickname": Session.nickname if Session.nickname != "" else "Host",
		"port": GAME_PORT,
		"players_online": _connected_peers.size() + 1,
		"max_players": 8,
		"selected_map": Session.selected_map,
		"mode": Session.game_mode,
	}
	var msg := JSON.stringify(data)
	b_peer.put_packet(msg.to_utf8_buffer())
	b_peer.close()

func _handle_discovered_server(info: Dictionary) -> void:
	for i in discovered_servers.size():
		if discovered_servers[i].host_ip == info.host_ip:
			discovered_servers[i] = info
			server_discovered.emit(info)
			return
	discovered_servers.append(info)
	server_discovered.emit(info)

# -------------------------------------------------------------------------
# MULTIPLAYER PEER (ENET)
# -------------------------------------------------------------------------

func host_room(port := GAME_PORT) -> Error:
	disconnect_game()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, 8)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = true
	is_connected_to_server = true
	_connected_peers.clear()
	_connected_peers[1] = {
		"nickname": Session.nickname if Session.nickname != "" else "Host",
		"char": Session.selected_char,
		"team_color_idx": Session.team_color_idx,
		"cosmetics": Session.get_room_slot_cosmetics(0),
		"slot": 0,
		"ready": true,
	}
	return OK

func join_room(host_ip: String, port := GAME_PORT) -> Error:
	disconnect_game()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host_ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = false
	return OK

func disconnect_game() -> void:
	if _peer:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	is_connected_to_server = false
	_connected_peers.clear()

# -------------------------------------------------------------------------
# MULTIPLAYER SIGNALS & RPC
# -------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if is_host:
		# Assign slot
		var slot_idx := _connected_peers.size()
		_connected_peers[id] = {
			"nickname": "Player %d" % id,
			"char": "Character/C01",
			"slot": slot_idx,
			"ready": false,
		}
		rpc_id(id, "_client_receive_room_state", _connected_peers, Session.selected_map, Session.room_title)
		rpc("_sync_connected_peers", _connected_peers)

func _on_peer_disconnected(id: int) -> void:
	if is_host:
		_connected_peers.erase(id)
		rpc("_sync_connected_peers", _connected_peers)
		player_disconnected_from_room.emit(id)

func _on_connected_to_server() -> void:
	is_connected_to_server = true
	rpc_id(1, "_server_register_player", {
		"nickname": Session.nickname if Session.nickname != "" else "Guest",
		"char": Session.selected_char,
		"team_color_idx": Session.team_color_idx,
		"cosmetics": Session.get_room_slot_cosmetics(0),
	})

func _on_connection_failed() -> void:
	disconnect_game()

func _on_server_disconnected() -> void:
	disconnect_game()

@rpc("any_peer", "call_local")
func _server_register_player(info: Dictionary) -> void:
	if not is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if _connected_peers.has(sender_id):
		_connected_peers[sender_id].nickname = info.get("nickname", "Player")
		_connected_peers[sender_id].char = info.get("char", "Character/C00")
		_connected_peers[sender_id].team_color_idx = int(info.get("team_color_idx", 1))
		_connected_peers[sender_id].cosmetics = info.get("cosmetics", {})
		rpc("_sync_connected_peers", _connected_peers)

func _apply_peers_to_session_slots(peers: Dictionary) -> void:
	for s in range(1, 8):
		if not bool(Session.room_slot_cosmetics[s].get("is_bot", false)):
			Session.room_slot_cosmetics[s] = {}
	for pid in peers.keys():
		var p: Dictionary = peers[pid]
		var s_idx: int = int(p.get("slot", -1))
		if s_idx >= 1 and s_idx < 8:
			var eq: Dictionary = (p.get("cosmetics", {}) as Dictionary).duplicate(true)
			eq["char"] = str(p.get("char", "Character/C01"))
			eq["nick"] = str(p.get("nickname", "Player %d" % int(pid)))
			eq["team_color_idx"] = int(p.get("team_color_idx", s_idx % 8))
			eq["ready"] = bool(p.get("ready", false))
			Session.room_slot_locked[s_idx] = false
			Session.set_room_slot_cosmetics(s_idx, eq)

@rpc("authority", "call_local")
func _client_receive_room_state(peers: Dictionary, map_code: String, title: String) -> void:
	_connected_peers = peers
	Session.selected_map = map_code
	Session.room_title = title
	_apply_peers_to_session_slots(peers)
	room_updated.emit({
		"peers": peers,
		"map": map_code,
		"title": title
	})

@rpc("authority", "call_local")
func _sync_connected_peers(peers: Dictionary) -> void:
	_connected_peers = peers
	_apply_peers_to_session_slots(peers)
	room_updated.emit({"peers": peers})

func start_match() -> void:
	if is_host:
		rpc("_rpc_start_match")

@rpc("authority", "call_local")
func _rpc_start_match() -> void:
	match_started.emit()
	Session.goto("game_stage")
