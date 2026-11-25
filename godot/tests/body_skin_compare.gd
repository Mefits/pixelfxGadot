extends SceneTree
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Ink=preload("res://lab/ink_051.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Skin=preload("res://lab/body_skin_054.gd")
var engines:Array=[]
var sprites:Array=[]
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    var out:String=args[0]
    if not ClassDB.class_exists("PixelFXBodyRaster"):push_error("Missing body raster");quit(1);return
    var frames:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var rig=Rig.make()
    root.size=Vector2i(720,240)
    root.content_scale_size=Vector2i(720,240)
    var bg:=ColorRect.new()
    bg.color=Color("#283b48")
    bg.size=Vector2(720,240)
    root.add_child(bg)
    for i in 3:
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
        var sp:=Sprite2D.new()
        sp.centered=false
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        sp.position=Vector2(i*240+20,0)
        sp.scale=Vector2.ONE*(2.5/float(1 if i<2 else 3))
        root.add_child(sp)
        sprites.append(sp)
    var report:Array=[]
    var first:Array=[]
    for t in frames.size():
        var f:Dictionary=frames[t]
        var p:=Clips.pose(f.run_angles,0,0)
        rig.evaluate(p)
        var bottom:float=-1000
        for side in ["near","far"]:
            for v in Ink.shoe_points(rig.point("foot_"+side),float(p.angles["foot_pitch_"+side])):
                bottom=maxf(bottom,v.y)
        p.root[1]=-bottom-float(f.run_flight)
        rig.evaluate(p)
        var q:Dictionary=rig.points.duplicate(true)
        var row:Array=[]
        for i in 3:
            var density:int=1 if i<2 else 3
            var data:Dictionary=Skin.make(q,p.angles,i)
            var result:Dictionary=engines[i].render(data.config,data.parts)
            if not result.ok:push_error(str(result.error));quit(1);return
            if result.body_pixels<50:push_error("Empty body");quit(1);return
            if t==0:first.append(result.rgba)
            if t==frames.size()-1 and first[i]!=result.rgba:push_error("Loop mismatch");quit(1);return
            var img:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            var sp:Sprite2D=sprites[i]
            if sp.texture==null:sp.texture=ImageTexture.create_from_image(img)
            else:sp.texture.update(img)
            row.append({"body_pixels":result.body_pixels,"cpu_us":result.cpu_us,"density":density})
        if q!=rig.points:push_error("Skin modified input");quit(1);return
        report.append(row)
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"frames":report,"loop_equal":true,"pose_unchanged":true}))
    file.close()
    print("BODY_SKIN054C_OK")
    quit()
