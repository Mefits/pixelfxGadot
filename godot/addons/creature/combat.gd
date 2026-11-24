extends RefCounted
const F=preload("res://addons/creature/fighter.gd")
var a
var b
var flashes: Array=[]
var hits: int=0
var elapsed: float=0

func _init(bank: Dictionary,second: Dictionary={}) -> void:
    a=F.new(93,1,Color("#5aafdc"),bank)
    b=F.new(227,-1,Color("#ce775f"),bank if second.is_empty() else second)

func step(dt: float,left: Dictionary,right: Dictionary) -> void:
    elapsed+=dt
    a.step(dt,left.get("move",0),left.get("jump",false),left.get("strike",false),left.get("cast",false),left.get("guard",false),b.pos.x)
    b.step(dt,right.get("move",0),right.get("jump",false),right.get("strike",false),right.get("cast",false),right.get("guard",false),a.pos.x)
    if absf(a.pos.y-b.pos.y)<18 and absf(a.pos.x-b.pos.x)<15:
        var d: float=1.0 if a.pos.x<b.pos.x else -1.0
        var m: float=(a.pos.x+b.pos.x)*.5
        a.pos.x=clampf(m-d*7.5,16,304)
        b.pos.x=clampf(m+d*7.5,16,304)
    # Collect both fighters' event lists before resolving, allowing trades.
    var ea: Array=a.events.duplicate()
    var eb: Array=b.events.duplicate()
    for e in ea: _event(a,b,e)
    for e in eb: _event(b,a,e)
    for i in range(flashes.size()-1,-1,-1):
        flashes[i].age+=dt
        if flashes[i].age>=flashes[i].life: flashes.remove_at(i)

func _event(src,dst,e: Dictionary) -> void:
    var hand: Vector2=e.world_anchor
    var chest: Vector2=dst.point("chest")
    var direction: int=e.direction
    var forward: bool=(chest.x-hand.x)*direction>=-5
    match e.kind:
        "charge":
            flashes.append({"kind":"charge","a":hand,"b":hand,"age":0.0,"life":.3,"owner":src,"anchor":e.anchor})
        "strike":
            flashes.append({"kind":"strike","a":hand,"b":hand+Vector2(direction*9,-3),"age":0.0,"life":.15})
            if forward and hand.distance_to(chest)<=19 and dst.hp>0:
                dst.damage(13,direction)
                hits+=1
        "cast":
            var target: Vector2=hand+Vector2(direction*104,0)
            if forward and absf(chest.x-hand.x)<=104 and absf(chest.y-hand.y)<=26 and dst.hp>0:
                target=chest
                dst.damage(20,direction)
                hits+=1
            flashes.append({"kind":"cast","a":hand,"b":target,"age":0.0,"life":.21})
