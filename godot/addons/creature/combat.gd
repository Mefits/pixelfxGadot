extends RefCounted
const F=preload("res://addons/creature/fighter.gd")
const DT: float=1.0/120
var a
var b
var flashes: Array=[]
var hits: int=0
var elapsed: float=0
var accumulator: float=0
var hitstop: float=0
var freeze_total: float=0
var impacts: int=0
var blocks: int=0
var combo: int=0
var best_combo: int=0
var modern: bool=true
var last_impact: Vector2=Vector2.ZERO
var impact_time: float=0
var sim_steps: int=0

func _init(bank: Dictionary,second: Dictionary={}) -> void:
    a=F.new(93,1,Color("#5aafdc"),bank)
    b=F.new(227,-1,Color("#ce775f"),bank if second.is_empty() else second)

func step(dt: float,left: Dictionary,right: Dictionary) -> void:
    a.modern=modern
    b.modern=modern
    a.capture_input(left)
    b.capture_input(right)
    accumulator+=clampf(dt,0,.25)
    while accumulator+0.00000001>=DT:
        accumulator-=DT
        _tick(left,right)

func _tick(left: Dictionary,right: Dictionary) -> void:
    elapsed+=DT
    if hitstop>0 and modern:
        hitstop=maxf(0,hitstop-DT)
        freeze_total+=DT
        return
    hitstop=0
    sim_steps+=1
    impact_time=maxf(0,impact_time-DT)
    var ax: float=a.pos.x
    var bx: float=b.pos.x
    a.step(DT,left.get("move",0),left.get("jump",false),left.get("strike",false),left.get("cast",false),left.get("guard",false),bx)
    b.step(DT,right.get("move",0),right.get("jump",false),right.get("strike",false),right.get("cast",false),right.get("guard",false),ax)
    if absf(a.pos.y-b.pos.y)<18 and absf(a.pos.x-b.pos.x)<15:
        var d: float=1.0 if a.pos.x<b.pos.x else -1.0
        var m: float=clampf((a.pos.x+b.pos.x)*.5,23.5,296.5)
        a.pos.x=m-d*7.5
        b.pos.x=m+d*7.5
    # Snapshot both event outcomes before damage changes either pose or guard.
    var outcomes: Array=[]
    for e in a.events:_event(a,b,e,outcomes)
    for e in b.events:_event(b,a,e,outcomes)
    for h in outcomes:
        if not h.blocked:
            h.src.confirmed=true
            h.src.last_hit_time=h.time
            combo=int(h.chain)
            best_combo=maxi(best_combo,combo)
    for h in outcomes:
        h.dst.damage(h.amount,h.direction,h.blocked)
        hits+=1
        if h.blocked:blocks+=1
        else:impacts+=1
        if modern:
            hitstop=maxf(hitstop,.035 if h.blocked else (.085 if h.amount>=20 else .058))
            impact_time=.18
            last_impact=h.p
            flashes.append({"kind":"block" if h.blocked else "impact","a":h.p,"b":h.p,"age":0.0,"life":.16,"direction":h.direction})
    for i in range(flashes.size()-1,-1,-1):
        flashes[i].age+=DT
        if flashes[i].age>=flashes[i].life:flashes.remove_at(i)

func _event(src,dst,e: Dictionary,outcomes: Array) -> void:
    var hand: Vector2=e.world_anchor
    var chest: Vector2=dst.point("chest")
    var direction: int=e.direction
    var forward: bool=(chest.x-hand.x)*direction>=-5
    var amount: int=0
    match e.kind:
        "charge":
            flashes.append({"kind":"charge","a":hand,"b":hand,"age":0.0,"life":.3,"owner":src,"anchor":e.anchor})
        "strike":
            flashes.append({"kind":"strike","a":hand,"b":hand+Vector2(direction*9,-3),"age":0.0,"life":.15})
            if forward and hand.distance_to(chest)<=19 and dst.hp>0:amount=13
        "cast":
            var target: Vector2=hand+Vector2(direction*104,0)
            if forward and absf(chest.x-hand.x)<=104 and absf(chest.y-hand.y)<=26 and dst.hp>0:
                target=chest
                amount=20
            flashes.append({"kind":"cast","a":hand,"b":target,"age":0.0,"life":.21})
    if amount>0:
        outcomes.append({"src":src,"dst":dst,"amount":amount,"direction":direction,"blocked":dst.guard and direction==-dst.facing,"time":e.attack_time,"chain":e.chain,"p":chest})
