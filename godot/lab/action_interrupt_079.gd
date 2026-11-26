extends RefCounted
## Lab-only fixed-step action player. Commands replace an action instance,
## not a queued clip after guard. Markers are emitted only by the live instance.
const Clips=preload("res://addons/creature/clips.gd")
const Offset=preload("res://lab/pose_transition_075.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Recovery=preload("res://lab/stance_recovery_078.gd")
const DT:float=1./60.
const TRANSITION:int=6
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

func command(a:Dictionary)->void:
    action=a
    serial+=1
    elapsed=0
    previous_source=-1
    fired.clear()
    locks.clear()
    phase=int(a.first)
    world_x=0.
    if current.is_empty():return
    if variant==2 and a.loop:
        phase=match_run(a,current)
    var first:Dictionary=raw(a,phase)
    world_x=float(current.root[0])-float(first.root[0])
    if variant==2:
        var available:Dictionary=grounded(current,previous)
        var start_toes:Dictionary=toes(first)
        var end_toes:Dictionary=toes(raw(a,phase+TRANSITION))
        # Retain a contact only when the destination also keeps the toe
        # near the floor over the transition. Never pin a swinging foot.
        var candidates:Array=[]
        for side in IK.SIDES:
            if not available.has(side):continue
            var stable:bool=true
            for tick in range(TRANSITION+1):
                var toe:Vector2=toes(raw(a,phase+tick))[side]
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
    if variant>0:
        inertial.begin(previous,current,destination(0),destination(1),TRANSITION*DT)

func step()->Dictionary:
    var target:Dictionary=destination(elapsed)
    var p:Dictionary=target.duplicate(true)
    var residual:float=0.
    var lock_count:int=0
    if variant>0 and serial>1 and elapsed<TRANSITION:
        p=inertial.apply(target,elapsed*DT)
        if variant==2 and elapsed>0 and not locks.is_empty():
            rig.evaluate(p)
            var goals:Dictionary={}
            for side in IK.SIDES:goals[side]=rig.point("foot_"+side)
            # Keep the world toe; blend to the incoming authored toe only
            # as the offset vanishes. Unlocked feet follow their own pose.
            var incoming:Dictionary=toes(target)
            var w:float=smoothstep(0.,float(TRANSITION),float(elapsed))
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
    var output={"pose":p,"target":target,"events":events,"instance":serial,"action":action.name,"local":elapsed,"source":source,"phase":phase,"lock_count":lock_count,"lock_error":residual,"selected_locks":locks.keys()}
    elapsed+=1
    return output
