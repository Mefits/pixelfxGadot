extends SceneTree
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Ink=preload("res://lab/ink_051.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Costume=preload("res://lab/sasuke_style_055.gd")
var engine
var sprite:Sprite2D
var rig
var out:String
func _initialize()->void:
    call_deferred("run")
func capture(p:Dictionary,name:String)->Dictionary:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    var data:Dictionary=Costume.make(q,p.angles,float(rig.rotations.head))
    var r:Dictionary=engine.render(data.config,data.parts)
    if not r.ok or r.body_pixels<50 or q!=rig.points:
        push_error("Sasuke raster failed "+str(r.get("error","invalid points")))
        return {}
    var im:=Image.create_from_data(r.width,r.height,false,Image.FORMAT_RGBA8,r.rgba)
    if sprite.texture==null:sprite.texture=ImageTexture.create_from_image(im)
    else:sprite.texture.update(im)
    await process_frame
    await RenderingServer.frame_post_draw
    if root.get_texture().get_image().save_png(out.path_join(name+".png"))!=OK:return {}
    return {"rgba":r.rgba,"cpu_us":r.cpu_us,"pixels":r.body_pixels}
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):quit(2);return
    out=args[0]
    engine=ClassDB.instantiate("PixelFXBodyRaster")
    rig=Rig.make()
    root.size=Vector2i(240,288)
    root.content_scale_size=Vector2i(240,288)
    var bg:=ColorRect.new()
    bg.color=Color("#283b48")
    bg.size=Vector2(240,288)
    root.add_child(bg)
    sprite=Sprite2D.new()
    sprite.centered=false
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(sprite)
    var frames:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var first:PackedByteArray
    var report:Array=[]
    for t in frames.size():
        var f:Dictionary=frames[t]
        var p:=Clips.pose(f.run_angles,0,0)
        rig.evaluate(p)
        var bottom:float=-1000
        for side in ["near","far"]:
            for v in Ink.shoe_points(rig.point("foot_"+side),float(p.angles["foot_pitch_"+side])):
                bottom=maxf(bottom,v.y)
        p.root[1]=-bottom-float(f.run_flight)
        var r:Dictionary=await capture(p,"%03d"%t)
        if r.is_empty():quit(1);return
        if t==0:first=r.rgba
        if t==frames.size()-1 and first!=r.rgba:push_error("Loop mismatch");quit(1);return
        report.append({"cpu_us":r.cpu_us,"pixels":r.pixels})
    var f:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var tests:Array=[["stand",Clips.pose({},0,0)],["guard",f.clips[2].samples[0].pose],["jab",f.clips[2].samples[1].pose],["kick",f.clips[1].samples[1].pose]]
    for case in tests:
        var r:Dictionary=await capture(case[1],case[0])
        if r.is_empty():quit(1);return
    var file:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"frames":report,"static_poses":4,"loop_equal":true,"pose_unchanged":true}))
    file.close()
    print("SASUKE055B_OK")
    quit()
