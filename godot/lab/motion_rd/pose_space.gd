extends RefCounted
## Pure pose transforms. Normalized endpoints are relative to the shoulder/thigh.
const TIPS = ["hand_near", "hand_far", "foot_near", "foot_far"]
const CHAINS = {
    "hand_near": ["shoulder_near", "elbow_near"],
    "hand_far": ["shoulder_far", "elbow_far"],
    "foot_near": ["thigh_near", "knee_near"],
    "foot_far": ["thigh_far", "knee_far"]
}

static func solve(rig, source: Dictionary, edit: Dictionary) -> Dictionary:
    var pose := source.duplicate(true)
    var hip := float(edit.tilt[0])
    var chest := float(edit.tilt[1])
    pose.angles.hips = hip
    pose.angles.chest = chest - hip
    pose.angles.head = -chest * 0.45
    rig.evaluate(pose)
    for tip in edit.targets:
        var pair: Array = CHAINS[tip]
        var upper: Dictionary = rig.joints[rig.ids[pair[0]]]
        var first: Vector2 = rig.joints[rig.ids[pair[1]]].offset
        var last: Vector2 = rig.joints[rig.ids[tip]].offset
        var data: Array = edit.targets[tip]
        var ray := Vector2(data[0], data[1])
        var a := first.length()
        var b := last.length()
        var reach := clampf(ray.length() * (a+b), absf(a-b)+0.0001, a+b-0.0001)
        var along := (a*a - b*b + reach*reach) / (2.0*reach)
        var pole := float(data[2])
        var axis := ray.normalized()
        var mid := axis*along + Vector2(-axis.y, axis.x)*sqrt(maxf(0,a*a-along*along))*pole
        var proximal := mid.angle() - first.angle()
        var distal := (axis*reach-mid).angle() - last.angle()
        pose.angles[pair[0]] = rad_to_deg(wrapf(proximal - float(rig.rotations[upper.parent]), -PI, PI))
        pose.angles[pair[1]] = rad_to_deg(wrapf(distal - proximal, -PI, PI))
    return pose

## Lift the planar FK edge vectors into 3D. Each edge is rotated independently
## around a vertical axis in world space, with hips and chest carrying separate yaw.
## The input body has a measured outline in side view, no measured thickness.
static func lift(rig, yaw: Array) -> Dictionary:
    var xyz := {}
    for j in rig.joints:
        var id: String = j.id
        var pt: Vector2 = rig.point(id)
        if j.parent == "":
            xyz[id] = Vector3(pt.x,pt.y,0)
            continue
        var d: Vector2 = pt-rig.point(j.parent)
        var channel := 0
        if id == "head" or id.begins_with("shoulder"):
            channel = 1
        for i in TIPS.size():
            var tip: String = TIPS[i]
            if id == tip or id == CHAINS[tip][1]:
                channel = i+2
                break
        var angle := deg_to_rad(float(yaw[channel]))
        # Positive limb yaw brings the end toward camera, on either screen side.
        var dz := d.x*sin(angle)
        xyz[id] = Vector3(xyz[j.parent]) + Vector3(d.x*cos(angle),d.y,dz)
    return xyz

static func project(points: Dictionary, focal: float) -> Dictionary:
    var screen := {}
    var pivot := Vector2(points.hips.x,points.hips.y)
    for id in points:
        var v: Vector3 = points[id]
        var scale_factor := focal/(focal-v.z)
        screen[id] = pivot+(Vector2(v.x,v.y)-pivot)*scale_factor
    return screen

## Reconstruct a reachable wrist/ankle on the camera ray of the gameplay
## anchor. The feasible depths are the roots of a ray/sphere intersection.
## Choose the nearest feasible depth to the staged depth and preserve elbow pole.
static func pin_screen(rig, points: Dictionary, tip: String, focal: float) -> bool:
    var chain: Array = CHAINS[tip]
    var base: Vector3 = points[chain[0]]
    var mid: Vector3 = points[chain[1]]
    var end: Vector3 = points[tip]
    var a := base.distance_to(mid)
    var b := mid.distance_to(end)
    var target: Vector2 = rig.point(tip)
    var pivot: Vector2 = rig.point("hips")
    var ray := Vector3((pivot.x-target.x)/focal,(pivot.y-target.y)/focal,1)
    var origin := Vector3(target.x,target.y,0)
    var center_z := (base-origin).dot(ray)/ray.length_squared()
    var radial_sq := (a+b-0.00001)**2 - base.distance_squared_to(origin+ray*center_z)
    if radial_sq < 0: return false
    var extent := sqrt(radial_sq/ray.length_squared())
    var z := clampf(end.z,center_z-extent,center_z+extent)
    var goal := origin+ray*z
    var length := base.distance_to(goal)
    if length < absf(a-b)+0.00001: return false
    var axis := (goal-base)/length
    var pole := mid-base-axis*(mid-base).dot(axis)
    if pole.length_squared()<0.0000001:
        pole=axis.cross(Vector3.FORWARD)
        if pole.length_squared()<0.0000001: pole=axis.cross(Vector3.UP)
    var along := (a*a-b*b+length*length)/(2*length)
    var radius := sqrt(maxf(0,a*a-along*along))
    var rest := base+axis*along
    points[chain[1]]=rest+pole.normalized()*radius
    points[tip]=goal
    if tip.begins_with("hand"):
        # Rotation around the shoulder/wrist axis preserves the pinned wrist and
        # segment lengths. Resolve face/forearm overlap in this camera only.
        var best := INF
        var chosen: Vector3 = points[chain[1]]
        for degrees in [0,-25,25,-50,50,-80,80]:
            var candidate := rest+pole.normalized().rotated(axis,deg_to_rad(degrees))*radius
            points[chain[1]]=candidate
            var screen:=project(points,focal)
            var nearest:=Geometry2D.get_closest_point_to_segment(screen.head,screen[chain[1]],screen[tip])
            var overlap:=maxf(0,8.5-nearest.distance_to(screen.head))
            var cost:float=overlap*overlap+0.0004*degrees*degrees
            if cost<best:
                best=cost
                chosen=candidate
        points[chain[1]]=chosen
    return true
