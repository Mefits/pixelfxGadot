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
        check(doc.keys.size()==(1 if id=="walk_idle" else 9),"sparse keys")
    var idle=Walk.new(docs)
    var expected:Dictionary=idle.pose.duplicate(true)
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
    print("WALK_CONTROL_SLIP ",max_slip)
    if failures.is_empty():print("WALK_CONTROL_OK")
    else:
        for f in failures:push_error(f)
    quit(0 if failures.is_empty() else 1)
