extends RefCounted
## Authoritative boundary for library trig/FK results. Dyadic fractions
## are exactly representable; converting through int also clears minus zero.
static func scalar(value:float)->float:
    return roundi(value*1024.)/1024.

static func point(value:Vector2)->Vector2:
    return Vector2(scalar(value.x),scalar(value.y))

static func pose(p:Dictionary)->void:
    for id in p.angles:p.angles[id]=scalar(p.angles[id])
    for i in 2:p.root[i]=scalar(p.root[i])
