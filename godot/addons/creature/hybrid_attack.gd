extends RefCounted
## Authored intentions, not baked world positions. Physical chunks remain authoritative.
## claw offsets are normalized by reach; tilt by the current trunk length.
const DURATION: float=.56
const ACTIVE_FROM: float=.19
const ACTIVE_TO: float=.32
const KEYS=[
    {"t":0.0,"claw":Vector2(.15,.65),"tilt":-.12,"speed":0.0,"rear":0.0},
    {"t":.15,"claw":Vector2(-.65,-.45),"tilt":.48,"speed":-20.0,"rear":3.0},
    {"t":.22,"claw":Vector2(.92,-.30),"tilt":-.40,"speed":175.0,"rear":-2.0},
    {"t":.30,"claw":Vector2(.96,.20),"tilt":-.25,"speed":155.0,"rear":-1.0},
    {"t":.42,"claw":Vector2(.30,.65),"tilt":-.12,"speed":0.0,"rear":0.0},
    {"t":.56,"claw":Vector2(.15,.65),"tilt":-.12,"speed":0.0,"rear":0.0}
]
var active: bool=false
var time: float=0
var facing: float=1
var leg: int=-1
var count: int=0
var hit_count: int=0
var hit_ids: Dictionary={}
var contacts: Array[Dictionary]=[]
var targets: Array[Dictionary]=[]
var valid_pose: bool=false
var prev_valid: bool=false
var prev_tip:=Vector2.ZERO
var tip:=Vector2.ZERO
var knee:=Vector2.ZERO
var desired_tip:=Vector2.ZERO
var blocked: bool=false
var blocked_ticks: int=0
var peak_support: int=0
var had_active_support: bool=false

func begin(limbs,direction: float) -> bool:
    if active or not limbs.enabled:return false
    leg=-1
    for i in range(limbs.legs.size()):
        if limbs.legs[i].parent==0 and limbs.legs[i].side>0:
            leg=i
            break
    if leg<0:return false
    active=true
    time=0
    facing=direction
    count+=1
    hit_ids.clear()
    contacts.clear()
    prev_valid=false
    valid_pose=false
    blocked=false
    blocked_ticks=0
    peak_support=0
    had_active_support=false
    limbs.override_leg=leg
    limbs.legs[leg].planted=false
    limbs.legs[leg].swing=false
    return true

func cancel(limbs) -> void:
    active=false
    valid_pose=false
    prev_valid=false
    limbs.override_leg=-1
    limbs.rear_height_offset=0
    limbs.front_height_offset=0

func sample(t: float) -> Dictionary:
    t=clampf(t,0,DURATION)
    for i in range(1,KEYS.size()):
        var a: Dictionary=KEYS[i-1]
        var b: Dictionary=KEYS[i]
        if t<=float(b.t):
            var u: float=(t-float(a.t))/(float(b.t)-float(a.t))
            u=u*u*(3-2*u)
            return {"claw":Vector2(a.claw).lerp(b.claw,u),"tilt":lerpf(a.tilt,b.tilt,u),"speed":lerpf(a.speed,b.speed,u),"rear":lerpf(a.rear,b.rear,u)}
    return KEYS[-1]

func phase() -> String:
    if not active:return "idle"
    if time<ACTIVE_FROM:return "windup"
    if time<=ACTIVE_TO:return "strike"
    return "recover"

static func segment_blocked(a: Vector2,b: Vector2,boxes: Array[Rect2],radius: float=0.0) -> bool:
    # Slab test for the entire closed segment against expanded rectangles.
    for source in boxes:
        var box: Rect2=source.grow(radius)
        var t0: float=0
        var t1: float=1
        var d: Vector2=b-a
        var intersects: bool=true
        for axis in range(2):
            var origin: float=a[axis]
            var delta: float=d[axis]
            var lo: float=box.position[axis]
            var hi: float=box.end[axis]
            if absf(delta)<.000001:
                if origin<lo or origin>hi:intersects=false;break
            else:
                var u: float=(lo-origin)/delta
                var v: float=(hi-origin)/delta
                t0=maxf(t0,minf(u,v))
                t1=minf(t1,maxf(u,v))
                if t0>t1:intersects=false;break
        if intersects:return true
    return false

static func solve(hip: Vector2,goal: Vector2,upper: float,lower: float,bend: float,boxes: Array[Rect2],old_tip: Vector2,has_old: bool) -> Dictionary:
    var d: Vector2=goal-hip
    var angle: float=d.angle() if d.length_squared()>.000001 else 0
    var min_len: float=absf(upper-lower)+.01
    var max_len: float=upper+lower-.01
    # Try full desired reach, shortened reach, and alternate bends.
    for turn in [0.0,.24,-.24,.50,-.50,.85,-.85,1.2,-1.2,PI]:
        var axis:=Vector2.from_angle(angle+float(turn))
        for factor in [1.0,.8,.6,.4,.2]:
            var length: float=clampf(d.length()*float(factor),min_len,max_len)
            var end: Vector2=hip+axis*length
            if has_old and segment_blocked(old_tip,end,boxes,.55):continue
            var along: float=(upper*upper-lower*lower+length*length)/(2*length)
            var height: float=sqrt(maxf(0,upper*upper-along*along))
            for sign0 in [bend,-bend]:
                var middle: Vector2=hip+axis*along+axis.orthogonal()*height*float(sign0)
                if segment_blocked(hip,middle,boxes,.55) or segment_blocked(middle,end,boxes,.55):continue
                return {"knee":middle,"tip":end}
    return {}

func after_step(body,limbs,dt: float) -> void:
    if not active:return
    var old_time: float=time
    time=minf(DURATION,time+dt)
    var intent: Dictionary=sample(time)
    var hip: Vector2=body.nodes[limbs.legs[leg].parent].p
    var reach: float=limbs.upper+limbs.lower
    desired_tip=hip+Vector2(intent.claw.x*facing,intent.claw.y)*reach
    var result: Dictionary=solve(hip,desired_tip,limbs.upper,limbs.lower,facing,body.obstacles,prev_tip,prev_valid)
    valid_pose=not result.is_empty()
    blocked=not valid_pose or Vector2(result.get("tip",hip)).distance_to(desired_tip)>2.5
    if blocked:blocked_ticks+=1
    peak_support=maxi(peak_support,limbs.support_count)
    if time>=ACTIVE_FROM and time<=ACTIVE_TO and limbs.support_count>0:had_active_support=true
    if valid_pose:
        knee=result.knee
        tip=result.tip
        var l: Dictionary=limbs.legs[leg]
        l.knee=knee
        l.tip=tip
        l.foot=tip
        l.planted=false
        l.swing=false
        # An active window is independent of rendering rate and may hit each target once.
        if time>=ACTIVE_FROM and old_time<ACTIVE_TO:
            var start: Vector2=prev_tip if prev_valid else tip
            for target in targets:
                if int(target.hp)<=0 or hit_ids.has(target.id):continue
                var center: Vector2=target.p
                var delta: Vector2=tip-start
                var u: float=clampf((center-start).dot(delta)/maxf(delta.length_squared(),.000001),0,1)
                var closest: Vector2=start+delta*u
                if closest.distance_to(center)<=float(target.r)+2 and not segment_blocked(hip,center,body.obstacles,.1) and not segment_blocked(closest,center,body.obstacles,.1):
                    target.hp=maxi(0,int(target.hp)-20)
                    hit_ids[target.id]=true
                    hit_count+=1
                    contacts.append({"p":closest,"t":time,"id":target.id})
        prev_tip=tip
        prev_valid=true
    else:
        prev_valid=false
    if time>=DURATION:cancel(limbs)
