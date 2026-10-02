class_name NetLink
extends RefCounted

## Wi-Fi co-op (v1.8, stage 1): one host (Mario, runs the game) and one
## guest (Luigi) over ENet (UDP) in the local network — native builds only
## (a browser can't do UDP; stage 2 adds an internet relay over WebSocket).
## Messages are var_to_bytes([type, payload]) — never objects. Channels:
## 0 reliable (scene changes, sounds, inputs, strings), 1 unreliable
## sequenced (snapshots, ~30 per second).
## Discovery without typing an IP: the host broadcasts a beacon every
## second AND answers the guest's broadcast query with a unicast reply —
## so it works even where one side drops incoming broadcasts (Android
## without a multicast lock).

const PORT := 47111
const DISCOVERY_PORT := 47110
const MAGIC := "MCLONE-LAN-1"
const CH_RELIABLE := 0
const CH_FAST := 1

var enet: ENetConnection
var peer: ENetPacketPeer          # guest: the host; host: the one guest
var is_host := false
var connected := false

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
	if not connected or peer == null:
		return
	var flags := ENetPacketPeer.FLAG_RELIABLE if reliable else ENetPacketPeer.FLAG_UNRELIABLE_FRAGMENT
	peer.send(CH_RELIABLE if reliable else CH_FAST, var_to_bytes([type, payload]), flags)

func ping_ms() -> int:
	if peer == null:
		return -1
	return int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func close() -> void:
	if peer and connected:
		peer.peer_disconnect()
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
