"""Write a Godot 4 SpriteFrames .tres for a horizontal sprite strip.

anims: {name: ([frame_name, ...], fps, loop)} — frame names index into
`order` (the left-to-right cell order of the strip). A frame name may repeat
inside one animation (used for holds, e.g. the dino's idle blink).
"""


def write_spriteframes(path, tex_path, cell_w, cell_h, order, anims):
    used = []
    for frames, _fps, _loop in anims.values():
        for f in frames:
            if f not in order:
                raise ValueError("%s: unknown frame %r" % (path, f))
            if f not in used:
                used.append(f)
    out = ['[gd_resource type="SpriteFrames" format=3]', "",
           '[ext_resource type="Texture2D" path="%s" id="1_tex"]' % tex_path, ""]
    for f in used:
        i = order.index(f)
        out += ['[sub_resource type="AtlasTexture" id="at_%s"]' % f,
                'atlas = ExtResource("1_tex")',
                "region = Rect2(%d, 0, %d, %d)" % (i * cell_w, cell_w, cell_h), ""]
    blocks = []
    for name, (frames, fps, loop) in anims.items():
        fr = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("at_%s")\n}' % f for f in frames)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                      % (fr, "true" if loop else "false", name, float(fps)))
    out += ["[resource]", "animations = [%s]" % ", ".join(blocks), ""]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
