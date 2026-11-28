extends RefCounted
## Spatial MotionEntry: two consecutive solved poses, world coordinates at 60 Hz.
## Captures signed yaw, local orientations, bone directions, foot frames and
## independent contact state. Never derives a new pose by lerping world joints.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
var current:Dictionary={}
var previous:Dictionary={}
var steps:Dictionary={}
var root_step:=Vector3.ZERO
var yaw_step:int=0
var toe_steps:Dictionary={}
var contacts:Dictionary={}

static func sample(r,pose:Dictionary,support=null)->Dictionary:
    assert(r.spatial_enabled)
    var dirs:Dictionary={}
    var rotations:Dictionary={}
    var feet:Dictionary={}
    for id in r.ids_in_order():
        var parent:String=r.parent_id(id)
        var basis:Basis=r.joint_basis[id]
        if parent.is_empty():
            rotations[id]=(FK.yaw_basis(r.yaw_units).transposed()*basis).orthonormalized().get_rotation_quaternion()
        else:
            var pb:Basis=r.joint_basis[parent]
            rotations[id]=(pb.transposed()*basis).orthonormalized().get_rotation_quaternion()
            dirs[id]=(pb.transposed()*(r.point3(id)-r.point3(parent))).normalized()
    for side in Support.SIDES:
        feet[side]=(FK.yaw_basis(r.yaw_units).transposed()*Support.foot_frame(r,pose,side)).orthonormalized().get_rotation_quaternion()
    var toes:Dictionary={}
    for side in Support.SIDES:toes[side]=Support.toe(r,pose,side)
    return {"pose":pose.duplicate(true),"yaw":r.yaw_units,"root":r.point3("hips"),"xyz":r.joint_xyz.duplicate(),"basis":r.joint_basis.duplicate(),"dirs":dirs,"rotations":rotations,"feet":feet,"toes":toes,"overrides":r.foot_basis_override.duplicate(),"contacts":support.contacts.duplicate(true) if support!=null else {}}

func _init(now:Dictionary,prior:Dictionary={}):
    current=now.duplicate(true)
    previous=(now if prior.is_empty() else prior).duplicate(true)
    root_step=Vector3(current.root)-Vector3(previous.root)
    yaw_step=int(current.yaw)-int(previous.yaw)
    contacts=current.contacts.duplicate(true)
    for id in current.xyz:steps[id]=Vector3(current.xyz[id])-Vector3(previous.xyz[id])
    for side in Support.SIDES:toe_steps[side]=Vector3(current.toes[side])-Vector3(previous.toes[side])

static func write_exact(r,s:Dictionary)->void:
    r.spatial_enabled=true
    r.yaw_units=int(s.yaw)
    r.joint_xyz=s.xyz.duplicate()
    r.joint_basis=s.basis.duplicate()
    r.foot_basis_override=s.overrides.duplicate()
    update_xy(r)

static func update_xy(r)->void:
    r.points.clear()
    for id in r.ids_in_order():
        var p:Vector3=r.point3(id)
        r.points[id]=Vector2(p.x,p.y)

# Extrapolate the shortest relative quaternion delta, limited to a half-turn
# over the correction horizon. Full body yaw is handled independently as int.
static func extrapolate(old:Quaternion,now:Quaternion,t:float)->Quaternion:
    var delta:Quaternion=(now*old.inverse()).normalized()
    if delta.w<0.:delta=-delta
    # atan2 of the quaternion vector avoids acos(w) cancellation near identity.
    # Explicitly normalize the axis: Godot get_axis() is ill-conditioned here.
    var vector:=Vector3(delta.x,delta.y,delta.z)
    var magnitude:float=vector.length()
    if magnitude<.0000001:return now
    var angle:float=2.*atan2(magnitude,clampf(delta.w,0.,1.))
    return (Quaternion(vector/magnitude,minf(angle*t,PI))*now).normalized()

static func direction_step(old:Vector3,now:Vector3,t:float)->Vector3:
    var d:float=clampf(old.dot(now),-1.,1.)
    if d>.999999:return now
    var axis:Vector3=old.cross(now)
    if axis.length_squared()<.000001:
        axis=old.cross(Vector3.RIGHT if absf(old.x)<.8 else Vector3.BACK)
    return (Quaternion(axis.normalized(),minf(acos(d)*t,PI))*now).normalized()

static func blend_direction(a:Vector3,b:Vector3,w:float)->Vector3:
    var d:float=clampf(a.dot(b),-1.,1.)
    if d>.999999:return a.lerp(b,w).normalized()
    var axis:Vector3=a.cross(b)
    if axis.length_squared()<.000001:
        axis=a.cross(Vector3.RIGHT if absf(a.x)<.8 else Vector3.BACK)
    return (Quaternion(axis.normalized(),acos(d)*w)*a).normalized()

