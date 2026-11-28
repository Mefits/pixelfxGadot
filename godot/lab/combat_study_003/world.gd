extends "res://lab/combat_study_002/world.gd"
const Skills=preload("res://lab/combat_study_003/skills.gd")
var landings:Array=[]
var dash_ready:Array=[]

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2):
    super(gap,stop_enabled,profile)
    # Use existing clips as placeholders, retaining real hand markers.
    # The pulse has a finite additional reach segment, launch uses the
    # cross pose; neither pretends to be a finished authored animation.
    bank.pulse=bank.cross.duplicate(true)
    bank.launch=bank.cross.duplicate(true)
    var frames:Array=[]
    var roots:Array=[]
    var feet:Array=[]
    for i in Skills.DASH_DURATION:
        frames.append({})
        roots.append([0.,0.])
        feet.append({})
    bank.dash={"frames":frames,"roots":roots,"feet":feet,"markers":{Skills.DASH_MARK:[{"kind":"utility","anchor":"hand_near"}]},"loop":false}
    for s in actors:
        s.y=0.
        s.vy=0.
        s.push_v=0.

func rule_for(action:String)->Dictionary:
    return Skills.EXTRA.get(action,super.rule_for(action))

func point(slot:int,id:String)->Vector2:
    return super.point(slot,id)+Vector2(0.,float(actors[slot].y))

func tip(slot:int,id:String)->Vector2:
    return super.tip(slot,id)+Vector2(0.,float(actors[slot].y))

func can_act(slot:int)->bool:
    return float(actors[slot].y)>=0. and float(actors[slot].vy)>=0.

func can_cancel(slot:int)->bool:
    var s:Dictionary=actors[slot]
    if not Skills.EXTRA.has(s.action) and not Skills.EXTRA.has(s.buffer):return super.can_cancel(slot)
    return Skills.permits(mode,s.action,s.buffer,s.result,s.used,s.remaining,players[slot].age,s.marker)

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    if action=="dash" and actors[slot].stun==0:
        command.speed=1.85
    return command

func advance_positions()->void:
    for i in 2:
        var s:Dictionary=actors[i]
        if float(s.y)<0. or float(s.vy)<0.:
            s.y=float(s.y)+float(s.vy)
            s.vy=float(s.vy)+Skills.GRAVITY
            if float(s.y)>=0.:
                s.y=0.
                s.vy=0.
                landings.append([tick,i])
        s.x=float(s.x)-facing(i)*float(s.push_v)
        s.push_v=move_toward(float(s.push_v),0.,.14)

func marker_event(ev:Dictionary,_a:Vector2,b:Vector2,blocking:bool,kind:String)->Dictionary:
    if kind=="utility":
        ev.result="ready"
        ev.distance=0.
        return ev
    if ev.attack=="pulse":
        var extra:=Vector2(facing(int(ev.attacker))*float(Skills.EXTRA.pulse.reach),0.)
        var close:=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,b,b+extra)
        var distance:float=minf(float(ev.distance),close.length())
        var front:bool=(root_x(ev.target)-root_x(ev.attacker))*facing(ev.attacker)>0.
        ev.distance=distance
        ev.result=("block" if blocking else "hit") if front and distance<=RADIUS else "miss"
        ev.end=Vector2(ev.point)+extra
    return ev

func outcome(ev:Dictionary,target_stun:int)->void:
    super.outcome(ev,target_stun)
    if ev.result=="ready":dash_ready.append([tick,ev.attacker])

func after_resolve(ev:Dictionary)->void:
    var s:Dictionary=actors[ev.target]
    if ev.result!="hit":return
    if ev.attack=="pulse":s.push_v=maxf(float(s.push_v),float(Skills.EXTRA.pulse.push))
    elif ev.attack=="launch":
        # One launch impulse on the ground; no air relaunch or air pursuit
        # in this stage. Full airborne control is the next experiment.
        if float(s.y)==0. and float(s.vy)==0.:s.vy=Skills.EXTRA.launch.vy
        s.push_v=maxf(float(s.push_v),float(Skills.EXTRA.launch.push))

func save()->PackedByteArray:
    return var_to_bytes([3,super.save(),landings,dash_ready])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==3)
    super.restore(s[1])
    landings=s[2]
    dash_ready=s[3]
