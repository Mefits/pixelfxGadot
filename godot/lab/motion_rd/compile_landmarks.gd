extends SceneTree
## Offline key reduction evaluates the same sampler and rig used by the game.
const RIG = preload("res://addons/creature/rig.gd")
const CLIPS = preload("res://addons/creature/clips.gd")
const VALID = preload("res://addons/creature/sdk_validate.gd")
const SPACE = preload("res://lab/motion_rd/pose_space.gd")

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size()!=2: quit(2);return
    var src: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    if not src is Dictionary or src.get("format")!="lab.compile.v1" or src.frames.size()<2:
        quit(2);return
    var rig=RIG.humanoid()
    var keys := []
    var expected := []
    var pose := CLIPS.pose()
    var held:Dictionary={}
    var held_points:Dictionary={}
    var locks:Dictionary={}
    var lock_frames:=[]
    var max_floor:=0.0
    var chosen_exposures:=0
    var locked_samples:=0
    var max_root_adjustment:=0.0
    var event_ticks:={}
    for event in src.events: event_ticks[roundi(float(event.t)*120)]=true
    for frame in src.frames:
        pose=SPACE.solve(rig,pose,frame.edit)
        pose.root=[0,0]
        rig.evaluate(pose)
        var distance:=0.0
        if not held_points.is_empty():
            for id in rig.points:
                distance=maxf(distance,rig.point(id).distance_to(held_points[id]))
        if held.is_empty() or distance>=float(src.pose_threshold) or event_ticks.has(int(frame.tick)) or frame==src.frames[-1]:
            held=pose.duplicate(true)
            held_points=rig.points.duplicate()
            chosen_exposures+=1
        pose=held.duplicate(true)
        pose.root=frame.root.duplicate()
        rig.evaluate(pose)
        if src.plant:
            # Remove floor penetration, including during a transition to/from a lock.
            pose.root[1]-=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            rig.evaluate(pose)
        for tip in locks.keys():
            if tip not in frame.support: locks.erase(tip)
        var targets:={}
        for tip in frame.support:
            if not locks.has(tip): locks[tip]=Vector2(rig.point(tip).x,0)
        # The filmed torso/leg proportions generally differ from the target.
        # A fixed ankle can be unreachable until we move the pelvis. Project
        # its shift into the feasible reach disks of the support legs together.
        var shift:=Vector2.ZERO
        for iteration in 16:
            var before:=shift
            for tip in frame.support:
                var chain:Array=SPACE.CHAINS[tip]
                var center:Vector2=locks[tip]-rig.point(chain[0])
                var reach:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()-.002
                if shift.distance_to(center)>reach:
                    shift=center+(shift-center).limit_length(reach)
            if before.distance_squared_to(shift)<0.00000001: break
        pose.root[0]+=shift.x
        pose.root[1]+=shift.y
        max_root_adjustment=maxf(max_root_adjustment,shift.length())
        rig.evaluate(pose)
        var goals:=locks.duplicate()
        if src.plant:
            for tip in ["foot_near","foot_far"]:
                if not goals.has(tip) and rig.point(tip).y>0:
                    goals[tip]=Vector2(rig.point(tip).x,0)
        for tip in goals:
            var chain:Array=SPACE.CHAINS[tip]
            var base:Vector2=rig.point(chain[0])
            var total:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
            var reach:Vector2=(goals[tip]-base)/total
            var bend:float=(rig.point(tip)-base).cross(rig.point(chain[1])-base)
            targets[tip]=[reach.x,reach.y,1 if bend>=0 else -1]
        if not targets.is_empty():
            var hip:float=pose.angles.hips
            pose=SPACE.solve(rig,pose,{"tilt":[hip,hip+float(pose.angles.chest)],"targets":targets})
            locked_samples+=1
        rig.evaluate(pose)
        lock_frames.append(locks.duplicate())
        keys.append({"t":float(frame.tick)/120.0,"pose":pose})
        expected.append(rig.points.duplicate())
    var duration:float=keys[-1].t
    var clip:={"duration":duration,"loop":false,"keys":[],"events":src.events,"easing":"linear"}
    var fixed:={0:true,keys.size()-1:true}
    for event in src.events:
        for i in keys.size():
            if keys[i].t>=event.t:
                fixed[i]=true
                if i>0: fixed[i-1]=true
                break
    for i in range(1,lock_frames.size()):
        if lock_frames[i]!=lock_frames[i-1]:
            fixed[i]=true
            fixed[i-1]=true
    var bounds:=fixed.keys()
    bounds.sort()
    var work:=[]
    for i in range(1,bounds.size()):
        work.append([bounds[i-1],bounds[i]])
    while not work.is_empty():
        var span:Array=work.pop_back()
        var a:int=span[0]
        var b:int=span[1]
        clip.keys=[keys[a],keys[b]]
        var worst:float=src.tolerance
        var split:=-1
        for k in range(a+1,b):
            rig.evaluate(CLIPS.sample(clip,keys[k].t,false))
            for id in rig.points:
                var error:float=rig.point(id).distance_to(expected[k][id])
                if error>worst:
                    worst=error
                    split=k
        if split!=-1:
            fixed[split]=true
            work.append([a,split])
            work.append([split,b])
    var selected:=fixed.keys()
    selected.sort()
    clip.keys=[]
    for i in selected: clip.keys.append(keys[i])
    var max_error:=0.0
    var max_plant:=0.0
    for i in keys.size():
        rig.evaluate(CLIPS.sample(clip,keys[i].t,false))
        for id in rig.points:
            max_error=maxf(max_error,rig.point(id).distance_to(expected[i][id]))
        max_floor=maxf(max_floor,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
        for tip in lock_frames[i]:
            max_plant=maxf(max_plant,rig.point(tip).distance_to(lock_frames[i][tip]))
    var entry:={"schema":1,"id":"retargeted_motion","name":"Retargeted motion","kind":"animation","source":"authored","payload":{"slot":src.slot,"clip":clip}}
    var report:Dictionary=VALID.new().validate(entry)
    if not report.ok or max_error>float(src.tolerance)+0.0001:
        push_error(str(report));quit(1);return
    var file:=FileAccess.open(args[1],FileAccess.WRITE)
    if file==null: quit(1);return
    file.store_string(JSON.stringify(entry,"",true,true))
    file.close()
    print("RETARGET ",JSON.stringify({"input_poses":keys.size(),"output_keys":selected.size(),"events":clip.events.size(),"selected_exposures":chosen_exposures,"support_samples":locked_samples,"max_plant_residual_px":max_plant,"max_root_adjustment_px":max_root_adjustment,"max_floor_penetration_px":max_floor,"max_sampled_joint_error_px":max_error,"tolerance_px":src.tolerance}))
    quit()
