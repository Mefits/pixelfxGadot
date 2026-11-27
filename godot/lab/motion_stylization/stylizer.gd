extends RefCounted
## Presentation only. Coordinates are rig units; samples once per simulation tick.
const MAX_SAMPLES=6
const MAX_SPEED=450.0
var samples:Array[Dictionary]=[]
var last_tick:int=-1
var attack_key:String=""
var last_age:int=-1
var prior_local:Vector2=Vector2.ZERO
var delta:Vector2=Vector2.ZERO
var weight:float=0.
var active_anchor:String=""
var strength:float=1.
var threshold:float=75.

func reset()->void:
    samples.clear()
    last_tick=-1
    attack_key=""
    last_age=-1
    delta=Vector2.ZERO
    weight=0.
    active_anchor=""

func sample(tick:int,key:String,age:int,anchor:String,local:Vector2,world:Vector2,gate:bool)->void:
    if tick==last_tick:return
    if tick<last_tick or tick>last_tick+1 or key!=attack_key or age<last_age:
        samples.clear()
        delta=Vector2.ZERO
        weight=0.
        prior_local=local
    else:
        delta=local-prior_local
    last_tick=tick
    last_age=age
    attack_key=key
    active_anchor=anchor
    prior_local=local
    var speed:float=delta.length()*60.
    weight=smoothstep(threshold,maxf(threshold+1.,MAX_SPEED),speed) if gate and not key.is_empty() else 0.
    while not samples.is_empty() and tick-int(samples[0].tick)>=MAX_SAMPLES:
        samples.pop_front()
    if gate and not key.is_empty():
        # Seed slow samples as well so both trails use the actual preceding path.
        samples.append({"p":world,"tick":tick,"w":weight})
        if samples.size()>MAX_SAMPLES:samples.pop_front()

func trail()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if samples.size()<2 or strength<=0.:return out
    var peak:float=0.
    for s in samples:peak=maxf(peak,float(s.w))
    if peak<=.005:return out
    for i in samples.size():
        var s:Dictionary=samples[i]
        var age:int=last_tick-int(s.tick)
        var fade:float=maxf(0.,1.-float(age)/MAX_SAMPLES)
        var u:float=float(i)/float(samples.size()-1)
        var width:float=4.2*strength*peak*fade*lerpf(.08,1.,u)
        out.append({"p":s.p,"width":width,"alpha":.72*fade*peak})
    return out

static func shift_xy(part:Dictionary,key:String,amount:Vector2)->void:
    part[key][0]+=amount.x
    part[key][1]+=amount.y

func deform(parts:Array)->Array:
    if weight<=.005 or strength<=0. or active_anchor.is_empty():return parts
    # 069 fixed humanoid topology: shoulder/arm/forearm or hip/thigh/shin.
    # Move the shared visual hinge backwards along actual displacement;
    # preserve root, wrist/ankle, terminal part and gameplay pose.
    var near:bool=active_anchor.ends_with("_near")
    var arm:bool=active_anchor.begins_with("hand_")
    var upper:int=(9 if near else 3) if arm else (12 if near else 6)
    var lower:int=upper+1
    if parts.size()<=lower or parts[upper].get("type")!="loft" or parts[lower].get("type")!="loft":return parts
    var offset:Vector2=(-delta*weight*strength*.85).limit_length(4.5)
    if offset.length_squared()<.0025:return parts
    var out:Array=parts.duplicate(true)
    shift_xy(out[upper],"b",offset)
    shift_xy(out[lower],"a",offset)
    # Modest tapered widening, not a larger fist/foot.
    for i in [upper,lower]:
        for row in out[i].sections:
            var u:float=clampf(float(row[0]),0.,1.)
            var swell:float=1.+.18*weight*strength*sin(PI*u)
            row[1]*=swell
            row[2]*=swell
    return out
