extends "res://addons/creature/rig.gd"
# Data-driven dimensions. The projected girdle must scale too: rig049
# overwrites its offsets each evaluation, so just changing rest offsets fails.
var shape:Dictionary
static func create(s:Dictionary):
    var r=load("res://lab/anatomy_rd/rig_dimensions_070.gd").new()
    r.shape=s.duplicate(true)
    var base=load("res://addons/creature/rig.gd").humanoid()
    for j in base.joints:
        var off:Vector2=j.offset
        match j.id:
            "hips","knee_far","knee_near","foot_far","foot_near":off*=float(s.leg)
            "chest":off*=float(s.torso)
            "head":off*=float(s.neck)
            "elbow_far","elbow_near":off*=.90*float(s.upper)
            "hand_far","hand_near":off*=.90*float(s.fore)
            "shoulder_far","shoulder_near":off=Vector2(off.x*float(s.shoulder),off.y*float(s.torso))
            "thigh_far","thigh_near":off.x*=float(s.hip)
        r.add_joint(j.id,j.parent,off,j.ik_root)
    return r
func evaluate(pose:Dictionary)->void:
    var a:Dictionary=pose.get("angles",{})
    var x:float=sqrt(50.)*sin(deg_to_rad(45.-clampf(float(a.get("shoulder_turn",0.)),0.,90.)))*float(shape.shoulder)
    var h:float=sqrt(32.)*sin(deg_to_rad(45.-clampf(float(a.get("pelvis_turn",0.)),0.,90.)))*float(shape.hip)
    joints[ids["shoulder_near"]].offset=Vector2(x,float(shape.torso))
    joints[ids["shoulder_far"]].offset=Vector2(-x,float(shape.torso))
    joints[ids["thigh_near"]].offset=Vector2(h,0)
    joints[ids["thigh_far"]].offset=Vector2(-h,0)
    super.evaluate(pose)
