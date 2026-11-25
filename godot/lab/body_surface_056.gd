extends RefCounted
# Pose-space connected surface experiment. No imported mesh, textures or IK.
# Shared shoulder/hip edge vertices make a single connected front surface.
# This is not yet a full 3D mesh or general weighted bind-pose skinning.
const Base=preload("res://lab/body_skin_054.gd")
const Style=preload("res://lab/body_style_055.gd")
static func v(p:Vector2,z:float,n:Vector3)->Dictionary:
    var nn:=n.normalized()
    return {"p":[p.x,p.y,z],"n":[nn.x,nn.y,nn.z]}
static func tri(parts:Array,a:Dictionary,b:Dictionary,c:Dictionary,m:int)->void:
    parts.append({"type":"triangle","a":a.p,"b":b.p,"c":c.p,"na":a.n,"nb":b.n,"nc":c.n,"part_id":100+m,"material_id":m})
static func quad(parts:Array,a:Dictionary,b:Dictionary,c:Dictionary,d:Dictionary,m:int)->void:
    tri(parts,a,b,c,m)
    tri(parts,a,c,d,m)
static func row(center:Vector2,right:Vector2,w:float,z:float,depth:float)->Array:
    return [v(center-right*w,z,Vector3(-right.x*.8,-right.y*.8,.6)),v(center,z+depth,Vector3(0,-.22,1)),v(center+right*w,z,Vector3(right.x*.8,right.y*.8,.6))]
static func strip(parts:Array,a:Array,b:Array,m:int)->void:
    for j in 2:quad(parts,a[j],a[j+1],b[j+1],b[j],m)
static func ring(center:Vector2,dir:Vector2,w:float,z:float,depth:float,reference:Vector2)->Array:
    var n:=Vector2(dir.y,-dir.x)
    if n.dot(reference)<0:n=-n
    return row(center,n,w,z,depth)
static func limb(parts:Array,attach:Array,a:Vector2,b:Vector2,c:Vector2,z:float,widths:Array,shirt:bool,leg:bool)->void:
    var d1:Vector2=(b-a).normalized()
    var d2:Vector2=(c-b).normalized()
    var ref:=Vector2(float(attach[2].p[0])-float(attach[0].p[0]),float(attach[2].p[1])-float(attach[0].p[1])).normalized()
    var n1:=Vector2(d1.y,-d1.x)
    if n1.dot(ref)<0:n1=-n1
    var n2:=Vector2(d2.y,-d2.x)
    if n2.dot(n1)<0:n2=-n2
    var mid:Vector2=(n1+n2).normalized()
    if mid.length_squared()<.01:mid=n1
    var m1:int=1 if shirt and not leg else 2 if shirt else 0
    var m2:int=0
    var top:Array=ring(a.lerp(b,.24),d1,widths[0],z,widths[0]*.72,n1)
    var hem:Array=ring(a.lerp(b,.68 if not leg else .78),d1,widths[1],z,widths[1]*.72,n1)
    var joint:Array=row(b,mid,widths[2],z,widths[2]*.68)
    var lower:Array=ring(b.lerp(c,.48),d2,widths[3],z,widths[3]*.72,n2)
    var end:Array=ring(c,d2,widths[4],z,widths[4]*.66,n2)
    strip(parts,attach,top,m1)
    strip(parts,top,hem,m1)
    strip(parts,hem,joint,m2)
    strip(parts,joint,lower,m2)
    strip(parts,lower,end,m2)
static func split_edge(a:Dictionary,b:Dictionary,z_raise:float)->Array:
    var pa:=Vector2(a.p[0],a.p[1])
    var pb:=Vector2(b.p[0],b.p[1])
    var mid:Dictionary=v(pa.lerp(pb,.5),(float(a.p[2])+float(b.p[2]))*.5+z_raise,Vector3(0,0,1))
    return [a,mid,b]
