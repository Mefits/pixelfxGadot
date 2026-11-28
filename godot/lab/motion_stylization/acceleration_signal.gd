extends RefCounted
## Presentation only, common for any strike. One authored phase permission;
## velocity, tangential acceleration and coherence are soft weights.
var tick:int=-1
var key:String=""
var anchor:String=""
var phase:bool=false
var prior:Vector2=Vector2.ZERO
var prior_world:Vector2=Vector2.ZERO
var velocity:Vector2=Vector2.ZERO
var acceleration:float=0.
var score:float=0.
var strength:float=1.
var sensitivity:float=1.
var onset_level:float=.025
var onset_tick:int=-1
var onset_world:Vector2=Vector2.ZERO
var path:PackedVector2Array=PackedVector2Array()
var direction:Vector2=Vector2.RIGHT
var displacement:Vector2=Vector2.ZERO

func reset()->void:
    tick=-1
    key=""
    anchor=""
    phase=false
    velocity=Vector2.ZERO
    acceleration=0.
    score=0.
    onset_tick=-1
    path.clear()
    displacement=Vector2.ZERO

func sample(t:int,id:String,limb:String,allowed:bool,local:Vector2,world:Vector2)->void:
    if tick==t:return
    var contiguous:bool=t==tick+1 and id==key and limb==anchor and not id.is_empty()
    var old_v:Vector2=velocity if contiguous else Vector2.ZERO
    var old_p:Vector2=prior if contiguous else local
    var v:Vector2=(local-old_p)*60.
    acceleration=(v.length()-old_v.length())*60. if contiguous else 0.
    var align:float=1.
    if v.length()>1. and old_v.length()>1.:
        align=clampf((v.normalized().dot(old_v.normalized())+1.)*.5,0.,1.)
    # No hard direction gate. A curved strike can still be expressive.
    var s:float=smoothstep(10.,170.,v.length()*sensitivity)
    var a:float=smoothstep(0.,4500.,maxf(0.,acceleration)*sensitivity)
    var raw:float=s*(.42+.58*a)*lerpf(.45,1.,align)
    if not allowed or not contiguous:
        score=0.
        path.clear()
        onset_tick=-1
        displacement=Vector2.ZERO
    else:
        if not phase:
            score=0.
            onset_tick=-1
            path.clear()
        # Fast attack onset, softer decay. Once begun, do not restart on
        # every positive acceleration spike or invent pre-chamber history.
        score=maxf(raw,score*.68)
        # Single adjustable onset visibility level, not multiple motion gates.
        if onset_tick<0 and score>onset_level:
            onset_tick=t
            onset_world=prior_world
            path.append(onset_world)
        if onset_tick>=0:
            if path.is_empty() or path[-1].distance_to(world)>.08:path.append(world)
            if path.size()>24:path.remove_at(1)
            displacement=(displacement+(local-old_p)).limit_length(32.)
    if v.length_squared()>1.:direction=v.normalized()
    velocity=v
    prior=local
    prior_world=world
    tick=t
    key=id
    anchor=limb
    phase=allowed

func trail()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if not phase or score<=.005 or strength<=0. or path.size()<2:return out
    # The first sample stays at the measured onset. Smooth intermediate
    # positions towards the onset-to-tip chord; preserve both endpoints.
    var end:Vector2=path[-1]
    var length:float=0.
    for i in range(1,path.size()):length+=path[i-1].distance_to(path[i])
    if length<.15:return out
    var distance:float=0.
    var alpha:float=clampf(sqrt(score)*strength,0.,1.)
    for i in path.size():
        if i>0:distance+=path[i-1].distance_to(path[i])
        var u:float=distance/length
        var p:Vector2=path[i].lerp(onset_world.lerp(end,u),.36*sin(PI*u))
        out.append({"p":p,"width":lerpf(.10,5.6,pow(u,.8))*alpha,"alpha":alpha*lerpf(.18,.94,u)})
    return out
