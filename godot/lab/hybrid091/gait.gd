extends "res://lab/distance_gait_087.gd"
## Distance calendar in rig units. Speed uses historical units per 1/60 s.
var arm_sweep:=94.
var flight_width:=5.

func move_distance(speed:float, distance:float)->void:
    velocity=speed
    travel+=distance
    while travel>=float(queue[1]):
        queue.pop_front()
        queue.append(float(queue[1])+step_for(velocity))
        side=1-side
        legs[side]={"start":queue[0],"end":queue[2]}

func path_for(index:int,w:float)->Dictionary:
    var path:=super.path_for(index,w)
    if path.stance:return path
    var leg:Dictionary=legs[index]
    var swing:float=float(leg.end)-float(leg.start)-STANCE_DISTANCE
    var s:=clampf((travel-float(leg.start)-STANCE_DISTANCE)/swing,0.,1.)
    var x:float
    if s<.25:x=-flight_width*smoothstep(0.,.25,s)
    elif s<.75:x=lerpf(-flight_width,flight_width,smoothstep(.25,.75,s))
    else:x=flight_width*(1.-smoothstep(.75,1.,s))
    var weight:=smoothstep(.65,1.,w)
    path.toe+=Vector2(x,-3.*maxf(0.,sin(TAU*s))*pow(sin(PI*s),2.))*weight
    return path

func intent()->Dictionary:
    var w:float=gait_for(velocity)
    var f:float=(travel-float(queue[0]))/(float(queue[1])-float(queue[0]))
    var phase:float=float(side)*.5+.5*f
    var p:Dictionary=template.duplicate(true)
    p.root=[0.,lerpf(.6,1.4,w)+lerpf(.6,1.,w)*cos(4.*PI*(phase-.1*w))]
    p.angles.hips=lerpf(10.,38.,w)+2.*sin(4.*PI*phase)
    p.angles.chest=lerpf(3.,6.,w)+2.*cos(4.*PI*phase)
    p.angles.head=lerpf(5.,15.,w)-float(p.angles.hips)-float(p.angles.chest)
    var bend:=10.*smoothstep(.65,1.,w)
    p.angles.chest+=bend
    p.angles.head-=bend
    p.angles.pelvis_turn=45.+8.*sin(TAU*phase)
    p.angles.shoulder_turn=lerpf(45.,35.,w)-lerpf(12.,5.,w)*sin(TAU*phase)
    for index in 2:
        var name:String=Leg.SIDES[index]
        var u:float=phase+.5*index
        # Exact 087 walking and transition arc, subtly approach the 088
        # horizontal trailing arm only at near-full sprint speed.
        var high:float=smoothstep(.80,1.,w)
        var upper:float=lerpf(-6.+30.*cos(TAU*u),82.+9.*cos(TAU*u+.4),w)
        var elbow:float=lerpf(-60.+12.*cos(TAU*u+.45),-12.+8.*sin(TAU*u),w)
        upper=lerpf(upper,arm_sweep+5.*cos(TAU*u+.4),high)
        elbow=lerpf(elbow,-6.+4.*sin(TAU*u),high)
        var a:Vector2=rig.joints[rig.ids["elbow_"+name]].offset
        var b:Vector2=rig.joints[rig.ids["hand_"+name]].offset
        var rest_a:float=rad_to_deg(a.angle())-90.
        var rest_b:float=rad_to_deg(b.angle())-90.
        p.angles["shoulder_"+name]=upper-float(p.angles.hips)-float(p.angles.chest)-rest_a
        p.angles["elbow_"+name]=elbow+rest_a-rest_b
    return {"pose":p,"paths":[path_for(0,w),path_for(1,w)],"gait":w}
