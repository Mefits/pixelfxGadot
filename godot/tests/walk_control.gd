extends SceneTree
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Asset=preload("res://lab/authoring/asset.gd")
const Preview=preload("res://lab/walk_preview.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize():call_deferred("run")
func run():
    var docs:Dictionary={}
    for id in Asset.WALK_IDS:
        var doc:Dictionary=Motion.default_doc(id)
        docs[id]=doc
        check(Asset.problem(doc)=="","valid "+id+" "+Asset.problem(doc))
        check(doc.keys.size()==(1 if id=="walk_idle" else (5 if id=="walk_breathe" else 9)),"sparse keys")
    var idle=Walk.new(docs)
    var expected:Dictionary=idle.pose.duplicate(true)
    var stance_toes:Array=Motion.toes(idle.rig,idle.pose)
    var span:float=absf(stance_toes[0].x-stance_toes[1].x)
    print("GUARD_STANCE_SPAN ",span)
    check(span>11.5,"wider stance")
    for direction in [-1,1]:
        for phase_tick in range(0,64,2):
            var w=Walk.new(docs)
            for t in phase_tick+1:w.step(direction)
            var old:float=w.x
            for t in Walk.STOP_TICKS+1:w.step(0)
            check(w.x==old and w.activity==0. and w.pose==expected,"stop returns exact idle")
            check(w.FACING==1,"fixed facing")
    var w=Walk.new(docs)
    var max_slip:float=0.
    for cmd in [1,-1]:
        for t in 85:
            var old:Array=Motion.toes(w.rig,w.pose)
            var old_x:float=w.x
            var stance:Array=w.paths.map(func(p):return p.stance)
            var old_direction:int=w.direction
            var old_age:int=w.transition_age
            w.step(cmd)
            if old_direction==cmd and old_age>=Walk.START_TICKS and w.direction==cmd:
                for i in 2:
                    if stance[i] and w.paths[i].stance:
                        var delta:float=absf(Motion.toe(w.rig,w.pose,Motion.SIDES[i]).x+w.x-old[i].x-old_x)
                        max_slip=maxf(max_slip,delta)
            check(absf(w.x)<=Walk.LIMIT,"bounds")
    check(max_slip<.5,"stance slip %.4f"%max_slip)
    # Source and runtime use the same sampler; an edited document changes T.
    var altered:Dictionary=docs.duplicate(true)
    for k in altered.walk_forward.keys:k.angles.shoulder_near+=20.
    var normal=Walk.new(docs)
    var edited=Walk.new(altered)
    for t in 20:
        normal.step(1)
        edited.step(1)
    check(absf(normal.pose.angles.shoulder_near-edited.pose.angles.shoulder_near)>10.,"edited walk affects T")
    var p=Preview.new(docs.walk_forward)
    for t in 31:p.step({})
    var target:Dictionary=Motion.intent(Motion.prepare(docs.walk_forward),0.,p.rig)
    check(p.final_pose==Motion.resolve(p.rig,p.support,target),"M preview same sampler")
    var still=Walk.new(docs)
    var origin:float=still.x
    var foot_targets:Array=Motion.toes(still.rig,still.pose)
    var lo:float=INF
    var hi:float=-INF
    var slip:float=0.
    var x_min:float=INF
    var x_max:float=-INF
    var heel_lifts:Array=[0.,0.]
    for tick in 320:
        still.step(0)
        lo=minf(lo,float(still.pose.root[1]))
        hi=maxf(hi,float(still.pose.root[1]))
        x_min=minf(x_min,float(still.pose.root[0]))
        x_max=maxf(x_max,float(still.pose.root[0]))
        for side in 2:
            heel_lifts[side]=maxf(float(heel_lifts[side]),-float(still.rig.point("foot_"+Motion.SIDES[side]).y))
        for side in 2:
            slip=maxf(slip,Motion.toe(still.rig,still.pose,Motion.SIDES[side]).distance_to(foot_targets[side]))
        check(still.x==origin,"idle no travel")
    check(hi-lo>1.5,"idle visible breath")
    check(x_max-x_min>5.5,"weight transfers both ways")
    check(heel_lifts[0]>1.2 and heel_lifts[1]>1.2,"both heels lift")
    print("DYNAMIC_GUARD_SHIFT ",x_max-x_min," HEEL_LIFTS ",heel_lifts)
    check(slip<.1,"idle fixed foot "+str(slip))
    # Guard stays raised through a complete loop; wrists move in the
    # torso frame (not merely because of root bobbing).
    var guard=Walk.new(docs)
    var near_min:=Vector2(INF,INF)
    var near_max:=Vector2(-INF,-INF)
    var far_min:=Vector2(INF,INF)
    var far_max:=Vector2(-INF,-INF)
    for tick in 320:
        guard.step(0)
        var r=guard.rig
        for side in Motion.SIDES:
            var wrist:Vector2=r.point("hand_"+side)
            var elbow:Vector2=r.point("elbow_"+side)
            var shoulder:Vector2=r.point("shoulder_"+side)
            check(wrist.y<elbow.y-3.,"guard wrist above elbow "+side)
            check(wrist.y<shoulder.y+3.,"guard wrist near shoulder "+side)
            var bend:float=absf((elbow-shoulder).angle_to(wrist-elbow))
            check(bend>deg_to_rad(85.) and bend<deg_to_rad(165.),"guard elbow bend "+side)
        check(r.point("hand_near").x>r.point("hand_far").x+2.,"asymmetric guard")
        if tick>32:
            var n:Vector2=r.point("hand_near")-r.point("chest")
            var f:Vector2=r.point("hand_far")-r.point("chest")
            near_min=near_min.min(n)
            near_max=near_max.max(n)
            far_min=far_min.min(f)
            far_max=far_max.max(f)
    check(near_max.distance_to(near_min)>.6,"near guard motion")
    check(far_max.distance_to(far_min)>.6,"far guard motion")
    print("GUARD_WRIST_RANGE ",near_max.distance_to(near_min)," ",far_max.distance_to(far_min))
    var breathing:Dictionary=docs.walk_breathe
    check(breathing.keys[0].angles==breathing.keys[-1].angles and breathing.keys[0].root==breathing.keys[-1].root,"idle loop boundary")
    print("IDLE_BREATH_RANGE ",hi-lo," FOOT_ERROR ",slip)
    print("WALK_CONTROL_SLIP ",max_slip)
    if failures.is_empty():print("WALK_CONTROL_OK")
    else:
        for f in failures:push_error(f)
    quit(0 if failures.is_empty() else 1)
