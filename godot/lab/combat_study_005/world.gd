extends "res://lab/combat_study_004/world.gd"
## Prototype defense. All contact decisions are derived from the same
## sampled sweep as 004, before either fighter receives the result.
const PARRY_WINDOW:int=4
const PARRY_LENGTH:int=18
const PARRY_STUN:int=19
const ESCAPE_TICKS:int=6
const ESCAPE_LOCK:int=10
const PARRY_RULE={"damage":0,"hitstun":0,"blockstun":0,"freeze":0}
var parries:Array=[]
var escapes:Array=[]
var evades:Array=[]
var punishments:Array=[]
var defense_enabled:bool=true

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2,defense:bool=true):
    super(gap,stop_enabled,profile)
    defense_enabled=defense
    var frames:Array=[]
    var roots:Array=[]
    var feet:Array=[]
    for i in PARRY_LENGTH:
        frames.append(guard.duplicate(true))
        roots.append([0.,0.])
        feet.append({})
    bank.parry={"frames":frames,"roots":roots,"feet":feet,"markers":{},"loop":false}
    for s in actors:
        s.escape_used=false
        s.escape_until=-1
        s.evade_left=0

func rule_for(action:String)->Dictionary:
    if action=="parry":return PARRY_RULE if defense_enabled else {}
    return super.rule_for(action)

func can_start(slot:int,action:String)->bool:
    if action=="parry":
        return defense_enabled and not airborne(slot) and actors[slot].remaining==0
    return super.can_start(slot,action)

func can_cancel(slot:int)->bool:
    if actors[slot].action=="parry" or actors[slot].buffer=="parry":return false
    return super.can_cancel(slot)

func escape_eligible(slot:int)->bool:
    var s:Dictionary=actors[slot]
    return defense_enabled and not s.escape_used and s.stun>0 and airborne(slot) and s.hp>0

func step(left:Dictionary,right:Dictionary)->void:
    var cmds:Array=[left,right]
    for i in 2:
        var s:Dictionary=actors[i]
        if bool(cmds[i].get("escape",false)) and escape_eligible(i):
            s.escape_until=tick+BUFFER
        if tick>int(s.escape_until):s.escape_until=-1
    var live:bool=freeze==0 and actors[0].hp>0 and actors[1].hp>0
    if live:
        for i in 2:
            var s:Dictionary=actors[i]
            if s.escape_until<tick or not escape_eligible(i):continue
            s.escape_used=true
            s.escape_until=-1
            s.evade_left=ESCAPE_TICKS
            s.stun=ESCAPE_LOCK
            s.vy=maxf(float(s.vy),3.4)
            s.push_v=maxf(float(s.push_v),1.4)
            s.buffer=""
            s.remaining=0
            s.action=""
            s.interrupt=true
            interrupted(i)
            escapes.append([tick,i])
    super.step(left,right)
    if live:
        for s in actors:s.evade_left=maxi(0,int(s.evade_left)-1)

func marker_event(ev:Dictionary,a:Vector2,b:Vector2,blocking:bool,kind:String)->Dictionary:
    ev=super.marker_event(ev,a,b,blocking,kind)
    if not defense_enabled or ev.result!="hit":return ev
    var dst:int=ev.target
    var d:Dictionary=actors[dst]
    if d.evade_left>0 and airborne(dst):
        ev.result="evade"
    elif d.action=="parry" and not airborne(dst) and players[dst].age in range(1,PARRY_WINDOW+1):
        ev.result="parry"
    return ev

func outcome(ev:Dictionary,target_stun:int)->void:
    var d:Dictionary=actors[ev.target]
    # Detect genuine punishment of a previously missed attack during its
    # still-active recovery, not arbitrary damage on an idle fighter.
    if ev.result=="hit" and d.result=="miss" and d.remaining>0 and not str(d.action).is_empty():
        punishments.append([tick,ev.attacker,ev.target,ev.attack,d.action,d.remaining])
    super.outcome(ev,target_stun)

func resolve_special(ev:Dictionary)->bool:
    if ev.result=="evade":
        evades.append([tick,ev.target,ev.attack])
        return true
    if ev.result!="parry":return false
    var source:Dictionary=actors[ev.attacker]
    var target:Dictionary=actors[ev.target]
    source.stun=maxi(int(source.stun),PARRY_STUN)
    source.remaining=0
    source.action=""
    source.buffer=""
    source.interrupt=true
    source.impulse=-80.
    interrupted(int(ev.attacker))
    # Success releases the parry action; failure leaves all 18 ticks locked.
    target.remaining=0
    target.action=""
    target.interrupt=true
    completed(int(ev.target))
    parries.append([tick,ev.target,ev.attack])
    if hitstop_enabled:freeze=maxi(freeze,3)
    return true

func save()->PackedByteArray:
    return var_to_bytes([5,super.save(),defense_enabled,parries,escapes,evades,punishments])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==5 and s[2]==defense_enabled)
    super.restore(s[1])
    parries=s[3]
    escapes=s[4]
    evades=s[5]
    punishments=s[6]
