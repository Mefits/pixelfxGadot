extends "res://lab/combat_study_001/world.gd"
const Policy=preload("res://lab/combat_study_002/policy.gd")
var mode:int=0
var links:Array=[]
var contacts:Array=[]
var recovery_gaps:Array=[]

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=0):
    super(gap,stop_enabled)
    assert(profile in [0,1,2])
    mode=profile
    for s in actors:
        s.used=[]
        s.result=""
        s.marker=-1
        s.last_hit=-1

func can_cancel(slot:int)->bool:
    var s:Dictionary=actors[slot]
    return Policy.permits(mode,s.action,s.buffer,s.result,s.used,s.remaining,players[slot].age,s.marker)

func started(slot:int,previous_action:String,next:String,cancelled:bool,old_remaining:int)->void:
    var s:Dictionary=actors[slot]
    if cancelled:
        links.append({"tick":tick,"slot":slot,"from":previous_action,"to":next,"remaining":old_remaining,"source_marker":s.marker})
    else:
        s.used=[]
        s.last_hit=-1
    s.used.append(next)
    s.result=""
    s.marker=-1

func outcome(ev:Dictionary,target_stun:int)->void:
    var s:Dictionary=actors[ev.attacker]
    # Called after both contacts were computed. A trade's subsequent
    # interrupt clears the chain even if its outbound marker was accepted.
    if s.action==ev.attack:
        s.result=ev.result
        s.marker=players[ev.attacker].age-1
    var info:Dictionary=ev.duplicate(true)
    info.target_stun_before=target_stun
    info.true_link=ev.result=="hit" and int(s.last_hit)>=0 and target_stun>0
    contacts.append(info)
    if ev.result=="hit" and s.action==ev.attack:
        if s.last_hit>=0:recovery_gaps.append([ev.attacker,tick-int(s.last_hit),target_stun])
        s.last_hit=tick

func interrupted(slot:int)->void:
    var s:Dictionary=actors[slot]
    s.used=[]
    s.result=""
    s.marker=-1
    s.last_hit=-1

func completed(slot:int)->void:
    interrupted(slot)

func save()->PackedByteArray:
    return var_to_bytes([2,mode,super.save(),links,contacts,recovery_gaps])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==2 and s[1]==mode)
    super.restore(s[2])
    links=s[3]
    contacts=s[4]
    recovery_gaps=s[5]
