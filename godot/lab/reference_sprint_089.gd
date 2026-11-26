extends "res://lab/arm_clearance_088.gd"
## 089: reference-directed flight silhouette. Keep 087 touchdown schedule
## and stance path unchanged. Adjust only free swing and upper body.
static func style_weight(w:float)->float:
    return smoothstep(.65,1.,w)

func path_for(index:int,w:float)->Dictionary:
    var path:Dictionary=super.path_for(index,w)
    if path.stance:return path
    var leg:Dictionary=legs[index]
    var distance:float=travel-float(leg.start)
    var swing:float=float(leg.end)-float(leg.start)-STANCE_DISTANCE
    var s:float=clampf((distance-STANCE_DISTANCE)/swing,0.,1.)
    var envelope:float=pow(sin(PI*s),2.)
    var pulse:float=sin(TAU*s)
    var weight:float=style_weight(w)
    # Early swing extends behind the hips; late swing reaches forward.
    # Both correction and first derivative vanish at the stance boundaries.
    var toe:Vector2=path.toe
    toe.x-=10.*pulse*envelope*weight
    toe.y-=3.*maxf(0.,pulse)*envelope*weight
    path.toe=toe
    return path

func sample()->Dictionary:
    # Parent solves both new swing paths with the same positive IK branch,
    # bounded root-height adjustment and unchanged world stance targets.
    var result:Dictionary=super.sample()
    var p:Dictionary=result.pose
    var bend:float=10.*style_weight(result.gait)
    # Curve upper torso forward, retain head direction and the 088
    # global arm arcs rather than rotating arms through the legs.
    p.angles.chest=float(p.angles.chest)+bend
    p.angles.head=float(p.angles.head)-bend
    for name in Leg.SIDES:
        var id:String="shoulder_"+name
        p.angles[id]=float(p.angles[id])-bend
    return result
