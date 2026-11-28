extends "res://lab/spatial_lab/spatial_mocap_010.gd"
## G20 stylization: signed source winding, continuous retiming, local
## pose edits with canonical lengths. Parent grounding is unchanged.
## 1=A exact 011 C; 2=B pose emphasis; 3=C staged timing + pose emphasis.
const RetimingCurve=preload("res://lab/spatial_lab/spatial_roundhouse_007.gd")
const MAPS=[
    [],
    [[0.,0.],[5.,12.],[12.,34.],[16.,44.],[19.,56.],[23.,64.],[30.,80.],[36.,104.],[54.,170.]],
    [[0.,0.],[5.,12.],[12.,34.],[16.,44.],[19.,56.],[23.,64.],[30.,80.],[36.,104.],[54.,170.]],
    [[0.,0.],[6.,12.],[13.,34.],[18.,44.],[22.,56.],[27.,64.],[35.,80.],[43.,104.],[60.,170.]]
]
const DURATIONS=[170,54,54,60]
const HIT_TICKS=[56,19,19,22]
const LEAN=[0.,17.,21.,24.]
const REACH=[0.,.985,.990,.992]
const AIM=[0.,.65,.77,.82]
var mode:int=1
var source_time:float=0.

func setup(art:Dictionary)->void:
    source_time=0.
    super.setup(art)

func source_at(tick:int)->float:
    return RetimingCurve.curve(MAPS[mode],float(tick))

# 010 uses normalized linear direction interpolation. Same interpolation
# with fractional source time instead of rounding to original 60Hz ticks.
func sample(_tick:int,k:int)->Vector3:
    var u:float=clampf(source_time*.5,0.,float(N-1))
    var lo:int=floori(u)
    var hi:int=mini(lo+1,N-1)
    var v:Vector3=vec(lo,k).lerp(vec(hi,k),u-float(lo))
    return v if k==0 else v.normalized()

func yaw_at(_tick:int)->int:
    var u:float=clampf(source_time*.5,0.,float(N-1))
    var lo:int=floori(u)
    return roundi(lerpf(float(yaw_samples[lo]),float(yaw_samples[mini(lo+1,N-1)]),u-float(lo)))

static func rotate_upper(r,rotation:Basis)->void:
    var pivot:Vector3=r.point3("hips")
    for id in r.ids_in_order():
        var node:String=id
        while not node.is_empty() and node!="chest":node=r.parent_id(node)
        if node!="chest":continue
        r.joint_xyz[id]=pivot+rotation*(r.point3(id)-pivot)
        r.joint_basis[id]=rotation*Basis(r.joint_basis[id])

func direct(r,tick:int,art:Dictionary)->void:
    super.direct(r,tick,art)
    # Edits only during the source's free striking-leg interval. The
    # original limb/torso motion remains the basis, not a replacement clip.
    var t:float=source_time
    var load:float=smoothstep(34.,43.,t)*(1.-smoothstep(44.,53.,t))
    var peak:float=smoothstep(43.,56.,t)*(1.-smoothstep(57.,78.,t))
    if peak<=.000001 and load<=.000001:return
    var hip:Vector3=r.point3("thigh_near")
    var knee:Vector3=r.point3("knee_near")
    var ankle:Vector3=r.point3("foot_near")
    var ray:Vector3=ankle-hip
    var old_lower:Vector3=(ankle-knee).normalized()
    var a:float=r.rest_offset_xyz("knee_near").length()
    var b:float=r.rest_offset_xyz("foot_near").length()
    var goal_dir:Vector3=ray.normalized()
    # Source kick already points toward +X. Give the silhouette a clearer
    # diagonal, but do not force the setup/retraction into a forward kick.
    var authored:Vector3=Vector3(1.,[0.,-.54,-.60,-.65][mode],0.).normalized()
    goal_dir=Entry.blend_direction(goal_dir,authored,peak*AIM[mode])
    var radius:float=lerpf(ray.length(),(a+b)*REACH[mode],peak)
    radius*=1.-load*[0.,.075,.085,.095][mode]
    radius=clampf(radius,IK.min_reach(a,b),IK.max_reach(a,b))
    var axis:Vector3=ray.normalized()
    var pole:Vector3=IK.perpendicular(axis,knee-hip)
    var q:Dictionary=IK.solve(hip,hip+goal_dir*radius,a,b,axis,pole)
    var upper:Vector3=Vector3(q.knee)-hip
    var lower:Vector3=Vector3(q.ankle)-Vector3(q.knee)
    var normal:Vector3=upper.cross(lower).normalized()
    r.joint_xyz.knee_near=q.knee
    r.joint_xyz.foot_near=q.ankle
    r.joint_basis.thigh_near=IK.bone_frame(r.rest_offset_xyz("knee_near"),upper,normal)
    r.joint_basis.knee_near=IK.bone_frame(r.rest_offset_xyz("foot_near"),lower,normal)
    var sole:Basis=Basis(Quaternion(old_lower,lower.normalized()))*Basis(r.foot_basis_override.near)
    r.foot_basis_override.near=sole
    r.joint_basis.foot_near=sole
    # Whole chest subtree moves rigidly about pelvis: arms keep their
    # source relationships to the torso, no arbitrary raised-hand pose.
    rotate_upper(r,Basis(Vector3.BACK,deg_to_rad(-LEAN[mode]*peak)))
    Entry.update_xy(r)

func evaluate_style(tick:int)->Dictionary:
    assert(mode>=1 and mode<=3 and tick>=0 and tick<=DURATIONS[mode])
    source_time=source_at(tick)
    # Parent support schedule uses the nearest original sample. Direction
    # interpolation above is continuous; only discrete contact labels round.
    return evaluate(roundi(source_time),true)
