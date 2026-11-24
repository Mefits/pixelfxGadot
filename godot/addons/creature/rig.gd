extends RefCounted
## Data-driven 2D joint graph. Root/world position, pose and render skin are separate.
## Each joint has a parent, rest offset and an optional IK chain limit.
var joints: Array=[]
var ids: Dictionary={}
var points: Dictionary={}
var rotations: Dictionary={}

func add_joint(id: String,parent: String,offset: Vector2,ik_root: String="") -> bool:
    if id.is_empty() or ids.has(id) or (not parent.is_empty() and not ids.has(parent)) or (parent.is_empty() and not joints.is_empty()):
        return false
    ids[id]=joints.size()
    joints.append({"id":id,"parent":parent,"offset":offset,"ik_root":ik_root})
    return true

func evaluate(pose: Dictionary) -> void:
    points.clear()
    rotations.clear()
    var angles: Dictionary=pose.get("angles",{})
    var shift: Array=pose.get("root",[0,0])
    for j in joints:
        var id: String=j.id
        var par: String=j.parent
        var angle: float=deg_to_rad(float(angles.get(id,0)))
        if par.is_empty():
            points[id]=Vector2(shift[0],shift[1])+j.offset
            rotations[id]=angle
        else:
            points[id]=Vector2(points[par])+Vector2(j.offset).rotated(float(rotations[par]))
            rotations[id]=float(rotations[par])+angle

func point(id: String) -> Vector2:
    return points.get(id,Vector2.ZERO)

func solve_ik(pose: Dictionary,end: String,target: Vector2,iterations: int=12) -> Dictionary:
    # CCD: no hard-coded limb names or number of joints. Bone lengths stay fixed.
    var out: Dictionary=pose.duplicate(true)
    if not ids.has(end):
        return out
    var chain: Array[String]=[]
    var j: Dictionary=joints[ids[end]]
    var stop: String=j.ik_root
    var par: String=j.parent
    while not par.is_empty():
        chain.append(par)
        if par==stop:
            break
        par=joints[ids[par]].parent
    if not out.has("angles"):
        out["angles"]={}
    evaluate(out)
    for _i in range(iterations):
        for id in chain:
            var a: Vector2=point(end)-point(id)
            var b: Vector2=target-point(id)
            if a.length_squared()<0.00001 or b.length_squared()<0.00001:
                continue
            var delta: float=rad_to_deg(a.angle_to(b))
            out["angles"][id]=wrapf(float(out["angles"].get(id,0))+delta,-180,180)
            evaluate(out)
        if point(end).distance_to(target)<.05:
            break
    return out

static func humanoid():
    var r=load("res://addons/creature/rig.gd").new()
    r.add_joint("hips","",Vector2(0,-22))
    r.add_joint("chest","hips",Vector2(0,-16))
    r.add_joint("head","chest",Vector2(0,-10))
    r.add_joint("shoulder_far","chest",Vector2(-5,1))
    r.add_joint("elbow_far","shoulder_far",Vector2(-4,10))
    r.add_joint("hand_far","elbow_far",Vector2(1,10),"shoulder_far")
    r.add_joint("shoulder_near","chest",Vector2(5,1))
    r.add_joint("elbow_near","shoulder_near",Vector2(4,10))
    r.add_joint("hand_near","elbow_near",Vector2(1,10),"shoulder_near")
    r.add_joint("thigh_far","hips",Vector2(-4,0))
    r.add_joint("knee_far","thigh_far",Vector2(-2,11))
    r.add_joint("foot_far","knee_far",Vector2(2,11),"thigh_far")
    r.add_joint("thigh_near","hips",Vector2(4,0))
    r.add_joint("knee_near","thigh_near",Vector2(2,11))
    r.add_joint("foot_near","knee_near",Vector2(-2,11),"thigh_near")
    return r
