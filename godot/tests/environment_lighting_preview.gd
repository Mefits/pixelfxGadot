extends SceneTree
const DEMO = preload("res://lab/environment/lighting_demo.tscn")
var demo
var failed: bool = false
var output: String

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, name: String) -> void:
    print(("PASS " if ok else "FAIL ")+name)
    failed=failed or not ok

func _image() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func _seek(t: float) -> Image:
    demo.seek(t)
    return await _image()

func _delta(a: Image,b: Image,rect: Rect2i) -> Vector3:
    var d:=Vector3.ZERO
    for y in range(rect.position.y,rect.end.y):
        for x in range(rect.position.x,rect.end.x):
            var u:=a.get_pixel(x,y)
            var v:=b.get_pixel(x,y)
            d+=Vector3(absf(v.r-u.r),absf(v.g-u.g),absf(v.b-u.b))
    return d

func _run() -> void:
    output=OS.get_environment("ENV_CAPTURE_DIR")
    if output.is_empty():
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(960,540)
    demo=DEMO.instantiate()
    demo.autoplay=false
    root.add_child(demo)
    demo.arena.set_process(false)
    var arena=demo.arena
    var bus=arena.combat_lighting
    var idle: Image=await _seek(0.0)
    _check(bus.materials.size()==2,"two terrain receivers")
    _check(bus.active_count==0,"idle no combat lighting")
    _check(arena.emit_combat_light(Vector2(186,286),112,Color(1,0,0),1.5,0.25),"manual native light accepted")
    var red: Image=await _image()
    var near:=_delta(idle,red,Rect2i(170,380,200,115))
    var far:=_delta(idle,red,Rect2i(680,380,200,115))
    var sky:=_delta(idle,red,Rect2i(0,0,960,350))
    print("red test near RGB delta=",near," far=",far," sky=",sky)
    _check(near.x>15.0 and near.y<0.01 and near.z<0.01,"localized red receiver response")
    _check(far.length()<0.01 and sky.length()<0.01,"no opposite ruin or sky leakage")
    _check(arena.emit_combat_light(Vector2(460,286),112,Color(0,0,1),1.5,0.25),"second simultaneous light accepted")
    var mixed: Image=await _image()
    var right:=_delta(red,mixed,Rect2i(620,380,200,115))
    _check(right.z>15.0 and right.x<0.01,"independent blue receiver response")
    bus.tick(0.3)
    var expired: Image=await _image()
    _check(bus.active_count==0 and expired.get_data()==idle.get_data(),"expired light restores exact original frame")
    for i in range(12):
        arena.emit_combat_light(Vector2(140+i*10,290),80,Color.WHITE,0.5,0.2)
    _check(bus.active_count==8,"bounded eight-light selection")
    bus.clear()
    var warm: Image=await _seek(0.75)
    _check(demo.fx.lights.list.size()>0 and bus.active_count>0,"real Chain Lightning emits environment light")
    bus.set_enabled(false)
    var warm_off: Image=await _image()
    bus.set_enabled(true)
    var warm_on: Image=await _image()
    _check(_delta(warm_off,warm_on,Rect2i(150,385,220,105)).length()>2.0,"actual effect changes nearby stone")
    _check(warm.get_data()==warm_on.get_data(),"toggle preserves deterministic rendered frame")
    _check(warm_on.save_png(output.path_join("lighting_warm.png"))==OK,"save warm frame")
    _check(warm_off.save_png(output.path_join("lighting_off.png"))==OK,"save unlit comparison")
    var cool: Image=await _seek(3.45)
    _check(cool.save_png(output.path_join("lighting_cool.png"))==OK,"save cool frame")
    var loop: Image=await _seek(6.0)
    _check(loop.get_data()==idle.get_data(),"demo exact six-second loop")
    if failed:
        quit(1)
        return
    var samples: Array[int]=[]
    for i in range(360):
        var started:=Time.get_ticks_usec()
        demo.seek(float(i)/60.0)
        samples.append(Time.get_ticks_usec()-started)
        var frame: Image=await _image()
        if frame.save_png(output.path_join("light_%04d.png"%i))!=OK:
            quit(1)
            return
    samples.sort()
    print("demo CPU update including native effect raster/upload submission p95_us=",samples[341]," p99_us=",samples[356]," max_us=",samples[-1])
    quit(0)
