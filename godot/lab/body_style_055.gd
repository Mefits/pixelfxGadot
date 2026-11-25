extends RefCounted
# Lab 0.55a: procedural costume recipe over the unchanged 0.54c body.
# No sprite textures, IK, new motion or native kernel edits.
const BaseGeometry=preload("res://lab/body_skin_054.gd")
static func color(h:String)->int:
    var c:=Color(h)
    return c.r8 | (c.g8 << 8) | (c.b8 << 16) | (255 << 24)
static func ramp(a:Array)->Array:
    var out:Array=[]
    for h in a:out.append(color(h))
    return out
static func material(parts:Array,i:int,m:int)->void:
    parts[i].material_id=m
static func oval(parts:Array,p:Vector2,z:float,r:Array,angle:float,m:int)->void:
    BaseGeometry.ell(parts,p,z,r,angle)
    parts[-1].material_id=m
static func stroke(parts:Array,a:Vector2,b:Vector2,z:float,ra:float,rb:float,m:int)->void:
    BaseGeometry.sweep(parts,a,b,z,ra,rb,0)
    parts[-1].material_id=m
static func make(q:Dictionary,angles:Dictionary,variant:int)->Dictionary:
    var data:Dictionary=BaseGeometry.make(q,angles,1)
    var parts:Array=data.parts
    var cfg:Dictionary=data.config
    # material slots: skin, upper garment, trousers, footwear/gloves, trim, hair, metal.
    var upper:Array=["#7185a1","#45566e","#29384e","#171f30"]
    var pants:Array=["#52667f","#36475e","#26354b","#1b2436"]
    var accent:Array=["#c1cbd7","#8295ad","#51657c","#35465c"]
    if variant==1:
        upper=["#b0b995","#829371","#52684e","#33483a"]
        pants=["#6c7d96","#495a75","#303d56","#222d42"]
        accent=["#d6c78a","#ac9e66","#766a49","#4a463b"]
    elif variant==2:
        upper=["#c58966","#97604d","#6b403c","#462b30"]
        pants=["#a09a8b","#777366","#514f49","#353a3b"]
        accent=["#d2bba5","#9f8272","#73554d","#4c3938"]
    cfg.merge({"width":240,"height":288,"origin":[120,252],"density":3,"outline":3,"ink":0xff101010,"materials":[ramp(["#f6d5b7","#dcaa8b","#b47a62","#815047"]),ramp(upper),ramp(pants),ramp(["#687586","#414c5d","#292f3e","#1a202c"]),ramp(accent),ramp(["#536176","#344156","#222b3e","#171c2a"]),ramp(["#d6e0e4","#9caebc","#637d90","#405063"])]},true)
    # Base order: far and near each 2 arm sweeps, 2 leg sweeps, hand, shoe.
    for side_index in 2:
        var side:String="far" if side_index==0 else "near"
        var z:float=-4.0 if side_index==0 else 4.0
        var k:int=side_index*6
        for j in [0,1]:material(parts,k+j,1 if variant!=1 else 2)
        for j in [2,3]:material(parts,k+j,2)
        material(parts,k+4,3 if variant==0 else 0)
        material(parts,k+5,3)
        var shoulder:Vector2=q["shoulder_"+side]
        var elbow:Vector2=q["elbow_"+side]
        var hand:Vector2=q["hand_"+side]
        var thigh:Vector2=q["thigh_"+side]
        var knee:Vector2=q["knee_"+side]
        var foot:Vector2=q["foot_"+side]
        var arm:Vector2=(hand-elbow).normalized()
        var shin:Vector2=(foot-knee).normalized()
        if variant==1:
            # Raised wrist guard and shin wrap, with cloth still joined at the elbow/knee.
            stroke(parts,hand-arm*2.4,hand-arm*.6,z,2.05,1.9,3)
            stroke(parts,foot-shin*4.2,foot-shin*1.8,z,2.05,1.85,4)
        elif variant==2:
            # Looser sleeves and trousers. Change both adjacent radii coherently.
            parts[k].ra=3.25
            parts[k].rb=2.7
            parts[k+1].ra=2.7
            parts[k+1].rb=1.9
            parts[k+1].bulge=.45
            parts[k+2].ra=4.2
            parts[k+2].rb=3.0
            parts[k+3].ra=3.0
            parts[k+3].rb=1.95
            parts[k+3].bulge=.65
            stroke(parts,hand-arm*2.0,hand-arm*.8,z,2.1,1.95,4)
    for j in [12,15]:material(parts,j,1)
    material(parts,14,2)
    # Torso local axes and head local axes: no new skeleton transforms.
    var up:Vector2=(q.chest-q.hips).normalized()
    var right:=Vector2(-up.y,up.x)
    var head:Vector2=q.head
    var hu:Vector2=(q.head-q.chest).normalized()
    var hr:=Vector2(-hu.y,hu.x)
    var ha:float=hr.angle()
    if variant==1:
        # Fitted olive vest shell, zip and two side pockets; depth remains explicit.
        oval(parts,q.chest-up*3.8,0,[5.45,6.15,5.65],right.angle(),1)
        oval(parts,q.chest-up*5.9-right*2.0,5.25,[1.45,2.25,1.0],right.angle(),4)
        oval(parts,q.chest-up*5.9+right*1.8,5.25,[1.45,2.25,1.0],right.angle(),4)
        stroke(parts,q.hips+up*3.0-right*3.1,q.hips+up*3.0+right*3.1,1.0,1.25,1.25,3)
    elif variant==2:
        oval(parts,q.hips+up*4.0,0,[5.5,4.8,5.35],right.angle(),1)
        stroke(parts,q.hips+up*4.1-right*3.4,q.hips+up*4.1+right*3.4,2,1.45,1.45,4)
        oval(parts,q.chest+up*2.3,0,[3.6,1.85,3.4],right.angle(),4)
        # Rigid stylized scarf ends follow torso orientation, not cloth simulation.
        var tail:Vector2=q.chest+up*2.3-right*2.6
        stroke(parts,tail,tail-right*5.8-up*1.3,-1.5,1.3,.6,4)
        stroke(parts,tail-up*.8,tail-right*4.4-up*2.7,-1.7,1.0,.5,4)
    else:
        stroke(parts,q.hips+up*2.0-right*3.2,q.hips+up*2.0+right*3.2,2,1.0,1.0,4)
    # Hair cap displaced toward back/up. Tapered hair locks are world geometry.
    oval(parts,head+hu*1.9-hr*.65,.3,[3.95,3.35,3.6],ha,5)
    for j in 3:
        var root:Vector2=head+hu*(2.2-float(j)*.35)-hr*(1.0+float(j)*.6)
        stroke(parts,root,root+hu*(3.0-float(j)*.55)-hr*(2.1+float(j)*.45),.15,1.25,.35,5)
    if variant==1:
        stroke(parts,head+hu*1.65-hr*3.0,head+hu*1.65+hr*2.8,2.4,.8,.8,3)
        oval(parts,head+hu*1.65+hr*1.2,3.55,[1.55,.7,.35],ha,6)
    elif variant==0:
        # Dark high collar and headband.
        oval(parts,q.chest+up*2.1,0,[3.0,1.55,3.0],right.angle(),3)
        stroke(parts,head+hu*1.35-hr*2.5,head+hu*1.35+hr*2.5,2.8,.65,.65,4)
    # Nose and visible eye: small surface marks, explicitly near-facing.
    oval(parts,head+hr*3.05-hu*.35,1.1,[1.05,.85,1.15],ha,0)
    oval(parts,head+hr*1.95+hu*.25,3.0,[.85,.36,.38],ha,3)
    return data
