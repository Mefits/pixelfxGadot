extends "res://lab/anatomy_rd/rig_049.gd"
## Lab-only per-character proportions; immutable source offsets, no clip edits.
static func create(upper_arm:float=1.,forearm:float=1.):
    var base=load("res://addons/creature/rig.gd").humanoid()
    var r=load("res://lab/anatomy_rd/rig_proportions_067.gd").new()
    for j in base.joints:
        var offset:Vector2=j.offset
        if j.id in ["elbow_near","elbow_far"]:offset*=clampf(upper_arm,.65,1.25)
        if j.id in ["hand_near","hand_far"]:offset*=clampf(forearm,.65,1.25)
        r.add_joint(j.id,j.parent,offset,j.ik_root)
    return r

func reach(end:String)->float:
    var wrist:Dictionary=joints[ids[end]]
    return Vector2(wrist.offset).length()+Vector2(joints[ids[wrist.parent]].offset).length()

# Solve against the requested world-space target when possible; otherwise
# report the clamp, rather than silently pretending the contact was reached.
# Analytic two-link seed avoids CCD singularity at full extension; CCD still
# validates/refines the pose. Preserve the authored elbow bend direction.
func aim_arm(p:Dictionary,end:String,target:Vector2)->Dictionary:
    evaluate(p)
    var elbow:String=joints[ids[end]].parent
    var shoulder:String=joints[ids[elbow]].parent
    var anchor:Vector2=point(shoulder)
    var delta:Vector2=target-anchor
    var l1:float=Vector2(joints[ids[elbow]].offset).length()
    var l2:float=Vector2(joints[ids[end]].offset).length()
    var d:float=clampf(delta.length(),absf(l1-l2)+.001,l1+l2-.001)
    var dir:Vector2=delta.normalized() if delta.length()>.0001 else (point(end)-anchor).normalized()
    if dir.length_squared()<.0001:dir=Vector2.RIGHT
    var adjusted:Vector2=anchor+dir*d
    var u:Vector2=point(elbow)-anchor
    var v:Vector2=point(end)-point(elbow)
    var bend_sign:float=1. if u.cross(v)>=0. else -1.
    var inner:float=acos(clampf((d*d-l1*l1-l2*l2)/(2.*l1*l2),-1.,1.))*bend_sign
    var global_upper:float=dir.angle()-atan2(l2*sin(inner),l1+l2*cos(inner))
    var shoulder_parent:String=joints[ids[shoulder]].parent
    var upper_rest:float=Vector2(joints[ids[elbow]].offset).angle()
    var fore_rest:float=Vector2(joints[ids[end]].offset).angle()
    var seeded:Dictionary=p.duplicate(true)
    seeded.angles[shoulder]=rad_to_deg(wrapf(global_upper-upper_rest-float(rotations[shoulder_parent]),-PI,PI))
    seeded.angles[elbow]=rad_to_deg(wrapf(inner+upper_rest-fore_rest,-PI,PI))
    var result:Dictionary=solve_ik(seeded,end,adjusted,32)
    evaluate(result)
    return {"pose":result,"requested_error":point(end).distance_to(target),
        "adjusted_error":point(end).distance_to(adjusted),"clamp_distance":target.distance_to(adjusted)}
