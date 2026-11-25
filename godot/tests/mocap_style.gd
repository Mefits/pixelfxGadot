extends SceneTree
const RIG=preload("res://addons/creature/rig.gd")
const RIG49=preload("res://lab/anatomy_rd/rig_049.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
const INK=preload("res://lab/anatomy_rd/ink_readable.gd")
const INK46=preload("res://lab/anatomy_rd/ink_046.gd")
const INK51=preload("res://lab/ink_051.gd")
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
    var shells:Array=[]
    var foot_angles:Array=[]
    var bags:Array=[]
    func _draw()->void:
        for i in pts.size():
            var x:=float(i*240)
            draw_rect(Rect2(x,0,240,230),Color("#273b4b"))
            draw_line(Vector2(x+4,210),Vector2(x+236,210),Color("#738a8f"))
            draw_set_transform(Vector2(x+(70 if bags[i] else 103),210),0,Vector2.ONE*3.4)
            if bags[i]:
                draw_line(Vector2(41,-60),Vector2(41,-53),Color("#9c9a8a"),.65)
                draw_rect(Rect2(36,-53,10,47),Color("#75634f"))
                draw_circle(Vector2(41,-53),5,Color("#75634f"))
                draw_circle(Vector2(41,-6),5,Color("#75634f"))
                draw_line(Vector2(36,-48),Vector2(36,-10),Color("#c0aa87"),.65)
                for y in [-47,-33,-19]:draw_line(Vector2(36,y),Vector2(46,y),Color("#a58b67"),.45)
            if int(shells[i])>0:INK51.actor(self,pts[i],int(shells[i])==2,foot_angles[i])
            elif skins[i]:INK46.actor(self,pts[i],0,"hand_near")
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
    for v in cfg:
        board.skins.append(v.get("skin46",false))
        board.shells.append(v.get("skin51",0))
        board.bags.append(v.get("bag",false))
    var all_points:Array=[]
    var all_foot_angles:Array=[]
    var report:Array=[]
    var count:=0
    for i in cfg.size():
        var v:Dictionary=cfg[i]
        rig=RIG49.make() if v.has("shoulder_mode") else RIG.humanoid()
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
        var toe_frames:Array=[]
        var foot_samples:Array=[]
        var max_sole_pen:=0.0
        var max_toe_error:=0.0
        var max_heel_lift:=0.0
        var release_origin:=Vector2.ZERO
        for t in v.frames.size():
            var f:Dictionary=v.frames[t]
            if v.get("run_cycle",false):
                var run_pose:=CLIPS.pose(f.run_angles,0,0)
                rig.evaluate(run_pose)
                var bottom:float=-1000.0
                for tip in ["foot_near","foot_far"]:
                    for vertex in INK51.shoe_points(rig.point(tip),float(run_pose.angles["foot_pitch_"+tip.trim_prefix("foot_")])):
                        bottom=maxf(bottom,vertex.y)
                # In-place cycle: ground the lowest sole or add authored flight.
                # Not a world-space locomotion or no-slip simulation.
                run_pose.root[1]=-bottom-float(f.run_flight)
                rig.evaluate(run_pose)
                for joint in rig.joints:
                    if not joint.parent.is_empty():
                        max_bone_error=maxf(max_bone_error,absf(rig.point(joint.id).distance_to(rig.point(joint.parent))-joint.offset.length()))
                    if previous.has(joint.id):max_joint_step=maxf(max_joint_step,rig.point(joint.id).distance_to(previous[joint.id]))
                previous=rig.points.duplicate()
                poses.append(previous)
                support_frames.append({})
                toe_frames.append({})
                keys.append({"t":t/60.0,"pose":run_pose})
                continue
            var tilt:float=clampf(f.tilt,-65,65)
            var hip_extra:float=f.get("hip_extra",0.0)
            var p:=CLIPS.pose({"hips":tilt*.25+hip_extra,"chest":tilt*.75-hip_extra,"head":-tilt*.45},f.root[0],f.root[1])
            if f.has("shoulder_turn"):p.angles["shoulder_turn"]=f.shoulder_turn
            if f.has("pelvis_turn"):p.angles["pelvis_turn"]=f.pelvis_turn
            if f.has("foot_pitch_near"):
                p.angles["foot_pitch_near"]=f.foot_pitch_near
                p.angles["foot_pitch_far"]=f.foot_pitch_far
            p=solve(rig,p,f.targets)
            # Foot correction uses actual source ankle height and a fixed planted point.
            var goals:Dictionary={}
            var toe_goals:Dictionary={}
            var feet:Dictionary={"foot_near":float(f.get("foot_pitch_near",0)),"foot_far":float(f.get("foot_pitch_far",0))}
            for j in 2:
                var tip:String=["foot_near","foot_far"][j]
                var foot:Array=f.feet[j]
                var support:bool=absf(foot[1])<=1.8
                if support:
                    if not locks.has(tip):locks[tip]=Vector2(rig.point(tip).x,0)
                    goals[tip]=locks[tip]
                    if int(v.get("foot51",0))==2:
                        var toe:Vector2=locks[tip]+Vector2(4,0)
                        toe_goals[tip]=toe
                        goals[tip]=toe-Vector2(4,0).rotated(deg_to_rad(float(feet[tip])))
                else:
                    locks.erase(tip)
                    if rig.point(tip).y>0:goals[tip]=Vector2(rig.point(tip).x,0)
            # Photo C: position the support hip above the planted ankle
            # with a slight knee bend. This is a kinematic support proxy,
            # not an assertion of dynamic physical balance.
            var reference_weight:float=float(f.get("reference_support_weight",0))
            if reference_weight>0 and goals.has("foot_near") and not locks.has("foot_far"):
                var ankle:Vector2=goals["foot_near"]
                var hip:Vector2=rig.point("thigh_near")
                var desired:Vector2=ankle+Vector2(float(f.get("reference_support_dx",.8)),-float(f.get("reference_support_height",21.4)))
                var delta:Vector2=(desired-hip)*reference_weight
                p.root[0]+=delta.x
                p.root[1]+=delta.y
                rig.evaluate(p)
            var support_targets:Dictionary={}
            for tip in locks:support_targets[tip]=goals[tip]
            support_frames.append(support_targets)
            toe_frames.append(toe_goals)
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
            if f.has("release_blend") and not locks.has("foot_far"):
                var release:float=float(f.release_blend)
                if release<=.00001 and previous.has("foot_far"):
                    release_origin=previous["foot_far"]
                var hip:Vector2=rig.point("thigh_far")
                var span:float=rig.joints[rig.ids["knee_far"]].offset.length()+rig.joints[rig.ids["foot_far"]].offset.length()
                var desired:Vector2=release_origin.lerp(rig.point("foot_far"),release)
                var ray:Vector2=(desired-hip)/span
                p=solve(rig,p,{"foot_far":[ray.x,ray.y,f.targets["foot_far"][2]]})
            var penetration:=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            if int(v.get("foot51",0))>0:
                for tip in feet:
                    for vertex in INK51.shoe_points(rig.point(tip),float(feet[tip])):penetration=maxf(penetration,vertex.y)
            max_pen=maxf(max_pen,penetration)
            p.root[1]-=penetration
            rig.evaluate(p)
            if f.has("aim_tip"):
                var tip:String=f.aim_tip
                var chain:Array=CHAINS[tip]
                var shoulder:Vector2=rig.point(chain[0])
                var span:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
                var goal:=Vector2(f.aim_point[0],f.aim_point[1])
                var ray:Vector2=(rig.point(tip).lerp(goal,float(f.aim_weight))-shoulder)/span
                # Avoid locked-out elbow, preserve current bend pole, no scaling.
                ray=ray.limit_length(.985)
                p=solve(rig,p,{tip:[ray.x,ray.y,f.targets[tip][2]]})
            for tip in locks:max_support_error=maxf(max_support_error,rig.point(tip).distance_to(goals[tip]))
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
        var clip:={"duration":float(keys.size()-1)/60.0,"loop":bool(v.get("run_cycle",false)),"easing":"linear","keys":keys,"events":events}
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
            var pose_angles:Dictionary=CLIPS.sample(clip,t/60.0,false).angles
            var pitches:Dictionary={"foot_near":float(pose_angles.get("foot_pitch_near",0)),"foot_far":float(pose_angles.get("foot_pitch_far",0))}
            foot_samples.append(pitches)
            for tip in pitches:
                for vertex in INK51.shoe_points(rig.point(tip),float(pitches[tip])):max_sole_pen=maxf(max_sole_pen,vertex.y)
            for tip in toe_frames[t]:
                var toe:Vector2=rig.point(tip)+Vector2(4,0).rotated(deg_to_rad(float(pitches[tip])))
                var heel:Vector2=rig.point(tip)+Vector2(-2,0).rotated(deg_to_rad(float(pitches[tip])))
                max_toe_error=maxf(max_toe_error,toe.distance_to(toe_frames[t][tip]))
                max_heel_lift=maxf(max_heel_lift,-heel.y)
            sampled.append(rig.points.duplicate())
        if max_sampler_error>.001:push_error("Sampler mismatch");quit(1);return
        all_points.append(sampled)
        all_foot_angles.append(foot_samples)
        var entry:={"schema":1,"id":"mocap_style_"+str(i),"name":v.label,"kind":"animation","source":"authored","payload":{"slot":"walk" if v.get("run_cycle",false) else "strike","clip":clip}}
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
            var check:Dictionary={"tick":tick,"anchor":e.anchor,"point":[wrist.x,wrist.y],"error_px":wrist.distance_to(poses[tick][e.anchor])}
            if v.get("bag",false):
                var chain:Array=CHAINS[e.anchor]
                var shoulder:Vector2=sampled[tick][chain[0]]
                var elbow:Vector2=sampled[tick][chain[1]]
                var fist:Vector2=wrist+Vector2(4,-.9) if str(e.anchor).begins_with("foot") else wrist+(wrist-elbow).normalized()*2.3
                check["shoulder"]=[shoulder.x,shoulder.y]
                check["chest"]=[sampled[tick]["chest"].x,sampled[tick]["chest"].y]
                if str(e.anchor).begins_with("foot") and v.has("foot51"):
                    var pitch:float=foot_samples[tick][e.anchor]
                    var outline:Array=INK51.shoe_points(wrist,pitch)
                    fist=outline[0]
                    for vertex in outline:
                        if vertex.x>fist.x:fist=vertex
                    check["foot_pitch_deg"]=pitch
                check["fist_tip"]=[fist.x,fist.y]
                check["bag_front_gap_px"]=36.0-fist.x
                check["limb_extension_px"]=shoulder.distance_to(wrist)
                if str(e.anchor).begins_with("hand"):check["arm_extension_px"]=shoulder.distance_to(wrist)
                else:
                    check["hip"]=[shoulder.x,shoulder.y]
                    var q:Dictionary=sampled[tick]
                    var torso:Vector2=q.chest-q.hips
                    var leg:Vector2=wrist-shoulder
                    var support_hip:Vector2=q.thigh_near
                    var support_ankle:Vector2=q.foot_near
                    check["torso_back_lean_deg"]=rad_to_deg(atan2(-torso.x,-torso.y))
                    check["kick_elevation_deg"]=rad_to_deg(atan2(-leg.y,leg.x))
                    check["support_hip_ankle_dx"]=support_hip.x-support_ankle.x
                    check["support_leg_extension_px"]=support_hip.distance_to(support_ankle)
                    var knee:Vector2=q.knee_far
                    var support_knee:Vector2=q.knee_near
                    check["kick_knee_bend_deg"]=180.0-absf(rad_to_deg((shoulder-knee).angle_to(wrist-knee)))
                    check["support_knee_bend_deg"]=180.0-absf(rad_to_deg((support_hip-support_knee).angle_to(support_ankle-support_knee)))
                    check["ankle_y"]=wrist.y
                    check["head_y"]=q.head.y
                    check["contact_points"]={}
                    for joint_id in q:
                        check["contact_points"][joint_id]=[q[joint_id].x,q[joint_id].y]
                check["pelvis_turn_deg"]=float(keys[tick].pose.angles.get("pelvis_turn",0))
                check["shoulder_turn_deg"]=float(keys[tick].pose.angles.get("shoulder_turn",0))
            event_checks.append(check)
        report.append({"max_sole_pen_px":max_sole_pen,"max_toe_error_px":max_toe_error,"max_heel_lift_px":max_heel_lift,"event_checks":event_checks,"variant":v.label,"duration":clip.duration,"contact_s":float(v.contact)/60.0,"frames":keys.size(),"sdk_keys":clip.keys.size(),"exposure_indices":exposure_indices,"exposure_count":exposure_indices.size(),"cadence_error_px":max_cadence_error,"cadence_support_error_px":max_cadence_support,"cadence_floor_px":max_cadence_floor,"cadence_max_step_px":max_cadence_step,"floor_pen_before_final_clamp":max_pen,"root_adjustment_px":max_root_adjust,"support_error_px":max_support_error,"bone_error_px":max_bone_error,"max_joint_step_px":max_joint_step,"sampler_error_px":max_sampler_error,"contact_hand_px":[poses[v.contact]["hand_near"].x,poses[v.contact]["hand_near"].y]})
    for t in count:
        board.pts=[]
        board.foot_angles=[]
        for v in all_points:board.pts.append(v[mini(t,v.size()-1)])
        for v in all_foot_angles:board.foot_angles.append(v[mini(t,v.size()-1)])
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.get_size()!=capture_size or img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    var f:=FileAccess.open(out.path_join("render-report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "));f.close()
    print("MOCAP_STYLE_OK")
    quit()
