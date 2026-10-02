class_name NetClient
extends Node

## Wi-Fi co-op guest (v1.8): plays Luigi on a game that runs on the host.
## Builds the static look of the course itself (Level.visual_only), shows
## the host's moving things as "puppets" (see NetHost for the record
## layout), the host's HUD, world map and sounds, and sends its buttons.
## Positions and the camera glide from one snapshot to the next.

signal left(reason: String)
signal scene_shown

const RATE := 30.0

var link := NetLink.new()
var game: Game
var host_ip := ""
var paused_local := false
var _strings := {}
var _res := {}
var _scene_id := -1
var _scene_kind := ""
var _level: Level
var _map: WorldMap
var _layer: Node2D
var _puppets := {}          # nid -> {node, kind, from, to, t}
var _dead := {}             # nid of effects that already finished here
var _cam_from := Vector2.ZERO
var _cam_to := Vector2.ZERO
var _cam_t := 1.0
var _mask := -1
var _vp := Vector2.ZERO
var _wait_t := 0.0
var _host_paused := false
var _first_scene := false
var _gone := false

func _leave(reason: String) -> void:
	if not _gone:
		_gone = true
		left.emit(reason)

func start(ip: String) -> int:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host_ip = ip
	return link.join(ip)

## Online (v1.9): join Mario's room at the relay.
func start_online(url: String, code: String) -> int:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host_ip = code
	return link.join_online(url, code)

var rtt_ms := -1
var _ping_t := 0.0
var _snap_dt := 1.0 / RATE
var _last_snap := 0

func ping_ms() -> int:
	return link.ping_ms() if not link.is_online() else rtt_ms

func close() -> void:
	link.close()
	_clear_scene()
	if _map:
		_map.queue_free()
		_map = null

func _exit_tree() -> void:
	close()

func _process(delta: float) -> void:
	if _gone:
		return
	for ev in link.poll():
		match ev[0]:
			"connect":
				_send_vp()
			"disconnect":
				_leave("The connection to Mario's game was lost.")
				return
			"msg":
				_on_msg(ev[1], ev[2])
			"error", "closed":
				_leave(str(ev[1]) if str(ev[1]) != "" else "The online connection ended.")
				return
	if not link.connected:
		_wait_t += delta
		if _wait_t > (15.0 if link.is_online() else 8.0):
			_leave("No answer from %s." % host_ip)
		return
	_ping_t -= delta
	if _ping_t <= 0.0:
		_ping_t = 2.0
		link.send("ping", Time.get_ticks_msec())
	_send_vp()
	_send_input()
	_glide(delta)

func _send_vp() -> void:
	var vp := game.get_viewport_rect().size
	if vp != _vp:
		_vp = vp
		link.send("vp", vp)

func _send_input() -> void:
	var m := 0
	if not paused_local:
		var acts := ["move_left", "move_right", "move_down", "ui_up", "jump", "run"]
		for i in acts.size():
			if Input.is_action_pressed(acts[i]):
				m |= 1 << i
	if m != _mask:
		_mask = m
		link.send("in", m)

func send_pause(on: bool) -> void:
	paused_local = on
	link.send("pause", on)

