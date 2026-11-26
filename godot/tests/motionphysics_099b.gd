extends SceneTree
const Common=preload("res://lab/ragdoll_common_099.gd")
var out:String
var spec:String
var m
var n:int
var event:Dictionary
var failures:Array=[]
func _initialize():call_deferred("run")
func save_json(name:String,value)->void:
    var f=FileAccess.open(out.path_join(name+".json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(value))
    f.close()
func check(ok:bool,label:String)->void:
    if not ok:failures.append(label)
func world(passes:int,copies:int=1):
    var w=ClassDB.instantiate("MotionPhysics099B")
    assert(w.setup(spec,passes,copies))
    return w
func weight(t:int,copies:int=1)->PackedFloat64Array:
    var a:=PackedFloat64Array()
    a.resize(n*copies)
    a.fill(1.-smoothstep(.06,.24,float(t)/120.))
    return a
func hit(w,dir:Vector2,scale:float=1.,copy:int=0)->void:
    assert(w.impulse(int(event.idx)+copy*n,dir.normalized()*Vector2(event.impulse).length()*scale,Vector2(event.point)+Vector2(copy*200,0)))
func percentile(a:Array)->float:
    a.sort()
    return float(a[mini(a.size()-1,ceili(a.size()*.95)-1)])
func momentum(w,copies:int=1)->Vector2:
    var p:=Vector2.ZERO
    var state:Array=w.state()
    for i in n*copies:
        p+=Vector2(state[i][3],state[i][4])*float(m.bodies[i%n].mass)
    return p
func compare(a:Array,b:Array)->float:
    var error:float=0.
    for i in a.size():
        for j in 6:error=maxf(error,absf(float(a[i][j])-float(b[i][j])))
    return error
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("MotionPhysics099B"):
        quit(2)
        return
    out=args[0]
    m=Common.make_model()
    n=m.bodies.size()
    event=Common.event(m)
    Common.export_spec(m,out.path_join("model.txt"))
    spec=FileAccess.get_file_as_string(out.path_join("model.txt"))
    var all:Dictionary={}
    var selected:int=0
    # Sweep actual Box2D native substeps; retain all three render traces.
    for passes in [1,4,8]:
        var w=world(passes)
        var initial:Array=w.state()
        var before:Vector2=momentum(w)
        hit(w,Vector2.LEFT)
        var delta:Vector2=momentum(w)-before
        var impulse_error:float=(delta-Vector2(event.impulse)).length()/Vector2(event.impulse).length()
        check(impulse_error<.0001,"impulse momentum "+str(passes))
        var rows:Array=[]
        var times:Array=[]
        var max_angle:float=0.
        var max_anchor:float=0.
        var max_floor:float=0.
        var max_fk:float=0.
        var final_speed:float=0.
        for t in Common.N*2:
            var controls:PackedFloat64Array=weight(t)
            var clock:int=Time.get_ticks_usec()
            assert(w.step(controls))
            var elapsed:int=Time.get_ticks_usec()-clock
            times.append(elapsed)
            var state:Array=w.state()
            Common.load_state(m,state)
            m.pose()
            var v:Dictionary=Common.validate(m)
            max_angle=maxf(max_angle,v.angle_error_deg)
            max_anchor=maxf(max_anchor,v.anchor)
            max_floor=maxf(max_floor,v.penetration)
            max_fk=maxf(max_fk,m.pose_error)
            if t>=Common.N*2-60:final_speed=maxf(final_speed,v.speed)
            rows.append({"us":elapsed,"state":state})
        save_json("box"+str(passes),rows)
        var quality:bool=max_angle<8. and max_anchor<1. and max_floor<.6 and max_fk<2. and final_speed<18.
        all[str(passes)]={"p95_substep_us":percentile(times),"angle_deg":max_angle,"anchor":max_anchor,"floor":max_floor,"fk":max_fk,"final_speed":final_speed,"impulse_error":impulse_error,"quality":quality,"final_hash":w.state_hash()}
        if quality and selected==0:selected=passes
        Common.load_state(m,initial)
    # Keep the best-resolution candidate for diagnostics if none passes.
    var passes:int=selected if selected>0 else 8
    var w=world(passes)
    hit(w,Vector2.LEFT)
    var rollback:Array=[]
    for t in 240:
        if t in [0,24,70,150,220]:
            var snapshot:PackedByteArray=w.snapshot()
            var h:String=w.state_hash()
            var s:Array=w.state()
            var forward:Array=[]
            var hashes:Array=[]
            var clock:int=Time.get_ticks_usec()
            for k in 16:
                if k==3:assert(w.impulse(int(event.idx),Vector2(-20,5),Vector2(s[int(event.idx)][0],s[int(event.idx)][1])))
                assert(w.step(weight(t+k)))
                forward.append(w.state())
                hashes.append(w.state_hash())
            var forward_us:int=Time.get_ticks_usec()-clock
            clock=Time.get_ticks_usec()
            var restored:bool=w.restore(snapshot)
            var restore_us:int=Time.get_ticks_usec()-clock
            var exact:bool=restored and h==w.state_hash() and s==w.state()
            var drift:float=0.
            clock=Time.get_ticks_usec()
            for k in 16:
                if k==3:assert(w.impulse(int(event.idx),Vector2(-20,5),Vector2(s[int(event.idx)][0],s[int(event.idx)][1])))
                assert(w.step(weight(t+k)))
                drift=maxf(drift,compare(forward[k],w.state()))
                exact=exact and forward[k]==w.state() and hashes[k]==w.state_hash()
            var replay_us:int=Time.get_ticks_usec()-clock
            check(exact,"rollback "+str(t))
            # A corrected input must actually change the outcome.
            assert(w.restore(snapshot))
            for k in 16:
                if k==3:assert(w.impulse(int(event.idx),Vector2(-75,-10),Vector2(s[int(event.idx)][0],s[int(event.idx)][1])))
                assert(w.step(weight(t+k)))
            var changed:bool=w.state()!=forward[-1]
            check(changed,"corrected input "+str(t))
            assert(w.restore(snapshot))
            rollback.append({"cut":t,"bytes":snapshot.size(),"exact":exact,"max_drift":drift,"restore_us":restore_us,"replay_8ticks_us":replay_us,"first_run_8ticks_us":forward_us,"changed_input":changed})
        assert(w.step(weight(t)))
    # Partial authority: kinematic hips + legs; torso/arms stay physical.
    # Translate supported chain slowly, then release it without a transform jump.
    m=Common.make_model()
    var pinned:Array=[]
    for i in n:
        var id:String=m.bodies[i].id
        if id=="hips" or id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_"):
            pinned.append(i)
    var partial=world(passes)
    for i in pinned:
        assert(partial.set_kinematic(i,true))
        assert(partial.set_velocity(i,Vector2(3.,0.),0.))
    var init:Array=partial.state()
    var arm:int=int(m.ids.hand_near)
    var pt:=Vector2(init[arm][0],init[arm][1])
    assert(partial.impulse(arm,Vector2(-60,0),pt))
    var mask:=PackedFloat64Array()
    mask.resize(n)
    mask.fill(0.)
    # Keep chest control stronger than the free arms.
    mask[int(m.ids.chest)]=.8
    for t in 60:assert(partial.step(mask))
    var mid:Array=partial.state()
    var support_error:float=0.
    for i in pinned:
        support_error=maxf(support_error,Vector2(mid[i][0],mid[i][1]).distance_to(Vector2(init[i][0]+1.5,init[i][1])))
    var arm_motion:float=Vector2(mid[arm][0],mid[arm][1]).distance_to(Vector2(init[arm][0]+1.5,init[arm][1]))
    var transfer_snapshot:PackedByteArray=partial.snapshot()
    for i in pinned:assert(partial.set_kinematic(i,false))
    var released:Array=partial.state()
    var handoff_error:float=compare(mid,released)
    for t in 60:assert(partial.step(mask))
    var release_final:Array=partial.state()
    var release_hash:String=partial.state_hash()
    assert(partial.restore(transfer_snapshot))
    for i in pinned:assert(partial.set_kinematic(i,false))
    for t in 60:assert(partial.step(mask))
    var release_exact:bool=partial.state()==release_final and partial.state_hash()==release_hash
    check(support_error<.1,"partial support")
    check(arm_motion>.5,"partial arm response")
    check(handoff_error<.0001,"kinematic release continuity")
    check(release_exact,"rollback across authority switch")
    # Independent full-body copies, real native calls and state export timed.
    var costs:Array=[]
    for copies in [1,2]:
        var pair=world(passes,copies)
        for c in copies:hit(pair,Vector2.LEFT,1.,c)
        var times:Array=[]
        for t in 360:
            var controls:PackedFloat64Array=weight(t,copies)
            var clock:int=Time.get_ticks_usec()
            assert(pair.step(controls))
            var state:Array=pair.state()
            times.append(Time.get_ticks_usec()-clock)
            assert(state.size()==n*copies)
        costs.append({"copies":copies,"p95_substep_with_export_us":percentile(times),"snapshot_bytes":pair.snapshot().size()})
    # Different impact directions: same anatomy and point, no arbitrary spin.
    var directions:Array=[]
    for dir in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
        var body=world(passes)
        var before:Vector2=momentum(body)
        hit(body,dir)
        var actual:Vector2=momentum(body)-before
        var wanted:Vector2=dir*Vector2(event.impulse).length()
        var error:float=actual.distance_to(wanted)/wanted.length()
        check(error<.0001,"direction momentum "+str(dir))
        directions.append({"direction":[dir.x,dir.y],"relative_impulse_error":error})
    check(selected>0,"no substep config meets joint and floor gates")
    check(costs[-1].p95_substep_with_export_us<500.,"two-body target 1ms per 60Hz tick")
    var report:Dictionary={"version":"Box2D 3.2.0","sweep":all,"selected":selected,"diagnostic_passes":passes,"rollback":rollback,"partial":{"support_error":support_error,"arm_motion":arm_motion,"handoff_error":handoff_error,"release_replay_exact":release_exact},"costs":costs,"directions":directions,"failures":failures,"qualified":failures.is_empty()}
    save_json("qualification",report)
    print("MOTIONPHYSICS_REPORT ",JSON.stringify(report))
    print("MOTIONPHYSICS_099B_TEST_OK")
    quit()
