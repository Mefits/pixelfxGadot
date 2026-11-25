extends SceneTree
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
const INK=preload("res://lab/anatomy_rd/ink_readable.gd")
const INK46=preload("res://lab/anatomy_rd/ink_046.gd")
const CHAINS={"hand_near":["shoulder_near","elbow_near"],"hand_far":["shoulder_far","elbow_far"],"foot_near":["thigh_near","knee_near"],"foot_far":["thigh_far","knee_far"]}
static func solve(rig,pose:Dictionary,targets:Dictionary)->Dictionary:
    rig.evaluate(pose)
    for tip in targets:
        var chain:Array=CHAINS[tip]
        var upper:Dictionary=rig.joints[rig.ids[chain[0]]]
        var first:Vector2=rig.joints[rig.ids[chain[1]]].offset
        var last:Vector2=rig.joints[rig.ids[tip]].offset
        var d:Array=targets[tip]
        var ray:=Vector2(d[0],d[1])
        if ray.length_squared()<.000001:ray=Vector2.DOWN*.01
        var a:=first.length()
        var b:=last.length()
        var reach:=clampf(ray.length()*(a+b),absf(a-b)+.0001,a+b-.0001)
        var along:float=(a*a-b*b+reach*reach)/(2.0*reach)
        var axis:=ray.normalized()
        var mid:=axis*along+axis.orthogonal()*sqrt(maxf(0,a*a-along*along))*float(d[2])
        # Vector2.orthogonal is clockwise in Godot; use explicit sign matching source cross.
        mid=axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,a*a-along*along))*float(d[2])
        var proximal:=mid.angle()-first.angle()
        var distal:=(axis*reach-mid).angle()-last.angle()
        pose.angles[chain[0]]=rad_to_deg(wrapf(proximal-float(rig.rotations[upper.parent]),-PI,PI))
        pose.angles[chain[1]]=rad_to_deg(wrapf(distal-proximal,-PI,PI))
    rig.evaluate(pose)
    return pose
class Board extends Node2D:
    var pts:Array=[]
    var skins:Array=[]
    func _draw()->void:
        for i in pts.size():
            var x:=float(i*240)
            draw_rect(Rect2(x,0,240,230),Color("#273b4b"))
            draw_line(Vector2(x+4,210),Vector2(x+236,210),Color("#738a8f"))
            draw_set_transform(Vector2(x+103,210),0,Vector2.ONE*3.4)
            if skins[i]:INK46.actor(self,pts[i],0,"hand_near")
            else:INK.actor(self,pts[i],0,"hand_near")
            draw_set_transform(Vector2.ZERO)
# Lab-only adapter: existing SDK accepts linear easing but not hold fields.
# Duplicate the outgoing pose just before the next exposure; no runtime edits.
static func hold_clip(original:Dictionary,indices:Array)->Dictionary:
    var result:=original.duplicate(true)
    result.keys=[]
    for j in indices.size():
        var k:int=indices[j]
        if j>0:
            var previous:int=indices[j-1]
            result.keys.append({"t":float(original.keys[k].t)-1.0/6000.0,"pose":original.keys[previous].pose.duplicate(true)})
        result.keys.append(original.keys[k].duplicate(true))
    return result

static func choose_exposures(rate:int,last:int,contact:int,support:Array,events:Array=[],holds:Array=[])->Array:
    var fixed:Dictionary={0:true,last:true,contact:true}
    for e in events:fixed[int(e.tick)]=true
    # Contact and support transitions must never be dropped.
    for k in range(1,support.size()):
        if support[k]!=support[k-1]:
            fixed[k-1]=true
            fixed[k]=true
    if rate==0:
        for k in range(last+1):fixed[k]=true
    elif rate>0:
        var j:=0
        while float(j)*60.0/rate<last:
            fixed[roundi(float(j)*60.0/rate)]=true
            j+=1
    else:
        # Smooth setup, skip transitional drawings in acceleration, hold the
        # contact silhouette, then recover with more spaced drawings.
        for k in (holds if not holds.is_empty() else [3,6,9,12,14,17,20,24,28,32,35]):
            k=int(k)
            if k<=last:fixed[k]=true
    var indices:=fixed.keys()
    indices.sort()
    return indices

