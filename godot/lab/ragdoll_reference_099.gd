extends RefCounted
## Isolated planar articulated rigid segments. PBD anchor and angular
## constraints, unilateral floor contacts, relative joint motors.
## Fixed 120Hz substeps. No authored world-space trajectory or rest pose.
const Leg=preload("res://lab/leg_constraints_082.gd")
const H:float=1./120.
const ITER:int=28
const GRAVITY:=Vector2(0.,180.)
const DAMP:float=.9
const FRICTION:float=.58
var rig
var bodies:Array=[]
var ids:Dictionary={}
var template:Dictionary={}
var floor_y:float
var guided:bool
var steps:int=0
var touched:bool=false
var contact_count:int=0
var penetration:float=0.
var anchor_error:float=0.
var pose_error:float=0.
var motor:float=0.
var peak_speed:float=0.
var profile:int=0
var iterations:int=28
var tone_impulse:float=0.
var friction_impulse:float=0.

func _init(r,entry:Dictionary,prior:Dictionary,floor:float,active:bool,velocity:Vector2,spin:float,mode:int=0,passes:int=28):
    profile=mode
    iterations=clampi(passes,4,28)
    rig=r
    template=entry.duplicate(true)
    floor_y=floor
    guided=active
    rig.evaluate(prior)
    var old_points:Dictionary=rig.points.duplicate()
    var old_angles:Dictionary=rig.rotations.duplicate()
    rig.evaluate(entry)
    for j in rig.joints:
        var id:String=j.id
        var parent:int=-1 if String(j.parent).is_empty() else int(ids[j.parent])
        var angle:float=rotation_for(id,entry,rig.rotations)
        var old_angle:float=rotation_for(id,prior,old_angles)
        var spec:Dictionary=segment(id)
        var center:Vector2=spec.center
        var mass:float=spec.mass
        var pos:Vector2=rig.point(id)+center.rotated(angle)
        var prev:Vector2=Vector2(old_points[id])+center.rotated(old_angle)
        var limits:Vector2=joint_limits(id)
        var goal:float=joint_goal(id,entry)
        var data:Dictionary={"id":id,"parent":parent,"offset":Vector2(j.offset),"com":center,"p":pos,"a":angle,"v":((pos-prev)*60.).limit_length(25.),"w":clampf(wrapf(angle-old_angle,-PI,PI)*60.,-3.,3.),"inv":1./mass,"ii":1./float(spec.inertia),"mass":mass,"samples":spec.samples,"lo":limits.x,"hi":limits.y,"goal":goal,"old_p":pos,"old_a":angle,"touch":false}
        ids[id]=bodies.size()
        bodies.append(data)
    var com:=Vector2.ZERO
    var mean:=Vector2.ZERO
    var mass_sum:float=0.
    for b in bodies:
        com+=Vector2(b.p)*float(b.mass)
        mean+=Vector2(b.v)*float(b.mass)
        mass_sum+=float(b.mass)
    com/=mass_sum
    mean/=mass_sum
    for b in bodies:
        var lever:Vector2=Vector2(b.p)-com
        b.v=Vector2(b.v)-mean+velocity+Vector2(-lever.y,lever.x)*spin
        b.w=float(b.w)+spin

func rotation_for(id:String,p:Dictionary,angles:Dictionary)->float:
    if id.begins_with("foot_"):return deg_to_rad(float(p.angles["foot_pitch_"+id.trim_prefix("foot_")]))
    if id.begins_with("hand_"):
        return float(angles[id.replace("hand_","elbow_")])+Vector2(rig.joints[rig.ids[id]].offset).angle()-PI*.5
    return float(angles[id])

