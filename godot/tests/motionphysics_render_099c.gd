extends SceneTree
const Common=preload("res://lab/ragdoll_common_099c.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const LABELS=["A / CHEST + SHORT RELEASE","B / CHEST + POSE HOLD","C / PELVIS + POSE HOLD + SLIDE"]
const NAMES=["profileA","profileB","profileC"]
const LEAD:int=18
var cfg={"width":520,"height":300,"origin":[390,245],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e]]}
func _initialize():call_deferred("run")
func fail(msg:String)->void:
    push_error(msg)
    quit(1)
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    var out:String=args[0]
    var traces:Array=[]
    var models:Array=[]
    var initial:Array=[]
    var min_y:float=0.
    for name in NAMES:
        var rows=JSON.parse_string(FileAccess.get_file_as_string(out.path_join(name+".json")))
        if not rows is Array or rows.size()!=Common.N*2:
            fail("bad trace "+name)
            return
        traces.append(rows)
        var m=Common.make_model()
        models.append(m)
        initial.append(Common.state(m))
        for t in Common.N:
            Common.load_state(m,rows[t*2+1].state)
            m.pose()
            for pt in m.rig.points.values():min_y=minf(min_y,Vector2(pt).y)
        Common.load_state(m,initial[-1])
    var origin_y:int=maxi(245,ceili(-min_y*3.)+54)
    var view_h:int=origin_y+55
    cfg.height=view_h
    root.size=Vector2i(1560,view_h+32)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    bg.z_index=-2
    root.add_child(bg)
    var bodies:Array=[]
    var engines:Array=[]
    var sprites:Array=[]
    var labels:Array=[]
    var grids:Array=[]
    var arrows:Array=[]
    for lane in 3:
        bodies.append(Body.new(2))
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
        var sp=Sprite2D.new()
        sp.centered=false
        sp.position=Vector2(lane*520,24)
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        root.add_child(sp)
        sprites.append(sp)
        var label=Label.new()
        label.text=LABELS[lane]
        label.position=Vector2(lane*520+8,1)
        label.add_theme_font_size_override("font_size",14)
        root.add_child(label)
        var line=Line2D.new()
        line.width=1.
        line.default_color=Color("#8ca1aa")
        line.z_index=-1
        var y:float=origin_y+24.+models[lane].floor_y*3.
        line.points=PackedVector2Array([Vector2(lane*520+8,y),Vector2(lane*520+512,y)])
        root.add_child(line)
        var grid=Line2D.new()
        grid.width=1.
        grid.default_color=Color("#8ca1aa")
        root.add_child(grid)
        grids.append(grid)
        var meter=Label.new()
        meter.position=Vector2(lane*520+8,view_h-14)
        meter.add_theme_font_size_override("font_size",13)
        root.add_child(meter)
        labels.append(meter)
        var arrow=Line2D.new()
        arrow.default_color=Color("#ffb66d")
        arrow.width=2.
        root.add_child(arrow)
        arrows.append(arrow)
    var caption=Label.new()
    caption.position=Vector2(8,view_h+8)
    caption.add_theme_font_size_override("font_size",14)
    root.add_child(caption)
    var records:Array=[]
    for t in Common.N+LEAD:
        var frame:Dictionary={"tick":t,"lanes":[]}
        caption.text="60 Hz / %03d / REFERENCE-3 FLIGHT POSE / STAGED RELEASE + PHYSICAL LANDING"%t
        for lane in 3:
            var m=models[lane]
            var state:Array=initial[lane] if t<LEAD else traces[lane][(t-LEAD)*2+1].state
            Common.load_state(m,state)
            var p:Dictionary=m.pose()
            var rig=m.rig
            var q:Dictionary=rig.points
            var com:Vector2=m.center_of_mass()
            var metrics:Dictionary=Common.validate(m)
            metrics["fk_error"]=m.pose_error
            metrics["com"]=[com.x,com.y]
            metrics["hip"]=[q.hips.x,q.hips.y]
            metrics["chest"]=[q.chest.x,q.chest.y]
            var min_x:float=INF
            var max_x:float=-INF
            for pt in q.values():
                min_x=minf(min_x,Vector2(pt).x)
                max_x=maxf(max_x,Vector2(pt).x)
            var ox:float=clampf(390.-minf(0.,com.x+12.)*3.,54.-min_x*3.,466.-max_x*3.)
            cfg.origin=[ox,float(origin_y)]
            var parts:Array=bodies[lane].make(q,p.angles,rig.rotations.head)
            for i in [0,2,3,8,9]:parts[i].material_id=1
            for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
            var result:Dictionary=engines[lane].render(cfg,parts)
            if not result.get("ok",false):
                fail(str(result))
                return
            var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
            var bounds=im.get_used_rect()
            if bounds.size.x==0 or bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=520 or bounds.end.y>=view_h:
                fail("clipped "+str([lane,t,bounds]))
                return
            metrics["raster_floor_overlap"]=bounds.end.y-(origin_y+m.floor_y*3.)
            if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
            else:sprites[lane].texture.update(im)
            var marks:=PackedVector2Array()
            var fy:float=origin_y+24.+m.floor_y*3.
            for k in range(floori((-ox)/30.)-1,ceili((520.-ox)/30.)+1):
                var x:float=ox+30.*k
                if x<8. or x>512.:continue
                var px:float=lane*520+x
                marks.append(Vector2(px,fy))
                marks.append(Vector2(px,fy+5))
                marks.append(Vector2(px,fy))
            grids[lane].points=marks
            labels[lane].text="COM X %+.1f  /  10-unit marks"%com.x
            arrows[lane].visible=t>=LEAD and t<LEAD+5
            if arrows[lane].visible:
                var target:Vector2=q.hips if lane==2 else q.chest
                var pt:Vector2=Vector2(lane*520+ox,origin_y+24.)+target*3.
                arrows[lane].points=PackedVector2Array([pt+Vector2(32,0),pt,pt+Vector2(8,-5),pt,pt+Vector2(8,5)])
            frame.lanes.append(metrics)
        records.append(frame)
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(out.path_join("frame-%03d.png"%t))!=OK:
            fail("capture failed")
            return
    var f=FileAccess.open(out.path_join("records.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(records))
    f.close()
    print("MOTIONPHYSICS_099C_RENDER_OK frames=",records.size())
    quit()
