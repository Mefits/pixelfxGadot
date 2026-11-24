extends SceneTree
const CLIP = preload("res://addons/pixelfx/clip.gd")
const PLAYER = preload("res://addons/pixelfx/player.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var clip = CLIP.read_clip("res://generated/lightning_chain-lightning/clip.json")
    if clip == null:
        quit(1)
        return
    var vp := SubViewport.new()
    vp.size = Vector2i(248, 104)
    vp.transparent_bg = false
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(vp)
    var bg := ColorRect.new()
    bg.size = Vector2(vp.size)
    vp.add_child(bg)
    var p = PLAYER.new()
    vp.add_child(p)
    p.play_clip(clip, clip.pivot)
    p.set_process(false)
    var failed: bool = false
    var out_dir: String = ProjectSettings.globalize_path("res://../reports")
    DirAccess.make_dir_recursive_absolute(out_dir)
    for i: int in [6, 12, 20]:
        p._show_frame(i)
        for rgb: Vector3i in [Vector3i(18,24,36),Vector3i(190,180,160)]:
            bg.color = Color8(rgb.x,rgb.y,rgb.z)
            await RenderingServer.frame_post_draw
            await RenderingServer.frame_post_draw
            var got: Image = vp.get_texture().get_image()
            got.convert(Image.FORMAT_RGBA8)
            var key: String = "chain_%d_%d" % [i,rgb.x]
            var expected := Image.load_from_file("res://tests/fixtures/" + key + ".png")
            if expected == null or expected.get_size() != got.get_size():
                quit(1)
                return
            expected.convert(Image.FORMAT_RGBA8)
            got.save_png(out_dir.path_join(key + "_godot.png"))
            expected.save_png(out_dir.path_join(key + "_original.png"))
            var a: PackedByteArray = got.get_data()
            var b: PackedByteArray = expected.get_data()
            var max_error: int = 0
            var bad: int = 0
            var total: int = 0
            for j in range(a.size()):
                if j % 4 == 3:
                    continue
                var e: int = absi(int(a[j]) - int(b[j]))
                max_error = maxi(max_error,e)
                total += e
                if e > 2:
                    bad += 1
            print(key, " max=", max_error, " mean=", float(total)/(a.size()*0.75), " channels>2=", bad)
            if max_error > 2:
                failed = true
    quit(1 if failed else 0)
