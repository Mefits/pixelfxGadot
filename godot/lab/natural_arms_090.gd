extends "res://lab/reference_sprint_089.gd"
## 090: restore 087 arm arcs; optionally soften the flight correction.
## Render-only depth adjustment is in arm_depth_090.gd.
var polish:bool=false

func path_for(index:int,w:float)->Dictionary:
    var path:Dictionary=super.path_for(index,w)
    if not polish or path.stance:return path
    var leg:Dictionary=legs[index]
    var swing:float=float(leg.end)-float(leg.start)-STANCE_DISTANCE
    var s:float=clampf((travel-float(leg.start)-STANCE_DISTANCE)/swing,0.,1.)
    var envelope:float=pow(sin(PI*s),2.)
    var weight:float=style_weight(w)
    # Replace only the 089 X correction. Broaden the two lobes with
    # zero-slope knots; same stance boundary and scheduler.
    var x:float=0.
    if s<.25:x=-5.*smoothstep(0.,.25,s)
    elif s<.75:x=lerpf(-5.,5.,smoothstep(.25,.75,s))
    else:x=5.*(1.-smoothstep(.75,1.,s))
    var toe:Vector2=path.toe
    toe.x+=(x+10.*sin(TAU*s)*envelope)*weight
    path.toe=toe
    return path

func sample()->Dictionary:
    var result:Dictionary=super.sample()
    var p:Dictionary=result.pose
    var w:float=result.gait
    var phase:float=result.phase
    for index in 2:
        var name:String=Leg.SIDES[index]
        var u:float=phase+.5*index
        # Exact 087 walking and transition arc, subtly approach the 088
        # horizontal trailing arm only at near-full sprint speed.
        var high:float=smoothstep(.80,1.,w)
        var upper:float=lerpf(-6.+30.*cos(TAU*u),82.+9.*cos(TAU*u+.4),w)
        var elbow:float=lerpf(-60.+12.*cos(TAU*u+.45),-12.+8.*sin(TAU*u),w)
        upper=lerpf(upper,94.+5.*cos(TAU*u+.4),high)
        elbow=lerpf(elbow,-6.+4.*sin(TAU*u),high)
        var a:Vector2=rig.joints[rig.ids["elbow_"+name]].offset
        var b:Vector2=rig.joints[rig.ids["hand_"+name]].offset
        var rest_a:float=rad_to_deg(a.angle())-90.
        var rest_b:float=rad_to_deg(b.angle())-90.
        p.angles["shoulder_"+name]=upper-float(p.angles.hips)-float(p.angles.chest)-rest_a
        p.angles["elbow_"+name]=elbow+rest_a-rest_b
    return result