func _on_msg(type: String, p) -> void:
	match type:
		"hello":
			var v := str(p.get("v", "")) if p is Dictionary else ""
			var mine := str(ProjectSettings.get_setting("application/config/version"))
			if v.get_slice(".", 0) + "." + v.get_slice(".", 1) != mine.get_slice(".", 0) + "." + mine.get_slice(".", 1):
				_leave("Different game versions: Mario %s, Luigi %s.\nPlease install the same version." % [v, mine])
		"bye":
			_leave("Mario ended the game.")
		"pong":
			rtt_ms = Time.get_ticks_msec() - int(p)
		"str":
			_strings[int(p[0])] = str(p[1])
		"scene":
			_build_scene(p)
		"snd":
			var snd := get_node_or_null("/root/Snd")
			if snd and p is Array and snd.has_method(str(p[0])):
				snd.callv(str(p[0]), p[1])
		"snap":
			var raw: PackedByteArray = p
			var data = bytes_to_var(raw.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
			if data is Dictionary and int(data.get("sc", -1)) == _scene_id:
				# glide over the real time between snapshots (30/s Wi-Fi, 20/s online)
				var now := Time.get_ticks_msec()
				if _last_snap > 0:
					_snap_dt = lerpf(_snap_dt, clampf((now - _last_snap) / 1000.0, 0.02, 0.2), 0.2)
				_last_snap = now
				_apply_snap(data)

# ----------------------------------------------------------------- scenes --
func _clear_scene() -> void:
	for nid in _puppets:
		var n = _puppets[nid].node
		if is_instance_valid(n):
			n.queue_free()
	_puppets.clear()
	_dead.clear()
	if _layer:
		_layer.queue_free()
		_layer = null
	if _level:
		game.world.remove_child(_level)
		_level.queue_free()
		_level = null
	if _map:
		_map.hide_map()

func _build_scene(p: Dictionary) -> void:
	_clear_scene()
	_scene_id = int(p.id)
	_scene_kind = str(p.kind)
	var hud := game.hud
	hud.visible = true
	hud.set_buttons_visible(true)
	game.camera.limit_left = -10000000
	game.camera.limit_right = 10000000
	game.camera.limit_top = -10000000
	game.camera.limit_bottom = 10000000
	match _scene_kind:
		"level":
			hud.hide_card()
			_level = Level.new()
			_level.name = "Level"
			_level.visual_only = true
			game.world.add_child(_level)
			_level.setup(Game.LEVELS[int(p.level)])
			_layer = Node2D.new()
			_layer.name = "NetPuppets"
			game.world.add_child(_layer)
		"map":
			hud.hide_card()
			if _map == null:
				_map = WorldMap.new()
				_map.name = "NetMap"
				_map.puppet = true
				game.world.add_child(_map)
			game.backdrop.set_theme(Game.MAP_THEME)
		_:
			hud.show_text_card(str(p.text), "please wait")
			hud.set_boss(-1, 0)
	_cam_t = 1.0
	_first_scene = true
	game.apply_touch_layout()
	scene_shown.emit()

func is_playing() -> bool:
	return _scene_kind in ["level", "map"]

func _apply_snap(d: Dictionary) -> void:
	_host_paused = bool(d.get("p", false))
	if _scene_kind != "wait":
		game.hud.apply_net_state(d.get("hud", []))
	if _host_paused and not paused_local:
		game.hud.show_banner("PAUSED", 0.5)
	var th := str(d.get("th", ""))
	if _scene_kind == "level" and th != "" and th != game.backdrop.theme:
		game.backdrop.set_theme(th)
	var cam: Vector2 = d.get("cam", _cam_to)
	if _first_scene or cam.distance_to(_cam_to) > 200.0:
		_cam_from = cam
		_first_scene = false
	else:
		_cam_from = game.camera.global_position
	_cam_to = cam
	_cam_t = 0.0
	if _scene_kind == "map" and _map and d.has("map"):
		_map.apply_net_state(d.map)
	elif _scene_kind == "level" and _layer:
		_apply_nodes(d.get("i", PackedInt32Array()), d.get("f", PackedFloat32Array()))

func _glide(delta: float) -> void:
	var rate := 1.0 / _snap_dt
	_cam_t = minf(_cam_t + delta * rate, 1.0)
	game.camera.global_position = _cam_from.lerp(_cam_to, _cam_t)
	for nid in _puppets:
		var pp: Dictionary = _puppets[nid]
		if pp.t < 1.0 and is_instance_valid(pp.node):
			pp.t = minf(pp.t + delta * rate, 1.0)
			var pos: Vector2 = pp.from.lerp(pp.to, pp.t)
			pp.node.position = pos

# ---------------------------------------------------------------- puppets --
func _str(id: int) -> String:
	return _strings.get(id, "")

func _load(path: String) -> Resource:
	if not _res.has(path):
		_res[path] = load(path) if ResourceLoader.exists(path) else null
	return _res[path]

func _texture(key: String) -> Texture2D:
	if _res.has(key):
		return _res[key]
	var t: Texture2D = null
	if key.begins_with("atlas|"):
		var parts := key.split("|")
		var atlas: Texture2D = _load(parts[1])
		if atlas:
			var r := parts[2].split(",")
			var at := AtlasTexture.new()
			at.atlas = atlas
			at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			t = at
	else:
		t = _load(key)
	_res[key] = t
	return t

func _apply_nodes(ints: PackedInt32Array, floats: PackedFloat32Array) -> void:
	var seen := {}
	var n := ints.size() / NetHost.NI
	var order := 0
	for i in n:
		var a := ints.slice(i * NetHost.NI, (i + 1) * NetHost.NI)
		var f := floats.slice(i * NetHost.NF, (i + 1) * NetHost.NF)
		var nid := a[0]
		seen[nid] = true
		if _dead.has(nid):
			continue
		var pp: Dictionary = _puppets.get(nid, {})
		if pp.is_empty() or not is_instance_valid(pp.node) or pp.kind != a[1]:
			if not pp.is_empty() and not is_instance_valid(pp.node):
				_dead[nid] = true          # an effect that finished on its own
				_puppets.erase(nid)
				continue
			var node := _make(a)
			if node == null:
				continue
			_layer.add_child(node)
			pp = {"node": node, "kind": a[1], "from": Vector2(f[0], f[1]), "to": Vector2(f[0], f[1]), "t": 1.0}
			_puppets[nid] = pp
			_set_pos(node, Vector2(f[0], f[1]))
		var to := Vector2(f[0], f[1])
		if to.distance_to(pp.to) > 48.0:
			pp.from = to                     # teleport (pipe, respawn): no glide
		else:
			pp.from = pp.node.position
		pp.to = to
		pp.t = 0.0
		_update(pp.node, a, f)
		if _layer.get_child(order) != pp.node:
			_layer.move_child(pp.node, order)
		order += 1
	for nid in _puppets.keys():
		if not seen.has(nid):
			var node = _puppets[nid].node
			if is_instance_valid(node):
				node.queue_free()
			_puppets.erase(nid)
	for nid in _dead.keys():
		if not seen.has(nid):
			_dead.erase(nid)

func _set_pos(node: CanvasItem, p: Vector2) -> void:
	node.position = p

func _make(a: PackedInt32Array) -> CanvasItem:
	match a[1]:
		NetHost.Kind.ANIM:
			var frames: SpriteFrames = _load(_str(a[2]))
			if frames == null:
				return null
			var s := AnimatedSprite2D.new()
			s.sprite_frames = frames
			return s
		NetHost.Kind.SPRITE:
			var tex := _texture(_str(a[2]))
			if tex == null:
				return null
			var s := Sprite2D.new()
			s.texture = tex
			return s
		NetHost.Kind.LABEL:
			var l := ScorePopup.new()
			l.setup(_str(a[2]), Vector2.ZERO)
			l.ready.connect(func(): l.set_process(false), CONNECT_ONE_SHOT)
			return l
		NetHost.Kind.FX:
			match _str(a[2]):
				"sparkle":
					return Sparkle.new()
				"puff":
					return JumpPuff.new()
				"stars":
					return StunStars.new()
				"mark":
					return BossFlame.MeteorMark.new()
			return null
		NetHost.Kind.BUBBLE:
			return BubbleView.new()
		NetHost.Kind.TONGUE:
			return TongueView.new()
	return null

func _update(node: CanvasItem, a: PackedInt32Array, f: PackedFloat32Array) -> void:
	node.z_as_relative = false
	node.z_index = a[6]
	node.modulate = Color(f[8], f[9], f[10], f[11])
	if node is Node2D:
		var n2: Node2D = node
		n2.rotation = f[2]
		n2.scale = Vector2(f[3], f[4])
		n2.skew = f[7]
	var flags := a[5]
	match a[1]:
		NetHost.Kind.ANIM:
			var s: AnimatedSprite2D = node
			var anim := StringName(_str(a[3]))
			if s.animation != anim and s.sprite_frames.has_animation(anim):
				s.animation = anim
			s.frame = a[4]
			s.flip_h = flags & 1 != 0
			s.flip_v = flags & 2 != 0
			s.centered = flags & 4 != 0
			s.offset = Vector2(f[5], f[6])
		NetHost.Kind.SPRITE:
			var s: Sprite2D = node
			s.flip_h = flags & 1 != 0
			s.flip_v = flags & 2 != 0
			s.centered = flags & 4 != 0
			s.hframes = maxi(a[7] & 0xff, 1)
			s.vframes = maxi((a[7] >> 8) & 0xff, 1)
			s.frame = clampi(a[4], 0, s.hframes * s.vframes - 1)
			s.offset = Vector2(f[5], f[6])
			if a[8] != 0:
				var r := _str(a[8]).split(",")
				if r.size() == 4:
					s.region_enabled = true
					s.region_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		NetHost.Kind.BUBBLE:
			var b: BubbleView = node
			b.body_h = float(a[7])
			b.small = a[8] != 0
			b.queue_redraw()
		NetHost.Kind.TONGUE:
			var t: TongueView = node
			t.length = a[7] / 10.0
			t.dir = a[8]
			t.queue_redraw()


class BubbleView extends Node2D:
	var body_h := 14.0
	var small := true
	func _draw() -> void:
		Player.draw_bubble_on(self, body_h, small)


class TongueView extends Node2D:
	var length := 0.0
	var dir := 1
	func _draw() -> void:
		Dino.draw_tongue_on(self, dir, length)
