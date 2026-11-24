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
    jab_a.capture(bool(left.get("jab",false)))
    jab_b.capture(bool(right.get("jab",false)))
    if freeze>0:
        freeze-=1
        frozen_ticks+=1
        ticks+=1
        return
    jab_a.tick(a)
    jab_b.tick(b)
    var prev_a:Vector2=rig_a.points.hand_near
    var prev_b:Vector2=rig_b.points.hand_near
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
    rig_a.sample(a,jab_a.pose())
    rig_b.sample(b,jab_b.pose())
    # Snapshot both contacts before modifying either fighter.
    var hit_a:bool=_contact(a,b,jab_a,jab_b,prev_a,rig_a,rig_b)
    var hit_b:bool=_contact(b,a,jab_b,jab_a,prev_b,rig_b,rig_a)
    if hit_a:
        jab_a.connected=true
        last_contact=rig_a.points.hand_near
        jab_b.receive(b,a.facing)
        hits+=1
    if hit_b:
        jab_b.connected=true
        last_contact=rig_b.points.hand_near
        jab_a.receive(a,b.facing)
        hits+=1
    if hit_a or hit_b:
        if hitstop_enabled:freeze=J.HITSTOP
        # Contact frame stays visible through freeze; hurt pose starts on next tick.
    ticks+=1

func _motor_input(input:Dictionary,j)->Dictionary:
    if not j.locked():return input
    return {"lock_facing":true,"hurt":j.hurt>0 or j.hp<=0}

func _contact(src,dst,attack,defender,previous:Vector2,source_rig,target_rig)->bool:
    if not attack.active() or defender.hp<=0:return false
    if (dst.pos.x-src.pos.x)*src.facing<=0:return false
    var p:Vector2=source_rig.points.hand_near
    # Sweep the visible fist against torso capsule sampled at three points.
    # No hit from an arbitrary root distance. Ground/air targets use the same geometry.
    var upper:Vector2=target_rig.points.chest
    var lower:Vector2=target_rig.points.hips
    for u in [0.0,.5,1.0]:
        var center:Vector2=upper.lerp(lower,u)
        var closest:Vector2=Geometry2D.get_closest_point_to_segment(center,previous,p)
        if center.distance_to(closest)<=17.0:return true
    return false
