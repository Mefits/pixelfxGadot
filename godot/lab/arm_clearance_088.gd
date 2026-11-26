extends "res://lab/distance_gait_087.gd"
## 088: separate shoulder and elbow phase during gait change.
## Same leg scheduler, torso, support and world travel as 087.
func sample()->Dictionary:
    var result:Dictionary=super.sample()
    var p:Dictionary=result.pose
    var w:float=result.gait
    var phase:float=result.phase
    var shoulder_mix:float=smoothstep(.1,.65,w)
    var elbow_mix:float=smoothstep(.5,.9,w)
    var fold:float=25.*pow(sin(PI*w),2.)
    for index in 2:
        var name:String=Leg.SIDES[index]
        var u:float=phase+.5*index
        # Keep the hand closer to chest during the sweep, then extend it
        # behind the shoulder. Reference: nearly horizontal trailing arms.
        var upper:float=lerpf(-12.+25.*cos(TAU*u),94.+5.*cos(TAU*u+.4),shoulder_mix)
        var elbow:float=lerpf(-95.+12.*cos(TAU*u+.45),-6.+4.*sin(TAU*u),elbow_mix)-fold
        var a:Vector2=rig.joints[rig.ids["elbow_"+name]].offset
        var b:Vector2=rig.joints[rig.ids["hand_"+name]].offset
        var rest_a:float=rad_to_deg(a.angle())-90.
        var rest_b:float=rad_to_deg(b.angle())-90.
        p.angles["shoulder_"+name]=upper-float(p.angles.hips)-float(p.angles.chest)-rest_a
        p.angles["elbow_"+name]=elbow+rest_a-rest_b
    return result
