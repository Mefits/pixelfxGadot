extends RefCounted
## Lab-only finite-duration inertial pose offset, not a dynamics solver.
## Preserve destination timing. Derivatives estimated from consecutive 60Hz samples.
const TICK:float=1.0/60.0
var duration:float=.15
var offsets:Dictionary={}
var derivatives:Dictionary={}
var root_offset:=Vector2.ZERO
var root_derivative:=Vector2.ZERO

static func delta(a:float,b:float)->float:
    return wrapf(a-b,-180.,180.)

static func root_of(p:Dictionary)->Vector2:
    return Vector2(float(p.root[0]),float(p.root[1]))

func begin(previous:Dictionary,current:Dictionary,destination:Dictionary,next:Dictionary,seconds:float)->void:
    duration=maxf(TICK,seconds)
    offsets.clear()
    derivatives.clear()
    var ids:Array=current.angles.keys()
    for p in [previous,destination,next]:
        for id in p.angles:
            if not ids.has(id):ids.append(id)
    for id in ids:
        var a:float=float(current.angles.get(id,0.))
        var b:float=float(previous.angles.get(id,0.))
        var c:float=float(destination.angles.get(id,0.))
        var d:float=float(next.angles.get(id,0.))
        offsets[id]=delta(a,c)
        # Cap extrapolation at an extra 20 degrees of Hermite tangent
        # displacement. A bounded heuristic, not exact velocity continuity.
        derivatives[id]=clampf((delta(a,b)-delta(d,c))/TICK,-20./duration,20./duration)
    root_offset=root_of(current)-root_of(destination)
    root_derivative=((root_of(current)-root_of(previous))-(root_of(next)-root_of(destination)))/TICK
    root_derivative=root_derivative.limit_length(4./duration)

func apply(destination:Dictionary,elapsed:float)->Dictionary:
    if elapsed>=duration:return destination.duplicate(true)
    var u:float=clampf(elapsed/duration,0.,1.)
    var h00:float=2.*u*u*u-3.*u*u+1.
    var h10:float=u*u*u-2.*u*u+u
    var p:Dictionary=destination.duplicate(true)
    for id in offsets:
        var angle:float=float(p.angles.get(id,0.))+float(offsets[id])*h00+float(derivatives[id])*duration*h10
        if id in ["shoulder_turn","pelvis_turn"]:angle=clampf(angle,0.,90.)
        p.angles[id]=angle
    var root:Vector2=root_of(destination)+root_offset*h00+root_derivative*duration*h10
    p.root=[root.x,root.y]
    return p
