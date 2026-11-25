extends SceneTree
const Base=preload("res://lab/body_skin_054.gd")
const B057=preload("res://lab/body_weighted_057.gd")
const Profiles=preload("res://lab/body_trapezius_065.gd")
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
var rig
var bodies=[Profiles.new(0),Profiles.new(1),Profiles.new(2)]
const LINKS=[[0,1],[0,2],[2,3],[0,8],[8,9]]
var cfg={"width":288,"height":240,"origin":[128,200],"density":3,"ink":0xff000000,"outline":3,
    "light":[-.48,-.64,.6],"seams":false,"materials":[]}
var engines=[]
var sprites=[]
var records=[]
var out:String
var first_run=[]
var max_xy:=0.
var golden:Dictionary={}
var solids=[]
var failed:=""
func _initialize():
    call_deferred("run")

func capture(p:Dictionary,clip:String,tick:int)->bool:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    if golden.has(clip) and golden[clip].has(tick):
        for id in golden[clip][tick]:
            var xy=golden[clip][tick][id]
            max_xy=maxf(max_xy,Vector2(xy[0],xy[1]).distance_to(q[id]))
    var joints:Dictionary={}
    for id in q:joints[id]=[q[id].x,q[id].y]
    var row={"clip":clip,"tick":tick,"lanes":[],"joints":joints}
    var all_parts=[]
    var baseline:Dictionary={}
    for lane in 3:
        var start=Time.get_ticks_usec()
        var parts:Array=bodies[lane].make(q,p.angles,rig.rotations.head)
        if lane>0:
            for j in parts.size():
                if j not in [0,2,8] and parts[j]!=all_parts[0][j]:
                    failed="unrelated geometry changed"
                    return false
            for j in [0,2,8]:
                for key in ["a","b"]:
                    if parts[j][key]!=all_parts[0][j][key]:
                        failed="axis moved"
                        return false
            for j in all_parts[0][0].sections:
                if float(j[0])<=.84 and j not in parts[0].sections:
                    failed="approved trunk changed"
                    return false
        if lane==1:
            for j in [2,8]:
                if parts[j]!=all_parts[0][j]:
                    failed="B changed connectors"
                    return false
        if lane==2 and parts[0]!=all_parts[1][0]:
            failed="C changed trunk"
            return false
        var conf:Dictionary=cfg.duplicate(true)
        conf.debug=true
        var prepared=Time.get_ticks_usec()-start
        var before=Time.get_ticks_usec()
        var result:Dictionary=engines[lane].render(conf,parts)
        var wall=Time.get_ticks_usec()-before
        if not result.get("ok"):
            failed=str(result)
            return false
        if clip=="run053a_C":
            if tick==0:first_run.append(result.rgba)
            elif tick==36 and first_run[lane]!=result.rgba:
                failed="loop"
                return false
        if lane==0:baseline=result
        var changed:int=0
        var maskdiff:int=0
        if lane>0:
            for j in result.part.size():
                if (result.part[j]==0)!=(baseline.part[j]==0):
                    maskdiff+=1
                if result.part[j]!=baseline.part[j] or result.depth[j]!=baseline.depth[j]:
                    changed+=1
            if absf(float(result.body_pixels-baseline.body_pixels))>float(baseline.body_pixels)*.30:
                failed="excessive silhouette area change"
                return false
        var proxy_xy:float=0.
        var proxy_z:float=0.
        for k in 2:
            var a:Array=parts[3+6*k].a
            var root:Vector2=q["shoulder_"+["far","near"][k]]
            proxy_xy=maxf(proxy_xy,root.distance_to(Vector2(a[0],a[1])))
            proxy_z=maxf(proxy_z,absf(float(a[2])-float(all_parts[0][3+6*k].a[2]))) if lane>0 else 0.
        if proxy_xy>1.225 or proxy_z>.00001:
            failed="proxy exceeded bound"
            return false
        all_parts.append(parts)
        var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
        if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
        else:sprites[lane].texture.update(im)
        var bounds=im.get_used_rect()
        if bounds.size.x==0 or bounds.position.x<=0 or bounds.end.x>=288 or bounds.position.y<=0 or bounds.end.y>=240:
            failed="empty or clipped "+str(bounds)
            return false
        row.lanes.append({"prepare_us":prepared,"raster_us":result.cpu_us,"bridge_us":wall-result.cpu_us,"body_pixels":result.body_pixels,"maskdiff":maskdiff,"changed_geometry_pixels":changed,"proxy_xy":proxy_xy,"proxy_z":proxy_z})
    if q!=rig.points:
        failed="changed FK"
        return false
    records.append(row)
    solids.append({"clip":clip,"tick":tick,"lanes":all_parts})
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image().save_png(out.path_join("%s-%03d.png"%[clip,tick]))==OK

func write_file(name:String,value):
    var f=FileAccess.open(out.path_join(name),FileAccess.WRITE)
    f.store_string(JSON.stringify(value))
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("PixelFXBodyRaster"):
        quit(2)
        return
    out=args[0]
    var fixtures=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    for clip in fixtures.clips:
        golden[clip.clip]={}
        for s in clip.samples:golden[clip.clip][int(s.tick)]=s.expected_xy
    rig=Rig.make()
    var stand=B057.stance()
    rig.evaluate(stand)
    root.size=Vector2i(864,240)
    root.content_scale_size=root.size
    var bg=ColorRect.new()
    bg.color=Color("#34424d")
    bg.size=root.size
    root.add_child(bg)
    for lane in 3:
        var sp=Sprite2D.new()
        sp.centered=false
        sp.position.x=288*lane
        sp.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        root.add_child(sp)
        sprites.append(sp)
        engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
    for i in 4:cfg.materials.append([0xffdfd5c8,0xffbdac9e,0xff998a81,0xff726669])
    if not await capture(stand,"stand",0):
        push_error(failed)
        quit(1)
        return
    for clip in fixtures.clips:
        var path=out.path_join(clip.clip+".json")
        if FileAccess.get_sha256(path)!=clip.sha256:
            push_error("Unverified clip "+path)
            quit(1)
            return
        var d=JSON.parse_string(FileAccess.get_file_as_string(path)).payload.clip
        for t in range(roundi(d.duration*60)+1):
            var pose=Clips.sample(d,t/60.,false)
            if not await capture(pose,clip.clip,t):
                push_error("%s/%d %s"%[clip.clip,t,failed])
                quit(1)
                return
    write_file("records.json",{"rows":records,"max_xy":max_xy})
    write_file("solids.json",solids)
    if max_xy>.001 or records.size()!=192:
        quit(1)
        return
    # Separate diagnostic angle: same neutral pose with projected hip bar
    # rotated to 45 degrees. Not part of the historical 192-pose test.
    var side:Dictionary=stand.duplicate(true)
    side.angles.pelvis_turn=45.
    side.angles.shoulder_turn=45.
    if not await capture(side,"side",0):
        push_error(failed)
        quit(1)
        return
    write_file("side.json",{"row":records.back(),"solids":solids.back()})
    # Additional upper-girdle poses, not part of the historical fixture count.
    var extra:Array=[]
    for turn in [0.,45.,90.]:
        var raised:Dictionary=stand.duplicate(true)
        raised.angles.shoulder_turn=turn
        raised.angles.shoulder_far=100.
        raised.angles.shoulder_near=-100.
        if not await capture(raised,"raised",int(turn)):
            push_error(failed)
            quit(1)
            return
        extra.append({"row":records.back(),"solids":solids.back()})
    write_file("shoulder-extra.json",extra)
    print("BODY_065_OK poses=192 diagnostic=4 max_xy=",max_xy)
    quit()
