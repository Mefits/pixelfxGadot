extends SceneTree
const Base=preload("res://lab/body_skin_054.gd")
const B057=preload("res://lab/body_weighted_057.gd")
const Profiles=preload("res://lab/body_pelvis_060.gd")
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
var rig
var body=Profiles.new(2)
const LINKS=[[0,2],[2,3],[0,5],[5,6],[0,8],[8,9],[0,11],[11,12]]
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
    var row={"clip":clip,"tick":tick,"lanes":[]}
    var all_parts=[]
    var baseline:Dictionary={}
    for lane in 3:
        var start=Time.get_ticks_usec()
        var parts:Array=body.make(q,p.angles,rig.rotations.head)
        if lane>0 and parts!=all_parts[0]:
            failed="geometry differs"
            return false
        var conf:Dictionary=cfg.duplicate(true)
        conf.debug=true
        if lane>0:
            conf.normal_blend=.65 if lane==1 else 1.4
            conf.normal_links=LINKS
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
        else:
            for key in ["depth","part","material","frame"]:
                if result[key]!=baseline[key]:
                    failed="changed geometry buffer "+key
                    return false
        var changed:int=0
        if lane>0:
            for j in range(0,result.rgba.size(),4):
                if result.rgba[j]!=baseline.rgba[j] or result.rgba[j+1]!=baseline.rgba[j+1] or result.rgba[j+2]!=baseline.rgba[j+2]:
                    changed+=1
                if result.rgba[j+3]!=baseline.rgba[j+3]:
                    failed="changed alpha"
                    return false
        all_parts.append(parts)
        var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
        if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
        else:sprites[lane].texture.update(im)
        var bounds=im.get_used_rect()
        if bounds.size.x==0 or bounds.position.x<=0 or bounds.end.x>=288 or bounds.position.y<=0 or bounds.end.y>=240:
            failed="empty or clipped "+str(bounds)
            return false
        row.lanes.append({"prepare_us":prepared,"raster_us":result.cpu_us,"bridge_us":wall-result.cpu_us,"body_pixels":result.body_pixels,"normal_pixels":result.normal_pixels,"changed_pixels":changed})
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
    print("BODY_061_OK poses=",records.size()," max_xy=",max_xy)
    quit()
