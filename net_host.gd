class_name NetHost
extends Node

## Wi-Fi co-op host (v1.8): this device runs the whole game (co-op, Mario
## plays here); the guest (Luigi) only sends its buttons and gets ~30
## snapshots a second of what to draw.
## A snapshot = scene id, camera, theme, HUD (Hud.net_state), the world map
## (WorldMap.net_state) or every visible moving thing in the course: each
## AnimatedSprite2D / Sprite2D / score popup / little effect under the
## level, found by walking the tree (static parts carry the meta
## "net_static" — the guest builds those itself, Level.visual_only).
## Record layout (NetClient reads the same): ints
## [nid, kind, res, anim, frame, flags, z, extra1, extra2] and floats
## [x, y, rot, sx, sy, ox, oy, skew, r, g, b, a] per thing; strings
## (resource paths, animation names, texts) go once through a table.

signal guest_joined
signal guest_left

const RATE := 30.0
const NI := 9
const NF := 12
enum Kind { ANIM = 1, SPRITE = 2, LABEL = 3, FX = 4, BUBBLE = 5, TONGUE = 6 }
const BUTTONS := ["left", "right", "down", "up", "jump", "run"]

var link := NetLink.new()
var discovery := NetLink.Discovery.new()
var game: Game
var guest_vp := Vector2(480, 270)
var _strings := {}
var _nids := {}
var _next_nid := 1
var _scene_id := 0
var _scene_key := ""
var _tick := 0.0
var _mask := 0
var _warned := {}

func start(host_name: String) -> int:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var err := link.host()
	if err != OK:
		return err
	discovery.start_host(host_name)
	var snd := get_node_or_null("/root/Snd")
	if snd:
		snd.net_tap = _on_sound
	return OK

func stop() -> void:
	var snd := get_node_or_null("/root/Snd")
	if snd and snd.net_tap == Callable(self, "_on_sound"):
		snd.net_tap = Callable()
	_apply_mask(0)
	if link.connected:
		link.send("bye", "")
		link.enet.flush()
	link.close()
	discovery.stop()

func is_connected_guest() -> bool:
	return link.connected

func _exit_tree() -> void:
	stop()

func _process(delta: float) -> void:
	discovery.poll(delta)
	for ev in link.poll():
		match ev[0]:
			"connect":
				_strings.clear()
				_nids.clear()
				_scene_key = ""
				link.send("hello", {"v": ProjectSettings.get_setting("application/config/version")})
				guest_joined.emit()
			"disconnect":
				_apply_mask(0)
				guest_left.emit()
			"msg":
				_on_msg(ev[1], ev[2])
	if not link.connected:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0 / RATE
		_send_frame()

func _on_msg(type: String, payload) -> void:
	match type:
		"in":
			_apply_mask(int(payload))
		"vp":
			if payload is Vector2:
				guest_vp = Vector2(clampf(payload.x, 200.0, 1200.0), clampf(payload.y, 150.0, 600.0))
		"pause":
			if game:
				game.net_guest_pause(bool(payload))

## Luigi's buttons: pressed / released on his co-op actions (p2_*), which
## have no local device on the host.
func _apply_mask(m: int) -> void:
	var names := CoopInput.action_names(1)
	for i in BUTTONS.size():
		var a: String = names[BUTTONS[i]]
		if not InputMap.has_action(a):
			continue
		var on := (m >> i) & 1 == 1
		if on and not Input.is_action_pressed(a):
			Input.action_press(a)
		elif not on and Input.is_action_pressed(a):
			Input.action_release(a)
	_mask = m

func _on_sound(method: String, args: Array) -> void:
	link.send("snd", [method, args])

func _sid(s: String) -> int:
	if _strings.has(s):
		return _strings[s]
	var id := _strings.size() + 1
	_strings[s] = id
	link.send("str", [id, s])
	return id

func _nid(n: Node) -> int:
	var k := n.get_instance_id()
	if not _nids.has(k):
		_nids[k] = _next_nid
		_next_nid += 1
	return _nids[k]

# ---------------------------------------------------------------- frames --
func _scene() -> Array:
	if game.state == Game.State.MAP and game.world_map:
		return ["map", "map", -1, ""]
	if game.level and game.state in [Game.State.INTRO, Game.State.PLAYING, Game.State.TRANSITION,
			Game.State.DYING, Game.State.CLEAR]:
		return ["level", "L%d" % game.level.get_instance_id(), game.level_index, ""]
	var text := "GAME OVER" if game.state == Game.State.GAMEOVER else "MARIO IS IN THE MENU"
	return ["wait", "W" + text, -1, text]

func _send_frame() -> void:
	var sc := _scene()
	if sc[1] != _scene_key:
		_scene_key = sc[1]
		_scene_id += 1
		_nids.clear()
		link.send("scene", {"id": _scene_id, "kind": sc[0], "level": sc[2], "text": sc[3]})
	var cam := _guest_camera()
	var snap := {"sc": _scene_id, "cam": cam, "hud": game.hud.net_state(), "p": game.is_paused(),
		"th": game.backdrop.theme}
	if sc[0] == "map":
		snap["map"] = game.world_map.net_state()
	elif sc[0] == "level":
		var ints := PackedInt32Array()
		var floats := PackedFloat32Array()
		var view := Rect2(cam - guest_vp * 0.5, guest_vp).grow(96.0)
		_collect(game.level, Color.WHITE, 0, view, ints, floats)
		snap["i"] = ints
		snap["f"] = floats
	var raw := var_to_bytes(snap)
	link.send("snap", raw.compress(FileAccess.COMPRESSION_DEFLATE), false)

