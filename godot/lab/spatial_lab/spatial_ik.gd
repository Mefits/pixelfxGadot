extends RefCounted
## Spatial Lab 0.03: analytic two-link geometry, in world rig units.
## The pole is the knee-side direction perpendicular to the hip->ankle axis.
const MARGIN:float=.002
const MAX_BEND:float=155.
const EPS:float=.000001

static func perpendicular(axis:Vector3,hint:Vector3)->Vector3:
    var v:Vector3=hint-axis*hint.dot(axis)
    if v.length_squared()<EPS:
        var fallback:Vector3=Vector3.RIGHT if absf(axis.x)<.8 else Vector3.BACK
        v=fallback-axis*fallback.dot(axis)
    return v.normalized()

static func transport(old_axis:Vector3,old_pole:Vector3,axis:Vector3)->Vector3:
    var prior:Vector3=old_axis.normalized()
    if prior.length_squared()<EPS:return perpendicular(axis,old_pole)
    var pole:Vector3=perpendicular(prior,old_pole)
    # At exact antipodes choose the previous knee side as rotation axis.
    if prior.dot(axis)<-.99999:return perpendicular(axis,pole)
    return perpendicular(axis,Quaternion(prior,axis)*pole)

static func min_reach(a:float,b:float)->float:
    return maxf(absf(a-b)+MARGIN,sqrt(maxf(0.,a*a+b*b+2.*a*b*cos(deg_to_rad(MAX_BEND)))))

static func max_reach(a:float,b:float)->float:
    return a+b-MARGIN

static func solve(hip:Vector3,target:Vector3,a:float,b:float,old_axis:Vector3,old_pole:Vector3)->Dictionary:
    assert(a>MARGIN and b>MARGIN)
    var delta:Vector3=target-hip
    var axis:Vector3=delta.normalized() if delta.length_squared()>EPS else old_axis.normalized()
    if axis.length_squared()<EPS:axis=Vector3.DOWN
    var pole:Vector3=transport(old_axis,old_pole,axis)
    var d:float=clampf(delta.length(),min_reach(a,b),max_reach(a,b))
    var along:float=(a*a-b*b+d*d)/(2.*d)
    var height:float=sqrt(maxf(0.,a*a-along*along))
    var knee:Vector3=hip+axis*along+pole*height
    var ankle:Vector3=hip+axis*d
    return {"knee":knee,"ankle":ankle,"axis":axis,"pole":pole,"residual":ankle.distance_to(target),"bend":rad_to_deg(acos(clampf((d*d-a*a-b*b)/(2.*a*b),-1.,1.)))}

static func bone_frame(rest:Vector3,world_bone:Vector3,normal:Vector3)->Basis:
    var ly:Vector3=rest.normalized()
    var lz:Vector3=perpendicular(ly,Vector3.BACK)
    var wy:Vector3=world_bone.normalized()
    var wz:Vector3=perpendicular(wy,normal)
    var local:=Basis(ly.cross(lz),ly,lz)
    var world:=Basis(wy.cross(wz),wy,wz)
    return world*local.transposed()
