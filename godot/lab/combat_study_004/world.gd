extends "res://lab/combat_study_003/world.gd"
const Air=preload("res://lab/combat_study_004/air.gd")
var pursuits:Array=[]
var air_hits:Array=[]
var slams:Array=[]
var juggle_events:Array=[]
var approach_budget:float=0.

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2):
    super(gap,stop_enabled,profile)
    var frames:Array=[]
    var roots:Array=[]
    var feet:Array=[]
    for i in Air.CHASE_DURATION:
        frames.append(guard.duplicate(true))
        roots.append([0.,0.])
        feet.append({})
    bank.chase={"frames":frames,"roots":roots,"feet":feet,"markers":{Air.CHASE_MARK:[{"kind":"utility","anchor":"hand_near"}]},"loop":false}
    bank.air_cross=retime(bank.cross,5,12)
    bank.air_pulse=retime(bank.pulse,5,12)
    bank.slam=retime(bank.cross,6,14)
    for s in actors:
        s.chasing=false
        s.follow_left=0
        s.air_used=[]
        s.juggled=false

# Preserve actual source contact pose and marker. No extra strike generated
# by a cancel. These are diagnostic retimed ground poses, not finished air art.
func retime(src:Dictionary,marker:int,length:int)->Dictionary:
    var old_marker:int=int(src.markers.keys()[0])
    var old_last:int=src.frames.size()-1
    var out:Dictionary={"frames":[],"roots":[],"feet":[],"markers":{marker:src.markers[old_marker].duplicate(true)},"loop":false}
    for i in length:
        var f:int=roundi(lerpf(0.,float(old_marker),float(i)/marker)) if i<=marker else roundi(lerpf(float(old_marker),float(old_last),float(i-marker)/(length-1-marker)))
        out.frames.append(src.frames[f].duplicate(true))
        out.roots.append(src.roots[f].duplicate(true))
        out.feet.append(src.feet[f].duplicate(true))
    return out

func rule_for(action:String)->Dictionary:
    return Air.EXTRA.get(action,super.rule_for(action))

func airborne(slot:int)->bool:
    return float(actors[slot].y)<0. or float(actors[slot].vy)<0.

func can_start(slot:int,action:String)->bool:
    var s:Dictionary=actors[slot]
    if action=="chase":
        return not airborne(slot) and airborne(1-slot) and s.action=="launch" and s.result=="hit" and s.remaining>0 and not s.used.has("chase")
    if action in Air.MOVES:
        return airborne(slot) and airborne(1-slot) and s.chasing and not s.air_used.has(action)
    return not airborne(slot)

func can_cancel(slot:int)->bool:
    var s:Dictionary=actors[slot]
    if s.buffer=="chase":return can_start(slot,"chase") and players[slot].age>s.marker
    if s.action=="chase" or s.action in Air.MOVES or s.buffer in Air.MOVES:
        return can_start(slot,s.buffer) and Air.permits(mode,s.action,s.buffer,s.result,s.air_used,s.remaining,players[slot].age,s.marker)
    return super.can_cancel(slot)

func started(slot:int,previous_action:String,next:String,cancelled:bool,old_remaining:int)->void:
    super.started(slot,previous_action,next,cancelled,old_remaining)
    var s:Dictionary=actors[slot]
    if next=="chase":
        s.chasing=true
        s.follow_left=Air.FOLLOW_TICKS
        s.air_used=[]
        s.vy=-2.9
        pursuits.append([tick,slot])
    elif next in Air.MOVES:s.air_used.append(next)

func interrupted(slot:int)->void:
    super.interrupted(slot)
    actors[slot].chasing=false
    actors[slot].follow_left=0

func completed(slot:int)->void:
    # End of the cancel chain is not an impact or the end of flight.
    super.interrupted(slot)

