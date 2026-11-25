extends "res://addons/creature/rig.gd"
## Lab-only shoulder girdle experiment. A latent horizontal shoulder bar
## projects to the side-view plane. All arm/leg segment lengths are unchanged.
## Not a full 3D body or runtime collision model.
static func make():
    var original=load("res://addons/creature/rig.gd").humanoid()
    var r=load("res://lab/anatomy_rd/rig_049.gd").new()
    for j in original.joints:r.add_joint(j.id,j.parent,j.offset,j.ik_root)
    return r

func evaluate(pose:Dictionary)->void:
    var turn:=clampf(float(pose.get("angles",{}).get("shoulder_turn",0.0)),0.0,90.0)
    var x:=sqrt(50.0)*sin(deg_to_rad(45.0-turn))
    joints[ids["shoulder_near"]].offset=Vector2(x,1)
    joints[ids["shoulder_far"]].offset=Vector2(-x,1)
    var pelvis:=clampf(float(pose.get("angles",{}).get("pelvis_turn",0.0)),0.0,90.0)
    var hip_x:=sqrt(32.0)*sin(deg_to_rad(45.0-pelvis))
    joints[ids["thigh_near"]].offset=Vector2(hip_x,0)
    joints[ids["thigh_far"]].offset=Vector2(-hip_x,0)
    super.evaluate(pose)
