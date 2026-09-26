#!/usr/bin/env python3
"""Re-insert the three godot_mcp autoload lines into project.godot if the
addon's own _exit_tree() stripped them during a headless --import/--export
run (see the learn-path CLAUDE.md, "Die drei [autoload]-Einträge ...").

Only touches those three lines — every other autoload and setting is kept
exactly as it is, so this is safe to run on a project.godot with uncommitted
changes (unlike `git checkout -- project.godot`).
"""
import sys

MCP = [
    'MCPScreenshot="*res://addons/godot_mcp/mcp_screenshot_service.gd"',
    'MCPInputService="*res://addons/godot_mcp/mcp_input_service.gd"',
    'MCPGameInspector="*res://addons/godot_mcp/mcp_game_inspector_service.gd"',
]

path = sys.argv[1] if len(sys.argv) > 1 else "project.godot"
lines = open(path, encoding="utf-8").read().split("\n")
missing = [m for m in MCP if m not in lines]
if not missing:
    sys.exit(0)

if "[autoload]" in lines:
    i = lines.index("[autoload]") + 1
    # skip the blank line right after the header
    while i < len(lines) and lines[i] == "":
        i += 1
    for m in reversed(missing):
        lines.insert(i, m)
else:
    # insert a fresh section right before [display] (Godot's own order)
    i = lines.index("[display]") if "[display]" in lines else len(lines)
    lines[i:i] = ["[autoload]", ""] + missing + [""]

open(path, "w", encoding="utf-8").write("\n".join(lines))
print("  (restored %d godot_mcp autoload line(s) in %s)" % (len(missing), path))
