extends RefCounted
## Side-view leg convention: positive geometric knee bend for both legs.
## Foot pitch is world-space; convert to shin-relative angle before blending.
const SIDES=["near","far"]
const REST:float=10.304846468766
static func wrap(a:float)->float:
    return wrapf(a,-180.,180.)
static func rest(side:String)->float:
    return REST if side=="near" else -REST
static func bend(p:Dictionary,side:String)->float:
    return wrap(float(p.angles["knee_"+side])+2.*rest(side))
static func shin(p:Dictionary,side:String)->float:
    return float(p.angles.hips)+float(p.angles["thigh_"+side])+float(p.angles["knee_"+side])+rest(side)
static func ankle(p:Dictionary,side:String)->float:
    return wrap(float(p.angles.get("foot_pitch_"+side,0.))-shin(p,side))
static func valid(p:Dictionary,side:String)->bool:
    return bend(p,side)>=-.001 and bend(p,side)<=155.001 and ankle(p,side)>=-95.001 and ankle(p,side)<=85.001
static func put(p:Dictionary,side:String,b:float,a:float)->void:
    p.angles["knee_"+side]=clampf(b,0.,155.)-2.*rest(side)
    p.angles["foot_pitch_"+side]=wrap(shin(p,side)+clampf(a,-95.,85.))
static func sanitize(p:Dictionary)->Dictionary:
    var q:Dictionary=p.duplicate(true)
    for side in SIDES:
        if not valid(q,side):put(q,side,bend(q,side),ankle(q,side))
    return q
static func residual(a:float,b:float,c:float,d:float,u:float,ticks:int,limit:float)->float:
    var h:float=2.*u*u*u-3.*u*u+1.
    var v:float=u*u*u-2.*u*u+u
    return (a-c)*h+clampf(((a-b)-(d-c))*ticks,-limit,limit)*v
static func correct(p:Dictionary,target:Dictionary,current:Dictionary,previous:Dictionary,first:Dictionary,next:Dictionary,local:int,ticks:int)->void:
    var u:float=float(local)/maxf(1.,float(ticks))
    for side in SIDES:
        var b:float=bend(target,side)+residual(bend(current,side),bend(previous,side),bend(first,side),bend(next,side),u,ticks,20.)
        var a:float=ankle(target,side)+residual(ankle(current,side),ankle(previous,side),ankle(first,side),ankle(next,side),u,ticks,20.)
        put(p,side,b,a)
