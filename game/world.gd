extends RefCounted
const M=preload("res://game/motor.gd")
const R=preload("res://game/rig.gd")
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
    var ax:float=a.pos.x
    var bx:float=b.pos.x
    a.tick(left,bx)
    b.tick(right,ax)
    if absf(a.pos.y-b.pos.y)<70 and absf(a.pos.x-b.pos.x)<38:
        var sign0:float=1 if ax<=bx else -1
        var mid:float=clampf((a.pos.x+b.pos.x)*.5,67,893)
        a.separate(mid-sign0*19-a.pos.x)
        b.separate(mid+sign0*19-b.pos.x)
        if a.velocity.x*sign0>0:a.velocity.x=0
        if b.velocity.x*sign0<0:b.velocity.x=0
    rig_a.sample(a)
    rig_b.sample(b)
    ticks+=1