func step(left:Dictionary,right:Dictionary)->void:
    # Shared pre-tick budget: order-independent, no position snap to target.
    approach_budget=maxf(0.,(root_x(1)-root_x(0)-Air.GAP)*.5)
    super.step(left,right)

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    command=super.motion_command(slot,action,command)
    # Limit actual gait travel including inertia after leaving a dash.
    # Same budget for each player even when both advance simultaneously.
    command.travel_limit=0. if airborne(slot) else approach_budget
    if airborne(slot) or approach_budget<.02:command.speed=0.
    return command

func advance_positions()->void:
    var before:Array=[airborne(0),airborne(1)]
    super.advance_positions()
    for i in 2:
        var s:Dictionary=actors[i]
        var other:Dictionary=actors[1-i]
        if before[i] and not airborne(i):
            s.chasing=false
            s.follow_left=0
            s.juggled=false
            s.air_used=[]
            if s.action=="chase" or s.action in Air.MOVES:
                s.action=""
                s.remaining=0
                s.buffer=""
                s.interrupt=true
                super.interrupted(i)
        if not s.chasing or not airborne(i):continue
        # Bounded optional pursuit, no snapping/teleporting or repeated lifts.
        if airborne(1-i) and s.follow_left>0:
            var goal_v:float=clampf(float(other.vy)+(float(other.y)-2.-float(s.y))*.25,-3.1,3.1)
            s.vy=move_toward(float(s.vy),goal_v,.55)
            var step_x:float=minf(approach_budget,1.35)
            s.x=float(s.x)+facing(i)*step_x
            s.follow_left-=1
        else:s.follow_left=0

func marker_event(ev:Dictionary,a:Vector2,b:Vector2,blocking:bool,kind:String)->Dictionary:
    if ev.attack=="chase":
        ev.result="ready" if airborne(ev.attacker) and airborne(ev.target) else "miss"
        ev.distance=0.
        return ev
    ev=super.marker_event(ev,a,b,blocking,kind)
    if ev.attack=="launch" and airborne(ev.target):
        ev.result="miss"
    if ev.attack in Air.MOVES:
        if not airborne(ev.attacker) or not airborne(ev.target):
            ev.result="miss"
        elif ev.attack=="air_pulse":
            var extra:=Vector2(facing(int(ev.attacker))*10.,0.)
            var close:=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,b,b+extra)
            ev.distance=minf(float(ev.distance),close.length())
            ev.end=Vector2(ev.point)+extra
            ev.result="hit" if float(ev.distance)<=RADIUS and (root_x(ev.target)-root_x(ev.attacker))*facing(ev.attacker)>0. else "miss"
    return ev

func outcome(ev:Dictionary,target_stun:int)->void:
    if ev.attack=="chase":
        # 003's dash diagnostic must not count chase utility events.
        var s:Dictionary=actors[ev.attacker]
        if s.action=="chase":
            s.result=ev.result
            s.marker=players[ev.attacker].age-1
        var info:Dictionary=ev.duplicate(true)
        info.target_stun_before=target_stun
        info.true_link=false
        contacts.append(info)
        return
    super.outcome(ev,target_stun)

func after_resolve(ev:Dictionary)->void:
    super.after_resolve(ev)
    if ev.result!="hit":return
    var target:Dictionary=actors[ev.target]
    var source:Dictionary=actors[ev.attacker]
    if ev.attack=="launch":target.juggled=false
    elif ev.attack in Air.MOVES:
        air_hits.append([tick,ev.attacker,ev.attack,float(source.y),float(target.y)])
        if ev.attack=="air_cross" and not target.juggled:
            target.juggled=true
            target.vy=minf(float(target.vy),Air.JUGGLE_VY)
            juggle_events.append([tick,ev.target])
        elif ev.attack=="slam":
            target.vy=maxf(float(target.vy),Air.SLAM_VY)
            source.vy=maxf(float(source.vy),2.5)
            source.follow_left=0
            source.chasing=false
            slams.append([tick,ev.attacker,ev.target])

func save()->PackedByteArray:
    return var_to_bytes([4,super.save(),pursuits,air_hits,slams,juggle_events])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==4)
    super.restore(s[1])
    pursuits=s[2]
    air_hits=s[3]
    slams=s[4]
    juggle_events=s[5]
