extends RefCounted
## Presentation-only sampler. World trajectory for trails; local velocity for deformation.
const MAX_SAMPLES=10
var samples:Array[Dictionary]=[]
var last_tick:int=-1
var attack_key:String=""
var last_age:int=-1
var prior_local:Vector2=Vector2.ZERO
var delta:Vector2=Vector2.ZERO
var heading:Vector2=Vector2.RIGHT
var weight:float=0.
var trail_weight:float=0.
var curvature:float=0.
var active_anchor:String=""
var strength:float=1.
var threshold:float=75.
var smear_threshold:float=55.
var impact_weight:float=0.
var impact_tip:Vector2=Vector2.ZERO
var impact_dir:Vector2=Vector2.RIGHT
var impact_tick:int=-100
var impact_key:String=""

func reset()->void:
    samples.clear()
    last_tick=-1
    attack_key=""
    last_age=-1
    delta=Vector2.ZERO
    heading=Vector2.RIGHT
    weight=0.
    trail_weight=0.
    curvature=0.
    active_anchor=""
    impact_weight=0.
    impact_tick=-100
    impact_key=""

func is_kick()->bool:
    return attack_key=="K"

func sample(tick:int,key:String,age:int,anchor:String,local:Vector2,world:Vector2,gate:bool,smear_gate:bool=true,accent:bool=false)->void:
    if tick==last_tick:return
    var discontinuity:bool=tick<last_tick or tick>last_tick+1 or key!=attack_key or age<last_age or anchor!=active_anchor
    if discontinuity:
        samples.clear()
        delta=Vector2.ZERO
        curvature=0.
        heading=Vector2.RIGHT
        impact_tick=-100
        impact_key=""
    else:
        var next_delta:Vector2=local-prior_local
        if next_delta.length_squared()>.01:
            var new_heading:Vector2=next_delta.normalized()
            curvature=absf(heading.angle_to(new_heading)) if delta.length_squared()>.01 else 0.
            heading=new_heading
        delta=next_delta
    last_tick=tick
    last_age=age
    attack_key=key
    active_anchor=anchor
    prior_local=local
    var speed:float=delta.length()*60.
    var top:float=285. if is_kick() else 240.
    var active:bool=not key.is_empty()
    trail_weight=smoothstep(threshold,maxf(threshold+1.,top),speed) if gate and active else 0.
    weight=smoothstep(smear_threshold,maxf(smear_threshold+1.,top*.88),speed) if gate and smear_gate and active else 0.
    var limit:int=MAX_SAMPLES if is_kick() else 7
    while not samples.is_empty() and tick-int(samples[0].tick)>=limit:
        samples.pop_front()
    if gate and active:
        samples.append({"p":world,"tick":tick,"w":trail_weight})
        if samples.size()>limit:samples.pop_front()
    if accent and active:
        impact_tick=tick
        impact_tip=world
        impact_dir=heading
        impact_key=key
    var dt:int=tick-impact_tick
    impact_weight=(1. if dt==0 else .46) if active and impact_key==key and dt>=0 and dt<=1 else 0.

func trail()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if samples.size()<2 or strength<=0.:return out
    var peak:float=0.
    for s in samples:peak=maxf(peak,float(s.w))
    if peak<=.005:return out
    var limit:float=10. if is_kick() else 7.
    # Keep a faithful sampled path. Chaikin corner cuts produce a smooth arc
    # inside the polyline hull (no invented overshooting spline).
    var raw:Array[Dictionary]=[]
    for i in samples.size():
        var s:Dictionary=samples[i]
        var fade:float=clampf(1.-float(last_tick-int(s.tick))/limit,0.,1.)
        var u:float=float(i)/float(samples.size()-1)
        var broad:float=8.2 if is_kick() else 6.4
        var width:float=broad*strength*pow(peak,.55)*pow(fade,.65)*lerpf(.035,1.,pow(u,.82))
        raw.append({"p":s.p,"width":width,"alpha":minf(.96,.98*pow(fade,.65)*pow(peak,.45)*minf(strength,1.))})
    out.append(raw[0])
    for i in range(1,raw.size()):
        var a:Dictionary=raw[i-1]
        var b:Dictionary=raw[i]
        if Vector2(a.p).distance_squared_to(Vector2(b.p))<.0025:continue
        for t in [.25,.75]:
            out.append({"p":Vector2(a.p).lerp(Vector2(b.p),t),"width":lerpf(a.width,b.width,t),"alpha":lerpf(a.alpha,b.alpha,t)})
    if Vector2(out[-1].p).distance_squared_to(Vector2(raw[-1].p))>.0025:out.append(raw[-1])
    return out if out.size()>=2 else []

static func shift_xy(part:Dictionary,key:String,amount:Vector2)->void:
    part[key][0]+=amount.x
    part[key][1]+=amount.y

func deform(parts:Array)->Array:
    if weight<=.005 or strength<=0. or active_anchor.is_empty():return parts
    var near:bool=active_anchor.ends_with("_near")
    var arm:bool=active_anchor.begins_with("hand_")
    var upper:int=(9 if near else 3) if arm else (12 if near else 6)
    var lower:int=upper+1
    if parts.size()<=lower or parts[upper].get("type")!="loft" or parts[lower].get("type")!="loft":return parts
    # Drag only the visual shared hinge; preserve actual strike and support.
    # Curvature boosts the smear on arcing movement, within a hard limit.
    var bend:float=1.+.35*clampf(curvature/1.2,0.,1.)
    var offset:Vector2=(-delta*weight*strength*1.65*bend).limit_length(7.5 if arm else 9.)
    if offset.length_squared()<.0025:return parts
    var out:Array=parts.duplicate(true)
    shift_xy(out[upper],"b",offset)
    shift_xy(out[lower],"a",offset)
    for i in [upper,lower]:
        for row in out[i].sections:
            var u:float=clampf(float(row[0]),0.,1.)
            var swell:float=1.+.48*weight*strength*sin(PI*u)
            row[1]*=swell
            row[2]*=swell
    return out

func accent_lines()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if impact_weight<=0. or strength<=0.:return out
    var axis:Vector2=impact_dir.normalized()
    var normal:=Vector2(-axis.y,axis.x)
    var size:float=(11. if impact_key=="K" else 8.)*strength
    # Two-tick directional burst behind the authored accent. No hit sparks:
    # this describes acceleration even when the strike misses.
    for i in range(-2,3):
        var spread:float=float(i)
        var end:Vector2=impact_tip-axis*(2.+absf(spread)*1.7)+normal*spread*2.4
        var start:Vector2=end-axis*size*(1.-absf(spread)*.23)-normal*spread*1.2
        out.append({"a":start,"b":end,"width":(1.05 if i==0 else .65)*strength,"alpha":impact_weight*(1.-absf(spread)*.17)})
    return out
