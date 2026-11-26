extends RefCounted
## Lab-only authored contact schedule + terrain target + analytic two-link IK.
## Coordinates are rig units, y down. Ankle/toe reference, NOT sole collision.
const SIDES=["near","far"]
const STEP_HEIGHT:float=2.5
const TOE:float=4.
const REACH_MARGIN:float=.002

static func root_of(p:Dictionary)->Vector2:
    return Vector2(float(p.root[0]),float(p.root[1]))

static func toe_vector(p:Dictionary,side:String)->Vector2:
    return Vector2(TOE,0.).rotated(deg_to_rad(float(p.angles.get("foot_pitch_"+side,0.))))

static func release(t:float)->float:
    return smoothstep(38.,40.,t)*(1.-smoothstep(62.,64.,t))

static func targets(p:Dictionary,q:Dictionary,initial:Dictionary,landing:Dictionary,t:float)->Dictionary:
    var near:Vector2=Vector2(initial.foot_near)+Vector2(TOE,-STEP_HEIGHT)-toe_vector(p,"near")
    var airborne:float=release(t)
    var ground:Vector2=initial.foot_far if t<51. else landing.foot_far
    var far:Vector2=ground.lerp(Vector2(q.foot_far),airborne)
    # Preserve original swing trajectory once the kicking leg is released.
    return {"near":near,"far":far,"airborne":airborne}

static func reach(rig,side:String)->float:
    return Vector2(rig.joints[rig.ids["knee_"+side]].offset).length()+Vector2(rig.joints[rig.ids["foot_"+side]].offset).length()

static func solve_leg(rig,p:Dictionary,side:String,target:Vector2,sign_bend:float)->void:
    rig.evaluate(p)
    var hip_id:String="thigh_"+side
    var knee_id:String="knee_"+side
    var foot_id:String="foot_"+side
    var hip:Vector2=rig.point(hip_id)
    var upper:Vector2=rig.joints[rig.ids[knee_id]].offset
    var lower:Vector2=rig.joints[rig.ids[foot_id]].offset
    var l1:float=upper.length()
    var l2:float=lower.length()
    var delta:Vector2=target-hip
    var dir:Vector2=delta.normalized() if delta.length_squared()>.000001 else Vector2.DOWN
    var d:float=clampf(delta.length(),absf(l1-l2)+REACH_MARGIN,l1+l2-REACH_MARGIN)
    var bend:float=acos(clampf((d*d-l1*l1-l2*l2)/(2.*l1*l2),-1.,1.))*sign_bend
    var global_upper:float=dir.angle()-atan2(l2*sin(bend),l1+l2*cos(bend))
    p.angles[hip_id]=rad_to_deg(wrapf(global_upper-upper.angle()-float(rig.rotations.hips),-PI,PI))
    p.angles[knee_id]=rad_to_deg(wrapf(bend+upper.angle()-lower.angle(),-PI,PI))
    rig.evaluate(p)

static func adapt(rig,p:Dictionary,t:float,initial:Dictionary,landing:Dictionary,variant:int)->Dictionary:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    var goal:Dictionary=targets(p,q,initial,landing,t)
    if variant==0:return {"pose":p.duplicate(true),"goal":goal}
    var signs:Dictionary={}
    for side in SIDES:
        var u:Vector2=Vector2(q["knee_"+side])-Vector2(q["thigh_"+side])
        var v:Vector2=Vector2(q["foot_"+side])-Vector2(q["knee_"+side])
        signs[side]=1. if u.cross(v)>=0. else -1.
    var result:Dictionary=p.duplicate(true)
    if variant==2:
        var air:float=goal.airborne
        # Height compensation interpolates with the authored unloading phase.
        # The pelvis projection toward the support foot is a kinematic proxy,
        # not a simulated mass center or ground reaction force.
        var desired:=Vector2(clampf((Vector2(goal.near).x-Vector2(q.hips).x)*.40,-2.,2.)*air,
            -STEP_HEIGHT*(.5+.5*air))
        var shift:Vector2=desired
        # Project the proposed root into both reachable disks, with an
        # explicit displacement bound. Remaining residual is reported.
        for iteration in 12:
            for side in SIDES:
                var center:Vector2=Vector2(goal[side])-Vector2(q["thigh_"+side])
                var rel:Vector2=shift-center
                var radius:float=reach(rig,side)-REACH_MARGIN
                if rel.length()>radius:shift=center+rel.normalized()*radius
            shift=shift.limit_length(4.)
        var root:Vector2=root_of(p)+shift
        result.root=[root.x,root.y]
    for side in SIDES:
        solve_leg(rig,result,side,goal[side],float(signs[side]))
    return {"pose":result,"goal":goal}
