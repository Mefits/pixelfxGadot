extends RefCounted
const M=preload("res://game/motor.gd")
const R=preload("res://game/rig.gd")
const J=preload("res://game/jab.gd")
var jab_a=J.new()
var jab_b=J.new()
var hits:int=0
var freeze:int=0
var frozen_ticks:int=0
var hitstop_enabled:bool=true
var hybrid_enabled:bool=true
var last_lever:float=0
var last_contact:=Vector2.ZERO
var a=M.new(300,1)
var b=M.new(660,-1)
var rig_a=R.new()
var rig_b=R.new()
var accumulator:float=0
var ticks:int=0
func _init()->void:
    rig_a.sample(a)
    rig_b.sample(b)
func advance(dt:float,left:Dictionary,right:Dictionary)->void:
    accumulator+=clampf(dt,0,.1)
    while accumulator+1e-9>=M.DT:
        tick(left,right)
        accumulator=maxf(0,accumulator-M.DT)
func tick(left:Dictionary,right:Dictionary)->void:
    jab_a.capture(bool(left.get("jab",false)),bool(left.get("heavy",false)),bool(left.get("kick",false)))
    jab_b.capture(bool(right.get("jab",false)),bool(right.get("heavy",false)),bool(right.get("kick",false)))
    if freeze>0:
        freeze-=1
        frozen_ticks+=1
        ticks+=1
        return
    jab_a.tick(a)
    jab_b.tick(b)
    var prev_a:Vector2=jab_a.contact_point(rig_a,a.facing)
    var prev_b:Vector2=jab_b.contact_point(rig_b,b.facing)
    var ax:float=a.pos.x
    var bx:float=b.pos.x
    a.tick(_motor_input(left,jab_a),bx)
    b.tick(_motor_input(right,jab_b),ax)
    if absf(a.pos.y-b.pos.y)<70 and absf(a.pos.x-b.pos.x)<38:
        var sign0:float=1 if ax<=bx else -1
        var mid:float=clampf((a.pos.x+b.pos.x)*.5,67,893)
        a.separate(mid-sign0*19-a.pos.x)
        b.separate(mid+sign0*19-b.pos.x)
        if a.velocity.x*sign0>0:a.velocity.x=0
        if b.velocity.x*sign0<0:b.velocity.x=0
    rig_a.sample(a,jab_a.pose(hybrid_enabled),jab_a.reaction.angles if hybrid_enabled else Vector4.ZERO)
    rig_b.sample(b,jab_b.pose(hybrid_enabled),jab_b.reaction.angles if hybrid_enabled else Vector4.ZERO)
    # Snapshot contacts and attack parameters before applying either hit.
    var hit_a:Dictionary=_contact(a,b,jab_a,jab_b,prev_a,rig_a,rig_b)
    var hit_b:Dictionary=_contact(b,a,jab_b,jab_a,prev_b,rig_b,rig_a)
    var profile_a:Dictionary=jab_a.profile()
    var profile_b:Dictionary=jab_b.profile()
    var pause_ticks:int=0
    if not hit_a.is_empty():
        jab_a.connected=true
        last_contact=hit_a.point
        last_lever=float(hit_a.lever)
        jab_b.receive(b,a.facing,profile_a,last_lever)
        pause_ticks=maxi(pause_ticks,int(profile_a.freeze))
        hits+=1
    if not hit_b.is_empty():
        jab_b.connected=true
        last_contact=hit_b.point
        last_lever=float(hit_b.lever)
        jab_a.receive(a,b.facing,profile_b,last_lever)
        pause_ticks=maxi(pause_ticks,int(profile_b.freeze))
        hits+=1
    if pause_ticks>0:
        if hitstop_enabled:freeze=pause_ticks
        # Contact frame stays visible through freeze; hurt pose starts on next tick.
    ticks+=1

func _motor_input(input:Dictionary,j)->Dictionary:
    if j.kicking():return {"lock_facing":true,"kick_support":true}
    if j.kick_pending>0:return {"settle_kick":true,"lock_facing":true}
    if not j.locked():return input
    return {"lock_facing":true,"hurt":j.hurt>0 or j.hp<=0}

func _contact(src,dst,attack,defender,previous:Vector2,source_rig,target_rig)->Dictionary:
    if not attack.active() or defender.hp<=0:return {}
    if (dst.pos.x-src.pos.x)*src.facing<=0:return {}
    var p:Vector2=attack.contact_point(source_rig,src.facing)
    # Sweep the visible striking extremity against sampled torso capsule.
    # No hit from an arbitrary root distance. Ground/air targets use the same geometry.
    var upper:Vector2=target_rig.points.chest
    var lower:Vector2=target_rig.points.hips
    var best:float=17.0
    var contact:Dictionary={}
    for u in [0.0,.25,.5,.75,1.0]:
        var center:Vector2=upper.lerp(lower,u)
        var closest:Vector2=Geometry2D.get_closest_point_to_segment(center,previous,p)
        var distance:float=center.distance_to(closest)
        if distance<=best:
            best=distance
            contact={"point":closest,"lever":clampf(1.0-float(u),.2,1.0)}
    return contact