func segment(id:String)->Dictionary:
    # Local COM offsets and circle samples are approximate anatomy, not
    # exact raster surface collision. Preserve the accepted rig lengths.
    var center:=Vector2.ZERO
    var mass:float=.7
    var inertia:float=2.
    var samples:Array=[]
    if id=="hips":
        center=Vector2(0,-8)
        mass=7.
        inertia=7.*(16.*16.+7.*7.)/12.
        samples=[[Vector2.ZERO,3.6],[Vector2(0,-7),3.5],[Vector2(0,-14),4.]]
    elif id=="chest":
        center=Vector2(0,-3.5)
        mass=3.5
        inertia=36.
        samples=[[Vector2.ZERO,4.],[Vector2(0,-5),2.2]]
    elif id=="head":
        mass=2.2
        inertia=19.
        samples=[[Vector2.ZERO,4.5]]
    elif id.begins_with("foot_"):
        center=Vector2(1.2,0)
        mass=.6
        inertia=2.2
        samples=[[Vector2(-.1,0),1.45],[Vector2(2.1,0),1.1],[Vector2(3.8,0),.7]]
    elif id.begins_with("hand_"):
        center=Vector2(0,1.1)
        mass=.35
        inertia=.8
        samples=[[Vector2.ZERO,1.15],[Vector2(0,1.8),1.25]]
    else:
        var child:String=""
        if id.begins_with("elbow_"):child=id.replace("elbow_","hand_")
        if id.begins_with("thigh_"):child=id.replace("thigh_","knee_")
        if id.begins_with("knee_"):child=id.replace("knee_","foot_")
        if id.begins_with("shoulder_"):child=id.replace("shoulder_","elbow_")
        var arm:bool=id.begins_with("shoulder_") or id.begins_with("elbow_")
        var upper:bool=id.begins_with("shoulder_") or id.begins_with("thigh_")
        var end:Vector2=rig.joints[rig.ids[child]].offset
        center=end*.5
        mass=(1.2 if upper else .85) if arm else (2.8 if upper else 1.8)
        var radius:float=(1.8 if upper else 1.5) if arm else (2.5 if upper else 1.8)
        inertia=mass*(end.length_squared()+4.*radius*radius)/12.
        samples=[[end*.18,radius],[end*.5,radius],[end*.86,radius*.8]]
    return {"center":center,"mass":mass,"inertia":inertia,"samples":samples}

func joint_limits(id:String)->Vector2:
    var degrees:=Vector2(-180,180)
    if id=="chest":degrees=Vector2(-42,58)
    elif id=="head":degrees=Vector2(-48,55)
    elif id.begins_with("thigh_"):degrees=Vector2(-140,65)
    elif id.begins_with("knee_"):
        var rest:float=Leg.rest(id.trim_prefix("knee_"))
        degrees=Vector2(-2.*rest,155.-2.*rest)
    elif id.begins_with("foot_"):
        var rest:float=Leg.rest(id.trim_prefix("foot_"))
        degrees=Vector2(-95.+rest,85.+rest)
    elif id.begins_with("shoulder_"):degrees=Vector2(-175,140)
    elif id.begins_with("elbow_"):
        var upper:Vector2=rig.joints[rig.ids[id]].offset
        var lower:Vector2=rig.joints[rig.ids[id.replace("elbow_","hand_")]].offset
        var correction:float=rad_to_deg(upper.angle()-lower.angle())
        degrees=Vector2(-155.+correction,correction)
    elif id.begins_with("hand_"):
        var rest:float=rad_to_deg(Vector2(rig.joints[rig.ids[id]].offset).angle()-PI*.5)
        degrees=Vector2(rest,rest)
    return degrees*PI/180.

func joint_goal(id:String,p:Dictionary)->float:
    # Only local joint targets. No absolute orientation motor, no root motor,
    # no target after the first contact. Reference 3 pike, approximate angles.
    var angle:float=float(p.angles.get(id,0.))
    if id=="chest":angle=35.
    elif id=="head":angle=18.
    elif id.begins_with("thigh_"):angle=-112. if id.ends_with("near") else -117.
    elif id.begins_with("knee_"):angle=(17. if id.ends_with("near") else 29.)-2.*Leg.rest(id.trim_prefix("knee_"))
    elif id.begins_with("shoulder_"):angle=-106. if id.ends_with("near") else -143.
    elif id.begins_with("elbow_"):
        var u:Vector2=rig.joints[rig.ids[id]].offset
        var l:Vector2=rig.joints[rig.ids[id.replace("elbow_","hand_")]].offset
        angle=-10.+rad_to_deg(u.angle()-l.angle())
    elif id.begins_with("foot_"):angle=28.+Leg.rest(id.trim_prefix("foot_"))
    var bounds:Vector2=joint_limits(id)
    return clampf(deg_to_rad(angle),bounds.x,bounds.y)

func pivot(b:Dictionary)->Vector2:
    return Vector2(b.p)-Vector2(b.com).rotated(float(b.a))

func angular_motor(b:Dictionary,a:Dictionary,strength:float)->void:
    var error:float=wrapf(float(b.goal)-wrapf(float(b.a)-float(a.a),-PI,PI),-PI,PI)
    var speed:float=float(b.w)-float(a.w)
    var delta:float=clampf((360.*error-24.*speed)*H*strength,-4.*strength,4.*strength)
    var impulse:float=delta/(float(a.ii)+float(b.ii))
    a.w=float(a.w)-impulse*float(a.ii)
    b.w=float(b.w)+impulse*float(b.ii)

