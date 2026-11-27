extends RefCounted
## Pure parameter normalization and piecewise time mapping. All defaults
## retain the v18 phase boundaries, authored keys, and contact windows.
static func defaults(roundhouse:bool)->Dictionary:
    return {"prep_ticks":10 if roundhouse else 9,"strike_ticks":3,
        "return_ticks":13 if roundhouse else 10,"recovery_ticks":10,
        "reach_scale":1.,"pelvis_scale":1.,"shoulder_scale":1.,"acceleration_scale":1.,"leg":-1}

static func normalize(value:Dictionary,roundhouse:bool)->Dictionary:
    var d:Dictionary=defaults(roundhouse)
    var ranges={"prep_ticks":[3,20],"strike_ticks":[2,8],"return_ticks":[5,22],"recovery_ticks":[5,25],
        "reach_scale":[.6,1.1],"pelvis_scale":[0.,1.5],"shoulder_scale":[0.,1.5],"acceleration_scale":[.5,1.5],"leg":[-1,1]}
    for id in d:
        var x=value.get(id,d[id])
        if not (x is int or x is float) or not is_finite(float(x)):continue
        var v:float=clampf(float(x),float(ranges[id][0]),float(ranges[id][1]))
        d[id]=roundi(v) if id.ends_with("_ticks") or id=="leg" else v
    return d

static func source_tick(age:int,settings:Dictionary,roundhouse:bool)->float:
    var d:Dictionary=defaults(roundhouse)
    if settings.prep_ticks==d.prep_ticks and settings.strike_ticks==d.strike_ticks and settings.return_ticks==d.return_ticks and settings.recovery_ticks==d.recovery_ticks:return clampf(float(age),0.,float(d.prep_ticks+d.strike_ticks+d.return_ticks+d.recovery_ticks))
    var elapsed:float=float(age)
    var authored:float=0.
    for key in ["prep_ticks","strike_ticks","return_ticks","recovery_ticks"]:
        var span:float=float(settings[key])
        var original:float=float(d[key])
        if elapsed<=span:return authored+maxf(0.,elapsed)/span*original
        elapsed-=span
        authored+=original
    return authored

static func shape_key(value:Dictionary,settings:Dictionary)->Dictionary:
    var k:Dictionary=value.duplicate(true)
    var reach:float=float(settings.reach_scale)
    var pelvis:float=float(settings.pelvis_scale)
    if reach!=1.:
        var ankle:Vector2=Vector2(k.ankle)*reach
        k.ankle=ankle.limit_length(.999)
        k.support_hip_x=clampf(float(k.support_hip_x)*reach,-.45,.45)
    if pelvis!=1.:
        k.pelvis_turn=clampf(45.+(float(k.pelvis_turn)-45.)*pelvis,0.,90.)
    var shoulder:float=float(settings.get("shoulder_scale",1.))
    if shoulder!=1.:
        k.shoulder_turn=clampf(45.+(float(k.shoulder_turn)-45.)*shoulder,0.,90.)
    return k
