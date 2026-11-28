extends "res://lab/combat_study_008/world.gd"
const Profiles=preload("res://lab/ability_study_001/profiles.gd")
var full_dash_travel:Array=[]
var dash_budget:Array=[-1.,-1.]
var entities:Array=[]
var lifecycle:Array=[]
var next_entity:int=1
var previous_elbows:Array=[]
var previous_travel:Array=[]
var ability_enabled:bool=true

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2,enabled:bool=true):
    super(gap,stop_enabled,profile,2)
    ability_enabled=enabled
    for id in Profiles.DATA:
        var p:Dictionary=Profiles.DATA[id]
        var clip:Dictionary=retime(original_cross,p.motion.release,p.motion.length)
        # Contact collection belongs to world, not the motion marker itself.
        clip.markers={}
        bank[id]=clip

func rule_for(action:String)->Dictionary:
    if Profiles.has_action(action):return Profiles.DATA[action].impact if ability_enabled else {}
    return super.rule_for(action)

func can_start(slot:int,action:String)->bool:
    if Profiles.has_action(action):return ability_enabled and not airborne(slot) and actors[slot].remaining==0
    return super.can_start(slot,action)

func can_cancel(slot:int)->bool:
    if Profiles.has_action(actors[slot].action) or Profiles.has_action(actors[slot].buffer):return false
    return super.can_cancel(slot)

func started(slot:int,previous_action:String,next:String,cancelled:bool,old_remaining:int)->void:
    super.started(slot,previous_action,next,cancelled,old_remaining)
    if not Profiles.has_action(next):return
    var e:Dictionary={"id":next_entity,"owner":slot,"attack":next,"age":0,"detached":false,"spent":false,"p":tip(slot,Profiles.DATA[next].motion.anchor),"travel":0.,"dash_travel":0.}
    next_entity+=1
    entities.append(e)
    if next=="impact_dash":dash_budget[slot]=15.
    lifecycle.append([tick,e.id,"start",slot])

func interrupted(slot:int)->void:
    super.interrupted(slot)
    if dash_budget[slot]>=0.:
        full_dash_travel.append([tick,slot,15.-dash_budget[slot]])
        dash_budget[slot]=-1.
    for e in entities:
        if e.owner==slot and not e.detached and not e.spent:
            e.spent=true
            lifecycle.append([tick,e.id,"interrupt",slot])

func step(left:Dictionary,right:Dictionary)->void:
    previous_elbows=[{"hand_near":point(0,"elbow_near"),"hand_far":point(0,"elbow_far")},{"hand_near":point(1,"elbow_near"),"hand_far":point(1,"elbow_far")}]
    previous_travel=[players[0].gait.travel,players[1].gait.travel]
    super.step(left,right)

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    command=super.motion_command(slot,action,command)
    if not Profiles.has_action(action):return command
    command.speed=0.
    command.travel_limit=0.
    for e in entities:
        if e.owner!=slot or e.attack!=action or e.detached or e.spent:continue
        var m:Dictionary=Profiles.DATA[action].movement
        if m.speed>0. and e.age>=m.first and e.age<=m.last:
            command.speed=m.speed
            command.travel_limit=minf(approach_budget,maxf(0.,float(dash_budget[slot])))
    return command

func advance_positions()->void:
    super.advance_positions()
    for i in 2:
        if dash_budget[i]>=0.:
            var travel:float=maxf(0.,float(players[i].gait.travel)-float(previous_travel[i]))
            dash_budget[i]=maxf(0.,dash_budget[i]-travel)

func completed(slot:int)->void:
    if dash_budget[slot]>=0.:
        # Base world decrements remaining before advance_positions on final tick.
        # The final ability tick has zero allowed gait travel.
        full_dash_travel.append([tick,slot,15.-dash_budget[slot]])
        dash_budget[slot]=-1.
    super.completed(slot)

static func near_segment(a:Vector2,b:Vector2)->float:
    if a.distance_squared_to(b)<.000001:return a.length()
    return Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b).length()

static func blade_end(hand:Vector2,elbow:Vector2,sign_x:float,length:float)->Vector2:
    var axis:Vector2=(hand-elbow).normalized()
    if axis.length_squared()<.01:axis=Vector2(sign_x,0.)
    return hand+axis*length

func marker_event(ev:Dictionary,a:Vector2,b:Vector2,blocking:bool,kind:String)->Dictionary:
    if Profiles.has_action(ev.attack):
        # Ability contact precomputed with its actual swept radius. Temporarily
        # disable only the 007 rig-marker diagnostic, not the defense resolver.
        var before:bool=diagnostic
        diagnostic=false
        ev=super.marker_event(ev,a,b,blocking,kind)
        diagnostic=before
        return ev
    return super.marker_event(ev,a,b,blocking,kind)

func contact_event(e:Dictionary,point_at:Vector2,distance:float,hit:bool,blocking:bool)->Dictionary:
    var i:int=e.owner
    var result:String=("block" if blocking else "hit") if hit else "miss"
    var ev:Dictionary={"id":"ability:%d:0"%int(e.id),"tick":tick,"attacker":i,"target":1-i,"attack":e.attack,"result":result,"anchor":Profiles.DATA[e.attack].motion.anchor,"point":point_at,"distance":distance,"entity":e.id}
    # Reuse 005's classification (parry/escape) and the one resolver.
    return marker_event(ev,Vector2.ZERO,Vector2.ZERO,blocking,"strike")

