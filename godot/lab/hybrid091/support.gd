extends RefCounted
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
var chains:Array=[]
var rig

func _init(r):
    rig=r
    for side in Leg.SIDES:
        var upper:Vector2=r.joints[r.ids["knee_"+side]].offset
        var lower:Vector2=r.joints[r.ids["foot_"+side]].offset
        chains.append([upper.length(),lower.length(),upper.angle(),lower.angle()])

# Evaluate the common parent frame once. Changing root height translates both
# thigh origins equally. Neither leg can affect its sibling's parent transform.
func resolve(p:Dictionary,paths:Array)->void:
    rig.evaluate(p)
    var goals:Array[Vector2]=[]
    var drop:=0.
    for i in 2:
        var side:String=Leg.SIDES[i]
        p.angles["foot_pitch_"+side]=paths[i].pitch
        var goal:Vector2=paths[i].toe-IK.toe_vector(p,side)
        goals.append(goal)
        var delta:Vector2=goal-rig.point("thigh_"+side)
        var radius:float=chains[i][0]+chains[i][1]-.15
        drop=maxf(drop,delta.y-sqrt(maxf(0.,radius*radius-delta.x*delta.x)))
    drop=clampf(drop,0.,2.)
    p.root[1]+=drop
    for i in 2:
        var side:String=Leg.SIDES[i]
        var chain:Array=chains[i]
        var delta:Vector2=goals[i]-rig.point("thigh_"+side)-Vector2.DOWN*drop
        var a:float=chain[0]
        var b:float=chain[1]
        var d:=clampf(delta.length(),absf(a-b)+.002,a+b-.002)
        var bend:=acos(clampf((d*d-a*a-b*b)/(2.*a*b),-1.,1.))
        var upper:=delta.angle()-atan2(b*sin(bend),a+b*cos(bend))
        p.angles["thigh_"+side]=rad_to_deg(wrapf(upper-chain[2]-rig.rotations.hips,-PI,PI))
        p.angles["knee_"+side]=rad_to_deg(wrapf(bend+chain[2]-chain[3],-PI,PI))
        if not Leg.valid(p,side):
            Leg.put(p,side,Leg.bend(p,side),Leg.ankle(p,side))
    rig.evaluate(p)
