extends SceneTree
const CLIP = preload("res://addons/pixelfx/clip.gd")
const PLAYER = preload("res://addons/pixelfx/player.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var folder := DirAccess.open("res://generated")
    if folder == null:
        quit(1)
        return
    var count: int = 0
    for name in folder.get_directories():
        var c = CLIP.read_clip("res://generated/" + name + "/clip.json")
        if c == null:
            push_error("Failed to load clip: " + name)
            quit(1)
            return
        var p = PLAYER.new()
        root.add_child(p)
        p.play_clip(c, Vector2(160, 120))
        if not p.active or p.frame_index != 0:
            quit(1)
            return
        p._show_frame(c.frames.size() - 1)
        if p.frame_index != c.frames.size() - 1 or p.page_index != c.page_indices[-1]:
            quit(1)
            return
        p.stop()
        if p.active or p.visible:
            quit(1)
            return
        p.free()
        count += 1
    print("Godot clip smoke: ", count, " clips")
    quit(0 if count >= 7 else 1)