# Astra-style geometric key reduction, independent of exposure selection.
# Error is against the uncompressed clip using its actual sampler at 120Hz.
static func reduce_clip(rig,original:Dictionary,support:Array,contact:int,tolerance:float)->Dictionary:
    var keys:Array=original.keys
    var fixed:Dictionary={0:true,keys.size()-1:true,contact:true}
    if contact>0:fixed[contact-1]=true
    for i in range(1,support.size()):
        if support[i]!=support[i-1]:
            fixed[i-1]=true
            fixed[i]=true
    var expected:Array=[]
    for t in range((keys.size()-1)*2+1):
        rig.evaluate(CLIPS.sample(original,t/120.0,false))
        expected.append(rig.points.duplicate())
    var bounds:=fixed.keys()
    bounds.sort()
    var work:Array=[]
    for i in range(1,bounds.size()):work.append([bounds[i-1],bounds[i]])
    var out:=original.duplicate(true)
    while not work.is_empty():
        var span:Array=work.pop_back()
        var a:int=span[0]
        var b:int=span[1]
        out.keys=[keys[a],keys[b]]
        var worst:=tolerance
        var split:=-1
        if b-a<2:continue
        for tick in range(a*2+1,b*2):
            rig.evaluate(CLIPS.sample(out,tick/120.0,false))
            for id in rig.points:
                var err:float=rig.point(id).distance_to(expected[tick][id])
                if err>worst:
                    worst=err
                    split=clampi(roundi(tick/2.0),a+1,b-1)
        if split>=0:
            fixed[split]=true
            work.append([a,split])
            work.append([split,b])
    var selected:=fixed.keys()
    selected.sort()
    out.keys=[]
    for i in selected:out.keys.append(keys[i].duplicate(true))
    var error:=0.0
    for t in expected.size():
        rig.evaluate(CLIPS.sample(out,t/120.0,false))
        for id in rig.points:error=maxf(error,rig.point(id).distance_to(expected[t][id]))
    return {"clip":out,"max_error_px":error,"tolerance_px":tolerance}