func art_pose(target:Dictionary,w:float)->Dictionary:
    var p:Dictionary=target.duplicate(true)
    for id in current.pose.angles:
        var start:float=current.pose.angles[id]
        var end:float=target.angles.get(id,start)
        p.angles[id]=lerpf(start,end,w) if id in ["pelvis_turn","shoulder_turn"] else lerp_angle(deg_to_rad(start),deg_to_rad(end),w)*180./PI
    return p

# The incoming clip is sampled at its real local tick, never retimed.
# Blend a continued entry to incoming local rotations/directions. The
# reconstruction uses canonical lengths, including the spatial girdles.
# Tick zero and the unconstrained horizon publish exact solved samples.
func blend(r,target:Dictionary,age:int,duration:int)->Dictionary:
    assert(duration>0 and age>=0)
    if age==0:
        write_exact(r,current)
        return current.pose.duplicate(true)
    if age>=duration:
        write_exact(r,target)
        return target.pose.duplicate(true)
    var u:float=float(age)/duration
    var w:float=u*u*(3.-2.*u)
    var t:float=float(age)*(1.-u*.5)
    var yaw:int=int(current.yaw)+roundi(lerpf(float(yaw_step)*t,float(int(target.yaw)-int(current.yaw)),w))
    r.yaw_units=yaw
    r.spatial_enabled=true
    r.joint_xyz.clear()
    r.joint_basis.clear()
    r.foot_basis_override.clear()
    var yaw_frame:Basis=FK.yaw_basis(yaw)
    for id in r.ids_in_order():
        var parent:String=r.parent_id(id)
        var q:Quaternion=extrapolate(previous.rotations[id],current.rotations[id],t).slerp(target.rotations[id],w).normalized()
        if parent.is_empty():
            r.joint_xyz[id]=(Vector3(current.root)+root_step*t).lerp(target.root,w)
            r.joint_basis[id]=yaw_frame*Basis(q)
        else:
            var pb:Basis=r.joint_basis[parent]
            var predicted:Vector3=direction_step(previous.dirs[id],current.dirs[id],t)
            var dir:Vector3=blend_direction(predicted,target.dirs[id],w)
            r.joint_xyz[id]=r.point3(parent)+pb*(dir*r.rest_offset_xyz(id).length())
            r.joint_basis[id]=pb*Basis(q)
    for side in Support.SIDES:
        var q:Quaternion=extrapolate(previous.feet[side],current.feet[side],t).slerp(target.feet[side],w).normalized()
        r.foot_basis_override[side]=yaw_frame*Basis(q)
    update_xy(r)
    return art_pose(target.pose,w)

# Conversion is intentionally strict. At a full aligned turn, compare
# against canonical lifted pose AND its actual legacy XY. Contacts must
# be released explicitly; arbitrary depth, twists or IK cannot silently
# disappear. Successful conversion still discards the reconstructed Z.
static func legacy_gate(r,pose:Dictionary,support=null,tolerance:float=.0001)->Dictionary:
    var aligned:bool=posmod(r.yaw_units,FK.TURN)==0
    var contact_free:bool=support==null or support.contacts.is_empty()
    var lifted=FK.new()
    lifted.lift_legacy(pose)
    var flat=FK.new()
    flat.evaluate_legacy(pose)
    var xy:float=0.
    var space:float=0.
    var basis_error:float=0.
    for id in r.ids_in_order():
        xy=maxf(xy,r.point(id).distance_to(flat.point(id)))
        space=maxf(space,r.point3(id).distance_to(lifted.point3(id)))
        var actual:Basis=r.joint_basis[id]
        var expected:Basis=lifted.joint_basis[id]
        basis_error=maxf(basis_error,maxf(actual.x.distance_to(expected.x),maxf(actual.y.distance_to(expected.y),actual.z.distance_to(expected.z))))
    for side in Support.SIDES:
        var actual:Basis=Support.foot_frame(r,pose,side)
        var expected:Basis=Support.foot_frame(lifted,pose,side)
        basis_error=maxf(basis_error,maxf(actual.x.distance_to(expected.x),maxf(actual.y.distance_to(expected.y),actual.z.distance_to(expected.z))))
    return {"allowed":aligned and contact_free and xy<=tolerance and space<=tolerance and basis_error<=tolerance,"aligned":aligned,"contact_free":contact_free,"xy_error":xy,"spatial_error":space,"basis_error":basis_error}
