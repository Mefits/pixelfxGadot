extends RefCounted
## G20 direction retarget. Fixture derived from ACCAD Open Motion Project
## CC BY 3.0; see docs/SPATIAL_MOCAP_010_RU.md.
## World directions preserve source swing geometry; target rest lengths
## and joint graph remain canonical. No claim of exact source bone roll.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const IK=preload("res://lab/spatial_lab/spatial_ik.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
const N:int=86
const END:int=170
const STRIDE:int=45
const DATA_PATH="res://lab/spatial_lab/mocap/g20_directions.b64"
const EXPECTED_SHA="962c66a057833d94e873bb1a4b651e00c516e74724c88435c04c96e70b1fbc7f"
var data:PackedByteArray
var yaw_samples:Array[int]=[]
var rig=FK.new()
var support=Support.new()
var active_side:String=""
var correction:=Vector3.ZERO
var base_floor:float=0.
var pose:Dictionary={}
var shift_peak:float=0.

func _init():
    data=Marshalls.base64_to_raw(FileAccess.get_file_as_string(DATA_PATH).strip_edges())
    var h:=HashingContext.new()
    h.start(HashingContext.HASH_SHA256)
    h.update(data)
    assert(data.size()==N*STRIDE and h.finish().hex_encode()==EXPECTED_SHA)
    var prev:float=0.
    var accum:float=0.
    for i in N:
        var v:Vector3=vec(i,1)
        var yaw:float=atan2(v.x,v.z)
        accum=yaw if i==0 else accum+wrapf(yaw-prev,-PI,PI)
        yaw_samples.append(roundi(accum*65536./TAU))
        prev=yaw

func signed(i:int)->int:
    var n:int=data[i]
    return n-256 if n>127 else n

func vec(i:int,k:int)->Vector3:
    var offset:int=i*STRIDE+k*3
    return Vector3(signed(offset),signed(offset+1),signed(offset+2))/(64. if k==0 else 127.)

func sample(tick:int,k:int)->Vector3:
    var lo:int=mini(floori(float(tick)/2.),N-1)
    var hi:int=mini(lo+1,N-1)
    var a:Vector3=vec(lo,k)
    var b:Vector3=vec(hi,k)
    var v:Vector3=a.lerp(b,float(tick%2)*.5)
    return v if k==0 else v.normalized()

func yaw_at(tick:int)->int:
    var lo:int=mini(floori(float(tick)/2.),N-1)
    return roundi(lerpf(yaw_samples[lo],yaw_samples[mini(lo+1,N-1)],float(tick%2)*.5))

static func girdle(lateral:Vector3,down:Vector3)->Basis:
    var z:Vector3=lateral.normalized()
    var y:Vector3=IK.perpendicular(z,down)
    return Basis(y.cross(z).normalized(),y,z)

func put(r,id:String,parent:String,direction:Vector3)->void:
    r.joint_xyz[id]=r.point3(parent)+direction.normalized()*r.rest_offset_xyz(id).length()

static func foot_frame(forward:Vector3,side:Vector3)->Basis:
    var x:Vector3=forward.normalized()
    var z:Vector3=IK.perpendicular(x,side)
    return Basis(x,z.cross(x).normalized(),z)

func limb(r,side:String,root:String,middle:String,end:String,upper:Vector3,lower:Vector3,reference:Vector3)->void:
    var a:String=root+"_"+side
    var b:String=middle+"_"+side
    var c:String=end+"_"+side
    put(r,b,a,upper)
    put(r,c,b,lower)
    var normal:Vector3=upper.cross(lower)
    if normal.length_squared()<.000001:normal=reference
    normal=normal.normalized()
    r.joint_basis[a]=IK.bone_frame(r.rest_offset_xyz(b),upper,normal)
    r.joint_basis[b]=IK.bone_frame(r.rest_offset_xyz(c),lower,normal)
    r.joint_basis[c]=r.joint_basis[b]

