extends RefCounted
## 081: sparse candidate planner derived from 080. Lab-only fixed-step action player. Commands replace an action instance,
## not a queued clip after guard. Markers are emitted only by the live instance.
const Clips=preload("res://addons/creature/clips.gd")
const Offset=preload("res://lab/pose_transition_075.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Recovery=preload("res://lab/stance_recovery_078.gd")
const DT:float=1./60.
const MIN_TICKS:int=2
const MAX_TICKS:int=12
const FIXED_TICKS:int=6
var duration:int=0
var deadline:int=MAX_TICKS
var plan_us:int=0
var plan_score:float=0.
var candidate_count:int=0
var pose_distance:float=0.
var velocity_mismatch:float=0.
var rig
var variant:int=0
var action:Dictionary={}
var serial:int=0
var elapsed:int=0
var phase:int=0
var world_x:float=0.
var previous:Dictionary={}
var current:Dictionary={}
var inertial=Offset.new()
var locks:Dictionary={}
var fired:Dictionary={}
var previous_source:int=-1

func _init(r,v:int):
    rig=r
    variant=v

func raw(a:Dictionary,source:int)->Dictionary:
    var tick:int=source
    if a.loop:
        tick=posmod(tick,int(a.last))
    else:
        tick=clampi(tick,int(a.first),int(a.last))
    return Clips.sample(a.clip,tick*DT,false)

func destination(local:int)->Dictionary:
    var p:Dictionary=raw(action,phase+local)
    p.root[0]=float(p.root[0])+world_x
    return p

func toes(p:Dictionary)->Dictionary:
    rig.evaluate(p)
    var out:Dictionary={}
    for side in IK.SIDES:out[side]=rig.point("foot_"+side)+IK.toe_vector(p,side)
    return out

func grounded(p:Dictionary,old:Dictionary)->Dictionary:
    var a:Dictionary=toes(p)
    var b:Dictionary=toes(old)
    var result:Dictionary={}
    for side in IK.SIDES:
        var v:Vector2=a[side]
        if absf(v.y)<.30 and v.distance_to(b[side])<.18:
            result[side]=v
    return result

func match_run(a:Dictionary,p:Dictionary)->int:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    var best:float=INF
    var result:int=0
    for tick in int(a.last):
        rig.evaluate(raw(a,tick))
        var score:float=0.
        for id in ["foot_near","foot_far","knee_near","knee_far","hand_near","hand_far","chest"]:
            var x:Vector2=Vector2(q[id])-Vector2(q.hips)
            var y:Vector2=rig.point(id)-rig.point("hips")
            score+=x.distance_squared_to(y)*(2. if id.begins_with("foot") else 1.)
        if score<best:
            best=score
            result=tick
    return result

func impact_deadline()->int:
    var limit:int=MAX_TICKS
    if action.loop:return limit
    limit=mini(limit,int(action.last)-phase)
    for e in action.clip.events:
        var t:int=roundi(float(e.t)*60.)
        if t>=phase and t<=int(action.last):
            limit=mini(limit,t-phase)
    return maxi(0,limit)

func configure(ticks:int)->void:
    duration=ticks
    locks.clear()
    var first:Dictionary=raw(action,phase)
    world_x=float(current.root[0])-float(first.root[0])
    if ticks==0:return
    var available:Dictionary=grounded(current,previous)
    var start_toes:Dictionary=toes(first)
    var candidates:Array=[]
    for side in IK.SIDES:
        if not available.has(side):continue
        var stable:bool=true
        for tick in range(ticks+1):
            var toe:Vector2=toes(raw(action,phase+tick))[side]
            if absf(toe.y)>.30 or toe.distance_to(start_toes[side])>.25:
                stable=false
                break
        if stable:candidates.append(side)
    if not candidates.is_empty():
        var anchor:String=candidates[0]
        world_x=Vector2(available[anchor]).x-Vector2(start_toes[anchor]).x
        rig.evaluate(current)
        var q:Dictionary=rig.points.duplicate(true)
        for side in candidates:
            var mapped:Vector2=Vector2(start_toes[side])+Vector2(world_x,0.)
            if mapped.distance_to(available[side])<.25:
                locks[side]={"toe":available[side],"sign":Recovery.bend_sign(q,side)}
    inertial.begin(previous,current,destination(0),destination(1),ticks*DT)

# Pure with respect to action time, event ledger and pose history.
# The rig is scratch FK state only; no rendering or contact events here.
func pose_at(local:int)->Dictionary:
    var target:Dictionary=destination(local)
    var p:Dictionary=target.duplicate(true)
    var residual:float=0.
    var lock_count:int=0
    if serial>1 and local<duration:
        p=inertial.apply(target,local*DT)
        if local>0 and not locks.is_empty():
            rig.evaluate(p)
            var goals:Dictionary={}
            for side in IK.SIDES:goals[side]=rig.point("foot_"+side)
            var incoming:Dictionary=toes(target)
            var w:float=smoothstep(0.,float(duration),float(local))
            for side in locks:
                var toe:Vector2=Vector2(locks[side].toe).lerp(incoming[side],w)
                goals[side]=toe-IK.toe_vector(p,side)
            Recovery.project_root(rig,p,IK.root_of(p),goals)
            for side in locks:
                IK.solve_leg(rig,p,side,goals[side],float(locks[side].sign))
            rig.evaluate(p)
            for side in locks:
                residual=maxf(residual,rig.point("foot_"+side).distance_to(goals[side]))
            lock_count=locks.size()
    return {"pose":p,"target":target,"lock_error":residual,"lock_count":lock_count}

func points_of(p:Dictionary)->Dictionary:
    rig.evaluate(p)
    return rig.points.duplicate(true)

func measure_entry()->void:
    var a:Dictionary=points_of(current)
    var b:Dictionary=points_of(previous)
    var c:Dictionary=points_of(destination(0))
    var d:Dictionary=points_of(destination(1))
    pose_distance=0.
    velocity_mismatch=0.
    for id in a:
        var x:Vector2=a[id]
        var old:Vector2=b[id]
        var y:Vector2=c[id]
        var next:Vector2=d[id]
        pose_distance=maxf(pose_distance,x.distance_to(y))
        velocity_mismatch=maxf(velocity_mismatch,(x-old).distance_to(next-y))

func evaluate_candidate(ticks:int)->Dictionary:
    configure(ticks)
    var old:Dictionary=points_of(current)
    var older:Dictionary=points_of(previous)
    var authored_old:Dictionary=points_of(destination(0))
    var peak_extra:float=0.
    var peak_accel:float=0.
    var peak_step:float=0.
    var error:float=0.
    # Include first exact target and its next frame, so a short candidate
    # cannot hide an abrupt handoff at the end of the correction.
    for k in range(ticks+2):
        var v:Dictionary=pose_at(k)
        var q:Dictionary=points_of(v.pose)
        var authored:Dictionary=points_of(v.target)
        error=maxf(error,float(v.lock_error))
        for id in q:
            var x:Vector2=q[id]
            var last:Vector2=old[id]
            var before:Vector2=older[id]
            var move:Vector2=x-last
            var source_move:Vector2=Vector2(authored[id])-Vector2(authored_old[id])
            peak_step=maxf(peak_step,move.length())
            peak_extra=maxf(peak_extra,maxf(0.,move.length()-source_move.length()))
            peak_accel=maxf(peak_accel,(move-(last-before)).length())
        older=old
        old=q
        authored_old=authored
    # Units are rig-space displacement per tick, not physical acceleration.
    # Cost is explicitly heuristic: preserve dynamics, penalize long correction,
    # and heavily penalize unreachable support. No retiming of incoming clip.
    var score:float=peak_extra+.35*peak_accel+.42*float(ticks)+100.*maxf(0.,error-.03)
    return {"score":score,"error":error,"peak_step":peak_step}

func command(a:Dictionary)->void:
    var start:int=Time.get_ticks_usec()
    action=a
    serial+=1
    elapsed=0
    previous_source=-1
    fired.clear()
    locks.clear()
    phase=int(a.first)
    world_x=0.
    duration=0
    plan_score=0.
    candidate_count=0
    pose_distance=0.
    velocity_mismatch=0.
    deadline=impact_deadline()
    if current.is_empty():
        plan_us=Time.get_ticks_usec()-start
        return
    if a.loop:
        phase=match_run(a,current)
    deadline=impact_deadline()
    if deadline==0:
        configure(0)
        plan_us=Time.get_ticks_usec()-start
        return
    configure(mini(FIXED_TICKS,deadline))
    measure_entry()
    var lo:int=mini(MIN_TICKS,deadline)
    var chosen:int=mini(FIXED_TICKS,deadline)
    if variant==1:
        # Short compatible transitions; longer if the pose or incoming
        # velocity differs. Deadline is a hard upper bound.
        chosen=clampi(ceili(pose_distance/4.+velocity_mismatch/5.),lo,deadline)
        var trial:Dictionary=evaluate_candidate(chosen)
        candidate_count=1
        plan_score=trial.score
        if trial.error>.20:
            # If heuristic duration cannot respect support, search legal
            # durations. Same fallback is used only for feasibility.
            var best:float=INF
            for ticks in [lo,deadline]:
                if ticks==chosen:continue
                var c:Dictionary=evaluate_candidate(int(ticks))
                candidate_count+=1
                if c.error<.20 and float(c.score)<best:
                    best=c.score
                    chosen=int(ticks)
                    plan_score=best
            if best==INF:
                configure(chosen)
                locks.clear()
                plan_score=-1.
                plan_us=Time.get_ticks_usec()-start
                return
    elif variant==2:
        var best:float=INF
        var guess:int=clampi(ceili(pose_distance/4.+velocity_mismatch/5.),lo,deadline)
        var choices:Array=[lo,guess,deadline]
        var tested:Dictionary={}
        for ticks in choices:
            if tested.has(ticks):continue
            tested[ticks]=true
            var c:Dictionary=evaluate_candidate(int(ticks))
            candidate_count+=1
            if c.error<=.20 and float(c.score)<best:
                chosen=int(ticks)
                best=c.score
        # No feasible candidate: retain heuristic duration and drop locks
        # rather than spending an unbounded command-time budget.
        if best==INF:
            chosen=guess
            configure(chosen)
            locks.clear()
            plan_score=-1.
            plan_us=Time.get_ticks_usec()-start
            return
        plan_score=best
    configure(chosen)
    plan_us=Time.get_ticks_usec()-start

func step()->Dictionary:
    var sampled:Dictionary=pose_at(elapsed)
    var p:Dictionary=sampled.pose
    var target:Dictionary=sampled.target
    var residual:float=sampled.lock_error
    var lock_count:int=sampled.lock_count
    var source:int=phase+elapsed
    if not action.loop:source=mini(source,int(action.last))
    else:source=posmod(source,int(action.last))
    var events:Array=[]
    if not action.loop:
        for i in action.clip.events.size():
            var e:Dictionary=action.clip.events[i]
            var t:int=roundi(float(e.t)*60.)
            if t<int(action.first) or t>int(action.last):continue
            if t==source and not fired.has(i):
                fired[i]=true
                events.append({"instance":serial,"source_tick":t,"anchor":e.anchor,"kind":e.kind})
    previous_source=source
    previous=current.duplicate(true) if not current.is_empty() else p.duplicate(true)
    current=p.duplicate(true)
    var output={"pose":p,"target":target,"events":events,"instance":serial,"action":action.name,"local":elapsed,"source":source,"phase":phase,"lock_count":lock_count,"lock_error":residual,"selected_locks":locks.keys(),"duration":duration,"deadline":deadline,"plan_us":plan_us,"plan_score":plan_score,"candidate_count":candidate_count,"pose_distance":pose_distance,"velocity_mismatch":velocity_mismatch}
    elapsed+=1
    return output
