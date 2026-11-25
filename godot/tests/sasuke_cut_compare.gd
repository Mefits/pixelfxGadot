extends SceneTree
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
const RoundCostume=preload("res://lab/sasuke_style_055.gd")
const CutCostume=preload("res://lab/sasuke_cut_055.gd")
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):quit(2);return
    var out:String=args[0]
    var rig=Rig.make()
    var engine=ClassDB.instantiate("PixelFXBodyRaster")
    var angle:float=rad_to_deg(atan2(2.0,11.0))
    var old:=Clips.pose({},0,0)
    # Rotate the two fixed-length rest offsets to vertical. No rest joint edits.
    var corrected:=Clips.pose({"thigh_far":-angle,"knee_far":2*angle,"thigh_near":angle,"knee_near":-2*angle},0,22-2*sqrt(125.0))
    rig.evaluate(corrected)
    var error:float=0.0
    for side in ["far","near"]:
        error=maxf(error,absf(rig.point("thigh_"+side).x-rig.point("knee_"+side).x))
        error=maxf(error,absf(rig.point("knee_"+side).x-rig.point("foot_"+side).x))
        error=maxf(error,absf(rig.point("foot_"+side).y))
    if error>.001:push_error("Neutral stance not straight");quit(1);return
    root.size=Vector2i(960,288)
    root.content_scale_size=Vector2i(960,288)
    var bg:=ColorRect.new()
    bg.color=Color("#283b48")
    bg.size=Vector2(960,288)
    root.add_child(bg)
    var report:Array=[]
    for i in 4:
        var pose:Dictionary=old if i==0 else corrected
        rig.evaluate(pose)
        var q:Dictionary=rig.points.duplicate(true)
        var data:Dictionary=RoundCostume.make(q,pose.angles,float(rig.rotations.head)) if i<2 else CutCostume.make(q,pose.angles,float(rig.rotations.head),2.0 if i==2 else 4.0)
        var result:Dictionary=engine.render(data.config,data.parts)
        if not result.ok or result.body_pixels<50 or q!=rig.points:push_error("Costume failed "+str(result.get("error","")));quit(1);return
        var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
        var sp:=Sprite2D.new()
        sp.centered=false
        sp.position=Vector2(i*240,0)
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        sp.texture=ImageTexture.create_from_image(im)
        root.add_child(sp)
        report.append({"lane":i,"pixels":result.body_pixels,"cpu_us":result.cpu_us})
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join("native.png"))!=OK:quit(1);return
    var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"lanes":report,"straight_error":error,"pose_unchanged":true}))
    file.close()
    print("SASUKE_CUT055C_OK")
    quit()