func direct(r,tick:int,art:Dictionary)->void:
    assert(tick>=0 and tick<=END)
    r.spatial_enabled=true
    r.yaw_units=yaw_at(tick)
    r.joint_xyz.clear()
    r.joint_basis.clear()
    r.foot_basis_override.clear()
    var reach:float=r.rest_offset_xyz("knee_near").length()+r.rest_offset_xyz("foot_near").length()
    var pelvis:Basis=girdle(sample(tick,1),-sample(tick,2))
    var chest:Basis=girdle(sample(tick,3),-sample(tick,2))
    r.joint_xyz.hips=sample(tick,0)*reach
    r.joint_basis.hips=pelvis
    put(r,"chest","hips",sample(tick,2))
    r.joint_basis.chest=chest
    put(r,"head","chest",sample(tick,4))
    r.joint_basis.head=girdle(chest.z,-sample(tick,4))
    for i in 2:
        var side:String=Support.SIDES[i]
        var sign_side:float=1. if i==0 else -1.
        put(r,"thigh_"+side,"hips",pelvis.z*sign_side)
        put(r,"shoulder_"+side,"chest",chest.z*sign_side+chest.y*.14)
        var j:int=5+i*5
        limb(r,side,"shoulder","elbow","hand",sample(tick,j),sample(tick,j+1),chest.z)
        limb(r,side,"thigh","knee","foot",sample(tick,j+2),sample(tick,j+3),pelvis.z)
        var sole:Basis=foot_frame(sample(tick,j+4),pelvis.z)
        r.joint_basis["foot_"+side]=sole
        r.foot_basis_override[side]=sole
    Entry.update_xy(r)

static func translate(r,shift:Vector3)->void:
    for id in r.ids_in_order():r.joint_xyz[id]=r.point3(id)+shift
    Entry.update_xy(r)

func setup(art:Dictionary)->void:
    pose=art.duplicate(true)
    direct(rig,0,pose)
    base_floor=maxf(Support.toe(rig,pose,"near").y,Support.toe(rig,pose,"far").y)
    support=Support.new()
    active_side=""
    correction=Vector3.ZERO
    shift_peak=0.

# First-pass manual contact labels from the supplied toe trajectories:
# right toe on floor in preparation; left supports high kick; right receives.
# These are specific to G20, not a universal automatic contact detector.
static func contact_at(tick:int)->String:
    if tick<34:return "near"
    if tick<80:return "far"
    return "near"

func evaluate(tick:int,grounded:bool)->Dictionary:
    direct(rig,tick,pose)
    translate(rig,Vector3(0.,-base_floor,0.))
    if not grounded:return {"accepted":true,"max_anchor_error":0.}
    var side:String=contact_at(tick)
    translate(rig,correction)
    if side!=active_side:
        # Retain prior horizontal translation, then capture the receiving
        # toe on the floor; no recapture during the same stance.
        var toe:Vector3=Support.toe(rig,pose,side)
        var offset:=Vector3(0.,-toe.y,0.)
        translate(rig,offset)
        correction+=offset
        support.contacts.clear()
        support.capture(rig,pose,side,Support.FIXED)
        active_side=side
    var contact:Dictionary=support.contacts[side]
    # Mocap supplies the toe's actual turning orientation. Fixed position,
    # source-oriented basis: do not rotate the foot by pelvis yaw alone.
    contact.basis=Support.foot_frame(rig,pose,side)
    var delta:Vector3=Vector3(contact.anchor)-Support.toe(rig,pose,side)
    translate(rig,delta)
    correction+=delta
    shift_peak=maxf(shift_peak,correction.length())
    # Reuse the existing transactional support solve. Solve into a distinct
    # rig so the source candidate remains well-defined.
    var solved=FK.new()
    var q:Dictionary=support.resolve_evaluated(solved,rig,8.)
    if q.accepted:Entry.write_exact(rig,Entry.sample(solved,pose,support))
    return q
