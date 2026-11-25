extends RefCounted
# Fan-art R&D recipe, no imported sprites. Reference: classic Part I blue shirt,
# white shorts, arm warmers, shin wraps, open-toe sandals, spiked black hair.
const Base=preload("res://lab/body_skin_054.gd")
const Style=preload("res://lab/body_style_055.gd")
static func oval(p:Array,at:Vector2,z:float,r:Array,angle:float,m:int)->void:
    Style.oval(p,at,z,r,angle,m)
static func tube(p:Array,a:Vector2,b:Vector2,z:float,ra:float,rb:float,m:int)->void:
    Style.stroke(p,a,b,z,ra,rb,m)
static func band(p:Array,at:Vector2,axis:Vector2,z:float,r:float,w:float,m:int)->void:
    oval(p,at,z,[r,w,r],axis.angle()-PI*.5,m)
static func cut(p:Array,a:Vector2,b:Vector2,z:float,ra:float,rb:float,m:int,profile:float,depth_ratio:float=1.0)->void:
    p.append({"type":"cut_tube","a":Base.xyz(a,z),"b":Base.xyz(b,z),"ra":ra,"rb":rb,"profile":profile,"depth_ratio":depth_ratio,"part_id":p.size()+1,"material_id":m})
static func cloth_band(p:Array,at:Vector2,axis:Vector2,z:float,r:float,w:float,m:int,profile:float)->void:
    cut(p,at-axis*w,at+axis*w,z,r,r,m,profile)
