extends SceneTree
const S=preload("res://game/arena.tscn")
const W=preload("res://game/world.gd")
func _initialize()->void:call_deferred("_run")
func capture(name:String)->void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image:Image=root.get_texture().get_image()
    if image.save_png("res://reports/"+name+".png")!=OK:push_error("Capture failed")
func sequence(scene,name:String,count:int,kind:String)->void:
    scene.world=W.new()
    scene.debug=false
    DirAccess.make_dir_recursive_absolute("res://reports/"+name)
    for frame in range(count):
        for i in range(6):
            var n:int=frame*6+i
            var input:Dictionary={}
            if kind=="walk":input={"move":1 if frame<20 else 0}
            elif kind=="run":input={"move":1 if frame<24 else 0,"run":frame<24}
            elif kind=="back":input={"move":-1 if frame<20 else 0}
            elif kind=="jump":input={"jump":n==12}
            scene.world.tick(input,{})
        scene.queue_redraw()
        await capture(name+"/frame_%03d"%frame)
func _run()->void:
    root.size=Vector2i(960,540)
    DirAccess.make_dir_recursive_absolute("res://reports")
    var scene=S.instantiate()
    root.add_child(scene)
    await process_frame
    scene.set_physics_process(false)
    scene.world=preload("res://game/world.gd").new()
    scene.queue_redraw()
    await capture("stance")
    DirAccess.make_dir_recursive_absolute("res://reports/guard")
    for frame in range(24):
        scene.queue_redraw()
        await capture("guard/frame_%03d"%frame)
        for tick in range(6):scene.world.tick({}, {})
    for i in range(47):scene.world.tick({"move":1,"run":true},{})
    scene.debug=true
    scene.queue_redraw()
    await capture("running")
    for i in range(32):scene.world.tick({"move":1,"jump":i==0},{})
    scene.queue_redraw()
    await capture("jump")
    await sequence(scene,"walk",32,"walk")
    await sequence(scene,"run",36,"run")
    await sequence(scene,"back",32,"back")
    await sequence(scene,"leap",30,"jump")
    scene._pause()
    if not scene.paused:quit(1);return
    scene._reset()
    if scene.world.ticks!=0:quit(1);return
    print("N graphical smoke OK")
    quit()