func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    var out:String=args[0]
    var cfg:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var rig=RIG.humanoid()
    var board:=Board.new()
    root.add_child(board)
    var capture_size:=Vector2i(cfg.size()*240,230)
    root.content_scale_size=capture_size
    root.size=capture_size
    for v in cfg:board.skins.append(v.get("skin46",false))
    var all_points:Array=[]
    var report:Array=[]
    var count:=0
    for i in cfg.size():
        var v:Dictionary=cfg[i]
        var poses:Array=[]
        var keys:Array=[]
        var max_pen:=0.0
        var max_root_adjust:=0.0
        var max_support_error:=0.0
        var max_joint_step:=0.0
        var previous:Dictionary={}
        var max_bone_error:=0.0
        var locks:Dictionary={}
        var support_frames:Array=[]
        for t in v.frames.size():
            var f:Dictionary=v.frames[t]
            var tilt:float=clampf(f.tilt,-65,65)
            var hip_extra:float=f.get("hip_extra",0.0)
            var p:=CLIPS.pose({"hips":tilt*.25+hip_extra,"chest":tilt*.75-hip_extra,"head":-tilt*.45},f.root[0],f.root[1])
            p=solve(rig,p,f.targets)
            # Foot correction uses actual source ankle height and a fixed planted point.
            var goals:Dictionary={}
            for j in 2:
                var tip:String=["foot_near","foot_far"][j]
                var foot:Array=f.feet[j]
                var support:bool=absf(foot[1])<=1.8
                if support:
                    if not locks.has(tip):locks[tip]=Vector2(rig.point(tip).x,0)
                    goals[tip]=locks[tip]
                else:
                    locks.erase(tip)
                    if rig.point(tip).y>0:goals[tip]=Vector2(rig.point(tip).x,0)
            support_frames.append(locks.duplicate())
            var shift:=Vector2.ZERO
            for iteration in 12:
                for tip in goals:
                    var chain:Array=CHAINS[tip]
                    var center:Vector2=goals[tip]-rig.point(chain[0])
                    var reach:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()-.002
                    if shift.distance_to(center)>reach:shift=center+(shift-center).limit_length(reach)
            p.root[0]+=shift.x
            p.root[1]+=shift.y
            max_root_adjust=maxf(max_root_adjust,shift.length())
            rig.evaluate(p)
            var targets:Dictionary={}
            for tip in goals:
                var chain:Array=CHAINS[tip]
                var span:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
                var ray:Vector2=(goals[tip]-rig.point(chain[0]))/span
                targets[tip]=[ray.x,ray.y,f.targets[tip][2]]
            p=solve(rig,p,targets)
            var penetration:=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            max_pen=maxf(max_pen,penetration)
            p.root[1]-=penetration
            rig.evaluate(p)
            for tip in locks:max_support_error=maxf(max_support_error,rig.point(tip).distance_to(locks[tip]))
            for joint in rig.joints:
                if not joint.parent.is_empty():
                    max_bone_error=maxf(max_bone_error,absf(rig.point(joint.id).distance_to(rig.point(joint.parent))-joint.offset.length()))
                if previous.has(joint.id):max_joint_step=maxf(max_joint_step,rig.point(joint.id).distance_to(previous[joint.id]))
            previous=rig.points.duplicate()
            poses.append(previous)
            keys.append({"t":t/60.0,"pose":p})
        
        count=maxi(count,poses.size())
        var events:Array=[]
        for e in v.get("events",[{"tick":v.contact,"anchor":"hand_near"}]):
            events.append({"t":float(e.tick)/60.0,"kind":"strike","anchor":e.anchor})
        var clip:={"duration":float(keys.size()-1)/60.0,"loop":false,"easing":"linear","keys":keys,"events":events}
        var original:=clip.duplicate(true)
        var exposure_indices:Array=choose_exposures(int(v.get("cadence",0)),keys.size()-1,int(v.contact),support_frames,v.get("events",[]),v.get("holds",[]))
        if int(v.get("cadence",0))!=0:clip=hold_clip(original,exposure_indices)
        var sampled:Array=[]
        var max_sampler_error:=0.0
        var max_cadence_error:=0.0
        var max_cadence_support:=0.0
        var max_cadence_floor:=0.0
        var max_cadence_step:=0.0
        var held_index:=0
        for t in keys.size():
            rig.evaluate(CLIPS.sample(clip,t/60.0,false))
            while held_index+1<exposure_indices.size() and exposure_indices[held_index+1]<=t:held_index+=1
            var expected_index:int=exposure_indices[held_index]
            for id in rig.points:
                max_sampler_error=maxf(max_sampler_error,rig.point(id).distance_to(poses[expected_index][id]))
                max_cadence_error=maxf(max_cadence_error,rig.point(id).distance_to(poses[t][id]))
                if t>0:max_cadence_step=maxf(max_cadence_step,rig.point(id).distance_to(sampled[-1][id]))
            for tip in support_frames[t]:max_cadence_support=maxf(max_cadence_support,rig.point(tip).distance_to(support_frames[t][tip]))
            max_cadence_floor=maxf(max_cadence_floor,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            sampled.append(rig.points.duplicate())
        if max_sampler_error>.001:push_error("Sampler mismatch");quit(1);return
        all_points.append(sampled)
        var entry:={"schema":1,"id":"mocap_style_"+str(i),"name":v.label,"kind":"animation","source":"authored","payload":{"slot":"strike","clip":clip}}
        if not VALID.new().validate(entry).ok:push_error("Invalid SDK "+str(i));quit(1);return
        var file:=FileAccess.open(out.path_join("clip_"+str(i)+".json"),FileAccess.WRITE)
        file.store_string(JSON.stringify(entry));file.close()
        if v.has("cadence") and int(v.cadence)==0 and not v.get("combo",false):
            var reduced:=reduce_clip(rig,original,support_frames,int(v.contact),.6)
            var reduced_entry:=entry.duplicate(true)
            reduced_entry.id="mocap_f_reduced"
            reduced_entry.name="F reduced (linear)"
            reduced_entry.payload.clip=reduced.clip
            if not VALID.new().validate(reduced_entry).ok or float(reduced.max_error_px)>.6001:push_error("Reduction gate failed");quit(1);return
            var reduced_file:=FileAccess.open(out.path_join("clip_reduced.json"),FileAccess.WRITE)
            reduced_file.store_string(JSON.stringify(reduced_entry));reduced_file.close()
            var reduced_report:=FileAccess.open(out.path_join("reduction-report.json"),FileAccess.WRITE)
            reduced_report.store_string(JSON.stringify({"original_keys":original.keys.size(),"reduced_keys":reduced.clip.keys.size(),"max_error_px":reduced.max_error_px,"tolerance_px":reduced.tolerance_px}));reduced_report.close()
        var event_checks:Array=[]
        for e in events:
            var tick:=roundi(float(e.t)*60)
            var wrist:Vector2=sampled[tick][e.anchor]
            event_checks.append({"tick":tick,"anchor":e.anchor,"point":[wrist.x,wrist.y],"error_px":wrist.distance_to(poses[tick][e.anchor])})
        report.append({"event_checks":event_checks,"variant":v.label,"duration":clip.duration,"contact_s":float(v.contact)/60.0,"frames":keys.size(),"sdk_keys":clip.keys.size(),"exposure_indices":exposure_indices,"exposure_count":exposure_indices.size(),"cadence_error_px":max_cadence_error,"cadence_support_error_px":max_cadence_support,"cadence_floor_px":max_cadence_floor,"cadence_max_step_px":max_cadence_step,"floor_pen_before_final_clamp":max_pen,"root_adjustment_px":max_root_adjust,"support_error_px":max_support_error,"bone_error_px":max_bone_error,"max_joint_step_px":max_joint_step,"sampler_error_px":max_sampler_error,"contact_hand_px":[poses[v.contact]["hand_near"].x,poses[v.contact]["hand_near"].y]})
    for t in count:
        board.pts=[]
        for v in all_points:board.pts.append(v[mini(t,v.size()-1)])
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.get_size()!=capture_size or img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    var f:=FileAccess.open(out.path_join("render-report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "));f.close()
    print("MOCAP_STYLE_OK")
    quit()
