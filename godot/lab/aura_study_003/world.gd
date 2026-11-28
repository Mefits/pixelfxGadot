extends "res://lab/ability_study_001/world.gd"
const Fist=preload("fist_geometry.gd")
const ATTACK:String="avatar_fist"
var timing:int=1
var casts:Array=[{},{}]
var cast_serial:int=1
var fist_events:Array=[]
var impulses:Array=[]

func _init(gap:float=52.,variant:int=1,stop_enabled:bool=true):
    super(gap,stop_enabled,2,true)
    assert(variant in [0,1,2])
    timing=variant
    var p:Dictionary=Fist.TIMINGS[timing]
    var clip:Dictionary=retime(bank.cross,int(p.peak)-1,int(p.length))
    # Do not let the human hand produce a second hit.
    # A non-strike marker retains the original transition deadline.
    clip.markers={int(p.peak)-1:[{"kind":"phase","anchor":"hand_far"}]}
    bank[ATTACK]=clip

func rule_for(action:String)->Dictionary:
    if action==ATTACK:return {"damage":Fist.DAMAGE,"hitstun":48,"blockstun":12,"freeze":Fist.TIMINGS[timing].freeze}
    return super.rule_for(action)

func can_start(slot:int,action:String)->bool:
    if action==ATTACK:return not airborne(slot) and actors[slot].remaining==0
    return super.can_start(slot,action)

func can_cancel(slot:int)->bool:
    if actors[slot].action==ATTACK or actors[slot].buffer==ATTACK:return false
    return super.can_cancel(slot)

func motion_command(slot:int,action:String,command:Dictionary)->Dictionary:
    command=super.motion_command(slot,action,command)
    if action==ATTACK:
        command.speed=0.
        command.travel_limit=0.
    return command

func geom(slot:int,g:float)->Dictionary:
    return Fist.sample(point(slot,"elbow_far"),tip(slot,"hand_far"),facing(slot),g)

func started(slot:int,previous_action:String,next:String,cancelled:bool,old_remaining:int)->void:
    super.started(slot,previous_action,next,cancelled,old_remaining)
    if next!=ATTACK:return
    casts[slot]={"id":cast_serial,"result":"","geometry":geom(slot,0.),"impact_age":-1,"locked":{}}
    cast_serial+=1

func interrupted(slot:int)->void:
    super.interrupted(slot)
    casts[slot]={}

func completed(slot:int)->void:
    super.completed(slot)
    casts[slot]={}

func collect_contacts(pending:Array,old_centers:Array,old_tips:Array,blocking:Array,actions:Array)->void:
    super.collect_contacts(pending,old_centers,old_tips,blocking,actions)
    var p:Dictionary=Fist.TIMINGS[timing]
    for i in 2:
        if casts[i].is_empty() or actions[i]!=ATTACK:continue
        var c:Dictionary=casts[i]
        var age:int=players[i].age
        var prev:Dictionary=c.geometry
        var g:float=Fist.growth(age,p)
        var next:Dictionary=geom(i,g)
        if not c.locked.is_empty():
            # Contact stops the extension; after hit-stop retract relative
            # to the current wrist, never track or snap to the target.
            var locked:Dictionary=c.locked
            var u:float=1.-smoothstep(0.,float(p.end-p.peak+4),float(age-int(c.impact_age)))
            next.g=float(locked.g)*u
            next.radius=float(locked.radius)*u
            next.axis=locked.axis
            next.center=Vector2(next.wrist)+(Vector2(locked.center)-Vector2(locked.wrist))*u
            c.geometry=next
            continue
        c.geometry=next
        if c.result!="":continue
        var j:int=1-i
        var a:Vector2=Vector2(prev.center)-Vector2(old_centers[j])
        var b:Vector2=Vector2(next.center)-center(j)
        var fraction:float=-1.
        if age<=int(p.hold) and g>=.12 and (root_x(j)-root_x(i))*facing(i)>0.:
            fraction=Fist.sweep(a,b,RADIUS+float(prev.radius),RADIUS+float(next.radius))
        if fraction<0. and age<int(p.hold):continue
        var hit:bool=fraction>=0.
        var at:Vector2=next.center
        var normal:Vector2=Vector2(facing(i),0.)
        var dist:float=b.length()
        if hit:
            var cc:Vector2=Vector2(prev.center).lerp(next.center,fraction)
            var target:Vector2=Vector2(old_centers[j]).lerp(center(j),fraction)
            normal=(target-cc).normalized()
            if normal.length_squared()<.01:normal=Vector2(facing(i),0.)
            var radius:float=lerpf(float(prev.radius),float(next.radius),fraction)
            at=cc+normal*radius
            dist=cc.distance_to(target)
            next.center=cc
            next.g=lerpf(float(prev.g),g,fraction)
            next.radius=radius
        var ev:Dictionary={"id":"avatar:%d:0"%int(c.id),"tick":tick,"attacker":i,"target":j,"attack":ATTACK,"result":("block" if blocking[j] else "hit") if hit else "miss","anchor":"hand_far","point":at,"distance":dist,"fist_center":next.center,"fist_radius":next.radius,"normal":normal,"fraction":fraction,"age":age}
        ev=marker_event(ev,a,b,blocking[j],"strike")
        c.result=ev.result
        if ev.result in ["hit","block","parry"]:
            c.impact_age=age
            c.locked=next.duplicate(true)
        c.geometry=next
        fist_events.append(ev.duplicate(true))
        pending.append(ev)

func after_resolve(ev:Dictionary)->void:
    super.after_resolve(ev)
    if ev.attack!=ATTACK or ev.result!="hit":return
    var s:Dictionary=actors[ev.target]
    # Reuse the existing authoritative 003/004 air/ground trajectory,
    # damping and landing. Do not directly modify HP or root position.
    s.push_v=maxf(float(s.push_v),Fist.PUSH)
    if float(s.y)==0. and float(s.vy)==0.:s.vy=Fist.LIFT
    s.impulse=Fist.RECOIL
    impulses.append({"tick":tick,"slot":ev.target,"vx":-facing(ev.target)*float(s.push_v),"vy":s.vy,"point":ev.point})

func save()->PackedByteArray:
    return var_to_bytes([3,super.save(),timing,casts,cast_serial,fist_events,impulses])

func restore(bytes:PackedByteArray)->void:
    var s:Array=bytes_to_var(bytes)
    assert(s[0]==3 and s[2]==timing)
    super.restore(s[1])
    casts=s[3]
    cast_serial=s[4]
    fist_events=s[5]
    impulses=s[6]