## Where the guest's camera looks: the host camera's center, clamped to the
## same limits with the guest's own screen size (it may be wider).
func _guest_camera() -> Vector2:
	var c := game.camera
	var half := guest_vp * 0.5
	var p := c.global_position
	var lo := Vector2(c.limit_left + half.x, c.limit_top + half.y)
	var hi := Vector2(c.limit_right - half.x, c.limit_bottom - half.y)
	return Vector2(clampf(p.x, lo.x, maxf(lo.x, hi.x)), clampf(p.y, lo.y, maxf(lo.y, hi.y)))

func _collect(n: Node, col: Color, z: int, view: Rect2, ints: PackedInt32Array, floats: PackedFloat32Array) -> void:
	for c in n.get_children():
		if c.has_meta("net_static") or not (c is CanvasItem):
			continue
		var ci: CanvasItem = c
		if not ci.visible:
			continue
		var cz := z + ci.z_index if ci.z_as_relative else ci.z_index
		var ccol := col * ci.modulate
		# only what the guest can see (each thing by its own position)
		if not (ci is Node2D) or view.has_point((ci as Node2D).global_position):
			_emit(ci, ccol * ci.self_modulate, cz, ints, floats)
		_collect(ci, ccol, cz, view, ints, floats)

func _emit(ci: CanvasItem, col: Color, z: int, ints: PackedInt32Array, floats: PackedFloat32Array) -> void:
	var kind := 0
	var res := 0
	var anim := 0
	var frame := 0
	var flags := 0
	var e1 := 0
	var e2 := 0
	var off := Vector2.ZERO
	if ci is AnimatedSprite2D:
		var a: AnimatedSprite2D = ci
		if a.sprite_frames == null or a.sprite_frames.resource_path == "":
			_warn(ci)
			return
		kind = Kind.ANIM
		res = _sid(a.sprite_frames.resource_path)
		anim = _sid(String(a.animation))
		frame = a.frame
		flags = int(a.flip_h) | int(a.flip_v) << 1 | int(a.centered) << 2
		off = a.offset
	elif ci is Sprite2D:
		var s: Sprite2D = ci
		var key := _tex_key(s.texture)
		if key == "":
			_warn(ci)
			return
		kind = Kind.SPRITE
		res = _sid(key)
		frame = s.frame
		flags = int(s.flip_h) | int(s.flip_v) << 1 | int(s.centered) << 2
		e1 = s.hframes | s.vframes << 8
		if s.region_enabled:
			var r := s.region_rect
			e2 = _sid("%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y])
		off = s.offset
	elif ci is ScorePopup:
		kind = Kind.LABEL
		res = _sid((ci as Label).text)
	elif ci is Sparkle or ci is JumpPuff or ci is StunStars or ci is BossFlame.MeteorMark:
		kind = Kind.FX
		res = _sid("sparkle" if ci is Sparkle else ("puff" if ci is JumpPuff else ("stars" if ci is StunStars else "mark")))
	elif ci is Player and (ci as Player).mode == Player.Mode.BUBBLE:
		kind = Kind.BUBBLE
		e1 = int((ci as Player).body_height())
		e2 = int((ci as Player).power == Player.Power.SMALL)
	elif ci.has_meta("net_tongue"):
		var d: Dino = ci.get_parent()
		if d._tongue_len <= 0.5:
			return
		kind = Kind.TONGUE
		e1 = int(d._tongue_len * 10.0)
		e2 = d.facing
	else:
		return
	var t := ci.get_global_transform()
	ints.append_array([_nid(ci), kind, res, anim, frame, flags, z, e1, e2])
	floats.append_array([t.origin.x, t.origin.y, t.get_rotation(), t.get_scale().x, t.get_scale().y,
		off.x, off.y, t.get_skew(), col.r, col.g, col.b, col.a])

static func _tex_key(tex: Texture2D) -> String:
	if tex == null:
		return ""
	if tex.resource_path != "" and not tex.resource_path.contains("::"):
		return tex.resource_path
	if tex is AtlasTexture and (tex as AtlasTexture).atlas and (tex as AtlasTexture).atlas.resource_path != "":
		var at: AtlasTexture = tex
		return "atlas|%s|%d,%d,%d,%d" % [at.atlas.resource_path, at.region.position.x, at.region.position.y,
			at.region.size.x, at.region.size.y]
	return ""

func _warn(ci: CanvasItem) -> void:
	var k := ci.get_class() + ":" + str(ci.get_script().resource_path if ci.get_script() else "")
	if not _warned.has(k):
		_warned[k] = true
		push_warning("NetHost: can't send %s (%s)" % [ci.get_path(), k])
