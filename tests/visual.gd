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
func impact_sequence(scene,name:String,hybrid:bool,heavy:bool)->void:
    scene.world=W.new()
    scene.world.hybrid_enabled=hybrid
    scene.world.a.separate(150)
    scene.world.b.separate(scene.world.a.pos.x+66-scene.world.b.pos.x)
    scene.world.rig_a.sample(scene.world.a)
    scene.world.rig_b.sample(scene.world.b)
    scene.debug=false
    DirAccess.make_dir_recursive_absolute("res://reports/"+name)
    for frame in range(44):
        for i in range(4):
            scene.world.tick({"heavy":heavy and frame==3 and i==0,"jab":not heavy and frame==3 and i==0},{})
        scene._hud()
        scene.queue_redraw()
        await capture(name+"/frame_%03d"%frame)
    if scene.world.hits!=1:push_error("Impact capture missed: "+name);quit(1)
func kick_sequence(scene,name:String,hit:bool,mirror:bool=false)->void:
    scene.world=W.new()
    scene.world.a.separate(150)
    scene.world.b.separate(scene.world.a.pos.x+(72 if hit else 130)-scene.world.b.pos.x)
    scene.world.rig_a.sample(scene.world.a)
    scene.world.rig_b.sample(scene.world.b)
    scene.artistic=true
    scene.smooth_skin=true
    scene.debug=false
    DirAccess.make_dir_recursive_absolute("res://reports/"+name)
    for frame in range(45):
        for i in range(4):
            var input:Dictionary={"kick":frame==3 and i==0}
            scene.world.tick({} if mirror else input,input if mirror else {})
        scene._hud()
        scene.queue_redraw()
        await capture(name+"/frame_%03d"%frame)
    if scene.world.hits!=(1 if hit else 0):push_error("Kick capture contact mismatch "+name);quit(1)
func check_skin(scene,state:Dictionary,tick0:int)->void:
    if scene.world.ticks!=tick0 or scene.world.rig_a.points!=state:
        push_error("Skin altered simulation")
        quit(1)
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
    scene.world=W.new()
    scene.world.a.separate(150)
    scene.world.b.separate(scene.world.a.pos.x+66-scene.world.b.pos.x)
    scene.world.rig_a.sample(scene.world.a)
    scene.world.rig_b.sample(scene.world.b)
    scene.debug=false
    DirAccess.make_dir_recursive_absolute("res://reports/jab")
    for frame in range(34):
        for i in range(4):
            scene.world.tick({"jab":frame==3 and i==0},{})
        scene._hud()
        scene.queue_redraw()
        await capture("jab/frame_%03d"%frame)
    if scene.world.hits!=1:push_error("Jab capture missed");quit(1);return
    await impact_sequence(scene,"heavy_hybrid",true,true)
    scene.smooth_skin=false
    await impact_sequence(scene,"heavy_old_skin",true,true)
    await sequence(scene,"run_old_skin",36,"run")
    scene.smooth_skin=true
    await impact_sequence(scene,"heavy_authored",false,true)
    await impact_sequence(scene,"jab_hybrid",true,false)
    await impact_sequence(scene,"jab_authored",false,false)
    scene.artistic=false
    await impact_sequence(scene,"heavy_mannequin",false,true)
    scene.artistic=true
    await kick_sequence(scene,"kick_hit",true)
    await kick_sequence(scene,"kick_miss",false)
    await kick_sequence(scene,"kick_mirror",true,true)
    var state:Dictionary=scene.world.rig_a.points.duplicate(true)
    var tick0:int=scene.world.ticks
    scene._toggle_skin()
    check_skin(scene,state,tick0)
    scene._toggle_skin()
    check_skin(scene,state,tick0)
    scene._toggle_smooth()
    check_skin(scene,state,tick0)
    scene._toggle_smooth()
    check_skin(scene,state,tick0)
    scene._pause()
    if not scene.paused:quit(1);return
    scene._reset()
    if scene.world.ticks!=0:quit(1);return
    print("N graphical smoke OK")
    quit()
