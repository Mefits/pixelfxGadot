extends RefCounted
## Combat Lab 0.01: thin duel rules over two accepted Hybrid091 players.
## No spatial FK in the authoritative contact path. No new locomotion solver.
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const CHANNELS=["chest","head","shoulder_turn","shoulder_near","elbow_near","shoulder_far","elbow_far"]
const RULES={"jab":{"damage":8,"hitstun":12,"blockstun":6,"freeze":3},"cross":{"damage":14,"hitstun":16,"blockstun":8,"freeze":4},"kick":{"damage":18,"hitstun":20,"blockstun":10,"freeze":5}}
const BUFFER:int=12
const RADIUS:float=7.
const PUSH_GAP:float=14.
var bank:Dictionary={}
var players:Array=[]
var actors:Array=[]
var events:Array=[]
var tick:int=0
var freeze:int=0
var frozen_ticks:int=0
var hitstop_enabled:bool=true
var starts:Array=[]
var run_clip:Dictionary
var guard:Dictionary

func _init(gap:float=28.,stop_enabled:bool=true):
    hitstop_enabled=stop_enabled
    run_clip=read_clip("run053a_C")
    var combo:Dictionary=read_clip("combo052a2_B")
    var kick:Dictionary=read_clip("highkick051c2_C")
    # One marker per move. Use existing source slices/real contact points.
    bank.jab=Motion.compile(combo,0,30,CHANNELS,60)
    bank.cross=Motion.compile(combo,23,45,CHANNELS,60)
    bank.kick=Motion.compile(kick,23,53,CHANNELS,60,Body.make_rig(),{"far":[23,33,40,53]})
    guard=bank.jab.frames[0].duplicate(true)
    bank.recover={"frames":[guard.duplicate(true)],"roots":[[0.,0.]],"markers":{},"feet":[{}],"loop":false}
    for i in 2:
        var p=Kernel.new(Body.make_rig(),run_clip,bank,guard,60)
        # Initialization only: settle gait before opening the duel.
        for warm in 60:p.step({"speed":0.})
        players.append(p)
        actors.append({"x":(-gap*.5 if i==0 else gap*.5),"travel0":p.gait.travel,"hp":100,"stun":0,"action":"","remaining":0,"buffer":"","expires":-1,"guard":false,"interrupt":false,"impulse":0.})
    
static func read_clip(id:String)->Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(FIX+id+".json")).payload.clip

static func facing(slot:int)->float:return 1. if slot==0 else -1.

func root_x(slot:int)->float:
    return float(actors[slot].x)+facing(slot)*(float(players[slot].gait.travel)-float(actors[slot].travel0))

func point(slot:int,id:String)->Vector2:
    var p:Vector2=players[slot].rig.point(id)
    return Vector2(root_x(slot)+p.x*facing(slot),p.y)

func tip(slot:int,id:String)->Vector2:
    var p:Vector2=players[slot].anchors[id]
    return Vector2(root_x(slot)+(p.x-float(players[slot].gait.travel))*facing(slot),p.y)

func center(slot:int)->Vector2:
    return point(slot,"chest").lerp(point(slot,"hips"),.3)

func capture(slot:int,cmd:Dictionary)->void:
    var s:Dictionary=actors[slot]
    var a:String=str(cmd.get("action",""))
    if RULES.has(a):
        s.buffer=a
        s.expires=tick+BUFFER
    if tick>int(s.expires):s.buffer=""
    s.guard=bool(cmd.get("guard",false))

func step(left:Dictionary,right:Dictionary)->void:
    events=[]
    var cmds:Array=[left,right]
    for i in 2:capture(i,cmds[i])
    if freeze>0:
        freeze-=1
        frozen_ticks+=1
        tick+=1
        return
    if actors[0].hp<=0 or actors[1].hp<=0:
        tick+=1
        return
    var old_centers:Array=[center(0),center(1)]
    var old_tips:Array=[{},{}]
    for i in 2:
        for id in players[i].anchors:old_tips[i][id]=tip(i,id)
    var action_at_tick:Array=["",""]
    var blocking:Array=[false,false]
    for i in 2:
        var s:Dictionary=actors[i]
        var p=players[i]
        var command:Dictionary={"speed":0.,"impulse":s.impulse}
        s.impulse=0.
        if s.interrupt:
            command.action="recover"
            s.interrupt=false
        elif s.stun==0 and s.remaining==0 and not s.guard and not str(s.buffer).is_empty():
            s.action=s.buffer
            s.buffer=""
            s.remaining=bank[s.action].frames.size()
            command.action=s.action
            starts.append([tick,i,s.action])
        elif s.stun==0 and s.remaining==0 and not s.guard:
            command.speed=1. if bool(cmds[i].get("forward",false)) else 0.
        blocking[i]=s.guard and s.stun==0 and s.remaining==0
        action_at_tick[i]=s.action if s.remaining>0 and s.stun==0 else ""
        p.step(command)
        if s.remaining>0:
            s.remaining-=1
            if s.remaining==0:s.action=""
        s.stun=maxi(0,int(s.stun)-1)
    # Fixed-facing, bounded two-slot pushbox. No world/rig teleport on hit.
    var gap:float=root_x(1)-root_x(0)
    if gap<PUSH_GAP:
        var shift:float=(PUSH_GAP-gap)*.5
        actors[0].x-=shift
        actors[1].x+=shift
    # Resolve both geometric contacts before mutating either fighter.
    # The same marker/swept-circle contract as Hybrid, now relative to a
    # real second sampled rig. Internal kernel health is not match HP.
    var pending:Array=[]
    for i in 2:
        var other:int=1-i
        if str(action_at_tick[i]).is_empty():continue
        for ev in players[i].events:
            if ev[5]!="strike":continue
            var id:String=ev[3]
            var a:Vector2=Vector2(old_tips[i][id])-Vector2(old_centers[other])
            var b:Vector2=tip(i,id)-center(other)
            var near:Vector2=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b) if a.distance_squared_to(b)>.000001 else a
            var contact:bool=near.length()<=RADIUS and (root_x(other)-root_x(i))*facing(i)>0.
            var outcome:String=("block" if blocking[other] else "hit") if contact else "miss"
            pending.append({"id":"%d:%d:%d:%d"%[tick,i,ev[1],ev[2]],"tick":tick,"attacker":i,"target":other,"attack":action_at_tick[i],"result":outcome,"anchor":id,"point":tip(i,id),"distance":near.length()})
    for ev in pending:
        events.append(ev)
        if ev.result=="miss":continue
        var s:Dictionary=actors[ev.target]
        var rule:Dictionary=RULES[ev.attack]
        if ev.result=="hit":
            s.hp=maxi(0,int(s.hp)-int(rule.damage))
            s.stun=maxi(s.stun,rule.hitstun)
            s.remaining=0
            s.action=""
            s.buffer=""
            s.interrupt=true
            s.impulse=-100.
        else:
            s.stun=maxi(s.stun,rule.blockstun)
            s.impulse=-45.
        if hitstop_enabled:freeze=maxi(freeze,int(rule.freeze))
    tick+=1

func save()->PackedByteArray:
    # Local trusted test snapshot only; not network serialization.
    return var_to_bytes([1,tick,freeze,frozen_ticks,hitstop_enabled,actors,starts,players[0].save(),players[1].save()])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==1)
    tick=s[1]
    freeze=s[2]
    frozen_ticks=s[3]
    hitstop_enabled=s[4]
    actors=s[5]
    starts=s[6]
    players[0].restore(s[7])
    players[1].restore(s[8])
    events=[]