func residual_tone(a:Dictionary,b:Dictionary)->void:
    # A zero-relative-speed motor with a bounded internal angular impulse.
    # The elastic contribution acts only outside a broad neutral range.
    # No prescribed resting pose; no world-space motor or root force.
    var id:String=b.id
    if id.begins_with("hand_"):return
    var relative:float=wrapf(float(b.a)-float(a.a),-PI,PI)
    var speed:float=float(b.w)-float(a.w)
    var lo:float=float(b.lo)
    var hi:float=float(b.hi)
    var stiffness:float=0.
    var resistance:float=5.
    var max_torque:float=35.
    if id.begins_with("thigh_"):
        var rest:float=Leg.rest(id.trim_prefix("thigh_"))
        lo=deg_to_rad(-60.+rest)
        hi=deg_to_rad(32.+rest)
        stiffness=180.
        resistance=9.
        max_torque=220.
    elif id=="chest":
        lo=deg_to_rad(-20.)
        hi=deg_to_rad(30.)
        stiffness=150.
        resistance=8.
        max_torque=180.
    elif id=="head":
        lo=deg_to_rad(-25.)
        hi=deg_to_rad(30.)
        stiffness=65.
        max_torque=65.
    elif id.begins_with("knee_"):
        var rest:float=Leg.rest(id.trim_prefix("knee_"))
        lo=deg_to_rad(-2.*rest)
        hi=deg_to_rad(100.-2.*rest)
        stiffness=55.
        max_torque=85.
    var excess:float=relative-clampf(relative,lo,hi)
    var effective:float=1./(float(a.ii)+float(b.ii))
    var impulse:float=clampf((-stiffness*excess-resistance*effective*speed)*H,-max_torque*H,max_torque*H)*(1.-motor)
    a.w=float(a.w)-impulse*float(a.ii)
    b.w=float(b.w)+impulse*float(b.ii)
    tone_impulse+=absf(impulse)

func center_of_mass()->Vector2:
    var com:=Vector2.ZERO
    var total:float=0.
    for b in bodies:
        com+=Vector2(b.p)*float(b.mass)
        total+=float(b.mass)
    return com/maxf(total,.001)

func solve_angle(a:Dictionary,b:Dictionary)->void:
    var relative:float=wrapf(float(b.a)-float(a.a),-PI,PI)
    var lower:float=float(b.lo)
    # Keep the initial pike target available; after the artistic motor fades
    # limit forward hip flexion in geometric (rest-corrected) coordinates.
    if profile>0 and String(b.id).begins_with("thigh_"):
        var rest:float=Leg.rest(String(b.id).trim_prefix("thigh_"))
        var release:float=1.-motor
        lower=maxf(lower,deg_to_rad(lerpf(-130.,-105.,release)+rest))
    var c:float=relative-clampf(relative,lower,float(b.hi))
    if absf(c)<.000001:return
    var impulse:float=-c/(float(a.ii)+float(b.ii))
    a.a=float(a.a)-impulse*float(a.ii)
    b.a=float(b.a)+impulse*float(b.ii)

func solve_anchor(a:Dictionary,b:Dictionary,axis:Vector2)->void:
    var ra:Vector2=(Vector2(b.offset)-Vector2(a.com)).rotated(float(a.a))
    var rb:Vector2=-Vector2(b.com).rotated(float(b.a))
    var c:float=(Vector2(b.p)+rb-Vector2(a.p)-ra).dot(axis)
    var ja:float=ra.cross(axis)
    var jb:float=rb.cross(axis)
    var impulse:float=-c/(float(a.inv)+float(b.inv)+ja*ja*float(a.ii)+jb*jb*float(b.ii))
    a.p=Vector2(a.p)-axis*impulse*float(a.inv)
    b.p=Vector2(b.p)+axis*impulse*float(b.inv)
    a.a=float(a.a)-ja*impulse*float(a.ii)
    b.a=float(b.a)+jb*impulse*float(b.ii)

func solve_floor(b:Dictionary,s:Array)->void:
    var local:Vector2=Vector2(s[0])-Vector2(b.com)
    var arm:Vector2=local.rotated(float(b.a))
    var pos:Vector2=Vector2(b.p)+arm
    var depth:float=pos.y+float(s[1])-floor_y
    if depth<=0.:return
    b.touch=true
    var j:float=arm.cross(Vector2.UP)
    var impulse:float=depth/(float(b.inv)+j*j*float(b.ii))
    b.p=Vector2(b.p)+Vector2.UP*impulse*float(b.inv)
    b.a=float(b.a)+j*impulse*float(b.ii)
    # Bounded tangential correction at the contact point, in the same
    # position solve. No scripted horizontal slide or forced floor pose.
    arm=local.rotated(float(b.a))
    var old_point:Vector2=Vector2(b.old_p)+local.rotated(float(b.old_a))
    var dx:float=(Vector2(b.p)+arm-old_point).x
    var jt:float=arm.cross(Vector2.RIGHT)
    var mu:float=.22
    
    var tangent:float=clampf(-dx/(float(b.inv)+jt*jt*float(b.ii)),-mu*impulse,mu*impulse)
    friction_impulse+=absf(tangent)
    b.p=Vector2(b.p)+Vector2.RIGHT*tangent*float(b.inv)
    b.a=float(b.a)+jt*tangent*float(b.ii)

