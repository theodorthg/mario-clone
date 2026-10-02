class_name NetLink
extends RefCounted

## Wi-Fi co-op (v1.8, stage 1): one host (Mario, runs the game) and one
## guest (Luigi) over ENet (UDP) in the local network — native builds only
## (a browser can't do UDP; stage 2 adds an internet relay over WebSocket).
## Messages are var_to_bytes([type, payload]) — never objects. Channels:
## 0 reliable (scene changes, sounds, inputs, strings), 1 unreliable
## sequenced (snapshots, ~30 per second).
## v1.9 (stage 2): the same messages over the internet — a WebSocket to the
## relay (server/relay.js, e.g. on Uberspace) that pairs Mario and Luigi by
## a 4-letter room code and passes the binary messages on. Works in the
## browser too. Control frames from the relay are JSON text (room, joined,
## left, error); game messages are binary frames.
## Discovery without typing an IP: the host broadcasts a beacon every
## second AND answers the guest's broadcast query with a unicast reply —
## so it works even where one side drops incoming broadcasts (Android
## without a multicast lock).

const PORT := 47111
const DISCOVERY_PORT := 47110
const MAGIC := "MCLONE-LAN-1"
const CH_RELIABLE := 0
const CH_FAST := 1

## The relay's address (wss://…/mario-relay). Set in project settings
## (application/config/relay_url) at build time; Settings key "relay_url"
## overrides it (tests: ws://127.0.0.1:8765).
const DEFAULT_RELAY := ""

var enet: ENetConnection
var peer: ENetPacketPeer          # guest: the host; host: the one guest
var ws: WebSocketPeer             # online (relay) instead of ENet
var is_host := false
var connected := false
var room_code := ""
var _ws_open := false
var _ws_hello := {}

static func relay_url() -> String:
	var u := str(GameSettings.load_all().get("relay_url", ""))
	if u == "":
		u = str(ProjectSettings.get_setting("application/config/relay_url", DEFAULT_RELAY))
	return u

## Online host: open a room at the relay (poll() then reports ["room", code]).
func host_online(url: String) -> int:
	is_host = true
	return _ws_open_to(url, {"op": "host", "v": ProjectSettings.get_setting("application/config/version")})

## Online guest: join room `code`.
func join_online(url: String, code: String) -> int:
	is_host = false
	return _ws_open_to(url, {"op": "join", "code": code.strip_edges().to_upper(),
		"v": ProjectSettings.get_setting("application/config/version")})

func is_online() -> bool:
	return ws != null

func _ws_open_to(url: String, hello: Dictionary) -> int:
	if url == "":
		return ERR_UNCONFIGURED
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 4 * 1024 * 1024
	ws.outbound_buffer_size = 4 * 1024 * 1024
	ws.max_queued_packets = 4096
	_ws_hello = hello
	_ws_open = false
	return ws.connect_to_url(url)

func _poll_ws() -> Array:
	var out := []
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _ws_open:
		_ws_open = true
		ws.send_text(JSON.stringify(_ws_hello))
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			var m = JSON.parse_string(pkt.get_string_from_utf8())
			if not (m is Dictionary):
				continue
			match str(m.get("op", "")):
				"room":
					room_code = str(m.get("code", ""))
					out.append(["room", room_code])
				"joined":
					connected = true
					out.append(["connect"])
				"left":
					connected = false
					out.append(["disconnect"])
				"error":
					out.append(["error", str(m.get("msg", "error"))])
		else:
			var msg = bytes_to_var(pkt)
			if msg is Array and msg.size() == 2:
				out.append(["msg", msg[0], msg[1]])
	if st == WebSocketPeer.STATE_CLOSED:
		# the relay names the reason in the close frame ("Mario ended …")
		var why := ws.get_close_reason()
		ws = null
		connected = false
		out.append(["closed", why if why != "" else ("No connection to the online server." if not _ws_open \
			else "The connection to the online server was lost.")])
	return out

## -> OK or an error code
func host(port := PORT) -> int:
	is_host = true
	enet = ENetConnection.new()
	return enet.create_host_bound("*", port, 1, 2)

func join(ip: String, port := PORT) -> int:
	is_host = false
	enet = ENetConnection.new()
	var err := enet.create_host(1, 2)
	if err != OK:
		return err
	peer = enet.connect_to_host(ip, port, 2)
	return OK if peer else ERR_CANT_CONNECT

