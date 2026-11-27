extends SceneTree
const Studio=preload("res://lab/hybrid_studio.gd")
func _initialize():call_deferred("run")
func fail(reason:String)->void:
    push_error(reason)
    quit(1)
func run()->void:
    root.size=Vector2i(960,540)
    root.content_scale_size=root.size
    var menu=load("res://lab/main.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    if menu.routes.get("H")!="res://lab/hybrid_studio.tscn" or menu.VERSION!="1.0 RC2" or menu.routes.size()!=10 or menu.routes.get("T")!="res://lab/combat_astra.tscn" or menu.routes.get("P")!="res://lab/motionphysics_studio.tscn" or menu.routes.get("M")!="res://lab/authoring/editor.tscn":
        fail("launcher routing")
        return
    if menu.SECTIONS[0].items.map(func(x):return x[0])!=["M","H","T","P","Y"] or menu.SECTIONS[1].items.map(func(x):return x[0])!=["J","U","I","A","L"]:
        fail("launcher categories")
        return
    for route in menu.routes.values():
        if not ResourceLoader.exists(route):
            fail("missing existing route "+route)
            return
    var args=OS.get_cmdline_user_args()
    if args.size()==1:
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(args[0].path_join("menu.png"))
    root.remove_child(menu)
    menu.queue_free()
    var scene=load("res://lab/hybrid_studio.tscn").instantiate()
    scene.manual=true
    root.add_child(scene)
    if not scene.last_ok:
        fail("initial native rendering")
        return
    scene.target_speed=1.85
    scene.set_cloth(1)
    for t in 100:scene.advance_tick()
    if scene.player.speed<1.8 or scene.last_travel<100. or scene.cloth.variant!=1 or not scene.last_ok:
        fail("locomotion or cloth B")
        return
    if args.size()==1:
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(args[0].path_join("hybrid.png"))
    scene.target_speed=0.
    scene.queue_action("jab")
    scene.advance_tick()
    if scene.player.action!="jab":
        fail("author action")
        return
    scene.set_cloth(2)
    scene.queue_action("cross")
    scene.advance_tick()
    if scene.player.action!="cross" or scene.cloth.variant!=2 or not scene.last_ok:
        fail("action interrupt or cloth C")
        return
    scene.set_cloth(0)
    scene.set_mode(1)
    scene.queue_hit("HEAD",.85,false)
    scene.advance_tick()
    if scene.reaction.seen.size()!=1 or scene.reaction.step_age>=0:
        fail("ordinary impact")
        return
    scene.queue_hit("HEAD",1.45,true)
    scene.advance_tick()
    for t in 8:scene.advance_tick()
    if scene.reaction.step_age<0 or not scene.last_ok:
        fail("recovery step")
        return
    if args.size()==1:
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(args[0].path_join("reaction.png"))
    scene.set_mode(0)
    if scene.player.tick!=0 or not scene.last_ok:
        fail("mode reset")
        return
    root.remove_child(scene)
    scene.queue_free()
    var fight=load("res://lab/combat_astra.tscn").instantiate()
    fight.manual=true
    root.add_child(fight)
    if not fight.last_ok:
        fail("Astra combat render")
        return
    var reference:Array=[]
    fight.hit_enabled=false
    fight.queue_attack(0)
    for t in 60:
        fight.advance()
        reference.append(fight.players[0].final_pose.duplicate(true))
    if fight.hits[0]!=0:
        fail("reference attack hit")
        return
    var found:bool=false
    for distance in [24.,20.,28.,16.,32.]:
        fight.distance=distance
        fight.hit_enabled=true
        fight.reset()
        fight.queue_attack(0)
        for t in 60:
            fight.advance()
            if fight.players[0].final_pose!=reference[t]:
                fail("contact changed attack pose")
                return
        if fight.hits[0]==1 and fight.hp[1]==95:
            found=true
            break
    if not found:
        fail("Astra event hit not found at training distances")
        return
    print("LAB_100_INTEGRATION_OK")
    quit()