static func make(q:Dictionary,angles:Dictionary,head_rot:float,shirt:bool)->Dictionary:
    var data:Dictionary=Base.make(q,angles,1)
    var old:Array=data.parts
    var parts:Array=[]
    var cfg:Dictionary=data.config
    cfg.merge({"width":288,"height":288,"origin":[144,252],"density":3,"outline":3,"ink":0xff101010,"mode":"reference","smooth":0,"joins":[],"materials":[Style.ramp(["#e4c6ad","#cba28b","#ac7c69","#805949"]),Style.ramp(["#5278aa","#365b8c","#24436f","#152c50"]),Style.ramp(["#eeeae0","#d0d0ce","#b0b5bf","#818c9e"]),Style.ramp(["#596678","#3d485c","#293446","#192333"])]},true)
    var hips:Vector2=q.hips
    var chest:Vector2=q.chest
    var up:Vector2=(chest-hips).normalized()
    var right:=Vector2(-up.y,up.x)
    var neck:Vector2=chest.lerp(q.head,.56)
    var neck_row:Array=row(neck,right,1.75,0.1,1.7)
    var shoulder:Array=row(chest+up*.65,right,4.7 if shirt else 4.1,.3,3.6)
    var armpit:Array=row(chest-up*4.6,right,3.95 if shirt else 3.35,.15,3.7)
    var waist:Array=row(hips+up*5.3,right,3.65 if shirt else 2.95,.1,3.25)
    var pelvis:Array=row(hips+up*.2,right,4.65 if shirt else 4.05,0.0,3.5)
    var bottom:Array=row(hips-up*3.0,right,4.5 if shirt else 3.85,0.0,2.8)
    # Add a central crotch indentation; same vertices used by both leg strips.
    bottom[1]=v(hips-up*4.65,1.25,Vector3(0,.2,1))
    strip(parts,neck_row,shoulder,1 if shirt else 0)
    # Split side edges with an explicit shared midpoint so attachment has no T junction.
    var left_attach:Array=split_edge(shoulder[0],armpit[0],0.0)
    var right_attach:Array=split_edge(shoulder[2],armpit[2],0.0)
    tri(parts,shoulder[0],shoulder[1],left_attach[1],1 if shirt else 0)
    quad(parts,left_attach[1],shoulder[1],armpit[1],armpit[0],1 if shirt else 0)
    tri(parts,shoulder[1],shoulder[2],right_attach[1],1 if shirt else 0)
    quad(parts,shoulder[1],right_attach[1],armpit[2],armpit[1],1 if shirt else 0)
    strip(parts,armpit,waist,1 if shirt else 0)
    strip(parts,waist,pelvis,1 if shirt else 0)
    var left_leg:Array=split_edge(bottom[0],bottom[1],0.0)
    var right_leg:Array=split_edge(bottom[1],bottom[2],0.0)
    tri(parts,pelvis[0],pelvis[1],left_leg[1],2 if shirt else 0)
    tri(parts,pelvis[0],left_leg[1],bottom[0],2 if shirt else 0)
    tri(parts,pelvis[1],bottom[1],left_leg[1],2 if shirt else 0)
    tri(parts,pelvis[1],pelvis[2],right_leg[1],2 if shirt else 0)
    tri(parts,pelvis[1],right_leg[1],bottom[1],2 if shirt else 0)
    tri(parts,pelvis[2],bottom[2],right_leg[1],2 if shirt else 0)
    # Assignment follows the projected girdle ordering; the fixed depth bias
    # remains explicit and is NOT reconstructed 3D.
    var far_left:bool=(Vector2(q.shoulder_far)-Vector2(q.shoulder_near)).dot(right)<=0
    var leg_far_left:bool=(Vector2(q.thigh_far)-Vector2(q.thigh_near)).dot(right)<=0
    for side in ["far","near"]:
        var z:float=-3.0 if side=="far" else 3.0
        var arm_left:bool=far_left if side=="far" else not far_left
        var leg_left:bool=leg_far_left if side=="far" else not leg_far_left
        var attach:Array=left_attach if arm_left else right_attach
        var la:Array=left_leg if leg_left else right_leg
        limb(parts,attach,q["shoulder_"+side],q["elbow_"+side],q["hand_"+side],z,[2.55,2.5,1.65,1.65,1.25] if shirt else [2.05,1.9,1.55,1.6,1.22],shirt,false)
        limb(parts,la,q["thigh_"+side],q["knee_"+side],q["foot_"+side],z,[3.3,2.85,1.9,1.75,1.35] if shirt else [2.55,2.1,1.8,1.7,1.25],shirt,true)
    # Reuse only existing head, hand and shoe volumes, not shoulder/hip spheres.
    for i in [4,5,10,11,16]:
        var item:Dictionary=old[i].duplicate(true)
        item.part_id=200+i
        item.material_id=3 if i in [5,11] else 0
        if i in [4,5]:item.center[2]=-3.0
        if i in [10,11]:item.center[2]=3.0
        if i==16:
            item.radii=[3.85,4.65,3.45]
            item.basis=[cos(head_rot),-sin(head_rot),0,sin(head_rot),cos(head_rot),0,0,0,1]
        parts.append(item)
    return {"config":cfg,"parts":parts}