static func make(q:Dictionary,angles:Dictionary,head_rot:float,profile:float)->Dictionary:
    var data:Dictionary=Base.make(q,angles,1)
    var p:Array=data.parts
    var cfg:Dictionary=data.config
    # skin / navy / ivory / blue sandals / pale wraps / hair / steel / ink
    cfg.merge({"width":240,"height":288,"origin":[120,252],"density":3,"outline":3,"ink":0xff101010,"materials":[
        Style.ramp(["#f8dbc8","#e6bca6","#bc8878","#895d59"]),
        Style.ramp(["#365a89","#244574","#18345c","#11223f"]),
        Style.ramp(["#f3f0e7","#d8d9d8","#b2b8c2","#858f9f"]),
        Style.ramp(["#416594","#2a4875","#1c3458","#14233b"]),
        Style.ramp(["#fcf8ed","#dedfdc","#b8bec5","#8e98a5"]),
        Style.ramp(["#414a60","#283247","#1d2638","#111827"]),
        Style.ramp(["#e1e7ec","#b2c0cb","#8394a4","#53677c"]),
        Style.ramp(["#333b4e","#272d3b","#1b2130","#151921"])
    ]},true)
    var up:Vector2=(q.chest-q.hips).normalized()
    var right:=Vector2(-up.y,up.x)
    var shirt_angle:float=right.angle()
    for s in 2:
        var side:String="far" if s==0 else "near"
        var z:float=-4.0 if s==0 else 4.0
        var k:int=s*6
        var sh:Vector2=q["shoulder_"+side]
        var el:Vector2=q["elbow_"+side]
        var hand:Vector2=q["hand_"+side]
        var hip:Vector2=q["thigh_"+side]
        var knee:Vector2=q["knee_"+side]
        var foot:Vector2=q["foot_"+side]
        var a:Vector2=(el-sh).normalized()
        var fore:Vector2=(hand-el).normalized()
        var leg:Vector2=(knee-hip).normalized()
        var shin:Vector2=(foot-knee).normalized()
        var pitch:float=deg_to_rad(float(angles.get("foot_pitch_"+side,0.0)))
        # Both halves of each organic join retain same skin material.
        p[k].ra=2.4
        p[k].rb=1.75
        p[k+1].ra=1.75
        p[k+1].rb=1.4
        p[k+2].ra=3.0
        p[k+2].rb=2.0
        p[k+3].ra=2.0
        p[k+3].rb=1.55
        # Shirt sleeve stops before elbow, separate flared cuff.
        cut(p,sh-a*.8,sh.lerp(el,.69),z,2.85,2.8,1,profile)
        cloth_band(p,sh.lerp(el,.65),a,z,2.83,.18,1,profile)
        # White forearm warmers, narrow navy edge, segmented wrap marks.
        cut(p,el.lerp(hand,.15),el.lerp(hand,.95),z,2.02,1.80,4,2)
        cloth_band(p,el.lerp(hand,.18),fore,z,2.08,.22,3,2)
        cloth_band(p,el.lerp(hand,.90),fore,z,1.85,.22,3,2)
        for t in [.35,.55,.73]:
            cloth_band(p,el.lerp(hand,t),fore,z,2.05-t*.25,.12,2,2)
        # White shorts: visibly wide at thigh, straight-ish hem above knee.
        cut(p,hip-leg*1.8,hip.lerp(knee,.90),z,3.75,3.25,2,profile)
        cloth_band(p,hip.lerp(knee,.86),leg,z,3.27,.18,2,profile)
        if s==1:
            # Small dark thigh holster and straps on near leg.
            band(p,hip.lerp(knee,.38),leg,z,3.68,.38,7)
            band(p,hip.lerp(knee,.53),leg,z,3.55,.36,7)
            oval(p,hip.lerp(knee,.44),z+3.35,[1.3,2.7,.85],leg.angle()-PI*.5,7)
        # Shin wraps leave a short exposed knee gap.
        cut(p,knee.lerp(foot,.19),knee.lerp(foot,.88),z,2.18,1.93,4,2)
        for t in [.34,.49,.64,.77]:
            cloth_band(p,knee.lerp(foot,t),shin,z,2.21-t*.25,.12,2,2)
        cloth_band(p,knee.lerp(foot,.20),shin,z,2.25,.22,3,2)
        cloth_band(p,knee.lerp(foot,.86),shin,z,2.02,.22,3,2)
        # Open toe sandal: base shoe dark blue; pale toe cap and heel strap.
        p[k+5].material_id=3
        oval(p,foot+Vector2(3.25,-.9).rotated(pitch),z+.3,[1.15,.95,1.45],pitch,0)
        oval(p,foot+Vector2(1.05,.35).rotated(pitch),z,[3.05,.52,2.0],pitch,7)
        oval(p,foot+Vector2(.0,-1.5).rotated(pitch),z,[1.65,1.45,1.98],pitch,3)
    p[12].material_id=1
    p[14].material_id=2
    p[15].material_id=1
    # Wider straight shirt hem conceals pelvis, tall collar wraps lower neck.
    # Keep anatomical primitives inside the shirt and replace the two exposed
    # torso bulges with one continuous tapered panel, flat at the hem.
    p[12].ra=3.0
    p[12].rb=3.2
    p[14].radii=[4.1,3.0,4.0]
    p[15].radii=[4.1,4.8,3.8]
    cut(p,q.hips+up*1.2,q.chest+up*1.0,0,4.85,5.1,1,profile,.96)
    var head:Vector2=q.head
    var hu:=Vector2(0,-1).rotated(head_rot)
    var hr:=Vector2(-hu.y,hu.x)
    var ha:float=hr.angle()
    # Collar anchored to neckline and slightly tilted with head.
    cut(p,q.chest.lerp(head,.12),q.chest.lerp(head,.56),0,3.25,3.0,1,profile,1.05)
    cloth_band(p,q.chest.lerp(head,.56),hu,0,3.04,.19,1,profile)
    # Head base remains anchored to FK head, stylized young face.
    p[16].radii=[3.85,4.65,3.45]
    p[16].basis=[cos(ha),-sin(ha),0,sin(ha),cos(ha),0,0,0,1]
    oval(p,head+hr*2.9-hu*.38,.85,[1.0,.9,1.2],ha,0)
    oval(p,head-hr*2.4-hu*.5,1.4,[.95,1.25,1.6],ha,0)
    # Hair silhouette: crown, swept-back pointed locks, long front fringe.
    oval(p,head+hu*2.1-hr*.65,.15,[3.8,3.25,3.7],ha,5)
    var tips:Array=[Vector2(-5.7,5.5),Vector2(-6.7,3.5),Vector2(-6.4,1.1),Vector2(-5.4,-.9)]
    for i in tips.size():
        var tip:Vector2=tips[i]
        var start:Vector2=head-hr*1.9+hu*(2.8-float(i)*.75)
        tube(p,start,head+hr*tip.x+hu*tip.y,-.1,1.6,.16,5)
    # Forehead protector lies in front of hair; two framing locks remain visible.
    tube(p,head+hu*1.7-hr*2.9,head+hu*1.7+hr*2.8,2.65,.95,.95,3)
    oval(p,head+hu*1.7+hr*.75,3.62,[1.8,.86,.48],ha,6)
    oval(p,head+hu*1.7+hr*.85,4.12,[.43,.40,.13],ha,7)
    oval(p,head+hu*1.7+hr*.85,4.25,[.23,.22,.13],ha,6)
    tube(p,head+hu*3.2+hr*2.15,head-hu*1.35+hr*3.05,2.45,1.25,.22,5)
    tube(p,head+hu*2.9-hr*2.25,head-hu*1.9-hr*2.8,2.55,1.1,.23,5)
    # Readable eye and eyebrow on near cheek, no fake frontal second eye.
    oval(p,head+hr*1.35+hu*.05,3.28,[.95,.46,.25],ha,2)
    oval(p,head+hr*1.72+hu*.04,3.58,[.43,.42,.16],ha,7)
    tube(p,head+hr*.55+hu*.68,head+hr*2.15+hu*.49,3.2,.19,.16,7)
    return data
