extends SceneTree
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Ink=preload("res://lab/ink_051.gd")
const Base=preload("res://lab/body_skin_054.gd")
const MeshBody=preload("res://lab/body_surface_056.gd")
var rig
var engines:Array=[]
var sprites:Array=[]
var out:String
func _initialize()->void:
    call_deferred("run")
func capture(p:Dictionary,name:String)->Array:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    var results:Array=[]
    for i in 3:
        var data:Dictionary=Base.make(q,p.angles,1) if i==0 else MeshBody.make(q,p.angles,float(rig.rotations.head),i==2)
        data.config.merge({"width":288,"height":288,"origin":[144,252],"density":3,"outline":3,"ink":0xff101010},true)
        if i==0:
            data.config.materials=MeshBody.make(q,p.angles,float(rig.rotations.head),false).config.materials
            data.parts[5].material_id=3
            data.parts[11].material_id=3
        var r:Dictionary=engines[i].render(data.config,data.parts)
        if not r.ok or r.body_pixels<50 or q!=rig.points:push_error("Surface failure "+str(r.get("error","")));return []
        var im:=Image.create_from_data(r.width,r.height,false,Image.FORMAT_RGBA8,r.rgba)
        var sp:Sprite2D=sprites[i]
        if sp.texture==null:sp.texture=ImageTexture.create_from_image(im)
        else:sp.texture.update(im)
        results.append({"rgba":r.rgba,"cpu_us":r.cpu_us,"pixels":r.body_pixels})
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join(name+".png"))!=OK:return []
    return results
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):quit(2);return
    out=args[0]
    rig=Rig.make()
    root.size=Vector2i(864,288)
    root.content_scale_size=Vector2i(864,288)
    var bg:=ColorRect.new()
    bg.color=Color("#283b48")
    bg.size=Vector2(864,288)
    root.add_child(bg)
    for i in 3:
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
        var sp:=Sprite2D.new()
        sp.centered=false
        sp.position=Vector2(i*288,0)
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        root.add_child(sp)
        sprites.append(sp)
    var angle:float=rad_to_deg(atan2(2.0,11.0))
    var stand:=Clips.pose({"thigh_far":-angle,"knee_far":2*angle,"thigh_near":angle,"knee_near":-2*angle},0,22-2*sqrt(125.0))
    if (await capture(stand,"stand")).is_empty():quit(1);return
    var f:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    for pair in [["guard",f.clips[2].samples[0].pose],["jab",f.clips[2].samples[1].pose],["kick",f.clips[1].samples[1].pose]]:
        if (await capture(pair[1],pair[0])).is_empty():quit(1);return
    var frames:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var report:Array=[]
    var first:Array=[]
    for t in frames.size():
        var frame:Dictionary=frames[t]
        var p:=Clips.pose(frame.run_angles,0,0)
        rig.evaluate(p)
        var bottom:float=-1000
        for side in ["near","far"]:
            for vtx in Ink.shoe_points(rig.point("foot_"+side),float(p.angles["foot_pitch_"+side])):
                bottom=maxf(bottom,vtx.y)
        p.root[1]=-bottom-float(frame.run_flight)
        var rr:Array=await capture(p,"%03d"%t)
        if rr.is_empty():quit(1);return
        var row:Array=[]
        for i in 3:
            if t==0:first.append(rr[i].rgba)
            if t==frames.size()-1 and first[i]!=rr[i].rgba:push_error("Loop mismatch");quit(1);return
            row.append({"cpu_us":rr[i].cpu_us,"pixels":rr[i].pixels})
        report.append(row)
    var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"frames":report,"static_poses":4,"pose_unchanged":true,"loop_equal":true}))
    file.close()
    print("BODY_SURFACE056_OK")
    quit()
