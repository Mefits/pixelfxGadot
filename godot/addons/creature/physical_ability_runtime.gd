extends RefCounted
## Fixed-tick physical ability runtime. Target dictionaries are shared with
## the host; position and HP updates are explicit. One active ability per body.
const P=preload("res://addons/creature/physical_ability.gd")
const H=preload("res://addons/creature/hybrid_attack.gd")
var profile:Dictionary={}
var target:Dictionary={}
var active:bool=false
var age:float=0
var cooldown:float=0
var phase:String="idle"
var branch:int=-1
var projectile:=Vector2.ZERO
var velocity:=Vector2.ZERO
var traveled:float=0
var hit:bool=false
var hits:int=0
var launches:int=0
var events:Array=[]
var acid_target:Dictionary={}
var acid_left:int=0
var acid_clock:float=0
var acid_damage:int=0
func configure(value:Dictionary)->bool:
    if active or not P.valid(value):return false
    profile=value.duplicate(true)
    return true
func clear_path(a:Vector2,b:Vector2,boxes:Array[Rect2],radius:float=0)->bool:
    return not H.segment_blocked(a,b,boxes,radius)
func begin(c,value:Dictionary)->bool:
    if active or cooldown>0 or c.attack.active or c.surface.active or c.grip_index>=0 or not P.compatible(profile,c):return false
    if profile.type!="grow" and (not value.get("p") is Vector2 or not value.has("hp") or not value.has("r") or int(value.hp)<=0):return false
    target=value
    age=0
    traveled=0
    hit=false
    branch=-1
    var head:Vector2=c.body.point("front")
    var direction:Vector2=(Vector2(value.get("p",head+Vector2(c.direction,0)))-head).normalized()
    if direction.length_squared()<.001:direction=Vector2(c.direction,0)
    match profile.type:
        "grab":
            var best:float=INF
            for i in range(c.branches.size()):
                var chain:Array=c.branches[i]
                var distance:float=c.body.nodes[chain[-1]].p.distance_to(value.p)
                if distance<best:best=distance;branch=i
            var max_reach:float=minf(float(profile.reach),float(c.anatomy.tentacle_length)*(c.branches[branch].size()-1))
            if head.distance_to(value.p)>max_reach+float(value.r)+2:return false
            phase="reach"
        "claw":
            if not c.attack.begin(c.limbs,c.direction):return false
            phase="strike"
        "grow":
            if not c.change_tail(1):return false
            phase="grow"
            events.append({"kind":"grow","p":head})
        "leap":
            if not c.grounded:return false
            var speed:float=float(profile.power)
            for i in range(c.body.nodes.size()):c.body.impulse(i,Vector2(signf(direction.x)*speed*.65,-speed))
            c.limbs.release_all()
            c.jump_cooldown=.22
            c.airborne_jump=true
            c.jump_cut=false
            phase="leap"
        "bolt","acid":
            projectile=head+direction*8
            if not clear_path(head,projectile,c.body.obstacles):return false
            velocity=direction*float(profile.power)
            phase="flight"
    active=true
    launches+=1
    return true
func finish()->void:
    active=false
    branch=-1
    phase="idle"
    cooldown=float(profile.get("cooldown",0))
func steer(c,dt:float)->void:
    if not active:return
    if profile.type=="grab" and branch>=0:
        if int(target.get("hp",0))<=0:finish();return
        var chain:Array=c.branches[branch]
        var root:Vector2=c.body.nodes[chain[0]].p
        var goal:Vector2=target.p
        if phase=="pull":
            goal=root+(goal-root).normalized()*minf(root.distance_to(goal),12.0)
        var span:float=float(c.anatomy.tentacle_length)*(chain.size()-1)
        goal=root+(goal-root).limit_length(span)
        for j in range(1,chain.size()):
            var n:Dictionary=c.body.nodes[chain[j]]
            var desired:Vector2=root.lerp(goal,float(j)/(chain.size()-1))
            var force:Vector2=((desired-Vector2(n.p))*65-Vector2(n.v)*4).limit_length(float(profile.power))
            c.body.force(chain[j],force)
            c.body.force(chain[j-1],-force*.25)
func _damage(at:Vector2,amount:int)->void:
    if hit:return
    hit=true
    target.hp=maxi(0,int(target.hp)-amount)
    hits+=1
    events.append({"kind":"hit","p":at,"type":profile.type})
func after(c,dt:float)->void:
    cooldown=maxf(0,cooldown-dt)
    if acid_left>0:
        acid_clock-=dt
        if acid_clock<=0:
            acid_clock+=.25
            acid_left-=1
            if int(acid_target.get("hp",0))>0:acid_target.hp=maxi(0,int(acid_target.hp)-acid_damage)
    if not active:return
    age+=dt
    var head:Vector2=c.body.point("front")
    if profile.type=="grab" and branch>=0:
        var chain:Array=c.branches[branch]
        var tip:Vector2=c.body.nodes[chain[-1]].p
        var p:Vector2=target.p
        if phase=="reach" and tip.distance_to(p)<=float(target.r)+3 and clear_path(tip,p,c.body.obstacles):
            phase="pull"
            hits+=1
            events.append({"kind":"grab","p":tip})
        if phase=="pull":
            if not clear_path(tip,p,c.body.obstacles) or tip.distance_to(p)>float(target.r)+12:finish();return
            var wanted:Vector2=p.move_toward(tip,float(profile.power)*dt)
            if clear_path(p,wanted,c.body.obstacles,float(target.r)):
                target.p=wanted
            else:
                finish()
                return
    elif profile.type=="leap":
        if age>.05 and head.distance_to(target.p)<=float(profile.reach)+float(target.r) and clear_path(head,target.p,c.body.obstacles):
            _damage(head,int(profile.damage))
    elif profile.type in ["bolt","acid"]:
        var before:Vector2=projectile
        if profile.type=="acid":velocity.y+=60*dt
        var next:Vector2=before+velocity*dt
        var d:Vector2=next-before
        var u:float=clampf((Vector2(target.p)-before).dot(d)/maxf(.00001,d.length_squared()),0,1)
        var contact:Vector2=before+d*u
        if contact.distance_to(target.p)<=float(target.r)+2 and clear_path(before,contact,c.body.obstacles,1.0):
            projectile=contact
            _damage(contact,int(profile.damage))
            if profile.type=="acid":
                acid_target=target
                acid_left=4
                acid_clock=.25
                acid_damage=maxi(1,int(float(profile.damage)/3.0))
            finish()
            return
        if not clear_path(before,next,c.body.obstacles,1.0):
            events.append({"kind":"blocked","p":before})
            finish()
            return
        projectile=next
        traveled+=d.length()
        if traveled>=float(profile.reach):finish();return
    elif profile.type=="claw":
        if not c.attack.active:finish();return
        return
    if age>=float(profile.duration):finish()
func drain_events()->Array:
    var out:Array=events.duplicate(true)
    events.clear()
    return out
