extends SceneTree
const Base=preload("res://lab/body_skin_054.gd")
const B057=preload("res://lab/body_weighted_057.gd")
const Profiles=preload("res://lab/body_neck_066.gd")
const Pelvis=preload("res://lab/body_pelvis_tip_067.gd")
const SizedRig=preload("res://lab/anatomy_rd/rig_proportions_067.gd")
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
var rig
var body=Profiles.new(1)
var pelvis=Pelvis.new()
var scales=[1.,.90,.80]
var rigs=[]
var pelvis_mode:bool=false
var ik_records=[]
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
        var active=rigs[0] if pelvis_mode else rigs[lane]
        active.evaluate(p)
        var local:Dictionary=active.points.duplicate(true)
        var parts:Array=pelvis.make(local,p.angles,active.rotations.head,lane) if pelvis_mode else body.make(local,p.angles,active.rotations.head)
        var s:float=1. if pelvis_mode else scales[lane]
        for id in q:
            if id not in ["elbow_far","elbow_near","hand_far","hand_near"] and local[id]!=q[id]:
                failed="unrelated FK changed"
                return false
        for side in ["far","near"]:
            var expected:Vector2=Vector2(q["shoulder_"+side])+s*(Vector2(q["hand_"+side])-Vector2(q["shoulder_"+side]))
            if expected.distance_to(local["hand_"+side])>.0001:
                failed="arm proportional FK"
                return false
        if lane>0:
            for j in parts.size():
                var allowed:Array=[0] if pelvis_mode else [2,3,4,8,9,10,14,16]
                if j not in allowed and parts[j]!=all_parts[0][j]:
                    failed="unrelated geometry changed "+str(j)
                    return false
            if pelvis_mode:
                for v in all_parts[0][0].sections:
                    if float(v[0])>=0. and v not in parts[0].sections:
                        failed="upper pelvis changed"
                        return false
        var lane_joints:Dictionary={}
        for id in local:lane_joints[id]=[local[id].x,local[id].y]
        var conf:Dictionary=cfg.duplicate(true)
        conf.debug=true
        var prepared=Time.get_ticks_usec()-start
        var before=Time.get_ticks_usec()
        var result:Dictionary=engines[lane].render(conf,parts)
        var wall=Time.get_ticks_usec()-before
        if not result.get("ok"):
            failed=str(result)
            return false
        if clip=="run053a_C" and not pelvis_mode:
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
        var hand_y:float=(float(local.hand_near.y)+float(local.hand_far.y))*.5
        var knee_y:float=(float(local.knee_near.y)+float(local.knee_far.y))*.5
        var tip:float=-float(parts[0].sections[0][0])*Vector2(local.chest-local.hips).length()
        all_parts.append(parts)
        var im=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
        if sprites[lane].texture==null:sprites[lane].texture=ImageTexture.create_from_image(im)
        else:sprites[lane].texture.update(im)
        var bounds=im.get_used_rect()
        if bounds.size.x==0 or bounds.position.x<=0 or bounds.end.x>=288 or bounds.position.y<=0 or bounds.end.y>=240:
            failed="empty or clipped "+str(bounds)
            return false
        row.lanes.append({"prepare_us":prepared,"raster_us":result.cpu_us,"bridge_us":wall-result.cpu_us,"body_pixels":result.body_pixels,"maskdiff":maskdiff,"changed_geometry_pixels":changed,"joints":lane_joints,"hand_y":hand_y,"knee_y":knee_y,"tip":tip})
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
    for s in scales:rigs.append(SizedRig.create(s,s))
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
    # Test the same three procedural punch families with explicit target
    # reporting, without changing the original shared clips.gd.
    var bank:Dictionary=Clips.defaults()
    for lane in 3:
        var active=rigs[lane]
        for spec in [["heavy",2,"hand_near",Vector2(25,-13)],["air_strike",1,"hand_near",Vector2(24,1)],["cross",2,"hand_far",Vector2.ZERO]]:
            var name:String=spec[0]
            var pose:Dictionary=bank[name].keys[spec[1]].pose.duplicate(true)
            active.evaluate(pose)
            var target:Vector2=active.point("hips")+Vector2(spec[3])
            if name=="cross":
                var original:Dictionary=bank.strike.keys[spec[1]].pose.duplicate(true)
                active.evaluate(original)
                target=active.point("hand_near")
            active.evaluate(pose)
            var before:float=active.point(spec[2]).distance_to(target)
            var aimed:Dictionary=active.aim_arm(pose,spec[2],target)
            if float(aimed.adjusted_error)>.051:
                push_error("IK failed "+str(aimed))
                quit(1)
                return
            for id in pose.angles:
                if id not in ["shoulder_near","elbow_near","shoulder_far","elbow_far"] and pose.angles[id]!=aimed.pose.angles[id]:
                    push_error("IK affected unrelated joints")
                    quit(1)
                    return
            ik_records.append({"lane":lane,"clip":name,"before_error":before,
                "requested_error":aimed.requested_error,"adjusted_error":aimed.adjusted_error,
                "clamp_distance":aimed.clamp_distance,"reach":active.reach(spec[2])})
    write_file("ik.json",ik_records)
    # Independent original-arm pelvis comparison over every run frame.
    pelvis_mode=true
    records.clear()
    solids.clear()
    var run_clip:Dictionary={}
    for clip in fixtures.clips:
        if clip.clip=="run053a_C":
            run_clip=JSON.parse_string(FileAccess.get_file_as_string(out.path_join(clip.clip+".json"))).payload.clip
    if not await capture(stand,"pelvis-stand",0):
        push_error(failed)
        quit(1)
        return
    for t in range(roundi(run_clip.duration*60)+1):
        if not await capture(Clips.sample(run_clip,t/60.,false),"pelvis-run",t):
            push_error(failed)
            quit(1)
            return
    write_file("pelvis-records.json",{"rows":records,"solids":solids})
    print("BODY_067_OK poses=192 diagnostics=4 pelvis=",records.size()," ik=",ik_records.size()," max_xy=",max_xy)
    quit()
