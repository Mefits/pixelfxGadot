extends RefCounted
## Delayed observation only. Bots never modify actors or predict future
## input/marker events. Replay stores the public commands they produced.
static func observe(w)->Dictionary:
    var a:Array=[]
    for s in w.actors:
        a.append({"action":str(s.action),"air":float(s.y)<0. or float(s.vy)<0.,"hurt":s.stun>0,"hp":s.hp})
    return {"gap":w.root_x(1)-w.root_x(0),"actors":a}

static func command(obs:Dictionary,slot:int,style:int,t:int)->Dictionary:
    var s:Dictionary=obs.actors[slot]
    var d:Dictionary=obs.actors[1-slot]
    var gap:float=obs.gap
    if s.hurt:return {"escape":s.air and style==1 and t%7==0}
    if s.air:return {"action":"air_cross" if t%11==0 else ("air_pulse" if t%11==5 else "")}
    if style==1 and not str(d.action).is_empty() and str(d.action) not in ["dash","chase","parry"] and gap<39.:
        if t%37==0:return {"action":"parry"}
        return {"guard":true}
    if t%12==0:
        if gap>39.:return {"action":"dash" if style==0 else "pulse"}
        if d.air:return {}
        var bank:Array=["jab","cross","kick","pulse","launch"]
        return {"action":bank[(int(t/12)+style)%bank.size()]}
    if s.action=="launch" and d.air and t%6==0:return {"action":"chase"}
    return {"forward":gap>31.}
