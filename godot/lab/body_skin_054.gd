extends RefCounted
# Geometry only: no changes to FK or motion. Coordinates in Lab rig pixels.
static func xyz(p:Vector2,z:float)->Array:
    return [p.x,p.y,z]
static func sweep(parts:Array,a:Vector2,b:Vector2,z:float,ra:float,rb:float,group:int,bulge:float=0.0)->void:
    parts.append({"type":"sweep","a":xyz(a,z),"b":xyz(b,z),"ra":ra,"rb":rb,"bulge":bulge,"part_id":parts.size()+1,"material_id":0,"blend_group":group})
static func ell(parts:Array,p:Vector2,z:float,r:Array,angle:float=0.0)->void:
    var c:=cos(angle)
    var s:=sin(angle)
    parts.append({"type":"ellipsoid","center":xyz(p,z),"radii":r,"basis":[c,-s,0,s,c,0,0,0,1],"part_id":parts.size()+1,"material_id":0})
static func make(q:Dictionary,angles:Dictionary,variant:int)->Dictionary:
    var parts:Array=[]
    var joins:Array=[]
    var d:int=3 if variant==2 else 1
    var cfg:Dictionary={"width":80*d,"height":96*d,"origin":[40*d,84*d],"density":d,"light":[-.48,-.64,.6],"materials":[[0xffe1d7bf,0xffc0aaa0,0xff957b79,0xff585265]],"outline":1,"ink":0xff25222a,"seams":variant==0}
    # A duplicates the Astra test geometry. B and C use the same improved
    # geometry and different density. Both disable cosmetic internal seams.
    for side in ["far","near"]:
        var z:float=-4 if side=="far" else 4
        var start:int=parts.size()
        var arm_group:int=start+1
        sweep(parts,q["shoulder_"+side],q["elbow_"+side],z,2.1 if variant==0 else 2.7,1.8 if variant==0 else 2.0,arm_group)
        sweep(parts,q["elbow_"+side],q["hand_"+side],z,1.8 if variant==0 else 2.0,1.3 if variant==0 else 1.65,arm_group,0.0 if variant==0 else .20)
        joins.append([start,start+1])
        var leg_start:int=parts.size()
        sweep(parts,q["thigh_"+side],q["knee_"+side],z,2.8 if variant==0 else 3.5,1.8 if variant==0 else 2.4,leg_start+1)
        sweep(parts,q["knee_"+side],q["foot_"+side],z,1.8 if variant==0 else 2.4,1.3 if variant==0 else 1.75,leg_start+1,0.0 if variant==0 else .24)
        joins.append([leg_start,leg_start+1])
        if variant>0:
            var h:Vector2=q["hand_"+side]
            var e:Vector2=q["elbow_"+side]
            var u:Vector2=(h-e).normalized()
            ell(parts,h+u*.65,z,[2.25,1.65,1.8],u.angle())
            var pitch:float=deg_to_rad(float(angles.get("foot_pitch_"+side,0)))
            ell(parts,q["foot_"+side]+Vector2(1.2,-.8).rotated(pitch),z,[3.0,1.65,2.0],pitch)
    sweep(parts,q.hips,q.chest,0,3 if variant==0 else 3.7,3.8 if variant==0 else 4.5,100)
    sweep(parts,q.chest,q.head,0,1.6 if variant==0 else 1.95,1.6 if variant==0 else 1.95,101)
    if variant==0:
        ell(parts,q.head,0,[3.8,4.3,3.2])
    else:
        var axis:Vector2=(q.chest-q.hips).normalized()
        var angle:float=axis.angle()-PI*.5
        ell(parts,q.hips+axis*1.1,0,[4.6,3.9,5.2],angle)
        ell(parts,q.chest-axis*3.5,0,[5.0,5.8,5.3],angle)
        ell(parts,q.head,0,[3.9,4.7,3.5],axis.angle()+PI*.5)
        cfg.merge({"mode":"organic","smooth":1.6,"joins":joins},true)
    return {"config":cfg,"parts":parts}
