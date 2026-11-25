extends RefCounted
const MeshData=preload("res://lab/weighted_surface_057.gd")
const Old=preload("res://lab/body_surface_056.gd")
const Base=preload("res://lab/body_skin_054.gd")
var mesh
static func stance()->Dictionary:
    var a:float=rad_to_deg(atan2(2.0,11.0))
    return {"angles":{"thigh_far":-a,"knee_far":2*a,"thigh_near":a,"knee_near":-2*a},"root":[0,22-2*sqrt(125.0)]}
func setup(q:Dictionary,r:Dictionary)->bool:
    mesh=MeshData.new()
    mesh.bind_points=q.duplicate(true)
    mesh.bind_rot=r.duplicate(true)
    var h:Vector2=q.hips
    var c:Vector2=q.chest
    var up:Vector2=(c-h).normalized()
    var right:=Vector2(-up.y,up.x)
    # Rest silhouette, authored in body coordinates. Shorter visible neck,
    # broader rib cage, tapered waist, pelvis without spherical caps.
    var neck:Array=mesh.row(c.lerp(q.head,.66),right,1.65,0,1.55,"chest","head",.35)
    var shoulder:Array=mesh.row(c+up*1.1,right,4.8,0,3.1,"chest","chest",0)
    var armpit:Array=mesh.row(c-up*4.6,right,4.0,0,3.35,"chest","hips",.12)
    var waist:Array=mesh.row(h+up*5.7,right,3.25,0,2.85,"chest","hips",.63)
    var hip:Array=mesh.row(h+up*.6,right,4.35,0,3.0,"hips","hips",0)
    # Shoulder edge endpoints carry the same influences for body and arm.
    for pair in [[shoulder[0],"shoulder_far",.38],[armpit[0],"shoulder_far",.18],[shoulder[4],"shoulder_near",.38],[armpit[4],"shoulder_near",.18]]:
        mesh.vertices[pair[0]].b1=pair[1]
        mesh.vertices[pair[0]].w=pair[2]
    mesh.strip(neck,shoulder,0)
    var left:Array=mesh.edge(shoulder[0],armpit[0],"chest","shoulder_far",.25)
    var right_arm:Array=mesh.edge(shoulder[4],armpit[4],"chest","shoulder_near",.25)
    var rim:Array=shoulder.duplicate()
    for j in range(1,5):rim.append(right_arm[j])
    for j in range(3,-1,-1):rim.append(armpit[j])
    for j in range(3,0,-1):rim.append(left[j])
    mesh.fan(rim,mesh.add(c-up*1.9,3.5,Vector3(0,-.1,1),"chest","hips",.08),0)
    mesh.strip(armpit,waist,0)
    mesh.strip(waist,hip,0)
    var bl:int=mesh.add(h-right*4.45-up*2.15,0,Vector3(-.5,.15,1),"hips","thigh_far",.35)
    var bc:int=mesh.add(h-up*4.15,1.1,Vector3(0,.3,1),"hips","hips",0)
    var br:int=mesh.add(h+right*4.45-up*2.15,0,Vector3(.5,.15,1),"hips","thigh_near",.35)
    var ll:Array=mesh.edge(bl,bc,"hips","thigh_far",.28)
    var rl:Array=mesh.edge(bc,br,"hips","thigh_near",.28)
    rim=hip.duplicate()
    rim.append(br)
    for j in range(3,-1,-1):rim.append(rl[j])
    for j in range(3,-1,-1):rim.append(ll[j])
    mesh.fan(rim,mesh.add(h-up*1.4,2.85,Vector3(0,.1,1),"hips","hips",0),0)
    for side in ["far","near"]:
        var z:float=-3.0 if side=="far" else 3.0
        build_limb(left if side=="far" else right_arm,"shoulder_"+side,"elbow_"+side,"hand_"+side,z,[2.35,2.05,1.65,1.78,1.48,1.22])
        build_limb(ll if side=="far" else rl,"thigh_"+side,"knee_"+side,"foot_"+side,z,[2.8,2.4,1.85,1.95,1.55,1.25])
    return mesh.validate()
func build_limb(attach:Array,b0:String,b1:String,b2:String,z:float,width:Array)->void:
    var q:Dictionary=mesh.bind_points
    var a:Vector2=q[b0]
    var b:Vector2=q[b1]
    var c:Vector2=q[b2]
    var d1:Vector2=(b-a).normalized()
    var d2:Vector2=(c-b).normalized()
    var n1:=Vector2(d1.y,-d1.x)
    var n2:=Vector2(d2.y,-d2.x)
    var edge:Vector2=mesh.vertices[attach[-1]].p-mesh.vertices[attach[0]].p
    if edge.dot(n1)<0:n1=-n1
    if n2.dot(n1)<0:n2=-n2
    var mid:Vector2=(n1+n2).normalized()
    var rows:Array=[attach,
        mesh.row(a.lerp(b,.27),n1,width[0],z,width[0]*.65,b0,b0,0),
        mesh.row(a.lerp(b,.72),n1,width[1],z,width[1]*.65,b0,b0,0),
        mesh.row(b,mid,width[2],z,width[2]*.65,b0,b1,.5,b1),
        mesh.row(b.lerp(c,.24),n2,width[3],z,width[3]*.65,b1,b1,0),
        mesh.row(b.lerp(c,.61),n2,width[4],z,width[4]*.65,b1,b1,0),
        mesh.row(c,n2,width[5],z,width[5]*.65,b1,b1,0)]
    for i in rows.size()-1:mesh.strip(rows[i],rows[i+1],0)
func make(q:Dictionary,r:Dictionary,angles:Dictionary,correct:bool)->Dictionary:
    var data:Dictionary=Old.make(q,angles,float(r.head),false)
    var parts:Array=[]
    var deformed:Array=mesh.deform(q,r,correct)
    parts=mesh.emit(deformed)
    # Same rigid hands/head/shoes as control; no silhouette editing hidden in skinning.
    for item in data.parts:
        if item.type!="triangle":parts.append(item)
    return {"config":data.config,"parts":parts,"audit":mesh.audit(deformed)}
