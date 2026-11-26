extends RefCounted
## Lab-only grounded recovery planner. Authored guard is a stance preference,
## not a compulsory world position. Targets are rig-space world coordinates.
const IK=preload("res://lab/support_adaptation_077.gd")
const Clips=preload("res://addons/creature/clips.gd")
const LOAD:int=8
const SWING:int=16
const SETTLE:int=10
const TOTAL:int=LOAD+SWING+SETTLE
const LIFT:float=3.2

static func root_of(p:Dictionary)->Vector2:
    return IK.root_of(p)

static func bend_sign(q:Dictionary,side:String)->float:
    var a:Vector2=Vector2(q["knee_"+side])-Vector2(q["thigh_"+side])
    var b:Vector2=Vector2(q["foot_"+side])-Vector2(q["knee_"+side])
    return 1. if a.cross(b)>=0. else -1.

static func plan(rig,entry:Dictionary,prior:Dictionary,guard:Dictionary)->Dictionary:
    rig.evaluate(prior)
    var prev:Dictionary=rig.points.duplicate(true)
    rig.evaluate(entry)
    var q:Dictionary=rig.points.duplicate(true)
    # Only start a grounded recovery when both ankles are near the local
    # floor reference, slow, and feet essentially flat. Otherwise defer.
    for side in IK.SIDES:
        var id:String="foot_"+side
        if absf(Vector2(q[id]).y)>.15 or Vector2(q[id]).distance_to(prev[id])>.12 or absf(float(entry.angles.get("foot_pitch_"+side,0.)))>2.:
            return {"ok":false,"reason":"entry not grounded"}
    rig.evaluate(guard)
    var g:Dictionary=rig.points.duplicate(true)
    var width:float=Vector2(g.foot_near).x-Vector2(g.foot_far).x
    if width<4.:return {"ok":false,"reason":"invalid guard"}
    # Choose the anchor which requires the smaller displacement of the
    # preferred guard root; no side is hardwired.
    var anchor:String="near"
    var best:float=INF
    for side in IK.SIDES:
        var d:Vector2=Vector2(q["foot_"+side])-Vector2(g["foot_"+side])
        var cost:float=(root_of(guard)+d-root_of(entry)).length()
        if cost<best:
            anchor=side
            best=cost
    var moving:String="far" if anchor=="near" else "near"
    var translation:Vector2=Vector2(q["foot_"+anchor])-Vector2(g["foot_"+anchor])
    var final:Dictionary=guard.duplicate(true)
    var finish:Vector2=root_of(guard)+translation
    final.root=[finish.x,finish.y]
    var targets:Dictionary={}
    for side in IK.SIDES:targets[side]=Vector2(g["foot_"+side])+translation
    var gap:float=Vector2(q.foot_near).x-Vector2(q.foot_far).x
    var inside:bool=Vector2(q.hips).x>Vector2(q.foot_far).x+.8 and Vector2(q.hips).x<Vector2(q.foot_near).x-.8
    var needs_step:bool=gap<width*.80 or gap>width*1.20 or not inside
    if not needs_step:
        # Already usable: retain both world contacts, return toward a
        # preferred upper-body guard and the center of the actual base.
        for side in IK.SIDES:targets[side]=q["foot_"+side]
        finish.x=(Vector2(q.foot_near).x+Vector2(q.foot_far).x)*.5
        final.root=[finish.x,finish.y]
    return {"ok":true,"entry":entry.duplicate(true),"final":final,"feet":{"near":q.foot_near,"far":q.foot_far},
        "targets":targets,"anchor":anchor,"moving":moving,"width":width,"needs_step":needs_step,
        "signs":{"near":bend_sign(g,"near"),"far":bend_sign(g,"far")}}

static func project_root(rig,p:Dictionary,desired:Vector2,goals:Dictionary)->void:
    rig.evaluate(p)
    var q:Dictionary=rig.points.duplicate(true)
    var original:Vector2=root_of(p)
    var shift:Vector2=desired-original
    for iteration in 16:
        for side in IK.SIDES:
            var center:Vector2=Vector2(goals[side])-Vector2(q["thigh_"+side])
            var rel:Vector2=shift-center
            var radius:float=IK.reach(rig,side)-IK.REACH_MARGIN
            if rel.length()>radius:shift=center+rel.normalized()*radius
    var root:Vector2=original+shift
    p.root=[root.x,root.y]

static func sample(rig,plan:Dictionary,tick:int,variant:int)->Dictionary:
    var entry:Dictionary=plan.entry
    var finish:Dictionary=plan.final
    var anchor:String=plan.anchor
    var moving:String=plan.moving
    var goals:Dictionary=plan.feet.duplicate()
    var t:float=float(clampi(tick,0,TOTAL))
    var u:float=smoothstep(0.,float(TOTAL),t)
    var p:Dictionary=entry.duplicate(true)
    if variant==0:return {"pose":p,"goals":goals,"phase":"HOLD","moving":moving}
    if variant==1:return {"pose":Clips.blend_pose(entry,finish,u),"goals":goals,"phase":"BLEND","moving":moving}
    if tick==0:return {"pose":p,"goals":goals,"phase":"LOAD","moving":moving}
    p=Clips.blend_pose(entry,finish,u)
    var begin:Vector2=root_of(entry)
    var end:Vector2=root_of(finish)
    var desired:Vector2=begin.lerp(end,u)
    var phase:String="SETTLE"
    if plan.needs_step:
        var support:Vector2=plan.feet[anchor]
        var loaded:=Vector2(lerpf(begin.x,support.x,.65),begin.y+1.7)
        if t<=LOAD:
            phase="LOAD"
            desired=begin.lerp(loaded,smoothstep(0.,float(LOAD),t))
        elif t<LOAD+SWING:
            phase="STEP"
            var s:float=(t-LOAD)/SWING
            var progress:float=smoothstep(0.,1.,s)
            goals[moving]=Vector2(plan.feet[moving]).lerp(plan.targets[moving],progress)+Vector2(0.,-LIFT*16.*s*s*(1.-s)*(1.-s))
            # Hold most of the load through the early swing, then ease
            # toward the wider base as the moving foot approaches contact.
            desired=loaded.lerp(end,.75*smoothstep(.25,1.,s))
        else:
            goals[moving]=plan.targets[moving]
            desired=loaded.lerp(end,.75).lerp(end,smoothstep(float(LOAD+SWING),float(TOTAL),t))
    else:
        phase="HOLD BASE"
    project_root(rig,p,desired,goals)
    for side in IK.SIDES:IK.solve_leg(rig,p,side,goals[side],float(plan.signs[side]))
    if tick>=TOTAL:phase="GUARD"
    return {"pose":p,"goals":goals,"phase":phase,"moving":moving}