func substep()->void:
    tone_impulse=0.
    friction_impulse=0.
    var t:float=float(steps)*H
    motor=(1.-smoothstep(.12,.35,t)) if guided and not touched else 0.
    if motor>0.:
        for b in bodies:
            if int(b.parent)>=0 and not String(b.id).begins_with("hand_"):
                angular_motor(b,bodies[b.parent],motor)
    if profile>0 and motor<.999:
        for b in bodies:
            if int(b.parent)>=0:
                # Blend in progressively rather than abruptly switching
                # from the artistic motor to residual muscle resistance.
                residual_tone(b,bodies[b.parent])
    for b in bodies:
        b.old_p=b.p
        b.old_a=b.a
        b.touch=false
        b.v=(Vector2(b.v)+GRAVITY*H)*exp(-DAMP*H)
        b.w=float(b.w)*exp(-DAMP*H)
        b.p=Vector2(b.p)+Vector2(b.v)*H
        b.a=float(b.a)+float(b.w)*H
    for iteration in iterations:
        for i in range(1,bodies.size()):
            var b:Dictionary=bodies[i]
            var a:Dictionary=bodies[b.parent]
            solve_angle(a,b)
            solve_anchor(a,b,Vector2.RIGHT)
            solve_anchor(a,b,Vector2.DOWN)
        for b in bodies:
            for s in b.samples:solve_floor(b,s)
    anchor_error=0.
    penetration=0.
    contact_count=0
    peak_speed=0.
    for b in bodies:
        b.v=(Vector2(b.p)-Vector2(b.old_p))/H
        b.w=(float(b.a)-float(b.old_a))/H
        peak_speed=maxf(peak_speed,Vector2(b.v).length()+absf(float(b.w))*2.)
        if b.touch:contact_count+=1
        if int(b.parent)>=0:
            var a:Dictionary=bodies[b.parent]
            anchor_error=maxf(anchor_error,pivot(b).distance_to(pivot(a)+Vector2(b.offset).rotated(float(a.a))))
        for s in b.samples:
            var p:Vector2=pivot(b)+Vector2(s[0]).rotated(float(b.a))
            penetration=maxf(penetration,p.y+float(s[1])-floor_y)
    if contact_count>0:
        touched=true
        motor=0.
    steps+=1

func pose()->Dictionary:
    var p:Dictionary=template.duplicate(true)
    var root:Vector2=pivot(bodies[0])-Vector2(rig.joints[0].offset)
    p.root=[root.x,root.y]
    for b in bodies:
        var id:String=b.id
        if id.begins_with("foot_"):
            p.angles["foot_pitch_"+id.trim_prefix("foot_")]=rad_to_deg(float(b.a))
        elif not id.begins_with("hand_"):
            var angle:float=float(b.a) if int(b.parent)<0 else float(b.a)-float(bodies[b.parent].a)
            p.angles[id]=rad_to_deg(wrapf(angle,-PI,PI))
    for side in Leg.SIDES:Leg.put(p,side,Leg.bend(p,side),Leg.ankle(p,side))
    rig.evaluate(p)
    pose_error=0.
    for b in bodies:pose_error=maxf(pose_error,rig.point(b.id).distance_to(pivot(b)))
    return p

func tick()->Dictionary:
    for sub in 2:substep()
    return pose()

func snapshot()->Dictionary:
    return {"bodies":bodies.duplicate(true),"steps":steps,"touched":touched,"contact_count":contact_count,"penetration":penetration,"anchor_error":anchor_error,"pose_error":pose_error,"motor":motor,"peak_speed":peak_speed,"tone_impulse":tone_impulse,"friction_impulse":friction_impulse}

func restore(s:Dictionary)->void:
    bodies=s.bodies.duplicate(true)
    steps=s.steps
    touched=s.touched
    contact_count=s.contact_count
    penetration=s.penetration
    anchor_error=s.anchor_error
    pose_error=s.pose_error
    motor=s.motor
    peak_speed=s.peak_speed
    tone_impulse=s.tone_impulse
    friction_impulse=s.friction_impulse
