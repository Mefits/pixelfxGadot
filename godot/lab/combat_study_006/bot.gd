extends RefCounted
## Only delayed visible action, phase proxy, air, spacing and reaction.
## No privileged access to contacts, future commands, hidden buffers or HP rules.
static func observe(w)->Dictionary:
    var a:Array=[]
    for i in 2:
        var s:Dictionary=w.actors[i]
        a.append({"action":str(s.action),"air":w.airborne(i),"hurt":s.stun>0,"pose_age":w.players[i].age if not str(s.action).is_empty() else 0})
    return {"gap":w.root_x(1)-w.root_x(0),"actors":a}

static func command(obs:Dictionary,slot:int,style:int,t:int)->Dictionary:
    var s:Dictionary=obs.actors[slot]
    var d:Dictionary=obs.actors[1-slot]
    var gap:float=obs.gap
    var phase:int=t+style*5
    if s.hurt:return {"escape":s.air and phase%5==0}
    if s.air:
        if phase%9==0:return {"action":"air_cross"}
        if phase%9==4:return {"action":"air_pulse"}
        return {}
    if s.action=="launch" and d.air:return {"action":"chase"} if phase%4==0 else {}
    if not str(s.action).is_empty():return {}
    var threat:bool=str(d.action) in ["jab","cross","kick","pulse","launch"]
    if style==1:
        # A spacing-oriented opponent retreats early from visible windup,
        # and attacks when a later phase is observed. No guaranteed punish.
        if threat and int(d.pose_age)<12 and gap<37.:return {"back":true}
        if gap>38. and phase%8==0:return {"action":"pulse"}
        if gap<36. and phase%10==0:return {"action":"cross" if threat else "jab"}
        return {"forward":gap>46.}
    if style==2:
        # Bounded guard interval, then attempt a counter. Avoid 005's
        # indefinite guard throughout all of the opponent's recovery.
        if threat and int(d.pose_age)<15 and gap<38.:return {"guard":true}
        if phase%8==0:return {"action":"pulse" if gap>37. else ("cross" if threat else "launch")}
        return {"forward":gap>34.}
    if phase%8==0:
        if gap>39.:return {"action":"dash"}
        var choices:Array=["jab","cross","kick","launch","pulse"]
        return {"action":choices[int(phase/8)%choices.size()]}
    return {"forward":gap>30.}