func collect_contacts(pending:Array,old_centers:Array,old_tips:Array,blocking:Array,actions:Array)->void:
    var keep:Array=[]
    for e in entities:
        var i:int=e.owner
        var j:int=1-i
        var p:Dictionary=Profiles.DATA[e.attack]
        var g:Dictionary=p.interaction
        if e.spent:continue
        if not e.detached and actions[i]!=e.attack:
            lifecycle.append([tick,e.id,"end",i])
            continue
        e.age+=1
        e.dash_travel+=maxf(0.,float(players[i].gait.travel)-float(previous_travel[i])) if p.movement.speed>0. else 0.
        var hand:Vector2=tip(i,p.motion.anchor)
        var old_hand:Vector2=old_tips[i][p.motion.anchor]
        var a:Vector2=old_hand-Vector2(old_centers[j])
        var b:Vector2=hand-center(j)
        var distance:float=INF
        var at:Vector2=hand
        var expired:bool=false
        var sweep_a:Vector2=a
        var sweep_b:Vector2=b
        if g.kind=="projectile":
            if not e.detached and e.age>=g.first:
                e.detached=true
                e.p=hand
                e.flight=0
                lifecycle.append([tick,e.id,"release",i,hand])
            if e.detached:
                var old:Vector2=e.p
                var delta:float=0. if e.flight==0 else minf(float(g.speed),maxf(0.,float(g.range)-float(e.travel)))
                var next:Vector2=old+Vector2(facing(i)*delta,0.)
                distance=(old-center(j)).length() if e.flight==0 else near_segment(old-Vector2(old_centers[j]),next-center(j))
                sweep_a=old-center(j) if e.flight==0 else old-Vector2(old_centers[j])
                sweep_b=next-center(j)
                e.p=next
                e.travel+=delta
                e.flight+=1
                at=next
                expired=e.travel>=g.range or e.flight>=p.lifecycle.life
        elif e.age>=g.first and e.age<=g.last:
            if g.kind=="blade":
                var old_end:Vector2=blade_end(old_hand,previous_elbows[i][p.motion.anchor],facing(i),g.length)
                var end:Vector2=blade_end(hand,point(i,str(p.motion.anchor).replace("hand_","elbow_")),facing(i),g.length)
                # Sweep nine evenly spaced blade points against moving hurt circle.
                # Bounded sampling, not an exact continuous rotating capsule.
                for n in range(9):
                    var u:float=float(n)/8.
                    var d:float=near_segment(old_hand.lerp(old_end,u)-Vector2(old_centers[j]),hand.lerp(end,u)-center(j))
                    if d<distance:
                        sweep_a=old_hand.lerp(old_end,u)-Vector2(old_centers[j])
                        sweep_b=hand.lerp(end,u)-center(j)
                        distance=d
                        at=hand.lerp(end,u)
            else:distance=near_segment(a,b)
            expired=e.age>=g.last
        var hit:bool=distance<=RADIUS+float(g.radius)
        if hit or expired:
            pending.append(contact_event(e,at,distance if is_finite(distance) else 9999.,hit,blocking[j]))
            if diagnostic:
                var ev:Dictionary=pending[-1]
                var nearest:Vector2=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,sweep_a,sweep_b) if sweep_a.distance_squared_to(sweep_b)>.000001 else sweep_a
                samples.append({"id":ev.id,"tick":tick,"attacker":i,"target":j,"attack":e.attack,"result":ev.result,"kind":"strike","origin":center(j),"a":sweep_a,"b":sweep_b,"extra":Vector2.ZERO,"nearest":nearest,"distance":ev.distance,"radius":RADIUS+float(g.radius),"blocking":blocking[j],"front":(root_x(j)-root_x(i))*facing(i)>0.,"air":[airborne(i),airborne(j)]})
            lifecycle.append([tick,e.id,"contact" if hit else "expire",i,e.dash_travel,e.travel])
            if g.kind=="blade":
                pending[-1].blade_base=hand
                pending[-1].blade_end=blade_end(hand,point(i,str(p.motion.anchor).replace("hand_","elbow_")),facing(i),g.length)
            # A struck attached effect can still be represented by the event;
            # it cannot hit again. Projectile dies on any resolved contact.
            continue
        keep.append(e)
    entities=keep

func after_resolve(ev:Dictionary)->void:
    super.after_resolve(ev)
    if Profiles.has_action(ev.attack) and ev.result=="hit":
        actors[ev.target].push_v=maxf(float(actors[ev.target].push_v),float(Profiles.DATA[ev.attack].impact.push))

func save()->PackedByteArray:
    return var_to_bytes([9,super.save(),entities,lifecycle,next_entity,ability_enabled,dash_budget,full_dash_travel])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==9 and s[5]==ability_enabled)
    super.restore(s[1])
    entities=s[2]
    lifecycle=s[3]
    next_entity=s[4]
    dash_budget=s[6]
    full_dash_travel=s[7]

func normalize(slot:int,cmd:Dictionary)->Dictionary:
    var raw:int=int(cmd.get("edge",0))
    if raw&224:
        var copy:Dictionary=cmd.duplicate(true)
        copy.edge=0
        var result:Dictionary=super.normalize(slot,copy)
        if raw==32:result.action="energy_bolt"
        elif raw==64:result.action="energy_blade"
        elif raw==128:result.action="impact_dash"
        return result
    return super.normalize(slot,cmd)
