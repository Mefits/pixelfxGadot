extends RefCounted
const Old=preload("res://lab/combat_study_006/bot.gd")
static func observe(w)->Dictionary:
    var o:Dictionary=Old.observe(w)
    o.bolts=[]
    for e in w.entities:
        if e.detached and not e.spent:o.bolts.append({"owner":e.owner,"x":e.p.x,"y":e.p.y})
    o.roots=[w.root_x(0),w.root_x(1)]
    return o

static func command(o:Dictionary,slot:int,style:int,t:int)->Dictionary:
    var s:Dictionary=o.actors[slot]
    var d:Dictionary=o.actors[1-slot]
    var gap:float=o.gap
    if s.hurt or s.air or s.action=="launch":return Old.command(o,slot,style,t)
    if not str(s.action).is_empty():return {}
    # Same eight-tick decision cadence, differing preferences.
    for bolt in o.bolts:
        if bolt.owner!=slot and absf(float(bolt.x)-float(o.roots[slot]))<24.:return {"guard":true}
    var phase:int=t+style*5
    if phase%8!=0:return {"forward":gap>38. and style==0,"back":gap<30. and style==1}
    var cycle:int=phase/8
    if style==1:
        if gap>43.:return {"action":"energy_bolt"}
        if gap>30.:return {"action":"energy_blade"} if cycle%2==0 else {"back":true}
        return {"action":"pulse"} if cycle%2==0 else {"back":true}
    if style==2:
        if str(d.action) in ["jab","cross","kick","pulse","launch","energy_blade","impact_dash"] and int(d.pose_age)<12:return {"guard":true}
        if gap>43.:return {"action":"energy_bolt"}
        return {"action":["cross","energy_blade","launch"][cycle%3]}
    if gap>42.:return {"action":"impact_dash" if cycle%2==0 else "energy_bolt"}
    if gap>30.:return {"action":"impact_dash"}
    return {"action":["jab","launch","energy_blade","cross"][cycle%4]}
