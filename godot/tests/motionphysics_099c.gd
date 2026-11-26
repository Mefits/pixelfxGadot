extends SceneTree
const Common=preload("res://lab/ragdoll_common_099c.gd")
var out:String
var spec:String
var model
var n:int
var base_event:Dictionary
var failures:Array=[]
func _initialize():call_deferred("run")
func save_json(name:String,value)->void:
    var f=FileAccess.open(out.path_join(name+".json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(value))
    f.close()
func check(ok:bool,label:String)->void:
    if not ok:failures.append(label)
func world(passes:int,copies:int=1,physical_profile:int=0):
    var w=ClassDB.instantiate("MotionPhysics099C")
    assert(w.setup(spec,passes,copies,physical_profile))
    return w
func impact_for(body_id:String,lever:Vector2=Vector2.ZERO)->Dictionary:
    var idx:int=int(model.ids[body_id])
    var b:Dictionary=model.bodies[idx]
    return {"idx":idx,"point":Vector2(b.p)+lever.rotated(float(b.a)),"impulse":base_event.impulse}
func controls(t:int,copies:int=1,profile:int=1)->PackedFloat64Array:
    var a:=PackedFloat64Array()
    a.resize(n*copies)
    var sec:float=float(t)/120.
    for i in a.size():
        var id:String=model.bodies[i%n].id
        var w:float=0.
        if profile==0:
            w=1.-smoothstep(.06,.24,sec)
        elif id=="chest":
            w=1. if sec<=.28 else lerpf(1.,.12,smoothstep(.28,.48,sec))
        elif id=="head":
            w=.85 if sec<=.26 else lerpf(.85,.12,smoothstep(.26,.46,sec))
        elif id.begins_with("thigh_"):
            w=1. if sec<=.30 else lerpf(1.,.20,smoothstep(.30,.54,sec))
        elif id.begins_with("knee_"):
            w=.92 if sec<=.30 else lerpf(.92,.24,smoothstep(.30,.52,sec))
        elif id.begins_with("shoulder_"):
            w=.82 if sec<=.20 else lerpf(.82,.10,smoothstep(.20,.42,sec))
        elif id.begins_with("elbow_"):
            w=.72 if sec<=.20 else lerpf(.72,.08,smoothstep(.20,.40,sec))
        elif id.begins_with("hand_"):
            w=.42 if sec<=.16 else lerpf(.42,.04,smoothstep(.16,.36,sec))
        elif id.begins_with("foot_"):
            w=.36 if sec<=.26 else lerpf(.36,.08,smoothstep(.26,.48,sec))
        a[i]=w
    return a
func hit(w,impact:Dictionary,copy:int=0)->void:
    assert(w.impulse(int(impact.idx)+copy*n,Vector2(impact.impulse),Vector2(impact.point)+Vector2(copy*200,0)))
func percentile(a:Array)->float:
    a.sort()
    return float(a[mini(a.size()-1,ceili(a.size()*.95)-1)])
func momentum(w,copies:int=1)->Vector2:
    var p:=Vector2.ZERO
    var state:Array=w.state()
    for i in n*copies:p+=Vector2(state[i][3],state[i][4])*float(model.bodies[i%n].mass)
    return p
func compare(a:Array,b:Array)->float:
    var error:float=0.
    for i in a.size():
        for j in 6:error=maxf(error,absf(float(a[i][j])-float(b[i][j])))
    return error
func setup_model()->void:
    model=Common.make_model()
    n=model.bodies.size()
    base_event=Common.event(model)
    Common.export_spec(model,out.path_join("model.txt"))
    spec=FileAccess.get_file_as_string(out.path_join("model.txt"))
func simulate(label:String,passes:int,physical_profile:int,impact:Dictionary,control_profile:int,write_trace:bool=true)->Dictionary:
    setup_model()
    var w=world(passes,1,physical_profile)
    var before:Vector2=momentum(w)
    hit(w,impact)
    var delta:Vector2=momentum(w)-before
    var impulse_error:float=(delta-Vector2(impact.impulse)).length()/Vector2(impact.impulse).length()
    check(impulse_error<.0001,label+" momentum")
    var rows:Array=[]
    var times:Array=[]
    var max_angle:float=0.
    var max_anchor:float=0.
    var max_floor:float=0.
    var max_fk:float=0.
    var final_speed:float=0.
    var pose_error_sum:float=0.
    var pose_error_count:int=0
    var worst_joint:String=""
    var worst_tick:int=0
    var worst_limit_rad:float=0.
    var com_x:Array=[]
    var com_vy:Array=[]
    var near_floor:Array=[]
    for t in Common.N*2:
        var clock:int=Time.get_ticks_usec()
        assert(w.step(controls(t,1,control_profile)))
        var elapsed:int=Time.get_ticks_usec()-clock
        times.append(elapsed)
        var state:Array=w.state()
        Common.load_state(model,state)
        model.pose()
        var v:Dictionary=Common.validate(model)
        max_angle=maxf(max_angle,v.angle_error_deg)
        max_anchor=maxf(max_anchor,v.anchor)
        max_floor=maxf(max_floor,v.penetration)
        max_fk=maxf(max_fk,model.pose_error)
        if t>=Common.N*2-60:final_speed=maxf(final_speed,v.speed)
        var total_mass:float=0.
        var com:=Vector2.ZERO
        var vy:float=0.
        for i in n:
            var mass:float=float(model.bodies[i].mass)
            total_mass+=mass
            com+=Vector2(state[i][0],state[i][1])*mass
            vy+=float(state[i][4])*mass
        com/=total_mass
        vy/=total_mass
        com_x.append(com.x)
        com_vy.append(vy)
        near_floor.append(int(v.near_floor))
        if t>=12 and t<=36:
            for i in range(1,n):
                var parent:int=int(model.bodies[i].parent)
                var rel:float=wrapf(float(state[i][2])-float(state[parent][2]),-PI,PI)
                var e:float=absf(wrapf(float(model.bodies[i].goal)-rel,-PI,PI))
                if String(model.bodies[i].id) in ["chest","thigh_far","thigh_near","knee_far","knee_near","shoulder_far","shoulder_near"]:
                    pose_error_sum+=rad_to_deg(e)
                    pose_error_count+=1
        for i in range(1,n):
            var parent:int=int(model.bodies[i].parent)
            var rel:float=wrapf(float(state[i][2])-float(state[parent][2]),-PI,PI)
            var outside:float=rel-clampf(rel,float(model.bodies[i].lo),float(model.bodies[i].hi))
            if absf(outside)>worst_limit_rad:
                worst_limit_rad=absf(outside)
                worst_joint=String(model.bodies[i].id)
                worst_tick=t
        rows.append({"state":state,"us":elapsed})
    var contact_tick:int=-1
    for t in range(36,near_floor.size()):
        if near_floor[t]>=3:
            contact_tick=t
            break
    var slide:float=0.
    var bounce_count:int=0
    if contact_tick>=0:
        slide=absf(com_x[contact_tick]-com_x[-1])
        for t in range(contact_tick+1,com_vy.size()):
            if com_vy[t-1]<-.15 and com_vy[t]>=.15:bounce_count+=1
    var pose_hold_error:float=pose_error_sum/maxf(1.,float(pose_error_count))
    var quality:bool=max_angle<8. and max_anchor<1. and max_floor<.6 and max_fk<2. and final_speed<18.
    if physical_profile==1:quality=quality and slide>=8. and bounce_count<=2
    var metrics:Dictionary={"label":label,"p95_step_us":percentile(times),"max_joint_limit_error_deg":max_angle,"worst_joint":worst_joint,"worst_tick":worst_tick,"max_anchor_error":max_anchor,"max_floor_penetration":max_floor,"max_fk_error":max_fk,"final_speed_peak":final_speed,"impulse_error":impulse_error,"flight_pose_hold_error_deg":pose_hold_error,"contact_tick":contact_tick,"post_contact_slide":slide,"bounce_count":bounce_count,"quality":quality,"final_state_hash":w.state_hash()}
    if write_trace:save_json(label,rows)
    return {"metrics":metrics,"rows":rows}
func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=1 or not ClassDB.class_exists("MotionPhysics099C"):
        quit(2)
        return
    out=args[0]
    setup_model()
    var baseline:Dictionary=base_event
    var staged_chest:Dictionary=impact_for("chest",Vector2(2.,-2.))
    var staged_hips:Dictionary=impact_for("hips",Vector2(0.,-1.5))
    var profiles:Array=[]
    profiles.append(simulate("profileA",16,0,baseline,0,true))
    profiles.append(simulate("profileB",16,0,staged_chest,1,true))
    profiles.append(simulate("profileC",16,1,staged_hips,1,true))
    var sweep:Dictionary={}
    var selected:int=0
    for passes in [8,12,16]:
        var probe:Dictionary=simulate("sweep",passes,1,staged_hips,1,false)
        sweep[str(passes)]=probe.metrics
        if selected==0 and bool(probe.metrics.quality):selected=passes
    # Rollback at five cuts, including a corrected input branch.
    setup_model()
    var w=world(maxi(8,selected),1,1)
    hit(w,staged_hips)
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
                if k==3:assert(w.impulse(int(staged_hips.idx),Vector2(-20,5),Vector2(s[int(staged_hips.idx)][0],s[int(staged_hips.idx)][1])))
                assert(w.step(controls(t+k,1,1)))
                forward.append(w.state())
                hashes.append(w.state_hash())
            var first_us:int=Time.get_ticks_usec()-clock
            clock=Time.get_ticks_usec()
            var restored:bool=w.restore(snapshot)
            var restore_us:int=Time.get_ticks_usec()-clock
            var exact:bool=restored and h==w.state_hash() and s==w.state()
            var drift:float=0.
            clock=Time.get_ticks_usec()
            for k in 16:
                if k==3:assert(w.impulse(int(staged_hips.idx),Vector2(-20,5),Vector2(s[int(staged_hips.idx)][0],s[int(staged_hips.idx)][1])))
                assert(w.step(controls(t+k,1,1)))
                drift=maxf(drift,compare(forward[k],w.state()))
                exact=exact and forward[k]==w.state() and hashes[k]==w.state_hash()
            var replay_us:int=Time.get_ticks_usec()-clock
            check(exact,"rollback "+str(t))
            assert(w.restore(snapshot))
            for k in 16:
                if k==3:assert(w.impulse(int(staged_hips.idx),Vector2(-75,-10),Vector2(s[int(staged_hips.idx)][0],s[int(staged_hips.idx)][1])))
                assert(w.step(controls(t+k,1,1)))
            var changed:bool=w.state()!=forward[-1]
            check(changed,"corrected input "+str(t))
            assert(w.restore(snapshot))
            rollback.append({"cut":t,"bytes":snapshot.size(),"exact":exact,"max_drift":drift,"restore_us":restore_us,"replay_8ticks_us":replay_us,"first_run_8ticks_us":first_us,"changed_input":changed})
        assert(w.step(controls(t,1,1)))
    # Partial authority: a moving kinematic lower-body chain, dynamic torso and arms.
    setup_model()
    var pinned:Array=[]
    for i in n:
        var id:String=model.bodies[i].id
        if id=="hips" or id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_"):pinned.append(i)
    var partial=world(maxi(8,selected),1,1)
    for i in pinned:
        assert(partial.set_kinematic(i,true))
        assert(partial.set_velocity(i,Vector2(3.,0.),0.))
    var init:Array=partial.state()
    var hips:int=int(model.ids.hips)
    var arm:int=int(model.ids.hand_near)
    var pt:=Vector2(init[arm][0],init[arm][1])
    assert(partial.impulse(arm,Vector2(-60,0),pt))
    var mask:=PackedFloat64Array()
    mask.resize(n)
    mask.fill(0.)
    mask[int(model.ids.chest)]=.8
    for t in 60:assert(partial.step(mask))
    var mid:Array=partial.state()
    var support_error:float=0.
    for i in pinned:
        var init_rel:=Vector2(init[i][0]-init[hips][0],init[i][1]-init[hips][1])
        var mid_rel:=Vector2(mid[i][0]-mid[hips][0],mid[i][1]-mid[hips][1])
        support_error=maxf(support_error,mid_rel.distance_to(init_rel))
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
    # Two-body cost includes the native step and state export.
    var costs:Array=[]
    for copies in [1,2]:
        setup_model()
        var pair=world(maxi(8,selected),copies,1)
        for c in copies:hit(pair,staged_hips,c)
        var times:Array=[]
        for t in 360:
            var clock:int=Time.get_ticks_usec()
            assert(pair.step(controls(t,copies,1)))
            var state:Array=pair.state()
            times.append(Time.get_ticks_usec()-clock)
            assert(state.size()==n*copies)
        costs.append({"copies":copies,"p95_substep_with_export_us":percentile(times),"snapshot_bytes":pair.snapshot().size()})
    # Directional momentum is conserved before simulation for three axes.
    var directions:Array=[]
    for dir in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
        setup_model()
        var body=world(maxi(8,selected),1,1)
        var before:Vector2=momentum(body)
        var hit_event:Dictionary=impact_for("hips",Vector2.ZERO)
        hit_event.impulse=dir*Vector2(base_event.impulse).length()
        hit(body,hit_event)
        var actual:Vector2=momentum(body)-before
        var error:float=actual.distance_to(Vector2(hit_event.impulse))/Vector2(hit_event.impulse).length()
        check(error<.0001,"direction momentum "+str(dir))
        directions.append({"direction":[dir.x,dir.y],"relative_impulse_error":error})
    check(selected>0,"no substep configuration meets quality and slide gates")
    check(costs[-1].p95_substep_with_export_us<500.,"two-body target 1ms per 60Hz tick")
    var report:Dictionary={"version":"Box2D 3.2.0 / MotionPhysics 0.99c","sweep":sweep,"selected":selected,"profiles":profiles.map(func(p):return p.metrics),"rollback":rollback,"partial":{"support_error":support_error,"arm_motion":arm_motion,"handoff_error":handoff_error,"release_replay_exact":release_exact},"costs":costs,"directions":directions,"failures":failures,"qualified":failures.is_empty()}
    save_json("qualification",report)
    print("MOTIONPHYSICS_099C_REPORT ",JSON.stringify(report))
    print("MOTIONPHYSICS_099C_TEST_OK")
    quit()
