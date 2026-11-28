extends RefCounted
## A shared onset-path ribbon and a spatially separate trajectory accent.
## Both start from actual samples, use the same continuous signal, and
## never create a gameplay hitbox or mutate a pose.
static func rows(drive,offset:bool=false)->Array[Dictionary]:
    var src:Array[Dictionary]=drive.trail()
    var out:Array[Dictionary]=[]
    if src.size()<2:return out
    var total:float=0.
    for i in range(1,src.size()):total+=Vector2(src[i-1].p).distance_to(Vector2(src[i].p))
    var length:float=0.
    var amount:float=clampf(sqrt(drive.score)*drive.strength,0.,1.5)
    for i in src.size():
        var p:Vector2=src[i].p
        if i>0:length+=p.distance_to(Vector2(src[i-1].p))
        var u:float=length/maxf(.01,total)
        var tangent:Vector2=(Vector2(src[mini(i+1,src.size()-1)].p)-Vector2(src[maxi(0,i-1)].p)).normalized()
        if tangent.length_squared()<.01:tangent=drive.direction
        var n:=Vector2(-tangent.y,tangent.x)
        # Consistent outside side chosen from the overall travel direction;
        # no per-sample sign flips as curvature changes.
        var ref_normal:=Vector2(-drive.direction.y,drive.direction.x)
        if n.dot(ref_normal)<0.:n=-n
        var width:float=lerpf(.12,7.2,pow(u,.72))*amount
        if offset:
            # Standalone accent beyond the striking tip; body is unmodified.
            # Taper the detached curve at both ends.
            p+=n*(2.6+3.0*u)+tangent*(2.0*u)
            width=lerpf(.15,2.1,sin(PI*u))*amount
        out.append({"p":p,"n":n,"width":width,"alpha":clampf(amount*lerpf(.22,.95,u),0.,1.)})
    return out
