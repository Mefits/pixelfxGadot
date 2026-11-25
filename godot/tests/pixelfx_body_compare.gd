extends SceneTree
const RIG=preload("res://lab/anatomy_rd/rig_049.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const INK=preload("res://lab/ink_051.gd")
const ORIGINAL=preload("res://addons/pixelfx/original_runtime.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
class Board extends Node2D:
    var joints:Dictionary={}
    var feet:Dictionary={}
    var raster:Dictionary={}
    var flight:float=0
    func _draw()->void:
        for i in 2:
            var x:float=i*260.0
            draw_rect(Rect2(x,0,260,230),Color("#273b4b"))
            draw_line(Vector2(x+4,210),Vector2(x+256,210),Color("#738a8f"))
        draw_set_transform(Vector2(125,210),0,Vector2.ONE*3.4)
        if not joints.is_empty():INK.actor(self,joints,true,feet)
        draw_set_transform(Vector2.ZERO)
        if raster.is_empty():return
        # Draw the original returned packed RGBA pixels, with no skin edits.
        # Integer display scale, nearest-pixel rectangles, original palette.
        var scale_px:float=4.0
        var origin:=Vector2(385,210-float(raster.y1+1)*scale_px-flight*3.4)
        for i in int(raster.n):
            var color:int=int(raster.color[i])
            var p:=Vector2(float(raster.xs[i]),float(raster.ys[i]))
            draw_rect(Rect2(origin+p*scale_px,Vector2.ONE*scale_px),Color8(color&255,(color>>8)&255,(color>>16)&255,(color>>24)&255))
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    var out:String=args[0]
    var data:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var rt=ORIGINAL.new()
    if not rt.open():push_error(rt.error);quit(1);return
    var stand:Dictionary=rt.pose({})
    if int(stand.get("n",0))<=0:push_error("Original pose failed");quit(1);return
    var rig=RIG.make()
    var board:=Board.new()
    root.add_child(board)
    root.content_scale_size=Vector2i(520,230)
    root.size=Vector2i(520,230)
    var timings:Array[float]=[]
    var report:Array=[]
    var first:Dictionary={}
    var last:Dictionary={}
    for t in data.size():
        var f:Dictionary=data[t]
        var p:=CLIPS.pose(f.run_angles,0,0)
        rig.evaluate(p)
        var bottom:float=-1000.0
        for side in ["near","far"]:
            for vertex in INK.shoe_points(rig.point("foot_"+side),float(p.angles["foot_pitch_"+side])):
                bottom=maxf(bottom,vertex.y)
        p.root[1]=-bottom-float(f.run_flight)
        rig.evaluate(p)
        var hips:Vector2=rig.point("hips")
        var spine:Vector2=rig.point("chest")-hips
        var tilt:float=atan2(spine.x,-spine.y)
        # Original body's 15px arms / 16.9px legs vs Lab's 20.8 / 22.36.
        # Map positions around pelvis, not absolute image coordinates.
        var lean:float=13.0*tan(tilt)
        var s:float=.75
        var pelvis:=Vector2(lean*.2,hips.y*s)
        var q:Dictionary={"lean":lean,"crouch":19.7+pelvis.y,"turn":deg_to_rad(12.0),"y":-1,
            "fz":2.5,"bz":-2.5,"fzz":2.4,"bzz":-2.4}
        for side in ["near","far"]:
            var h:Vector2=pelvis+(rig.point("hand_"+side)-hips)*s
            var a:Vector2=pelvis+(rig.point("foot_"+side)-hips)*s
            if side=="near":
                q.merge({"fx":h.x,"fy":h.y,"ffx":a.x,"ffy":a.y-1.8,"toeF":float(p.angles.foot_pitch_near)>20},true)
            else:
                q.merge({"bx":h.x,"by":h.y,"fbx":a.x,"fby":a.y-1.8,"toeB":float(p.angles.foot_pitch_far)>20},true)
        var start:int=Time.get_ticks_usec()
        var r:Dictionary=rt.pose(q)
        timings.append((Time.get_ticks_usec()-start)/1000.0)
        if int(r.get("n",0))<=0 or r.n!=r.xs.size() or r.n!=r.ys.size() or r.n!=r.color.size():
            push_error("Original raster failed "+str(t));quit(1);return
        if t==0:first=r.duplicate(true)
        last=r
        board.joints=rig.points.duplicate()
        board.feet={"foot_near":p.angles.foot_pitch_near,"foot_far":p.angles.foot_pitch_far}
        board.raster=r
        board.flight=float(f.run_flight)
        report.append({"tick":t,"input":q,"pixels":r.n,"bounds":[r.x0,r.y0,r.x1,r.y1]})
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.get_size()!=Vector2i(520,230) or img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    if first!=last:push_error("Original raster seam mismatch");quit(1);return
    timings.sort()
    var file:=FileAccess.open(out.path_join("body-report.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"backend":"PixelFXOriginal QuickJS posed","original_palette":true,"frames":report,"seam_equal":true,"pose_bridge_p95_ms":timings[int(timings.size()*.95)],"stand_pixels":stand.n}, "  "))
    file.close()
    print("PIXELFX_BODY_COMPARE_OK")
    quit()
