extends RefCounted
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const FLOOR: float=146.0
const ATTACKS=["strike","cross","heavy","kick","air_strike","cast"]
var rig=RIG.humanoid()
var bank: Dictionary
var pos: Vector2
var velocity:=Vector2.ZERO
var facing: int=1
var hp: int=100
var state: String="idle"
var t: float=0
var guard: bool=false
var hitstun: float=0
var events: Array=[]
var tint: Color
var modern: bool=true
var queued: String=""
var buffer: float=0
var jump_buffer: float=0
var previous_strike: bool=false
var previous_cast: bool=false
var previous_jump: bool=false
var previous_heavy: bool=false
var previous_kick: bool=false
var confirmed: bool=false
var last_hit_time: float=-1
var chain: int=0
var attacks_started: int=0
var combo_clip: Dictionary={}
var current_pose: Dictionary={}
var blend_from: Dictionary={}
var blend_time: float=0
var flash: float=0
var last_blocked: bool=false

func _init(x: float,side: int,c: Color,clips: Dictionary) -> void:
    pos=Vector2(x,FLOOR)
    facing=side
    tint=c
    bank=CLIPS.complete(clips)
    combo_clip=bank.cross
    current_pose=CLIPS.sample(bank.idle,0)
    rig.evaluate(current_pose)

func point(id: String) -> Vector2:
    var q: Vector2=rig.point(id)
    return pos+Vector2(q.x*facing,q.y)

func clip() -> Dictionary:
    return bank[state]

func start(name: String,stage: int=0) -> void:
    blend_from=current_pose.duplicate(true)
    blend_time=.065 if modern else 0.0
    state=name
    t=0
    chain=stage
    confirmed=false
    last_hit_time=-1
    if name in ATTACKS:attacks_started+=1

func capture_input(input: Dictionary) -> void:
    var strike: bool=input.get("strike",false)
    var cast: bool=input.get("cast",false)
    var jump: bool=input.get("jump",false)
    var heavy: bool=input.get("heavy",false)
    var kick: bool=input.get("kick",false)
    if modern and heavy and not previous_heavy:
        queued="heavy"
        buffer=.23
    elif modern and kick and not previous_kick:
        queued="kick"
        buffer=.23
    elif strike and not previous_strike:
        queued="strike"
        buffer=.23
    elif cast and not previous_cast:
        queued="cast"
        buffer=.23
    if jump and not previous_jump:jump_buffer=.12
    previous_strike=strike
    previous_cast=cast
    previous_jump=jump
    previous_heavy=heavy
    previous_kick=kick

func _consume(name: String,stage: int=1) -> void:
    var chosen: String=name
    if modern and name=="strike":
        if pos.y<FLOOR-.1:chosen="air_strike"
        elif stage==2:chosen="cross"
    start(chosen,stage)
    queued=""
    buffer=0

func step(dt: float,move: float,jump: bool,strike: bool,cast: bool,block: bool,enemy_x: float) -> void:
    events.clear()
    if hp<=0:
        guard=false
        return
    flash=maxf(0,flash-dt)
    hitstun=maxf(0,hitstun-dt)
    var locked: bool=state in ATTACKS and t<float(clip().duration)
    var next_attack: String=queued if modern and buffer>0 else ("strike" if not modern and strike else ("cast" if not modern and cast else ""))
    if modern and locked and state in ["strike","cross"] and confirmed and chain<3 and t>=last_hit_time+.065 and t>=float(clip().duration)*.53 and next_attack in ["strike","cast"] and not block and hitstun<=0:
        _consume(next_attack,chain+1)
        locked=true
    if hitstun<=0 and not locked:
        facing=1 if enemy_x>=pos.x else -1
        guard=block
        if not next_attack.is_empty() and not block:
            _consume(next_attack)
        else:
            if (jump_buffer>0 if modern else jump) and pos.y>=FLOOR-.01 and not block:
                velocity.y=-118
                jump_buffer=0
            var wanted: String="jump" if pos.y<FLOOR-.01 or velocity.y<0 else ("guard" if block else ("walk" if absf(move)>.1 else "idle"))
            if state!=wanted:start(wanted)
        var target: float=move*(18 if block else 64 if modern else 53) if not state in ATTACKS else 0.0
        velocity.x=move_toward(velocity.x,target,dt*650) if modern else target
    else:
        guard=false
        velocity.x=move_toward(velocity.x,0,dt*(220 if modern else 150))
    if modern and state in ["strike","cross","heavy","kick","air_strike"] and hitstun<=0:
        var impact: float=float(clip().duration)*.43
        for e in clip().events:
            if e.kind=="strike":impact=float(e.t);break
        # Windup is authored in the pose; the motor adds a brief real forward step.
        if t>=maxf(0,impact-.075) and t<impact+.065:
            var drive: float=105 if state=="heavy" else (85 if state=="kick" else (78 if state=="cross" else 65))
            velocity.x=move_toward(velocity.x,facing*drive,dt*1200)
    buffer=maxf(0,buffer-dt)
    jump_buffer=maxf(0,jump_buffer-dt)
    velocity.y+=dt*340
    pos+=velocity*dt
    if pos.y>FLOOR:
        pos.y=FLOOR
        velocity.y=0
    pos.x=clampf(pos.x,16,304)
    var old: float=t if t>0.0 else -0.000001
    t+=dt
    var c: Dictionary=clip()
    var due: Array=[]
    if state in ATTACKS:
        for marker in CLIPS.events_between(c,old,t):
            if marker.kind!="vfx":due.append({"marker":marker,"absolute":float(marker.t)})
    due.append_array(CLIPS.visual_events_between(c,old,t,not state in ATTACKS))
    due.sort_custom(func(a,b):return float(a.absolute)<float(b.absolute))
    for entry in due:
        var marker: Dictionary=entry.marker
        if not rig.ids.has(marker.anchor):continue
        var e: Dictionary=marker.duplicate()
        rig.evaluate(CLIPS.sample(c,float(marker.t),false))
        e["world_anchor"]=point(marker.anchor)
        e["world_chest"]=point("chest")
        e["direction"]=facing
        e["attack_time"]=float(marker.t)
        e["chain"]=chain
        e["attack_kind"]=state
        events.append(e)
    current_pose=CLIPS.sample(c,t)
    if blend_time>0:
        blend_time=maxf(0,blend_time-dt)
        if state not in ["strike","cast"] or t<.065:
            current_pose=CLIPS.blend_pose(blend_from,current_pose,1-blend_time/.065)
    rig.evaluate(current_pose)

func damage(amount: int,direction: int,blocked: bool=false) -> void:
    last_blocked=blocked
    hp=maxi(0,hp-(maxi(1,int(amount/4.0)) if blocked else amount))
    flash=.11
    if blocked:
        if modern:velocity.x=direction*28
    else:
        hitstun=.42 if modern and amount>=22 else (.30 if modern and amount==17 else .24)
        queued=""
        buffer=0
        start("hurt_heavy" if modern and amount>=22 else "hurt")
        velocity.x=direction*((112 if amount>=22 else (88 if amount==17 else 70)) if modern else 45)
        current_pose=CLIPS.sample(bank[state],0)
        blend_time=0
        rig.evaluate(current_pose)