## Pumps the connection. Returns events: ["connect"], ["disconnect"],
## ["msg", type, payload].
func poll() -> Array:
	if ws:
		return _poll_ws()
	var out := []
	if enet == null:
		return out
	while true:
		var ev: Array = enet.service(0)
		var t: int = ev[0]
		if t == ENetConnection.EVENT_NONE or t == ENetConnection.EVENT_ERROR:
			break
		var p: ENetPacketPeer = ev[1]
		match t:
			ENetConnection.EVENT_CONNECT:
				if is_host and connected and p != peer:
					p.peer_disconnect()          # one guest only
					continue
				peer = p
				peer.set_timeout(0, 4000, 8000)
				connected = true
				out.append(["connect"])
			ENetConnection.EVENT_DISCONNECT:
				if p == peer:
					connected = false
					peer = null
					out.append(["disconnect"])
			ENetConnection.EVENT_RECEIVE:
				var raw := p.get_packet()
				if p != peer:
					continue
				var m = bytes_to_var(raw)
				if m is Array and m.size() == 2:
					out.append(["msg", m[0], m[1]])
	return out

func send(type: String, payload, reliable := true) -> void:
	if ws:
		# TCP: everything arrives; drop fast data if the line can't keep up
		if connected and ws.get_ready_state() == WebSocketPeer.STATE_OPEN \
				and (reliable or ws.get_current_outbound_buffered_amount() < 256 * 1024):
			ws.send(var_to_bytes([type, payload]))
		return
	if not connected or peer == null:
		return
	var flags := ENetPacketPeer.FLAG_RELIABLE if reliable else ENetPacketPeer.FLAG_UNRELIABLE_FRAGMENT
	peer.send(CH_RELIABLE if reliable else CH_FAST, var_to_bytes([type, payload]), flags)

func ping_ms() -> int:
	if peer == null:
		return -1
	return int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func close() -> void:
	if ws:
		ws.poll()                     # hand queued messages ("bye") to the socket first
		ws.close()
		ws.poll()
		ws = null
		connected = false
		return
	if peer and connected:
		enet.flush()                  # peer_disconnect() drops what is still queued
		peer.peer_disconnect_later()
		enet.flush()
	if enet:
		enet.destroy()
	enet = null
	peer = null
	connected = false

## This device's addresses in the local network (to show on the host).
static func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or \
				(a.begins_with("172.") and int(a.get_slice(".", 1)) >= 16 and int(a.get_slice(".", 1)) <= 31):
			out.append(a)
	return out


## Finding hosts in the local network: the host listens on
## DISCOVERY_PORT and broadcasts a beacon to GUEST_PORT every second; the
## guest listens on GUEST_PORT and broadcasts "FIND" queries, which the host
## answers directly (unicast).
const GUEST_PORT := 47112

class Discovery:
	var udp := PacketPeerUDP.new()
	var hosting := false
	var host_name := ""
	var _t := 0.0
	## guest: ip -> {name, seen (msec)}
	var found := {}

	func start_host(name: String) -> int:
		hosting = true
		host_name = name
		udp.set_broadcast_enabled(true)
		return udp.bind(DISCOVERY_PORT)

	func start_search() -> int:
		hosting = false
		udp.set_broadcast_enabled(true)
		return udp.bind(GUEST_PORT)

	func poll(delta: float) -> void:
		_t -= delta
		if _t <= 0.0:
			_t = 1.0
			if hosting:
				_send_to("255.255.255.255", GUEST_PORT, "HOST|" + host_name)
			else:
				_send_to("255.255.255.255", DISCOVERY_PORT, "FIND")
				_send_to("127.0.0.1", DISCOVERY_PORT, "FIND")     # same device (tests)
		while udp.get_available_packet_count() > 0:
			var pkt := udp.get_packet()
			var ip := udp.get_packet_ip()
			var port := udp.get_packet_port()
			var txt := pkt.get_string_from_utf8()
			if not txt.begins_with(MAGIC + "|"):
				continue
			var body := txt.substr(MAGIC.length() + 1)
			if hosting and body == "FIND":
				_send_to(ip, port, "HOST|" + host_name)
			elif not hosting and body.begins_with("HOST|"):
				found[ip] = {"name": body.substr(5), "seen": Time.get_ticks_msec()}
		# forget hosts that went quiet
		for ip in found.keys():
			if Time.get_ticks_msec() - int(found[ip].seen) > 4000:
				found.erase(ip)

	func _send_to(ip: String, port: int, body: String) -> void:
		udp.set_dest_address(ip, port)
		udp.put_packet((MAGIC + "|" + body).to_utf8_buffer())

	func stop() -> void:
		udp.close()
