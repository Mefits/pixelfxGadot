extends SceneTree
const SCENE = preload("res://lab/environment/cosmic_ruins.tscn")
var scene
var output: String
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    print(("PASS " if ok else "FAIL ") + message)
    failed = failed or not ok

func _frame(t: float) -> Image:
    scene.set_time(t)
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func _run() -> void:
    output = OS.get_environment("ENV_CAPTURE_DIR")
    if output.is_empty():
        push_error("ENV_CAPTURE_DIR missing")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(960,540)
    scene = SCENE.instantiate()
    scene.animate = false
    root.add_child(scene)
    print("Startup generation us=",scene.generation_us," layers=",scene.layers.size())
    _check(scene.layers.size()==10,"ten independently generated scene layers")
    var first: Image = await _frame(0.0)
    var middle: Image = await _frame(3.0)
    var loop: Image = await _frame(12.0)
    _check(first.get_width()>0 and first.get_height()>0,"real rendered viewport")
    _check(first.get_data()==loop.get_data(),"exact loop closure t=0 vs t=12")
    _check(first.get_data()!=middle.get_data(),"animation changes rendered pixels")
    var y: int = int(first.get_height()*0.96)
    var stable: bool = true
    for x in range(first.get_width()):
        if first.get_pixel(x,y)!=middle.get_pixel(x,y):
            stable = false
    _check(stable,"foreground stays fixed")
    var ids: Array[int] = []
    for sprite in scene.layers:
        ids.append(sprite.texture.get_instance_id())
    var timings: Array[int] = []
    for i in range(720):
        var started := Time.get_ticks_usec()
        scene.set_time(float(i)/60.0)
        timings.append(Time.get_ticks_usec()-started)
    timings.sort()
    print("CPU update only (excludes GPU/render/readback) p95_us=",timings[683]," p99_us=",timings[712]," max_us=",timings[-1])
    var unchanged: bool = true
    for i in range(ids.size()):
        unchanged = unchanged and ids[i]==scene.layers[i].texture.get_instance_id()
    _check(unchanged,"no texture recreation during animation")
    if failed:
        quit(1)
        return
    _check(first.save_png(output.path_join("cosmic_ruins.png"))==OK,"save reference frame")
    # 720 unique time samples, actual Godot output, no simulated or interpolated frames.
    for i in range(720):
        var img: Image = await _frame(float(i)/60.0)
        if img.save_png(output.path_join("frame_%04d.png"%i))!=OK:
            push_error("Capture failed at "+str(i))
            quit(1)
            return
    root.remove_child(scene)
    scene.free()
    scene = SCENE.instantiate()
    scene.animate = false
    scene.internal_width = 960
    root.add_child(scene)
    var large: Image = await _frame(0.0)
    _check(scene.raster_width==960 and scene.raster_height==540,"960x540 internal raster")
    _check(large.save_png(output.path_join("cosmic_ruins_960.png"))==OK,"save larger raster comparison")
    print("960 startup generation us=",scene.generation_us)
    quit(1 if failed else 0)
