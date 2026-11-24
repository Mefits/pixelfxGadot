extends SceneTree
## Real engine frame capture. Use a graphical Godot process (Xvfb on Linux).
const DEMO=preload("res://addons/creature/sdk_demo.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
const API=preload("res://addons/creature/kit_api.gd")
func _initialize()->void:call_deferred("_run")
func fail(message:String)->void:
    print("CREATURE_SDK "+JSON.stringify({"ok":false,"error":message}))
    quit(2)
func _run()->void:
    var args:PackedStringArray=OS.get_cmdline_user_args()
    if args.size()<4 or args.size()>5:
        fail("render TEMPLATE.json OUT_DIR FPS FRAME_COUNT [CREATURE.json]");return
    if DisplayServer.get_name()=="headless":
        fail("Rendering requires graphical driver, e.g. xvfb-run -a godot");return
    if not args[2].is_valid_int() or not args[3].is_valid_int():
        fail("FPS and frame count must be integers");return
    var fps:int=int(args[2])
    var count:int=int(args[3])
    if not fps in [15,30,60] or count<2 or count>180:
        fail("FPS 15/30/60; frames 2..180");return
    var validator=VALID.new()
    var report:Dictionary=validator.validate_file(args[0])
    if not report.ok:
        fail(JSON.stringify(report));return
    var e:Dictionary=API.read(args[0])
    var anatomy:Dictionary={}
    if args.size()==5:
        var creature:Dictionary=API.read(args[4])
        report=validator.compatibility(creature,e)
        if not report.ok:fail(JSON.stringify(report));return
        anatomy=creature.payload
    var folder:String=args[1]
    if DirAccess.dir_exists_absolute(folder) or FileAccess.file_exists(folder):
        fail("Output directory already exists");return
    if DirAccess.make_dir_recursive_absolute(folder)!=OK:
        fail("Could not create output directory");return
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(320,180)
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var demo=DEMO.new()
    demo.manual=true
    demo.entry=e
    demo.anatomy_override=anatomy
    viewport.add_child(demo)
    await process_frame
    var frames:Array=[]
    var hashes:Dictionary={}
    var started:bool=false
    var dt:float=1.0/fps
    for i in range(count):
        var axis:float=1.0 if e.kind=="creature" and i>fps/4 and i<fps else 0.0
        var trigger:bool=false
        if e.kind=="ability" and not started:
            trigger=i>=fps/2 and (demo.creature==null or demo.creature.grounded)
        demo.advance_frame(dt,axis,trigger,false)
        if e.kind=="ability" and (demo.attempted or (demo.world!=null and demo.world.a.attacks_started>0)):started=true
        await process_frame
        await RenderingServer.frame_post_draw
        var image:Image=viewport.get_texture().get_image()
        if image==null or image.is_empty():
            fail("Empty renderer output");return
        var filename:String="frame_%04d.png"%i
        var path:String=folder.path_join(filename)
        if image.save_png(path)!=OK:fail("Cannot write "+path);return
        var sha:String=FileAccess.get_sha256(path)
        hashes[sha]=true
        frames.append({"file":filename,"time":float(i+1)/fps,"sha256":sha})
    var stats:Dictionary=demo.diagnostics()
    var ok:bool=hashes.size()>1 and stats.get("finite",true) and float(stats.get("max_penetration",0))<.1
    var result:Dictionary={"ok":ok,"sdk_version":"0.35","renderer":"Godot viewport","template":e.id,"fps":fps,"width":320,"height":180,"frames":frames,"unique_frames":hashes.size(),"diagnostics":stats}
    var f:=FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
    if f==null:fail("Cannot write report");return
    f.store_string(JSON.stringify(result,"  ",true,true))
    f.close()
    print("CREATURE_SDK "+JSON.stringify({"ok":ok,"report":folder.path_join("report.json"),"unique_frames":hashes.size(),"diagnostics":stats}))
    quit(0 if ok else 1)
