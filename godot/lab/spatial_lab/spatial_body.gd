extends RefCounted
## Spatial Lab 0.02: experimental closed 3D surfaces on existing native
## PixelFX triangles + ellipsoid. Never change the accepted 2D body path.
const Body=preload("res://lab/body_ankle_069.gd")
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const SIDES:int=6
var body=Body.new(2)
var reference=Body.make_rig()

static func xyz(v:Vector3)->Array:
    return [v.x,v.y,v.z]

static func materials(parts:Array)->void:
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2

# Canonical shape rows from the actual 069 adapter; discard old cosmetic
# depth lanes, distal shear and section Z biases. 2D pose only supplies art
# profile, never the spatial endpoints.
func make(r,pose:Dictionary)->Array:
    assert(r.spatial_enabled)
    reference.evaluate(pose)
    var angles:Dictionary=pose.get("angles",{})
    var profiles:Array=body.make(reference.points,angles,reference.rotations.head)
    materials(profiles)
    var out:Array=[]
    var hips:Vector3=r.point3("hips")
    var chest:Vector3=r.point3("chest")
    var head:Vector3=r.point3("head")
    var up:Vector3=(chest-hips).normalized()
    loft(out,profiles[0],hips,chest,r.joint_basis.hips,5)
    loft(out,profiles[1],chest,head,r.joint_basis.chest,4)
    for k in 2:
        var side:String=["far","near"][k]
        var shoulder:Vector3=r.point3("shoulder_"+side)
        var elbow:Vector3=r.point3("elbow_"+side)
        var hand:Vector3=r.point3("hand_"+side)
        var thigh:Vector3=r.point3("thigh_"+side)
        var knee:Vector3=r.point3("knee_"+side)
        var foot:Vector3=r.point3("foot_"+side)
        var shoulder_proxy:Vector3=shoulder.lerp(chest,.24)
        var hip_proxy:Vector3=thigh.lerp(hips,.27)
        var anchor:Vector3=chest-up*1.8
        if anchor.distance_to(shoulder_proxy)<.45:anchor=chest+up*1.2
        var hip_anchor:Vector3=hips.lerp(chest,.15)
        if hip_anchor.distance_to(hip_proxy)<.2:hip_anchor+=up
        var i:int=2+k*6
        loft(out,profiles[i],anchor,shoulder_proxy,r.joint_basis.chest,3)
        loft(out,profiles[i+1],shoulder_proxy,elbow,r.joint_basis["shoulder_"+side],4)
        loft(out,profiles[i+2],elbow,hand,r.joint_basis["elbow_"+side],4)
        loft(out,profiles[i+3],hip_anchor,hip_proxy,r.joint_basis.hips,3)
        loft(out,profiles[i+4],hip_proxy,knee,r.joint_basis["thigh_"+side],4)
        loft(out,profiles[i+5],knee,foot,r.joint_basis["knee_"+side],4)
        loft(out,profiles[14+2*k],hand,hand+(hand-elbow).normalized()*2.55,r.joint_basis["hand_"+side],4)
        # Legacy foot_pitch is world planar pitch, not local ankle flexion.
        # Rotate its sole with body yaw; individual foot IK/orientation is 0.03+.
        var sole:Basis=FK.yaw_basis(r.yaw_units)*Basis(Vector3.BACK,deg_to_rad(float(angles.get("foot_pitch_"+side,0.))))
        if r.foot_basis_override.has(side):sole=r.foot_basis_override[side]
        loft(out,profiles[15+2*k],foot+sole*Vector3(-1.65,-.30,0),foot+sole*Vector3(3.75,-.30,0),sole,4)
    var p:Dictionary=profiles[18].duplicate(true)
    p.center=xyz(head.lerp(chest,.20))
    var hb:Basis=r.joint_basis.head
    p.basis=[hb.x.x,hb.y.x,hb.z.x,hb.x.y,hb.y.y,hb.z.y,hb.x.z,hb.y.z,hb.z.z]
    out.append(p)
    return out

static func section_indices(rows:Array,count:int)->Array[int]:
    var ids:Array[int]=[]
    for i in count:
        ids.append(roundi(float(i)*(rows.size()-1)/(count-1)))
    return ids

static func ring_point(row:Array,a:Vector3,d:Vector3,right:Vector3,front:Vector3,exponent:float,j:int)->Vector3:
    var theta:float=TAU*float(j)/SIDES
    var c:float=cos(theta)
    var s:float=sin(theta)
    var x:float=signf(c)*pow(absf(c),2./exponent)*float(row[2] if c>=0. else row[1])
    var z:float=signf(s)*pow(absf(s),2./exponent)*float(row[3])
    return a+d*float(row[0])+right*x+front*z

# Use the joint-local frame, not a camera-facing billboard. Caps stay
# visible end-on; cull only back/zero-area faces of closed surfaces to keep
# within the native 512 primitive budget. Normals are world-space unit vectors.
static func loft(out:Array,part:Dictionary,a:Vector3,b:Vector3,frame:Basis,count:int=4)->void:
    var d:Vector3=b-a
    assert(d.length_squared()>0.000001)
    var axis:Vector3=d.normalized()
    var front:Vector3=frame.z-axis*axis.dot(frame.z)
    if front.length_squared()<.000001:front=frame.x-axis*axis.dot(frame.x)
    front=front.normalized()
    var right:Vector3=front.cross(axis).normalized()
    front=axis.cross(right)
    var rows:Array=part.sections
    var indices:Array[int]=section_indices(rows,mini(count,rows.size()))
    var rings:Array=[]
    var normals:Array=[]
    for i in indices:
        var ring:Array[Vector3]=[]
        for j in SIDES:ring.append(ring_point(rows[i],a,d,right,front,float(part.profile),j))
        rings.append(ring)
    for i in rings.size():
        var nr:Array[Vector3]=[]
        for j in SIDES:
            var tangent:Vector3=rings[i][(j+1)%SIDES]-rings[i][posmod(j-1,SIDES)]
            var axial:Vector3=rings[mini(i+1,rings.size()-1)][j]-rings[maxi(0,i-1)][j]
            nr.append(tangent.cross(axial).normalized())
        normals.append(nr)
    for i in range(rings.size()-1):
        for j in SIDES:
            var k:int=(j+1)%SIDES
            triangle(out,part,rings[i][j],rings[i][k],rings[i+1][k],normals[i][j],normals[i][k],normals[i+1][k])
            triangle(out,part,rings[i][j],rings[i+1][k],rings[i+1][j],normals[i][j],normals[i+1][k],normals[i+1][j])
    var lo:Vector3=a+d*float(rows[indices[0]][0])
    var hi:Vector3=a+d*float(rows[indices[-1]][0])
    for j in SIDES:
        var k:int=(j+1)%SIDES
        triangle(out,part,lo,rings[0][k],rings[0][j],-axis,-axis,-axis)
        triangle(out,part,hi,rings[-1][j],rings[-1][k],axis,axis,axis)

static func triangle(out:Array,part:Dictionary,a:Vector3,b:Vector3,c:Vector3,na:Vector3,nb:Vector3,nc:Vector3)->void:
    if (b-a).cross(c-a).z<=0.00000001:return
    out.append({"type":"triangle","a":xyz(a),"b":xyz(b),"c":xyz(c),"na":xyz(na),"nb":xyz(nb),"nc":xyz(nc),"part_id":part.part_id,"material_id":part.material_id})
