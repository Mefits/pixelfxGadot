extends SceneTree
const Base=preload("res://lab/body_skin_054.gd")
const B057=preload("res://lab/body_weighted_057.gd")
const Profiles=preload("res://lab/body_ankle_069.gd")
const Old=preload("res://lab/body_anatomy_068.gd")
const Pelvis=preload("res://lab/body_pelvis_tip_067.gd")
const SizedRig=preload("res://lab/anatomy_rd/rig_proportions_067.gd")
const Rig=preload("res://lab/anatomy_rd/rig_049.gd")
const Clips=preload("res://addons/creature/clips.gd")
var rig
var bodies=[Profiles.new(0),Profiles.new(1),Profiles.new(2)]
var source=Old.new(2)
var active
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
        active.evaluate(p)
        var local:Dictionary=active.points.duplicate(true)
        var parts:Array=bodies[lane].make(local,p.angles,active.rotations.head)
        var s:float=.90
        for id in q:
            if id not in ["elbow_far","elbow_near","hand_far","hand_near"] and local[id]!=q[id]:
                failed="unrelated FK changed"
                return false
        for side in ["far","near"]:
            for joint in ["elbow_","hand_"]:
                var expected:Vector2=Vector2(q["shoulder_"+side])+s*(Vector2(q[joint+side])-Vector2(q["shoulder_"+side]))
                if expected.distance_to(local[joint+side])>.0001:
                    failed="arm proportional FK"
                    return false
        if lane==0 and parts!=source.make(local,p.angles,active.rotations.head):
            failed="baseline mismatch"
            return false
        if lane>0:
            for j in parts.size():
                if j not in [7,13,15,17] and parts[j]!=all_parts[0][j]:
                    failed="unrelated anatomy changed "+str(j)
                    return false
            for j in [7,13,15,17]:
                for key in ["a","b","part_id","material_id"]:
                    if parts[j][key]!=all_parts[0][j][key]:
                        failed="axis or identity changed"
                        return false
            for j in [7,13]:
                for v in all_parts[0][j].sections:
                    if float(v[0])<=.75 and v not in parts[j].sections:
                        failed="calf changed"
                        return false
            for j in [15,17]:
                for i in parts[j].sections.size():
                    var v:Array=parts[j].sections[i]
                    var original:Array=all_parts[0][j].sections[i]
                    if v[0]!=original[0] or v[2]!=original[2] or v[4]!=original[4] or (v[0]>=.72 and v!=original):
                        failed="plantar edge or distal toe changed"
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
    active=Profiles.make_rig()
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
    var ankle_extra:Array=[]
    for pitch in [-65,-35,0,35,65]:
        var test:Dictionary=stand.duplicate(true)
        test.angles.foot_pitch_near=float(pitch)
        test.angles.foot_pitch_far=float(pitch)
        if not await capture(test,"ankle",pitch+65):
            push_error(failed)
            quit(1)
            return
        ankle_extra.append({"row":records.back(),"solids":solids.back()})
    write_file("ankle-extra.json",ankle_extra)
    print("BODY_069_OK poses=192 diagnostic=9 max_xy=",max_xy)
    quit()
