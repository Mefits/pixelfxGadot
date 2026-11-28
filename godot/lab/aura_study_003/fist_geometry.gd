extends RefCounted
## One world-space geometry contract used by collision and renderer.
## Art pixels, fixed 60Hz age. Research values, not final frame data.
const TIMINGS=[
    {"name":"sharp","first":2,"peak":6,"hold":9,"end":16,"length":23,"freeze":3},
    {"name":"balanced","first":4,"peak":10,"hold":14,"end":24,"length":31,"freeze":5},
    {"name":"heavy","first":6,"peak":15,"hold":21,"end":33,"length":40,"freeze":7}
]
const DAMAGE:int=24
const PUSH:float=4.2
const LIFT:float=-2.15
const RECOIL:float=-540.
static func growth(age:int,p:Dictionary)->float:
    return smoothstep(float(p.first),float(p.peak),float(age))*(1.-smoothstep(float(p.hold),float(p.end),float(age)))
static func sample(elbow:Vector2,wrist:Vector2,facing:float,g:float)->Dictionary:
    var forward:=Vector2(facing,0.)
    var axis:Vector2=(wrist-elbow).normalized()
    if axis.length_squared()<.01:axis=forward
    axis=forward.lerp(axis,.72).normalized()
    if axis.length_squared()<.01:axis=forward
    # Same 002 fist proportions; longer reach for the stand-off experiment.
    var center:Vector2=wrist+axis*25.0*g
    return {"elbow":elbow,"wrist":wrist,"axis":axis,"facing":facing,"g":g,"center":center,"radius":6.*g}
static func sweep(a:Vector2,b:Vector2,r0:float,r1:float)->float:
    # First intersection of a relative linear sweep with a linearly growing circle.
    var d:Vector2=b-a
    var dr:float=r1-r0
    var c:float=a.length_squared()-r0*r0
    if c<=0.:return 0.
    var aa:float=d.length_squared()-dr*dr
    var bb:float=2.*(a.dot(d)-r0*dr)
    if absf(aa)<.000001:
        if bb>=0.:return -1.
        var t:float=-c/bb
        return t if t>=0. and t<=1. else -1.
    var discriminant:float=bb*bb-4.*aa*c
    if discriminant<0.:return -1.
    var lo:float=(-bb-sqrt(discriminant))/(2.*aa)
    var hi:float=(-bb+sqrt(discriminant))/(2.*aa)
    if lo>hi:
        var swap:float=lo
        lo=hi
        hi=swap
    if lo>=0. and lo<=1.:return lo
    if hi>=0. and hi<=1.:return hi
    return -1.
